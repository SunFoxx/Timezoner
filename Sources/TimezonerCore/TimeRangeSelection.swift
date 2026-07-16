import Foundation

public struct TimeRangeSelection: Equatable, Sendable {
    public let start: Date
    public let end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval? {
        guard let end else {
            return nil
        }
        return end.timeIntervalSince(start)
    }
}
