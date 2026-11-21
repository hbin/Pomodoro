import Foundation

public enum Phase: String, Codable, Sendable, Equatable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    public var isBreak: Bool {
        self != .focus
    }
}

public enum RunState: String, Codable, Sendable, Equatable {
    case idle
    case running
    case paused
    case completed
}

public struct TimerState: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var selectedFocusMinutes: Int
    public var phase: Phase
    public var runState: RunState
    public var totalSeconds: TimeInterval
    public var remainingSeconds: TimeInterval
    public var endDate: Date?
    public var completedFocusCount: Int

    public init(
        version: Int = TimerState.currentVersion,
        selectedFocusMinutes: Int = 25,
        phase: Phase = .focus,
        runState: RunState = .idle,
        totalSeconds: TimeInterval = 25 * 60,
        remainingSeconds: TimeInterval = 25 * 60,
        endDate: Date? = nil,
        completedFocusCount: Int = 0
    ) {
        self.version = version
        self.selectedFocusMinutes = selectedFocusMinutes
        self.phase = phase
        self.runState = runState
        self.totalSeconds = totalSeconds
        self.remainingSeconds = remainingSeconds
        self.endDate = endDate
        self.completedFocusCount = completedFocusCount
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
    }
}

public enum TimerEvent: Equatable, Sendable {
    case completed(Phase)
}

public struct TimerEngine {
    public private(set) var state: TimerState
    public var now: @Sendable () -> Date

    public static let focusChoices = [15, 25, 45]

    public init(
        state: TimerState = .initial,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.now = now
        self.state = Self.sanitized(state)
    }

    private static func sanitized(_ raw: TimerState) -> TimerState {
        var state = raw
        if !focusChoices.contains(state.selectedFocusMinutes) {
            state.selectedFocusMinutes = 25
        }
        state.completedFocusCount = max(0, state.completedFocusCount)

        switch state.runState {
        case .idle:
            state.phase = .focus
            state.totalSeconds = TimeInterval(state.selectedFocusMinutes * 60)
            state.remainingSeconds = state.totalSeconds
            state.endDate = nil
        case .running:
            if state.endDate == nil {
                state.runState = .paused
            }
            if state.totalSeconds <= 0 {
                state.totalSeconds = TimeInterval(state.selectedFocusMinutes * 60)
            }
            state.remainingSeconds = clamped(state.remainingSeconds, to: state.totalSeconds)
        case .paused:
            if state.totalSeconds <= 0 {
                state.totalSeconds = TimeInterval(state.selectedFocusMinutes * 60)
            }
            state.remainingSeconds = clamped(state.remainingSeconds, to: state.totalSeconds)
            state.endDate = nil
        case .completed:
            if state.totalSeconds <= 0 {
                state.totalSeconds = TimeInterval(state.selectedFocusMinutes * 60)
            }
            state.remainingSeconds = 0
            state.endDate = nil
        }
        return state
    }

    private static func clamped(_ value: TimeInterval, to total: TimeInterval) -> TimeInterval {
        min(max(0, value), total)
    }

    // MARK: - Queries

    public func remaining(at date: Date? = nil) -> TimeInterval {
        let date = date ?? now()
        switch state.runState {
        case .running:
            guard let endDate = state.endDate else { return state.remainingSeconds }
            return min(max(0, endDate.timeIntervalSince(date)), state.totalSeconds)
        case .idle:
            return state.totalSeconds
        case .paused, .completed:
            return state.remainingSeconds
        }
    }

    public func displaySeconds(at date: Date? = nil) -> Int {
        Int(ceil(remaining(at: date)))
    }

    public func progress(at date: Date? = nil) -> Double {
        guard state.totalSeconds > 0 else { return 0 }
        let fraction = 1 - (remaining(at: date) / state.totalSeconds)
        return min(max(0, fraction), 1)
    }

    public func minuteDialProgress(at date: Date? = nil) -> Double {
        min(max(remaining(at: date) / 3600, 0), 1)
    }

    public var recommendedBreak: (minutes: Int, phase: Phase) {
        let isLong = state.completedFocusCount > 0 && state.completedFocusCount % 4 == 0
        return isLong ? (15, .longBreak) : (5, .shortBreak)
    }

    public var selectedDurationSeconds: TimeInterval {
        TimeInterval(state.selectedFocusMinutes * 60)
    }

    // MARK: - Lifecycle

