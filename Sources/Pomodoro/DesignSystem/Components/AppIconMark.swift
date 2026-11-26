import AppKit
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
