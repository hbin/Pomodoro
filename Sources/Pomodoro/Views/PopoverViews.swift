import AppKit
import PomodoroCore
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var updates: UpdateController
    @Environment(\.colorScheme) private var scheme

    /// The timer card is a 2:3 portrait. Settings uses the same width but
    /// keeps its own content-measured height.
    static let timerWidth: CGFloat = 340
    static let settingsWidth: CGFloat = 340
    static let timerHeight: CGFloat = 510
    /// The dial scales with the 2:3 timer card so the side arrows keep their
    /// 44-point targets without changing the card's horizontal padding.
    static let timerDialSize: CGFloat = 203

    /// The Settings card is at least this tall, and grows to fit its content
    /// so no row or explanation has to scroll.
    static let settingsHeight: CGFloat = 592
    static let settingsMaxHeight: CGFloat = 760

    /// The outer padding of the Settings card; the rest of its height is the
    /// measured content plus footer.
    private static let settingsChrome: CGFloat = 37

    static func contentWidth(showingSettings: Bool) -> CGFloat {
        showingSettings ? settingsWidth : timerWidth
    }

    static func contentHeight(showingSettings: Bool, settingsContent: CGFloat = 0) -> CGFloat {
        guard showingSettings else { return timerHeight }
        let fitted = settingsContent > 0 ? settingsContent + settingsChrome : settingsHeight
        return min(max(settingsHeight, fitted.rounded(.up)), settingsMaxHeight)
    }

    @State private var idleMode: IdleMode = LaunchIdleMode.override ?? .focus

    /// The mode that owns the ambient light. Idle follows the selector, a
    /// running or paused interval follows its phase, and a completed interval
    /// follows the next interval offered by the completion screen.
    private var activeMode: IdleMode {
        if model.isIdle {
            return idleMode
        }
        if model.isCompleted {
            return IdleMode(phase: model.completionOffer.phase)
        }
        return IdleMode(phase: model.phase)
    }

    private var ambient: AmbientPose {
        AmbientPose.forMode(activeMode)
    }

    private var ambientAccent: Color {
        let palette = Palette.forScheme(scheme)
        if model.isIdle || model.isCompleted {
            return activeMode.glowColor(in: palette)
        }
        if model.phase == .longBreak {
            return palette.brass
        }
        return palette.accent(for: model.phase)
    }

    var body: some View {
        ZStack {
            PopoverBackground(
                pose: ambient,
                accent: ambientAccent,
                showsAmbient: !model.isShowingSettings
            )
            Group {
                if model.isShowingSettings {
                    SettingsView(
                        model: model,
                        updates: updates,
                        onQuit: { NSApp.terminate(nil) },
                        onClose: model.closeSettings,
                        onContentHeight: model.reportSettingsContentHeight
                    )
                } else {
                    content
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 19)
            .padding(.bottom, 18)
        }
        .frame(
            width: Self.contentWidth(showingSettings: model.isShowingSettings),
            height: Self.contentHeight(
                showingSettings: model.isShowingSettings,
                settingsContent: model.settingsContentHeight
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onAppear {
            if let override = LaunchIdleMode.override {
                idleMode = override
            } else {
                normalizeIdleSelection()
            }
        }
        .onChange(of: model.isIdle) { _, isIdle in
            if isIdle {
                normalizeIdleSelection()
            }
        }
    }

    private func normalizeIdleSelection() {
        guard model.isIdle else { return }
        idleMode = .focus
    }

    @ViewBuilder
    private var content: some View {
        if model.isCompleted {
            CompletionPopoverView(model: model, ambient: ambient)
        } else {
            TimerPopoverView(model: model, ambient: ambient, idleMode: $idleMode)
        }
    }
}

struct TimerPopoverView: View {
    @ObservedObject var model: TimerModel
    let ambient: AmbientPose
    @Binding var idleMode: IdleMode
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingEnd = false
    @State private var readoutFlow = 0.0

    private var palette: Palette { Palette.forScheme(scheme) }
    private var modeColors: ModeColors {
        palette.modeColors(for: model.isIdle ? idleMode.phase : model.phase)
    }
    private var accent: Color { modeColors.accent }

    private var title: String {
        if model.isIdle { return idleMode.title }
        if model.isPaused { return L10n.string("timer.title.paused") }
        if model.isBreak { return IdleMode(phase: model.phase).selectorLabel }
        return L10n.string("timer.title.running")
    }

    private var dialCaption: String {
        if model.isIdle { return L10n.string("timer.caption.ready") }
        return IdleMode(phase: model.phase).selectorLabel
    }

    private var idleTime: String {
        String(format: "%02d:00", idleMode.minutes(in: model.durations))
    }

    private var activeStatusText: String {
        if let endsAt = model.endsAtText, !model.isPaused {
            return L10n.format("timer.status.ends_at", endsAt)
        }
        return L10n.format("timer.status.paused_remaining", model.timeText)
    }

    private var activeStatus: some View {
        Text(activeStatusText)
            .font(Typo.sans(10.7))
            .foregroundStyle(palette.mutedInk)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeader(accent: accent, onSettings: model.openSettings)

            Text(title)
                .font(Typo.serif(34))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(height: Typo.lineHeight(34), alignment: .center)
                .padding(.top, 26)

            dialRow
                .padding(.top, 20)

            Group {
                if model.isIdle {
                    modeSelector
                } else {
                    activeStatus
                }
            }
            .frame(height: 28, alignment: .bottom)
            .padding(.top, 8)

            controls
            .padding(.top, 20)

            if let error = model.errorMessage {
                ErrorNote(message: error, onDismiss: model.dismissError)
                    .padding(.bottom, 7)
            }

            Spacer(minLength: 8)

            if !model.isIdle {
                Text(L10n.string(model.isPaused ? "timer.tip.paused" : "timer.tip.keeps_running"))
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk)
                    .padding(.top, 10)
            } else {
                Text(L10n.string("timer.tip.rhythm"))
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk)
                    .padding(.top, 10)
            }
        }
    }

    private var dialRow: some View {
        HStack(spacing: 0) {
            if model.isIdle {
                modeArrow(offset: -1)
            }
            Spacer(minLength: 0)
            DialView(
                timeText: model.isIdle ? idleTime : model.timeText,
                caption: dialCaption,
                progress: model.isIdle ? 0 : model.progress,
                accent: accent,
                size: PopoverRootView.timerDialSize,
                showsCountdown: !model.isIdle,
                readoutFlow: model.isIdle ? readoutFlow : 0,
                accessibilityLabel: dialAccessibilityLabel(
                    for: model.isIdle ? idleMode : IdleMode(phase: model.phase)
                ),
                accessibilityValue: model.isIdle
                    ? L10n.format(
                        "timer.a11y.ready_value",
                        idleMode.minutes(in: model.durations)
                    )
                    : model.isPaused
                        ? L10n.format("timer.a11y.paused_value", model.timeText)
                        : L10n.format("timer.a11y.running_value", model.timeText),
                ambient: ambient
            )
            .id(model.phase)
            Spacer(minLength: 0)
            if model.isIdle {
                modeArrow(offset: 1)
            }
        }
    }

    private var modeSelector: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(IdleMode.allCases) { mode in
                    Button {
                        guard mode != idleMode else { return }
                        // The modes are ordered left to right on screen, so a
                        // jump to a later one slides the strip left.
                        readoutFlow = mode.rawValue > idleMode.rawValue ? -1 : 1
                        idleMode = mode
                    } label: {
                        Capsule()
                            .fill(accent)
                            .frame(width: mode == idleMode ? 14 : 5, height: 5)
                            .frame(height: 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.accessibilityLabel(in: model.durations))
                    .accessibilityAddTraits(mode == idleMode ? [.isSelected] : [])
                }
            }
            Text(idleMode.selectorLabel)
                .font(Typo.sans(9, weight: "DemiBold"))
                .tracking(0.12)
                .textCase(.uppercase)
                .lineLimit(1)
                .foregroundStyle(accent)
        }
        .frame(height: 28)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: idleMode)
    }

    private func modeArrow(offset: Int) -> some View {
        let target = idleMode.neighbour(by: offset)
        let isAvailable = target != nil
        return Button {
            if let target {
                // The mode being taken sits on the arrow's side of the dial,
                // so the strip travels the other way to bring it in.
                readoutFlow = Double(-offset)
                idleMode = target
            }
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 12.5, weight: .semibold))
                .frame(width: 32, height: 32)
                .foregroundStyle(palette.mutedInk)
                .background {
                    Circle()
                        .fill(palette.plaque.opacity(0.42))
                }
                .overlay {
                    Circle()
                        .strokeBorder(palette.brass.opacity(0.30), lineWidth: 1)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .shadow(
            color: .black.opacity(0.14),
            radius: 6,
            x: ambient.dialShadowX * (scheme == .dark ? 1.3 : 1.0),
            y: 3
        )
        .accessibilityLabel(
            L10n.string(offset < 0 ? "timer.action.previous_mode" : "timer.action.next_mode")
        )
        .accessibilityValue(idleMode.selectorLabel)
        .help(
            L10n.string(offset < 0 ? "timer.action.previous_mode" : "timer.action.next_mode")
        )
        .opacity(isAvailable ? 1 : 0)
        .scaleEffect(isAvailable ? 1 : 0.84)
        .offset(x: isAvailable ? 0 : CGFloat(offset) * 6)
        .allowsHitTesting(isAvailable)
        .accessibilityHidden(!isAvailable)
        .animation(reduceMotion ? nil : AmbientMotion.curve, value: ambient)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: idleMode)
    }

    @ViewBuilder
    private var controls: some View {
        if confirmingEnd && !model.isBreak {
            endConfirmation
        } else {
            HStack(spacing: 9) {
                primaryButton

                if !model.isIdle {
                    endButton
                }
            }
        }
    }

    private var primaryButton: some View {
        Button {
            if model.isIdle {
                if idleMode == .focus {
                    model.startFocus()
                } else {
                    model.startBreak(idleMode.phase)
                }
            } else {
                model.togglePause()
            }
        } label: {
            PrimaryButtonLabel(
                title: primaryButtonTitle,
                icon: primaryButtonIcon
            )
        }
        .buttonStyle(PrimaryCTAButtonStyle(colors: modeColors, height: 49))
        .accessibilityHint(primaryButtonHint)
    }

    private var endButton: some View {
        Button {
            if model.isBreak {
                model.endInterval()
            } else {
                confirmingEnd = true
            }
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 13, weight: .semibold))
        }
        .buttonStyle(SquareButtonStyle(size: 44, foreground: palette.tomato))
        .accessibilityLabel(
            model.isBreak
                ? L10n.string("timer.action.end_break")
                : L10n.string("timer.action.end_focus")
        )
        .accessibilityHint(
            model.isBreak
                ? L10n.string("timer.action.end_break_hint")
                : L10n.string("timer.action.end_focus_hint")
        )
    }

    private var endConfirmation: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 4)
            Text(L10n.string("timer.end.confirm"))
                .font(Typo.sans(11))
                .foregroundStyle(palette.ink.opacity(0.82))
                .padding(.trailing, 10)
            Button(L10n.string("timer.end.keep_going")) {
                confirmingEnd = false
            }
            .buttonStyle(QuietTextButtonStyle())

            Button(L10n.string("timer.end.end")) {
                confirmingEnd = false
                model.endInterval()
            }
            .buttonStyle(DestructiveTextButtonStyle(color: palette.deepTomato))
        }
        .frame(height: 49)
    }

    private var primaryButtonTitle: String {
        if model.isIdle {
            return idleMode.primaryLabel(in: model.durations)
        }
        return model.isPaused
            ? L10n.string("timer.action.resume")
            : L10n.string("timer.action.pause")
    }

    private var primaryButtonIcon: String {
        if model.isIdle {
            return "play.fill"
        }
        return model.isPaused ? "play.fill" : "pause.fill"
    }

    private var primaryButtonHint: String {
        if model.isIdle {
            return L10n.string(
                idleMode.isBreak
                    ? "timer.a11y.start_break_hint"
                    : "timer.a11y.start_hint"
            )
        }
        return model.isPaused
            ? L10n.string("timer.a11y.resume_hint")
            : L10n.string("timer.a11y.pause_hint")
    }
}

