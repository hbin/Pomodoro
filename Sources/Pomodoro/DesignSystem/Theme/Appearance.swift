import AppKit
import PomodoroCore
import SwiftUI

enum LaunchAppearance {
    static var override: NSAppearance? {
        if CommandLine.arguments.contains("--force-dark") {
            return NSAppearance(named: .darkAqua)
        }
        if CommandLine.arguments.contains("--force-light") {
            return NSAppearance(named: .aqua)
        }
        return nil
    }

    static func appearance(for preference: ThemePreference) -> NSAppearance? {
        guard let scheme = preference.colorScheme else { return nil }
        return NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    }
}

extension ThemePreference {
    var title: String {
        switch self {
        case .system: L10n.string("settings.appearance.system")
        case .light: L10n.string("settings.appearance.light")
        case .dark: L10n.string("settings.appearance.black")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
