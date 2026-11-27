import Foundation
import PomodoroCore
import UserNotifications
import XCTest
@testable import Pomodoro

private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

private struct ScheduledNotification: Equatable {
    var endDate: Date
    var phase: Phase
}

private enum SchedulerCall: Equatable {
    case authorizationStatusRead
    case authorizationRequested
    case scheduleAttempted(ScheduledNotification)
    case installed(ScheduledNotification)
    case suppressed(ScheduledNotification)
    case cancelled
}

/// A deterministic stand-in for `NotificationService` that can hold either
/// suspension point open so a test can issue a newer request at the exact
/// moment a stale request is in flight.
@MainActor
private final class FakeNotificationScheduler: NotificationScheduling {
    private(set) var calls: [SchedulerCall] = []
    private(set) var pending: ScheduledNotification?

    var authorizationResult = true
    var currentAuthorizationStatus: UNAuthorizationStatus = .authorized
    var authorizationGate: Suspension?
    var scheduleGate: Suspension?

    var authorizationRequestCount: Int {
        calls.filter { $0 == .authorizationRequested }.count
    }

    var scheduleAttempts: [ScheduledNotification] {
        calls.compactMap { call in
            guard case .scheduleAttempted(let notification) = call else { return nil }
            return notification
        }
    }

    var installed: [ScheduledNotification] {
        calls.compactMap { call in
            guard case .installed(let notification) = call else { return nil }
            return notification
        }
    }

    var suppressed: [ScheduledNotification] {
        calls.compactMap { call in
            guard case .suppressed(let notification) = call else { return nil }
            return notification
        }
    }

    var cancelCount: Int {
        calls.filter { $0 == .cancelled }.count
    }

    func requestAuthorization() async -> Bool {
        calls.append(.authorizationRequested)
        if let authorizationGate {
            await authorizationGate.suspend()
        }
        return authorizationResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        calls.append(.authorizationStatusRead)
        return currentAuthorizationStatus
    }

    @discardableResult
    func schedule(
        at date: Date,
        phase: Phase,
        ifCurrent shouldInstall: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let notification = ScheduledNotification(endDate: date, phase: phase)
        calls.append(.scheduleAttempted(notification))
        if let scheduleGate {
            await scheduleGate.suspend()
        }
        guard shouldInstall() else {
            calls.append(.suppressed(notification))
            return false
        }
        pending = notification
        calls.append(.installed(notification))
        return true
    }

    func cancel() {
        calls.append(.cancelled)
        pending = nil
    }
}

/// One controllable suspension point. `suspend()` reports entry and then waits
/// for `release()`, so tests never need a wall-clock sleep.
@MainActor
private final class Suspension {
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasEntered = false
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func waitUntilEntered() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { continuation in
            enteredWaiters.append(continuation)
        }
    }

    func suspend() async {
        hasEntered = true
        let waiters = enteredWaiters
        enteredWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            releaseWaiter = continuation
        }
    }

    func release() {
        isReleased = true
        if let releaseWaiter {
            self.releaseWaiter = nil
            releaseWaiter.resume()
        }
    }
}

@MainActor
final class NotificationReconcilerTests: XCTestCase {
    func testScheduleAdvancesGenerationAndInstallsLatestIntent() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let endDate = referenceDate.addingTimeInterval(25 * 60)

        XCTAssertTrue(reconciler.isSettled)
        let generation = reconciler.schedule(at: endDate, phase: .focus)

        XCTAssertEqual(generation.rawValue, 1)
        XCTAssertTrue(reconciler.isCurrent(generation))
        XCTAssertFalse(reconciler.isSettled)

        await reconciler.settle()

