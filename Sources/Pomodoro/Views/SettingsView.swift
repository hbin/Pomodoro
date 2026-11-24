import AppKit
import SwiftUI
import PomodoroCore
import UserNotifications

struct SettingsView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var updates: UpdateController
    let onQuit: () -> Void
    let onClose: () -> Void
    let onContentHeight: (CGFloat) -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var showsUpdatePanel = false
    @State private var editingDuration: Phase?
    @State private var scrolledHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private var palette: Palette { Palette.forScheme(scheme) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(L10n.string("settings.title"))
                                .font(Typo.serif(29))
                                .foregroundStyle(palette.ink)
                                .frame(minHeight: Typo.lineHeight(29), alignment: .leading)
                            Spacer(minLength: 8)
                            Button {
                                onClose()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(palette.mutedInk)
                                    .background { Circle().fill(palette.plaque.opacity(0.42)) }
                                    .overlay {
                                        Circle().strokeBorder(
                                            palette.brass.opacity(0.30),
                                            lineWidth: 1
                                        )
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n.string("settings.back"))
                        }
                        Text(L10n.string("settings.subtitle"))
                            .font(Typo.sans(10.7))
                            .foregroundStyle(palette.mutedInk)
                            .frame(minHeight: Typo.lineHeight(10.7), alignment: .leading)
                            .padding(.top, 2)

                        sectionHeader(L10n.string("settings.section.timer"))

                        durationHeader
                            .padding(.top, 8)

                        durationColumns
                            .padding(.top, 4)

                        settingRow(
                            title: L10n.string("settings.focus.auto_break.title"),
                            detail: L10n.string("settings.focus.auto_break.detail"),
                            isOn: Binding(
                                get: { model.autoStartBreak },
                                set: { model.setAutoStartBreak($0) }
                            )
                        )
                        .padding(.top, 7)

                        settingRow(
                            title: L10n.string("settings.focus.auto_pomodoro.title"),
                            detail: L10n.string("settings.focus.auto_pomodoro.detail"),
                            isOn: Binding(
                                get: { model.autoStartFocus },
                                set: { model.setAutoStartFocus($0) }
                            )
                        )
                        .padding(.top, 5)

                        sectionHeader(L10n.string("settings.section.sound"))

                        settingRow(
                            title: L10n.string("settings.sound.chime.title"),
                            detail: L10n.string("settings.sound.chime.detail"),
                            isOn: Binding(
                                get: { model.chimeEnabled },
                                set: { model.setChimeEnabled($0) }
                            )
                        )

                        settingRow(
                            title: L10n.string("settings.sound.tick.title"),
                            detail: L10n.string("settings.sound.tick.detail"),
                            isOn: Binding(
                                get: { model.tickEnabled },
                                set: { model.setTickEnabled($0) }
                            )
                        )
                        .padding(.top, 5)

                        sectionHeader(L10n.string("settings.section.menu_bar"))

                        settingRow(
                            title: L10n.string("settings.menu_bar.minutes.title"),
                            detail: L10n.string("settings.menu_bar.minutes.detail"),
                            isOn: Binding(
                                get: { model.showMenuBarMinutes },
                                set: { model.setShowMenuBarMinutes($0) }
                            )
                        )

                        sectionHeader(L10n.string("settings.section.appearance"))

                        appearancePicker
                            .padding(.top, 8)

                        languageRow
                            .padding(.top, 12)

                        sectionHeader(L10n.string("settings.section.notifications"))

                        HStack(spacing: 8) {
                            Circle()
                                .fill(notificationColor)
                                .frame(width: 6, height: 6)
                            Text(model.notificationStatusText)
                                .font(Typo.sans(12, weight: "Medium"))
                                .foregroundStyle(palette.ink.opacity(0.86))
                                .frame(minHeight: Typo.lineHeight(12), alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button(L10n.string("settings.notifications.open")) {
                                model.openNotificationSettings()
                            }
                            .buttonStyle(QuietTextButtonStyle())
                        }
                        .padding(.top, 8)

                        if model.notificationStatus == .denied {
                            Text(L10n.string("settings.notifications.denied_detail"))
                                .font(Typo.sans(10))
                                .foregroundStyle(palette.mutedInk)
                                .frame(minHeight: Typo.lineHeight(10), alignment: .leading)
                                .padding(.top, 1)
                        }
                    }
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        scrolledHeight = height
                        reportNeededHeight()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                if let error = model.errorMessage {
                    ErrorNote(message: error, onDismiss: model.dismissError)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }

                Hairline()
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text(versionText)
                            .font(Typo.sans(9.5))
                            .foregroundStyle(palette.mutedInk.opacity(0.8))
                        UpdateDot(
                            hasUpdate: updates.hasUpdate,
                            isExpanded: showsUpdatePanel,
                            language: model.activeLanguage
                        ) {
                            showsUpdatePanel.toggle()
                        }
                    }
                    Spacer()
                    Button(L10n.string("settings.quit")) {
                        onQuit()
                    }
                    .buttonStyle(QuietTextButtonStyle())
                }
                .padding(.top, 7)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    footerHeight = height
                    reportNeededHeight()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showsUpdatePanel {
                UpdatePanel(
                    updates: updates,
                    language: model.activeLanguage,
                    onInstall: {
                        showsUpdatePanel = false
                        updates.installUpdate()
                    },
                    onCheck: {
                        showsUpdatePanel = false
                        updates.checkForUpdates()
                    },
                    onClose: {
                        showsUpdatePanel = false
                    }
                )
                .frame(maxWidth: 304)
                .padding(.bottom, 42)
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            model.refreshNotificationStatus()
        }
    }

    /// The card grows to this height, so the scrolling content and the footer
    /// never compete for the same space.
    private func reportNeededHeight() {
        guard scrolledHeight > 0, footerHeight > 0 else { return }
        onContentHeight(scrolledHeight + footerHeight + 0.7)
    }

    private var appearancePicker: some View {
        HStack(spacing: 6) {
            ForEach(ThemePreference.allCases, id: \.self) { preference in
                let isSelected = model.themePreference == preference
                Button {
                    model.setThemePreference(preference)
                } label: {
                    Text(preference.title)
                        .font(Typo.sans(11.5, weight: isSelected ? "DemiBold" : "Medium"))
                        .foregroundStyle(isSelected ? palette.boneTop : palette.ink.opacity(0.8))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isSelected ? palette.ink : palette.plaque.opacity(0.28))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? palette.ink : palette.brass.opacity(0.42),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.format("settings.appearance.theme_a11y", preference.title))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    private var languageRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(L10n.string("settings.language.title"))
                    .font(Typo.sans(12, weight: "Medium"))
                    .foregroundStyle(palette.ink.opacity(0.88))
                    .frame(minHeight: Typo.lineHeight(12), alignment: .leading)
                Text(model.languagePreference.detail)
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk)
                    .frame(minHeight: Typo.lineHeight(9.7), alignment: .leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            languageMenu
        }
    }

    private var languageMenu: some View {
        Menu {
            Toggle(
                isOn: Binding(
                    get: { model.languagePreference == .system },
                    set: { isOn in
                        if isOn {
                            model.setLanguagePreference(.system)
                        }
                    }
                )
            ) {
                Text(L10n.string("settings.language.system"))
            }

            Divider()

            ForEach(AppLanguage.allCases) { language in
                Toggle(
                    isOn: Binding(
                        get: { model.languagePreference == .language(language) },
                        set: { isOn in
                            if isOn {
                                model.setLanguagePreference(.language(language))
                            }
                        }
                    )
                ) {
                    Text(language.autonym)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 10.5, weight: .medium))
                    .accessibilityHidden(true)
                Text(model.languagePreference.title)
                    .font(Typo.sans(11.5, weight: "Medium"))
                    .lineLimit(1)
            }
            .foregroundStyle(palette.ink.opacity(0.84))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.plaque.opacity(0.28))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(palette.brass.opacity(0.42), lineWidth: 1)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help(model.languagePreference.detail)
        .accessibilityLabel(L10n.string("settings.language.title"))
        .accessibilityValue(model.languagePreference.title)
        .accessibilityHint(model.languagePreference.detail)
    }

    private var notificationColor: Color {
        switch model.notificationStatus {
        case .authorized, .provisional, .ephemeral:
            palette.sage
        case .denied:
            palette.tomato
        default:
            palette.brass
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return "v\(version)"
    }

    private func sectionHeader(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline(height: 1)
                .padding(.top, 12)
            sectionLabel(text)
                .padding(.top, 6)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typo.label(8.7))
            .tracking(Typo.tracking(1.9))
            .foregroundStyle(palette.mutedInk)
            .frame(minHeight: Typo.lineHeight(8.7), alignment: .leading)
    }

    private func settingRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(Typo.sans(12, weight: "Medium"))
                    .foregroundStyle(palette.ink.opacity(0.88))
                    .frame(minHeight: Typo.lineHeight(12), alignment: .leading)
                Text(detail)
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk)
                    .frame(minHeight: Typo.lineHeight(9.7), alignment: .leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(palette.tomato)
                .controlSize(.small)
                .accessibilityLabel(title)
        }
        .padding(.top, 7)
    }

    private var durationHeader: some View {
        Text(L10n.string("settings.durations.time_header"))
            .font(Typo.sans(10.5, weight: "Medium"))
            .foregroundStyle(palette.ink.opacity(0.84))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationColumns: some View {
        HStack(alignment: .top, spacing: 8) {
            durationColumn(.focus, title: L10n.string("timer.mode.focus"))
            durationColumn(.shortBreak, title: L10n.string("timer.mode.short_break"))
            durationColumn(.longBreak, title: L10n.string("timer.mode.long_break"))
        }
    }

    private func durationColumn(_ phase: Phase, title: String) -> some View {
        DurationColumn(
            title: title,
            minutes: model.durations.minutes(for: phase),
            isEditing: editingDuration == phase,
            range: IntervalDurations.allowedMinutes,
            onBeginEditing: { editingDuration = phase },
            onEndEditing: {
                if editingDuration == phase {
                    editingDuration = nil
                }
            },
            onChange: { model.setDurationMinutes($0, for: phase) }
        )
    }
}

private struct DurationColumn: View {
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
