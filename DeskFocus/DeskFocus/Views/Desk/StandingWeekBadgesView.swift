//
//  StandingWeekBadgesView.swift
//  DeskFocus
//
//  Mon–Fri standing goal progress (week starts Monday).
//

import SwiftData
import SwiftUI

struct StandingWeekBadgesView: View {
    @Environment(DeskSessionStore.self) private var deskStore

    @Query(sort: \DailyPostureLog.date, order: .reverse)
    private var postureLogs: [DailyPostureLog]

    private var badges: [WorkweekBadgeDay] {
        getWorkweekStandingBadges(
            now: deskStore.tickNow,
            logs: postureLogs,
            goalMs: deskStore.standingGoalMs
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(badges) { day in
                badgeCell(day)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Standing goal progress Monday through Friday")
    }

    private func badgeCell(_ day: WorkweekBadgeDay) -> some View {
        let diameter: CGFloat = 32
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .strokeBorder(circleStroke(for: day.kind), lineWidth: 1.5)
                    .background(Circle().fill(circleFill(for: day.kind)))
                    .frame(width: diameter, height: diameter)

                if day.kind == .partial, deskStore.standingGoalMs > 0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(day.ratio))
                        .stroke(DeskTheme.primary.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: diameter - 6, height: diameter - 6)
                }
            }

            Text(day.labelShort)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DeskTheme.primary.opacity(0.9))
        }
        .accessibilityLabel(accessibilityLabel(for: day))
    }

    private func circleFill(for kind: WorkweekBadgeKind) -> Color {
        switch kind {
        case .future:
            return Color.clear
        case .complete:
            return DeskTheme.primary.opacity(0.22)
        case .partial:
            return Color.clear
        case .missed:
            return DeskTheme.primary.opacity(0.06)
        }
    }

    private func circleStroke(for kind: WorkweekBadgeKind) -> Color {
        switch kind {
        case .future:
            return DeskTheme.border.opacity(0.65)
        case .complete:
            return DeskTheme.primary.opacity(0.9)
        case .partial:
            return DeskTheme.border
        case .missed:
            return DeskTheme.muted.opacity(0.75)
        }
    }

    private func accessibilityLabel(for day: WorkweekBadgeDay) -> String {
        let goal = formatDeskDuration(ms: deskStore.standingGoalMs)
        switch day.kind {
        case .future:
            return "\(day.labelShort), upcoming workday"
        case .complete:
            return "\(day.labelShort), standing goal met for \(goal)"
        case .partial:
            return "\(day.labelShort), \(Int(day.ratio * 100)) percent of standing goal \(goal)"
        case .missed:
            return "\(day.labelShort), standing goal not met"
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyPostureLog.self, PomodoroTask.self, configurations: configuration)
    let store = DeskSessionStore(
        storage: LocalDeskStorage(),
        dailyLogStore: DailyLogStore(modelContext: container.mainContext)
    )
    return StandingWeekBadgesView()
        .modelContainer(container)
        .environment(store)
        .padding()
        .background(DeskTheme.screenBackground(for: .standing))
}
