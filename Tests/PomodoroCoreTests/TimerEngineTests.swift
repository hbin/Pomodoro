import XCTest
@testable import PomodoroCore

final class TestClock: @unchecked Sendable {
    var date: Date

    init(_ date: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        self.date = date
    }

    func advance(_ seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}

final class TimerEngineTests: XCTestCase {
    private func makeEngine(_ clock: TestClock, state: TimerState = .initial) -> TimerEngine {
        TimerEngine(state: state, now: { clock.date })
    }

    func testStartFocusUsesAbsoluteEndDate() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        let end = engine.startFocus(minutes: 25)

        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.totalSeconds, 1500)
        XCTAssertEqual(end, clock.date.addingTimeInterval(1500))
        XCTAssertEqual(engine.displaySeconds(), 1500)
        XCTAssertEqual(engine.progress(), 0, accuracy: 0.0001)
    }

    func testMinuteDialTracksRemainingTime() {
        let clock = TestClock()
        var idleEngine = makeEngine(clock)
        idleEngine.selectFocusMinutes(15)
        XCTAssertEqual(idleEngine.minuteDialProgress(), 0.25, accuracy: 0.0001)

        var engine = makeEngine(clock)
        engine.startFocus(minutes: 45)
        XCTAssertEqual(engine.minuteDialProgress(), 0.75, accuracy: 0.0001)

        clock.advance(6)
        XCTAssertEqual(engine.minuteDialProgress(), 2694.0 / 3600.0, accuracy: 0.0001)

        engine.pause()
        clock.advance(60)
        XCTAssertEqual(engine.minuteDialProgress(), 2694.0 / 3600.0, accuracy: 0.0001)
    }

    func testNaturalCompletionAdvancesRhythm() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus(minutes: 25)

        clock.advance(1500)
        let event = engine.refresh()

        XCTAssertEqual(event, .completed(.focus))
        XCTAssertEqual(engine.state.runState, .completed)
        XCTAssertEqual(engine.state.completedFocusCount, 1)
        XCTAssertEqual(engine.recommendedBreak.minutes, 5)
        XCTAssertEqual(engine.recommendedBreak.phase, .shortBreak)
        XCTAssertEqual(engine.displaySeconds(), 0)
    }

    func testPauseFreezesRemainingTimeAndResumeReschedules() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus(minutes: 25)

        clock.advance(300)
        engine.pause()
        XCTAssertEqual(engine.state.runState, .paused)
        XCTAssertEqual(engine.remaining(), 1200, accuracy: 0.001)
        XCTAssertNil(engine.state.endDate)

        clock.advance(900)
        XCTAssertEqual(engine.remaining(), 1200, accuracy: 0.001)

        let resumedEnd = engine.resume()
        XCTAssertEqual(resumedEnd, clock.date.addingTimeInterval(1200))
        XCTAssertEqual(engine.state.runState, .running)
    }

    func testPauseAtZeroStillCompletesNaturally() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus(minutes: 25)
        clock.advance(1500)

        XCTAssertEqual(engine.pause(), .completed(.focus))
        XCTAssertEqual(engine.state.runState, .completed)
        XCTAssertEqual(engine.state.completedFocusCount, 1)
    }

    func testEarlyEndDoesNotAdvanceRhythm() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus(minutes: 45)

        clock.advance(120)
        engine.endEarly()

        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.state.selectedFocusMinutes, 25)
        XCTAssertEqual(engine.displaySeconds(), 1500)
    }

    func testFourthCompletionOffersLongBreak() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        for index in 1...4 {
            engine.startFocus(minutes: 25)
            clock.advance(1500)
            XCTAssertEqual(engine.refresh(), .completed(.focus))
            XCTAssertEqual(engine.state.completedFocusCount, index)
        }

        XCTAssertEqual(engine.recommendedBreak.minutes, 15)
        XCTAssertEqual(engine.recommendedBreak.phase, .longBreak)

        engine.startRecommendedBreak()
        XCTAssertEqual(engine.state.phase, .longBreak)
        XCTAssertEqual(engine.state.totalSeconds, 900)
        XCTAssertEqual(engine.state.runState, .running)
    }

    func testSkippingLongBreakResetsRhythm() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        for _ in 1...4 {
            engine.startFocus(minutes: 25)
            clock.advance(1500)
            _ = engine.refresh()
        }

        engine.skipBreak()

        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.recommendedBreak.minutes, 5)
    }

    func testStartingAnotherInsteadOfLongBreakResetsRhythm() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        for _ in 1...4 {
            engine.startFocus(minutes: 25)
            clock.advance(1500)
            _ = engine.refresh()
        }
        engine.startAnother()

        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.state.runState, .running)
    }

    func testBreakCompletionOffersAnotherFocus() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus(minutes: 25)
        clock.advance(1500)
        _ = engine.refresh()
        engine.startRecommendedBreak()

        clock.advance(300)
        XCTAssertEqual(engine.refresh(), .completed(.shortBreak))
        XCTAssertEqual(engine.state.runState, .completed)
        XCTAssertEqual(engine.state.phase, .shortBreak)

        engine.startAnother()
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.runState, .running)
    }

    func testRestoreExpiredIntervalCompletesOnce() {
        let clock = TestClock()
        let past = clock.date.addingTimeInterval(-60)
        let state = TimerState(
            selectedFocusMinutes: 25,
            phase: .focus,
            runState: .running,
            totalSeconds: 1500,
            remainingSeconds: 60,
            endDate: past,
            completedFocusCount: 0
        )
        var engine = makeEngine(clock, state: state)

        XCTAssertEqual(engine.restore(), .completed(.focus))
        XCTAssertEqual(engine.state.completedFocusCount, 1)
        XCTAssertNil(engine.restore())
        XCTAssertEqual(engine.state.completedFocusCount, 1)
    }

    func testRestorePausedPreservesRemainder() {
        let clock = TestClock()
        let state = TimerState(
            selectedFocusMinutes: 45,
            phase: .focus,
            runState: .paused,
            totalSeconds: 2700,
            remainingSeconds: 811,
            endDate: nil,
            completedFocusCount: 2
        )
        var engine = makeEngine(clock, state: state)

        XCTAssertNil(engine.restore())
        XCTAssertEqual(engine.state.runState, .paused)
        XCTAssertEqual(engine.displaySeconds(), 811)
        XCTAssertEqual(engine.state.completedFocusCount, 2)
    }

    func testClockMovedBackwardsDoesNotExtendPastTotal() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus(minutes: 25)

        clock.advance(-3600)
        XCTAssertEqual(engine.remaining(), 1500, accuracy: 0.001)
        XCTAssertLessThanOrEqual(engine.progress(), 1)

        // A backwards clock is reconciled conservatively: the interval keeps
        // its full remaining duration instead of extending past its total.
        XCTAssertNil(engine.refresh())
        XCTAssertEqual(engine.remaining(), 1500, accuracy: 0.001)

        clock.advance(1499)
        XCTAssertNil(engine.refresh())
        clock.advance(1)
        XCTAssertEqual(engine.refresh(), .completed(.focus))
    }
}