struct CompletionPopoverView: View {
    @ObservedObject var model: TimerModel
    let ambient: AmbientPose
    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { Palette.forScheme(scheme) }
    private var offer: CompletionOffer { model.completionOffer }
    private var offerMode: IdleMode { IdleMode(phase: offer.phase) }
    private var modeColors: ModeColors { palette.modeColors(for: offer.phase) }
    private var accent: Color { modeColors.accent }

    private var bodyText: String {
        model.phase.isBreak
            ? L10n.string("completion.body.break_ready")
            : L10n.string("completion.body.focus_done")
    }

    private var actionTitle: String {
        offer.phase == .focus
            ? L10n.format("timer.action.start", offer.minutes)
            : L10n.format("timer.action.start_break", offer.minutes)
    }

    private var actionHint: String {
        offer.phase == .focus
            ? L10n.string("timer.a11y.start_hint")
            : L10n.string("timer.a11y.start_break_hint")
    }

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeader(accent: accent, onSettings: model.openSettings)

            Text(offerMode.title)
                .font(Typo.serif(34))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(height: Typo.lineHeight(34), alignment: .center)
                .padding(.top, 26)

            DialView(
                timeText: offer.timeText,
                caption: L10n.string("timer.caption.ready"),
                progress: 0,
                accent: accent,
                size: PopoverRootView.timerDialSize,
                accessibilityLabel: dialAccessibilityLabel(for: offerMode),
                accessibilityValue: L10n.format("timer.a11y.ready_value", offer.minutes),
                ambient: ambient
            )
            .padding(.top, 20)

