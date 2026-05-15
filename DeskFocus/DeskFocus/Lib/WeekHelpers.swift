//
//  WeekHelpers.swift
//  DeskFocus
//

import Foundation

/// Gregorian `YYYY-MM-DD` in the **current** timezone (fixed format, not localized).
func dayKey(for date: Date) -> String {
    let cal = Calendar.current
    let y = cal.component(.year, from: date)
    let m = cal.component(.month, from: date)
    let d = cal.component(.day, from: date)
    return String(format: "%04d-%02d-%02d", y, m, d)
}

/// Parses `dayKey(for:)`-style Gregorian strings in the user's current timezone.
func date(fromGregorianDayKey key: String) -> Date? {
    let parts = key.split(separator: "-")
    guard parts.count == 3,
          let y = Int(parts[0]),
          let m = Int(parts[1]),
          let d = Int(parts[2]) else { return nil }
    var components = DateComponents()
    components.year = y
    components.month = m
    components.day = d
    return Calendar.current.date(from: components)
}

/// Start of the calendar week (Monday 00:00) containing `date`, using `Calendar(identifier: .iso8601)` (Monday-first weeks).
func mondayOf(_ date: Date) -> Date {
    let cal = Calendar(identifier: .iso8601)
    guard let interval = cal.dateInterval(of: .weekOfYear, for: date) else {
        return date
    }
    return interval.start
}

/// Week label aligned with persisted `SessionState.weekKey`, e.g. `2026-W19` (year and week number).
func calendarWeekKey(for date: Date) -> String {
    let cal = Calendar(identifier: .iso8601)
    let year = cal.component(.yearForWeekOfYear, from: date)
    let week = cal.component(.weekOfYear, from: date)
    return "\(year)-W\(String(format: "%02d", week))"
}

/// Exclusive end (`next Monday`) of the calendar week containing `date`.
func exclusiveEndOfCalendarWeek(containing date: Date) -> Date {
    let cal = Calendar(identifier: .iso8601)
    guard let exclusiveEnd = cal.date(byAdding: .day, value: 7, to: mondayOf(date)) else {
        return date.addingTimeInterval(7 * 24 * 3600)
    }
    return exclusiveEnd
}

/// Monday through Friday only, using the user's **current** calendar.
func isWorkday(_ date: Date) -> Bool {
    let weekday = Calendar.current.component(.weekday, from: date)
    switch weekday {
    case 2 ... 6: return true // Mon … Fri (`weekday`: Sun = 1)
    default: return false
    }
}
