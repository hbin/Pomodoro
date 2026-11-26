import SwiftUI

struct PrimaryCTAButtonStyle: ButtonStyle {
    let colors: ModeColors
    var height: CGFloat = 48
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.sans(13.5, weight: "DemiBold"))
            .foregroundStyle(colors.onButton)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [colors.buttonTop, colors.buttonBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.986 : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: colors)
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
