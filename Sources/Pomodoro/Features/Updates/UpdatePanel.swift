import SwiftUI

struct UpdatePanel: View {
    @ObservedObject var updates: UpdateController
    let language: AppLanguage
    let onInstall: () -> Void
    let onCheck: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { Palette.forScheme(scheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.string("updates.panel.title"))
                    .font(Typo.sans(11.5, weight: "DemiBold"))
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 6)
                if updates.hasUpdate {
                    Button(L10n.string("updates.action.later"), action: onClose)
                        .buttonStyle(QuietTextButtonStyle())
                        .accessibilityHint(L10n.string("updates.action.later_hint"))
                } else {
                    Button(L10n.string("updates.action.check_now"), action: onCheck)
                    .buttonStyle(QuietTextButtonStyle(color: palette.ink))
                    .disabled(!updates.canCheckForUpdates)
                    .opacity(updates.canCheckForUpdates ? 1 : 0.45)
                }
            }

            HStack(alignment: .top, spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 4.5, height: 4.5)
                    .padding(.top, 4)
                Text(updates.statusText)
                    .font(Typo.sans(9.7, weight: updates.hasUpdate ? "Medium" : "Regular"))
                    .foregroundStyle(updates.hasUpdate ? palette.ink : palette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)

            if showsInstallButton {
                Button(L10n.string("updates.action.install")) {
                    onInstall()
                }
                .buttonStyle(UpdatePrimaryButtonStyle())
                .disabled(!updates.canInstallUpdate)
                .opacity(updates.canInstallUpdate ? 1 : 0.5)
                .padding(.top, 9)
            }

            Hairline()
                .padding(.top, showsInstallButton ? 9 : 7)

            HStack(spacing: 2) {
                Text(L10n.string("updates.section.automatic"))
                    .font(Typo.label(7.8))
                    .tracking(Typo.tracking(1.35))
                    .foregroundStyle(palette.mutedInk)
                Spacer(minLength: 8)
                ForEach(UpdateMode.allCases) { mode in
                    let isSelected = updates.mode == mode
                    Button(mode.title) {
                        updates.setMode(mode)
                    }
                    .font(Typo.sans(9.5, weight: isSelected ? "DemiBold" : "Medium"))
                    .foregroundStyle(
                        isSelected
                            ? palette.ink
                            : palette.mutedInk.opacity(0.88)
                    )
                    .buttonStyle(.plain)
                    .frame(minHeight: 24)
                    .padding(.horizontal, 4)
                    .overlay(alignment: .bottom) {
                        if isSelected {
                            Rectangle()
                                .fill(palette.ink.opacity(0.48))
                                .frame(height: 0.7)
                                .padding(.horizontal, 4)
                        }
                    }
                    .disabled(!updates.isAvailable)
                    .opacity(updates.isAvailable ? 1 : 0.45)
                    .help(mode.detail)
                    .accessibilityLabel(L10n.format("updates.mode.a11y", mode.title))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.top, 1)

            if updates.isBetaChannelAvailable {
                Hairline()
                    .padding(.top, 6)

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.string("updates.beta.title"))
                            .font(Typo.sans(9.5, weight: "Medium"))
                            .foregroundStyle(palette.ink.opacity(0.86))
                        Text(L10n.string("updates.beta.detail"))
                            .font(Typo.sans(8.6))
                            .foregroundStyle(palette.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 6)
                    Toggle("", isOn: betaChannelBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(palette.tomato)
                        .controlSize(.mini)
                        .accessibilityLabel(L10n.string("updates.beta.title"))
                        .accessibilityHint(L10n.string("updates.beta.detail"))
                }
                .padding(.top, 5)
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 11)
        .padding(.top, 9)
        .padding(.bottom, 3)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(palette.plaque)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(palette.brass.opacity(0.48), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
        }
        .accessibilityElement(children: .contain)
        .id(language)
    }

    private var betaChannelBinding: Binding<Bool> {
        Binding(
            get: { updates.isBetaChannelEnabled },
            set: { updates.setBetaChannelEnabled($0) }
        )
    }

    private var showsInstallButton: Bool {
        if case .installing = updates.availability {
            return false
        }
        return updates.hasUpdate
    }

    private var statusColor: Color {
        if updates.hasUpdate {
            return palette.tomato
        }
        if case .upToDate = updates.availability {
            return palette.sage
        }
        return palette.mutedInk.opacity(0.48)
    }
}

private struct UpdatePrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let palette = Palette.forScheme(scheme)

        configuration.label
            .font(Typo.sans(11, weight: "DemiBold"))
            .foregroundStyle(palette.boneTop)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.ink.opacity(configuration.isPressed ? 0.86 : 1))
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.988 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}
