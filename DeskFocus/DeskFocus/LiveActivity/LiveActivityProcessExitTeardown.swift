//
//  LiveActivityProcessExitTeardown.swift
//  DeskFocus
//

import DeskFocusLiveSupport
import UIKit

/// When the last `UIWindowScene` disconnects (force quit from the app switcher) or the app process is ending,
/// end Live Activities so the Dynamic Island / lock screen presentation does not outlive the app.
@MainActor
final class DeskFocusLiveActivityDisconnectHandler {
    static let shared = DeskFocusLiveActivityDisconnectHandler()

    private weak var deskManager: DeskSessionLiveActivityManager?
    private weak var pomodoroManager: PomodoroLiveActivityManager?

    private init() {}

    func register(desk: DeskSessionLiveActivityManager, pomodoro: PomodoroLiveActivityManager) {
        deskManager = desk
        pomodoroManager = pomodoro
    }

    func tearDownAllLiveActivitiesForProcessExit() async {
        await LiveActivityDuplicateTeardown.endAllDeskSessionActivities()
        await LiveActivityDuplicateTeardown.endAllPomodoroSessionActivities()
        deskManager?.resetTrackedActivityAfterExternalTermination()
        pomodoroManager?.resetTrackedActivityAfterExternalTermination()
    }
}

private extension UIApplication {
    /// Whether another window scene is still attached after `disconnected` is removed. Excludes the disconnecting
    /// scene by session id so we still tear down if it remains listed in `connectedScenes` briefly as `.background`.
    func deskFocus_hasOtherAttachedWindowScenes(excluding disconnected: UIScene?) -> Bool {
        let excludeId = disconnected?.session.persistentIdentifier
        return connectedScenes.contains { scene in
            guard scene is UIWindowScene else { return false }
            if let excludeId, scene.session.persistentIdentifier == excludeId { return false }
            switch scene.activationState {
            case .foregroundActive, .foregroundInactive, .background:
                return true
            case .unattached:
                return false
            @unknown default:
                return false
            }
        }
    }
}

final class DeskFocusAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSceneDidDisconnect),
            name: UIScene.didDisconnectNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        return true
    }

    @objc private func handleSceneDidDisconnect(_ notification: Notification) {
        let disconnected = notification.object as? UIScene
        // Defer so `connectedScenes` reflects teardown; exclude the disconnecting session so a stale `.background`
        // entry does not block Live Activity dismissal.
        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard !UIApplication.shared.deskFocus_hasOtherAttachedWindowScenes(excluding: disconnected) else {
                    return
                }
                scheduleLiveActivityProcessExitTeardown()
            }
        }
    }

    @objc private func handleWillTerminate(_ notification: Notification) {
        scheduleLiveActivityProcessExitTeardown()
    }

    private func scheduleLiveActivityProcessExitTeardown() {
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "com.deskfocus.end-live-activities") {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
        Task { @MainActor in
            await DeskFocusLiveActivityDisconnectHandler.shared.tearDownAllLiveActivitiesForProcessExit()
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
    }
}
