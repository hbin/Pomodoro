import AppKit
import PomodoroCore
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var model: TimerModel
    @Environment(\.colorScheme) private var scheme

    static let width: CGFloat = 380
    static let height: CGFloat = 544

    var body: some View {
        ZStack {
            PopoverBackground()
            Group {
                if model.isShowingSettings {
                    SettingsView(
                        model: model,
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
        .frame(width: Self.width, height: Self.height)
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
        if model.isIdle { return "Ready to focus" }
        if model.isPaused { return "Holding pause" }
        if model.isBreak { return "Step away" }
        return "Focus in progress"
    }

    private var dialCaption: String {
        model.isIdle ? "READY" : model.readoutCaption
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
                accessibilityLabel: model.isBreak ? "Break timer" : "Focus timer",
                accessibilityValue: model.isIdle
                    ? "\(model.selectedFocusMinutes) minutes, ready"
                    : "\(model.timeText), \(model.isPaused ? "paused" : "running")"
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
                Text("You can close this popover; the timer keeps running.")
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk.opacity(0.78))
            } else if !model.firstRunTipDismissed {
                HStack(spacing: 7) {
                    Text("The dial lives in your menu bar. Click it anytime.")
                        .font(Typo.sans(9.7))
                        .foregroundStyle(palette.mutedInk)
                    Spacer(minLength: 2)
                    Button {
                        model.dismissFirstRunTip()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(IconButtonStyle(size: 19))
                    .accessibilityLabel("Dismiss tip")
                }
                .padding(.horizontal, 2)
            } else {
                Text("Enjoy the rhythm of focused time.")
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk.opacity(0.78))
            }
        }
    }

    private var intervalPicker: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Text("INTERVAL")
                    .font(Typo.label(8.7))
                    .tracking(1.8)
                    .foregroundStyle(palette.mutedInk)
                Spacer()
                Text("long break after 4")
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
                Text("Ends at \(endsAt)")
                    .font(Typo.sans(10.7))
                    .foregroundStyle(palette.mutedInk)
            } else {
                Text("Paused · \(model.timeText) remaining")
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
        .accessibilityLabel(model.isBreak ? "End break" : "End focus interval")
        .accessibilityHint(model.isBreak ? "Ends the break now" : "Asks for confirmation before ending focus")
    }

    private var endConfirmation: some View {
        HStack(spacing: 8) {
            Text("End this focus?")
                .font(Typo.sans(11))
                .foregroundStyle(palette.ink.opacity(0.82))
            Spacer(minLength: 4)
            Button("Keep going") {
                confirmingEnd = false
            }
            .buttonStyle(QuietTextButtonStyle())

            Button("End") {
                confirmingEnd = false
                model.endInterval()
            }
            .buttonStyle(QuietTextButtonStyle(color: palette.tomato))
        }
        .frame(height: 49)
    }

    private var primaryButtonTitle: String {
        if model.isIdle {
            return "Start \(model.selectedFocusMinutes)-minute focus"
        }
        return model.isPaused ? "Resume" : "Pause"
    }

    private var primaryButtonIcon: String {
        if model.isIdle {
            return "play.fill"
        }
        return model.isPaused ? "play.fill" : "pause.fill"
    }

    private var primaryButtonHint: String {
        if model.isIdle {
            return "Starts a focus interval in this popover"
        }
        return model.isPaused ? "Resumes the timer" : "Pauses the timer"
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

            Text("COMPLETE")
                .font(Typo.label(8.7))
                .tracking(2.1)
                .foregroundStyle(palette.mutedInk)
                .padding(.top, 22)

            Text(model.isBreak ? "Break complete" : "Focus complete")
                .font(Typo.serif(32))
                .foregroundStyle(palette.ink)
                .padding(.top, 3)

            DialView(
                timeText: "00:00",
                caption: "COMPLETE",
                progress: 1,
                accent: accent,
                size: 168,
                accessibilityLabel: model.isBreak ? "Break complete" : "Focus complete",
                accessibilityValue: "Complete"
            )
            .padding(.top, 12)

            Text(model.isBreak
                 ? "Start another focus whenever you’re ready."
                 : "Nothing starts until you choose.")
                .font(Typo.sans(10.7))
                .foregroundStyle(palette.mutedInk)
                .padding(.top, 7)

            Spacer(minLength: 10)

            if model.isBreak {
                Button {
                    model.startAnother()
                } label: {
                    HStack(spacing: 8) {
                        Text("Start another focus")
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
                        Text("Take a \(model.recommendedBreakMinutes)-minute break")
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PrimaryInstrumentButtonStyle(color: palette.deepAccent(for: .shortBreak), height: 48))

                Button("Start another focus") {
                    model.startAnother()
                }
                .buttonStyle(OutlineButtonStyle(height: 41))
                .padding(.top, 8)
            }

            Button("Done for now") {
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
