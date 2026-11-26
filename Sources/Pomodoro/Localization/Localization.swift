import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case vietnamese = "vi"
    case korean = "ko"

    var id: String { rawValue }

    var autonym: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .vietnamese: "Tiếng Việt"
        case .korean: "한국어"
        }
    }

    static let systemDefault: AppLanguage = {
        guard let identifier = Bundle.main.preferredLocalizations.first else {
            return .english
        }
        return AppLanguage(identifier: identifier)
    }()

    init(identifier: String) {
        let normalized = identifier
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        let primaryLanguage = String(
            normalized.prefix { $0 != "-" }
        )

        switch primaryLanguage {
        case "zh":
            if normalized.contains("hant")
                || normalized.hasPrefix("zh-tw")
                || normalized.hasPrefix("zh-hk")
                || normalized.hasPrefix("zh-mo") {
                self = .traditionalChinese
            } else {
                self = .simplifiedChinese
            }
        case "en": self = .english
        case "ja": self = .japanese
        case "vi": self = .vietnamese
        case "ko": self = .korean
        default: self = .english
        }
    }
}

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

enum L10n {
    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var language: AppLanguage
        private let bundles: [AppLanguage: Bundle]

        init() {
            language = LanguagePreferenceStore.load().effectiveLanguage

            var bundles: [AppLanguage: Bundle] = [:]
            for language in AppLanguage.allCases {
                guard let path = Bundle.main.path(
                    forResource: language.rawValue,
                    ofType: "lproj"
                ), let bundle = Bundle(path: path) else {
                    continue
                }
                bundles[language] = bundle
            }
            self.bundles = bundles
        }

        var activeLanguage: AppLanguage {
            lock.lock()
            defer { lock.unlock() }
            return language
        }

        func setActiveLanguage(_ language: AppLanguage) {
            lock.lock()
            defer { lock.unlock() }
            self.language = language
        }

        func bundle(for language: AppLanguage) -> Bundle? {
            bundles[language]
        }
    }

    private static let state = State()

    static var activeLanguage: AppLanguage {
        state.activeLanguage
    }

    static func setActiveLanguage(_ language: AppLanguage) {
        state.setActiveLanguage(language)
    }

    static func string(_ key: String.LocalizationValue) -> String {
        let language = state.activeLanguage
        return String(
            localized: key,
            bundle: state.bundle(for: language) ?? .main
        )
    }

    static func format(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }

    static func count(_ key: String.LocalizationValue, _ count: Int) -> String {
        // String.localizedStringWithFormat selects plurals with Locale.current,
        // which can disagree with the app language. String(format:) resolves
        // the catalog's plural rule with the localized format itself.
        String(format: string(key), count)
    }
}
