import Foundation

final class TestClock: @unchecked Sendable {
    var date: Date

    init(_ date: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        self.date = date
    }

    func advance(_ seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}
