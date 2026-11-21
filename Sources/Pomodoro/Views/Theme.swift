import AppKit
import SwiftUI
import PomodoroCore

enum LaunchAppearance {
    private static var colorSchemeOverride: ColorScheme? {
        if CommandLine.arguments.contains("--force-dark") { return .dark }
        if CommandLine.arguments.contains("--force-light") { return .light }
        return nil
    }

    static func colorScheme(for preference: ThemePreference) -> ColorScheme? {
        colorSchemeOverride ?? preference.colorScheme
    }

    static func appearance(for preference: ThemePreference) -> NSAppearance? {
        guard let scheme = colorScheme(for: preference) else { return nil }
        return NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    }
}

extension ThemePreference {
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Black"
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
                leaf: Color(hex: 0x5C8E50),
                onLeaf: .white,
                sage: Color(hex: 0x94A284),
                deepSage: Color(hex: 0x5E6B52)
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
            leaf: Color(hex: 0x74965F),
            onLeaf: Color(hex: 0x2B2520),
            sage: Color(hex: 0x7F8C72),
            deepSage: Color(hex: 0x5F6B52)
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
    static func sans(_ size: CGFloat, weight: String = "Regular") -> Font {
        let name: String
        switch weight {
        case "Medium": name = "AvenirNext-Medium"
        case "DemiBold": name = "AvenirNext-DemiBold"
        case "Bold": name = "AvenirNext-Bold"
        default: name = "AvenirNext-Regular"
        }
        return .custom(name, size: size)
    }

    static func serif(_ size: CGFloat) -> Font {
        .custom("IowanOldStyle-Roman", size: size)
    }

    static func digits(_ size: CGFloat) -> Font {
        .custom("AvenirNext-Medium", size: size).monospacedDigit()
    }

    static func label(_ size: CGFloat = 9.5) -> Font {
        .custom("AvenirNext-DemiBold", size: size)
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

    var body: some View {
        let palette = Palette.forScheme(scheme)
        ZStack {
            LinearGradient(
                colors: [palette.boneTop, palette.bone, palette.paper.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if !reduceTransparency {
                RadialGradient(
                    colors: [palette.tomato.opacity(0.045), .clear],
                    center: UnitPoint(x: 0.2, y: 0.0),
                    startRadius: 2,
                    endRadius: 330
                )
            }
            PaperGrain(opacity: 0.4)
        }
    }
}

struct Hairline: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(Palette.forScheme(scheme).lightBrass.opacity(0.5))
            .frame(height: 0.7)
    }
}
