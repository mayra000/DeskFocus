//
//  DeskSessionStore.swift
//  DeskFocus
//

import Combine
import Foundation
import Observation

@Observable @MainActor
final class DeskSessionStore {

    var posture: Posture
    var running: Bool {
        didSet {
            if !running {
                lastReconcileAt = nil
            }
        }
    }

    var sessionPausedMs: Int
    var runStartedAt: Date?
    var sessionDisplayMode: SessionDisplayMode
    var countdownDurationMs: Int
    var standingGoalMs: Int
    var factIndex: Int

    var weeklySittingMs: Int
    var weekKey: String

    /// Drives Live Activity: true while the desk timer is running; cleared on pause / clear / countdown end.
    var deskLiveActivityVisible: Bool

    /// Fired after each **continuous** standing segment accumulates `STANDING_CONFETTI_INTERVAL_MS` while the desk timer is running.
    var onStandingConfettiMilestone: (() -> Void)?

    /// Fired after each **continuous** sitting segment accumulates `SITTING_HOUR_MS` while the desk timer is running.
    var onSittingHourConfettiMilestone: (() -> Void)?

    /// Fired when the user pauses stopwatch mode after running at least one minute in the ended segment.
    var onStopwatchSegmentPauseCelebrate: (() -> Void)?

    /// Fired when the desk **countdown** reaches zero (not user clear).
    var onDeskCountdownComplete: (() -> Void)?

    private(set) var tickNow: Date = .init()

    var sessionElapsedMs: Int {
        computeSessionElapsed(at: tickNow)
    }

    private var lastReconcileAt: Date?

    private var ticker: AnyCancellable?

    private let storage: DeskStorage
    private let dailyLogStore: DailyLogStore
    private let defaults: UserDefaults
    private let notificationScheduler: NotificationScheduler

    /// Live Activity / ActivityKit sync (optional).
    weak var liveActivityManager: DeskSessionLiveActivityManager?

    private static let notificationsPromptKey = "deskfocus.notifications.prompted"
    private static let stopwatchPauseConfettiMinSegmentMs = 60_000


    /// Progress toward the next standing confetti milestone within the current standing stretch (resets when switching to sitting).
    private var standingConfettiAccumMs: Int = 0

    /// Progress toward the next sitting-hour confetti milestone within the current sitting stretch (resets when switching to standing).
    private var sittingHourConfettiAccumMs: Int = 0

    /// Throttles streak retention notification rescheduling during standing reconciliation.
    private var lastStreakRetentionRescheduleAt: Date?

    init(
        storage: DeskStorage,
        dailyLogStore: DailyLogStore,
        defaults: UserDefaults = .standard,
        notificationScheduler: NotificationScheduler = .shared
    ) {
        self.storage = storage
        self.dailyLogStore = dailyLogStore
        self.defaults = defaults
        self.notificationScheduler = notificationScheduler

        let snapshot = storage.load()
        posture = snapshot.posture
        running = snapshot.running
        sessionPausedMs = snapshot.sessionPausedMs
        runStartedAt = snapshot.runStartedAt
        sessionDisplayMode = snapshot.sessionDisplayMode
        countdownDurationMs = clampCountdownMs(snapshot.countdownDurationMs)
        standingGoalMs = clampStandingGoalMs(snapshot.standingGoalMs)
        factIndex = snapshot.factIndex
        weeklySittingMs = snapshot.weeklySittingMs
        weekKey = snapshot.weekKey
        deskLiveActivityVisible = snapshot.deskLiveActivityVisible
        if !running {
            deskLiveActivityVisible = false
        }

        if running {
            lastReconcileAt = runStartedAt ?? Date()
            startTickerIfNeeded()
        }
    }

    // MARK: - Actions

    func play() {
        guard !running else { return }

        if defaults.bool(forKey: Self.notificationsPromptKey) {
            beginPlayWithoutPrompt()
            return
        }

        Task { @MainActor in
            await notificationScheduler.requestPermission()
            self.defaults.set(true, forKey: Self.notificationsPromptKey)
            self.beginPlayWithoutPrompt()
        }
    }