        XCTAssertTrue(reconciler.isSettled)
        XCTAssertEqual(
            scheduler.pending,
            ScheduledNotification(endDate: endDate, phase: .focus)
        )
        XCTAssertEqual(
            scheduler.installed,
            [ScheduledNotification(endDate: endDate, phase: .focus)]
        )
    }

    func testEveryScheduleAndCancelAdvancesGeneration() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let focusEnd = referenceDate.addingTimeInterval(25 * 60)
        let breakEnd = focusEnd.addingTimeInterval(5 * 60)

        let first = reconciler.schedule(at: focusEnd, phase: .focus)
        await reconciler.settle()

        let second = reconciler.schedule(at: breakEnd, phase: .longBreak)
        await reconciler.settle()
        XCTAssertEqual(
            scheduler.pending,
            ScheduledNotification(endDate: breakEnd, phase: .longBreak)
        )

        let cancelled = reconciler.cancel()
        await reconciler.settle()

        XCTAssertEqual(
            [first.rawValue, second.rawValue, cancelled.rawValue],
            [1, 2, 3]
        )
        XCTAssertFalse(reconciler.isCurrent(first))
        XCTAssertFalse(reconciler.isCurrent(second))
        XCTAssertTrue(reconciler.isCurrent(cancelled))
        XCTAssertNil(scheduler.pending)
    }

    func testPauseDuringInFlightScheduleLeavesNoPendingNotification() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let endDate = referenceDate.addingTimeInterval(25 * 60)
        let gate = Suspension()
        scheduler.scheduleGate = gate

        let start = reconciler.schedule(at: endDate, phase: .focus)
        await gate.waitUntilEntered()
        let pause = reconciler.cancel()

        gate.release()
        await reconciler.settle()

        let staleSchedule = ScheduledNotification(endDate: endDate, phase: .focus)
        XCTAssertGreaterThan(pause, start)
        XCTAssertFalse(reconciler.isCurrent(start))
        XCTAssertTrue(reconciler.isCurrent(pause))
        XCTAssertEqual(scheduler.scheduleAttempts, [staleSchedule])
        XCTAssertEqual(scheduler.installed, [])
        XCTAssertEqual(scheduler.suppressed, [staleSchedule])
        XCTAssertEqual(scheduler.cancelCount, 1)
        XCTAssertNil(scheduler.pending)
    }

    func testResumeDuringInFlightScheduleInstallsOnlyLatestInterval() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let startEnd = referenceDate.addingTimeInterval(25 * 60)
        let resumeEnd = startEnd.addingTimeInterval(3 * 60)
        let gate = Suspension()
        scheduler.scheduleGate = gate

        let start = reconciler.schedule(at: startEnd, phase: .focus)
        await gate.waitUntilEntered()
        let pause = reconciler.cancel()
        let resume = reconciler.schedule(at: resumeEnd, phase: .focus)

        gate.release()
        await reconciler.settle()

        let staleSchedule = ScheduledNotification(endDate: startEnd, phase: .focus)
        let currentSchedule = ScheduledNotification(endDate: resumeEnd, phase: .focus)
        XCTAssertGreaterThan(pause, start)
        XCTAssertGreaterThan(resume, pause)
        XCTAssertEqual(scheduler.suppressed, [staleSchedule])
        XCTAssertEqual(scheduler.installed, [currentSchedule])
        XCTAssertEqual(scheduler.pending, currentSchedule)
        XCTAssertFalse(reconciler.isCurrent(start))
        XCTAssertFalse(reconciler.isCurrent(pause))
        XCTAssertTrue(reconciler.isCurrent(resume))
    }

    func testNewerScheduleSupersedesInFlightSchedule() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let firstEnd = referenceDate.addingTimeInterval(25 * 60)
        let secondEnd = firstEnd.addingTimeInterval(10 * 60)
        let gate = Suspension()
        scheduler.scheduleGate = gate

        let first = reconciler.schedule(at: firstEnd, phase: .focus)
        await gate.waitUntilEntered()
        let second = reconciler.schedule(at: secondEnd, phase: .shortBreak)

        gate.release()
        await reconciler.settle()

        let staleSchedule = ScheduledNotification(endDate: firstEnd, phase: .focus)
        let currentSchedule = ScheduledNotification(endDate: secondEnd, phase: .shortBreak)
        XCTAssertGreaterThan(second, first)
        XCTAssertEqual(scheduler.suppressed, [staleSchedule])
        XCTAssertEqual(scheduler.installed, [currentSchedule])
        XCTAssertEqual(scheduler.pending, currentSchedule)
        XCTAssertFalse(reconciler.isCurrent(first))
        XCTAssertTrue(reconciler.isCurrent(second))
    }

    func testMultipleRequestsBeforeDrainStartsApplyOnlyLatestIntent() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let firstEnd = referenceDate.addingTimeInterval(25 * 60)
        let secondEnd = firstEnd.addingTimeInterval(60)

        let first = reconciler.schedule(at: firstEnd, phase: .focus)
        let second = reconciler.schedule(at: secondEnd, phase: .focus)

        await reconciler.settle()

        let currentSchedule = ScheduledNotification(endDate: secondEnd, phase: .focus)
        XCTAssertGreaterThan(second, first)
        XCTAssertEqual(scheduler.scheduleAttempts, [currentSchedule])
        XCTAssertEqual(scheduler.installed, [currentSchedule])
        XCTAssertEqual(scheduler.pending, currentSchedule)
    }

    func testDelayedAuthorizationDropsSupersededSchedule() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let endDate = referenceDate.addingTimeInterval(25 * 60)
        let gate = Suspension()
        scheduler.authorizationGate = gate
        var results: [Bool] = []
        reconciler.onAuthorizationResolved = { results.append($0) }

        let start = reconciler.schedule(
            at: endDate,
            phase: .focus,
            requestingAuthorization: true
        )
        await gate.waitUntilEntered()
        let pause = reconciler.cancel()

        gate.release()
        await reconciler.settle()

        XCTAssertGreaterThan(pause, start)
        XCTAssertEqual(scheduler.authorizationRequestCount, 1)
        XCTAssertEqual(results, [true])
        XCTAssertEqual(scheduler.scheduleAttempts, [])
        XCTAssertEqual(scheduler.installed, [])
        XCTAssertEqual(scheduler.cancelCount, 1)
        XCTAssertNil(scheduler.pending)
        XCTAssertFalse(reconciler.isCurrent(start))
        XCTAssertTrue(reconciler.isCurrent(pause))
    }

    func testDelayedAuthorizationAppliesNewestResumeIntent() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let startEnd = referenceDate.addingTimeInterval(25 * 60)
        let resumeEnd = startEnd.addingTimeInterval(4 * 60)
        let gate = Suspension()
        scheduler.authorizationGate = gate

        let start = reconciler.schedule(
            at: startEnd,
            phase: .focus,
            requestingAuthorization: true
        )
        await gate.waitUntilEntered()
        let pause = reconciler.cancel()
        let resume = reconciler.schedule(at: resumeEnd, phase: .focus)

        gate.release()
        await reconciler.settle()

        let currentSchedule = ScheduledNotification(endDate: resumeEnd, phase: .focus)
        XCTAssertGreaterThan(pause, start)
        XCTAssertGreaterThan(resume, pause)
        XCTAssertEqual(scheduler.authorizationRequestCount, 1)
        XCTAssertEqual(scheduler.installed, [currentSchedule])
        XCTAssertEqual(scheduler.pending, currentSchedule)
        XCTAssertFalse(reconciler.isCurrent(start))
        XCTAssertFalse(reconciler.isCurrent(pause))
        XCTAssertTrue(reconciler.isCurrent(resume))
    }

    func testAuthorizationIsRequestedAtMostOnceAndReported() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let firstEnd = referenceDate.addingTimeInterval(25 * 60)
        let secondEnd = firstEnd.addingTimeInterval(5 * 60)
        var results: [Bool] = []
        reconciler.onAuthorizationResolved = { results.append($0) }

        reconciler.schedule(at: firstEnd, phase: .focus, requestingAuthorization: true)
        await reconciler.settle()
        reconciler.schedule(at: secondEnd, phase: .focus, requestingAuthorization: true)
        await reconciler.settle()

        XCTAssertEqual(scheduler.authorizationRequestCount, 1)
        XCTAssertEqual(results, [true])
        XCTAssertEqual(
            scheduler.installed,
            [
                ScheduledNotification(endDate: firstEnd, phase: .focus),
                ScheduledNotification(endDate: secondEnd, phase: .focus)
            ]
        )
        XCTAssertEqual(
            scheduler.pending,
            ScheduledNotification(endDate: secondEnd, phase: .focus)
        )
    }

    func testBreakPhaseIsCarriedToTheScheduler() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)
        let endDate = referenceDate.addingTimeInterval(5 * 60)

        reconciler.schedule(at: endDate, phase: .shortBreak)
        await reconciler.settle()

        XCTAssertEqual(
            scheduler.pending,
            ScheduledNotification(endDate: endDate, phase: .shortBreak)
        )
    }

    func testCancelWithoutScheduleOnlyCancels() async {
        let scheduler = FakeNotificationScheduler()
        let reconciler = NotificationReconciler(scheduler: scheduler)

        let generation = reconciler.cancel()
        await reconciler.settle()

        XCTAssertEqual(generation.rawValue, 1)
        XCTAssertTrue(reconciler.isCurrent(generation))
        XCTAssertEqual(scheduler.scheduleAttempts, [])
        XCTAssertEqual(scheduler.installed, [])
        XCTAssertEqual(scheduler.cancelCount, 1)
        XCTAssertNil(scheduler.pending)
    }
}
