import Foundation

enum LanguagePreference: Hashable, Sendable {
    case system
    case language(AppLanguage)

    var effectiveLanguage: AppLanguage {
        switch self {
        case .system: .systemDefault
        case .language(let language): language
        }
    }

    var title: String {
        switch self {
        case .system: L10n.string("settings.language.system")
        case .language(let language): language.autonym
        }
    }

    var detail: String {
        switch self {
        case .system: L10n.string("settings.language.system_detail")
        case .language: L10n.string("settings.language.detail")
        }
    }
}

enum LanguagePreferenceStore {
    static let defaultsKey = "PomodoroLanguagePreference"

    static func load(from defaults: UserDefaults = .standard) -> LanguagePreference {
        guard let identifier = defaults.string(forKey: defaultsKey),
              let language = AppLanguage(rawValue: identifier) else {
            return .system
        }
        return .language(language)
    }

    static func save(
        _ preference: LanguagePreference,
        to defaults: UserDefaults = .standard
    ) {
        switch preference {
        case .system:
            defaults.removeObject(forKey: defaultsKey)
        case .language(let language):
            defaults.set(language.rawValue, forKey: defaultsKey)
        }
    }
}