    func pause() {
        pauseAndPersist(at: Date())
    }

    /// Resume/toggle target for Live Activity: resumes without the first-play notification prompt flow.
    func resumeFromLiveActivity() {
        guard !running else { return }
        beginPlayWithoutPrompt()
    }

    /// Pause if running, otherwise resume (Live Activity play/pause control).
    func applyLiveActivityToggle() {
        if running {
            pause()
        } else {
            resumeFromLiveActivity()
        }
    }

    func clearSession() {
        guard !running else { return }
        clearDeskTimerElapsedState()
        persist()
    }

    /// Pauses if running, then clears desk timer **progress only** (elapsed, live activity, alerts).
    /// Does not change countdown duration, posture, weekly sitting totals, or SwiftData logs.
    func resetDeskTimerProgress() {
        if running {
            pauseAndPersist(at: Date())
        }
        clearDeskTimerElapsedState()
        persist()
    }

    /// Clears countdown target to `0` only. Leaves shared desk timer elapsed (stopwatch accumulation) untouched.
    func clearCountdownTime() {
        guard sessionDisplayMode == .countdown else { return }
        if running {
            pauseAndPersist(at: Date())
        }
        setCountdownDurationMs(0)
    }

    private func clearDeskTimerElapsedState() {
        notificationScheduler.cancelAllDeskAlerts()
        sessionPausedMs = 0
        runStartedAt = nil
        standingConfettiAccumMs = 0
        sittingHourConfettiAccumMs = 0
        deskLiveActivityVisible = false
    }

    func switchPosture() {
        let wasRunning = running
        if wasRunning {
            reconcile(at: Date())
        }

        posture = posture == .sitting ? .standing : .sitting

        if posture == .sitting {
            standingConfettiAccumMs = 0
        } else {
            sittingHourConfettiAccumMs = 0
        }

        sessionPausedMs = 0
        if wasRunning {
            let now = Date()
            runStartedAt = now
            lastReconcileAt = now
            tickNow = now
            refreshDeskNotifications(reference: now)
        } else {
            runStartedAt = nil
        }

        persist()
    }

    func toggleSessionDisplayMode() {
        sessionDisplayMode = sessionDisplayMode == .stopwatch ? .countdown : .stopwatch
        refreshDeskNotifications(reference: Date())
        persist()
    }

    func setCountdownDurationMs(_ ms: Int) {
        countdownDurationMs = clampCountdownMs(ms)
        refreshDeskNotifications(reference: Date())
        persist()
    }

    func adjustStandingGoalMs(_ delta: Int) {
        standingGoalMs = clampStandingGoalMs(standingGoalMs + delta)
        persist()
        refreshStreakRetentionNotificationsIfNeeded(at: Date())
    }

    /// Cycles wellness fact index (persisted in session); `factCount` is typically `deskWellnessFacts.count`.
    func advanceFact(by delta: Int, factCount: Int) {
        guard factCount > 0 else { return }
        factIndex = ((factIndex + delta) % factCount + factCount) % factCount
        persist()
    }

    func completeCountdownSession() {
        guard sessionDisplayMode == .countdown else { return }
        if running {
            pauseAndPersist(at: Date())
        }
        sessionPausedMs = 0
        deskLiveActivityVisible = false
        persist()
    }

    func clearAllUserData() {
        if running {
            reconcile(at: Date())
        }

        ticker?.cancel()
        ticker = nil

        notificationScheduler.cancelAllDeskAlerts()
        notificationScheduler.cancelStreakReminders()

        dailyLogStore.deleteAllLogs()

        defaults.removeObject(forKey: SessionState.storageKey)
        defaults.removeObject(forKey: Self.notificationsPromptKey)
        defaults.removeObject(forKey: "desktimer:last-prune")

        standingConfettiAccumMs = 0
        sittingHourConfettiAccumMs = 0

        applySavedSnapshot(SessionState.default)
        persist()
    }

    func handleForeground() {
        if running {
            reconcile(at: Date())
            refreshDeskNotifications(reference: Date())
        }
        tickNow = Date()
        refreshStreakRetentionNotificationsIfNeeded(at: Date())
    }

