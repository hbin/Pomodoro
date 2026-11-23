import SwiftUI

struct AppIconMark: View {
    @Environment(\.colorScheme) private var scheme
    var accent: Color?
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .clipShape(
                        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                            .strokeBorder(
                                .black.opacity(scheme == .dark ? 0.28 : 0.10),
                                lineWidth: 0.7
                            )
                            .padding(size * 0.055)
                    }
                    .shadow(
                        color: .black.opacity(scheme == .dark ? 0.30 : 0.12),
                        radius: 1.2,
                        y: 0.8
                    )
            } else {
                MiniDial(accent: accent, size: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PrimaryInstrumentButtonStyle: ButtonStyle {
    var color: Color
    var textColor: Color = .white
    var height: CGFloat = 48
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.sans(13.5, weight: "DemiBold"))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.96), color],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                    }
                    .shadow(color: color.opacity(configuration.isPressed ? 0.10 : 0.22), radius: 9, y: 4)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.986 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct InkButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var height: CGFloat = 48
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let palette = Palette.forScheme(scheme)
        configuration.label
            .font(Typo.sans(13.5, weight: "DemiBold"))
            .foregroundStyle(palette.boneTop)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.ink)
                    .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.986 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var height: CGFloat = 46
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let palette = Palette.forScheme(scheme)
        configuration.label
            .font(Typo.sans(12.5, weight: "Medium"))
            .foregroundStyle(palette.ink.opacity(0.88))
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.plaque.opacity(configuration.isPressed ? 0.9 : 0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.brass.opacity(0.5), lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.986 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SquareButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var size: CGFloat = 50
    var foreground: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let palette = Palette.forScheme(scheme)
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle((foreground ?? palette.ink.opacity(0.74)).opacity(configuration.isPressed ? 0.55 : 1))
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(palette.plaque.opacity(configuration.isPressed ? 0.9 : 0.46))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(palette.brass.opacity(0.45), lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct QuietTextButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var color: Color?

    func makeBody(configuration: Configuration) -> some View {
        let palette = Palette.forScheme(scheme)
        configuration.label
            .font(Typo.sans(11.5, weight: "Medium"))
            .foregroundStyle((color ?? palette.mutedInk).opacity(configuration.isPressed ? 0.55 : 0.92))
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .contentShape(Rectangle())
    }
}

struct IconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var size: CGFloat = 28
    var foreground: Color?
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let palette = Palette.forScheme(scheme)
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle((foreground ?? palette.mutedInk).opacity(configuration.isPressed ? 0.55 : 1))
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(palette.ink.opacity(isHovering ? 0.055 : 0))
            }
            .contentShape(Circle())
            .onHover { isHovering = $0 }
    }
}

struct DurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.forScheme(scheme)
        Button(action: action) {
            Text(L10n.count("common.minutes_compact", minutes))
                .font(Typo.sans(12.5, weight: isSelected ? "DemiBold" : "Medium"))
                .foregroundStyle(isSelected ? palette.boneTop : palette.ink.opacity(0.8))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? palette.ink : palette.plaque.opacity(0.28))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    isSelected ? palette.ink : palette.brass.opacity(0.42),
                                    lineWidth: 1
                                )
                        }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.format("timer.a11y.focus_chip", minutes))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

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

struct ErrorNote: View {
    let message: String
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.forScheme(scheme)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(palette.tomato)
                .padding(.top, 1)
            Text(message)
                .font(Typo.sans(10.5))
                .foregroundStyle(palette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 2)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconButtonStyle(size: 20))
            .accessibilityLabel(L10n.string("accessibility.dismiss_error"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.tomato.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(palette.tomato.opacity(0.18), lineWidth: 0.8)
                }
        }
    }
}

struct PopoverHeader: View {
    let accent: Color?
    let onSettings: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.forScheme(scheme)
        HStack(spacing: 8) {
            AppIconMark(accent: accent)
            Text(verbatim: "POMODORO")
                .font(Typo.wordmark(10))
                .tracking(2.5)
                .foregroundStyle(palette.ink.opacity(0.72))
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle(size: 28))
            .accessibilityLabel(L10n.string("accessibility.settings"))
        }
    }
}
