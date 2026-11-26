import Foundation

public struct PersistedState: Codable, Sendable, Equatable {
    public var timer: TimerState
    public var durations: IntervalDurations
    public var chimeEnabled: Bool
    public var tickEnabled: Bool
    public var showMenuBarMinutes: Bool
    public var autoStartBreak: Bool
    public var autoStartFocus: Bool
    public var themePreference: ThemePreference
    public var firstRunTipDismissed: Bool

    public init(
        timer: TimerState = .initial,
        durations: IntervalDurations = .defaults,
        chimeEnabled: Bool = true,
        tickEnabled: Bool = false,
        showMenuBarMinutes: Bool = true,
        autoStartBreak: Bool = false,
        autoStartFocus: Bool = false,
        themePreference: ThemePreference = .system,
        firstRunTipDismissed: Bool = false
    ) {
        self.timer = timer
        self.durations = durations
        self.chimeEnabled = chimeEnabled
        self.tickEnabled = tickEnabled
        self.showMenuBarMinutes = showMenuBarMinutes
        self.autoStartBreak = autoStartBreak
        self.autoStartFocus = autoStartFocus
        self.themePreference = themePreference
        self.firstRunTipDismissed = firstRunTipDismissed
    }

    private enum CodingKeys: String, CodingKey {
        case timer
        case durations
        case chimeEnabled
        case tickEnabled
        case showMenuBarMinutes
        case autoStartBreak
        case autoStartFocus
        case themePreference
        case firstRunTipDismissed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PersistedState()
        timer = try container.decodeIfPresent(TimerState.self, forKey: .timer) ?? defaults.timer
        durations = try container.decodeIfPresent(IntervalDurations.self, forKey: .durations) ?? defaults.durations
        chimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .chimeEnabled) ?? defaults.chimeEnabled
        tickEnabled = try container.decodeIfPresent(Bool.self, forKey: .tickEnabled) ?? defaults.tickEnabled
        showMenuBarMinutes = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarMinutes) ?? defaults.showMenuBarMinutes
        autoStartBreak = try container.decodeIfPresent(Bool.self, forKey: .autoStartBreak) ?? defaults.autoStartBreak
        autoStartFocus = try container.decodeIfPresent(Bool.self, forKey: .autoStartFocus) ?? defaults.autoStartFocus
        themePreference = try container.decodeIfPresent(ThemePreference.self, forKey: .themePreference) ?? defaults.themePreference
        firstRunTipDismissed = try container.decodeIfPresent(Bool.self, forKey: .firstRunTipDismissed) ?? defaults.firstRunTipDismissed
    }
}

extension PersistedState {
    /// A next-interval Ready screen is session presentation, not restorable
    /// timer state. Persist idle as Focus Ready while retaining the focus-cycle
    /// position used to choose the following short or long break.
    func readyStateNormalizedForPersistence() -> PersistedState {
        guard timer.runState == .idle else { return self }

        var normalized = self
        normalized.timer.phase = .focus
        normalized.timer.selectedFocusMinutes = durations.focusMinutes
        normalized.timer.totalSeconds = TimeInterval(durations.focusMinutes * 60)
        normalized.timer.remainingSeconds = normalized.timer.totalSeconds
        normalized.timer.endDate = nil
        return normalized
    }
}
