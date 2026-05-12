//
//  SessionState.swift
//  DeskFocus
//

import Foundation

struct SessionState: Codable {
    var posture: Posture
    var running: Bool
    var sessionPausedMs: Int
    var runStartedAt: Date?
    var weeklySittingMs: Int
    var weekKey: String
    var factIndex: Int
    var sessionDisplayMode: SessionDisplayMode
    /// Always a multiple of `5 * 60 * 1000` when set through app logic.
    var countdownDurationMs: Int
    /// Clamped in store/UI: 5 min–8 hr, multiple of 5 min.
    var standingGoalMs: Int

    static let storageKey = "desktimer:session"

    static let `default` = SessionState(
        posture: .sitting,
        running: false,
        sessionPausedMs: 0,
        runStartedAt: nil,
        weeklySittingMs: 0,
        weekKey: isoWeekKey(for: Date()),
        factIndex: 0,
        sessionDisplayMode: .stopwatch,
        countdownDurationMs: 30 * 60 * 1000,
        standingGoalMs: 60 * 60 * 1000
    )
}
