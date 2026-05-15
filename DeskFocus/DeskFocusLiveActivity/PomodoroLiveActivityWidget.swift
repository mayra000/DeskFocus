//
//  PomodoroLiveActivityWidget.swift
//  DeskFocusLiveActivity
//

import ActivityKit
import AppIntents
import DeskFocusLiveSupport
import SwiftUI
import WidgetKit

struct PomodoroLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroSessionActivityAttributes.self) { context in
            PomodoroLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(LiveActivityPomodoroTheme.cardBackground(for: context.state.phaseRaw))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    PomodoroIslandExpandedSummary(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
            } compactTrailing: {
                PomodoroCompactTimer(state: context.state)
            }             minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .disfavoredLocations([.carPlay], for: [.systemSmall])
        .disfavoredLocations([.carPlay], for: [.accessoryInline, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Lock screen

private let pomodoroButtonColumnWidth: CGFloat = 110
private let pomodoroTimerFontSize: CGFloat = 26

private struct PomodoroLiveActivityLockScreenView: View {
    let state: PomodoroSessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("DESKFOCUS")
                        .font(.subheadline.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 8)
                (Text("NOW: ")
                    .foregroundStyle(Color.white.opacity(0.58))
                 + Text(phaseBadgeUppercase)
                    .foregroundStyle(Color.white))
                    .font(.caption.weight(.bold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color.white.opacity(0.14)))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 16) {

                HStack(alignment: .center, spacing: 14) {
                    Button(intent: TogglePomodoroSessionIntent()) {
                        Image(systemName: state.isRunning ? "pause.fill" : "play.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(intent: ResetPomodoroSessionIntent()) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: pomodoroButtonColumnWidth, alignment: .leading)

                ZStack(alignment: .trailing) {
                    PomodoroLargeTimer(state: state)

                    HStack(alignment: .center, spacing: 0) {
                        Text(timerCaption)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .textCase(.uppercase)
                            .fixedSize()
                            .padding(.trailing, 4)

                        PomodoroLargeTimer(state: state)
                            .hidden()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
        }
        .padding(24)
    }

    private var phaseBadgeUppercase: String {
        switch state.phaseRaw {
        case "pomodoro": return "FOCUS"
        case "shortBreak": return "SHORT BREAK"
        case "longBreak": return "LONG BREAK"
        default: return state.phaseRaw.uppercased()
        }
    }

    private var timerCaption: String {
        state.phaseRaw == "pomodoro" ? "FOCUS" : "BREAK"
    }
}

// MARK: - Timer rendering

private extension PomodoroSessionActivityAttributes.ContentState {

    func countdownRange() -> ClosedRange<Date>? {
        guard isRunning,
              let start = countdownStartAt,
              let end = countdownEndsAt,
              end > start
        else { return nil }
        return start ... end
    }
}

private struct PomodoroLargeTimer: View {
    let state: PomodoroSessionActivityAttributes.ContentState

    var body: some View {
        Group {
            if let range = state.countdownRange() {
                Text(timerInterval: range, countsDown: true, showsHours: true)
            } else {
                Text(PomodoroLiveTimerFormatting.displayString(remainingMs: state.remainingMs))
            }
        }
        .font(.system(size: pomodoroTimerFontSize, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct PomodoroCompactTimer: View {
    let state: PomodoroSessionActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            Text(PomodoroLiveTimerFormatting.compactString(state: state, now: timeline.date))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct PomodoroIslandExpandedSummary: View {
    let state: PomodoroSessionActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.caption.weight(.semibold))
                Text(PomodoroLiveTimerFormatting.displayString(state: state, now: timeline.date))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private enum PomodoroLiveTimerFormatting {

    static func compactString(state: PomodoroSessionActivityAttributes.ContentState, now: Date) -> String {
        let ms = displayRemainingMs(state: state, now: now)
        return formatMsCompact(ms)
    }

    static func displayString(state: PomodoroSessionActivityAttributes.ContentState, now: Date) -> String {
        formatMsFull(displayRemainingMs(state: state, now: now))
    }

    static func displayString(remainingMs: Int) -> String {
        formatMsFull(max(0, remainingMs))
    }

    private static func displayRemainingMs(state: PomodoroSessionActivityAttributes.ContentState, now: Date) -> Int {
        guard state.isRunning, let end = state.countdownEndsAt, end > now else {
            return max(0, state.remainingMs)
        }
        return max(0, Int((end.timeIntervalSince(now) * 1000.0).rounded()))
    }

    private static func formatMsCompact(_ ms: Int) -> String {
        let sec = max(0, ms) / 1_000
        let h = sec / 3_600
        let m = (sec % 3_600) / 60
        let s = sec % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private static func formatMsFull(_ ms: Int) -> String {
        let sec = max(0, ms) / 1_000
        let h = sec / 3_600
        let m = (sec % 3_600) / 60
        let s = sec % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Colors (aligned with in-app `PomodoroTheme`)

private enum LiveActivityPomodoroTheme {
    static func cardBackground(for phaseRaw: String) -> Color {
        switch phaseRaw {
        case "pomodoro":
            return Color(red: 168 / 255, green: 98 / 255, blue: 92 / 255)
        case "shortBreak":
            return Color(red: 74 / 255, green: 118 / 255, blue: 114 / 255)
        case "longBreak":
            return Color(red: 91 / 255, green: 135 / 255, blue: 169 / 255)
        default:
            return Color(red: 142 / 255, green: 72 / 255, blue: 68 / 255)
        }
    }
}
