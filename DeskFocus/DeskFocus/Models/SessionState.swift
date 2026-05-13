//
//  SessionState.swift
//  DeskFocus
//

import Foundation

struct SessionState: Codable, Equatable {
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
    /// True after the user starts a desk timer until explicit clear or countdown completion; keeps Live Activity during pause.
    var deskLiveActivityVisible: Bool

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
        standingGoalMs: 60 * 60 * 1000,
        deskLiveActivityVisible: false
    )

    enum CodingKeys: String, CodingKey {
        case posture
        case running
        case sessionPausedMs
        case runStartedAt
        case weeklySittingMs
        case weekKey
        case factIndex
        case sessionDisplayMode
        case countdownDurationMs
        case standingGoalMs
        case deskLiveActivityVisible
    }

    init(
        posture: Posture,
        running: Bool,
        sessionPausedMs: Int,
        runStartedAt: Date?,
        weeklySittingMs: Int,
        weekKey: String,
        factIndex: Int,
        sessionDisplayMode: SessionDisplayMode,
        countdownDurationMs: Int,
        standingGoalMs: Int,
        deskLiveActivityVisible: Bool
    ) {
        self.posture = posture
        self.running = running
        self.sessionPausedMs = sessionPausedMs
        self.runStartedAt = runStartedAt
        self.weeklySittingMs = weeklySittingMs
        self.weekKey = weekKey
        self.factIndex = factIndex
        self.sessionDisplayMode = sessionDisplayMode
        self.countdownDurationMs = countdownDurationMs
        self.standingGoalMs = standingGoalMs
        self.deskLiveActivityVisible = deskLiveActivityVisible
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        posture = try c.decode(Posture.self, forKey: .posture)
        running = try c.decode(Bool.self, forKey: .running)
        sessionPausedMs = try c.decode(Int.self, forKey: .sessionPausedMs)
        runStartedAt = try c.decodeIfPresent(Date.self, forKey: .runStartedAt)
        weeklySittingMs = try c.decode(Int.self, forKey: .weeklySittingMs)
        weekKey = try c.decode(String.self, forKey: .weekKey)
        factIndex = try c.decode(Int.self, forKey: .factIndex)
        sessionDisplayMode = try c.decode(SessionDisplayMode.self, forKey: .sessionDisplayMode)
        countdownDurationMs = try c.decode(Int.self, forKey: .countdownDurationMs)
        standingGoalMs = try c.decode(Int.self, forKey: .standingGoalMs)
        deskLiveActivityVisible = try c.decodeIfPresent(Bool.self, forKey: .deskLiveActivityVisible)
            ?? (running || sessionPausedMs > 0)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(posture, forKey: .posture)
        try c.encode(running, forKey: .running)
        try c.encode(sessionPausedMs, forKey: .sessionPausedMs)
        try c.encodeIfPresent(runStartedAt, forKey: .runStartedAt)
        try c.encode(weeklySittingMs, forKey: .weeklySittingMs)
        try c.encode(weekKey, forKey: .weekKey)
        try c.encode(factIndex, forKey: .factIndex)
        try c.encode(sessionDisplayMode, forKey: .sessionDisplayMode)
        try c.encode(countdownDurationMs, forKey: .countdownDurationMs)
        try c.encode(standingGoalMs, forKey: .standingGoalMs)
        try c.encode(deskLiveActivityVisible, forKey: .deskLiveActivityVisible)
    }
}
