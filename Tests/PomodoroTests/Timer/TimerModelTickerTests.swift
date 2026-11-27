import Foundation
import PomodoroCore
import UserNotifications
import XCTest
@testable import Pomodoro

private let tickerReferenceDate = Date(timeIntervalSince1970: 1_800_000_000)

private final class ManualClock: @unchecked Sendable {
    var date: Date

    init(_ date: Date = tickerReferenceDate) {
        self.date = date
    }

    func advance(_ seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}

@MainActor
private final class FakeTicker: TickerScheduling {
    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    private(set) var timersCreated = 0
    private(set) var activeTimers = 0
    private var handler: (@MainActor () -> Void)?

    var isRunning: Bool {
        activeTimers > 0
    }

    func start(handler: @escaping @MainActor () -> Void) {
        startCalls += 1
        guard activeTimers == 0 else { return }
        activeTimers = 1
        timersCreated += 1
        self.handler = handler
    }

    func stop() {
        stopCalls += 1
        activeTimers = 0
        handler = nil
    }

    func fire() {
        handler?()
    }
}

@MainActor
private final class FakeNotificationScheduler: NotificationScheduling {
    private(set) var scheduled: [(endDate: Date, phase: Phase)] = []
    private(set) var cancelCount = 0

    func requestAuthorization() async -> Bool {
        true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        .authorized
    }

    @discardableResult
    func schedule(
        at date: Date,
        phase: Phase,
        ifCurrent shouldInstall: @escaping @MainActor () -> Bool
    ) async -> Bool {
        guard shouldInstall() else { return false }
        scheduled.append((date, phase))
        return true
    }

    func cancel() {
        cancelCount += 1
    }
}

final class TimerModelTickerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PomodoroTickerTests-\(UUID().uuidString)", isDirectory: true)
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
    func testIdleActivationDoesNotStartTicker() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(clock: clock)

        model.activate()

