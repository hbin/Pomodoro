import AppKit
import Foundation
import PomodoroCore
import UserNotifications

struct MenuBarDescriptor: Equatable {
    var title: String
    var isActive: Bool
    var isPaused: Bool
    var isCompleted: Bool
    var isBreak: Bool
    var remainingMinutes: Int
    var progress: Double
}

@MainActor
final class TimerModel: ObservableObject {
    @Published private(set) var snapshot: TimerState
    @Published private(set) var now: Date
    @Published private(set) var isShowingSettings = false
    @Published private(set) var chimeEnabled: Bool
    @Published private(set) var tickEnabled: Bool
    @Published private(set) var showMenuBarMinutes: Bool
    @Published private(set) var themePreference: ThemePreference
    @Published private(set) var firstRunTipDismissed: Bool
    @Published private(set) var errorMessage: String?
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isFirstRun: Bool

    var onMenuBarChange: ((MenuBarDescriptor) -> Void)?
    var onAppearanceChange: ((ThemePreference) -> Void)?

    private let store: StateStore
    private let notifications: NotificationService
    private let sounds: SoundPlayer
    private var engine: TimerEngine
    private var ticker: Timer?
    private var lastMenuBarDescriptor: MenuBarDescriptor?
    private var lastTickSecond: Int?
    private var lastTickDate: Date?
    private var hasRequestedAuthorization = false
    private var tickerStarted = false
    private var needsInitialSave = false

    init(
        store: StateStore = StateStore(directory: StateStore.defaultDirectory()),
        notifications: NotificationService = NotificationService(),
        sounds: SoundPlayer = SoundPlayer()
    ) {
        self.store = store
        self.notifications = notifications
        self.sounds = sounds

        let loaded = store.load()
        var engine = TimerEngine(state: loaded.state.timer)
        let restoredEvent = engine.restore()
        self.engine = engine
        self.snapshot = engine.state
        self.now = Date()
        self.chimeEnabled = loaded.state.chimeEnabled
        self.tickEnabled = loaded.state.tickEnabled
        self.showMenuBarMinutes = loaded.state.showMenuBarMinutes
        self.themePreference = loaded.state.themePreference
        self.firstRunTipDismissed = loaded.state.firstRunTipDismissed
        self.isFirstRun = loaded.isFirstRun
        self.errorMessage = loaded.recoveryMessage
        self.needsInitialSave = restoredEvent != nil

        if engine.state.runState == .running {
            self.lastTickSecond = engine.displaySeconds(at: now)
            self.lastTickDate = now
        }
    }

    // MARK: - Lifecycle

