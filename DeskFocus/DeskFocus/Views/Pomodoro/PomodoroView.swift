//
//  PomodoroView.swift
//  DeskFocus
//

import SwiftData
import SwiftUI
import UIKit

struct PomodoroView: View {
    @Environment(PomodoroStore.self) private var store

    @Query(sort: \PomodoroTask.order, order: .reverse)
    private var tasks: [PomodoroTask]

    @State private var newTaskTitle = ""
    @State private var keyboardOverlapHeight: CGFloat = 0

    @FocusState private var addTaskFieldFocused: Bool

    private var phaseColors: PomodoroTheme.PhaseColors {
        PomodoroTheme.colors(for: store.phase)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    timerCard

                    statusBlock

                    tasksSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, keyboardOverlapHeight > 0 ? keyboardOverlapHeight + 28 : 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded { _ in UIApplication.deskFocusDismissKeyboard() }
            )
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                keyboardOverlapHeight = Self.keyboardOverlapHeight(from: note)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardOverlapHeight = 0
            }
            .onChange(of: addTaskFieldFocused) { _, focused in
                guard focused else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeOut(duration: 0.34)) {
                        scrollProxy.scrollTo("addTaskField", anchor: UnitPoint(x: 0.5, y: 0.82))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.35), value: store.phase)
        .animation(.easeOut(duration: 0.22), value: keyboardOverlapHeight)
        .onDisappear {
            UIApplication.deskFocusDismissKeyboard()
        }
    }

    private var timerCard: some View {
        VStack(spacing: 20) {
            phaseTabs

            Text(timerClockString)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PomodoroTheme.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Button {
                store.toggleRunning()
            } label: {
                Text(store.startLabel)
                    .font(.subheadline.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(phaseColors.startText)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(phaseColors.startFill)
                    )
            }
            .buttonStyle(.plain)
            .disabled(store.remainingMs <= 0 && !store.running)
            .opacity(store.remainingMs <= 0 && !store.running ? 0.45 : 1)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(phaseColors.card)
        )
    }

    private var phaseTabs: some View {
        HStack(spacing: 4) {
            phaseTab(title: "Pomodoro", phase: .pomodoro)
            phaseTab(title: "Short Break", phase: .shortBreak)
            phaseTab(title: "Long Break", phase: .longBreak)
        }
        .padding(4)
        .frame(maxWidth: .infinity)
    }

    private func phaseTab(title: String, phase: PomodoroPhase) -> some View {
        let selected = store.phase == phase
        return Button {
            store.setPhase(phase)
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .foregroundStyle(selected ? PomodoroTheme.primary : PomodoroTheme.muted)
                .background(
                    Group {
                        if selected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(PomodoroTheme.tabPill)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private var timerClockString: String {
        let m = store.remainingMs / 60_000
        let s = (store.remainingMs % 60_000) / 1_000
        return String(format: "%02d:%02d", m, s)
    }

    private var statusBlock: some View {
        Group {
            switch store.phase {
            case .pomodoro:
                if let label = store.focusSessionLabel {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(label)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PomodoroTheme.primary)
                        Text("Time to focus!")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PomodoroTheme.primary)
                    }
                }
            case .shortBreak:
                Text("Short break — step away from the screen.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PomodoroTheme.primary)
            case .longBreak:
                Text("Long break — unwind before the next focus round.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PomodoroTheme.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Rectangle()
                .fill(PomodoroTheme.primary.opacity(0.35))
                .frame(height: 1)
                .padding(.top, 4)

            Text("TASKS")
                .font(.subheadline.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(PomodoroTheme.primary)

            addTaskField

            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    private var addTaskField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PomodoroTheme.addTaskPlaceholder)

            TextField(
                "",
                text: $newTaskTitle,
                prompt: Text("Add Task")
                    .font(.subheadline)
                    .foregroundStyle(PomodoroTheme.addTaskPlaceholder)
            )
            .textFieldStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(PomodoroTheme.primary)
            .focused($addTaskFieldFocused)
            .onSubmit(addTaskFromField)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    PomodoroTheme.dashedStroke,
                    style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                )
        )
        .id("addTaskField")
    }

    private static func keyboardOverlapHeight(from notification: Notification) -> CGFloat {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return 0 }
        guard frame.minY.isFinite else { return 0 }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return max(0, UIScreen.main.bounds.height - frame.minY)
        }
        return scene.screen.bounds.intersection(frame).height
    }

    private func addTaskFromField() {
        store.addTask(title: newTaskTitle)
        newTaskTitle = ""
    }

    private func taskRow(_ task: PomodoroTask) -> some View {
        HStack(spacing: 12) {
            Button {
                store.toggleDone(id: task.id)
            } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.done ? phaseColors.startFill : PomodoroTheme.muted)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.subheadline.weight(.medium))
                .strikethrough(task.done)
                .foregroundStyle(task.done ? PomodoroTheme.muted : PomodoroTheme.primary.opacity(0.95))

            Spacer(minLength: 8)

            Button {
                store.removeTask(id: task.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PomodoroTheme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
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
    let pomodoro = PomodoroStore(modelContext: container.mainContext)
    return PomodoroView()
        .modelContainer(container)
        .environment(pomodoro)
}
