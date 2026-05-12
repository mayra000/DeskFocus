//
//  ContentView.swift
//
//  Created by Mayra Sanchez on 5/12/26.
//

import SwiftData
import SwiftUI

enum DeskFocusAppMode: String, CaseIterable {
    case desk
    case pomodoro

    static let storageKey = "deskfocus-app-mode"

    var title: String {
        switch self {
        case .desk: return "Desk"
        case .pomodoro: return "Pomodoro"
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DeskSessionStore.self) private var deskStore

    @AppStorage(DeskFocusAppMode.storageKey)
    private var modeRaw: String = DeskFocusAppMode.desk.rawValue

    private var selectedMode: DeskFocusAppMode {
        DeskFocusAppMode(rawValue: modeRaw) ?? .desk
    }

    private var selectedModeBinding: Binding<DeskFocusAppMode> {
        Binding(
            get: { DeskFocusAppMode(rawValue: modeRaw) ?? .desk },
            set: { modeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerModeSwitcher

                Group {
                    switch selectedMode {
                    case .desk:
                        DeskView()
                    case .pomodoro:
                        PomodoroView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("DeskFocus")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                deskStore.handleForeground()
            }
        }
    }

    private var headerModeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(DeskFocusAppMode.allCases, id: \.self) { mode in
                Button {
                    selectedModeBinding.wrappedValue = mode
                } label: {
                    Text(mode.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedMode == mode ? Color.accentColor : Color.clear)
                        )
                        .foregroundStyle(selectedMode == mode ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMode == mode ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemFill))
        )
        .padding(.horizontal)
        .padding(.vertical, 10)
        .accessibilityLabel("App mode")
        .accessibilityHint("Switch between Desk timer and Pomodoro")
    }
}

#Preview {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Schema([DailyPostureLog.self, PomodoroTask.self]), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError(String(describing: error))
        }
    }()
    let ctx = container.mainContext
    let desk = DeskSessionStore(storage: LocalDeskStorage(), dailyLogStore: DailyLogStore(modelContext: ctx))
    let pomodoro = PomodoroStore(modelContext: ctx)
    return ContentView()
        .modelContainer(container)
        .environment(desk)
        .environment(pomodoro)
}