            Spacer(minLength: 8)

            Text(bodyText)
                .font(Typo.sans(10.7))
                .foregroundStyle(palette.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .bottom)

            Button {
                if offer.phase == .focus {
                    model.startAnother()
                } else {
                    model.takeBreak()
                }
            } label: {
                PrimaryButtonLabel(title: actionTitle, icon: "play.fill")
            }
            .buttonStyle(PrimaryCTAButtonStyle(colors: modeColors, height: 49))
            .accessibilityHint(actionHint)
            .padding(.top, 20)

            Button(L10n.string("completion.action.done")) {
                model.doneForNow()
            }
            .buttonStyle(QuietTextButtonStyle())
            .padding(.top, 10)

            if let error = model.errorMessage {
                ErrorNote(message: error, onDismiss: model.dismissError)
                    .padding(.top, 5)
            }
        }
    }
}

private func dialAccessibilityLabel(for mode: IdleMode) -> String {
    switch mode {
    case .focus:
        L10n.string("timer.a11y.focus_dial")
    case .shortBreak:
        L10n.string("timer.a11y.short_break_dial")
    case .longBreak:
        L10n.string("timer.a11y.long_break_dial")
    }
}

private struct PrimaryButtonLabel: View {
    let title: String
    let icon: String

    var body: some View {
        ZStack {
            Text(title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack {
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.trailing, 15)
        }
    }
}

private struct DestructiveTextButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.sans(11.5, weight: "DemiBold"))
            .foregroundStyle(.white)
            .padding(.horizontal, 15)
            .frame(height: 30)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.78 : 1))
            }
    }
}
