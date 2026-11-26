import SwiftUI

struct MiniDial: View {
    @Environment(\.colorScheme) private var scheme
    var accent: Color?
    var size: CGFloat = 19

    var body: some View {
        let palette = Palette.forScheme(scheme)
        ZStack {
            Circle()
                .strokeBorder(palette.brass.opacity(0.9), lineWidth: 1.3)
            Circle()
                .fill(palette.plaque)
                .padding(3.6)
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let dialRadius = size * 0.36
                let tickRadius = size * 0.27

                var ticks = Path()
                for hour in stride(from: 0, to: 12, by: 3) {
                    let angle = Angle.degrees(Double(hour) * 30 - 90)
                    let start = CGPoint(
                        x: center.x + cos(angle.radians) * tickRadius,
                        y: center.y + sin(angle.radians) * tickRadius
                    )
                    let end = CGPoint(
                        x: center.x + cos(angle.radians) * dialRadius,
                        y: center.y + sin(angle.radians) * dialRadius
                    )
                    ticks.move(to: start)
                    ticks.addLine(to: end)
                }
                context.stroke(
                    ticks,
                    with: .color(palette.ink.opacity(0.48)),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                )

                let handAngle = Angle.degrees(60)
                let handRadius = size * 0.29
                var hand = Path()
                hand.move(to: center)
                hand.addLine(to: CGPoint(
                    x: center.x + cos(handAngle.radians) * handRadius,
                    y: center.y + sin(handAngle.radians) * handRadius
                ))
                context.stroke(
                    hand,
                    with: .color(accent ?? palette.tomato),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            }
            Circle()
                .fill(palette.brass)
                .frame(width: 2.6, height: 2.6)
                .overlay(Circle().fill(palette.ink).frame(width: 1, height: 1))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
