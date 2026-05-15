//
//  DeskSessionLiveActivityManager.swift
//  DeskFocus
//

import ActivityKit
import DeskFocusLiveSupport
import Foundation

private actor DeskLiveActivityUpdateSerialGate {
    func update(_ activity: Activity<DeskSessionActivityAttributes>, state: DeskSessionActivityAttributes.ContentState) async {
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }
}

/// Owns the desk timer Live Activity: `Activity.request` runs only asynchronously after the scene is active.
@MainActor
final class DeskSessionLiveActivityManager {

    /// While Pomodoro has claimed Live Activity (`pomodoroLiveActivityVisible`), hide the desk activity so only one shows at a time (Pomodoro wins).
    var shouldSuppressDeskLiveActivity: (() -> Bool)?

    /// Called immediately before requesting a desk Live Activity — end Pomodoro activities and refresh the pomodoro manager’s references.
    var beforeRequestingDeskLiveActivity: (() async -> Void)?

    private var activity: Activity<DeskSessionActivityAttributes>?
    private var lastPushedState: DeskSessionActivityAttributes.ContentState?
    private var sceneIsActive = false
    private var startTask: Task<Void, Never>?
    /// Superseded starter tasks can overlap `Activity.request`; only the newest nonce wins.
    private var exclusiveStartNonce = 0
    private let updateGate = DeskLiveActivityUpdateSerialGate()

    func resetTrackedActivityAfterExternalTermination() {
        activity = nil
        lastPushedState = nil
    }

    func noteSceneBecameActive(syncing store: DeskSessionStore) {
        sceneIsActive = true
        scheduleResync(store: store)
    }

    func noteSceneBecameInactive() {
        sceneIsActive = false
        startTask?.cancel()
        startTask = nil
    }

    func deskSessionStoreDidPersist(_ store: DeskSessionStore) {
        scheduleResync(store: store)
    }

    private func scheduleResync(store: DeskSessionStore) {
        let state = contentState(from: store)
        let suppressed = shouldSuppressDeskLiveActivity?() ?? false
        let wantActivity = shouldKeepLiveActivityVisible(for: store) && !suppressed

        if !wantActivity {
            Task { await endActivityIfNeeded() }
            lastPushedState = nil
            return
        }

        guard state != lastPushedState else { return }

        if activity == nil {
            guard sceneIsActive else { return }
            enqueueStartIfNeeded(store: store, state: state)
        } else {
            Task { await pushUpdate(state: state) }
        }
    }

    /// Live Activity only while the desk timer is running (`deskLiveActivityVisible` is cleared on pause).
    private func shouldKeepLiveActivityVisible(for store: DeskSessionStore) -> Bool {
        store.deskLiveActivityVisible && store.running
    }

    private func enqueueStartIfNeeded(store: DeskSessionStore, state: DeskSessionActivityAttributes.ContentState) {
        exclusiveStartNonce += 1
        let nonce = exclusiveStartNonce
        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let self else { return }
            await Task.yield()
            await Task.yield()
            guard !Task.isCancelled, self.sceneIsActive else { return }
            guard nonce == self.exclusiveStartNonce else { return }
            let latest = self.contentState(from: store)
            guard self.shouldKeepLiveActivityVisible(for: store) else { return }
            guard !(self.shouldSuppressDeskLiveActivity?() ?? false) else { return }
            await self.startOrRefresh(with: latest, nonce: nonce)
        }
    }

    private func startOrRefresh(with state: DeskSessionActivityAttributes.ContentState, nonce: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let activity {
            await LiveActivityDuplicateTeardown.endDeskSessionActivities(except: activity)
            await updateGate.update(activity, state: state)
            lastPushedState = state
            return
        }

        guard nonce == exclusiveStartNonce else { return }

        await beforeRequestingDeskLiveActivity?()

        guard nonce == exclusiveStartNonce else { return }

        await LiveActivityDuplicateTeardown.endAllDeskSessionActivities()
        self.activity = nil

        guard nonce == exclusiveStartNonce else { return }

        do {
            let newActivity = try Activity.request(
                attributes: DeskSessionActivityAttributes(),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            guard nonce == exclusiveStartNonce else {
                await newActivity.end(nil, dismissalPolicy: .immediate)
                return
            }
            activity = newActivity
            lastPushedState = state
        } catch {
            activity = nil
        }
    }

    private func pushUpdate(state: DeskSessionActivityAttributes.ContentState) async {
        guard let activity else { return }
        await LiveActivityDuplicateTeardown.endDeskSessionActivities(except: activity)
        await updateGate.update(activity, state: state)
        lastPushedState = state
    }

    private func endActivityIfNeeded() async {
        startTask?.cancel()
        startTask = nil
        await LiveActivityDuplicateTeardown.endAllDeskSessionActivities()
        activity = nil
    }

    private func contentState(from store: DeskSessionStore) -> DeskSessionActivityAttributes.ContentState {
        let now = Date()
        let elapsed = store.elapsedMs(at: now)
        let isCountdown = store.sessionDisplayMode == .countdown
        let tickingWholeSeconds: Int
        if isCountdown {
            tickingWholeSeconds = max(0, store.countdownDurationMs - elapsed) / 1_000
        } else {
            tickingWholeSeconds = max(0, elapsed) / 1_000
        }
        let islandCompact = DeskLiveActivityTimerText.compact(
            elapsedMs: elapsed,
            isCountdown: isCountdown,
            countdownDurationMs: store.countdownDurationMs
        )
        let islandExpanded = DeskLiveActivityTimerText.full(
            elapsedMs: elapsed,
            isCountdown: isCountdown,
            countdownDurationMs: store.countdownDurationMs
        )
        return DeskSessionActivityAttributes.ContentState(
            postureRaw: store.posture.rawValue,
            displayModeRaw: store.sessionDisplayMode.rawValue,
            sessionPausedMs: store.sessionPausedMs,
            segmentStartedAt: store.runStartedAt,
            isRunning: store.running,
            countdownDurationMs: store.countdownDurationMs,
            tickingWholeSeconds: tickingWholeSeconds,
            islandCompactTime: islandCompact,
            islandExpandedTime: islandExpanded
        )
    }
}
