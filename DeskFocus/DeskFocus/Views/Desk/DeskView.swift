//
//  DeskView.swift
//  DeskFocus
//

import SwiftData
import SwiftUI

struct DeskView: View {
    @Environment(DeskSessionStore.self) private var deskStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                deskHeaderControls

                StandingWeekBadgesView()
                WeeklySummaryView()
                ActivityLogView()
                FactCarouselView()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var deskHeaderControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(deskStore.posture == .standing ? "Standing" : "Sitting", systemImage: deskStore.posture == .standing ? "figure.stand" : "figure.seated.side")
                    .font(.headline)
                Spacer()
                Button("Switch") {
                    deskStore.switchPosture()
                }
                .buttonStyle(.bordered)
            }

            Text(formattedSessionElapsed)
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Button(deskStore.running ? "Pause" : "Play") {
                    if deskStore.running {
                        deskStore.pause()
                    } else {
                        deskStore.play()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Clear session") {
                    deskStore.clearSession()
                }
                .buttonStyle(.bordered)
                .disabled(deskStore.running)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var formattedSessionElapsed: String {
        let ms = deskStore.sessionElapsedMs
        let sec = max(0, ms) / 1_000
        let m = sec / 60
        let s = sec % 60
        let h = m / 60
        let rm = m % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, rm, s)
        }
        return String(format: "%d:%02d", m, s)
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
    return DeskView()
        .modelContainer(container)
        .environment(desk)
}
