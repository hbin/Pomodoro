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
    private func makeEngine(
        _ clock: TestClock,
        state: TimerState = .initial,
        durations: IntervalDurations = .defaults
    ) -> TimerEngine {
        TimerEngine(state: state, durations: durations, now: { clock.date })
    }

    func testStartFocusUsesAbsoluteEndDate() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        let end = engine.startFocus()

        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.totalSeconds, 1500)
        XCTAssertEqual(end, clock.date.addingTimeInterval(1500))
        XCTAssertEqual(engine.displaySeconds(), 1500)
        XCTAssertEqual(engine.progress(), 0, accuracy: 0.0001)
    }

    func testNaturalCompletionAdvancesRhythm() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()

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
        engine.startFocus()

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
        engine.startFocus()
        clock.advance(1500)

        XCTAssertEqual(engine.pause(), .completed(.focus))
        XCTAssertEqual(engine.state.runState, .completed)
        XCTAssertEqual(engine.state.completedFocusCount, 1)
    }

    func testEarlyEndAdvancesCycleWithoutNaturalCompletion() {
        let clock = TestClock()
        var engine = makeEngine(
            clock,
            durations: IntervalDurations(focusMinutes: 45)
        )
        engine.startFocus()

        clock.advance(120)
        engine.endEarly()

        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.state.focusCyclePosition, 1)
        XCTAssertEqual(engine.state.selectedFocusMinutes, 45)
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.displaySeconds(), 300)
    }

    func testFourthCompletionOffersLongBreak() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        for index in 1...4 {
            engine.startFocus()
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

    func testStartRecommendedBreakAfterChimeDelayKeepsFullCountdown() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()
        clock.advance(1500)
        XCTAssertEqual(engine.refresh(), .completed(.focus))

        let end = engine.startRecommendedBreak(after: 1)

        XCTAssertEqual(end, clock.date.addingTimeInterval(301))
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.totalSeconds, 300)
        XCTAssertEqual(engine.displaySeconds(), 300)

        clock.advance(0.2)
        XCTAssertNil(engine.refresh())
        XCTAssertEqual(engine.state.endDate, end)
        XCTAssertEqual(engine.displaySeconds(), 300)

        clock.advance(0.3)
        XCTAssertEqual(engine.remaining(), 300, accuracy: 0.001)
        XCTAssertEqual(engine.progress(), 0, accuracy: 0.0001)

        clock.advance(0.5)
        XCTAssertEqual(engine.displaySeconds(), 300)

        clock.advance(1)
        XCTAssertEqual(engine.displaySeconds(), 299)
    }

    func testStartAnotherAfterChimeDelayKeepsFullCountdown() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()
        clock.advance(1500)
        XCTAssertEqual(engine.refresh(), .completed(.focus))
        engine.startRecommendedBreak()
        clock.advance(300)
        XCTAssertEqual(engine.refresh(), .completed(.shortBreak))

        let end = engine.startAnother(after: 1)

        XCTAssertEqual(end, clock.date.addingTimeInterval(1501))
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.totalSeconds, 1500)
        XCTAssertEqual(engine.displaySeconds(), 1500)

        clock.advance(0.2)
        XCTAssertNil(engine.refresh())
        XCTAssertEqual(engine.state.endDate, end)
        XCTAssertEqual(engine.displaySeconds(), 1500)

        clock.advance(1.8)
        XCTAssertEqual(engine.displaySeconds(), 1499)
    }

    func testStartingShortBreakDirectlyFromIdle() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        let end = engine.startBreak(.shortBreak)

        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.totalSeconds, 300)
        XCTAssertEqual(engine.state.remainingSeconds, 300)
        XCTAssertEqual(engine.state.endDate, clock.date.addingTimeInterval(300))
        XCTAssertEqual(end, clock.date.addingTimeInterval(300))
        XCTAssertEqual(engine.displaySeconds(), 300)
    }

    func testStartingLongBreakDirectlyFromIdle() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        let end = engine.startBreak(.longBreak)

        XCTAssertEqual(engine.state.phase, .longBreak)
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.totalSeconds, 900)
        XCTAssertEqual(engine.state.remainingSeconds, 900)
        XCTAssertEqual(engine.state.endDate, clock.date.addingTimeInterval(900))
        XCTAssertEqual(end, clock.date.addingTimeInterval(900))
        XCTAssertEqual(engine.displaySeconds(), 900)
    }

    func testDirectBreakPreservesFocusRhythm() {
        let clock = TestClock()
        let state = TimerState(completedFocusCount: 3)
        var engine = makeEngine(clock, state: state)

        engine.startBreak(.longBreak)

        XCTAssertEqual(engine.state.completedFocusCount, 3)
        XCTAssertEqual(engine.recommendedBreak.phase, .shortBreak)
    }

    func testDirectBreakRejectsInvalidPhaseAndNonIdleStates() {
        let clock = TestClock()
        var idleEngine = makeEngine(clock)

        XCTAssertNil(idleEngine.startBreak(.focus))
        XCTAssertEqual(idleEngine.state, .initial)

        let states = [
            TimerState(
                phase: .focus,
                runState: .running,
                totalSeconds: 1500,
                remainingSeconds: 1200,
                endDate: clock.date.addingTimeInterval(1200)
            ),
            TimerState(
                phase: .focus,
                runState: .paused,
                totalSeconds: 1500,
                remainingSeconds: 1200
            ),
            TimerState(
                phase: .focus,
                runState: .completed,
                totalSeconds: 1500,
                remainingSeconds: 0
            ),
            TimerState(
                phase: .shortBreak,
                runState: .running,
                totalSeconds: 300,
                remainingSeconds: 200,
                endDate: clock.date.addingTimeInterval(200)
            ),
            TimerState(
                phase: .shortBreak,
                runState: .paused,
                totalSeconds: 300,
                remainingSeconds: 200
            ),
            TimerState(
                phase: .shortBreak,
                runState: .completed,
                totalSeconds: 300,
                remainingSeconds: 0
            )
        ]

        for state in states {
            var engine = makeEngine(clock, state: state)

            XCTAssertNil(engine.startBreak(.shortBreak), "\(state.runState) \(state.phase)")
            XCTAssertEqual(engine.state, state)
        }
    }

    func testSkippingLongBreakResetsRhythm() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        for _ in 1...4 {
            engine.startFocus()
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
            engine.startFocus()
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
        engine.startFocus()
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

    func testRefreshAfterWakeCompletesExpiredIntervalOnce() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()

        clock.advance(90)
        XCTAssertNil(engine.refresh())
        XCTAssertEqual(engine.displaySeconds(), 1410)

        clock.advance(1500)
        XCTAssertEqual(engine.refresh(), .completed(.focus))
        XCTAssertEqual(engine.state.completedFocusCount, 1)
        XCTAssertNil(engine.refresh())
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

    func testConfiguredDurationsDriveFocusAndDirectBreaks() {
        let clock = TestClock()
        let durations = IntervalDurations(
            focusMinutes: 50,
            shortBreakMinutes: 10,
            longBreakMinutes: 20
        )
        var engine = makeEngine(clock, durations: durations)

        let focusEnd = engine.startFocus()

        XCTAssertEqual(engine.state.selectedFocusMinutes, 50)
        XCTAssertEqual(engine.state.totalSeconds, 3000)
        XCTAssertEqual(focusEnd, clock.date.addingTimeInterval(3000))
        XCTAssertEqual(engine.displaySeconds(), 3000)

        engine.endEarly()
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.state.totalSeconds, 600)
        XCTAssertEqual(engine.state.selectedFocusMinutes, 50)
        XCTAssertEqual(engine.displaySeconds(), 600)

        let shortEnd = engine.startBreak(.shortBreak)
        XCTAssertEqual(engine.state.totalSeconds, 600)
        XCTAssertEqual(shortEnd, clock.date.addingTimeInterval(600))

        engine.endEarly()
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.state.totalSeconds, 3000)
        let longEnd = engine.startBreak(.longBreak)
        XCTAssertEqual(engine.state.totalSeconds, 1200)
        XCTAssertEqual(longEnd, clock.date.addingTimeInterval(1200))
    }

    func testConfiguredShortBreakDrivesRecommendation() {
        let clock = TestClock()
        var engine = makeEngine(
            clock,
            durations: IntervalDurations(
                focusMinutes: 50,
                shortBreakMinutes: 10,
                longBreakMinutes: 20
            )
        )

        engine.startFocus()
        clock.advance(3000)
        XCTAssertEqual(engine.refresh(), .completed(.focus))
        XCTAssertEqual(engine.recommendedBreak.minutes, 10)
        XCTAssertEqual(engine.recommendedBreak.phase, .shortBreak)

        engine.startRecommendedBreak()
        XCTAssertEqual(engine.state.totalSeconds, 600)
        XCTAssertEqual(engine.state.phase, .shortBreak)
    }

    func testConfiguredLongBreakDrivesFourthCompletionAndAnotherFocus() {
        let clock = TestClock()
        var engine = makeEngine(
            clock,
            durations: IntervalDurations(
                focusMinutes: 50,
                shortBreakMinutes: 10,
                longBreakMinutes: 20
            )
        )

        for _ in 1...4 {
            engine.startFocus()
            clock.advance(3000)
            XCTAssertEqual(engine.refresh(), .completed(.focus))
        }

        XCTAssertEqual(engine.recommendedBreak.minutes, 20)
        XCTAssertEqual(engine.recommendedBreak.phase, .longBreak)

        engine.startRecommendedBreak()
        XCTAssertEqual(engine.state.totalSeconds, 1200)
        clock.advance(1200)
        XCTAssertEqual(engine.refresh(), .completed(.longBreak))

        engine.startAnother()
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.totalSeconds, 3000)
        XCTAssertEqual(engine.state.selectedFocusMinutes, 50)
    }

    func testApplyDurationsUpdatesIdleAndLeavesActiveIntervalAlone() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        let focusEnd = engine.startFocus()
        clock.advance(60)

        engine.applyDurations(
            IntervalDurations(
                focusMinutes: 50,
                shortBreakMinutes: 10,
                longBreakMinutes: 20
            )
        )

        XCTAssertEqual(engine.state.totalSeconds, 1500)
        XCTAssertEqual(engine.state.endDate, focusEnd)
        XCTAssertEqual(engine.remaining(), 1440, accuracy: 0.001)

        engine.pause()
        XCTAssertEqual(engine.remaining(), 1440, accuracy: 0.001)
        engine.applyDurations(IntervalDurations(focusMinutes: 60))
        XCTAssertEqual(engine.state.totalSeconds, 1500)
        XCTAssertEqual(engine.remaining(), 1440, accuracy: 0.001)

        XCTAssertNil(engine.endInterval(autoStart: false))
        XCTAssertEqual(engine.state.runState, .paused)

        engine.doneForNow()
        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.state.selectedFocusMinutes, 60)
        XCTAssertEqual(engine.state.totalSeconds, 3600)
        XCTAssertEqual(engine.displaySeconds(), 3600)
    }

    func testIdleSanitizationUsesConfiguredFocus() {
        let clock = TestClock()
        let durations = IntervalDurations(focusMinutes: 30)
        let state = TimerState(
            selectedFocusMinutes: 45,
            phase: .focus,
            runState: .idle,
            totalSeconds: 2700,
            remainingSeconds: 2700
        )

        let engine = TimerEngine(
            state: state,
            durations: durations,
            now: { clock.date }
        )

        XCTAssertEqual(engine.state.selectedFocusMinutes, 30)
        XCTAssertEqual(engine.state.totalSeconds, 1800)
        XCTAssertEqual(engine.state.remainingSeconds, 1800)

        let invalid = TimerState(
            selectedFocusMinutes: 999,
            phase: .focus,
            runState: .idle,
            totalSeconds: 2700,
            remainingSeconds: 2700
        )
        let invalidEngine = TimerEngine(
            state: invalid,
            durations: durations,
            now: { clock.date }
        )
        XCTAssertEqual(invalidEngine.state.selectedFocusMinutes, 30)
    }

    func testClockMovedBackwardsDoesNotExtendPastTotal() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()

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

    func testEarlyEndedFocusDestinationsFollowFourFocusCycle() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        for position in 1...4 {
            engine.startFocus()
            clock.advance(60)

            let transition = engine.endInterval(autoStart: false)
            let expectedPhase: Phase = position == 4 ? .longBreak : .shortBreak

            XCTAssertEqual(transition?.endedPhase, .focus)
            XCTAssertEqual(transition?.nextPhase, expectedPhase)
            XCTAssertEqual(transition?.runState, .idle)
            XCTAssertNil(transition?.endDate)
            XCTAssertEqual(engine.state.phase, expectedPhase)
            XCTAssertEqual(engine.state.runState, .idle)
            XCTAssertEqual(engine.state.focusCyclePosition, position)
            XCTAssertEqual(engine.state.completedFocusCount, 0)
            XCTAssertEqual(engine.state.totalSeconds, TimeInterval(
                engine.durations.minutes(for: expectedPhase) * 60
            ))
        }
    }

    func testEarlyEndedShortBreakAdvancesToFocusReadyWithoutChangingCycle() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        engine.startFocus()
        clock.advance(60)
        _ = engine.endInterval(autoStart: false)
        engine.startBreak(.shortBreak)
        clock.advance(30)

        let transition = engine.endInterval(autoStart: false)

        XCTAssertEqual(transition?.endedPhase, .shortBreak)
        XCTAssertEqual(transition?.nextPhase, .focus)
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.state.focusCyclePosition, 1)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.state.totalSeconds, 1500)
        XCTAssertEqual(engine.displaySeconds(), 1500)
    }

    func testEarlyEndedLongBreakAdvancesToNextFocusAndResetsCompletedCycle() {
        let clock = TestClock()
        let state = TimerState(
            phase: .longBreak,
            runState: .running,
            totalSeconds: 900,
            remainingSeconds: 600,
            endDate: clock.date.addingTimeInterval(600),
            completedFocusCount: 4,
            focusCyclePosition: 4
        )
        var engine = makeEngine(clock, state: state)

        let transition = engine.endInterval(autoStart: false)

        XCTAssertEqual(transition?.endedPhase, .longBreak)
        XCTAssertEqual(transition?.nextPhase, .focus)
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.state.focusCyclePosition, 0)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.displaySeconds(), 1500)
    }

    func testEarlyAndNaturalFocusEndsShareOneFourFocusCadence() {
        let clock = TestClock()
        var engine = makeEngine(clock)

        engine.startFocus()
        clock.advance(60)
        XCTAssertEqual(engine.endInterval(autoStart: false)?.nextPhase, .shortBreak)
        engine.startBreak(.shortBreak)
        clock.advance(300)
        XCTAssertEqual(engine.refresh(), .completed(.shortBreak))
        engine.startAnother()

        clock.advance(1500)
        XCTAssertEqual(engine.refresh(), .completed(.focus))
        XCTAssertEqual(engine.state.focusCyclePosition, 2)
        XCTAssertEqual(engine.state.completedFocusCount, 1)
        XCTAssertEqual(engine.recommendedBreak.phase, .shortBreak)
        engine.startRecommendedBreak()
        clock.advance(300)
        XCTAssertEqual(engine.refresh(), .completed(.shortBreak))
        engine.startAnother()

        clock.advance(60)
        XCTAssertEqual(engine.endInterval(autoStart: false)?.nextPhase, .shortBreak)
        engine.startBreak(.shortBreak)
        clock.advance(300)
        XCTAssertEqual(engine.refresh(), .completed(.shortBreak))
        engine.startAnother()

        clock.advance(1500)
        XCTAssertEqual(engine.refresh(), .completed(.focus))
        XCTAssertEqual(engine.state.focusCyclePosition, 4)
        XCTAssertEqual(engine.state.completedFocusCount, 2)
        XCTAssertEqual(engine.recommendedBreak.phase, .longBreak)

        engine.startRecommendedBreak()
        clock.advance(900)
        XCTAssertEqual(engine.refresh(), .completed(.longBreak))
        engine.startAnother()
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.focusCyclePosition, 0)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
    }

    func testEndControlAutoStartShowsNextIntervalRunningWithOneSecondHold() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()
        clock.advance(60)

        let transition = engine.endInterval(autoStart: true)

        XCTAssertEqual(TimerEngine.endControlHandoffDelay, 1.0)
        XCTAssertEqual(transition?.nextPhase, .shortBreak)
        XCTAssertEqual(transition?.runState, .running)
        XCTAssertEqual(transition?.endDate, clock.date.addingTimeInterval(301))
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.totalSeconds, 300)
        XCTAssertEqual(engine.remaining(), 300, accuracy: 0.001)
        XCTAssertEqual(engine.progress(), 0, accuracy: 0.0001)

        clock.advance(0.5)
        XCTAssertEqual(engine.displaySeconds(), 300)
        XCTAssertEqual(engine.progress(), 0, accuracy: 0.0001)

        clock.advance(0.5)
        XCTAssertEqual(engine.remaining(), 300, accuracy: 0.001)
        XCTAssertEqual(engine.displaySeconds(), 300)

        clock.advance(1)
        XCTAssertEqual(engine.remaining(), 299, accuracy: 0.001)
        XCTAssertEqual(engine.displaySeconds(), 299)
    }

    func testEndControlAutoStartOffShowsFullReadyDurationWithoutCountingDown() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()
        clock.advance(60)

        let transition = engine.endInterval(autoStart: false)

        XCTAssertEqual(transition?.nextPhase, .shortBreak)
        XCTAssertEqual(transition?.runState, .idle)
        XCTAssertNil(transition?.endDate)
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.runState, .idle)
        XCTAssertEqual(engine.remaining(), 300, accuracy: 0.001)

        clock.advance(30)
        XCTAssertEqual(engine.remaining(), 300, accuracy: 0.001)
        XCTAssertEqual(engine.displaySeconds(), 300)

        let end = engine.startBreak(.shortBreak)
        XCTAssertEqual(end, clock.date.addingTimeInterval(300))
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.endDate, end)
    }

    func testAutoStartedLongBreakUsesSameOneSecondHold() {
        let clock = TestClock()
        let state = TimerState(
            phase: .focus,
            runState: .running,
            totalSeconds: 1500,
            remainingSeconds: 1200,
            endDate: clock.date.addingTimeInterval(1200),
            focusCyclePosition: 3
        )
        var engine = makeEngine(clock, state: state)

        let transition = engine.endInterval(autoStart: true)

        XCTAssertEqual(transition?.nextPhase, .longBreak)
        XCTAssertEqual(transition?.endDate, clock.date.addingTimeInterval(901))
        XCTAssertEqual(engine.state.phase, .longBreak)
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.focusCyclePosition, 4)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.displaySeconds(), 900)
    }

    func testEndControlAutoStartedFocusHoldsFullCountdownForOneSecond() {
        let clock = TestClock()
        let state = TimerState(
            phase: .shortBreak,
            runState: .running,
            totalSeconds: 300,
            remainingSeconds: 180,
            endDate: clock.date.addingTimeInterval(180),
            focusCyclePosition: 2
        )
        var engine = makeEngine(clock, state: state)

        let transition = engine.endInterval(autoStart: true)

        XCTAssertEqual(transition?.endedPhase, .shortBreak)
        XCTAssertEqual(transition?.nextPhase, .focus)
        XCTAssertEqual(transition?.endDate, clock.date.addingTimeInterval(1501))
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.focusCyclePosition, 2)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.state.totalSeconds, 1500)
        XCTAssertEqual(engine.displaySeconds(), 1500)

        clock.advance(1)
        XCTAssertEqual(engine.remaining(), 1500, accuracy: 0.001)
        clock.advance(1)
        XCTAssertEqual(engine.displaySeconds(), 1499)
    }

    func testAutoStartedFocusAfterEndingLongBreakResetsCycleAndHolds() {
        let clock = TestClock()
        let state = TimerState(
            phase: .longBreak,
            runState: .running,
            totalSeconds: 900,
            remainingSeconds: 600,
            endDate: clock.date.addingTimeInterval(600),
            completedFocusCount: 4,
            focusCyclePosition: 4
        )
        var engine = makeEngine(clock, state: state)

        let transition = engine.endInterval(autoStart: true)

        XCTAssertEqual(transition?.endedPhase, .longBreak)
        XCTAssertEqual(transition?.nextPhase, .focus)
        XCTAssertEqual(transition?.endDate, clock.date.addingTimeInterval(1501))
        XCTAssertEqual(engine.state.phase, .focus)
        XCTAssertEqual(engine.state.runState, .running)
        XCTAssertEqual(engine.state.focusCyclePosition, 0)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
        XCTAssertEqual(engine.displaySeconds(), 1500)
    }

    func testEarlyEndCannotCountTwice() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()
        clock.advance(60)

        XCTAssertEqual(engine.endInterval(autoStart: false)?.nextPhase, .shortBreak)
        XCTAssertNil(engine.endInterval(autoStart: false))
        XCTAssertEqual(engine.state.focusCyclePosition, 1)
        XCTAssertEqual(engine.state.completedFocusCount, 0)

        clock.advance(1500)
        XCTAssertNil(engine.refresh())
        XCTAssertEqual(engine.state.focusCyclePosition, 1)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
    }

    func testPausedIntervalHasNoEndControlTransition() {
        let clock = TestClock()
        var engine = makeEngine(clock)
        engine.startFocus()
        clock.advance(60)
        engine.pause()

        XCTAssertNil(engine.endInterval(autoStart: true))
        XCTAssertNil(engine.endEarly())
        XCTAssertEqual(engine.state.runState, .paused)
        XCTAssertEqual(engine.state.focusCyclePosition, 0)
        XCTAssertEqual(engine.state.completedFocusCount, 0)
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
