import Foundation

public struct TimerEndTransition: Equatable, Sendable {
    public let endedPhase: Phase
    public let nextPhase: Phase
    public let runState: RunState
    public let endDate: Date?

    public init(
        endedPhase: Phase,
        nextPhase: Phase,
        runState: RunState,
        endDate: Date?
    ) {
        self.endedPhase = endedPhase
        self.nextPhase = nextPhase
        self.runState = runState
        self.endDate = endDate
    }
}
