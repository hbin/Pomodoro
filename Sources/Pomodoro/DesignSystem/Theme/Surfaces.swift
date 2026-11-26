import SwiftUI

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
