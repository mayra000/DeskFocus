//
//  DaySlice.swift
//  DeskFocus
//

import Foundation

/// Splits the half-open range `[from, to)` across **local** midnights.
/// - Parameters:
///   - body: `dayKey` (`YYYY-MM-DD`), that calendar day’s start (`Date`), slice length in milliseconds (≥ 1 when invoked).
func forEachDaySlice(from start: Date, to end: Date, body: (String, Date, Int) -> Void) {
    guard start < end else { return }

    let cal = Calendar.current
    var cursor = start

    while cursor < end {
        let dayStart = cal.startOfDay(for: cursor)
        guard let nextMidnight = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            break
        }
        let sliceEnd = min(nextMidnight, end)
        let ms = Int((sliceEnd.timeIntervalSince(cursor) * 1000.0).rounded())
        if ms > 0 {
            body(dayKey(for: cursor), dayStart, ms)
        }
        cursor = sliceEnd
    }
}
