import SwiftUI

struct UpdateDot: View {
    let hasUpdate: Bool
    let isExpanded: Bool
    let language: AppLanguage
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { Palette.forScheme(scheme) }

    var body: some View {
        Button(action: action) {
            ZStack {
                if hasUpdate {
                    Circle()
                        .fill(palette.tomato.opacity(0.09))
                        .frame(width: 12, height: 12)
                }
                Circle()
                    .fill(hasUpdate ? palette.tomato : palette.mutedInk.opacity(0.56))
                    .frame(
                        width: hasUpdate ? 5 : 4.5,
                        height: hasUpdate ? 5 : 4.5
                    )
            }
            .frame(width: 20, height: 20)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(hasUpdate
            ? L10n.string("updates.dot.value_available")
            : L10n.string("updates.dot.label"))
        .accessibilityLabel(L10n.string("updates.dot.label"))
        .accessibilityValue(hasUpdate
            ? L10n.string("updates.dot.value_available")
            : L10n.string("updates.dot.value_none"))
        .accessibilityHint(L10n.string("updates.dot.hint"))
        .accessibilityAddTraits(isExpanded ? [.isSelected] : [])
        .id(language)
    }
}
