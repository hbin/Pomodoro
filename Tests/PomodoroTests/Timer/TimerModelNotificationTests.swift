import Foundation
import PomodoroCore
import UserNotifications
import XCTest
@testable import Pomodoro

private let notificationReferenceDate = Date(timeIntervalSince1970: 1_800_000_000)

private struct PlannedNotification: Equatable {
    var endDate: Date
    var phase: Phase
}

private final class NotificationClock: @unchecked Sendable {
    var date: Date

    init(_ date: Date = notificationReferenceDate) {
        self.date = date
    }

    func advance(_ seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}

@MainActor
private final class NotificationSuspension {
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
private final class NotificationTicker: TickerScheduling {
    private(set) var timersCreated = 0
    private(set) var activeTimers = 0
    private var handler: (@MainActor () -> Void)?

    var isRunning: Bool {
        activeTimers > 0
    }

    func start(handler: @escaping @MainActor () -> Void) {
        guard activeTimers == 0 else { return }
        activeTimers = 1
        timersCreated += 1
        self.handler = handler
    }

    func stop() {
        activeTimers = 0
        handler = nil
    }

    func fire() {
        handler?()
    }
}

@MainActor
private final class RecordingNotificationScheduler: NotificationScheduling {
    private(set) var scheduleAttempts: [PlannedNotification] = []
    private(set) var installed: [PlannedNotification] = []
    private(set) var suppressed: [PlannedNotification] = []
    private(set) var pending: PlannedNotification?
    private(set) var authorizationRequests = 0
    private(set) var cancelCount = 0

    var authorizationResult = true
    var authorizationStatusResult: UNAuthorizationStatus = .authorized
    var authorizationGate: NotificationSuspension?
    var scheduleGate: NotificationSuspension?

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        if let authorizationGate {
            await authorizationGate.suspend()
        }
        return authorizationResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusResult
    }

    @discardableResult
    func schedule(
        at date: Date,
        phase: Phase,
        ifCurrent shouldInstall: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let notification = PlannedNotification(endDate: date, phase: phase)
        scheduleAttempts.append(notification)
        if let scheduleGate {
            await scheduleGate.suspend()
        }
        guard shouldInstall() else {
            suppressed.append(notification)
            return false
        }
        pending = notification
        installed.append(notification)
        return true
    }

    func cancel() {
        cancelCount += 1
        pending = nil
    }
}

final class TimerModelNotificationTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PomodoroNotificationTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testStartThenPauseLeavesNoPendingNotification() async throws {
        let clock = NotificationClock()
        let (model, ticker, notifications) = try makeModel(clock: clock)
        let gate = NotificationSuspension()
        notifications.scheduleGate = gate

        model.startFocus()
        let startNotification = try XCTUnwrap(model.snapshot.endDate).map(phase: .focus)
        await gate.waitUntilEntered()

        model.togglePause()
        gate.release()
        await model.settleNotifications()

