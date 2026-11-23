import Foundation

public enum ThemePreference: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case system
    case light
    case dark
}

public struct PersistedState: Codable, Sendable, Equatable {
    public var timer: TimerState
    public var chimeEnabled: Bool
    public var tickEnabled: Bool
    public var showMenuBarMinutes: Bool
    public var themePreference: ThemePreference
    public var firstRunTipDismissed: Bool

    public init(
        timer: TimerState = .initial,
        chimeEnabled: Bool = true,
        tickEnabled: Bool = false,
        showMenuBarMinutes: Bool = true,
        themePreference: ThemePreference = .system,
        firstRunTipDismissed: Bool = false
    ) {
        self.timer = timer
        self.chimeEnabled = chimeEnabled
        self.tickEnabled = tickEnabled
        self.showMenuBarMinutes = showMenuBarMinutes
        self.themePreference = themePreference
        self.firstRunTipDismissed = firstRunTipDismissed
    }

    private enum CodingKeys: String, CodingKey {
        case timer
        case chimeEnabled
        case tickEnabled
        case showMenuBarMinutes
        case themePreference
        case firstRunTipDismissed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PersistedState()
        timer = try container.decodeIfPresent(TimerState.self, forKey: .timer) ?? defaults.timer
        chimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .chimeEnabled) ?? defaults.chimeEnabled
        tickEnabled = try container.decodeIfPresent(Bool.self, forKey: .tickEnabled) ?? defaults.tickEnabled
        showMenuBarMinutes = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarMinutes) ?? defaults.showMenuBarMinutes
        themePreference = try container.decodeIfPresent(ThemePreference.self, forKey: .themePreference) ?? defaults.themePreference
        firstRunTipDismissed = try container.decodeIfPresent(Bool.self, forKey: .firstRunTipDismissed) ?? defaults.firstRunTipDismissed
    }
}

public enum StateRecoveryIssue: Sendable, Equatable {
    case unreadableStateBackedUp
    case unreadableStateReset
}

public struct LoadResult: Sendable {
    public var state: PersistedState
    public var isFirstRun: Bool
    public var backupURL: URL?
    public var recoveryIssue: StateRecoveryIssue?

    public init(
        state: PersistedState,
        isFirstRun: Bool,
        backupURL: URL? = nil,
        recoveryIssue: StateRecoveryIssue? = nil
    ) {
        self.state = state
        self.isFirstRun = isFirstRun
        self.backupURL = backupURL
        self.recoveryIssue = recoveryIssue
    }
}

public struct StateStore {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Pomodoro", isDirectory: true)
    }

    public var stateURL: URL {
        directory.appendingPathComponent("state.json", isDirectory: false)
    }

    public func load() -> LoadResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: stateURL.path) else {
            return LoadResult(state: PersistedState(), isFirstRun: true)
        }

        do {
            let data = try Data(contentsOf: stateURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(PersistedState.self, from: data)
            return LoadResult(state: state, isFirstRun: false)
        } catch {
            let backupURL = uniqueBackupURL()
            var didBackUp = false
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                try fileManager.moveItem(at: stateURL, to: backupURL)
                didBackUp = true
            } catch {
                didBackUp = false
            }
            return LoadResult(
                state: PersistedState(),
                isFirstRun: false,
                backupURL: didBackUp ? backupURL : nil,
                recoveryIssue: didBackUp ? .unreadableStateBackedUp : .unreadableStateReset
            )
        }
    }

    public func save(_ state: PersistedState) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: [.atomic])
    }

    private func uniqueBackupURL() -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        var candidate = directory.appendingPathComponent("state-unreadable-\(stamp).json")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("state-unreadable-\(stamp)-\(counter).json")
            counter += 1
        }
        return candidate
    }
}
