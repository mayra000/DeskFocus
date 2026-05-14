//
//  DeskLiveActivityTimerText.swift
//  DeskFocusLiveSupport
//

import Foundation

public enum DeskLiveActivityTimerText {

    /// Compact island (`mm:ss` or short `h:mm:ss`).
    public static func compact(
        elapsedMs: Int,
        isCountdown: Bool,
        countdownDurationMs: Int
    ) -> String {
        let ms = displayMs(elapsedMs: elapsedMs, isCountdown: isCountdown, countdownDurationMs: countdownDurationMs)
        return formatCompact(ms: ms)
    }

    /// Lock-screen island row (`hh:mm:ss`).
    public static func full(
        elapsedMs: Int,
        isCountdown: Bool,
        countdownDurationMs: Int
    ) -> String {
        let ms = displayMs(elapsedMs: elapsedMs, isCountdown: isCountdown, countdownDurationMs: countdownDurationMs)
        return formatFull(ms: ms)
    }

    private static func displayMs(elapsedMs: Int, isCountdown: Bool, countdownDurationMs: Int) -> Int {
        let e = max(0, elapsedMs)
        if isCountdown {
            return max(0, countdownDurationMs - e)
        }
        return e
    }

    private static func formatCompact(ms: Int) -> String {
        let sec = max(0, ms) / 1_000
        let h = sec / 3_600
        let m = (sec % 3_600) / 60
        let s = sec % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private static func formatFull(ms: Int) -> String {
        let sec = max(0, ms) / 1_000
        let h = sec / 3_600
        let m = (sec % 3_600) / 60
        let s = sec % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
