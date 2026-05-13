//
//  DeskFocusLiveActivityWidget.swift
//  DeskFocusLiveActivity
//

import ActivityKit
import AppIntents
import DeskFocusLiveSupport
import SwiftUI
import WidgetKit

struct DeskFocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeskSessionActivityAttributes.self) { context in
            DeskLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(LiveActivityDeskTheme.cardBackground(for: context.state.postureRaw))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                Image(systemName: "stopwatch")
                    .foregroundStyle(.white)
            } compactTrailing: {
                LiveActivityCompactTimer(state: context.state)
            } minimal: {
                Image(systemName: "stopwatch")
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Lock screen

private struct DeskLiveActivityLockScreenView: View {
    let state: DeskSessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "stopwatch")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("DESKFOCUS")
                    .font(.subheadline.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                Text("NOW: \(statusPostureLabel)")
                    .font(.caption.weight(.bold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
            }

            HStack(alignment: .center, spacing: 14) {
                Button(intent: PauseDeskSessionIntent()) {
                    Image(systemName: "pause.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                Button(intent: ClearDeskSessionIntent()) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                HStack(alignment: .center, spacing: 10) {
                    Text(timerCaption)
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .textCase(.uppercase)
                        .fixedSize(horizontal: true, vertical: false)

                    LiveActivityLargeTimer(state: state)
                }
            }
        }
        .padding(24)
    }

    private var statusPostureLabel: String {
        state.postureRaw == "standing" ? "STANDING" : "SITTING"
    }

    private var timerCaption: String {
        state.displayModeRaw == "countdown" ? "COUNTDOWN" : "TIMER"
    }
}

// MARK: - Timer rendering

private extension DeskSessionActivityAttributes.ContentState {

    /// Wall-clock instant where cumulative desk elapsed ms matches `sessionPausedMs` (stopwatch / countdown elapsed baseline).
    var liveActivityLogicalSessionStart: Date? {
        guard isRunning, let seg = segmentStartedAt else { return nil }
        return seg.addingTimeInterval(-TimeInterval(sessionPausedMs) / 1000)
    }

    /// Range for system-driven **count-up** timer (`countsDown: false`).
    func stopwatchTimerRange() -> ClosedRange<Date>? {
        guard displayModeRaw != "countdown" else { return nil }
        guard let logical = liveActivityLogicalSessionStart else { return nil }
        return logical ... Date.distantFuture
    }

    /// Range for system-driven **countdown** (`countsDown: true`).
    func countdownTimerRange() -> ClosedRange<Date>? {
        guard displayModeRaw == "countdown" else { return nil }
        guard let seg = segmentStartedAt, isRunning else { return nil }
        let spanSeconds = TimeInterval(max(0, countdownDurationMs - sessionPausedMs)) / 1000
        let end = seg.addingTimeInterval(spanSeconds)
        guard end > seg else { return nil }
        return seg ... end
    }
}

private struct LiveActivityLargeTimer: View {
    let state: DeskSessionActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.displayModeRaw == "countdown" {
                if let range = state.countdownTimerRange() {
                    Text(timerInterval: range, countsDown: true, showsHours: true)
                } else {
                    Text("00:00:00")
                }
            } else if let range = state.stopwatchTimerRange() {
                Text(timerInterval: range, countsDown: false, showsHours: true)
            } else {
                Text(LiveActivityTimerFormatting.displayString(state: state, now: Date()))
            }
        }
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
}

private struct LiveActivityCompactTimer: View {
    let state: DeskSessionActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.displayModeRaw == "countdown" {
                if let range = state.countdownTimerRange() {
                    Text(timerInterval: range, countsDown: true, showsHours: true)
                } else {
                    Text("00:00:00")
                }
            } else if let range = state.stopwatchTimerRange() {
                Text(timerInterval: range, countsDown: false, showsHours: true)
            } else {
                Text(LiveActivityTimerFormatting.displayString(state: state, now: Date()))
            }
        }
        .font(.caption2.weight(.bold))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
    }
}

private enum LiveActivityTimerFormatting {
    static func displayString(state: DeskSessionActivityAttributes.ContentState, now: Date) -> String {
        let elapsedMs = elapsedMs(state: state, now: now)
        let displayMs: Int
        if state.displayModeRaw == "countdown" {
            displayMs = max(0, state.countdownDurationMs - elapsedMs)
        } else {
            displayMs = max(0, elapsedMs)
        }

        let sec = displayMs / 1_000
        let h = sec / 3_600
        let m = (sec % 3_600) / 60
        let s = sec % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private static func elapsedMs(state: DeskSessionActivityAttributes.ContentState, now: Date) -> Int {
        guard state.isRunning, let start = state.segmentStartedAt else {
            return state.sessionPausedMs
        }
        return state.sessionPausedMs + Int((now.timeIntervalSince(start) * 1000.0).rounded())
    }
}

// MARK: - Colors (aligned with app `DeskTheme.mainCard`)

private enum LiveActivityDeskTheme {
    static func cardBackground(for postureRaw: String) -> Color {
        postureRaw == "standing"
            ? Color(red: 38 / 255, green: 58 / 255, blue: 86 / 255)
            : Color(red: 40 / 255, green: 64 / 255, blue: 52 / 255)
    }
}