final class PersistenceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PomodoroTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTripPreservesStateAndPreferences() throws {
        let store = StateStore(directory: directory)
        var state = PersistedState()
        state.timer.selectedFocusMinutes = 45
        state.timer.runState = .paused
        state.timer.phase = .focus
        state.timer.totalSeconds = 2700
        state.timer.remainingSeconds = 412
        state.timer.completedFocusCount = 3
        state.tickEnabled = true
        state.chimeEnabled = false
        state.showMenuBarMinutes = false
        state.themePreference = .dark
        state.firstRunTipDismissed = true

        try store.save(state)
        let result = store.load()

        XCTAssertFalse(result.isFirstRun)
        XCTAssertNil(result.backupURL)
        XCTAssertEqual(result.state, state)
    }

    func testMissingStateIsFirstRun() {
        let store = StateStore(directory: directory)
        let result = store.load()

        XCTAssertTrue(result.isFirstRun)
        XCTAssertEqual(result.state, PersistedState())
        XCTAssertNil(result.recoveryMessage)
    }

    func testCorruptStateIsBackedUpAndRecovered() throws {
        let store = StateStore(directory: directory)
        try Data("not json".utf8).write(to: store.stateURL)

        let result = store.load()

        XCTAssertFalse(result.isFirstRun)
        XCTAssertEqual(result.state, PersistedState())
        XCTAssertNotNil(result.recoveryMessage)
        let backupURL = try XCTUnwrap(result.backupURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), "not json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.stateURL.path))
    }

    func testDecodingPartialStateUsesDefaults() throws {
        let store = StateStore(directory: directory)
        let json = #"{"timer":{"runState":"idle","selectedFocusMinutes":15}}"#
        try Data(json.utf8).write(to: store.stateURL)

        let result = store.load()

        XCTAssertEqual(result.state.timer.selectedFocusMinutes, 15)
        XCTAssertTrue(result.state.chimeEnabled)
        XCTAssertFalse(result.state.tickEnabled)
        XCTAssertEqual(result.state.themePreference, .system)
    }
}
