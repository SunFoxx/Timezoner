import Foundation

enum TestSupport {
    static func timeZone(_ identifier: String) -> TimeZone {
        guard let timeZone = TimeZone(identifier: identifier) else {
            preconditionFailure("Missing test timezone: \(identifier)")
        }
        return timeZone
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        in timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: 0
        )
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Invalid test date: \(components)")
        }
        return date
    }
}