    // MARK: - Reconcile

    private func reconcile(at now: Date) {
        tickNow = now

        guard running, let watermark = lastReconcileAt else {
            return
        }

        if watermark < now {
            let deltaMs = Int((now.timeIntervalSince(watermark) * 1000.0).rounded())
            if posture == .standing {
                feedStandingConfetti(deltaMs: deltaMs)
            } else if posture == .sitting {
                feedSittingHourConfetti(deltaMs: deltaMs)
            }
            dailyLogStore.addPostureDelta(from: watermark, to: now, posture: posture)
            addWeeklySittingMs(from: watermark, to: now)
            lastReconcileAt = now
        }

        if sessionDisplayMode == .countdown, countdownDurationMs > 0, computeSessionElapsed(at: now) >= countdownDurationMs {
            finalizeCountdownCompletion(at: now)
            return
        }

        maybeRescheduleStreakRetentionNotifications(at: now)
        persist()
    }

    private func beginPlayWithoutPrompt() {
        guard !running else { return }

        guard sessionDisplayMode != .countdown || countdownDurationMs > 0 else {
            persist()
            return
        }

        running = true
        let now = Date()
        runStartedAt = now
        lastReconcileAt = now
        tickNow = now

        startTickerIfNeeded()
        refreshDeskNotifications(reference: now)
        deskLiveActivityVisible = true
        persist()
    }

    private func pauseAndPersist(at anchor: Date) {
        guard running else { return }

        reconcile(at: anchor)

        ticker?.cancel()
        ticker = nil

        guard running else {
            persist()
            return
        }

        guard let segmentStart = runStartedAt else {
            running = false
            deskLiveActivityVisible = false
            notificationScheduler.cancelAllDeskAlerts()
            persist()
            return
        }

        let segmentMs = Int((anchor.timeIntervalSince(segmentStart) * 1000.0).rounded())
        sessionPausedMs += segmentMs
        running = false
        runStartedAt = nil
        deskLiveActivityVisible = false

        if sessionDisplayMode == .stopwatch, segmentMs >= Self.stopwatchPauseConfettiMinSegmentMs {
            // Long sitting segments already celebrate via `onSittingHourConfettiMilestone`; avoid a second burst on pause.
            if posture == .standing || segmentMs < SITTING_HOUR_MS {
                onStopwatchSegmentPauseCelebrate?()
            }
        }

        notificationScheduler.cancelAllDeskAlerts()
        persist()
    }

    private func finalizeCountdownCompletion(at now: Date) {
        ticker?.cancel()
        ticker = nil

        running = false
        runStartedAt = nil
        sessionPausedMs = 0
        deskLiveActivityVisible = false

        notificationScheduler.cancelAllDeskAlerts()

        tickNow = now

        onDeskCountdownComplete?()

        persist()
    }

    // MARK: - Ticker

