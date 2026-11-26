public enum RunState: String, Codable, Sendable, Equatable {
    case idle
    case running
    case paused
    case completed
}
