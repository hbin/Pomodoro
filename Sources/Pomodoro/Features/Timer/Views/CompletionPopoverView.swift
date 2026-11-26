import SwiftUI

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
        L10n.string("timer.action.start")
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
