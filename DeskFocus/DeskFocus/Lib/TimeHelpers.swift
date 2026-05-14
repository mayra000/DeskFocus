//
//  TimeHelpers.swift
//  DeskFocus
//

import Foundation

let POMODORO_MS = 25 * 60 * 1000
let SHORT_BREAK_MS = 5 * 60 * 1000
let LONG_BREAK_MS = 15 * 60 * 1000

let COUNTDOWN_STEP_MS = 5 * 60 * 1000
let DEFAULT_COUNTDOWN_MS = 30 * 60 * 1000
let DEFAULT_STANDING_GOAL_MS = 60 * 60 * 1000
let STANDING_CONFETTI_INTERVAL_MS = 30 * 60 * 1000
/// Continuous sitting while the desk timer is running; confetti celebrates each full hour (sitting “hour” reminders).
let SITTING_HOUR_MS = 60 * 60 * 1000

private let standingMinMs = 5 * 60 * 1000
private let standingMaxMs = 8 * 60 * 60 * 1000
private let countdownMinMs = 1 * 60 * 1000
private let countdownMaxMs = 8 * 60 * 60 * 1000

/// Clamps to 5 min–8 hr and rounds to the nearest 5-minute step (then reclamped).
func clampStandingGoalMs(_ ms: Int) -> Int {
    let clamped = min(max(ms, standingMinMs), standingMaxMs)
    let stepped = Int((Double(clamped) / Double(COUNTDOWN_STEP_MS)).rounded()) * COUNTDOWN_STEP_MS
    return min(max(stepped, standingMinMs), standingMaxMs)
}

/// `0` is allowed (cleared countdown). Otherwise clamps to 1 min–8 hr and rounds to the nearest 5-minute step (then reclamped).
func clampCountdownMs(_ ms: Int) -> Int {
    guard ms > 0 else { return 0 }
    let clamped = min(max(ms, countdownMinMs), countdownMaxMs)
    let stepped = Int((Double(clamped) / Double(COUNTDOWN_STEP_MS)).rounded()) * COUNTDOWN_STEP_MS
    return min(max(stepped, countdownMinMs), countdownMaxMs)
}

/// Human-readable hours/minutes from millisecond totals (desk logs).
func formatDeskDuration(ms: Int) -> String {
    let totalMinutes = max(0, ms) / (60 * 1000)
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    if h > 0 {
        return "\(h) hr \(m) min"
    }
    return "\(m) min"
}

/// Compact goal string for desk UI (e.g. `1h 0m`).
func formatCompactStandingGoal(ms: Int) -> String {
    let totalMinutes = max(0, ms) / (60 * 1000)
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    return "\(h)h \(m)m"
}
