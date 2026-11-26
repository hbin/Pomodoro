import Foundation

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
