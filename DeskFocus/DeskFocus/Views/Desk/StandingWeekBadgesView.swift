//
//  StandingWeekBadgesView.swift
//  DeskFocus
//
//  Mon–Fri standing goal progress (week starts Monday).
//

import Foundation
import SwiftData
import SwiftUI

struct StandingWeekBadgesView: View {
    @Environment(DeskSessionStore.self) private var deskStore

    @Query(sort: \DailyPostureLog.date, order: .reverse)
    private var postureLogs: [DailyPostureLog]

    @State private var selectedDaySummary: WeekDaySummarySelection?

    private var badges: [WorkweekBadgeDay] {
        getWorkweekStandingBadges(
            now: deskStore.tickNow,
            logs: postureLogs,
            standingGoalMs: deskStore.standingGoalMs,
            standingGoalSnapshotsByDayKey: deskStore.standingGoalSnapshotsByDayKey
        )
    }

    private var logByDayKey: [String: DailyPostureLog] {
        Dictionary(uniqueKeysWithValues: postureLogs.map { ($0.dayKey, $0) })
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(badges) { day in
                Button {
                    let log = logByDayKey[day.dayKey]
                    let rawSit = log?.sittingMs ?? 0
                    let rawStand = log?.standingMs ?? 0
                    let net = deskStore.daySummaryDisplayedPostures(
                        dayKey: day.dayKey,
                        rawSittingMs: rawSit,
                        rawStandingMs: rawStand
                    )
                    selectedDaySummary = WeekDaySummarySelection(
                        dayKey: day.dayKey,
                        badgeKind: day.kind,
                        sittingMs: net.sitting,
                        standingMs: net.standing,
                        rawSittingMs: rawSit,
                        rawStandingMs: rawStand,
                        goalMs: day.goalMsApplied
                    )
                } label: {
                    badgeCell(day)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Show sitting and standing summary")
            }
        }
        .accessibilityElement(children: .contain)
        .sheet(item: $selectedDaySummary) { selection in
            WeekDayPostureSummarySheet(
                selection: selection,
                posture: deskStore.posture
            )
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
    }

    private func badgeCell(_ day: WorkweekBadgeDay) -> some View {
        let diameter: CGFloat = 32
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .strokeBorder(circleStroke(for: day.kind), lineWidth: circleLineWidth(for: day.kind))
                    .background(Circle().fill(circleFill(for: day.kind)))
                    .frame(width: diameter, height: diameter)

                if day.kind == .complete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DeskTheme.primary)
                        .accessibilityHidden(true)
                }

                if day.kind == .partial, day.goalMsApplied > 0 {
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

    private func circleLineWidth(for kind: WorkweekBadgeKind) -> CGFloat {
        switch kind {
        case .complete:
            return 3
        default:
            return 1.5
        }
    }

    private func circleStroke(for kind: WorkweekBadgeKind) -> Color {
        switch kind {
        case .future:
            return DeskTheme.border.opacity(0.65)
        case .complete:
            return DeskTheme.primary
        case .partial:
            return DeskTheme.border
        case .missed:
            return DeskTheme.muted.opacity(0.75)
        }
    }

    private func accessibilityLabel(for day: WorkweekBadgeDay) -> String {
        let goal = formatDeskDuration(ms: day.goalMsApplied)
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

// MARK: - Day tap summary

private struct WeekDaySummarySelection: Identifiable {
    var id: String { dayKey }
    let dayKey: String
    let badgeKind: WorkweekBadgeKind
    /// Sitting/standing times shown in the sheet (may omit time before the last desk-timer reset **today**).
    let sittingMs: Int
    let standingMs: Int
    /// Full-day SwiftData totals — used for goal copy so it stays aligned with workweek badges.
    let rawSittingMs: Int
    let rawStandingMs: Int
    let goalMs: Int
}

private struct WeekDayPostureSummarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let selection: WeekDaySummarySelection
    let posture: Posture

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(formattedDayHeader(selection.dayKey))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DeskTheme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                summaryLine(title: "Sitting", valueMs: selection.sittingMs)
                summaryLine(title: "Standing", valueMs: selection.standingMs)

                if let caption = goalCaption {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(DeskTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DeskTheme.screenBackground(for: posture))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DeskTheme.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func summaryLine(title: String, valueMs: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(DeskTheme.muted)
            Spacer(minLength: 16)
            Text(formatDeskDuration(ms: valueMs))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DeskTheme.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formattedDayHeader(_ dayKey: String) -> String {
        guard let date = date(fromGregorianDayKey: dayKey) else { return dayKey }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var goalCaption: String? {
        let standingForGoal = selection.rawStandingMs
        let goalMs = selection.goalMs
        switch selection.badgeKind {
        case .future:
            return "Time for this day will appear once the day starts."
        case .complete:
            if goalMs > 0 {
                return "Standing goal met (\(formatDeskDuration(ms: goalMs)))."
            }
            return nil
        case .partial:
            guard goalMs > 0 else { return nil }
            let remain = max(0, goalMs - standingForGoal)
            if remain > 0 {
                return "\(formatDeskDuration(ms: remain)) to go for your standing goal."
            }
            return nil
        case .missed:
            guard goalMs > 0 else { return nil }
            if standingForGoal == 0 {
                return "No standing time recorded for this day."
            }
            return "Below your standing goal for this day."
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
