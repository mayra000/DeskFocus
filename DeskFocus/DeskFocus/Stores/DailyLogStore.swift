//
//  DailyLogStore.swift
//  DeskFocus
//

import Foundation
import SwiftData

@MainActor
final class DailyLogStore {

    struct WeekDayRow: Identifiable {
        var id: String { dayKey }
        let dayKey: String
        let weekdayShort: String
        let dayLabel: String
        let sittingMs: Int
        let standingMs: Int
    }

    private static let defaultKeepDays = 120
    private static let lastPruneDefaultsKey = "desktimer:last-prune"

    private let modelContext: ModelContext
    private let defaults: UserDefaults

    private let isoCalendar = Calendar(identifier: .iso8601)

    init(modelContext: ModelContext, userDefaults: UserDefaults = .standard) {
        self.modelContext = modelContext
        self.defaults = userDefaults
        performPrune(keepDays: Self.defaultKeepDays, relativeTo: Date())
        defaults.set(Date().timeIntervalSince1970, forKey: Self.lastPruneDefaultsKey)
    }

    func addPostureDelta(from start: Date, to end: Date, posture: Posture) {
        pruneIfCalendarDayPassed(relativeTo: end)
        forEachDaySlice(from: start, to: end) { rowKey, dayStart, sliceMs in
            applyDelta(dayKey: rowKey, date: dayStart, ms: sliceMs, posture: posture)
        }
        try? modelContext.save()
    }

    func pruneOldEntries(keepDays: Int = 120) {
        performPrune(keepDays: keepDays, relativeTo: Date())
    }

    func weekDayRows(for now: Date) -> [WeekDayRow] {
        pruneIfCalendarDayPassed(relativeTo: now)
        let monday = mondayOf(now)
        var rows: [WeekDayRow] = []
        for offset in 0..<7 {
            guard let dayDate = isoCalendar.date(byAdding: .day, value: offset, to: monday) else {
                continue
            }
            rows.append(makeWeekDayRow(for: dayDate))
        }
        return rows
    }

    func todayLog(for now: Date) -> WeekDayRow {
        pruneIfCalendarDayPassed(relativeTo: now)
        let dayStart = Calendar.current.startOfDay(for: now)
        return makeWeekDayRow(for: dayStart)
    }

    // MARK: - Pruning

    private func pruneIfCalendarDayPassed(relativeTo now: Date) {
        let calendar = Calendar.current
        let lastInterval = defaults.object(forKey: Self.lastPruneDefaultsKey) as? Double
        let lastRun = lastInterval.map(Date.init(timeIntervalSince1970:))
        let shouldPrune: Bool = if let previous = lastRun {
            !calendar.isDate(previous, inSameDayAs: now)
        } else {
            true
        }
        guard shouldPrune else { return }
        performPrune(keepDays: Self.defaultKeepDays, relativeTo: now)
        defaults.set(now.timeIntervalSince1970, forKey: Self.lastPruneDefaultsKey)
    }

    private func performPrune(keepDays: Int, relativeTo reference: Date) {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -keepDays, to: reference) else {
            return
        }
        let cutoff = Calendar.current.startOfDay(for: cutoffDate)

        guard let olds = try? modelContext.fetch(
            FetchDescriptor<DailyPostureLog>(
                predicate: #Predicate<DailyPostureLog> { log in
                    log.date < cutoff
                }
            )
        ) else {
            return
        }
        for row in olds {
            modelContext.delete(row)
        }
        try? modelContext.save()
    }

    // MARK: - Rows

    private func makeWeekDayRow(for anchorDate: Date) -> WeekDayRow {
        let key = dayKey(for: anchorDate)
        let fetched = fetchLog(dayKey: key)
        let sitting = fetched?.sittingMs ?? 0
        let standing = fetched?.standingMs ?? 0
        let weekdayFormatted = anchorDate.formatted(.dateTime.weekday(.abbreviated))
        let dayFormatted = anchorDate.formatted(.dateTime.month(.abbreviated).day())

        return WeekDayRow(
            dayKey: key,
            weekdayShort: weekdayFormatted,
            dayLabel: dayFormatted,
            sittingMs: sitting,
            standingMs: standing
        )
    }

    private func fetchLog(dayKey rowKey: String) -> DailyPostureLog? {
        let predicate = #Predicate<DailyPostureLog> { log in
            log.dayKey == rowKey
        }
        var descriptor = FetchDescriptor<DailyPostureLog>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func deleteAllLogs() {
        guard let logs = try? modelContext.fetch(FetchDescriptor<DailyPostureLog>()) else { return }
        for row in logs {
            modelContext.delete(row)
        }
        try? modelContext.save()
    }

    private func applyDelta(dayKey rowKey: String, date dayStart: Date, ms sliceMs: Int, posture: Posture) {
        if let existing = fetchLog(dayKey: rowKey) {
            switch posture {
            case .sitting:
                existing.sittingMs += sliceMs
            case .standing:
                existing.standingMs += sliceMs
            }
        } else {
            let sittingMs = posture == .sitting ? sliceMs : 0
            let standingMs = posture == .standing ? sliceMs : 0
            modelContext.insert(
                DailyPostureLog(dayKey: rowKey, date: dayStart, sittingMs: sittingMs, standingMs: standingMs)
            )
        }
    }
}
