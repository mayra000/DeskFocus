//
//  PomodoroView.swift
//  DeskFocus
//

import SwiftData
import SwiftUI

struct PomodoroView: View {
    @Environment(PomodoroStore.self) private var store

    @Query(sort: \PomodoroTask.order, order: .reverse)
    private var tasks: [PomodoroTask]

    @State private var newTaskTitle = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                timerCard

                tasksSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let label = store.focusSessionLabel, store.phase == .pomodoro {
                Text("Focus \(label)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(store.statusLine)
                .font(.title3.weight(.medium))

            Text("Completed: \(store.pomodorosCompleted)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(store.startLabel) {
                store.toggleRunning()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasks")
                .font(.headline)

            HStack {
                TextField("New task", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    store.addTask(title: newTaskTitle)
                    newTaskTitle = ""
                }
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(tasks) { task in
                    HStack {
                        Button {
                            store.toggleDone(id: task.id)
                        } label: {
                            Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.done ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(task.title)
                            .strikethrough(task.done)
                            .foregroundStyle(task.done ? .secondary : .primary)

                        Spacer()

                        Button(role: .destructive) {
                            store.removeTask(id: task.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
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
