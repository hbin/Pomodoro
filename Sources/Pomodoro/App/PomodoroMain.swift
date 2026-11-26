import AppKit

@main
@MainActor
struct PomodoroMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.appearance = LaunchAppearance.override
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
