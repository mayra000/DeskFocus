//
//  DeskLiveActivityIntents.swift
//  DeskFocusLiveSupport
//

import AppIntents
import Foundation

public extension Notification.Name {
    static let deskFocusPauseFromLiveActivity = Notification.Name("DeskFocus.pauseFromLiveActivity")
    static let deskFocusClearFromLiveActivity = Notification.Name("DeskFocus.clearFromLiveActivity")
}

/// Posted on `NotificationCenter.default` while the app is launched to handle the action (`openAppWhenRun`).
public struct PauseDeskSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Pause"
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .deskFocusPauseFromLiveActivity, object: nil)
        return .result()
    }
}

/// Ends the desk session timer from the Live Activity (pause first if needed, then clear).
public struct ClearDeskSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Clear timer"
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .deskFocusClearFromLiveActivity, object: nil)
        return .result()
    }
}
