import SwiftUI
import PomodoroCore
import UserNotifications

struct SettingsView: View {
    @ObservedObject var model: TimerModel
    let onQuit: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var confirmingReset = false

    private var palette: Palette { Palette.forScheme(scheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(Typo.serif(29))
                    .foregroundStyle(palette.ink)
                Text("A quiet timer, nothing to manage.")
                    .font(Typo.sans(10.7))
                    .foregroundStyle(palette.mutedInk)
                    .padding(.top, 2)

                sectionLabel("APPEARANCE")
                    .padding(.top, 16)
                Hairline()
                    .padding(.top, 7)

                appearancePicker
                    .padding(.top, 8)

                sectionLabel("SOUND")
                    .padding(.top, 18)
                Hairline()
                    .padding(.top, 7)

                settingRow(
                    title: "Completion chime",
                    detail: "A soft two-note chime when an interval ends.",
                    isOn: Binding(
                        get: { model.chimeEnabled },
                        set: { model.setChimeEnabled($0) }
                    )
                )

                Hairline()
                    .padding(.vertical, 9)

                settingRow(
                    title: "Tick sound",
                    detail: "A quiet tick each second during focus only.",
                    isOn: Binding(
                        get: { model.tickEnabled },
                        set: { model.setTickEnabled($0) }
                    )
                )

                sectionLabel("MENU BAR")
                    .padding(.top, 18)
                Hairline()
                    .padding(.top, 7)

                settingRow(
                    title: "Show remaining minutes",
                    detail: "Clock time stays hidden when this is off.",
                    isOn: Binding(
                        get: { model.showMenuBarMinutes },
                        set: { model.setShowMenuBarMinutes($0) }
                    )
                )

                sectionLabel("NOTIFICATIONS")
                    .padding(.top, 18)
                Hairline()
                    .padding(.top, 7)

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

                sectionLabel("RESET")
                    .padding(.top, 18)
                Hairline()
                    .padding(.top, 7)

                if confirmingReset {
                    resetConfirmation
                        .padding(.top, 8)
                } else {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Reset timer and preferences")
                                .font(Typo.sans(12, weight: "Medium"))
                                .foregroundStyle(palette.ink.opacity(0.86))
                            Text("Clears the current interval and rhythm.")
                                .font(Typo.sans(9.7))
                                .foregroundStyle(palette.mutedInk)
                        }
                        Spacer()
                        Button("Reset…") {
                            confirmingReset = true
                        }
                        .buttonStyle(QuietTextButtonStyle(color: palette.tomato))
                    }
                    .padding(.top, 10)
                }

                if let error = model.errorMessage {
                    ErrorNote(message: error, onDismiss: model.dismissError)
                        .padding(.top, 10)
                }

                Spacer(minLength: 10)

                Hairline()
                HStack(spacing: 6) {
                    Text(versionText)
                        .font(Typo.sans(9.5))
                        .foregroundStyle(palette.mutedInk.opacity(0.8))
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
                .padding(.top, 9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            model.refreshNotificationStatus()
        }
        .preferredColorScheme(LaunchAppearance.colorScheme(for: model.themePreference))
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

    private var resetConfirmation: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text("Reset timer and preferences?")
                    .font(Typo.sans(11.5, weight: "DemiBold"))
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 2)
                Button("Cancel") {
                    confirmingReset = false
                }
                .buttonStyle(QuietTextButtonStyle())
                Button("Reset") {
                    confirmingReset = false
                    model.resetEverything()
                }
                .buttonStyle(QuietTextButtonStyle(color: palette.tomato))
            }
            Text("The current interval will be discarded. This can’t be undone.")
                .font(Typo.sans(9.7))
                .foregroundStyle(palette.mutedInk)
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
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Pomodoro \(version) (\(build))"
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
        .padding(.top, 10)
    }
}
