//
//  DeskFocusApp.swift
//  DeskFocus
//
//  Created by Mayra Sanchez on 5/12/26.
//

import DeskFocusLiveSupport
import SwiftData
import SwiftUI
import UIKit

@MainActor
private func scheduleConfettiBurst(driver: ConfettiBurstDriver, palette: ConfettiPalette) {
    Task { @MainActor in
        // Two yields: bootstrap + `ConfettiView` host attach often land on the next frame(s).
        await Task.yield()
        await Task.yield()
        driver.fire(palette)
    }
}

/// SwiftData bundle at an explicit Application Support URL so a damaged default Core Data/WAL file
/// cannot deadlock launch compared to the default hashed store location.
private enum DeskFocusModelContainerFactory {

    static func makeShared() throws -> ModelContainer {
        let schema = Schema([DailyPostureLog.self, PomodoroTask.self])
        let url = try storeFileURL()
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func storeFileURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let folder = base.appending(path: "DeskFocusModel", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "Desk.store")
    }
}

@MainActor
private final class DeskFocusSessionBootstrap {
    let confettiDriver = ConfettiBurstDriver()
    let deskStore: DeskSessionStore
    let pomodoroStore: PomodoroStore
    let liveActivity = DeskSessionLiveActivityManager()
    let pomodoroLiveActivity = PomodoroLiveActivityManager()

    init(modelContext: ModelContext) {
        let dailyLog = DailyLogStore(modelContext: modelContext)
        deskStore = DeskSessionStore(storage: LocalDeskStorage(), dailyLogStore: dailyLog)
        pomodoroStore = PomodoroStore(modelContext: modelContext)

        deskStore.liveActivityManager = liveActivity
        pomodoroStore.liveActivityManager = pomodoroLiveActivity
        DeskFocusLiveActivityDisconnectHandler.shared.register(desk: liveActivity, pomodoro: pomodoroLiveActivity)

        liveActivity.shouldSuppressDeskLiveActivity = { [weak self] in
            guard let self else { return false }
            return self.pomodoroStore.pomodoroLiveActivityVisible
        }

        liveActivity.beforeRequestingDeskLiveActivity = { [weak self] in
            guard let self else { return }
            await LiveActivityDuplicateTeardown.endAllPomodoroSessionActivities()
            self.pomodoroLiveActivity.resetTrackedActivityAfterExternalTermination()
        }

        pomodoroLiveActivity.beforeRequestingPomodoroLiveActivity = { [weak self] in
            guard let self else { return }
            await LiveActivityDuplicateTeardown.endAllDeskSessionActivities()
            self.liveActivity.resetTrackedActivityAfterExternalTermination()
        }

        pomodoroStore.onPomodoroLiveActivityEngagementChanged = { [weak self] in
            guard let self else { return }
            self.liveActivity.deskSessionStoreDidPersist(self.deskStore)
        }

        deskStore.onStandingConfettiMilestone = { [weak self] in
            guard let self else { return }
            scheduleConfettiBurst(driver: self.confettiDriver, palette: .standing)
        }
        deskStore.onSittingHourConfettiMilestone = { [weak self] in
            guard let self else { return }
            scheduleConfettiBurst(driver: self.confettiDriver, palette: .countdown)
        }
        deskStore.onStopwatchSegmentPauseCelebrate = { [weak self] in
            guard let self else { return }
            scheduleConfettiBurst(driver: self.confettiDriver, palette: .countdown)
        }
        deskStore.onDeskCountdownComplete = { [weak self] in
            guard let self else { return }
            scheduleConfettiBurst(driver: self.confettiDriver, palette: .countdown)
        }
        pomodoroStore.onPomodoroComplete = { [weak self] in
            guard let self else { return }
            scheduleConfettiBurst(driver: self.confettiDriver, palette: .pomodoro)
        }

        applyPendingLiveActivityCommands()
    }

