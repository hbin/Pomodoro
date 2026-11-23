import AppKit
import PomodoroCore
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var updates: UpdateController
    @Environment(\.colorScheme) private var scheme

    static let width: CGFloat = 380
    static let height: CGFloat = 544
    static let settingsHeight: CGFloat = 520

    static func contentHeight(showingSettings: Bool) -> CGFloat {
        showingSettings ? settingsHeight : height
    }

    var body: some View {
        ZStack {
            PopoverBackground()
            Group {
                if model.isShowingSettings {
                    SettingsView(
                        model: model,
                        updates: updates,
                        onQuit: { NSApp.terminate(nil) },
                        onClose: model.closeSettings
                    )
                } else {
                    content
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 19)
            .padding(.bottom, 18)
        }
        .frame(
            width: Self.width,
            height: Self.contentHeight(showingSettings: model.isShowingSettings)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if model.isCompleted {
            CompletionPopoverView(model: model)
        } else {
            TimerPopoverView(model: model)
        }
    }
}

struct TimerPopoverView: View {
    @ObservedObject var model: TimerModel
    @Environment(\.colorScheme) private var scheme
    @State private var confirmingEnd = false

    private var palette: Palette { Palette.forScheme(scheme) }
    private var accent: Color {
        model.isIdle ? palette.tomato : palette.accent(for: model.phase)
    }

    private var title: String {
        if model.isIdle { return L10n.string("timer.title.idle") }
        if model.isPaused { return L10n.string("timer.title.paused") }
        if model.isBreak { return L10n.string("timer.title.break") }
        return L10n.string("timer.title.running")
    }

    private var dialCaption: String {
        model.isIdle ? L10n.string("timer.caption.ready") : model.readoutCaption
    }

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeader(accent: accent, onSettings: model.openSettings)

            Text(title)
                .font(Typo.serif(34))
                .foregroundStyle(palette.ink)
                .padding(.top, 20)

            DialView(
                timeText: model.timeText,
                caption: dialCaption,
                progress: model.isIdle ? 0 : model.progress,
                accent: accent,
                size: 215,
                showsCountdown: !model.isIdle,
                handProgress: model.dialHandProgress,
                accessibilityLabel: model.isBreak
                    ? L10n.string("timer.a11y.break_dial")
                    : L10n.string("timer.a11y.focus_dial"),
                accessibilityValue: model.isIdle
                    ? L10n.format("timer.a11y.ready_value", model.selectedFocusMinutes)
                    : model.isPaused
                        ? L10n.format("timer.a11y.paused_value", model.timeText)
                        : L10n.format("timer.a11y.running_value", model.timeText)
            )
            .padding(.top, 11)

            Group {
                if model.isIdle {
                    intervalPicker
                } else {
                    activeStatus
                }
            }
            .frame(height: 54)
            .padding(.top, 16)

            controls
            .padding(.top, 17)

            Spacer(minLength: 8)

            if let error = model.errorMessage {
                ErrorNote(message: error, onDismiss: model.dismissError)
                    .padding(.bottom, 7)
            }

            if !model.isIdle {
                Text(L10n.string("timer.tip.keeps_running"))
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk.opacity(0.78))
            } else if !model.firstRunTipDismissed {
                HStack(spacing: 7) {
                    Text(L10n.string("timer.tip.first_run"))
                        .font(Typo.sans(9.7))
                        .foregroundStyle(palette.mutedInk)
                    Spacer(minLength: 2)
                    Button {
                        model.dismissFirstRunTip()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(IconButtonStyle(size: 19))
                    .accessibilityLabel(L10n.string("timer.tip.dismiss"))
                }
                .padding(.horizontal, 2)
            } else {
                Text(L10n.string("timer.tip.rhythm"))
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk.opacity(0.78))
            }
        }
    }

    private var intervalPicker: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Text(L10n.string("timer.interval.label"))
                    .font(Typo.label(8.7))
                    .tracking(Typo.tracking(1.8))
                    .foregroundStyle(palette.mutedInk)
                Spacer()
                Text(L10n.string("timer.interval.long_break_hint"))
                    .font(Typo.sans(9.5))
                    .foregroundStyle(palette.mutedInk.opacity(0.8))
            }

            HStack(spacing: 8) {
                ForEach(TimerEngine.focusChoices, id: \.self) { minutes in
                    DurationChip(
                        minutes: minutes,
                        isSelected: model.selectedFocusMinutes == minutes
                    ) {
                        model.selectFocusMinutes(minutes)
                    }
                }
            }
        }
    }

    private var activeStatus: some View {
        VStack(spacing: 3) {
            if let endsAt = model.endsAtText, !model.isPaused {
                Text(L10n.format("timer.status.ends_at", endsAt))
                    .font(Typo.sans(10.7))
                    .foregroundStyle(palette.mutedInk)
            } else {
                Text(L10n.format("timer.status.paused_remaining", model.timeText))
                    .font(Typo.sans(10.7))
                    .foregroundStyle(palette.mutedInk)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                model.startFocus()
            } else {
                model.togglePause()
            }
        } label: {
            HStack(spacing: 8) {
                Text(primaryButtonTitle)
                    .lineLimit(1)
                Spacer()
                Image(systemName: primaryButtonIcon)
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(
            PrimaryInstrumentButtonStyle(
                color: primaryButtonColor,
                textColor: primaryButtonTextColor,
                height: 49
            )
        )
        .accessibilityHint(primaryButtonHint)
    }

    private var primaryButtonColor: Color {
        model.isIdle ? palette.leaf : accent
    }

    private var primaryButtonTextColor: Color {
        model.isIdle ? palette.onLeaf : .white
    }

    private var endButton: some View {
        Button {
            if model.isBreak {
                model.endInterval()
            } else {
                confirmingEnd = true
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
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
            Text(L10n.string("timer.end.confirm"))
                .font(Typo.sans(11))
                .foregroundStyle(palette.ink.opacity(0.82))
            Spacer(minLength: 4)
            Button(L10n.string("timer.end.keep_going")) {
                confirmingEnd = false
            }
            .buttonStyle(QuietTextButtonStyle())

            Button(L10n.string("timer.end.end")) {
                confirmingEnd = false
                model.endInterval()
            }
            .buttonStyle(QuietTextButtonStyle(color: palette.tomato))
        }
        .frame(height: 49)
    }

    private var primaryButtonTitle: String {
        if model.isIdle {
            return L10n.format("timer.action.start", model.selectedFocusMinutes)
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
            return L10n.string("timer.a11y.start_hint")
        }
        return model.isPaused
            ? L10n.string("timer.a11y.resume_hint")
            : L10n.string("timer.a11y.pause_hint")
    }
}

struct CompletionPopoverView: View {
    @ObservedObject var model: TimerModel
    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { Palette.forScheme(scheme) }
    private var accent: Color { palette.accent(for: model.phase) }

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeader(accent: accent, onSettings: model.openSettings)

            Text(L10n.string("timer.caption.complete"))
                .font(Typo.label(8.7))
                .tracking(Typo.tracking(2.1))
                .foregroundStyle(palette.mutedInk)
                .padding(.top, 22)

            Text(
                model.isBreak
                    ? L10n.string("completion.title.break")
                    : L10n.string("completion.title.focus")
            )
            .font(Typo.serif(32))
            .foregroundStyle(palette.ink)
            .padding(.top, 3)

            DialView(
                timeText: "00:00",
                caption: L10n.string("timer.caption.complete"),
                progress: 1,
                accent: accent,
                size: 168,
                accessibilityLabel: model.isBreak
                    ? L10n.string("completion.title.break")
                    : L10n.string("completion.title.focus"),
                accessibilityValue: L10n.string("completion.a11y.complete")
            )
            .padding(.top, 12)

            Text(
                model.isBreak
                    ? L10n.string("completion.body.break_ready")
                    : L10n.string("completion.body.focus_done")
            )
            .font(Typo.sans(10.7))
            .foregroundStyle(palette.mutedInk)
            .padding(.top, 7)

            Spacer(minLength: 10)

            if model.isBreak {
                Button {
                    model.startAnother()
                } label: {
                    HStack(spacing: 8) {
                        Text(L10n.string("completion.action.start_another"))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                }
                .buttonStyle(
                    PrimaryInstrumentButtonStyle(
                        color: palette.leaf,
                        textColor: palette.onLeaf,
                        height: 48
                    )
                )
            } else {
                Button {
                    model.takeBreak()
                } label: {
                    HStack(spacing: 8) {
                        Text(L10n.format("completion.action.take_break", model.recommendedBreakMinutes))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PrimaryInstrumentButtonStyle(color: palette.deepAccent(for: .shortBreak), height: 48))

                Button(L10n.string("completion.action.start_another")) {
                    model.startAnother()
                }
                .buttonStyle(OutlineButtonStyle(height: 41))
                .padding(.top, 8)
            }

            Button(L10n.string("completion.action.done")) {
                model.doneForNow()
            }
            .buttonStyle(QuietTextButtonStyle())
            .padding(.top, 5)

            if let error = model.errorMessage {
                ErrorNote(message: error, onDismiss: model.dismissError)
                    .padding(.top, 5)
            }
        }
    }
}
