//
//  ActivityLogView.swift
//  DeskFocus
//
//  Mirrors React ActivityLog — recent daily posture totals from SwiftData.
//

import SwiftData
import SwiftUI

struct ActivityLogView: View {
    @Environment(DeskSessionStore.self) private var deskStore

    @Query(sort: \DailyPostureLog.date, order: .reverse)
    private var allLogs: [DailyPostureLog]

    private static let visibleDays = 14

    private var rows: [DailyPostureLog] {
        let cal = Calendar.current
        let anchor = deskStore.tickNow
        guard let cutoff = cal.date(byAdding: .day, value: -Self.visibleDays, to: cal.startOfDay(for: anchor)) else {
            return []
        }
        return allLogs.filter { $0.date >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent activity")
                .font(.headline)

            if rows.isEmpty {
                ContentUnavailableView(
                    "No entries yet",
                    systemImage: "calendar.badge.clock",
                    description: Text("Desk time you track will show up here by day.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { log in
                        logRow(log)
                        Divider()
                            .padding(.leading, 4)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func logRow(_ log: DailyPostureLog) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Text(log.dayKey)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Label(formatDeskDuration(ms: log.sittingMs), systemImage: "figure.seated.side")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(formatDeskDuration(ms: log.standingMs), systemImage: "figure.stand")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .labelStyle(.titleOnly)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(log.dayKey), sitting \(formatDeskDuration(ms: log.sittingMs)), standing \(formatDeskDuration(ms: log.standingMs))")
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyPostureLog.self, PomodoroTask.self, configurations: configuration)
    let ctx = container.mainContext
    ctx.insert(DailyPostureLog(dayKey: dayKey(for: Date()), date: Calendar.current.startOfDay(for: Date()), sittingMs: 3_600_000, standingMs: 1_800_000))
    let store = DeskSessionStore(
        storage: LocalDeskStorage(),
        dailyLogStore: DailyLogStore(modelContext: ctx)
    )
    return ActivityLogView()
        .modelContainer(container)
        .environment(store)
        .padding()
}
