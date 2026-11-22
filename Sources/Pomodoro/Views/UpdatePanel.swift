import SwiftUI

struct UpdateDot: View {
    let hasUpdate: Bool
    let isExpanded: Bool
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
        .help(hasUpdate ? "Update available" : "Update settings")
        .accessibilityLabel("Update settings")
        .accessibilityValue(hasUpdate ? "Update available" : "No update available")
        .accessibilityHint("Shows update controls")
        .accessibilityAddTraits(isExpanded ? [.isSelected] : [])
    }
}

struct UpdatePanel: View {
    @ObservedObject var updates: UpdateController
    let onInstall: () -> Void
    let onCheck: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { Palette.forScheme(scheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Updates")
                    .font(Typo.sans(11.5, weight: "DemiBold"))
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 6)
                if updates.hasUpdate {
                    Button("Later", action: onClose)
                        .buttonStyle(QuietTextButtonStyle())
                        .accessibilityHint("Keeps the update available")
                } else {
                    Button("Check Now", action: onCheck)
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
                Button("Install Update") {
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
                Text("AUTOMATIC")
                    .font(Typo.label(7.8))
                    .tracking(1.35)
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
                    .accessibilityLabel("\(mode.title) updates")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.top, 1)
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
