import AppKit
import PomodoroCore
import SwiftUI

@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let model: TimerModel
    private let popover = NSPopover()
    private let reopenDelay: TimeInterval = 0.25
    private static let menuBarAnchorWidth: CGFloat = 32
    private var anchorWindow: NSWindow?
    private var lastCloseDate: Date?
    var onWillShow: (() -> Void)?
    var onDidClose: (() -> Void)?

    init(model: TimerModel) {
        self.model = model
        super.init()

        let host = NSHostingController(
            rootView: PopoverRootView(model: model)
        )
        host.view.frame = NSRect(
            x: 0,
            y: 0,
            width: PopoverRootView.width,
            height: PopoverRootView.height
        )
        popover.contentViewController = host
        popover.contentSize = NSSize(width: PopoverRootView.width, height: PopoverRootView.height)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        applyAppearance(model.themePreference)
    }

    var isShown: Bool { popover.isShown }

    func applyAppearance(_ preference: ThemePreference) {
        popover.appearance = LaunchAppearance.appearance(for: preference)
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            close()
            return
        }
        if let lastCloseDate, Date().timeIntervalSince(lastCloseDate) < reopenDelay {
            return
        }
        show(relativeTo: button)
    }

    func show(relativeTo button: NSStatusBarButton) {
        NSApp.activate(ignoringOtherApps: true)
        guard let window = makeAnchorWindow(relativeTo: button),
              let anchorView = window.contentView else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            return
        }
        anchorWindow = window
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    /// The status item shrinks before it shifts over when the countdown title
    /// disappears. NSPopover latches onto that intermediate position, so anchor
    /// it to a transparent window that stays put instead.
    private func makeAnchorWindow(relativeTo button: NSStatusBarButton) -> NSWindow? {
        guard let buttonWindow = button.window else { return nil }
        let buttonRect = buttonWindow.convertToScreen(button.bounds)
        let width = min(Self.menuBarAnchorWidth, buttonRect.width)
        let window = AnchorWindow(
            contentRect: NSRect(
                x: buttonRect.maxX - width,
                y: buttonRect.minY,
                width: width,
                height: buttonRect.height
            ),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.isExcludedFromWindowsMenu = true
        window.orderFrontRegardless()
        return window
    }

    func close() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func popoverWillShow(_ notification: Notification) {
        onWillShow?()
    }

    func popoverWillClose(_ notification: Notification) {
        lastCloseDate = Date()
    }

    func popoverDidClose(_ notification: Notification) {
        anchorWindow?.orderOut(nil)
        anchorWindow = nil
        onDidClose?()
    }
}

private final class AnchorWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
