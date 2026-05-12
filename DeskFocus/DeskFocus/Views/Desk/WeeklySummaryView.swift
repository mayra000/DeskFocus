//
//  WeeklySummaryView.swift
//  DeskFocus
//
//  Mirrors React WeeklySummary — ISO week stats, sitting vs standing aggregates, streak hints.
//

import SwiftData
import SwiftUI

struct WeeklySummaryView: View {
    @Environment(DeskSessionStore.self) private var deskStore

    @Query(sort: \DailyPostureLog.date, order: .reverse)
    private var postureLogs: [DailyPostureLog]

    private var snapshot: GamificationSnapshot {
        computeGamificationSnapshot(
            logs: postureLogs,
            standingGoalMs: deskStore.standingGoalMs,
            now: deskStore.tickNow
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week summary")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                summaryRow(title: "ISO week", value: deskStore.weekKey)
                summaryRow(title: "Sitting (this ISO week)", value: formatDeskDuration(ms: deskStore.weeklySittingMs))
                summaryRow(
                    title: "Standing on workdays",
                    value: formatDeskDuration(ms: snapshot.weeklyStandingWorkdaysMs)
                )
                summaryRow(title: "Standing goal", value: formatDeskDuration(ms: deskStore.standingGoalMs))
                summaryRow(title: "Workday streak", value: "\(snapshot.workdayStandingStreak) days")

                if snapshot.gamificationActiveToday {
                    Text("Today counts toward your workweek standing totals.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Weekends don’t affect your workday standing streak.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        }
        .accessibilityElement(children: .contain)
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyPostureLog.self, PomodoroTask.self, configurations: configuration)
    let store = DeskSessionStore(
        storage: LocalDeskStorage(),
        dailyLogStore: DailyLogStore(modelContext: container.mainContext)
    )
    return WeeklySummaryView()
        .modelContainer(container)
        .environment(store)
        .padding()
}
