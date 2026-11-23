import AppKit

@MainActor
final class StatusItemController: NSObject {
    let statusItem: NSStatusItem
    var onClick: (() -> Void)?
    var onRightClick: (() -> NSMenu?)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        guard let button = statusItem.button else { return }
        button.image = MenuBarIconFactory.image(progress: 0, isPaused: false)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Pomodoro"
        button.setAccessibilityLabel(L10n.string("status_bar.accessibility_label"))
    }

    @objc
    private func handleClick(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            if let menu = onRightClick?(), let button = statusItem.button {
                menu.popUp(
                    positioning: nil,
                    at: NSPoint(x: 0, y: button.bounds.height + 4),
                    in: button
                )
            }
            return
        }
        onClick?()
    }

    func update(_ descriptor: MenuBarDescriptor) {
        guard let button = statusItem.button else { return }
        button.setAccessibilityLabel(L10n.string("status_bar.accessibility_label"))
        button.image = MenuBarIconFactory.image(
            progress: descriptor.progress,
            isPaused: descriptor.isPaused,
            isBreak: descriptor.isBreak,
            showsRemainingTime: descriptor.isActive || descriptor.isCompleted
        )
        button.title = descriptor.showsRemainingMinutes
            ? " " + L10n.count("common.minutes_compact", descriptor.remainingMinutes)
            : ""
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        let value: String
        if descriptor.isActive {
            if descriptor.isBreak {
                value = descriptor.isPaused
                    ? L10n.count("status_bar.a11y.break_paused", descriptor.remainingMinutes)
                    : L10n.count("status_bar.a11y.break_running", descriptor.remainingMinutes)
            } else {
                value = descriptor.isPaused
                    ? L10n.count("status_bar.a11y.focus_paused", descriptor.remainingMinutes)
                    : L10n.count("status_bar.a11y.focus_running", descriptor.remainingMinutes)
            }
        } else if descriptor.isCompleted {
            value = descriptor.isBreak
                ? L10n.string("status_bar.a11y.break_complete")
                : L10n.string("status_bar.a11y.focus_complete")
        } else {
            value = L10n.string("status_bar.a11y.ready")
        }
        button.setAccessibilityValue(value)
        button.toolTip = descriptor.isActive || descriptor.isCompleted
            ? L10n.format("status_bar.tooltip", value)
            : L10n.string("status_bar.tooltip.ready")
    }

    var anchorButton: NSStatusBarButton? {
        statusItem.button
    }
}
