//
//  DeskFocusApp.swift
//  DeskFocus
//
//  Created by Mayra Sanchez on 5/12/26.
//

import SwiftData
import SwiftUI

@MainActor
private final class DeskFocusSessionBootstrap {
    let confettiDriver = ConfettiBurstDriver()
    let deskStore: DeskSessionStore
    let pomodoroStore: PomodoroStore

    init(modelContext: ModelContext) {
        let dailyLog = DailyLogStore(modelContext: modelContext)
        deskStore = DeskSessionStore(storage: LocalDeskStorage(), dailyLogStore: dailyLog)
        pomodoroStore = PomodoroStore(modelContext: modelContext)

        deskStore.onStandingConfettiMilestone = { [weak self] in
            self?.confettiDriver.fire(.standing)
        }
        pomodoroStore.onPomodoroComplete = { [weak self] in
            self?.confettiDriver.fire(.pomodoro)
        }
    }
}

private struct DeskFocusRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var bootstrap: DeskFocusSessionBootstrap?

    var body: some View {
        Group {
            if let bootstrap {
                ZStack {
                    ContentView()
                        .environment(bootstrap.deskStore)
                        .environment(bootstrap.pomodoroStore)

                    ConfettiView(driver: bootstrap.confettiDriver)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if bootstrap == nil {
                bootstrap = DeskFocusSessionBootstrap(modelContext: modelContext)
            }
        }
    }
}

@main
struct DeskFocusApp: App {

    private let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Schema([DailyPostureLog.self, PomodoroTask.self]))
        } catch {
            fatalError(String(describing: error))
        }
    }()

    var body: some Scene {
        WindowGroup {
            DeskFocusRootView()
                .modelContainer(sharedModelContainer)
        }
    }
}
