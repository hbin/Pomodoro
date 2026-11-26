import Foundation

public struct TimerEngine {
    public private(set) var state: TimerState
    public private(set) var durations: IntervalDurations
    public var now: @Sendable () -> Date

    /// The fixed end-control handoff. The next interval is shown running
    /// immediately, but its countdown stays full for this long.
    public static let endControlHandoffDelay: TimeInterval = 1.0

    /// Allows a running interval's end date to sit slightly more than its total
    /// duration in the future. Auto-start break uses this window to hold its
    /// countdown until the completion chime ends; beyond it, a backwards clock
    /// is clamped.
    private static let clockDriftTolerance: TimeInterval = 2

    public init(
        state: TimerState = .initial,
        durations: IntervalDurations = .defaults,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.now = now
        self.durations = durations
        self.state = Self.sanitized(state, durations: durations)
    }

    /// Updates the lengths used by the next interval. An idle Ready interval
    /// follows its phase's new length immediately; a running, paused, or
    /// completed interval keeps the duration it captured when it started.
    public mutating func applyDurations(_ durations: IntervalDurations) {
        self.durations = durations
        guard state.runState == .idle else { return }
        state.selectedFocusMinutes = durations.focusMinutes
        state.totalSeconds = TimeInterval(durations.minutes(for: state.phase) * 60)
        state.remainingSeconds = state.totalSeconds
        state.endDate = nil
    }

    private static func sanitized(
        _ raw: TimerState,
        durations: IntervalDurations
    ) -> TimerState {
        var state = raw
        if !IntervalDurations.allowedMinutes.contains(state.selectedFocusMinutes) {
            state.selectedFocusMinutes = durations.focusMinutes
        }
        state.completedFocusCount = max(0, state.completedFocusCount)
        state.focusCyclePosition = max(0, state.focusCyclePosition)

        switch state.runState {
        case .idle:
            state.phase = .focus
            state.selectedFocusMinutes = durations.focusMinutes
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

    public var recommendedBreak: (minutes: Int, phase: Phase) {
        let isLong = state.focusCyclePosition > 0 && state.focusCyclePosition % 4 == 0
        return isLong
            ? (durations.longBreakMinutes, .longBreak)
            : (durations.shortBreakMinutes, .shortBreak)
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
        if endDate.timeIntervalSince(date) > state.totalSeconds + Self.clockDriftTolerance {
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
        if endDate.timeIntervalSince(date) > state.totalSeconds + Self.clockDriftTolerance {
            state.endDate = date.addingTimeInterval(state.totalSeconds)
        }
        return nil
    }

    @discardableResult
    public mutating func startFocus(after delay: TimeInterval = 0) -> Date? {
        resetFocusCycleIfComplete()
        return begin(.focus, after: delay)
    }

    @discardableResult
    public mutating func startBreak(_ phase: Phase) -> Date? {
        guard state.runState == .idle, phase.isBreak else { return nil }
        return begin(phase)
    }

    @discardableResult
    public mutating func startRecommendedBreak(after delay: TimeInterval = 0) -> Date? {
        guard state.runState == .completed, state.phase == .focus else { return nil }
        return begin(recommendedBreak.phase, after: delay)
    }

    /// Starts the next focus with its end date pushed out by `delay`, used to
    /// hold the countdown while the break chime finishes.
    @discardableResult
    public mutating func startAnother(after delay: TimeInterval = 0) -> Date? {
        guard state.runState == .completed else { return nil }
        return startFocus(after: delay)
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

    /// Ends the running interval and advances to the next interval in the
    /// Pomodoro cycle. An early-ended focus advances the cycle without counting
    /// as a natural completion. Auto-start controls whether the next interval
    /// begins running or waits in its Ready state.
    @discardableResult
    public mutating func endInterval(
        autoStart: Bool,
        handoffDelay: TimeInterval = TimerEngine.endControlHandoffDelay
    ) -> TimerEndTransition? {
        guard state.runState == .running else { return nil }

        let endedPhase = state.phase
        let nextPhase: Phase
        switch endedPhase {
        case .focus:
            state.focusCyclePosition += 1
            nextPhase = recommendedBreak.phase
        case .shortBreak, .longBreak:
            resetFocusCycleIfComplete()
            nextPhase = .focus
        }

        let endDate: Date?
        if autoStart {
            endDate = begin(nextPhase, after: handoffDelay)
        } else {
            makeReady(nextPhase)
            endDate = nil
        }

        return TimerEndTransition(
            endedPhase: endedPhase,
            nextPhase: nextPhase,
            runState: state.runState,
            endDate: endDate
        )
    }

    /// Ends the running interval into the next interval's Ready state.
    @discardableResult
    public mutating func endEarly() -> TimerEndTransition? {
        endInterval(autoStart: false)
    }

    /// Declines the offered break from the focus-complete state.
    public mutating func skipBreak() {
        guard state.runState == .completed, state.phase == .focus else {
            endEarly()
            return
        }
        resetFocusCycleIfComplete()
        toIdle()
    }

    public mutating func doneForNow() {
        resetFocusCycleIfComplete()
        toIdle()
    }

    private mutating func begin(_ phase: Phase, after delay: TimeInterval = 0) -> Date {
        let minutes = durations.minutes(for: phase)
        state.selectedFocusMinutes = durations.focusMinutes
        state.phase = phase
        state.totalSeconds = TimeInterval(minutes * 60)
        state.remainingSeconds = state.totalSeconds
        let endDate = now().addingTimeInterval(max(0, delay) + state.totalSeconds)
        state.endDate = endDate
        state.runState = .running
        return endDate
    }

    private mutating func makeReady(_ phase: Phase) {
        state.selectedFocusMinutes = durations.focusMinutes
        state.phase = phase
        state.totalSeconds = TimeInterval(durations.minutes(for: phase) * 60)
        state.remainingSeconds = state.totalSeconds
        state.endDate = nil
        state.runState = .idle
    }

    private mutating func resetFocusCycleIfComplete() {
        guard state.focusCyclePosition > 0, state.focusCyclePosition % 4 == 0 else {
            return
        }
        state.completedFocusCount = 0
        state.focusCyclePosition = 0
    }

    private mutating func toIdle() {
        state.phase = .focus
        state.runState = .idle
        state.selectedFocusMinutes = durations.focusMinutes
        state.totalSeconds = TimeInterval(durations.focusMinutes * 60)
        state.remainingSeconds = state.totalSeconds
        state.endDate = nil
    }

    private mutating func finish() -> TimerEvent {
        let finishedPhase = state.phase
        state.runState = .completed
        state.endDate = nil
        state.remainingSeconds = 0
        if finishedPhase == .focus {
            state.completedFocusCount += 1
            state.focusCyclePosition += 1
        }
        return .completed(finishedPhase)
    }
}
