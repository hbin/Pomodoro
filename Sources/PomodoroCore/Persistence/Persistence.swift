import Foundation

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
        let data = try encoder.encode(state.readyStateNormalizedForPersistence())
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
