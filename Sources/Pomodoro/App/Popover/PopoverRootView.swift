import AppKit
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var updates: UpdateController
    @Environment(\.colorScheme) private var scheme
    @State private var showsUpdatePanel = false

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

    /// The mode that owns the ambient light. Idle follows the selector, a
    /// running or paused interval follows its phase, and a completed interval
    /// follows the next interval offered by the completion screen.
    private var activeMode: IdleMode {
        if model.isIdle {
            return IdleMode(phase: model.idlePhase)
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
                        showsUpdatePanel: $showsUpdatePanel,
                        onQuit: { NSApp.terminate(nil) },
                        onClose: model.closeSettings,
                        onContentHeight: model.reportSettingsContentHeight
                    )
                } else {
                    content
                }
            }
            .padding(.horizontal, SettingsCardMetrics.horizontalInset)
            .padding(.top, SettingsCardMetrics.topInset)
            .padding(.bottom, SettingsCardMetrics.bottomInset)

            if model.isShowingSettings, showsUpdatePanel {
                SettingsCardMarginDismissOverlay {
                    showsUpdatePanel = false
                }
            }
        }
        .frame(
            width: Self.contentWidth(showingSettings: model.isShowingSettings),
            height: Self.contentHeight(
                showingSettings: model.isShowingSettings,
                settingsContent: model.settingsContentHeight
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onChange(of: model.isShowingSettings) { _, isShowing in
            if !isShowing {
                showsUpdatePanel = false
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isCompleted {
            CompletionPopoverView(model: model, ambient: ambient)
        } else {
            TimerPopoverView(
                model: model,
                ambient: ambient,
                completionStartSweep: model.completionStartSweepPending
            )
        }
    }
}

private enum SettingsCardMetrics {
    static let horizontalInset: CGFloat = 20
    static let topInset: CGFloat = 19
    static let bottomInset: CGFloat = 18
}

/// Captures clicks in the card chrome outside `SettingsView`'s content bounds.
/// The content-area overlay remains inside `SettingsView`; together they cover
/// the whole card while leaving the update panel interactive.
private struct SettingsCardMarginDismissOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .contentShape(SettingsCardMarginShape(), eoFill: true)
            .onTapGesture(perform: onDismiss)
            .accessibilityHidden(true)
    }
}

private struct SettingsCardMarginShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(
            CGRect(
                x: rect.minX + SettingsCardMetrics.horizontalInset,
                y: rect.minY + SettingsCardMetrics.topInset,
                width: max(0, rect.width - SettingsCardMetrics.horizontalInset * 2),
                height: max(
                    0,
                    rect.height
                        - SettingsCardMetrics.topInset
                        - SettingsCardMetrics.bottomInset
                )
            )
        )
        return path
    }
}
