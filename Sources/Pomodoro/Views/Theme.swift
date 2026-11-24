import AppKit
import SwiftUI
import PomodoroCore

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

struct Palette {
    let bone: Color
    let boneTop: Color
    let paper: Color
    let plaque: Color
    let ink: Color
    let mutedInk: Color
    let tomato: Color
    let deepTomato: Color
    let brass: Color
    let lightBrass: Color
    let leaf: Color
    let onLeaf: Color
    let sage: Color
    let deepSage: Color
    /// Accent for the idle mode indicator: the dots and the mode label.
    /// Light mode needs the deeper variants because 9-point text requires
    /// 4.5:1; the dark accent already passes on the espresso field.
    let modeFocus: Color
    let modeBreak: Color

    static func forScheme(_ scheme: ColorScheme) -> Palette {
        if scheme == .dark {
            return Palette(
                bone: Color(hex: 0x1D1916),
                boneTop: Color(hex: 0x25201B),
                paper: Color(hex: 0x28221D),
                plaque: Color(hex: 0x302A23),
                ink: Color(hex: 0xF2E8D8),
                mutedInk: Color(hex: 0xA69782),
                tomato: Color(hex: 0xD46A54),
                deepTomato: Color(hex: 0xB85340),
                brass: Color(hex: 0xC39A66),
                lightBrass: Color(hex: 0x6D573C),
                leaf: Color(hex: 0x2F6B3A),
                onLeaf: .white,
                sage: Color(hex: 0x94A284),
                deepSage: Color(hex: 0x5E6B52),
                modeFocus: Color(hex: 0xD46A54),
                modeBreak: Color(hex: 0x94A284)
            )
        }
        return Palette(
            bone: Color(hex: 0xF6EFE2),
            boneTop: Color(hex: 0xFBF6EC),
            paper: Color(hex: 0xECE2D2),
            plaque: Color(hex: 0xFCF7ED),
            ink: Color(hex: 0x2B2520),
            mutedInk: Color(hex: 0x756858),
            tomato: Color(hex: 0xC6533F),
            deepTomato: Color(hex: 0xA53D2E),
            brass: Color(hex: 0xB48A58),
            lightBrass: Color(hex: 0xDCC29B),
            leaf: Color(hex: 0x7C9F5C),
            onLeaf: Color(hex: 0x2B2520),
            sage: Color(hex: 0x7F8C72),
            deepSage: Color(hex: 0x5F6B52),
            modeFocus: Color(hex: 0xA53D2E),
            modeBreak: Color(hex: 0x5F6B52)
        )
    }

    func accent(for phase: Phase) -> Color {
        phase.isBreak ? sage : tomato
    }

    func deepAccent(for phase: Phase) -> Color {
        phase.isBreak ? deepSage : deepTomato
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Typo {
    private enum InterfaceLanguage {
        case english
        case simplifiedChinese
        case traditionalChinese
        case japanese
    }

    private static var interfaceLanguage: InterfaceLanguage {
        switch L10n.activeLanguage {
        case .english: .english
        case .simplifiedChinese: .simplifiedChinese
        case .traditionalChinese: .traditionalChinese
        case .japanese: .japanese
        }
    }

    private static var isCJK: Bool {
        switch interfaceLanguage {
        case .simplifiedChinese, .traditionalChinese, .japanese: true
        case .english: false
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
        }
    }
}

struct PaperGrain: View {
    @Environment(\.colorScheme) private var scheme
    var opacity: Double = 0.5

    var body: some View {
        Canvas { context, size in
            var generator = SplitMix64(seed: 0x5EED_CAFE_1234_5678)
            let count = 520
            let color: Color = scheme == .dark ? .white : .black
            for _ in 0..<count {
                let x = generator.nextDouble() * size.width
                let y = generator.nextDouble() * size.height
                let radius = 0.35 + generator.nextDouble() * 0.55
                let alpha = 0.018 + generator.nextDouble() * 0.035
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
        .blendMode(scheme == .dark ? .plusLighter : .multiply)
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

struct InstrumentFace: View {
    var accent: Color
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let palette = Palette.forScheme(scheme)
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.boneTop, palette.bone, palette.paper.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if !reduceTransparency {
                RadialGradient(
                    colors: [accent.opacity(0.075), .clear],
                    center: UnitPoint(x: 0.18, y: 0.08),
                    startRadius: 4,
                    endRadius: 340
                )
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(scheme == .dark ? 0.018 : 0.30), .clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.42)
                    )
                )

            PaperGrain()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [palette.lightBrass, palette.brass, palette.brass.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius - 5, style: .continuous)
                .strokeBorder(palette.lightBrass.opacity(0.32), lineWidth: 0.7)
                .padding(5.5)
        }
    }
}

struct PopoverBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pose: AmbientPose
    let accent: Color
    var showsAmbient = true

    var body: some View {
        let palette = Palette.forScheme(scheme)
        let isDark = scheme == .dark
        let travel: CGFloat = isDark ? 1.3 : 1.0

        ZStack {
            if showsAmbient {
                AmbientPaper(
                    angle: isDark ? 180 : pose.paperAngle,
                    colors: [palette.boneTop, palette.bone, palette.paper.opacity(0.92)]
                )

                if !reduceTransparency {
                    RadialGradient(
                        colors: [Color.white.opacity(isDark ? 0.035 : 0.12), .clear],
                        center: UnitPoint(x: 0.5, y: -0.05),
                        startRadius: 0,
                        endRadius: 250
                    )

                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(isDark ? 0.16 : 0.10), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(width: 300, height: 220)
                        .blur(radius: 26)
                        .offset(x: pose.glowX * travel, y: -64)

                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(isDark ? 0.16 : 0.32), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 240, height: 90)
                        .blur(radius: 14)
                        .offset(x: pose.rimX * travel, y: -34)

                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [Color.black.opacity(isDark ? 0.22 : 0.07), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 110
                            )
                        )
                        .frame(width: 300, height: 200)
                        .blur(radius: 28)
                        .offset(x: pose.shadeX * travel, y: 190)
                }
            } else {
                LinearGradient(
                    colors: [palette.boneTop, palette.bone, palette.paper.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            PaperGrain(opacity: 0.4)
        }
        .animation(reduceMotion || !showsAmbient ? nil : AmbientMotion.curve, value: pose)
    }
}

struct Hairline: View {
    var height: CGFloat = 0.7
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(Palette.forScheme(scheme).lightBrass.opacity(0.5))
            .frame(height: height)
    }
}
