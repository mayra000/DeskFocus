//
//  FactCarouselView.swift
//  DeskFocus
//
//  Mirrors React FactCarousel — prev/next, auto-advance on an interval, persisted index.
//

import Combine
import SwiftData
import SwiftUI

struct FactCarouselView: View {
    @Environment(DeskSessionStore.self) private var deskStore

    private var facts: [String] { deskWellnessFacts }

    private var safeIndex: Int {
        guard !facts.isEmpty else { return 0 }
        return min(max(deskStore.factIndex, 0), facts.count - 1)
    }

    private var currentFact: String {
        guard !facts.isEmpty else { return "" }
        return facts[safeIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wellness facts")
                .font(.headline)

            Text(currentFact)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                .animation(.easeInOut(duration: 0.2), value: deskStore.factIndex)

            HStack {
                Button {
                    deskStore.advanceFact(by: -1, factCount: facts.count)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(facts.isEmpty)

                Spacer()

                if facts.count > 0 {
                    Text("\(safeIndex + 1) / \(facts.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    deskStore.advanceFact(by: 1, factCount: facts.count)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(facts.isEmpty)
            }
            .buttonStyle(.bordered)
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            guard !facts.isEmpty else { return }
            deskStore.advanceFact(by: 1, factCount: facts.count)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyPostureLog.self, PomodoroTask.self, configurations: configuration)
    let store = DeskSessionStore(
        storage: LocalDeskStorage(),
        dailyLogStore: DailyLogStore(modelContext: container.mainContext)
    )
    return FactCarouselView()
        .modelContainer(container)
        .environment(store)
        .padding()
}
