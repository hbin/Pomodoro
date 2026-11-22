import AppKit
import Combine
import PomodoroCore
import SwiftUI

@MainActor
final class PopoverController: NSObject {
    private let model: TimerModel
    private let updates: UpdateController
    private let host: NSHostingController<PopoverRootView>
    private let panel: TimerPanel
    private let reopenDelay: TimeInterval = 0.25
    private static let menuBarAnchorWidth: CGFloat = 32
    private static let panelTopGap: CGFloat = 5
    private static let screenEdgeInset: CGFloat = 8
    private var lastCloseDate: Date?
    private var settingsObservation: AnyCancellable?
    private var appResignObserver: NSObjectProtocol?
    private var localMouseMonitor: Any?
    var onWillShow: (() -> Void)?
    var onDidClose: (() -> Void)?

    init(model: TimerModel, updates: UpdateController) {
        self.model = model
        self.updates = updates
        let host = NSHostingController(
            rootView: PopoverRootView(model: model, updates: updates)
        )
        self.host = host
        let initialHeight = PopoverRootView.contentHeight(
            showingSettings: model.isShowingSettings
        )
        host.view.frame = NSRect(
            x: 0,
            y: 0,
            width: PopoverRootView.width,
            height: initialHeight
        )
        let panel = TimerPanel(
            contentRect: host.view.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        super.init()

        panel.contentViewController = host
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .transient
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.tabbingMode = .disallowed
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.onCancel = { [weak self] in
            self?.close()
        }
        setAppearance(
            LaunchAppearance.override
                ?? LaunchAppearance.appearance(for: model.themePreference)
        )

        settingsObservation = model.$isShowingSettings
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isShowingSettings in
                self?.resize(for: isShowingSettings)
            }

        appResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.close()
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            if let self, event.window !== self.panel {
                self.close()
            }
            return event
        }
    }

    var isShown: Bool { panel.isVisible }

    func applyAppearance(_ preference: ThemePreference) {
        setAppearance(LaunchAppearance.appearance(for: preference))
    }

    private func setAppearance(_ appearance: NSAppearance?) {
        panel.appearance = appearance
    }

    private func resize(for isShowingSettings: Bool) {
        let height = PopoverRootView.contentHeight(showingSettings: isShowingSettings)
        guard panel.frame.height != height else { return }

        var frame = panel.frame
        let top = frame.maxY
        frame.size = NSSize(width: PopoverRootView.width, height: height)
        if panel.isVisible {
            frame.origin.y = top - height
        }
        panel.setFrame(frame, display: panel.isVisible)
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if panel.isVisible {
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
        guard let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }

        let buttonRect = buttonWindow.convertToScreen(button.bounds)
        let height = PopoverRootView.contentHeight(
            showingSettings: model.isShowingSettings
        )
        let anchorWidth = min(Self.menuBarAnchorWidth, buttonRect.width)
        let anchorCenterX = buttonRect.maxX - anchorWidth / 2
        let visibleFrame = screen.visibleFrame
        let maxX = visibleFrame.maxX - PopoverRootView.width - Self.screenEdgeInset
        let x = min(
            max(anchorCenterX - PopoverRootView.width / 2, visibleFrame.minX + Self.screenEdgeInset),
            maxX
        )
        let y = max(
            buttonRect.minY - Self.panelTopGap - height,
            visibleFrame.minY + Self.screenEdgeInset
        )

        panel.setFrame(
            NSRect(x: x, y: y, width: PopoverRootView.width, height: height),
            display: true
        )
        onWillShow?()
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
    }

    func close() {
        guard panel.isVisible else { return }
        lastCloseDate = Date()
        panel.orderOut(nil)
        onDidClose?()
    }

}

@MainActor
private final class TimerPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
