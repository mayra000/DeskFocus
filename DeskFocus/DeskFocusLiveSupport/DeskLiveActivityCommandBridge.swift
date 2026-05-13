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
