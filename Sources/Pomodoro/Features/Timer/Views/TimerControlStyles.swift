import SwiftUI

struct PrimaryButtonLabel: View {
    let title: String
    let icon: String

    var body: some View {
        ZStack {
            Text(title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack {
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.trailing, 15)
        }
    }
}

/// Quiet trailing end control. It has no resting plate, so the running row
/// reads as one primary action plus a muted glyph; hover or keyboard focus
/// reveals a plaque disc behind the glyph without changing the hit area.
struct EndControlButtonStyle: ButtonStyle {
    let palette: Palette
    var isFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let highlighted = isHovering || isFocused
        configuration.label
            .font(.system(size: ControlMetrics.endIconSize, weight: .medium))
            .foregroundStyle(highlighted ? palette.ink : palette.mutedInk)
            .frame(width: ControlMetrics.endHitWidth, height: ControlMetrics.rowHeight)
            .background {
                if highlighted {
                    Circle()
                        .fill(
                            reduceTransparency
                                ? palette.plaque
                                : palette.plaque.opacity(0.72)
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(palette.brass.opacity(0.34), lineWidth: 1)
                        }
                        .frame(
                            width: ControlMetrics.hoverDiscSize,
                            height: ControlMetrics.hoverDiscSize
                        )
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: highlighted)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
