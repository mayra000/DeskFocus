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

    private enum CountdownDigitField: Hashable {
        case hour, minute, second
    }

    @FocusState private var countdownFocusedDigit: CountdownDigitField?
    @State private var countdownHourDraft = ""
    @State private var countdownMinuteDraft = ""
    @State private var countdownSecondDraft = ""

    var body: some View {
        deskScrollStack
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.45), value: deskStore.posture)
            .animation(.easeInOut(duration: 0.35), value: deskStore.sessionDisplayMode)
            .animation(.easeInOut(duration: 0.28), value: deskStore.running)
            .animation(.easeInOut(duration: 0.22), value: deskStore.sessionPausedMs)
            .onAppear {
                UIApplication.deskFocusDismissKeyboard()
            }
            .onChange(of: deskStore.sessionDisplayMode) { _, newMode in
                if newMode != .countdown {
                    countdownFocusedDigit = nil
                    UIApplication.deskFocusDismissKeyboard()
                }
            }
            .onChange(of: deskStore.running) { _, isRunning in
                if isRunning {
                    countdownFocusedDigit = nil
                    UIApplication.deskFocusDismissKeyboard()
                }
            }
    }

    private var deskScrollStack: some View {
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

                    VStack(alignment: .leading, spacing: 56) {
                        StandingWeekBadgesView()
                        standingGoalSection
                        // Wellness facts carousel hidden for a cleaner desk UI (see `deskWellnessFacts` / FactCarouselView if restoring).
                        weeklySittingSection

                        ActivityLogView()
                        WeeklySummaryView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollDisabled(countdownFocusedDigit != nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if countdownFocusedDigit != nil {
                    Spacer()
                    Button("Done") {
                        if let field = countdownFocusedDigit {
                            commitCountdownField(field)
                        }
                        countdownFocusedDigit = nil
                        UIApplication.deskFocusDismissKeyboard()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            guard let field = countdownFocusedDigit else { return }
            commitCountdownField(field)
            countdownFocusedDigit = nil
        }
    }

    /// 0 → empty deeper fill at bottom; 1 → full bleed deep.
    /// Sitting uses a fixed one-hour scale (`postureFillRatio`) so the backdrop matches “sitting hour” pacing
    /// instead of the countdown picker / cleared countdown (`countdownDurationMs` could be a short timer or 0).
    private var deskTimerFillFraction: CGFloat {
        let elapsedMs = deskStore.sessionElapsedMs
        if deskStore.posture == .sitting {
            return CGFloat(postureFillRatio(elapsedMs: elapsedMs))
        }
        let denominator: Int
        switch deskStore.sessionDisplayMode {
        case .countdown:
            let d = deskStore.countdownDurationMs
            denominator = d > 0 ? d : max(1, deskStore.standingGoalMs)
        case .stopwatch:
            denominator = max(1, deskStore.standingGoalMs)
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

            Group {
                if deskStore.sessionDisplayMode == .countdown {
                    countdownPickerSection
                } else {
                    stopwatchDigitsRow
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 20) {
                deskCircleIconButton(
                    systemName: deskStore.running ? "pause.fill" : "play.fill",
                    accessibilityLabel: deskStore.running ? "Pause" : "Play",
                    disabled: deskPlayBlocked
                ) {
                    if deskStore.running {
                        deskStore.pause()
                    } else {
                        deskStore.play()
                    }
                }

                deskCircleIconButton(
                    systemName: "xmark",
                    accessibilityLabel: deskClearTimerAccessibilityLabel,
                    disabled: !deskClearTimerEnabled
                ) {
                    if deskStore.sessionDisplayMode == .countdown {
                        countdownFocusedDigit = nil
                        UIApplication.deskFocusDismissKeyboard()
                        deskStore.clearCountdownTime()
                    } else {
                        deskStore.resetDeskTimerProgress()
                    }
                }

                deskCircleIconButton(
                    systemName: deskStore.sessionDisplayMode == .countdown ? "stopwatch" : "clock",
                    accessibilityLabel: deskStore.sessionDisplayMode == .countdown
                        ? "Switch to stopwatch"
                        : "Switch to countdown timer",
                    emphasized: deskStore.sessionDisplayMode == .countdown
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

    private var deskPlayBlocked: Bool {
        !deskStore.running
            && deskStore.sessionDisplayMode == .countdown
            && deskStore.countdownDurationMs <= 0
    }

    /// Stopwatch clear: elapsed progress. Countdown clear: countdown target / remaining (`countdownFaceMs`), or running countdown.
    private var deskClearTimerEnabled: Bool {
        switch deskStore.sessionDisplayMode {
        case .countdown:
            return deskStore.running || countdownFaceMs > 0
        case .stopwatch:
            return deskStore.running || deskStore.sessionElapsedMs > 0
        }
    }

    private var deskClearTimerAccessibilityLabel: String {
        switch deskStore.sessionDisplayMode {
        case .countdown:
            return "Clear countdown"
        case .stopwatch:
            return "Clear stopwatch"
        }
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
            return "COUNTDOWN"
        case .stopwatch:
            return deskStore.posture == .sitting
                ? "YOU HAVE BEEN SITTING FOR"
                : "YOU HAVE BEEN STANDING FOR"
        }
    }

    /// Face shown in countdown mode: remaining while running, configured duration while paused.
    private var countdownFaceMs: Int {
        if deskStore.running {
            return max(0, deskStore.countdownDurationMs - deskStore.sessionElapsedMs)
        }
        return deskStore.countdownDurationMs
    }

    private var countdownFaceHMS: (h: Int, m: Int, s: Int) {
        let sec = countdownFaceMs / 1_000
        return (sec / 3_600, (sec % 3_600) / 60, sec % 60)
    }

    private var countdownSteppersEnabled: Bool {
        deskStore.sessionDisplayMode == .countdown && !deskStore.running
    }

    private var stopwatchDigitsRow: some View {
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
    }

    private var countdownPickerSection: some View {
        let hms = countdownFaceHMS

        return VStack(spacing: 14) {
            HStack(spacing: 10) {
                countdownQuantityColumn(
                    field: .hour,
                    draft: $countdownHourDraft,
                    value: hms.h,
                    padDigits: false,
                    label: "HOURS",
                    steppersEnabled: countdownSteppersEnabled,
                    incrementAccessibilityLabel: "Increase countdown hours",
                    decrementAccessibilityLabel: "Decrease countdown hours",
                    increment: {
                        deskStore.setCountdownDurationMs(deskStore.countdownDurationMs + 3_600 * 1_000)
                    },
                    decrement: {
                        deskStore.setCountdownDurationMs(deskStore.countdownDurationMs - 3_600 * 1_000)
                    }
                )

                Text(":")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(DeskTheme.primary)
                    .frame(height: 44)
                    .offset(y: -10)

                countdownQuantityColumn(
                    field: .minute,
                    draft: $countdownMinuteDraft,
                    value: hms.m,
                    padDigits: true,
                    label: "MINUTES",
                    steppersEnabled: countdownSteppersEnabled,
                    incrementAccessibilityLabel: "Increase countdown by five minutes",
                    decrementAccessibilityLabel: "Decrease countdown by five minutes",
                    increment: {
                        deskStore.setCountdownDurationMs(deskStore.countdownDurationMs + COUNTDOWN_STEP_MS)
                    },
                    decrement: {
                        deskStore.setCountdownDurationMs(deskStore.countdownDurationMs - COUNTDOWN_STEP_MS)
                    }
                )

                Text(":")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(DeskTheme.primary)
                    .frame(height: 44)
                    .offset(y: -10)

                countdownQuantityColumn(
                    field: .second,
                    draft: $countdownSecondDraft,
                    value: hms.s,
                    padDigits: true,
                    label: "SECONDS",
                    steppersEnabled: false,
                    digitTapEnabled: countdownSteppersEnabled,
                    incrementAccessibilityLabel: "Increase countdown seconds",
                    decrementAccessibilityLabel: "Decrease countdown seconds",
                    increment: {},
                    decrement: {}
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.22))
            )
        }
    }

    private func countdownQuantityColumn(
        field: CountdownDigitField,
        draft: Binding<String>,
        value: Int,
        padDigits: Bool,
        label: String,
        steppersEnabled: Bool,
        digitTapEnabled: Bool? = nil,
        incrementAccessibilityLabel: String,
        decrementAccessibilityLabel: String,
        increment: @escaping () -> Void,
        decrement: @escaping () -> Void
    ) -> some View {
        let digitText = padDigits ? String(format: "%02d", value) : "\(value)"
        let tapsOK = digitTapEnabled ?? steppersEnabled

        return VStack(spacing: 8) {
            countdownArrowButton(
                up: true,
                enabled: steppersEnabled,
                accessibilityLabel: incrementAccessibilityLabel,
                action: increment
            )

            countdownDigitEntry(field: field, displayText: digitText, draft: draft, tapEnabled: tapsOK)

            countdownArrowButton(
                up: false,
                enabled: steppersEnabled,
                accessibilityLabel: decrementAccessibilityLabel,
                action: decrement
            )

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DeskTheme.muted)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private func countdownDigitEntry(
        field: CountdownDigitField,
        displayText: String,
        draft: Binding<String>,
        tapEnabled: Bool
    ) -> some View {
        let focusedHere = countdownFocusedDigit == field

        return ZStack {
            // Keep TextField in the hierarchy so focus → keyboard is reliable (conditional swap often fails inside ScrollView).
            TextField("", text: draft)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DeskTheme.primary)
                .tint(DeskTheme.primary)
                .frame(minWidth: 56, minHeight: 48)
                .focused($countdownFocusedDigit, equals: field)
                .opacity(focusedHere ? 1 : 0)
                .allowsHitTesting(focusedHere)
                .accessibilityLabel(countdownDigitAccessibilityLabel(field))
                .accessibilityHidden(!focusedHere)

            if !focusedHere {
                Button {
                    guard tapEnabled else { return }
                    beginEditingCountdownField(field)
                } label: {
                    Text(displayText)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DeskTheme.primary)
                        .frame(minWidth: 56, minHeight: 48)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(tapEnabled)
                .accessibilityLabel(countdownDigitAccessibilityLabel(field))
                .accessibilityHint(tapEnabled ? "Tap to type a value" : "")
            }
        }
        .frame(minHeight: 48)
    }

    private func countdownDigitAccessibilityLabel(_ field: CountdownDigitField) -> String {
        switch field {
        case .hour: return "Countdown hours"
        case .minute: return "Countdown minutes"
        case .second: return "Countdown seconds"
        }
    }

    private func beginEditingCountdownField(_ field: CountdownDigitField) {
        if let current = countdownFocusedDigit, current != field {
            commitCountdownField(current)
        }
        // Blank draft so the number pad replaces the prior value instead of inserting into padded text (e.g. "090" → "0090").
        switch field {
        case .hour: countdownHourDraft = ""
        case .minute: countdownMinuteDraft = ""
        case .second: countdownSecondDraft = ""
        }
        // Next run loop so the TextField is hit-testable before accepting focus (helps inside ScrollView / TabView).
        DispatchQueue.main.async {
            countdownFocusedDigit = field
        }
    }

    private func commitCountdownField(_ field: CountdownDigitField) {
        let hms = countdownFaceHMS
        let totalSec: Int
        switch field {
        case .hour:
            let h = parseRawNonNegativeInt(countdownHourDraft, fallback: hms.h)
            totalSec = max(0, h) * 3_600 + max(0, hms.m) * 60 + max(0, hms.s)
        case .minute:
            let mParsed = parseRawNonNegativeInt(countdownMinuteDraft, fallback: hms.m)
            if mParsed >= 60 {
                // Whole-minute duration (e.g. 80 → 1h 20m; 90 → 1h 30m), not “shown hours + mParsed”.
                totalSec = mParsed * 60 + max(0, hms.s)
            } else {
                totalSec = max(0, hms.h) * 3_600 + mParsed * 60 + max(0, hms.s)
            }
        case .second:
            let s = parseRawNonNegativeInt(countdownSecondDraft, fallback: hms.s)
            totalSec = max(0, hms.h) * 3_600 + max(0, hms.m) * 60 + max(0, s)
        }
        deskStore.setCountdownDurationMs(totalSec * 1_000)
    }

    /// Parses a non-negative integer from draft text; empty/invalid uses `fallback`.
    private func parseRawNonNegativeInt(_ raw: String, fallback: Int) -> Int {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty, let v = Int(digits) else { return fallback }
        return max(0, v)
    }

    private func countdownArrowButton(
        up: Bool,
        enabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DeskTheme.primary.opacity(enabled ? 1 : 0.28))
                .rotationEffect(.degrees(up ? 0 : 180))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel)
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
        emphasized: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.medium))
                .foregroundStyle(DeskTheme.primary.opacity(disabled ? 0.28 : 1))
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .strokeBorder(DeskTheme.border, lineWidth: emphasized ? 2 : 1)
                        .background(Circle().fill(Color.black.opacity(0.12)))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
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
