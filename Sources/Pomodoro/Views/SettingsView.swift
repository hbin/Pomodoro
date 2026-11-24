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

                        sectionLabel(L10n.string("settings.section.appearance"))
                            .padding(.top, 13)
                        Hairline()
                            .padding(.top, 4)

                        appearancePicker
                            .padding(.top, 8)

                        Hairline()
                            .padding(.top, 10)

                        languageRow
                            .padding(.top, 8)

                        sectionLabel(L10n.string("settings.section.sound"))
                            .padding(.top, 13)
                        Hairline()
                            .padding(.top, 4)

                        settingRow(
                            title: L10n.string("settings.sound.chime.title"),
                            detail: L10n.string("settings.sound.chime.detail"),
                            isOn: Binding(
                                get: { model.chimeEnabled },
                                set: { model.setChimeEnabled($0) }
                            )
                        )

                        Hairline()
                            .padding(.vertical, 6)

                        settingRow(
                            title: L10n.string("settings.sound.tick.title"),
                            detail: L10n.string("settings.sound.tick.detail"),
                            isOn: Binding(
                                get: { model.tickEnabled },
                                set: { model.setTickEnabled($0) }
                            )
                        )

                        sectionLabel(L10n.string("settings.section.focus"))
                            .padding(.top, 13)
                        Hairline()
                            .padding(.top, 4)

                        settingRow(
                            title: L10n.string("settings.focus.auto_break.title"),
                            detail: L10n.string("settings.focus.auto_break.detail"),
                            isOn: Binding(
                                get: { model.autoStartBreak },
                                set: { model.setAutoStartBreak($0) }
                            )
                        )

                        Hairline()
                            .padding(.vertical, 6)

                        settingRow(
                            title: L10n.string("settings.focus.auto_pomodoro.title"),
                            detail: L10n.string("settings.focus.auto_pomodoro.detail"),
                            isOn: Binding(
                                get: { model.autoStartFocus },
                                set: { model.setAutoStartFocus($0) }
                            )
                        )

                        sectionLabel(L10n.string("settings.section.menu_bar"))
                            .padding(.top, 13)
                        Hairline()
                            .padding(.top, 4)

                        settingRow(
                            title: L10n.string("settings.menu_bar.minutes.title"),
                            detail: L10n.string("settings.menu_bar.minutes.detail"),
                            isOn: Binding(
                                get: { model.showMenuBarMinutes },
                                set: { model.setShowMenuBarMinutes($0) }
                            )
                        )

                        sectionLabel(L10n.string("settings.section.notifications"))
                            .padding(.top, 13)
                        Hairline()
                            .padding(.top, 4)

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
                        .padding(.top, 10)

                        if model.notificationStatus == .denied {
                            Text(L10n.string("settings.notifications.denied_detail"))
                                .font(Typo.sans(10))
                                .foregroundStyle(palette.mutedInk)
                                .frame(minHeight: Typo.lineHeight(10), alignment: .leading)
                                .padding(.top, 1)
                        }
                    }
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
                .frame(width: 304)
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
}
