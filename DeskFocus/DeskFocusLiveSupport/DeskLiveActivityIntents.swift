//
//  DeskLiveActivityIntents.swift
//  DeskFocusLiveSupport
//

import AppIntents
import Foundation

/// Pause/resume desk timer; state is applied in the main app via `DeskLiveActivityCommandBridge`.
public struct PauseDeskSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Pause or resume"
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        DeskLiveActivityCommandBridge.enqueue(.togglePauseResume)
        return .result()
    }
}

/// Clears the desk session and dismisses the Live Activity (handled in the main app).
public struct ClearDeskSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Clear timer"
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        DeskLiveActivityCommandBridge.enqueue(.clearSession)
        return .result()
    }
}
