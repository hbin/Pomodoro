import AppKit

@main
@MainActor
struct PomodoroMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--force-dark") {
            application.appearance = NSAppearance(named: .darkAqua)
        } else if CommandLine.arguments.contains("--force-light") {
            application.appearance = NSAppearance(named: .aqua)
        }
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
