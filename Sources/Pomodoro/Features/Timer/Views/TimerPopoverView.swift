import SwiftUI

struct TimerPopoverView: View {
    @ObservedObject var model: TimerModel
    let ambient: AmbientPose
    let completionStartSweep: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isEndControlFocused: Bool
    @State private var readoutFlow = 0.0

    private var palette: Palette { Palette.forScheme(scheme) }
    private var idleMode: IdleMode { IdleMode(phase: model.idlePhase) }
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
                .onChange(of: model.runState) { _, runState in
                    guard runState != .running else { return }
                    isEndControlFocused = false
                }

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
        .onAppear {
            model.consumeCompletionStartSweep()
        }
    }

    private var dialRow: some View {
        HStack(spacing: 0) {
            if model.isIdle {
                modeArrow(offset: -1)
            }
            Spacer(minLength: 0)
            // Keep one dial from Ready into the selected running mode so its
            // ring can sweep from empty before beginning to drain.
            DialView(
                timeText: model.isIdle ? idleTime : model.timeText,
                caption: dialCaption,
                progress: model.isIdle ? 0 : model.progress,
                accent: accent,
                size: PopoverRootView.timerDialSize,
                showsCountdown: !model.isIdle,
                readoutFlow: model.isIdle ? readoutFlow : 0,
                readoutIdentity: idleMode.rawValue,
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
                ambient: ambient,
                sweepsOnAppear: completionStartSweep && model.isRunning && !reduceMotion
            )
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
                        model.selectIdlePhase(mode.phase)
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
                model.selectIdlePhase(target.phase)
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

    private var controls: some View {
        ZStack {
            primaryButton
                .frame(width: ControlMetrics.primaryWidth, height: ControlMetrics.rowHeight)

            if model.isRunning {
                endButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: ControlMetrics.rowHeight)
    }

    private var primaryButton: some View {
        Button {
            if model.isIdle {
                model.startIdleInterval()
            } else {
                model.togglePause()
            }
        } label: {
            PrimaryButtonLabel(
                title: primaryButtonTitle,
                icon: primaryButtonIcon
            )
        }
        .buttonStyle(PrimaryCTAButtonStyle(colors: modeColors, height: ControlMetrics.rowHeight))
        .frame(width: ControlMetrics.primaryWidth, height: ControlMetrics.rowHeight)
        .accessibilityHint(primaryButtonHint)
    }

    private var endButton: some View {
        Button {
            endFromControl()
        } label: {
            Image(systemName: "forward.end.fill")
        }
        .focused($isEndControlFocused)
        .buttonStyle(
            EndControlButtonStyle(
                palette: palette,
                isFocused: isEndControlFocused
            )
        )
        .focusEffectDisabled()
        .help(endControlLabel)
        .accessibilityLabel(endControlLabel)
        .accessibilityHint(endControlHint)
        .onKeyPress(.return) {
            guard model.isRunning else { return .ignored }
            endFromControl()
            return .handled
        }
    }

    private var endControlLabel: String {
        L10n.string(model.isBreak ? "timer.action.end_break" : "timer.action.end_focus")
    }

    private var endControlHint: String {
        L10n.string(model.isBreak ? "timer.action.end_break_hint" : "timer.action.end_focus_hint")
    }

    private func endFromControl() {
        guard model.isRunning else { return }
        isEndControlFocused = false
        model.endInterval()
    }

    private var primaryButtonTitle: String {
        model.isRunning
            ? L10n.string("timer.action.pause")
            : L10n.string("timer.action.start")
    }

    private var primaryButtonIcon: String {
        model.isRunning ? "pause.fill" : "play.fill"
    }

    private var primaryButtonHint: String {
        if model.isRunning {
            return L10n.string("timer.a11y.pause_hint")
        }
        let mode = model.isIdle ? idleMode : IdleMode(phase: model.phase)
        return L10n.string(
            mode.isBreak
                ? "timer.a11y.start_break_hint"
                : "timer.a11y.start_hint"
        )
    }
}

func dialAccessibilityLabel(for mode: IdleMode) -> String {
    switch mode {
    case .focus:
        L10n.string("timer.a11y.focus_dial")
    case .shortBreak:
        L10n.string("timer.a11y.short_break_dial")
    case .longBreak:
        L10n.string("timer.a11y.long_break_dial")
    }
}
