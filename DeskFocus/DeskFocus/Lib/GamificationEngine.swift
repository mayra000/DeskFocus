//
//  GamificationEngine.swift
//  DeskFocus
//

import Foundation

// MARK: - Types

enum WorkweekBadgeKind: String, Codable {
    case future
    case complete
    case partial
    case missed
}

struct WorkweekBadgeDay: Identifiable {
    let labelShort: String
    let dayKey: String
    let kind: WorkweekBadgeKind
    /// Progress toward standing goal (`0 … 1`); used visually for `.partial`; `.complete` is `1`, `.missed` / `.future` use `0`.
    let ratio: Double

    var id: String { dayKey }
}

struct GamificationSnapshot {
    let standingGoalMs: Int
    let gamificationActiveToday: Bool
    let weeklyStandingWorkdaysMs: Int
    let workdayStandingStreak: Int
    let placeholderLevel: Int
    let workweekStandingBadges: [WorkweekBadgeDay]
}

// MARK: - Public API (pure — no persistence / timers / mutations)

func computeGamificationSnapshot(
    logs: [DailyPostureLog],
    standingGoalMs: Int,
    now: Date
) -> GamificationSnapshot {
    GamificationSnapshot(
        standingGoalMs: standingGoalMs,
        gamificationActiveToday: isWorkday(now),
        weeklyStandingWorkdaysMs: aggregateWeeklyStandingOnWorkdays(logs: logs, now: now),
        workdayStandingStreak: computeWorkdayStandingStreak(logs: logs, now: now, goalMs: standingGoalMs),
        placeholderLevel: 1,
        workweekStandingBadges: getWorkweekStandingBadges(now: now, logs: logs, goalMs: standingGoalMs)
    )
}

/// Mon–Fri tiles for the calendar week containing `now` (week starts Monday; anchors on `mondayOf(now)` offsets `0 … 4`).
func getWorkweekStandingBadges(now: Date, logs: [DailyPostureLog], goalMs: Int) -> [WorkweekBadgeDay] {
    let lookup = postureLogLookup(logs)
    let weekCalendar = Calendar(identifier: .iso8601)
    let anchorMonday = mondayOf(now)

    let labelShortMonFri = ["M", "T", "W", "TH", "F"]

    var badges: [WorkweekBadgeDay] = []

    for offset in 0 ..< 5 {
        guard let slotDate = weekCalendar.date(byAdding: .day, value: offset, to: anchorMonday) else {
            continue
        }

        let key = dayKey(for: slotDate)
        let standing = lookup[key]?.standingMs ?? 0
        let (kind, ratio) = classifyStandingBadge(day: slotDate, now: now, standingMs: standing, goalMs: goalMs)

        badges.append(
            WorkweekBadgeDay(
                labelShort: labelShortMonFri[offset],
                dayKey: key,
                kind: kind,
                ratio: ratio
            )
        )
    }

    return badges
}

func computeWorkdayStandingStreak(logs: [DailyPostureLog], now: Date, goalMs: Int) -> Int {
    let lookup = postureLogLookup(logs)
    let calendar = Calendar.current

    guard goalMs > 0 else {
        return 0
    }

    let todayStart = calendar.startOfDay(for: now)

    var streak = 0
    var offset = 0

    while offset < 400 {
        guard let probeDay = calendar.date(byAdding: .day, value: -offset, to: todayStart) else {
            break
        }

        defer { offset += 1 }

        if !isWorkday(probeDay) {
            continue
        }

        let standing = lookup[dayKey(for: probeDay)]?.standingMs ?? 0

        if standing >= goalMs {
            streak += 1
        } else {
            break
        }
    }

    return streak
}

// MARK: - Internals

private func postureLogLookup(_ logs: [DailyPostureLog]) -> [String: DailyPostureLog] {
    Dictionary(uniqueKeysWithValues: logs.map { ($0.dayKey, $0) })
}

private func aggregateWeeklyStandingOnWorkdays(logs: [DailyPostureLog], now: Date) -> Int {
    let weekCalendar = Calendar(identifier: .iso8601)
    let weekStart = mondayOf(now)
    let lookup = postureLogLookup(logs)

    var total = 0
    for offset in 0 ..< 7 {
        guard let day = weekCalendar.date(byAdding: .day, value: offset, to: weekStart) else {
            continue
        }
        if !isWorkday(day) {
            continue
        }
        total += lookup[dayKey(for: day)]?.standingMs ?? 0
    }
    return total
}

/// Badge classification for Mon–Fri week tiles (same rules for past / today / future).
private func classifyStandingBadge(
    day: Date,
    now: Date,
    standingMs: Int,
    goalMs: Int
) -> (WorkweekBadgeKind, Double) {
    let calendar = Calendar.current
    let probeStart = calendar.startOfDay(for: day)
    let todayStart = calendar.startOfDay(for: now)

    let ratio = standingRatio(standingMs: standingMs, goalMs: goalMs)

    switch calendar.compare(probeStart, to: todayStart, toGranularity: .day) {
    case .orderedDescending:
        return (.future, 0)

    case .orderedSame:
        if standingMs >= goalMs {
            return (.complete, 1)
        }
        return (.partial, ratio)

    case .orderedAscending:
        if standingMs >= goalMs {
            return (.complete, 1)
        }
        if standingMs == 0 {
            return (.missed, 0)
        }
        return (.partial, ratio)

    @unknown default:
        return (.future, 0)
    }
}

private func standingRatio(standingMs: Int, goalMs: Int) -> Double {
    guard goalMs > 0 else {
        return 0
    }
    return min(1.0, max(0.0, Double(standingMs) / Double(goalMs)))
}