    /// Reconciles a restored state with the current clock. Returns a completion
    /// event when the app was shut down or asleep past the interval's end.
    public mutating func restore() -> TimerEvent? {
        guard state.runState == .running, let endDate = state.endDate else {
            return nil
        }
        let date = now()
        if endDate <= date {
            return finish()
        }
        if endDate.timeIntervalSince(date) > state.totalSeconds {
            state.endDate = date.addingTimeInterval(state.totalSeconds)
        }
        return nil
    }

    public mutating func refresh() -> TimerEvent? {
        guard state.runState == .running else { return nil }
        guard let endDate = state.endDate else {
            state.runState = .paused
            return nil
        }
        let date = now()
        if date >= endDate {
            return finish()
        }
        if endDate.timeIntervalSince(date) > state.totalSeconds {
            state.endDate = date.addingTimeInterval(state.totalSeconds)
        }
        return nil
    }

    @discardableResult
    public mutating func startFocus(minutes: Int? = nil) -> Date? {
        let minutes = minutes ?? state.selectedFocusMinutes
        guard Self.focusChoices.contains(minutes) else { return nil }

        if state.runState == .completed, state.phase == .focus,
           recommendedBreak.phase == .longBreak {
            state.completedFocusCount = 0
        }

        state.selectedFocusMinutes = minutes
        state.phase = .focus
        state.totalSeconds = TimeInterval(minutes * 60)
        state.remainingSeconds = state.totalSeconds
        state.endDate = now().addingTimeInterval(state.totalSeconds)
        state.runState = .running
        return state.endDate
    }

    public mutating func selectFocusMinutes(_ minutes: Int) {
        guard state.runState == .idle, Self.focusChoices.contains(minutes) else { return }
        state.selectedFocusMinutes = minutes
        state.totalSeconds = TimeInterval(minutes * 60)
        state.remainingSeconds = state.totalSeconds
    }

    @discardableResult
    public mutating func startRecommendedBreak() -> Date? {
        guard state.runState == .completed, state.phase == .focus else { return nil }
        let recommendation = recommendedBreak
        state.phase = recommendation.phase
        state.totalSeconds = TimeInterval(recommendation.minutes * 60)
        state.remainingSeconds = state.totalSeconds
        state.endDate = now().addingTimeInterval(state.totalSeconds)
        state.runState = .running
        return state.endDate
    }

    @discardableResult
    public mutating func startAnother() -> Date? {
        guard state.runState == .completed else { return nil }
        if state.phase == .focus, recommendedBreak.phase == .longBreak {
            state.completedFocusCount = 0
        }
        return startFocus(minutes: state.selectedFocusMinutes)
    }

    @discardableResult
    public mutating func pause() -> TimerEvent? {
        guard state.runState == .running, let endDate = state.endDate else { return nil }
        let remaining = endDate.timeIntervalSince(now())
        if remaining <= 0 {
            return finish()
        }
        state.remainingSeconds = min(remaining, state.totalSeconds)
        state.endDate = nil
        state.runState = .paused
        return nil
    }

    @discardableResult
    public mutating func resume() -> Date? {
        guard state.runState == .paused, state.remainingSeconds > 0 else { return nil }
        let endDate = now().addingTimeInterval(state.remainingSeconds)
        state.endDate = endDate
        state.runState = .running
        return endDate
    }

    /// Ends the current interval early. A focus interval ended this way never
    /// advances the long-break rhythm.
    public mutating func endEarly() {
        toIdle()
    }

    /// Declines the offered break from the focus-complete state.
    public mutating func skipBreak() {
        guard state.runState == .completed, state.phase == .focus else {
            endEarly()
            return
        }
        if recommendedBreak.phase == .longBreak {
            state.completedFocusCount = 0
        }
        toIdle()
    }

    public mutating func doneForNow() {
        if state.runState == .completed, state.phase == .focus,
           recommendedBreak.phase == .longBreak {
            state.completedFocusCount = 0
        }
        toIdle()
    }

    private mutating func toIdle() {
        state.phase = .focus
        state.runState = .idle
        state.selectedFocusMinutes = 25
        state.totalSeconds = 25 * 60
        state.remainingSeconds = 25 * 60
        state.endDate = nil
    }

    private mutating func finish() -> TimerEvent {
        let finishedPhase = state.phase
        state.runState = .completed
        state.endDate = nil
        state.remainingSeconds = 0
        if finishedPhase == .focus {
            state.completedFocusCount += 1
        }
        return .completed(finishedPhase)
    }
}
