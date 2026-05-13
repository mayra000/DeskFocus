//
//  DeskView.swift
//  DeskFocus
//

import Combine
import SwiftData
import SwiftUI
import UIKit

struct DeskView: View {
    @Environment(DeskSessionStore.self) private var deskStore

    private var facts: [String] { deskWellnessFacts }

    private var safeFactIndex: Int {
        guard !facts.isEmpty else { return 0 }
        return min(max(deskStore.factIndex, 0), facts.count - 1)
    }

    private var currentFact: String {
        guard !facts.isEmpty else { return "" }
        return facts[safeFactIndex]
    }

    var body: some View {
        ZStack {
            TimerVerticalFillBackground(
                fraction: deskTimerFillFraction,
                baseColor: DeskTheme.timerSplitBase(for: deskStore.posture),
                deepColor: DeskTheme.timerSplitDeep(for: deskStore.posture)
            )
            .ignoresSafeArea(edges: [.horizontal, .bottom])

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    mainTimerCard

                    StandingWeekBadgesView()
                    standingGoalSection
                    factSection
                    weeklySittingSection

                    WeeklySummaryView()
                    ActivityLogView()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.45), value: deskStore.posture)
        .onAppear {
            UIApplication.deskFocusDismissKeyboard()
        }
    }

    /// 0 → empty deeper fill at bottom; 1 → full bleed deep (aligned with countdown draining / elapsed progress).
    private var deskTimerFillFraction: CGFloat {
        let elapsedMs = deskStore.sessionElapsedMs
        let denominator: Int
        switch deskStore.sessionDisplayMode {
        case .countdown:
            denominator = max(1, deskStore.countdownDurationMs)
        case .stopwatch:
            denominator =
                deskStore.posture == .standing
                    ? max(1, deskStore.standingGoalMs)
                    : max(1, deskStore.countdownDurationMs)
        }
        return CGFloat(min(1, Double(elapsedMs) / Double(denominator)))
    }

    // MARK: - Main card

    private var mainTimerCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer(minLength: 0)
                posturePill
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule(style: .continuous).fill(DeskTheme.pillBackground))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Text(sessionContextCaption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DeskTheme.muted)
                .textCase(.uppercase)
                .tracking(0.6)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                timerDigitGroup(value: displayHMS.h, width: 44, label: "HOURS")
                Text(":")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(DeskTheme.primary)
                    .offset(y: -12)
                timerDigitGroup(value: displayHMS.m, width: 44, label: "MINUTES")
                Text(":")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(DeskTheme.primary)
                    .offset(y: -12)
                timerDigitGroup(value: displayHMS.s, width: 44, label: "SECONDS")
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 20) {
                deskCircleIconButton(systemName: "play.fill", accessibilityLabel: "Play") {
                    deskStore.play()
                }
                .opacity(deskStore.running ? 0.35 : 1)

                deskCircleIconButton(systemName: "pause.fill", accessibilityLabel: "Pause") {
                    deskStore.pause()
                }
                .opacity(deskStore.running ? 1 : 0.35)

                deskCircleIconButton(
                    systemName: deskStore.sessionDisplayMode == .countdown ? "stopwatch" : "clock",
                    accessibilityLabel: "Toggle countdown or stopwatch"
                ) {
                    deskStore.toggleSessionDisplayMode()
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                deskStore.switchPosture()
            } label: {
                Text(switchPostureTitle)
                    .font(.subheadline.weight(.bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(DeskTheme.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DeskTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DeskTheme.mainCard(for: deskStore.posture))
        )
        .accessibilityElement(children: .contain)
    }

    private var posturePill: some View {
        (Text("NOW ")
            + Text(deskStore.posture == .sitting ? "Sitting" : "Standing")
            .fontWeight(.bold))
            .font(.subheadline)
            .foregroundStyle(DeskTheme.primary)
    }

    private var sessionContextCaption: String {
        switch deskStore.sessionDisplayMode {
        case .countdown:
            return "COUNTDOWN REMAINING"
        case .stopwatch:
            return deskStore.posture == .sitting
                ? "YOU HAVE BEEN SITTING FOR"
                : "YOU HAVE BEEN STANDING FOR"
        }
    }

    private var switchPostureTitle: String {
        deskStore.posture == .sitting ? "SWITCH TO STANDING" : "SWITCH TO SITTING"
    }

    private var displayMs: Int {
        switch deskStore.sessionDisplayMode {
        case .stopwatch:
            return max(0, deskStore.sessionElapsedMs)
        case .countdown:
            return max(0, deskStore.countdownDurationMs - deskStore.sessionElapsedMs)
        }
    }

    private var displayHMS: (h: Int, m: Int, s: Int) {
        let sec = displayMs / 1_000
        return (sec / 3_600, (sec % 3_600) / 60, sec % 60)
    }

    private func timerDigitGroup(value: Int, width: CGFloat, label: String) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%02d", value))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DeskTheme.primary)
                .frame(minWidth: width)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DeskTheme.muted)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }

    private func deskCircleIconButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.medium))
                .foregroundStyle(DeskTheme.primary)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .strokeBorder(DeskTheme.border, lineWidth: 1)
                        .background(Circle().fill(Color.black.opacity(0.12)))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Standing goal

    private var standingGoalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STANDING GOAL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DeskTheme.muted)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 16) {
                Button {
                    deskStore.adjustStandingGoalMs(-COUNTDOWN_STEP_MS)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DeskTheme.muted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease standing goal")

                Text(formatCompactStandingGoal(ms: deskStore.standingGoalMs))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DeskTheme.primary)
                    .frame(maxWidth: .infinity)

                Button {
                    deskStore.adjustStandingGoalMs(COUNTDOWN_STEP_MS)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DeskTheme.muted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase standing goal")
            }
        }
    }

    // MARK: - Fact

    private var factSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentFact)
                .font(.footnote)
                .foregroundStyle(DeskTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button {
                    UIPasteboard.general.string = currentFact
                } label: {
                    Image(systemName: "link")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DeskTheme.muted)
                .disabled(currentFact.isEmpty)
                .accessibilityLabel("Copy wellness note")

                Spacer()

                Button {
                    deskStore.advanceFact(by: -1, factCount: facts.count)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DeskTheme.muted)
                .disabled(facts.isEmpty)

                Button {
                    deskStore.advanceFact(by: 1, factCount: facts.count)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DeskTheme.muted)
                .disabled(facts.isEmpty)
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            guard !facts.isEmpty else { return }
            deskStore.advanceFact(by: 1, factCount: facts.count)
        }
    }

    // MARK: - Weekly sitting

    private var weeklySittingSection: some View {
        let parts = hms(fromMs: deskStore.weeklySittingMs)

        return VStack(alignment: .leading, spacing: 10) {
            Text("TIME SPENT SITTING THIS WEEK:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DeskTheme.muted)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(alignment: .center, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    compactClockPart(value: parts.h, label: "HR")
                    Text(":").font(.callout.weight(.bold)).foregroundStyle(DeskTheme.primary).offset(y: -4)
                    compactClockPart(value: parts.m, label: "MIN")
                    Text(":").font(.callout.weight(.bold)).foregroundStyle(DeskTheme.primary).offset(y: -4)
                    compactClockPart(value: parts.s, label: "SEC")
                }

                Button {
                    deskStore.handleForeground()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.medium))
                        .foregroundStyle(DeskTheme.muted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh weekly sitting summary")
            }
        }
    }

    private func compactClockPart(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(DeskTheme.primary)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(DeskTheme.muted)
        }
    }

    private func hms(fromMs ms: Int) -> (h: Int, m: Int, s: Int) {
        let sec = max(0, ms) / 1_000
        return (sec / 3_600, (sec % 3_600) / 60, sec % 60)
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
