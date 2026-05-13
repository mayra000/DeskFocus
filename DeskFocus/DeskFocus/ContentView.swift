//
//  ContentView.swift
//
//  Created by Mayra Sanchez on 5/12/26.
//

import SwiftData
import SwiftUI
import UIKit

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
    @Environment(PomodoroStore.self) private var pomodoroStore

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

    private var pomodoroPhaseColors: PomodoroTheme.PhaseColors {
        PomodoroTheme.colors(for: pomodoroStore.phase)
    }

    /// Matches the lighter band of each tab’s vertical progress background.
    private var chromeBackdrop: Color {
        switch selectedMode {
        case .desk:
            return DeskTheme.timerSplitBase(for: deskStore.posture)
        case .pomodoro:
            return PomodoroTheme.timerSplitColors(for: pomodoroStore.phase).base
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // TabView page layout often leaves an uncovered strip above the home indicator; paint behind it explicitly.
                chromeBackdrop
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    appHeader

                    TabView(selection: selectedModeBinding) {
                        DeskView()
                            .tag(DeskFocusAppMode.desk)
                        PomodoroView()
                            .tag(DeskFocusAppMode.pomodoro)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.32), value: modeRaw)
            .animation(.easeInOut(duration: 0.35), value: pomodoroStore.phase)
            .animation(.easeInOut(duration: 0.45), value: deskStore.posture)
            .onChange(of: modeRaw) { _, newRaw in
                if DeskFocusAppMode(rawValue: newRaw) == .desk {
                    UIApplication.deskFocusDismissKeyboard()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                deskStore.handleForeground()
                pomodoroStore.handleForeground()
            }
        }
    }

    private var appHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("DESKFOCUS")
                .font(.system(.subheadline, design: .default).weight(.bold))
                .tracking(0.8)
                .foregroundStyle(selectedMode == .desk ? DeskTheme.primary : PomodoroTheme.primary)

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedModeBinding.wrappedValue = selectedMode == .desk ? .pomodoro : .desk
                }
            } label: {
                Text(selectedMode == .desk ? "SWITCH TO POMODORO" : "SWITCH TO STANDING TIMER")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .foregroundStyle(
                        selectedMode == .desk ? DeskTheme.primary : PomodoroTheme.primary
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedMode == .pomodoro ? pomodoroPhaseColors.headerButtonFill : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                selectedMode == .desk
                                    ? DeskTheme.border
                                    : PomodoroTheme.primary.opacity(0.95),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedMode == .desk ? "Switch to Pomodoro" : "Switch to standing desk timer")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(chromeBackdrop)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { _ in UIApplication.deskFocusDismissKeyboard() }
        )
    }
}

extension UIApplication {
    static func deskFocusDismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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
