import AppKit
import SwiftUI

struct DurationColumn: View {
    let title: String
    let minutes: Int
    let isEditing: Bool
    let range: ClosedRange<Int>
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void
    let onChange: (Int) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: String
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    init(
        title: String,
        minutes: Int,
        isEditing: Bool,
        range: ClosedRange<Int>,
        onBeginEditing: @escaping () -> Void,
        onEndEditing: @escaping () -> Void,
        onChange: @escaping (Int) -> Void
    ) {
        self.title = title
        self.minutes = minutes
        self.isEditing = isEditing
        self.range = range
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
        self.onChange = onChange
        _draft = State(initialValue: String(minutes))
    }

    private var palette: Palette { Palette.forScheme(scheme) }
    private var valueText: String { L10n.format("settings.durations.value", minutes) }
    private var stepValueText: String {
        L10n.format("settings.durations.value", adjustmentBase)
    }
    private var helpText: String { L10n.string("settings.durations.help") }
    private var accessibilityHint: String { L10n.string("settings.durations.a11y_hint") }

    private var adjustmentBase: Int {
        guard isEditing, let parsed = Int(draft) else { return minutes }
        return min(max(parsed, range.lowerBound), range.upperBound)
    }

    private var canDecrease: Bool { adjustmentBase > range.lowerBound }
    private var canIncrease: Bool { adjustmentBase < range.upperBound }

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(Typo.sans(10.5, weight: "Medium"))
                .foregroundStyle(palette.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                DurationStepButton(
                    symbol: "minus",
                    isEnabled: canDecrease,
                    accessibilityLabel: L10n.format(
                        "settings.durations.decrease",
                        title
                    ),
                    accessibilityValue: stepValueText,
                    accessibilityHint: accessibilityHint,
                    action: { adjust(by: -1) }
                )

                Group {
                    if isEditing {
                        editingField
                    } else {
                        valueButton
                    }
                }
                .frame(maxWidth: .infinity)

                DurationStepButton(
                    symbol: "plus",
                    isEnabled: canIncrease,
                    accessibilityLabel: L10n.format(
                        "settings.durations.increase",
                        title
                    ),
                    accessibilityValue: stepValueText,
                    accessibilityHint: accessibilityHint,
                    action: { adjust(by: 1) }
                )
            }
            .frame(maxWidth: .infinity, minHeight: 28)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(palette.plaque.opacity(isEditing ? 0.44 : 0.28))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        isEditing
                            ? palette.tomato.opacity(0.68)
                            : palette.brass.opacity(isHovering ? 0.6 : 0.42),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isEditing)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovering)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: minutes) { _, newValue in
            if !isEditing {
                draft = String(newValue)
            }
        }
        .onChange(of: isEditing) { wasEditing, editing in
            if wasEditing, !editing {
                commitDraft()
                isFocused = false
            }
        }
    }

    private var valueButton: some View {
        Button {
            beginEditing()
        } label: {
            valueLabel
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(title)
        .accessibilityValue(valueText)
        .accessibilityHint(accessibilityHint)
    }

    private var editingField: some View {
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(Typo.digits(13))
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.ink.opacity(0.92))
            .focused($isFocused)
            .focusEffectDisabled()
            .frame(maxWidth: .infinity, minHeight: 28)
            .onSubmit { finishEditing() }
            .accessibilityLabel(title)
            .accessibilityHint(accessibilityHint)
            .onAppear {
                focusEditor()
            }
            .onChange(of: isFocused) { _, focused in
                if !focused, isEditing {
                    onEndEditing()
                }
            }
            .onChange(of: draft) { _, newValue in
                let filtered = String(newValue.filter(\.isNumber).prefix(3))
                if filtered != newValue {
                    draft = filtered
                }
                applyDraftWhileTyping(filtered)
            }
            .help(helpText)
    }

    private var valueLabel: some View {
        Text(String(minutes))
            .font(Typo.digits(13))
            .foregroundStyle(palette.ink.opacity(0.92))
    }

    private func beginEditing() {
        draft = String(minutes)
        onBeginEditing()
    }

    /// Defers focus past the click that opened the editor. Setting focus while
    /// the button's mouse-up is still being handled can leave the field visible
    /// but unfocused when the click lands outside the text's inner bounds.
    private func focusEditor() {
        DispatchQueue.main.async {
            isFocused = true
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }

    private func finishEditing() {
        isFocused = false
        onEndEditing()
    }

    private func adjust(by delta: Int) {
        let next = clamped(adjustmentBase + delta)
        if next != minutes {
            onChange(next)
        }
        if isEditing {
            draft = String(next)
            isFocused = false
            onEndEditing()
        }
    }

    /// Applies each valid keystroke so the setting takes effect without leaving
    /// the field. The draft is only normalized on commit, which keeps editing
    /// predictable while the user is still typing.
    private func applyDraftWhileTyping(_ text: String) {
        guard let parsed = Int(text) else { return }
        onChange(clamped(parsed))
    }

    private func commitDraft() {
        guard let parsed = Int(draft) else {
            draft = String(minutes)
            return
        }
        let resolved = clamped(parsed)
        draft = String(resolved)
        onChange(resolved)
    }

    private func clamped(_ minutes: Int) -> Int {
        min(max(minutes, range.lowerBound), range.upperBound)
    }
}

private struct DurationStepButton: View {
    let symbol: String
    let isEnabled: Bool
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityHint: String
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var palette: Palette { Palette.forScheme(scheme) }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 28)
                .foregroundStyle(
                    palette.mutedInk.opacity(isEnabled ? 0.9 : 0.26)
                )
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            palette.ink.opacity(
                                isHovering && isEnabled ? 0.065 : 0
                            )
                        )
                        .padding(2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .help(accessibilityLabel)
        .onHover { hovering in
            isHovering = hovering && isEnabled
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isHovering)
    }
}
