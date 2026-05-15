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
    /// Frozen goal snapshots by `dayKey(for:)`; **today’s** entry is overwritten on each save so past weekdays keep the goal they had while that day was current.
    var standingGoalSnapshotsByDayKey: [String: Int]
    /// True after the user starts a desk timer until explicit clear or countdown completion; keeps Live Activity during pause.
    var deskLiveActivityVisible: Bool
    /// Posture-split ms for the **current** desk session (cleared with timer reset / countdown end); persists across backgrounding.
    var deskSessionSittingMs: Int
    var deskSessionStandingMs: Int

    static let storageKey = "desktimer:session"

    static let `default` = SessionState(
        posture: .sitting,
        running: false,
        sessionPausedMs: 0,
        runStartedAt: nil,
        weeklySittingMs: 0,
        weekKey: calendarWeekKey(for: Date()),
        factIndex: 0,
        sessionDisplayMode: .stopwatch,
        countdownDurationMs: 30 * 60 * 1000,
        standingGoalMs: 60 * 60 * 1000,
        standingGoalSnapshotsByDayKey: [:],
        deskLiveActivityVisible: false,
        deskSessionSittingMs: 0,
        deskSessionStandingMs: 0
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
        case standingGoalSnapshotsByDayKey
        case deskLiveActivityVisible
        case deskSessionSittingMs
        case deskSessionStandingMs
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
        standingGoalSnapshotsByDayKey: [String: Int],
        deskLiveActivityVisible: Bool,
        deskSessionSittingMs: Int,
        deskSessionStandingMs: Int
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
        self.standingGoalSnapshotsByDayKey = standingGoalSnapshotsByDayKey
        self.deskLiveActivityVisible = deskLiveActivityVisible
        self.deskSessionSittingMs = deskSessionSittingMs
        self.deskSessionStandingMs = deskSessionStandingMs
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
        standingGoalSnapshotsByDayKey =
            try c.decodeIfPresent([String: Int].self, forKey: .standingGoalSnapshotsByDayKey) ?? [:]
        deskLiveActivityVisible = try c.decodeIfPresent(Bool.self, forKey: .deskLiveActivityVisible)
            ?? (running || sessionPausedMs > 0)
        deskSessionSittingMs = try c.decodeIfPresent(Int.self, forKey: .deskSessionSittingMs) ?? 0
        deskSessionStandingMs = try c.decodeIfPresent(Int.self, forKey: .deskSessionStandingMs) ?? 0
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
        try c.encode(standingGoalSnapshotsByDayKey, forKey: .standingGoalSnapshotsByDayKey)
        try c.encode(deskLiveActivityVisible, forKey: .deskLiveActivityVisible)
        try c.encode(deskSessionSittingMs, forKey: .deskSessionSittingMs)
        try c.encode(deskSessionStandingMs, forKey: .deskSessionStandingMs)
    }
}
