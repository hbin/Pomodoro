import Foundation

/// The user's preferred length for each interval. An active interval keeps the
/// duration captured in `TimerState`; these values apply when the next interval
/// is started.
public struct IntervalDurations: Codable, Sendable, Equatable {
    public static let allowedMinutes = 1...180

    public static let defaults = IntervalDurations()

    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int

    public init(
        focusMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15
    ) {
        self.focusMinutes = Self.clamped(focusMinutes)
        self.shortBreakMinutes = Self.clamped(shortBreakMinutes)
        self.longBreakMinutes = Self.clamped(longBreakMinutes)
    }

    public func minutes(for phase: Phase) -> Int {
        switch phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
    }

    public mutating func setMinutes(_ minutes: Int, for phase: Phase) {
        switch phase {
        case .focus: focusMinutes = Self.clamped(minutes)
        case .shortBreak: shortBreakMinutes = Self.clamped(minutes)
        case .longBreak: longBreakMinutes = Self.clamped(minutes)
        }
    }

    private static func clamped(_ minutes: Int) -> Int {
        min(max(minutes, allowedMinutes.lowerBound), allowedMinutes.upperBound)
    }

    private enum CodingKeys: String, CodingKey {
        case focusMinutes
        case shortBreakMinutes
        case longBreakMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = IntervalDurations.defaults
        focusMinutes = Self.clamped(
            try container.decodeIfPresent(Int.self, forKey: .focusMinutes)
                ?? defaults.focusMinutes
        )
        shortBreakMinutes = Self.clamped(
            try container.decodeIfPresent(Int.self, forKey: .shortBreakMinutes)
                ?? defaults.shortBreakMinutes
        )
        longBreakMinutes = Self.clamped(
            try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes)
                ?? defaults.longBreakMinutes
        )
    }
}
