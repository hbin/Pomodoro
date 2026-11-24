import SwiftUI

struct DialView: View {
    let timeText: String
    let caption: String
    /// Elapsed fraction of the active interval. The ring shows its complement
    /// while `showsCountdown` is true.
    let progress: Double
    let accent: Color
    let size: CGFloat
    /// Whether an interval is active. The ring is empty otherwise; the readout
    /// uses the countdown transition only while true.
    var showsCountdown = false
    /// Which way the readout travels when the value changes: `-1` to the left,
    /// `1` to the right, `0` for no horizontal motion.
    var readoutFlow = 0.0
    let accessibilityLabel: String
    let accessibilityValue: String
    let ambient: AmbientPose

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    /// The duration that is leaving, drawn beside the incoming one until it
    /// has cleared the plaque.
    @State private var leavingText: String?
    @State private var leavingOffset = 0.0
    @State private var enteringOffset = 0.0
    @State private var swapGeneration = 0

    private var palette: Palette { Palette.forScheme(scheme) }
    private var travelScale: CGFloat { scheme == .dark ? 1.3 : 1.0 }

    var body: some View {
        let rimWidth: CGFloat = max(6, size * 0.031)
        let faceInset: CGFloat = rimWidth + 4
        let tickRadius = size / 2 - faceInset - 9
        let plaqueDiameter = size * (size < 210 ? 0.55 : 0.51)
        let elapsedProgress = min(max(progress, 0), 1)
        let remainingProgress = showsCountdown ? 1 - elapsedProgress : 0

        ZStack {
            Circle()
                .fill(palette.boneTop)
                .shadow(
                    color: .black.opacity(scheme == .dark ? 0.35 : 0.13),
                    radius: 6,
                    x: ambient.dialShadowX * travelScale,
                    y: 3
                )
                .animation(reduceMotion ? nil : AmbientMotion.curve, value: ambient)

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
                .animation(reduceMotion ? nil : AmbientMotion.curve, value: ambient)

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

            // The session ring is an inlay in the chapter ring: outside the
            // decorative marks, inside the brass rim, square-ended, and flat.
            // It is empty at idle, sweeps to full at the start, then drains
            // counterclockwise.
            Circle()
                .trim(from: 0, to: remainingProgress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: max(2.0, size * 0.0112), lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
                .padding(size / 2 - (tickRadius + 6.5))
                .animation(reduceMotion ? nil : .linear(duration: 0.3), value: remainingProgress)
                .animation(reduceMotion ? nil : AmbientMotion.curve, value: accent)
                .accessibilityHidden(true)

            plaque(diameter: plaqueDiameter)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(accessibilityValue))
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
                .animation(reduceMotion ? nil : AmbientMotion.curve, value: ambient)

            VStack(spacing: diameter * 0.045) {
                timeReadout(diameter: diameter)
                Text(caption)
                    .font(Typo.label(max(7.4, diameter * 0.047)))
                    .tracking(Typo.tracking(diameter * 0.011))
                    .foregroundStyle(palette.mutedInk.opacity(0.95))
            }
            .offset(y: -diameter * 0.012)
        }
        .frame(width: diameter, height: diameter)
    }

    /// The digits roll while a countdown ticks. A ready duration instead
    /// leaves through one side of the plaque while the next one arrives
    /// through the other, like a strip passing behind a window.
    @ViewBuilder
    private func timeReadout(diameter: CGFloat) -> some View {
        let font = Typo.digits(diameter * 0.285)

        if showsCountdown {
            Text(timeText)
                .font(font)
                .foregroundStyle(palette.ink)
                .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: timeText)
        } else {
            ZStack {
                if let leavingText {
                    Text(leavingText)
                        .font(font)
                        .foregroundStyle(palette.ink)
                        .offset(x: leavingOffset)
                }
                Text(timeText)
                    .font(font)
                    .foregroundStyle(palette.ink)
                    .offset(x: enteringOffset)
            }
            // The plaque is the window the strip passes behind, so a
            // half-slid number is cut at its edge rather than floating over
            // the face.
            .frame(width: diameter * 0.94)
            .clipped()
            .onChange(of: timeText) { old, _ in
                swapReadout(from: old, window: diameter)
            }
        }
    }

    private static let readoutExit = Animation.easeIn(duration: 0.15)
    private static let readoutEntry = Animation.easeOut(duration: 0.20)
    private static let entryStart = 0.15
    private static let swapEnd = 0.38

    private func swapReadout(from old: String, window: CGFloat) {
        // A readout with no direction to travel, as on the completion screen,
        // swaps at once rather than sliding two values through one spot.
        guard !reduceMotion, readoutFlow != 0, old != timeText, !showsCountdown else { return }
        swapGeneration += 1
        let generation = swapGeneration
        // A little more than the readout's own width, so a value clears the
        // window instead of leaving a sliver behind.
        let travel = window * 0.86 * readoutFlow

        // Park the outgoing value at rest and the incoming one offstage
        // before the strip starts to move.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            leavingText = old
            leavingOffset = 0
            enteringOffset = -travel
        }

        DispatchQueue.main.async {
            guard generation == swapGeneration else { return }
            withAnimation(Self.readoutExit) {
                leavingOffset = travel
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.entryStart) {
                guard generation == swapGeneration else { return }
                withAnimation(Self.readoutEntry) {
                    enteringOffset = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.swapEnd) {
                guard generation == swapGeneration else { return }
                leavingText = nil
            }
        }
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle.radians) * radius,
            y: center.y + sin(angle.radians) * radius
        )
    }
}