        XCTAssertEqual(model.runState, .paused)
        XCTAssertEqual(notifications.scheduleAttempts, [startNotification])
        XCTAssertEqual(notifications.suppressed, [startNotification])
        XCTAssertEqual(notifications.installed, [])
        XCTAssertNil(notifications.pending)
        XCTAssertEqual(notifications.authorizationRequests, 1)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testStartThenEndLeavesNoPendingNotification() async throws {
        let clock = NotificationClock()
        let (model, ticker, notifications) = try makeModel(clock: clock)
        let gate = NotificationSuspension()
        notifications.scheduleGate = gate

        model.startFocus()
        let startNotification = try XCTUnwrap(model.snapshot.endDate).map(phase: .focus)
        await gate.waitUntilEntered()

        model.endInterval()
        gate.release()
        await model.settleNotifications()

        XCTAssertEqual(model.runState, .idle)
        XCTAssertEqual(notifications.scheduleAttempts, [startNotification])
        XCTAssertEqual(notifications.suppressed, [startNotification])
        XCTAssertEqual(notifications.installed, [])
        XCTAssertNil(notifications.pending)
        XCTAssertEqual(notifications.authorizationRequests, 1)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testStartPauseResumeInstallsOnlyTheResumedNotification() async throws {
        let clock = NotificationClock()
        let (model, ticker, notifications) = try makeModel(clock: clock)
        let gate = NotificationSuspension()
        notifications.scheduleGate = gate

        model.startFocus()
        let startNotification = try XCTUnwrap(model.snapshot.endDate).map(phase: .focus)
        await gate.waitUntilEntered()

        clock.advance(60)
        model.togglePause()
        clock.advance(30)
        model.togglePause()
        let resumedNotification = try XCTUnwrap(model.snapshot.endDate).map(phase: .focus)

        gate.release()
        await model.settleNotifications()

        XCTAssertNotEqual(startNotification, resumedNotification)
        XCTAssertEqual(notifications.scheduleAttempts, [startNotification, resumedNotification])
        XCTAssertEqual(notifications.suppressed, [startNotification])
        XCTAssertEqual(notifications.installed, [resumedNotification])
        XCTAssertEqual(notifications.pending, resumedNotification)
        XCTAssertEqual(notifications.authorizationRequests, 1)
        XCTAssertEqual(ticker.activeTimers, 1)
    }

    @MainActor
    func testDelayedAuthorizationThenPauseAppliesOnlyThePause() async throws {
        let clock = NotificationClock()
        let (model, ticker, notifications) = try makeModel(clock: clock)
        let gate = NotificationSuspension()
        notifications.authorizationGate = gate

        model.startFocus()
        await gate.waitUntilEntered()

        model.togglePause()
        gate.release()
        await model.settleNotifications()

        XCTAssertEqual(model.runState, .paused)
        XCTAssertEqual(notifications.authorizationRequests, 1)
        XCTAssertEqual(notifications.scheduleAttempts, [])
        XCTAssertEqual(notifications.installed, [])
        XCTAssertNil(notifications.pending)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testWakeRecoveryCompletionSuppressesInFlightStartNotification() async throws {
        let clock = NotificationClock()
        let (model, ticker, notifications) = try makeModel(clock: clock)
        let gate = NotificationSuspension()
        notifications.scheduleGate = gate

        model.startFocus()
        let startNotification = try XCTUnwrap(model.snapshot.endDate).map(phase: .focus)
        await gate.waitUntilEntered()

        clock.advance(25 * 60 + 1)
        model.recoverAfterWake()
        gate.release()
        await model.settleNotifications()

        XCTAssertEqual(model.runState, .completed)
        XCTAssertEqual(notifications.scheduleAttempts, [startNotification])
        XCTAssertEqual(notifications.suppressed, [startNotification])
        XCTAssertEqual(notifications.installed, [])
        XCTAssertNil(notifications.pending)
        XCTAssertEqual(notifications.authorizationRequests, 1)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testAutoStartInstallsOnlyTheBreakNotificationAndKeepsOneTicker() async throws {
        let clock = NotificationClock()
        let (model, ticker, notifications) = try makeModel(
            autoStartBreak: true,
            clock: clock
        )
        let gate = NotificationSuspension()
        notifications.scheduleGate = gate

        model.startFocus()
        let startNotification = try XCTUnwrap(model.snapshot.endDate).map(phase: .focus)
        await gate.waitUntilEntered()

        clock.advance(25 * 60 + 1)
        ticker.fire()
        let breakNotification = try XCTUnwrap(model.snapshot.endDate).map(phase: .shortBreak)

        gate.release()
        await model.settleNotifications()

        XCTAssertEqual(model.runState, .running)
        XCTAssertEqual(model.phase, .shortBreak)
        XCTAssertEqual(notifications.scheduleAttempts, [startNotification, breakNotification])
        XCTAssertEqual(notifications.suppressed, [startNotification])
        XCTAssertEqual(notifications.installed, [breakNotification])
        XCTAssertEqual(notifications.pending, breakNotification)
        XCTAssertEqual(notifications.authorizationRequests, 1)
        XCTAssertEqual(ticker.activeTimers, 1)
        XCTAssertEqual(ticker.timersCreated, 1)
    }

    @MainActor
    func testRestoredRunningIntervalSchedulesWithoutRequestingAuthorization() async throws {
        let clock = NotificationClock()
        let timer = runningState(at: clock.date)
        let (model, ticker, notifications) = try makeModel(timer: timer, clock: clock)

        model.activate()
        await model.settleNotifications()

        let notification = try XCTUnwrap(timer.endDate).map(phase: .focus)
        XCTAssertEqual(model.runState, .running)
        XCTAssertEqual(notifications.authorizationRequests, 0)
        XCTAssertEqual(notifications.scheduleAttempts, [notification])
        XCTAssertEqual(notifications.installed, [notification])
        XCTAssertEqual(notifications.pending, notification)
        XCTAssertEqual(ticker.activeTimers, 1)
        XCTAssertEqual(ticker.timersCreated, 1)
    }

    @MainActor
    private func makeModel(
        timer: TimerState = .initial,
        autoStartBreak: Bool = false,
        autoStartFocus: Bool = false,
        clock: NotificationClock
    ) throws -> (TimerModel, NotificationTicker, RecordingNotificationScheduler) {
        let store = StateStore(directory: directory)
        let persisted = PersistedState(
            timer: timer,
            chimeEnabled: false,
            autoStartBreak: autoStartBreak,
            autoStartFocus: autoStartFocus
        )
        try store.save(persisted)

        let ticker = NotificationTicker()
        let notifications = RecordingNotificationScheduler()
        let model = TimerModel(
            store: store,
            notifications: notifications,
            ticker: ticker,
            now: { clock.date }
        )
        return (model, ticker, notifications)
    }

    @MainActor
    private func runningState(at date: Date) -> TimerState {
        TimerState(
            phase: .focus,
            runState: .running,
            totalSeconds: 25 * 60,
            remainingSeconds: 10 * 60,
            endDate: date.addingTimeInterval(10 * 60)
        )
    }
}

private extension Date {
    func map(phase: Phase) -> PlannedNotification {
        PlannedNotification(endDate: self, phase: phase)
    }
}
