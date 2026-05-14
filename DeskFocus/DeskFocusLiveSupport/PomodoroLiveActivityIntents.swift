//
//  PomodoroLiveActivityIntents.swift
//  DeskFocusLiveSupport
//

import AppIntents
import Foundation

/// Pause/resume Pomodoro; handled in the main app via `PomodoroLiveActivityCommandBridge`.
public struct TogglePomodoroSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Pause or resume Pomodoro"
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        PomodoroLiveActivityCommandBridge.enqueue(.togglePauseResume)
        return .result()
    }
}

/// Resets the current phase to its full duration (paused) and dismisses the Live Activity.
public struct ResetPomodoroSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Reset Pomodoro timer"
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        PomodoroLiveActivityCommandBridge.enqueue(.resetTimer)
        return .result()
    }
}
