import SwiftUI

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