    func activate() {
        startTicker()
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

    private func startTicker() {
        guard !tickerStarted else { return }
        tickerStarted = true
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        if engine.state.runState == .running {
            now = Date()
        }
        if let event = engine.refresh() {
            handle(event: event)
            return
        }
        if engine.state != snapshot {
            snapshot = engine.state
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
    var selectedFocusMinutes: Int { snapshot.selectedFocusMinutes }
    var recommendedBreakMinutes: Int { engine.recommendedBreak.minutes }
    var recommendedBreakPhase: Phase { engine.recommendedBreak.phase }
    var completedFocusCount: Int { snapshot.completedFocusCount }

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

    var dialHandProgress: Double {
        engine.minuteDialProgress(at: now)
    }

    var endsAtText: String? {
        guard let endDate = snapshot.endDate else { return nil }
        return endDate.formatted(date: .omitted, time: .shortened)
    }

    var phaseLabel: String {
        return switch snapshot.phase {
        case .focus: "FOCUS"
        case .shortBreak: "SHORT BREAK"
        case .longBreak: "LONG BREAK"
        }
    }

    var intervalCaption: String {
        let minutes = Int(snapshot.totalSeconds / 60)
        return switch snapshot.phase {
        case .focus: "\(minutes)-MINUTE INTERVAL"
        case .shortBreak: "\(minutes)-MINUTE BREAK"
        case .longBreak: "\(minutes)-MINUTE BREAK"
        }
    }

    var readoutCaption: String {
        return switch snapshot.runState {
        case .idle: "READY"
        case .running: "REMAINING"
        case .paused: "PAUSED"
        case .completed: "COMPLETE"
        }
    }

    var notificationStatusText: String {
        return switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            "Notifications are on"
        case .denied:
            "Notifications are off"
        case .notDetermined:
            "Notifications not requested yet"
        @unknown default:
            "Notification status unknown"
        }
    }

    var menuBarDescriptor: MenuBarDescriptor {
        let active = snapshot.runState == .running || snapshot.runState == .paused
        let completed = snapshot.runState == .completed
        let remainingMinutes = active ? max(1, Int(ceil(remainingSeconds / 60))) : 0
        let title: String
        if active && showMenuBarMinutes {
            title = "\(remainingMinutes)m"
        } else {
            title = ""
        }
        let progress: Double
        if completed {
            progress = 1
        } else if active {
            progress = Self.menuBarProgress(engine.progress(at: now))
        } else {
            progress = 0
        }
        return MenuBarDescriptor(
            title: title,
            isActive: active,
            isPaused: snapshot.runState == .paused,
            isCompleted: completed,
            isBreak: snapshot.phase.isBreak,
            remainingMinutes: remainingMinutes,
            progress: progress
        )
    }

    // MARK: - Actions

    func selectFocusMinutes(_ minutes: Int) {
        engine.selectFocusMinutes(minutes)
        snapshot = engine.state
        save()
    }

    func startFocus(minutes: Int? = nil) {
        guard let endDate = engine.startFocus(minutes: minutes) else { return }
        snapshot = engine.state
        now = Date()
        lastTickSecond = nil
        lastTickDate = nil
        save()
        updateMenuBar(force: true)
        announce("Focus started")
        scheduleNotification(endDate: endDate, phase: .focus)
    }

    func takeBreak() {
        guard let endDate = engine.startRecommendedBreak() else { return }
        snapshot = engine.state
        now = Date()
        lastTickSecond = nil
        save()
        updateMenuBar(force: true)
        announce("Break started")
        scheduleNotification(endDate: endDate, phase: snapshot.phase)
    }

    func startAnother() {
        guard let endDate = engine.startAnother() else { return }
        snapshot = engine.state
        now = Date()
        lastTickSecond = nil
        lastTickDate = nil
        save()
        updateMenuBar(force: true)
        announce("Focus started")
        scheduleNotification(endDate: endDate, phase: .focus)
    }

    func togglePause() {
        if engine.state.runState == .running {
            if let event = engine.pause() {
                handle(event: event)
                return
            }
            snapshot = engine.state
            now = Date()
            lastTickSecond = nil
            notifications.cancel()
            save()
            updateMenuBar(force: true)
            announce("Focus paused")
        } else if engine.state.runState == .paused {
            guard let endDate = engine.resume() else { return }
            snapshot = engine.state
            now = Date()
            lastTickSecond = engine.displaySeconds(at: now)
            lastTickDate = now
            save()
            updateMenuBar(force: true)
            announce("Focus resumed")
            scheduleNotification(endDate: endDate, phase: snapshot.phase)
        }
    }

    func endInterval() {
        engine.endEarly()
        snapshot = engine.state
        now = Date()
        notifications.cancel()
        save()
        updateMenuBar(force: true)
        announce("Interval ended")
    }

    func skipBreak() {
        engine.skipBreak()
        finishToIdle()
        announce("Break skipped")
    }

    func doneForNow() {
        engine.doneForNow()
        finishToIdle()
    }

    private func finishToIdle() {
        snapshot = engine.state
        now = Date()
        notifications.cancel()
        save()
        updateMenuBar(force: true)
    }

    func dismissFirstRunTip() {
        firstRunTipDismissed = true
        isFirstRun = false
        save()
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

    func setThemePreference(_ preference: ThemePreference) {
        guard themePreference != preference else { return }
        themePreference = preference
        save()
        onAppearanceChange?(preference)
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
        errorMessage = nil
    }

    // MARK: - Private

    private func handle(event: TimerEvent) {
        snapshot = engine.state
        now = Date()
        lastTickSecond = nil
        lastTickDate = nil
        notifications.cancel()
        updateMenuBar(force: true)
        save()

        switch event {
        case .completed(let phase):
            if chimeEnabled {
                sounds.playChime()
            }
            if phase == .focus {
                announce("Focus complete. \(recommendedBreakMinutes)-minute break available.")
            } else {
                announce("Break complete.")
            }
        }
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
        let persisted = PersistedState(
            timer: engine.state,
            chimeEnabled: chimeEnabled,
            tickEnabled: tickEnabled,
            showMenuBarMinutes: showMenuBarMinutes,
            themePreference: themePreference,
            firstRunTipDismissed: firstRunTipDismissed
        )
        do {
            try store.save(persisted)
        } catch {
            errorMessage = "Timer state couldn’t be saved to disk."
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