    /// Widget / Live Activity intents run in the extension and enqueue commands in the shared app group.
    func applyPendingLiveActivityCommands() {
        if let command = DeskLiveActivityCommandBridge.dequeuePendingCommand() {
            switch command {
            case .togglePauseResume:
                deskStore.applyLiveActivityToggle()
            case .clearSession:
                if deskStore.running {
                    deskStore.pause()
                }
                deskStore.clearSession()
            }
        }
        if let command = PomodoroLiveActivityCommandBridge.dequeuePendingCommand() {
            switch command {
            case .togglePauseResume:
                pomodoroStore.applyLiveActivityToggle()
            case .resetTimer:
                pomodoroStore.applyLiveActivityReset()
            }
        }
    }
}

private struct DeskFocusRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var bootstrap: DeskFocusSessionBootstrap?

    var body: some View {
        ZStack {
            LaunchBrandGradient()
                .ignoresSafeArea()

            Group {
                if let bootstrap {
                    ZStack {
                        ContentView()
                            .environment(bootstrap.deskStore)
                            .environment(bootstrap.pomodoroStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea(edges: .bottom)

                        ConfettiView(driver: bootstrap.confettiDriver)
                            .allowsHitTesting(false)
                            .ignoresSafeArea()
                    }
                    .onAppear {
                        if scenePhase == .active {
                            bootstrap.applyPendingLiveActivityCommands()
                            bootstrap.liveActivity.noteSceneBecameActive(syncing: bootstrap.deskStore)
                            bootstrap.pomodoroLiveActivity.noteSceneBecameActive(syncing: bootstrap.pomodoroStore)
                        }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active {
                            bootstrap.applyPendingLiveActivityCommands()
                            bootstrap.liveActivity.noteSceneBecameActive(syncing: bootstrap.deskStore)
                            bootstrap.pomodoroLiveActivity.noteSceneBecameActive(syncing: bootstrap.pomodoroStore)
                        } else if phase == .inactive || phase == .background {
                            bootstrap.liveActivity.noteSceneBecameInactive()
                            bootstrap.pomodoroLiveActivity.noteSceneBecameInactive()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        bootstrap.applyPendingLiveActivityCommands()
                    }
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            guard bootstrap == nil else { return }
            await Task.yield()
            bootstrap = DeskFocusSessionBootstrap(modelContext: modelContext)
        }
    }
}

/// Opens SwiftData after the shell appears so UIKit can commit a frame before any disk I/O.
private struct DeskFocusLaunchShell: View {
    @State private var modelContainer: ModelContainer?
    @State private var modelLoadFailed = false
    @State private var modelLoadStarted = false

    var body: some View {
        ZStack {
            LaunchBrandGradient()
                .ignoresSafeArea()

            if modelLoadFailed {
                Text("DeskFocus couldn’t open its saved data. Delete the app to reset.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            } else if let modelContainer {
                DeskFocusRootView()
                    .modelContainer(modelContainer)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.25)
                    Text("Loading…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            guard !modelLoadStarted else { return }
            modelLoadStarted = true
            Task { await openModelStorageIfNeeded() }
        }
    }

    /// Cold launch is more reliable with `onAppear` + explicit `Task`; keeps model open off launch storyboard timing.
    @MainActor
    private func openModelStorageIfNeeded() async {
        guard modelContainer == nil, !modelLoadFailed else { return }
        await Task.yield()
        await Task.yield()
        let result = Result {
            try DeskFocusModelContainerFactory.makeShared()
        }
        switch result {
        case .success(let container):
            modelContainer = container
        case .failure:
            modelLoadFailed = true
        }
    }
}

@main
struct DeskFocusApp: App {
    @UIApplicationDelegateAdaptor(DeskFocusAppDelegate.self) private var appDelegate

    init() {
        UIWindow.appearance().backgroundColor = LaunchBrandGradient.uiWindowFallback
    }

    var body: some Scene {
        WindowGroup {
            DeskFocusLaunchShell()
        }
    }
}
