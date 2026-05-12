//
//  StandingWeekBadgesView.swift
//  DeskFocus
//
//  Mirrors React StandingWeekBadges / workweek standing goal badges (Mon–Fri).
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
        VStack(alignment: .leading, spacing: 8) {
            Text("This week")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(badges) { day in
                    badgeTile(day)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Standing goal progress Monday through Friday")
        }
    }

    @ViewBuilder
    private func badgeTile(_ day: WorkweekBadgeDay) -> some View {
        let side: CGFloat = 40
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tileBackground(for: day.kind))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tileStroke(for: day.kind), lineWidth: 1)

            if day.kind == .partial, deskStore.standingGoalMs > 0 {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: max(4, geo.size.width * day.ratio))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(2)
                }
            }

            Text(day.labelShort)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tileForeground(for: day.kind))
        }
        .frame(width: side, height: side)
        .accessibilityLabel(accessibilityLabel(for: day))
    }

    private func tileBackground(for kind: WorkweekBadgeKind) -> Color {
        switch kind {
        case .future:
            return Color(.secondarySystemFill)
        case .complete:
            return Color.green.opacity(0.35)
        case .partial:
            return Color(.tertiarySystemFill)
        case .missed:
            return Color.red.opacity(0.15)
        }
    }

    private func tileStroke(for kind: WorkweekBadgeKind) -> Color {
        switch kind {
        case .future:
            return Color.secondary.opacity(0.35)
        case .complete:
            return Color.green.opacity(0.7)
        case .partial:
            return Color.accentColor.opacity(0.45)
        case .missed:
            return Color.red.opacity(0.45)
        }
    }

    private func tileForeground(for kind: WorkweekBadgeKind) -> Color {
        switch kind {
        case .future:
            return .secondary
        case .complete:
            return .primary
        case .partial:
            return .primary
        case .missed:
            return .secondary
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
}
