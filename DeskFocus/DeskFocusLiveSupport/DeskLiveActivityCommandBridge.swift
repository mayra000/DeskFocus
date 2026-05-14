//
//  DeskLiveActivityCommandBridge.swift
//  DeskFocusLiveSupport
//

import Foundation

public enum DeskLiveActivityCommand: String, Sendable {
    case togglePauseResume
    case clearSession
}

public enum DeskLiveActivityCommandBridge {

    public static let appGroupIdentifier = "group.com.mayra.DeskFocus"

    private static let pendingCommandKey = "deskfocus.liveActivity.pendingCommand"

    public static func enqueue(_ command: DeskLiveActivityCommand) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.set(command.rawValue, forKey: pendingCommandKey)
    }

    /// Returns and removes the next command, if any.
    public static func dequeuePendingCommand() -> DeskLiveActivityCommand? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return nil }
        guard let raw = defaults.string(forKey: pendingCommandKey),
              let cmd = DeskLiveActivityCommand(rawValue: raw)
        else { return nil }
        defaults.removeObject(forKey: pendingCommandKey)
        return cmd
    }
}

// MARK: - Pomodoro

public enum PomodoroLiveActivityCommand: String, Sendable {
    case togglePauseResume
    case resetTimer
}

public enum PomodoroLiveActivityCommandBridge {

    private static let pendingCommandKey = "deskfocus.liveActivity.pendingPomodoroCommand"

    public static func enqueue(_ command: PomodoroLiveActivityCommand) {
        guard let defaults = UserDefaults(suiteName: DeskLiveActivityCommandBridge.appGroupIdentifier) else { return }
        defaults.set(command.rawValue, forKey: pendingCommandKey)
    }

    public static func dequeuePendingCommand() -> PomodoroLiveActivityCommand? {
        guard let defaults = UserDefaults(suiteName: DeskLiveActivityCommandBridge.appGroupIdentifier) else { return nil }
        guard let raw = defaults.string(forKey: pendingCommandKey),
              let cmd = PomodoroLiveActivityCommand(rawValue: raw)
        else { return nil }
        defaults.removeObject(forKey: pendingCommandKey)
        return cmd
    }
}
