import Foundation
import PomodoroCore

/// Identifies one notification reconciliation request.
///
/// Generation `0` is the initial no-request state. Every `schedule` or `cancel`
/// call advances the generation by exactly one and returns the new value.
/// Generations are never reused, so exactly one generation is current at a
/// time: the one returned by the latest call. Any earlier generation is stale
/// as soon as a newer request is made, even if that request has not been
/// applied yet.
struct NotificationGeneration: Equatable, Comparable, Sendable, CustomStringConvertible {
    let rawValue: UInt64

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    static func < (lhs: NotificationGeneration, rhs: NotificationGeneration) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        "notification-generation-\(rawValue)"
    }
}

/// Serializes notification scheduling against the latest desired intent.
///
/// The reconciler owns the only path from the timer to
/// `NotificationScheduling`. `schedule` and `cancel` are synchronous entry
/// points: they record the latest intent and advance the generation, then a
/// single drain task applies that intent. Because there is never more than one
/// drain task, an older request cannot overtake a newer one.
///
/// After every suspension point the drain re-checks its generation. If a newer
/// request arrived, the partial attempt is abandoned and the drain reconciles
/// the latest intent instead. The seam's `ifCurrent` check adds the same guard
/// immediately before a notification request is installed, closing the window
/// between the last settings read and `add`.
///
/// The reconciler performs no UserNotifications work itself; all effects go
/// through the injected seam, which keeps it deterministic and testable.
@MainActor
final class NotificationReconciler {
    private enum Intent {
        case none
        case scheduled(endDate: Date, phase: Phase)
    }

    private let scheduler: any NotificationScheduling

    private var desiredIntent: Intent = .none
    private var appliedGeneration = NotificationGeneration(rawValue: 0)
    private var drainTask: Task<Void, Never>?
    private var needsAuthorizationRequest = false
    private var hasRequestedAuthorization = false

    /// The latest generation issued by this reconciler.
    private(set) var generation = NotificationGeneration(rawValue: 0)

    /// Called once, after the reconciler's at-most-once authorization request
    /// resolves. The result reports the system response, not whether the
    /// request that prompted it is still current; callers can use it to refresh
    /// the displayed permission status.
    var onAuthorizationResolved: (@MainActor (Bool) -> Void)?

    init(scheduler: any NotificationScheduling) {
        self.scheduler = scheduler
    }

    /// True when the latest intent has been applied and no drain is running.
    var isSettled: Bool {
        appliedGeneration == generation && drainTask == nil
    }

    /// Whether `generation` is still the latest request.
    func isCurrent(_ generation: NotificationGeneration) -> Bool {
        generation == self.generation
    }

    /// Requests that the interval-end notification reflect `endDate` and `phase`.
    ///
    /// - Parameter requestingAuthorization: ask the system for permission as
    ///   part of this reconciliation, at most once per reconciler lifetime. A
    ///   caller that restores a running interval without prompting passes
    ///   `false`; the first explicit Start, Resume, or auto-start passes `true`.
    /// - Returns: the generation assigned to this request.
    @discardableResult
    func schedule(
        at endDate: Date,
        phase: Phase,
        requestingAuthorization: Bool = false
    ) -> NotificationGeneration {
        desiredIntent = .scheduled(endDate: endDate, phase: phase)
        if requestingAuthorization {
            needsAuthorizationRequest = true
        }
        advanceGeneration()
        startDrainIfNeeded()
        return generation
    }

    /// Requests that no interval-end notification remains.
    ///
    /// Every call advances the generation, including repeated cancels, so it
    /// always invalidates an in-flight schedule request.
    /// - Returns: the generation assigned to this request.
    @discardableResult
    func cancel() -> NotificationGeneration {
        desiredIntent = .none
        advanceGeneration()
        startDrainIfNeeded()
        return generation
    }

    /// Waits until the latest generation has been applied.
    ///
    /// Intended for tests and explicit shutdown. Production call sites enqueue
    /// and let the drain run on the main actor.
    func settle() async {
        while true {
            if let drainTask {
                await drainTask.value
                continue
            }
            guard appliedGeneration != generation else { return }
            startDrainIfNeeded()
        }
    }

    private func advanceGeneration() {
        generation = NotificationGeneration(rawValue: generation.rawValue + 1)
    }

    private func startDrainIfNeeded() {
        guard drainTask == nil else { return }

        drainTask = Task { [weak self] in
            guard let self else { return }
            await self.drain()
            self.finishDrain()
        }
    }

    private func finishDrain() {
        drainTask = nil
        if appliedGeneration != generation {
            startDrainIfNeeded()
        }
    }

    private func drain() async {
        while appliedGeneration != generation {
            let requestedGeneration = generation
            let intent = desiredIntent

            if needsAuthorizationRequest {
                needsAuthorizationRequest = false
                if !hasRequestedAuthorization {
                    hasRequestedAuthorization = true
                    let granted = await scheduler.requestAuthorization()
                    onAuthorizationResolved?(granted)
                    if requestedGeneration != generation {
                        continue
                    }
                }
            }

            switch intent {
            case .none:
                scheduler.cancel()
            case .scheduled(let endDate, let phase):
                let currentGeneration = requestedGeneration
                await scheduler.schedule(at: endDate, phase: phase) { [weak self] in
                    guard let self else { return false }
                    return self.isCurrent(currentGeneration)
                }
            }

            if requestedGeneration != generation {
                continue
            }
            appliedGeneration = requestedGeneration
        }
    }
}
