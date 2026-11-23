import Foundation
import PomodoroCore
import SwiftUI

/// The three idle modes shown by the design study, in dot order.
enum IdleMode: Int, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: Int { rawValue }

    init(phase: Phase) {
        switch phase {
        case .focus: self = .focus
        case .shortBreak: self = .shortBreak
        case .longBreak: self = .longBreak
        }
    }

    var minutes: Int {
        switch self {
        case .focus: 25
        case .shortBreak: 5
        case .longBreak: 15
        }
    }

    var isBreak: Bool { self != .focus }

    var phase: Phase {
        switch self {
        case .focus: .focus
        case .shortBreak: .shortBreak
        case .longBreak: .longBreak
        }
    }

    /// The hand points at the selected duration on the 60-minute dial.
    var handProgress: Double {
        Double(minutes) / 60.0
    }

    var title: String {
        switch self {
        case .focus: L10n.string("timer.title.idle")
        case .shortBreak: L10n.string("timer.title.short_break")
        case .longBreak: L10n.string("timer.title.long_break")
        }
    }

    var primaryLabel: String {
        switch self {
        case .focus: L10n.format("timer.action.start", 25)
        case .shortBreak: L10n.format("timer.action.start_break", 5)
        case .longBreak: L10n.format("timer.action.start_break", 15)
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .focus: L10n.format("timer.a11y.focus_chip", 25)
        case .shortBreak: L10n.format("timer.break.short_with_minutes", 5)
        case .longBreak: L10n.format("timer.break.long_with_minutes", 15)
        }
    }

    var selectorLabel: String {
        switch self {
        case .focus: L10n.string("timer.mode.focus")
        case .shortBreak: L10n.string("timer.mode.short_break")
        case .longBreak: L10n.string("timer.mode.long_break")
        }
    }

    func glowColor(in palette: Palette) -> Color {
        switch self {
        case .focus: palette.tomato
        case .shortBreak: palette.sage
        case .longBreak: palette.brass
        }
    }

    func shifted(by delta: Int) -> IdleMode {
        let count = IdleMode.allCases.count
        return IdleMode(rawValue: (rawValue + delta + count) % count) ?? self
    }
}

enum LaunchIdleMode {
    static var override: IdleMode? {
        for argument in CommandLine.arguments {
            switch argument {
            case "--idle-mode=focus": return .focus
            case "--idle-mode=short": return .shortBreak
            case "--idle-mode=long": return .longBreak
            default: continue
            }
        }
        return nil
    }
}

/// The idle light position follows the three mode dots from left to right.
struct AmbientPose: Equatable {
    let index: Int
    let paperAngle: Double
    let dialCenter: UnitPoint
    let plaqueCenter: UnitPoint
    let glowX: CGFloat
    let rimX: CGFloat
    let shadeX: CGFloat
    let dialShadowX: CGFloat
    let plaqueShadowX: CGFloat

    var plaqueShadeCenter: UnitPoint {
        UnitPoint(x: 1 - plaqueCenter.x, y: 1 - plaqueCenter.y)
    }

    static func forMode(_ mode: IdleMode) -> AmbientPose {
        poses[min(mode.rawValue, poses.count - 1)]
    }

    static let poses: [AmbientPose] = [
        AmbientPose(
            index: 0,
            paperAngle: 163,
            dialCenter: UnitPoint(x: 0.30, y: 0.24),
            plaqueCenter: UnitPoint(x: 0.30, y: 0.22),
            glowX: -36,
            rimX: -40,
            shadeX: 20,
            dialShadowX: 3,
            plaqueShadowX: 1.5
        ),
        AmbientPose(
            index: 1,
            paperAngle: 180,
            dialCenter: UnitPoint(x: 0.50, y: 0.14),
            plaqueCenter: UnitPoint(x: 0.50, y: 0.12),
            glowX: 0,
            rimX: 0,
            shadeX: 0,
            dialShadowX: 0,
            plaqueShadowX: 0
        ),
        AmbientPose(
            index: 2,
            paperAngle: 197,
            dialCenter: UnitPoint(x: 0.70, y: 0.24),
            plaqueCenter: UnitPoint(x: 0.70, y: 0.22),
            glowX: 36,
            rimX: 40,
            shadeX: -20,
            dialShadowX: -3,
            plaqueShadowX: -1.5
        )
    ]
}

enum AmbientMotion {
    static let curve = Animation.timingCurve(0.2, 0.78, 0.18, 1, duration: 0.85)
}

/// A linear paper gradient whose angle can animate. SwiftUI does not
/// interpolate `LinearGradient` points by default.
struct AmbientPaper: View, @MainActor Animatable {
    var angle: Double
    let colors: [Color]

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    private var startPoint: UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(
            x: 0.5 - sin(radians) * 0.5,
            y: 0.5 + cos(radians) * 0.5
        )
    }

    private var endPoint: UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(
            x: 0.5 + sin(radians) * 0.5,
            y: 0.5 - cos(radians) * 0.5
        )
    }
}

/// A radial gradient whose center can animate.
struct AmbientCircleFace: View, @MainActor Animatable {
    var center: UnitPoint
    let colors: [Color]
    let startRadius: CGFloat
    let endRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(center.x, center.y) }
        set { center = UnitPoint(x: newValue.first, y: newValue.second) }
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: colors,
                    center: center,
                    startRadius: startRadius,
                    endRadius: endRadius
                )
            )
    }
}
