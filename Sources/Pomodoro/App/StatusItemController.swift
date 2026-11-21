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
        button.setAccessibilityLabel("Pomodoro timer")
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
        button.image = MenuBarIconFactory.image(
            progress: descriptor.progress,
            isPaused: descriptor.isPaused,
            showsRemainingTime: descriptor.isActive || descriptor.isCompleted
        )
        button.title = descriptor.title.isEmpty ? "" : " \(descriptor.title)"
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        let phase = descriptor.isBreak ? "Break" : "Focus"
        let value: String
        if descriptor.isActive {
            value = "\(phase), \(descriptor.remainingMinutes) minutes remaining"
                + (descriptor.isPaused ? ", paused" : "")
        } else if descriptor.isCompleted {
            value = "\(phase) complete"
        } else {
            value = "Ready to focus"
        }
        button.setAccessibilityValue(value)
        button.toolTip = descriptor.isActive || descriptor.isCompleted
            ? "Pomodoro — \(value)"
            : "Pomodoro — ready to focus"
    }

    var anchorButton: NSStatusBarButton? {
        statusItem.button
    }
}
