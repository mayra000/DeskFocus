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
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityIslandExpandedSummary(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "stopwatch")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
            } compactTrailing: {
                LiveActivityCompactTimer(state: context.state)
            } minimal: {
                Image(systemName: "stopwatch")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Lock screen

// Button column: two 44pt circles + 14pt gap = 102pt. Fixed at 110pt.
private let kButtonColumnWidth: CGFloat = 110
private let kTimerFontSize: CGFloat = 26

private struct DeskLiveActivityLockScreenView: View {
    let state: DeskSessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Top row: app name + posture badge
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "stopwatch")
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
                 + Text(statusPostureLabel)
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

            // Bottom row: fixed-width button column | timer takes the rest
            HStack(alignment: .center, spacing: 16) {

                // Left: pause + clear — hard fixed width, never grows
                HStack(alignment: .center, spacing: 14) {
                    Button(intent: PauseDeskSessionIntent()) {
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

                    Button(intent: ClearDeskSessionIntent()) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: kButtonColumnWidth, alignment: .leading)

                // Right: digits pinned to trailing edge; "TIMER" label sits
                // immediately to their left via a ZStack overlay — this way the
                // digits never move regardless of label width.
                ZStack(alignment: .trailing) {
                    LiveActivityLargeTimer(state: state)

                    HStack(alignment: .center, spacing: 0) {
                        Text(timerCaption)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .textCase(.uppercase)
                            .fixedSize()
                            .padding(.trailing, 4)  // gap between label and digits (smaller than before)

                        LiveActivityLargeTimer(state: state)
                            .hidden()               // reserve digit width, keep label positioned
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
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

    var liveActivityLogicalSessionStart: Date? {
        guard isRunning, let seg = segmentStartedAt else { return nil }
        return seg.addingTimeInterval(-TimeInterval(sessionPausedMs) / 1000)
    }

    func stopwatchTimerRange() -> ClosedRange<Date>? {
        guard displayModeRaw != "countdown" else { return nil }
        guard let logical = liveActivityLogicalSessionStart else { return nil }
        return logical ... Date.distantFuture
    }

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
        .font(.system(size: kTimerFontSize, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct LiveActivityCompactTimer: View {
    let state: DeskSessionActivityAttributes.ContentState

    var body: some View {
        // Avoid Text(timerInterval:) in compact — it often expands the island to full width.
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            Text(LiveActivityTimerFormatting.compactDisplayString(state: state, now: timeline.date))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// Single short line for expanded island; keeps regions from driving extra horizontal chrome.
private struct LiveActivityIslandExpandedSummary: View {
    let state: DeskSessionActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            HStack(spacing: 8) {
                Image(systemName: "stopwatch")
                    .font(.caption.weight(.semibold))
                Text(LiveActivityTimerFormatting.displayString(state: state, now: timeline.date))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private enum LiveActivityTimerFormatting {
    /// Shorter than lock-screen time (`mm:ss` or `h:mm:ss`) so the compact pill stays narrow.
    static func compactDisplayString(state: DeskSessionActivityAttributes.ContentState, now: Date) -> String {
        let displayMs: Int
        if state.displayModeRaw == "countdown" {
            let elapsed = elapsedMs(state: state, now: now)
            displayMs = max(0, state.countdownDurationMs - elapsed)
        } else {
            displayMs = max(0, elapsedMs(state: state, now: now))
        }
        let sec = displayMs / 1_000
        let h = sec / 3_600
        let m = (sec % 3_600) / 60
        let s = sec % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

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

// MARK: - Colors

private enum LiveActivityDeskTheme {
    static func cardBackground(for postureRaw: String) -> Color {
        postureRaw == "standing"
            ? Color(red: 38 / 255, green: 58 / 255, blue: 86 / 255)
            : Color(red: 40 / 255, green: 64 / 255, blue: 52 / 255)
    }
}