import Foundation

public struct TimeOfDay: Codable, Comparable, Hashable, Sendable {
    public static let minutesPerDay = 24 * 60
    public static let sliderStepMinutes = 5

    public let minutesSinceMidnight: Int

    public init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else {
            return nil
        }
        self.minutesSinceMidnight = (hour * 60) + minute
    }

    public init?(minutesSinceMidnight: Int) {
        guard (0..<Self.minutesPerDay).contains(minutesSinceMidnight) else {
            return nil
        }
        self.minutesSinceMidnight = minutesSinceMidnight
    }

    public init?(text: String) {
        let characters = Array(text)
        guard characters.count == 5, characters[2] == ":" else {
            return nil
        }
        guard
            let hour = Int(String(characters[0...1])),
            let minute = Int(String(characters[3...4]))
        else {
            return nil
        }
        self.init(hour: hour, minute: minute)
    }

    public var hour: Int {
        return minutesSinceMidnight / 60
    }

    public var minute: Int {
        return minutesSinceMidnight % 60
    }

    public var formatted: String {
        return String(format: "%02d:%02d", hour, minute)
    }

    public var snappedToFiveMinutes: TimeOfDay {
        let rounded = Int((Double(minutesSinceMidnight) / Double(Self.sliderStepMinutes)).rounded())
        let clamped = min(rounded * Self.sliderStepMinutes, Self.minutesPerDay - Self.sliderStepMinutes)
        guard let value = TimeOfDay(minutesSinceMidnight: clamped) else {
            preconditionFailure("A clamped time must be inside one day")
        }
        return value
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        return lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}
