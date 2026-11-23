import SwiftUI

struct DialView: View {
    let timeText: String
    let caption: String
    let progress: Double
    let accent: Color
    let size: CGFloat
    var showsCountdown = false
    var handProgress = 0.0
    let accessibilityLabel: String
    let accessibilityValue: String
    let ambient: AmbientPose
    let handColor: Color

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var palette: Palette { Palette.forScheme(scheme) }
    private var travelScale: CGFloat { scheme == .dark ? 1.3 : 1.0 }

    var body: some View {
        let rimWidth: CGFloat = max(6, size * 0.031)
        let faceInset: CGFloat = rimWidth + 4
        let tickRadius = size / 2 - faceInset - 9
        let plaqueDiameter = size * (size < 210 ? 0.55 : 0.51)
        let elapsedProgress = min(max(progress, 0), 1)
        let clampedHandProgress = min(max(handProgress, 0), 1)
        let arcProgress = showsCountdown ? clampedHandProgress : elapsedProgress

        ZStack {
            Circle()
                .fill(palette.boneTop)
                .shadow(
                    color: .black.opacity(scheme == .dark ? 0.35 : 0.13),
                    radius: 6,
                    x: ambient.dialShadowX * travelScale,
                    y: 3
                )

            AmbientCircleFace(
                center: ambient.dialCenter,
                colors: [
                    palette.plaque,
                    palette.boneTop,
                    palette.paper.opacity(0.72)
                ],
                startRadius: 4,
                endRadius: size * 0.62
            )
                .padding(faceInset)
                .overlay {
                    Circle()
                        .strokeBorder(palette.ink.opacity(contrast == .increased ? 0.14 : 0.07), lineWidth: 0.8)
                        .padding(faceInset)
                }

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            palette.lightBrass,
                            palette.brass,
                            palette.brass.opacity(0.72),
                            palette.lightBrass
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: rimWidth
                )
                .padding(rimWidth / 2 + 1)

            Circle()
                .strokeBorder(palette.lightBrass.opacity(0.28), lineWidth: 0.8)
                .padding(faceInset - 1.2)

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                for index in 0..<60 {
                    let isMajor = index % 5 == 0
                    let angle = Angle.degrees(Double(index) * 6 - 90)
                    let inner = tickRadius - (isMajor ? size * 0.041 : size * 0.022)
                    let outer = tickRadius
                    var path = Path()
                    path.move(to: point(center: center, radius: inner, angle: angle))
                    path.addLine(to: point(center: center, radius: outer, angle: angle))
                    let color = palette.ink.opacity(isMajor ? 0.62 : 0.30)
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: isMajor ? 1.25 : 0.75, lineCap: .round)
                    )
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)

            // The arc is a chapter ring: outside the minute ticks, inside the
            // brass rim, square-ended, and flat rather than glowing.
            Circle()
                .trim(from: 0, to: arcProgress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: max(2.0, size * 0.0112), lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
                .padding(size / 2 - (tickRadius + 6.5))
                .animation(reduceMotion ? nil : .linear(duration: 0.22), value: arcProgress)
                .accessibilityHidden(true)

            handView(
                tickRadius: tickRadius,
                plaqueDiameter: plaqueDiameter,
                handProgress: clampedHandProgress
            )

            plaque(diameter: plaqueDiameter)

        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : AmbientMotion.curve, value: ambient)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(accessibilityValue))
    }

    private func handView(
        tickRadius: CGFloat,
        plaqueDiameter: CGFloat,
        handProgress: Double
    ) -> some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let degrees = handProgress * 360 - 90
            let angle = Angle.degrees(degrees)
            let startRadius = plaqueDiameter / 2 + size * 0.025
            let endRadius = tickRadius - size * 0.012
            var path = Path()
            path.move(to: point(center: center, radius: startRadius, angle: angle))
            path.addLine(to: point(center: center, radius: endRadius, angle: angle))
            context.addFilter(.shadow(color: .black.opacity(0.16), radius: 1.5, x: 0.5, y: 1))
            context.stroke(
                path,
                with: .color(handColor),
                style: StrokeStyle(lineWidth: max(2.6, size * 0.014), lineCap: .round)
            )
        }
        .frame(width: size, height: size)
        .animation(
            reduceMotion ? nil : (showsCountdown ? .linear(duration: 0.22) : .easeInOut(duration: 0.7)),
            value: handProgress
        )
        .accessibilityHidden(true)
    }

    private func plaque(diameter: CGFloat) -> some View {
        ZStack {
            AmbientCircleFace(
                center: ambient.plaqueCenter,
                colors: [palette.plaque, palette.boneTop],
                startRadius: 2,
                endRadius: diameter * 0.62
            )
                .overlay {
                    AmbientCircleFace(
                        center: ambient.plaqueCenter,
                        colors: [
                            Color.white.opacity(scheme == .dark ? 0.14 : 0.42),
                            .clear
                        ],
                        startRadius: 0,
                        endRadius: diameter * 0.62
                    )
                }
                .overlay {
                    AmbientCircleFace(
                        center: ambient.plaqueShadeCenter,
                        colors: [
                            Color.black.opacity(scheme == .dark ? 0.14 : 0.05),
                            .clear
                        ],
                        startRadius: 0,
                        endRadius: diameter * 0.62
                    )
                }
                .overlay {
                    Circle()
                        .strokeBorder(palette.brass.opacity(0.55), lineWidth: 0.9)
                }
                .shadow(
                    color: .black.opacity(scheme == .dark ? 0.32 : 0.10),
                    radius: 4,
                    x: ambient.plaqueShadowX * travelScale,
                    y: 2
                )

            VStack(spacing: diameter * 0.045) {
                Text(timeText)
                    .font(Typo.digits(diameter * 0.285))
                    .foregroundStyle(palette.ink)
                    .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: timeText)
                Text(caption)
                    .font(Typo.label(max(7.4, diameter * 0.047)))
                    .tracking(Typo.tracking(diameter * 0.011))
                    .foregroundStyle(palette.mutedInk.opacity(0.95))
            }
            .offset(y: -diameter * 0.012)
        }
        .frame(width: diameter, height: diameter)
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle.radians) * radius,
            y: center.y + sin(angle.radians) * radius
        )
    }
}
