import AppKit
import Foundation
import PomodoroCore
import UserNotifications

@MainActor
protocol TickerScheduling: AnyObject {
    func start(handler: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
final class RunLoopTicker: TickerScheduling {
    private static let interval: TimeInterval = 0.2
    private var timer: Timer?

    func start(handler: @escaping @MainActor () -> Void) {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { _ in
            MainActor.assumeIsolated {
                handler()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct MenuBarDescriptor: Equatable {
    var showsRemainingMinutes: Bool
    var isActive: Bool
    var isPaused: Bool
    var isCompleted: Bool
    var isBreak: Bool
    var remainingMinutes: Int
    var progress: Double
}

/// The interval offered by the completion screen. A completed focus offers
/// the recommended break; a completed break offers the next focus. The offer
/// is presentation-only: no countdown starts until the user chooses.
struct CompletionOffer: Equatable {
    var phase: Phase
    var minutes: Int

    var timeText: String {
        String(format: "%02d:00", minutes)
    }
}

private enum TimerModelError: Equatable {
    case recovery(StateRecoveryIssue)
    case saveFailed

    var message: String {
        switch self {
        case .recovery(.unreadableStateBackedUp):
            L10n.string("errors.recovery.backed_up")
        case .recovery(.unreadableStateReset):
            L10n.string("errors.recovery.reset")
        case .saveFailed:
            L10n.string("errors.save_failed")
        }
    }
}

@MainActor
final class TimerModel: ObservableObject {
    /// Extra room after the chime for audio-output latency before the break
    /// countdown starts.
    private static let autoStartChimeBuffer: TimeInterval = 0.15

    @Published private(set) var snapshot: TimerState
    @Published private(set) var now: Date
    @Published private(set) var isShowingSettings = false
    /// The natural height of the Settings content, measured by the view so the
    /// card can grow to fit instead of scrolling.
    @Published private(set) var settingsContentHeight: CGFloat = 0
    @Published private(set) var chimeEnabled: Bool
    @Published private(set) var tickEnabled: Bool
    @Published private(set) var showMenuBarMinutes: Bool
    @Published private(set) var durations: IntervalDurations
    @Published private(set) var autoStartBreak: Bool
    @Published private(set) var autoStartFocus: Bool
    @Published private(set) var themePreference: ThemePreference
    @Published private(set) var languagePreference: LanguagePreference
    @Published private(set) var firstRunTipDismissed: Bool
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isFirstRun: Bool
    /// The mode shown on the Ready screen. This is presentation state only:
    /// it is not saved, and a relaunch returns to Focus Ready.
    @Published private(set) var idlePhase: Phase
    /// Set when the completion screen starts its offered interval. The next
    /// timer presentation consumes it to sweep the ring from empty.
    @Published private(set) var completionStartSweepPending = false

    @Published private var error: TimerModelError?

    var onMenuBarChange: ((MenuBarDescriptor) -> Void)?
    var onAppearanceChange: ((ThemePreference) -> Void)?
    var onLanguageChange: (() -> Void)?

    private let store: StateStore
    private let notifications: any NotificationScheduling
    private let sounds: SoundPlayer
    private let ticker: any TickerScheduling
    private let dateProvider: @Sendable () -> Date
    private var engine: TimerEngine
    private var powerObservers: [NSObjectProtocol] = []
    private var timerActivity: NSObjectProtocol?
    private var lastMenuBarDescriptor: MenuBarDescriptor?
    private var lastTickSecond: Int?
    private var lastTickDate: Date?
    private var lastWakeRecovery: Date?
    private var hasRequestedAuthorization = false
    private var needsInitialSave = false

    init(
        store: StateStore = StateStore(directory: StateStore.defaultDirectory()),
        notifications: any NotificationScheduling = NotificationService(),
        sounds: SoundPlayer = SoundPlayer(),
        ticker: any TickerScheduling = RunLoopTicker(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let languagePreference = LanguagePreferenceStore.load()
        L10n.setActiveLanguage(languagePreference.effectiveLanguage)

        self.store = store
        self.notifications = notifications
        self.sounds = sounds
        self.ticker = ticker
        self.dateProvider = now

        let loaded = store.load()
        var engine = TimerEngine(
            state: loaded.state.timer,
            durations: loaded.state.durations,
            now: now
        )
        let restoredEvent = engine.restore()
        let currentDate = now()
        self.engine = engine
        self.snapshot = engine.state
        self.now = currentDate
        self.chimeEnabled = loaded.state.chimeEnabled
        self.tickEnabled = loaded.state.tickEnabled
        self.showMenuBarMinutes = loaded.state.showMenuBarMinutes
        self.durations = loaded.state.durations
        self.autoStartBreak = loaded.state.autoStartBreak
        self.autoStartFocus = loaded.state.autoStartFocus
        self.themePreference = loaded.state.themePreference
        self.languagePreference = languagePreference
        self.firstRunTipDismissed = loaded.state.firstRunTipDismissed
        self.isFirstRun = loaded.isFirstRun
        self.idlePhase = LaunchIdleMode.override?.phase ?? .focus
        self.error = switch loaded.recoveryIssue {
        case .unreadableStateBackedUp: .recovery(.unreadableStateBackedUp)
        case .unreadableStateReset: .recovery(.unreadableStateReset)
        case nil: nil
        }
        self.needsInitialSave = restoredEvent != nil

        if engine.state.runState == .running {
            self.lastTickSecond = engine.displaySeconds(at: currentDate)
            self.lastTickDate = currentDate
        }
    }

    // MARK: - Lifecycle

    func activate() {
        startObservingPowerEvents()
        tick()
        syncTicker()
        syncTimerActivity()
        refreshNotificationStatus()
        updateMenuBar(force: true)
        if engine.state.runState == .running {
            scheduleNotificationForCurrentInterval()
        }
        if needsInitialSave {
            needsInitialSave = false
            save()
        }
    }

    func saveNow() {
        save()
    }

    func reportSettingsContentHeight(_ height: CGFloat) {
        guard height > 0, height.isFinite, abs(height - settingsContentHeight) >= 0.5 else { return }
        settingsContentHeight = height
    }

    private func syncTicker() {
        if engine.state.runState == .running {
            ticker.start { [weak self] in
                self?.tick()
            }
        } else {
            ticker.stop()
        }
    }

    private func startObservingPowerEvents() {
        guard powerObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names = [
            NSWorkspace.willSleepNotification,
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.screensDidWakeNotification
        ]
        powerObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if name == NSWorkspace.willSleepNotification
                        || name == NSWorkspace.screensDidSleepNotification {
                        self.prepareForSleep()
                    } else {
                        self.recoverAfterWake()
                    }
                }
            }
        }
    }

    private func prepareForSleep() {
        lastTickSecond = nil
        lastTickDate = nil
        sounds.prepareForSleep()
    }

    func recoverAfterWake() {
        let date = dateProvider()
        if let lastWakeRecovery, date.timeIntervalSince(lastWakeRecovery) < 2 {
            return
        }
        lastWakeRecovery = date
        sounds.resumeAfterWake()
        lastTickSecond = nil
        lastTickDate = nil
        tick()
        syncTicker()
        updateMenuBar(force: true)
    }

    private func tick() {
        if engine.state.runState == .running {
            now = dateProvider()
        }
        if let event = engine.refresh() {
            handle(event: event)
            return
        }
        if engine.state != snapshot {
            snapshot = engine.state
        }
        if engine.state.runState != .running {
            syncTicker()
        }
        updateTickSound()
        updateMenuBar()
    }

    // MARK: - Derived values

    var runState: RunState { snapshot.runState }
    var phase: Phase { snapshot.phase }
    var isIdle: Bool { snapshot.runState == .idle }
    var isRunning: Bool { snapshot.runState == .running }
    var isPaused: Bool { snapshot.runState == .paused }
    var isCompleted: Bool { snapshot.runState == .completed }
    var isBreak: Bool { snapshot.phase.isBreak }
    var recommendedBreakMinutes: Int { engine.recommendedBreak.minutes }
    var recommendedBreakPhase: Phase { engine.recommendedBreak.phase }
    var completedFocusCount: Int { snapshot.completedFocusCount }
    var activeLanguage: AppLanguage { languagePreference.effectiveLanguage }
    var errorMessage: String? { error?.message }

    /// The next interval shown by the completion screen. While a completed
    /// interval is on screen, `phase` still names the interval that just
    /// finished; this offer derives the guided next step without starting it.
    var completionOffer: CompletionOffer {
        if snapshot.phase.isBreak {
            return CompletionOffer(phase: .focus, minutes: durations.focusMinutes)
        }
        return CompletionOffer(
            phase: recommendedBreakPhase,
            minutes: recommendedBreakMinutes
        )
    }

    var remainingSeconds: TimeInterval {
        engine.remaining(at: now)
    }

    var displaySeconds: Int {
        Int(ceil(remainingSeconds))
    }

    var timeText: String {
        Self.formatTime(displaySeconds)
    }

    var progress: Double {
        engine.progress(at: now)
    }

    var endsAtText: String? {
        guard let endDate = snapshot.endDate else { return nil }
        return endDate.formatted(date: .omitted, time: .shortened)
    }

    var readoutCaption: String {
        return switch snapshot.runState {
        case .idle: L10n.string("timer.caption.ready")
        case .running: L10n.string("timer.caption.remaining")
        case .paused: L10n.string("timer.caption.paused")
        case .completed: L10n.string("timer.caption.complete")
        }
    }

    var notificationStatusText: String {
        return switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            L10n.string("notification_status.on")
        case .denied:
            L10n.string("notification_status.off")
        case .notDetermined:
            L10n.string("notification_status.not_requested")
        @unknown default:
            L10n.string("notification_status.unknown")
        }
    }

    var menuBarDescriptor: MenuBarDescriptor {
        let active = snapshot.runState == .running || snapshot.runState == .paused
        let completed = snapshot.runState == .completed
        let menuBarPhase = snapshot.runState == .idle ? idlePhase : snapshot.phase
        let remainingMinutes = active ? max(1, Int(ceil(remainingSeconds / 60))) : 0
        let progress: Double
        if completed {
            progress = 1
        } else if active {
            progress = Self.menuBarProgress(engine.progress(at: now))
        } else {
            progress = 0
        }
        return MenuBarDescriptor(
            showsRemainingMinutes: active && showMenuBarMinutes,
            isActive: active,
            isPaused: snapshot.runState == .paused,
            isCompleted: completed,
            isBreak: menuBarPhase.isBreak,
            remainingMinutes: remainingMinutes,
            progress: progress
        )
    }

    // MARK: - Actions

    func selectIdlePhase(_ phase: Phase) {
        guard isIdle, phase != idlePhase else { return }
        idlePhase = phase
        updateMenuBar(force: true)
    }

    func startIdleInterval() {
        guard isIdle else { return }
        if idlePhase == .focus {
            startFocus()
        } else {
            startBreak(idlePhase)
        }
    }

    func startFocus() {
        guard let endDate = engine.startFocus() else { return }
        snapshot = engine.state
        now = dateProvider()
        lastTickSecond = nil
        lastTickDate = nil
        syncTicker()
        save()
        updateMenuBar(force: true)
        announce(L10n.string("announcements.focus_started"))
        scheduleNotification(endDate: endDate, phase: .focus)
    }

    /// Starts the break offered by the completion screen.
    func takeBreak() {
        startRecommendedBreak(after: 0, sweepsOnPresentation: true)
    }

    /// Starts the recommended break with its end date pushed out by `delay`, so
    /// the displayed countdown stays at full while the completion chime ends.
    private func startRecommendedBreak(
        after delay: TimeInterval,
        sweepsOnPresentation: Bool = false
    ) {
        guard let endDate = engine.startRecommendedBreak(after: delay) else { return }
        if sweepsOnPresentation {
            completionStartSweepPending = true
        }
        snapshot = engine.state
        now = dateProvider()
        lastTickSecond = nil
        syncTicker()
        save()
        updateMenuBar(force: true)
        announce(L10n.string("announcements.break_started"))
        scheduleNotification(endDate: endDate, phase: snapshot.phase)
    }

    func startBreak(_ phase: Phase) {
        guard let endDate = engine.startBreak(phase) else { return }
        snapshot = engine.state
        now = dateProvider()
        lastTickSecond = nil
        syncTicker()
        save()
        updateMenuBar(force: true)
        announce(L10n.string("announcements.break_started"))
        scheduleNotification(endDate: endDate, phase: snapshot.phase)
    }

    /// Starts the focus offered by the completion screen.
    func startAnother() {
        startAnother(after: 0, sweepsOnPresentation: true)
    }

    /// Starts the next focus with its end date pushed out by `delay`, so the
    /// countdown holds at full while the break chime finishes.
    private func startAnother(
        after delay: TimeInterval,
        sweepsOnPresentation: Bool = false
    ) {
        guard let endDate = engine.startAnother(after: delay) else { return }
        if sweepsOnPresentation {
            completionStartSweepPending = true
        }
        snapshot = engine.state
        now = dateProvider()
        lastTickSecond = nil
        lastTickDate = nil
        syncTicker()
        save()
        updateMenuBar(force: true)
        announce(L10n.string("announcements.focus_started"))
        scheduleNotification(endDate: endDate, phase: .focus)
    }

    func consumeCompletionStartSweep() {
        guard completionStartSweepPending else { return }
        completionStartSweepPending = false
    }

    func togglePause() {
        if engine.state.runState == .running {
            if let event = engine.pause() {
                handle(event: event)
                return
            }
            snapshot = engine.state
            now = dateProvider()
            lastTickSecond = nil
            notifications.cancel()
            syncTicker()
            save()
            updateMenuBar(force: true)
            announce(L10n.string("announcements.focus_paused"))
        } else if engine.state.runState == .paused {
            guard let endDate = engine.resume() else { return }
            snapshot = engine.state
            now = dateProvider()
            lastTickSecond = engine.displaySeconds(at: now)
            lastTickDate = now
            syncTicker()
            save()
            updateMenuBar(force: true)
            announce(L10n.string("announcements.focus_resumed"))
            scheduleNotification(endDate: endDate, phase: snapshot.phase)
        }
    }

    func endInterval() {
        guard engine.state.runState == .running else { return }
        let endedPhase = engine.state.phase
        let autoStart = endedPhase.isBreak ? autoStartFocus : autoStartBreak
        guard let transition = engine.endInterval(autoStart: autoStart) else { return }

        if transition.runState == .idle {
            idlePhase = transition.nextPhase
        }
        snapshot = engine.state
        now = dateProvider()
        lastTickSecond = nil
        lastTickDate = nil
        notifications.cancel()
        if chimeEnabled {
            sounds.playChime(for: endedPhase)
        }
        save()
        updateMenuBar(force: true)
        if transition.runState == .running, let endDate = transition.endDate {
            announce(
                L10n.string(
                    transition.nextPhase.isBreak
                        ? "announcements.break_started"
                        : "announcements.focus_started"
                )
            )
            scheduleNotification(endDate: endDate, phase: transition.nextPhase)
        } else {
            announce(L10n.string("announcements.interval_ended"))
        }
        syncTicker()
    }

    func skipBreak() {
        engine.skipBreak()
        finishToIdle()
        announce(L10n.string("announcements.break_skipped"))
    }

    func doneForNow() {
        engine.doneForNow()
        finishToIdle()
    }

    private func finishToIdle() {
        idlePhase = .focus
        completionStartSweepPending = false
        snapshot = engine.state
        now = dateProvider()
        notifications.cancel()
        syncTicker()
        save()
        updateMenuBar(force: true)
    }

    func openSettings() {
        isShowingSettings = true
    }

    func closeSettings() {
        isShowingSettings = false
    }

    func setChimeEnabled(_ enabled: Bool) {
        chimeEnabled = enabled
        save()
    }

    func setTickEnabled(_ enabled: Bool) {
        tickEnabled = enabled
        if !enabled {
            lastTickSecond = nil
        }
        save()
    }

    func setShowMenuBarMinutes(_ enabled: Bool) {
        showMenuBarMinutes = enabled
        save()
        updateMenuBar(force: true)
    }

    func setDurationMinutes(_ minutes: Int, for phase: Phase) {
        var updated = durations
        updated.setMinutes(minutes, for: phase)
        guard updated != durations else { return }
        durations = updated
        engine.applyDurations(updated)
        snapshot = engine.state
        save()
    }

    func setAutoStartBreak(_ enabled: Bool) {
        guard autoStartBreak != enabled else { return }
        autoStartBreak = enabled
        save()
    }

    func setAutoStartFocus(_ enabled: Bool) {
        guard autoStartFocus != enabled else { return }
        autoStartFocus = enabled
        save()
    }

    func setThemePreference(_ preference: ThemePreference) {
        if themePreference != preference {
            themePreference = preference
            save()
        }
        onAppearanceChange?(preference)
    }

    func setLanguagePreference(_ preference: LanguagePreference) {
        guard languagePreference != preference else { return }

        LanguagePreferenceStore.save(preference)
        L10n.setActiveLanguage(preference.effectiveLanguage)
        languagePreference = preference

        onLanguageChange?()
        updateMenuBar(force: true)
        if engine.state.runState == .running {
            scheduleNotificationForCurrentInterval()
        }
        announce(
            L10n.format(
                "announcements.language_changed",
                preference.effectiveLanguage.autonym
            )
        )
    }

    func refreshNotificationStatus() {
        Task {
            notificationStatus = await notifications.authorizationStatus()
        }
    }

    func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.hb.pomodoro",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func dismissError() {
        error = nil
    }

    // MARK: - Private

    private func handle(event: TimerEvent) {
        snapshot = engine.state
        now = dateProvider()
        lastTickSecond = nil
        lastTickDate = nil
        completionStartSweepPending = false
        notifications.cancel()
        updateMenuBar(force: true)
        save()

        switch event {
        case .completed(let phase):
            if chimeEnabled {
                sounds.playChime(for: phase)
            }
            if phase == .focus {
                if autoStartBreak {
                    if chimeEnabled {
                        startRecommendedBreak(
                            after: SoundPlayer.focusChimeDuration + Self.autoStartChimeBuffer
                        )
                    } else {
                        startRecommendedBreak(after: 0)
                    }
                } else {
                    announce(L10n.format("announcements.focus_complete", recommendedBreakMinutes))
                }
            } else {
                if autoStartFocus {
                    if chimeEnabled {
                        startAnother(
                            after: SoundPlayer.breakChimeDuration + Self.autoStartChimeBuffer
                        )
                    } else {
                        startAnother(after: 0)
                    }
                } else {
                    announce(L10n.string("announcements.break_complete"))
                }
            }
        }
        syncTicker()
    }

    private func updateTickSound() {
        guard tickEnabled,
              engine.state.runState == .running,
              engine.state.phase == .focus else {
            lastTickSecond = nil
            return
        }
        let second = engine.displaySeconds(at: now)
        if let previous = lastTickSecond {
            if second == previous - 1, let lastTickDate,
               now.timeIntervalSince(lastTickDate) < 1.6 {
                sounds.playTick()
            }
            if second > previous {
                lastTickSecond = second
                self.lastTickDate = now
                return
            }
        }
        if lastTickSecond != second {
            lastTickSecond = second
            lastTickDate = now
        }
    }

    private func updateMenuBar(force: Bool = false) {
        let descriptor = menuBarDescriptor
        if force || descriptor != lastMenuBarDescriptor {
            lastMenuBarDescriptor = descriptor
            onMenuBarChange?(descriptor)
        }
    }

    private func scheduleNotification(endDate: Date, phase: Phase) {
        Task {
            if !hasRequestedAuthorization {
                hasRequestedAuthorization = true
                _ = await notifications.requestAuthorization()
                notificationStatus = await notifications.authorizationStatus()
            }
            await notifications.schedule(at: endDate, phase: phase)
        }
    }

    private func scheduleNotificationForCurrentInterval() {
        guard let endDate = engine.state.endDate else { return }
        let phase = engine.state.phase
        Task {
            await notifications.schedule(at: endDate, phase: phase)
        }
    }

    private func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                NSAccessibility.NotificationUserInfoKey.announcement: message,
                NSAccessibility.NotificationUserInfoKey.priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }

    private func save() {
        syncTimerActivity()
        let persisted = PersistedState(
            timer: engine.state,
            durations: durations,
            chimeEnabled: chimeEnabled,
            tickEnabled: tickEnabled,
            showMenuBarMinutes: showMenuBarMinutes,
            autoStartBreak: autoStartBreak,
            autoStartFocus: autoStartFocus,
            themePreference: themePreference,
            firstRunTipDismissed: firstRunTipDismissed
        )
        do {
            try store.save(persisted)
        } catch {
            self.error = .saveFailed
        }
    }

    private func syncTimerActivity() {
        if engine.state.runState == .running {
            guard timerActivity == nil else { return }
            timerActivity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep],
                reason: "Pomodoro countdown is running"
            )
        } else if let timerActivity {
            ProcessInfo.processInfo.endActivity(timerActivity)
            self.timerActivity = nil
        }
    }

    private static func formatTime(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    private static func menuBarProgress(_ progress: Double) -> Double {
        let steps = 96.0
        let clamped = min(max(progress, 0), 1)
        return (clamped * steps).rounded() / steps
    }
}
