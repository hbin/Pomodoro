import Foundation

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
