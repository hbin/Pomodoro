import Foundation
import Sparkle

enum UpdateMode: String, CaseIterable, Identifiable {
    case notify
    case download
    case never

    var id: Self { self }

    var title: String {
        switch self {
        case .notify: "Notify"
        case .download: "Download"
        case .never: "Never"
        }
    }

    var detail: String {
        switch self {
        case .notify:
            "Checks daily; you choose when to install."
        case .download:
            "Downloads quietly and installs when Pomodoro quits."
        case .never:
            "Automatic updates off; manual checks still work."
        }
    }

    init(automaticallyChecks: Bool, automaticallyDownloads: Bool) {
        if !automaticallyChecks {
            self = .never
        } else if automaticallyDownloads {
            self = .download
        } else {
            self = .notify
        }
    }
}

enum UpdateAvailability: Equatable {
    case unknown
    case upToDate
    case available(version: String)
    case ready(version: String)
    case installing(version: String)

    var hasUpdate: Bool {
        switch self {
        case .available, .ready, .installing:
            true
        case .unknown, .upToDate:
            false
        }
    }

    var version: String? {
        switch self {
        case .available(let version), .ready(let version), .installing(let version):
            version
        case .unknown, .upToDate:
            nil
        }
    }
}

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var mode: UpdateMode = .notify
    @Published private(set) var availability: UpdateAvailability = .unknown

    private var updaterController: SPUStandardUpdaterController?
    private var observations: [NSKeyValueObservation] = []
    private var immediateInstallHandler: (() -> Void)?
    private var hasStarted = false

    var isAvailable: Bool {
        updaterController != nil
    }

    var hasUpdate: Bool {
        availability.hasUpdate
    }

    var statusText: String {
        guard isAvailable else {
            return "Updates are unavailable in this build."
        }

        switch availability {
        case .unknown:
            return mode.detail
        case .upToDate:
            return "Pomodoro is up to date."
        case .available(let version):
            return "Version \(version) is available."
        case .ready(let version):
            return "Version \(version) is ready to install."
        case .installing(let version):
            return "Installing version \(version)…"
        }
    }

    var canInstallUpdate: Bool {
        immediateInstallHandler != nil || canCheckForUpdates
    }

    override init() {
        super.init()

        guard let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              !feedURL.isEmpty,
              let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              !publicKey.isEmpty else {
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        updaterController = controller
        syncState(from: controller.updater)
    }

    func start() {
        guard let updaterController, !hasStarted else { return }
        hasStarted = true
        observe(updaterController.updater)
        syncState(from: updaterController.updater)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, let updaterController = self.updaterController else { return }
            updaterController.startUpdater()
            self.syncState(from: updaterController.updater)
        }
    }

    func setMode(_ mode: UpdateMode) {
        guard let updater = updaterController?.updater else { return }

        switch mode {
        case .notify:
            updater.automaticallyDownloadsUpdates = false
            updater.automaticallyChecksForUpdates = true
        case .download:
            updater.automaticallyChecksForUpdates = true
            updater.automaticallyDownloadsUpdates = true
        case .never:
            updater.automaticallyDownloadsUpdates = false
            updater.automaticallyChecksForUpdates = false
        }

        syncState(from: updater)
    }

    func checkForUpdates() {
        guard let updater = updaterController?.updater,
              updater.canCheckForUpdates else {
            return
        }
        updater.checkForUpdates()
    }

    func installUpdate() {
        if let immediateInstallHandler {
            self.immediateInstallHandler = nil
            if let version = availability.version {
                availability = .installing(version: version)
            }
            immediateInstallHandler()
        } else {
            checkForUpdates()
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        immediateInstallHandler = nil
        availability = .available(version: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        immediateInstallHandler = nil
        availability = .upToDate
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        availability = .ready(version: item.displayVersionString)
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        availability = .installing(version: item.displayVersionString)
    }

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        availability = .ready(version: item.displayVersionString)
        self.immediateInstallHandler = immediateInstallHandler
        return true
    }

    func updater(
        _ updater: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate item: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        switch choice {
        case .skip:
            immediateInstallHandler = nil
            availability = .unknown
        case .install:
            availability = .installing(version: item.displayVersionString)
        case .dismiss:
            switch state.stage {
            case .downloaded:
                availability = .ready(version: item.displayVersionString)
            case .installing:
                availability = .installing(version: item.displayVersionString)
            case .notDownloaded:
                availability = .available(version: item.displayVersionString)
            @unknown default:
                availability = .available(version: item.displayVersionString)
            }
        @unknown default:
            break
        }
    }

    private func observe(_ updater: SPUUpdater) {
        observations = [
            updater.observe(
                \.automaticallyChecksForUpdates,
                options: [.initial, .new]
            ) { [weak self] updater, _ in
                MainActor.assumeIsolated {
                    self?.mode = UpdateMode(
                        automaticallyChecks: updater.automaticallyChecksForUpdates,
                        automaticallyDownloads: updater.automaticallyDownloadsUpdates
                    )
                }
            },
            updater.observe(
                \.automaticallyDownloadsUpdates,
                options: [.initial, .new]
            ) { [weak self] updater, _ in
                MainActor.assumeIsolated {
                    self?.mode = UpdateMode(
                        automaticallyChecks: updater.automaticallyChecksForUpdates,
                        automaticallyDownloads: updater.automaticallyDownloadsUpdates
                    )
                }
            },
            updater.observe(
                \.canCheckForUpdates,
                options: [.initial, .new]
            ) { [weak self] updater, _ in
                MainActor.assumeIsolated {
                    self?.canCheckForUpdates = updater.canCheckForUpdates
                }
            }
        ]
    }

    private func syncState(from updater: SPUUpdater) {
        mode = UpdateMode(
            automaticallyChecks: updater.automaticallyChecksForUpdates,
            automaticallyDownloads: updater.automaticallyDownloadsUpdates
        )
        canCheckForUpdates = updater.canCheckForUpdates
    }
}
