import PomodoroCore
import SwiftUI

struct ModeColors: Equatable {
    let accent: Color
    let buttonTop: Color
    let buttonBottom: Color
    let onButton: Color
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
    /// Accent and primary fill for each mode. The accent is tuned for the
    /// 9-point mode label and the channel arc; the fill is tuned for the
    /// 13.5-point primary label.
    let modeFocus: ModeColors
    let modeShort: ModeColors
    let modeLong: ModeColors

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
                modeFocus: ModeColors(
                    accent: Color(hex: 0xD46A54),
                    buttonTop: Color(hex: 0xD46A54),
                    buttonBottom: Color(hex: 0xCE6853),
                    onButton: Color(hex: 0x1D1916)
                ),
                modeShort: ModeColors(
                    accent: Color(hex: 0x94A284),
                    buttonTop: Color(hex: 0x7FA160),
                    buttonBottom: Color(hex: 0x789A58),
                    onButton: Color(hex: 0x1D1916)
                ),
                modeLong: ModeColors(
                    accent: Color(hex: 0x7F8C72),
                    buttonTop: Color(hex: 0x2F6B3A),
                    buttonBottom: Color(hex: 0x285D32),
                    onButton: .white
                )
            )
        }
        return Palette(
            bone: Color(hex: 0xF6EFE2),
            boneTop: Color(hex: 0xFBF6EC),
            paper: Color(hex: 0xECE2D2),
            plaque: Color(hex: 0xFCF7ED),
            ink: Color(hex: 0x2B2520),
            mutedInk: Color(hex: 0x6B5E4E),
            tomato: Color(hex: 0xC6533F),
            deepTomato: Color(hex: 0xA53D2E),
            brass: Color(hex: 0xB48A58),
            lightBrass: Color(hex: 0xDCC29B),
            leaf: Color(hex: 0x7C9F5C),
            onLeaf: Color(hex: 0x2B2520),
            sage: Color(hex: 0x7F8C72),
            deepSage: Color(hex: 0x5F6B52),
            modeFocus: ModeColors(
                accent: Color(hex: 0xA53D2E),
                buttonTop: Color(hex: 0xB84A37),
                buttonBottom: Color(hex: 0xA53D2E),
                onButton: Color(hex: 0xFBF6EC)
            ),
            modeShort: ModeColors(
                accent: Color(hex: 0x5F6B52),
                buttonTop: Color(hex: 0x7FA160),
                buttonBottom: Color(hex: 0x789A58),
                onButton: Color(hex: 0x2B2520)
            ),
            modeLong: ModeColors(
                accent: Color(hex: 0x4E5A43),
                buttonTop: Color(hex: 0x5F6B52),
                buttonBottom: Color(hex: 0x4E5A43),
                onButton: Color(hex: 0xFBF6EC)
            )
        )
    }

    func modeColors(for phase: Phase) -> ModeColors {
        switch phase {
        case .focus: modeFocus
        case .shortBreak: modeShort
        case .longBreak: modeLong
        }
    }

    func accent(for phase: Phase) -> Color {
        modeColors(for: phase).accent
    }

    func deepAccent(for phase: Phase) -> Color {
        modeColors(for: phase).accent
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
