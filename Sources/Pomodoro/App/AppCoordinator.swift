import AppKit
import PomodoroCore

@MainActor
final class AppCoordinator: NSObject, NSMenuItemValidation {
    private let model: TimerModel
    private let statusItem: StatusItemController
    private let popover: PopoverController
    private let updates: UpdateController

    override init() {
        let model = TimerModel()
        let updates = UpdateController()
        self.model = model
        self.statusItem = StatusItemController()
        self.updates = updates
        self.popover = PopoverController(model: model, updates: updates)
        super.init()

        statusItem.onClick = { [weak self] in
            self?.togglePopover()
        }
        statusItem.onRightClick = { [weak self] in
            self?.makeStatusMenu()
        }
        model.onMenuBarChange = { [weak self] descriptor in
            self?.statusItem.update(descriptor)
        }
        model.onAppearanceChange = { [weak self] preference in
            self?.applyAppearance(preference)
        }
        popover.onWillShow = { [weak self] in
            self?.model.refreshNotificationStatus()
        }
        popover.onDidClose = { [weak self] in
            self?.model.closeSettings()
        }
    }

    func start() {
        if LaunchAppearance.override == nil {
            applyAppearance(model.themePreference)
        }
        buildMainMenu()
        model.activate()
        statusItem.update(model.menuBarDescriptor)

        let shouldOpenSettings = CommandLine.arguments.contains("--open-settings")
        if shouldOpenSettings {
            model.openSettings()
        }

        let shouldOpenOnLaunch = model.isFirstRun
            || model.errorMessage != nil
            || CommandLine.arguments.contains("--open-popover")
            || shouldOpenSettings
        if shouldOpenOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.showPopover()
            }
        }

        updates.start()
    }

    func shutdown() {
        model.saveNow()
    }

    private func showPopover() {
        guard let button = statusItem.anchorButton else { return }
        popover.show(relativeTo: button)
    }

    private func togglePopover() {
        guard let button = statusItem.anchorButton else { return }
        popover.toggle(relativeTo: button)
    }

    private func applyAppearance(_ preference: ThemePreference) {
        NSApp.appearance = LaunchAppearance.appearance(for: preference)
        popover.applyAppearance(preference)
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "Pomodoro")
        appItem.submenu = appMenu

        let about = NSMenuItem(
            title: "About Pomodoro",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        about.target = NSApp
        appMenu.addItem(about)

        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesFromMenu(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = self
        checkForUpdates.isEnabled = updates.canCheckForUpdates
        appMenu.addItem(checkForUpdates)
        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Pomodoro",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        appMenu.addItem(quit)

        NSApp.mainMenu = mainMenu
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesFromMenu(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = self
        checkForUpdates.isEnabled = updates.canCheckForUpdates
        menu.addItem(checkForUpdates)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Pomodoro",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdatesFromMenu(_:)) {
            return updates.canCheckForUpdates
        }
        return true
    }

    @objc
    private func openSettingsFromMenu() {
        model.openSettings()
        if !popover.isShown {
            showPopover()
        }
    }

    @objc
    private func checkForUpdatesFromMenu(_ sender: Any?) {
        popover.close()
        updates.checkForUpdates()
    }
}
