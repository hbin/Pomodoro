import Foundation

public struct TimerState: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    /// The focus length captured when the current or last focus started.
    /// New intervals read `IntervalDurations.focusMinutes`; this field remains
    /// for older state files and the active-interval snapshot.
    public var selectedFocusMinutes: Int
    public var phase: Phase
    public var runState: RunState
    public var totalSeconds: TimeInterval
    public var remainingSeconds: TimeInterval
    public var endDate: Date?
    /// Focus intervals completed naturally in the current cycle.
    public var completedFocusCount: Int
    /// Focus intervals that count toward the current four-focus cycle. Early
    /// ends advance this without changing `completedFocusCount`.
    public var focusCyclePosition: Int

    public init(
        version: Int = TimerState.currentVersion,
        selectedFocusMinutes: Int = 25,
        phase: Phase = .focus,
        runState: RunState = .idle,
        totalSeconds: TimeInterval = 25 * 60,
        remainingSeconds: TimeInterval = 25 * 60,
        endDate: Date? = nil,
        completedFocusCount: Int = 0,
        focusCyclePosition: Int? = nil
    ) {
        self.version = version
        self.selectedFocusMinutes = selectedFocusMinutes
        self.phase = phase
        self.runState = runState
        self.totalSeconds = totalSeconds
        self.remainingSeconds = remainingSeconds
        self.endDate = endDate
        self.completedFocusCount = completedFocusCount
        self.focusCyclePosition = max(0, focusCyclePosition ?? completedFocusCount)
    }

    public static var initial: TimerState { TimerState() }

    private enum CodingKeys: String, CodingKey {
        case version
        case selectedFocusMinutes
        case phase
        case runState
        case totalSeconds
        case remainingSeconds
        case endDate
        case completedFocusCount
        case focusCyclePosition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TimerState()
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? defaults.version
        selectedFocusMinutes = try container.decodeIfPresent(Int.self, forKey: .selectedFocusMinutes) ?? defaults.selectedFocusMinutes
        phase = try container.decodeIfPresent(Phase.self, forKey: .phase) ?? defaults.phase
        runState = try container.decodeIfPresent(RunState.self, forKey: .runState) ?? defaults.runState
        totalSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .totalSeconds) ?? defaults.totalSeconds
        remainingSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .remainingSeconds) ?? defaults.remainingSeconds
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        completedFocusCount = try container.decodeIfPresent(Int.self, forKey: .completedFocusCount) ?? defaults.completedFocusCount
        focusCyclePosition = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .focusCyclePosition)
                ?? completedFocusCount
        )
    }
}
