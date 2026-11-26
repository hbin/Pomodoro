import XCTest
@testable import PomodoroCore

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
        state.timer.focusCyclePosition = 2
        state.tickEnabled = true
        state.chimeEnabled = false
        state.showMenuBarMinutes = false
        state.durations = IntervalDurations(
            focusMinutes: 50,
            shortBreakMinutes: 10,
            longBreakMinutes: 20
        )
        state.autoStartBreak = true
        state.autoStartFocus = true
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
        XCTAssertNil(result.recoveryIssue)
    }

    func testCorruptStateIsBackedUpAndRecovered() throws {
        let store = StateStore(directory: directory)
        try Data("not json".utf8).write(to: store.stateURL)

        let result = store.load()

        XCTAssertFalse(result.isFirstRun)
        XCTAssertEqual(result.state, PersistedState())
        XCTAssertEqual(result.recoveryIssue, .unreadableStateBackedUp)
        let backupURL = try XCTUnwrap(result.backupURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), "not json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.stateURL.path))
    }

    func testCorruptStateWithFailedBackupReportsReset() throws {
        let store = StateStore(directory: directory)
        try Data("not json".utf8).write(to: store.stateURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: directory.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
        }

        let result = store.load()

        XCTAssertFalse(result.isFirstRun)
        XCTAssertEqual(result.state, PersistedState())
        XCTAssertEqual(result.recoveryIssue, .unreadableStateReset)
        XCTAssertNil(result.backupURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.stateURL.path))
    }

    func testDecodingPartialStateUsesDefaults() throws {
        let store = StateStore(directory: directory)
        let json = #"{"timer":{"runState":"idle","selectedFocusMinutes":15}}"#
        try Data(json.utf8).write(to: store.stateURL)

        let result = store.load()

        XCTAssertEqual(result.state.timer.selectedFocusMinutes, 15)
        XCTAssertTrue(result.state.chimeEnabled)
        XCTAssertFalse(result.state.tickEnabled)
        XCTAssertFalse(result.state.autoStartBreak)
        XCTAssertFalse(result.state.autoStartFocus)
        XCTAssertEqual(result.state.themePreference, .system)
        XCTAssertEqual(result.state.durations, .defaults)
    }

    func testDecodingLegacyStateUsesAutoStartDefaults() throws {
        let store = StateStore(directory: directory)
        let json = """
        {
          "timer": {
            "selectedFocusMinutes": 25,
            "phase": "focus",
            "runState": "idle",
            "totalSeconds": 1500,
            "remainingSeconds": 1500,
            "completedFocusCount": 2
          },
          "chimeEnabled": true,
          "tickEnabled": false,
          "showMenuBarMinutes": true,
          "themePreference": "system",
          "firstRunTipDismissed": true
        }
        """
        try Data(json.utf8).write(to: store.stateURL)

        let result = store.load()

        XCTAssertNil(result.recoveryIssue)
        XCTAssertFalse(result.state.autoStartBreak)
        XCTAssertFalse(result.state.autoStartFocus)
        XCTAssertEqual(result.state.timer.completedFocusCount, 2)
        XCTAssertEqual(result.state.timer.focusCyclePosition, 2)
        XCTAssertEqual(result.state.durations, .defaults)
    }

    func testPartialDurationsUseDefaultsForMissingValues() throws {
        let store = StateStore(directory: directory)
        let json = #"{"durations":{"focusMinutes":50}}"#
        try Data(json.utf8).write(to: store.stateURL)

        let result = store.load()

        XCTAssertNil(result.recoveryIssue)
        XCTAssertEqual(
            result.state.durations,
            IntervalDurations(focusMinutes: 50)
        )
    }

    func testOutOfRangeDurationsAreClampedOnDecode() throws {
        let store = StateStore(directory: directory)
        let json = #"{"durations":{"focusMinutes":0,"shortBreakMinutes":999,"longBreakMinutes":-5}}"#
        try Data(json.utf8).write(to: store.stateURL)

        let result = store.load()

        XCTAssertNil(result.recoveryIssue)
        XCTAssertEqual(result.state.durations.focusMinutes, 1)
        XCTAssertEqual(result.state.durations.shortBreakMinutes, 180)
        XCTAssertEqual(result.state.durations.longBreakMinutes, 1)
    }

    func testDefaultDurationsUseClassicRhythm() {
        let durations = IntervalDurations()

        XCTAssertEqual(durations.focusMinutes, 25)
        XCTAssertEqual(durations.shortBreakMinutes, 5)
        XCTAssertEqual(durations.longBreakMinutes, 15)
        XCTAssertEqual(durations.minutes(for: .focus), 25)
        XCTAssertEqual(durations.minutes(for: .shortBreak), 5)
        XCTAssertEqual(durations.minutes(for: .longBreak), 15)
        XCTAssertEqual(PersistedState().durations, durations)
    }

    func testDurationsClampChangesAndRejectOutOfRangeValues() {
        var durations = IntervalDurations()

        durations.setMinutes(0, for: .focus)
        durations.setMinutes(999, for: .shortBreak)
        durations.setMinutes(-1, for: .longBreak)

        XCTAssertEqual(durations.focusMinutes, 1)
        XCTAssertEqual(durations.shortBreakMinutes, 180)
        XCTAssertEqual(durations.longBreakMinutes, 1)
        XCTAssertEqual(durations.minutes(for: .focus), 1)
        XCTAssertEqual(durations.minutes(for: .shortBreak), 180)
        XCTAssertEqual(durations.minutes(for: .longBreak), 1)
    }

    func testExplicitAutoStartBreakOffSurvivesRoundTrip() throws {
        let store = StateStore(directory: directory)
        var state = PersistedState()
        state.autoStartBreak = false

        try store.save(state)
        let result = store.load()

        XCTAssertNil(result.recoveryIssue)
        XCTAssertFalse(result.state.autoStartBreak)
    }

    func testNextPhaseReadyIsPersistedAsFocusReadyWithCyclePosition() throws {
        let store = StateStore(directory: directory)
        let readyBreak = TimerState(
            phase: .shortBreak,
            runState: .idle,
            totalSeconds: 300,
            remainingSeconds: 300,
            completedFocusCount: 0,
            focusCyclePosition: 1
        )

        try store.save(PersistedState(timer: readyBreak))
        let result = store.load()

        XCTAssertEqual(result.state.timer.phase, .focus)
        XCTAssertEqual(result.state.timer.runState, .idle)
        XCTAssertEqual(result.state.timer.totalSeconds, 1500)
        XCTAssertEqual(result.state.timer.remainingSeconds, 1500)
        XCTAssertEqual(result.state.timer.focusCyclePosition, 1)
        XCTAssertEqual(result.state.timer.completedFocusCount, 0)

        let restored = TimerEngine(state: result.state.timer, durations: result.state.durations)
        XCTAssertEqual(restored.state.phase, .focus)
        XCTAssertEqual(restored.state.runState, .idle)
        XCTAssertEqual(restored.state.focusCyclePosition, 1)
    }

    func testRunningAndPausedRestoreKeepNaturalAndCycleCounts() {
        let clock = TestClock()
        let runningState = TimerState(
            phase: .shortBreak,
            runState: .running,
            totalSeconds: 300,
            remainingSeconds: 240,
            endDate: clock.date.addingTimeInterval(240),
            completedFocusCount: 2,
            focusCyclePosition: 3
        )
        var running = TimerEngine(
            state: runningState,
            durations: .defaults,
            now: { clock.date }
        )
        XCTAssertNil(running.restore())
        XCTAssertEqual(running.state.runState, .running)
        XCTAssertEqual(running.state.completedFocusCount, 2)
        XCTAssertEqual(running.state.focusCyclePosition, 3)

        var pausedState = runningState
        pausedState.runState = .paused
        pausedState.remainingSeconds = 120
        pausedState.endDate = nil
        var paused = TimerEngine(
            state: pausedState,
            durations: .defaults,
            now: { clock.date }
        )
        XCTAssertNil(paused.restore())
        XCTAssertEqual(paused.state.runState, .paused)
        XCTAssertEqual(paused.state.completedFocusCount, 2)
        XCTAssertEqual(paused.state.focusCyclePosition, 3)
    }
}
