//
//  PomodoroStore.swift
//  DeskFocus
//

import Combine
import Foundation
import Observation
import SwiftData

@Observable @MainActor
final class PomodoroStore {

    static let activeTaskDefaultsKey = "pomodoro-active-task-id"

    var phase: PomodoroPhase = .pomodoro
    var remainingMs: Int = POMODORO_MS
    var running: Bool = false {
        didSet {
            if !running {
                lastTickAt = nil
            }
        }
    }

    var pomodorosCompleted: Int = 0
    var activeTaskId: String?

    /// Mirrors desk `deskLiveActivityVisible`: true after the user starts Pomodoro until reset or phase tab change.
    var pomodoroLiveActivityVisible = false

    weak var liveActivityManager: PomodoroLiveActivityManager?

    /// Called when `pomodoroLiveActivityVisible` toggles so the desk Live Activity can hide or resync immediately (desk may be paused with no ticker/persist).
    var onPomodoroLiveActivityEngagementChanged: (() -> Void)?

    var onPomodoroComplete: (() -> Void)?

    // MARK: - Computed presentation

    var focusSessionLabel: String? {
        guard phase == .pomodoro else { return nil }
        /// Next focus session index (completed count + 1).
        return "#\(max(1, pomodorosCompleted + 1))"
    }

    var startLabel: String {
        running ? "PAUSE" : "START"
    }

    var statusLine: String {
        switch phase {
        case .pomodoro:
            let m = remainingMs / 60_000
            let s = (remainingMs % 60_000) / 1_000
            return String(format: "Focus — %d:%02d left", m, s)
        case .shortBreak:
            return "Short break — step away from the screen."
        case .longBreak:
            return "Long break — unwind before the next focus round."
        }
    }

    // MARK: - Internals

    private let modelContext: ModelContext
    private let defaults: UserDefaults

    private var lastTickAt: Date?
    private var ticker: AnyCancellable?

    init(modelContext: ModelContext, defaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.defaults = defaults
        self.activeTaskId = defaults.string(forKey: Self.activeTaskDefaultsKey)
    }

    // MARK: - Actions

    func toggleRunning() {
        if running {
            pauseTimer()
            return
        }
        guard remainingMs > 0 else { return }
        startTimer()
    }

    /// Pause/resume from Live Activity controls (same semantics as in-app toggle).
    func applyLiveActivityToggle() {
        toggleRunning()
    }

    /// Full-duration reset for the current phase (paused); dismisses Live Activity.
    func applyLiveActivityReset() {
        let wasEngaged = pomodoroLiveActivityVisible
        pomodoroLiveActivityVisible = false
        pauseTimer()
        remainingMs = Self.duration(for: phase)
        if wasEngaged {
            onPomodoroLiveActivityEngagementChanged?()
        }
        syncLiveActivity()
    }

    func setPhase(_ next: PomodoroPhase) {
        let wasEngaged = pomodoroLiveActivityVisible
        pauseTimer()
        pomodoroLiveActivityVisible = false
        phase = next
        remainingMs = Self.duration(for: next)
        if wasEngaged {
            onPomodoroLiveActivityEngagementChanged?()
        }
        syncLiveActivity()
    }

    func addTask(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var descriptor = FetchDescriptor<PomodoroTask>(
            sortBy: [SortDescriptor(\.order, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        let topOrder = (try? modelContext.fetch(descriptor).first?.order) ?? -1

        modelContext.insert(PomodoroTask(title: trimmed, order: topOrder + 1))
        try? modelContext.save()
    }

    func toggleDone(id: String) {
        let rowId = id
        let predicate = #Predicate<PomodoroTask> { $0.id == rowId }
        let fetch = FetchDescriptor<PomodoroTask>(predicate: predicate)
        guard let task = try? modelContext.fetch(fetch).first else { return }
        task.done.toggle()
        try? modelContext.save()
    }

    func removeTask(id: String) {
        let rowId = id
        let predicate = #Predicate<PomodoroTask> { $0.id == rowId }
        let fetch = FetchDescriptor<PomodoroTask>(predicate: predicate)
        guard let task = try? modelContext.fetch(fetch).first else { return }
        modelContext.delete(task)
        if activeTaskId == id {
            selectTask(id: nil)
        }
        try? modelContext.save()
    }

    func selectTask(id: String?) {
        activeTaskId = id
        if let id {
            defaults.set(id, forKey: Self.activeTaskDefaultsKey)
        } else {
            defaults.removeObject(forKey: Self.activeTaskDefaultsKey)
        }
    }

    // MARK: - Timer

    func handleForeground() {
        reconcileTick(at: Date())
    }

    private func startTimer() {
        let becameEngaged = !pomodoroLiveActivityVisible
        running = true
        pomodoroLiveActivityVisible = true
        if becameEngaged {
            onPomodoroLiveActivityEngagementChanged?()
        }
        lastTickAt = Date()

        if ticker == nil {
            ticker = Timer.publish(every: 0.25, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] date in
                    guard let self else { return }
                    self.reconcileTick(at: date)
                }
        }
        syncLiveActivity()
    }

    private func pauseTimer() {
        ticker?.cancel()
        ticker = nil
        running = false
        syncLiveActivity()
    }

    private func syncLiveActivity() {
        liveActivityManager?.pomodoroStoreDidUpdate(self)
    }

    private func reconcileTick(at now: Date) {
        guard running, remainingMs > 0, let anchor = lastTickAt else {
            return
        }

        let deltaMs = Int((now.timeIntervalSince(anchor) * 1000.0).rounded())
        guard deltaMs > 0 else {
            lastTickAt = now
            return
        }

        let applied = min(remainingMs, deltaMs)
        remainingMs -= applied
        lastTickAt = now

        if remainingMs <= 0 {
            remainingMs = 0
            completeCurrentPhaseTransition()
            return
        }
        syncLiveActivity()
    }

    private func completeCurrentPhaseTransition() {
        pauseTimer()

        switch phase {
        case .pomodoro:
            onPomodoroComplete?()
            pomodorosCompleted += 1
            let nextPhase: PomodoroPhase =
                pomodorosCompleted % 4 == 0 ? .longBreak : .shortBreak
            phase = nextPhase
            remainingMs = Self.duration(for: nextPhase)

        case .shortBreak, .longBreak:
            phase = .pomodoro
            remainingMs = POMODORO_MS
        }
        syncLiveActivity()
    }

    private static func duration(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .pomodoro:
            return POMODORO_MS
        case .shortBreak:
            return SHORT_BREAK_MS
        case .longBreak:
            return LONG_BREAK_MS
        }
    }
}
