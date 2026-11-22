import SwiftUI
import PomodoroCore
import UserNotifications

struct SettingsView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var updates: UpdateController
    let onQuit: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var showsUpdatePanel = false

    private var palette: Palette { Palette.forScheme(scheme) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(Typo.serif(29))
                    .foregroundStyle(palette.ink)
                Text("A quiet timer, nothing to manage.")
                    .font(Typo.sans(10.7))
                    .foregroundStyle(palette.mutedInk)
                    .padding(.top, 2)

                sectionLabel("APPEARANCE")
                    .padding(.top, 13)
                Hairline()
                    .padding(.top, 4)

                appearancePicker
                    .padding(.top, 8)

                sectionLabel("SOUND")
                    .padding(.top, 13)
                Hairline()
                    .padding(.top, 4)

                settingRow(
                    title: "Completion chime",
                    detail: "A soft two-note chime when an interval ends.",
                    isOn: Binding(
                        get: { model.chimeEnabled },
                        set: { model.setChimeEnabled($0) }
                    )
                )

                Hairline()
                    .padding(.vertical, 6)

                settingRow(
                    title: "Tick sound",
                    detail: "A quiet tick each second during focus only.",
                    isOn: Binding(
                        get: { model.tickEnabled },
                        set: { model.setTickEnabled($0) }
                    )
                )

                sectionLabel("MENU BAR")
                    .padding(.top, 13)
                Hairline()
                    .padding(.top, 4)

                settingRow(
                    title: "Show remaining minutes",
                    detail: "Clock time stays hidden when this is off.",
                    isOn: Binding(
                        get: { model.showMenuBarMinutes },
                        set: { model.setShowMenuBarMinutes($0) }
                    )
                )

                sectionLabel("NOTIFICATIONS")
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
                    Spacer()
                    Button("Open Settings") {
                        model.openNotificationSettings()
                    }
                    .buttonStyle(QuietTextButtonStyle())
                }
                .padding(.top, 10)

                if model.notificationStatus == .denied {
                    Text("The timer still works without notifications.")
                        .font(Typo.sans(10))
                        .foregroundStyle(palette.mutedInk)
                        .padding(.top, 1)
                }

                if let error = model.errorMessage {
                    ErrorNote(message: error, onDismiss: model.dismissError)
                        .padding(.top, 10)
                }

                Spacer(minLength: 4)

                Hairline()
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text(versionText)
                            .font(Typo.sans(9.5))
                            .foregroundStyle(palette.mutedInk.opacity(0.8))
                        UpdateDot(
                            hasUpdate: updates.hasUpdate,
                            isExpanded: showsUpdatePanel
                        ) {
                            showsUpdatePanel.toggle()
                        }
                    }
                    Spacer()
                    Button("Done") {
                        onClose()
                    }
                    .buttonStyle(QuietTextButtonStyle(color: palette.ink))
                    Button("Quit Pomodoro") {
                        onQuit()
                    }
                    .buttonStyle(QuietTextButtonStyle())
                }
                .padding(.top, 7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showsUpdatePanel {
                UpdatePanel(
                    updates: updates,
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
                .accessibilityLabel("\(preference.title) theme")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
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
            .tracking(1.9)
            .foregroundStyle(palette.mutedInk)
    }

    private func settingRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(Typo.sans(12, weight: "Medium"))
                    .foregroundStyle(palette.ink.opacity(0.88))
                Text(detail)
                    .font(Typo.sans(9.7))
                    .foregroundStyle(palette.mutedInk)
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
