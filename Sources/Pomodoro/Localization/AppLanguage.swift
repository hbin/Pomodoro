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
