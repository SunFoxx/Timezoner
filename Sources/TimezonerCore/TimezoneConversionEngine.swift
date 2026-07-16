import Foundation

public struct TimezoneConversionEngine: Sendable {
    public init() {}

    public func timeOfDay(for instant: Date, in timeZone: TimeZone) -> TimeOfDay {
        let calendar = calendar(in: timeZone)
        let components = calendar.dateComponents([.hour, .minute], from: instant)
        guard
            let hour = components.hour,
            let minute = components.minute,
            let time = TimeOfDay(hour: hour, minute: minute)
        else {
            preconditionFailure("A calendar projection must produce a valid time")
        }
        return time
    }

    public func replacingStart(
        in selection: TimeRangeSelection,
        with requestedTime: TimeOfDay,
        viewedIn timeZone: TimeZone
    ) -> TimeRangeSelection {
        let newStart = instant(onLocalDayOf: selection.start, at: requestedTime, in: timeZone)
        guard let existingEnd = selection.end else {
            return TimeRangeSelection(start: newStart)
        }

        let actualStartTime = timeOfDay(for: newStart, in: timeZone)
        let endTime = timeOfDay(for: existingEnd, in: timeZone)
        let endReference = referenceDate(
            basedOn: newStart,
            addingDayWhen: endTime < actualStartTime,
            in: timeZone
        )
        let newEnd = endInstant(
            onLocalDayOf: endReference,
            at: endTime,
            in: timeZone,
            notBefore: newStart
        )
        return TimeRangeSelection(start: newStart, end: newEnd)
    }

    public func replacingEnd(
        in selection: TimeRangeSelection,
        with requestedTime: TimeOfDay,
        viewedIn timeZone: TimeZone
    ) -> TimeRangeSelection {
        let startTime = timeOfDay(for: selection.start, in: timeZone)
        let endReference = referenceDate(
            basedOn: selection.start,
            addingDayWhen: requestedTime < startTime,
            in: timeZone
        )
        let newEnd = endInstant(
            onLocalDayOf: endReference,
            at: requestedTime,
            in: timeZone,
            notBefore: selection.start
        )
        return TimeRangeSelection(start: selection.start, end: newEnd)
    }

    public func dayOffset(
        of instant: Date,
        in timeZone: TimeZone,
        relativeTo reference: Date,
        in referenceTimeZone: TimeZone
    ) -> Int {
        let instantComponents = calendar(in: timeZone).dateComponents([.year, .month, .day], from: instant)
        let referenceComponents = calendar(in: referenceTimeZone).dateComponents([.year, .month, .day], from: reference)
        let neutralCalendar = calendar(in: TimeZone(secondsFromGMT: 0) ?? referenceTimeZone)

        guard
            let instantDay = neutralCalendar.date(from: normalizedDay(instantComponents)),
            let referenceDay = neutralCalendar.date(from: normalizedDay(referenceComponents))
        else {
            return 0
        }
        return neutralCalendar.dateComponents([.day], from: referenceDay, to: instantDay).day ?? 0
    }

    public func roundedToNearestFiveMinutes(_ date: Date) -> Date {
        let step = TimeInterval(TimeOfDay.sliderStepMinutes * 60)
        let roundedInterval = (date.timeIntervalSinceReferenceDate / step).rounded() * step
        return Date(timeIntervalSinceReferenceDate: roundedInterval)
    }

    private func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func instant(
        onLocalDayOf reference: Date,
        at time: TimeOfDay,
        in timeZone: TimeZone,
        repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first
    ) -> Date {
        let calendar = calendar(in: timeZone)
        let startOfDay = calendar.startOfDay(for: reference)
        let searchStart = startOfDay.addingTimeInterval(-1)
        let components = DateComponents(hour: time.hour, minute: time.minute, second: 0)
        guard
            let instant = calendar.nextDate(
                after: searchStart,
                matching: components,
                matchingPolicy: .nextTimePreservingSmallerComponents,
                repeatedTimePolicy: repeatedTimePolicy,
                direction: .forward
            )
        else {
            preconditionFailure("Every local day must resolve a requested wall time")
        }
        return instant
    }

    private func endInstant(
        onLocalDayOf reference: Date,
        at time: TimeOfDay,
        in timeZone: TimeZone,
        notBefore start: Date
    ) -> Date {
        let firstOccurrence = instant(
            onLocalDayOf: reference,
            at: time,
            in: timeZone,
            repeatedTimePolicy: .first
        )
        if firstOccurrence >= start {
            return firstOccurrence
        }

        let lastOccurrence = instant(
            onLocalDayOf: reference,
            at: time,
            in: timeZone,
            repeatedTimePolicy: .last
        )
        if lastOccurrence >= start {
            return lastOccurrence
        }

        let nextDay = referenceDate(basedOn: reference, addingDayWhen: true, in: timeZone)
        return instant(onLocalDayOf: nextDay, at: time, in: timeZone)
    }

    private func referenceDate(basedOn start: Date, addingDayWhen shouldAddDay: Bool, in timeZone: TimeZone) -> Date {
        guard shouldAddDay else {
            return start
        }
        let calendar = calendar(in: timeZone)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: start) else {
            preconditionFailure("A Gregorian day must have a successor")
        }
        return nextDay
    }

    private func normalizedDay(_ components: DateComponents) -> DateComponents {
        return DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 12
        )
    }
}