        XCTAssertEqual(model.runState, .idle)
        XCTAssertFalse(ticker.isRunning)
        XCTAssertEqual(ticker.startCalls, 0)
    }

    @MainActor
    func testActivationWithRestoredRunningIntervalStartsOneTicker() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(
            timer: runningState(at: clock.date),
            clock: clock
        )

        model.activate()

        XCTAssertEqual(model.runState, .running)
        XCTAssertTrue(ticker.isRunning)
        XCTAssertEqual(ticker.activeTimers, 1)
        XCTAssertEqual(ticker.timersCreated, 1)
    }

    @MainActor
    func testActivationWithRestoredPausedIntervalDoesNotStartTicker() throws {
        let clock = ManualClock()
        let timer = TimerState(
            phase: .focus,
            runState: .paused,
            totalSeconds: 25 * 60,
            remainingSeconds: 10 * 60
        )
        let (model, ticker, _) = try makeModel(timer: timer, clock: clock)

        model.activate()

        XCTAssertEqual(model.runState, .paused)
        XCTAssertFalse(ticker.isRunning)
        XCTAssertEqual(ticker.startCalls, 0)
    }

    @MainActor
    func testStartPauseAndResumeMoveTickerWithRunState() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(clock: clock)

        model.startFocus()
        XCTAssertEqual(model.runState, .running)
        XCTAssertTrue(ticker.isRunning)

        clock.advance(60)
        model.togglePause()
        XCTAssertEqual(model.runState, .paused)
        XCTAssertFalse(ticker.isRunning)

        clock.advance(30)
        model.togglePause()
        XCTAssertEqual(model.runState, .running)
        XCTAssertTrue(ticker.isRunning)
        XCTAssertEqual(ticker.activeTimers, 1)
    }

    @MainActor
    func testCompletionStopsTickerWithoutAutoStart() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(clock: clock)

        model.startFocus()
        XCTAssertTrue(ticker.isRunning)

        clock.advance(25 * 60 + 1)
        ticker.fire()

        XCTAssertEqual(model.runState, .completed)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testCompletionWithAutoStartKeepsOneTickerRunning() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(
            autoStartBreak: true,
            clock: clock
        )

        model.startFocus()
        clock.advance(25 * 60 + 1)
        ticker.fire()

        XCTAssertEqual(model.runState, .running)
        XCTAssertEqual(model.phase, .shortBreak)
        XCTAssertEqual(ticker.activeTimers, 1)
    }

    @MainActor
    func testEndIntervalStopsTickerWhenItFinishesToReady() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(clock: clock)

        model.startFocus()
        XCTAssertTrue(ticker.isRunning)

        model.endInterval()

        XCTAssertEqual(model.runState, .idle)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testEndIntervalWithAutoStartKeepsOneTickerRunning() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(
            autoStartBreak: true,
            clock: clock
        )

        model.startFocus()
        model.endInterval()

        XCTAssertEqual(model.runState, .running)
        XCTAssertEqual(model.phase, .shortBreak)
        XCTAssertEqual(ticker.activeTimers, 1)
        XCTAssertEqual(ticker.timersCreated, 1)
    }

    @MainActor
    func testDoneForNowStopsTicker() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(clock: clock)

        model.startFocus()
        XCTAssertTrue(ticker.isRunning)

        model.doneForNow()

        XCTAssertEqual(model.runState, .idle)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testSkipBreakStopsTicker() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(clock: clock)

        model.startFocus()
        XCTAssertTrue(ticker.isRunning)

        model.skipBreak()

        XCTAssertEqual(model.runState, .idle)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testWakeRecoveryStartsOnlyWhileRunningWithoutDuplicateTicker() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(
            timer: runningState(at: clock.date),
            clock: clock
        )
        model.activate()
        XCTAssertEqual(ticker.timersCreated, 1)

        clock.advance(10)
        model.recoverAfterWake()
        XCTAssertTrue(ticker.isRunning)
        XCTAssertEqual(ticker.activeTimers, 1)
        XCTAssertEqual(ticker.timersCreated, 1)

        model.togglePause()
        XCTAssertFalse(ticker.isRunning)

        clock.advance(3)
        model.recoverAfterWake()
        XCTAssertEqual(model.runState, .paused)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testWakeRecoveryCompletesExpiredIntervalAndStopsTicker() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(
            timer: runningState(at: clock.date),
            clock: clock
        )
        model.activate()
        XCTAssertTrue(ticker.isRunning)

        clock.advance(10 * 60 + 1)
        model.recoverAfterWake()

        XCTAssertEqual(model.runState, .completed)
        XCTAssertFalse(ticker.isRunning)
    }

    @MainActor
    func testRepeatedActivationAndWakeDoNotCreateDuplicateTickers() throws {
        let clock = ManualClock()
        let (model, ticker, _) = try makeModel(
            timer: runningState(at: clock.date),
            clock: clock
        )

        model.activate()
        model.activate()
        model.recoverAfterWake()

        XCTAssertEqual(model.runState, .running)
        XCTAssertEqual(ticker.activeTimers, 1)
        XCTAssertEqual(ticker.timersCreated, 1)
    }

    @MainActor
    func testExpiredRestoredRunningStateCompletesOnActivationWithoutStartingTicker() throws {
        let clock = ManualClock()
        var timer = runningState(at: clock.date)
        timer.endDate = clock.date.addingTimeInterval(-60)
        let (model, ticker, _) = try makeModel(timer: timer, clock: clock)

        XCTAssertEqual(model.runState, .completed)
        model.activate()

        XCTAssertEqual(model.runState, .completed)
        XCTAssertFalse(ticker.isRunning)
        XCTAssertEqual(ticker.startCalls, 0)
        XCTAssertEqual(ticker.timersCreated, 0)
    }

    @MainActor
    func testActivationReconcilesIntervalThatExpiresBeforeActivation() throws {
        let clock = ManualClock()
        let timer = TimerState(
            phase: .focus,
            runState: .running,
            totalSeconds: 60,
            remainingSeconds: 60,
            endDate: clock.date.addingTimeInterval(60)
        )
        let (model, ticker, _) = try makeModel(timer: timer, clock: clock)
        XCTAssertEqual(model.runState, .running)
        XCTAssertFalse(ticker.isRunning)

        clock.advance(61)
        model.activate()

        XCTAssertEqual(model.runState, .completed)
        XCTAssertFalse(ticker.isRunning)
        XCTAssertEqual(ticker.startCalls, 0)
    }

    @MainActor
    private func makeModel(
        timer: TimerState = .initial,
        autoStartBreak: Bool = false,
        autoStartFocus: Bool = false,
        clock: ManualClock
    ) throws -> (TimerModel, FakeTicker, FakeNotificationScheduler) {
        let store = StateStore(directory: directory)
        let persisted = PersistedState(
            timer: timer,
            chimeEnabled: false,
            autoStartBreak: autoStartBreak,
            autoStartFocus: autoStartFocus
        )
        try store.save(persisted)

        let ticker = FakeTicker()
        let notifications = FakeNotificationScheduler()
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
