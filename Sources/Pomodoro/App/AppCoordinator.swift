import AppKit
import PomodoroCore

@MainActor
final class AppCoordinator: NSObject {
    private let model: TimerModel
    private let statusItem: StatusItemController
    private let popover: PopoverController

    override init() {
        let model = TimerModel()
        self.model = model
        self.statusItem = StatusItemController()
        self.popover = PopoverController(model: model)
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

    @objc
    private func openSettingsFromMenu() {
        model.openSettings()
        if !popover.isShown {
            showPopover()
        }
    }
}
