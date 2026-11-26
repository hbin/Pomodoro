import AppKit
import SwiftUI

enum Typo {
    private enum InterfaceLanguage {
        case english
        case simplifiedChinese
        case traditionalChinese
        case japanese
        case vietnamese
        case korean
    }

    private static var interfaceLanguage: InterfaceLanguage {
        switch L10n.activeLanguage {
        case .english: .english
        case .simplifiedChinese: .simplifiedChinese
        case .traditionalChinese: .traditionalChinese
        case .japanese: .japanese
        case .vietnamese: .vietnamese
        case .korean: .korean
        }
    }

    private static var isCJK: Bool {
        switch interfaceLanguage {
        case .simplifiedChinese, .traditionalChinese, .japanese, .korean: true
        case .english, .vietnamese: false
        }
    }

    static func tracking(_ value: CGFloat) -> CGFloat {
        isCJK ? 0 : value
    }

    static func lineHeight(_ size: CGFloat) -> CGFloat {
        (size * 1.4).rounded(.up)
    }

    static func sans(_ size: CGFloat, weight: String = "Regular") -> Font {
        let style = sansStyle(weight: weight)
        return font(named: style.name, size: size, fallback: style.fallback)
    }

    static func serif(_ size: CGFloat) -> Font {
        let name = switch interfaceLanguage {
        case .english: "IowanOldStyle-Roman"
        case .simplifiedChinese: "STSongti-SC-Regular"
        case .traditionalChinese: "STSongti-TC-Regular"
        case .japanese: "HiraMinProN-W3"
        case .vietnamese: "Palatino-Roman"
        case .korean: "AppleMyungjo"
        }
        if NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .regular, design: .serif)
    }

    static func digits(_ size: CGFloat) -> Font {
        if NSFont(name: "AvenirNext-Medium", size: size) != nil {
            return .custom("AvenirNext-Medium", size: size).monospacedDigit()
        }
        return .system(size: size, weight: .medium).monospacedDigit()
    }

    static func label(_ size: CGFloat = 9.5) -> Font {
        sans(size, weight: "DemiBold")
    }

    static func wordmark(_ size: CGFloat) -> Font {
        font(named: "AvenirNext-DemiBold", size: size, fallback: .semibold)
    }

    private static func font(named name: String, size: CGFloat, fallback: Font.Weight) -> Font {
        if NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: fallback)
    }

    private static func sansStyle(weight: String) -> (name: String, fallback: Font.Weight) {
        switch interfaceLanguage {
        case .english:
            switch weight {
            case "Medium": ("AvenirNext-Medium", .medium)
            case "DemiBold": ("AvenirNext-DemiBold", .semibold)
            case "Bold": ("AvenirNext-Bold", .bold)
            default: ("AvenirNext-Regular", .regular)
            }
        case .vietnamese:
            switch weight {
            case "Medium": ("AvenirNext-Medium", .medium)
            case "DemiBold": ("AvenirNext-DemiBold", .semibold)
            case "Bold": ("AvenirNext-Bold", .bold)
            default: ("AvenirNext-Regular", .regular)
            }
        case .simplifiedChinese:
            switch weight {
            case "Medium": ("PingFangSC-Medium", .medium)
            case "DemiBold", "Bold": ("PingFangSC-Semibold", weight == "Bold" ? .bold : .semibold)
            default: ("PingFangSC-Regular", .regular)
            }
        case .traditionalChinese:
            switch weight {
            case "Medium": ("PingFangTC-Medium", .medium)
            case "DemiBold", "Bold": ("PingFangTC-Semibold", weight == "Bold" ? .bold : .semibold)
            default: ("PingFangTC-Regular", .regular)
            }
        case .japanese:
            switch weight {
            case "Medium": ("HiraginoSans-W5", .medium)
            case "DemiBold", "Bold": ("HiraginoSans-W6", weight == "Bold" ? .bold : .semibold)
            default: ("HiraginoSans-W3", .regular)
            }
        case .korean:
            switch weight {
            case "Medium": ("AppleSDGothicNeo-Medium", .medium)
            case "DemiBold": ("AppleSDGothicNeo-SemiBold", .semibold)
            case "Bold": ("AppleSDGothicNeo-Bold", .bold)
            default: ("AppleSDGothicNeo-Regular", .regular)
            }
        }
    }
}
