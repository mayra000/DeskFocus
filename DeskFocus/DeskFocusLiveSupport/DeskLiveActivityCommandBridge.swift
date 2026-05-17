//
//  DeskLiveActivityCommandBridge.swift
//  DeskFocusLiveSupport
//

import CoreFoundation
import Foundation

/// Posted on the **main app** main queue when a Live Activity control enqueues a command in the widget extension.
public extension Notification.Name {
    static let deskFocusLiveActivityIntentDidEnqueue = Notification.Name(
        "com.mayra.DeskFocus.liveActivityIntentDidEnqueue"
    )
}

private enum LiveActivityPendingIntentDarwin {
    /// Widget / Live Activity AppIntents run in the extension process. The main app often becomes active **before**
    /// `perform()` finishes writing the shared defaults key, so `dequeuePendingCommand()` sees nothing unless we also
    /// signal the host immediately after enqueue (Darwin notify).
    static let notificationName = "com.mayra.DeskFocus.liveActivity.pendingIntentCommand" as CFString

    static func postEnqueueSignal() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: notificationName),
            nil,
            nil,
            true
        )
    }
}

// MARK: - Desk

public enum DeskLiveActivityCommand: String, Sendable {
    case togglePauseResume
    case clearSession
}

public enum DeskLiveActivityCommandBridge {

    public static let appGroupIdentifier = "group.com.mayra.DeskFocus"

    private static let pendingCommandKey = "deskfocus.liveActivity.pendingCommand"

    private static var didInstallDarwinHostObserver = false

    public static func enqueue(_ command: DeskLiveActivityCommand) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.set(command.rawValue, forKey: pendingCommandKey)
        LiveActivityPendingIntentDarwin.postEnqueueSignal()
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

    /// Call once from the host app at launch (e.g. `UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:)`).
    public static func installHostDarwinNotifyObserverIfNeeded() {
        guard !didInstallDarwinHostObserver else { return }
        didInstallDarwinHostObserver = true

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(LiveActivityPendingIntentDarwinHostObserver.shared).toOpaque(),
            LiveActivityPendingIntentDarwinHostObserver.callback,
            LiveActivityPendingIntentDarwin.notificationName,
            nil,
            CFNotificationSuspensionBehavior.deliverImmediately
        )
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
        LiveActivityPendingIntentDarwin.postEnqueueSignal()
    }

    /// Returns and removes the next command, if any.
    public static func dequeuePendingCommand() -> PomodoroLiveActivityCommand? {
        guard let defaults = UserDefaults(suiteName: DeskLiveActivityCommandBridge.appGroupIdentifier) else { return nil }
        guard let raw = defaults.string(forKey: pendingCommandKey),
              let cmd = PomodoroLiveActivityCommand(rawValue: raw)
        else { return nil }
        defaults.removeObject(forKey: pendingCommandKey)
        return cmd
    }
}

// MARK: - Darwin host observer

private enum LiveActivityPendingIntentDarwinHostObserver {
    static let shared = ObserverBox()

    final class ObserverBox: @unchecked Sendable {
        fileprivate init() {}
    }

    static let callback: CFNotificationCallback = { _, observer, _, _, _ in
        guard observer != nil else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .deskFocusLiveActivityIntentDidEnqueue, object: nil)
        }
    }
}
