public enum Phase: String, Codable, Sendable, Equatable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    public var isBreak: Bool {
        self != .focus
    }
}