    private func startTickerIfNeeded() {
        guard ticker == nil else { return }

        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                self.reconcile(at: date)
            }
    }

    // MARK: - Weekly sitting

    private func addWeeklySittingMs(from start: Date, to end: Date) {
        guard posture == .sitting, start < end else { return }

        var cursor = start
        while cursor < end {
            let sliceKey = calendarWeekKey(for: cursor)
            let boundary = exclusiveEndOfCalendarWeek(containing: cursor)
            let segmentEnd = min(boundary, end)

            if sliceKey != weekKey {
                weekKey = sliceKey
                weeklySittingMs = 0
            }

            weeklySittingMs += Int((segmentEnd.timeIntervalSince(cursor) * 1000.0).rounded())
            cursor = segmentEnd
        }
    }

    private func computeSessionElapsed(at reference: Date) -> Int {
        guard running, let segmentStart = runStartedAt else {
            return sessionPausedMs
        }
        let delta = reference.timeIntervalSince(segmentStart)
        return sessionPausedMs + Int((delta * 1000.0).rounded())
    }

    /// Elapsed desk-session ms at `reference` (running uses segment + pause; paused returns `sessionPausedMs`).
    func elapsedMs(at reference: Date) -> Int {
        computeSessionElapsed(at: reference)
    }

    // MARK: - Persistence

    private func currentSnapshot() -> SessionState {
        SessionState(
            posture: posture,
            running: running,
            sessionPausedMs: sessionPausedMs,
            runStartedAt: runStartedAt,
            weeklySittingMs: weeklySittingMs,
            weekKey: weekKey,
            factIndex: factIndex,
            sessionDisplayMode: sessionDisplayMode,
            countdownDurationMs: countdownDurationMs,
            standingGoalMs: standingGoalMs,
            deskLiveActivityVisible: deskLiveActivityVisible
        )
    }

    private func applySavedSnapshot(_ state: SessionState) {
        posture = state.posture
        running = state.running
        sessionPausedMs = state.sessionPausedMs
        runStartedAt = state.runStartedAt
        sessionDisplayMode = state.sessionDisplayMode
        countdownDurationMs = clampCountdownMs(state.countdownDurationMs)
        standingGoalMs = clampStandingGoalMs(state.standingGoalMs)
        factIndex = state.factIndex
        weeklySittingMs = state.weeklySittingMs
        weekKey = state.weekKey
        deskLiveActivityVisible = state.deskLiveActivityVisible
        if !running {
            deskLiveActivityVisible = false
        }
        standingConfettiAccumMs = 0
        sittingHourConfettiAccumMs = 0
        ticker?.cancel()
        ticker = nil
        lastReconcileAt = running ? state.runStartedAt ?? Date() : nil
        if running {
            startTickerIfNeeded()
        }
        tickNow = Date()
    }

    private func persist() {
        storage.save(currentSnapshot())
        liveActivityManager?.deskSessionStoreDidPersist(self)
    }

    private func refreshDeskNotifications(reference anchor: Date) {
        notificationScheduler.cancelAllDeskAlerts()

        guard running else { return }

        let hourNow = Calendar.current.component(.hour, from: anchor)

        if posture == .sitting {
            notificationScheduler.scheduleSittingHourAlerts(startedAt: anchor, currentHour: hourNow)
        }

        if sessionDisplayMode == .countdown, countdownDurationMs > 0 {
            let remainingMs = countdownDurationMs - computeSessionElapsed(at: anchor)
            guard remainingMs > 250 else {
                finalizeCountdownCompletion(at: anchor)
                return
            }

            let fireDate = anchor.addingTimeInterval(Double(remainingMs) / 1000)
            notificationScheduler.scheduleCountdownComplete(at: fireDate, posture: posture)
        }
    }

    private func feedStandingConfetti(deltaMs: Int) {
        guard deltaMs > 0 else { return }
        standingConfettiAccumMs += deltaMs
        while standingConfettiAccumMs >= STANDING_CONFETTI_INTERVAL_MS {
            standingConfettiAccumMs -= STANDING_CONFETTI_INTERVAL_MS
            onStandingConfettiMilestone?()
        }
    }

    private func feedSittingHourConfetti(deltaMs: Int) {
        guard deltaMs > 0 else { return }
        sittingHourConfettiAccumMs += deltaMs
        while sittingHourConfettiAccumMs >= SITTING_HOUR_MS {
            sittingHourConfettiAccumMs -= SITTING_HOUR_MS
            onSittingHourConfettiMilestone?()
        }
    }

    private func maybeRescheduleStreakRetentionNotifications(at now: Date) {
        guard posture == .standing, running else { return }
        if let last = lastStreakRetentionRescheduleAt, now.timeIntervalSince(last) < 45 {
            return
        }
        lastStreakRetentionRescheduleAt = now
        refreshStreakRetentionNotificationsIfNeeded(at: now)
    }

    private func refreshStreakRetentionNotificationsIfNeeded(at date: Date) {
        let todayStanding = dailyLogStore.todayLog(for: date).standingMs
        notificationScheduler.rescheduleStreakReminders(
            now: date,
            standingGoalMs: standingGoalMs,
            todayStandingMs: todayStanding
        )
    }
}
