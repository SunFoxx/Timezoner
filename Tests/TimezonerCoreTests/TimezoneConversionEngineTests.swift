import XCTest

@testable import TimezonerCore

final class TimezoneConversionEngineTests: XCTestCase {
    private let engine = TimezoneConversionEngine()
    private let utc = TestSupport.timeZone("UTC")
    private let newYork = TestSupport.timeZone("America/New_York")

    func testProjectsOneInstantIntoEveryTimezone() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: utc)

        XCTAssertEqual(engine.timeOfDay(for: instant, in: utc), TimeOfDay(hour: 12, minute: 0))
        XCTAssertEqual(engine.timeOfDay(for: instant, in: newYork), TimeOfDay(hour: 7, minute: 0))
    }

    func testEndBeforeStartMeansFollowingLocalDay() {
        let start = TestSupport.date(2026, 1, 15, 23, 0, in: utc)
        let selection = TimeRangeSelection(start: start)

        let updated = engine.replacingEnd(
            in: selection,
            with: TimeOfDay(hour: 1, minute: 0)!,
            viewedIn: utc
        )

        XCTAssertEqual(updated.end, TestSupport.date(2026, 1, 16, 1, 0, in: utc))
        XCTAssertEqual(updated.duration, 2 * 60 * 60)
    }

    func testEqualEndAndStartIsAZeroLengthRange() {
        let start = TestSupport.date(2026, 1, 15, 9, 0, in: utc)
        let selection = TimeRangeSelection(start: start)

        let updated = engine.replacingEnd(
            in: selection,
            with: TimeOfDay(hour: 9, minute: 0)!,
            viewedIn: utc
        )

        XCTAssertEqual(updated.end, start)
        XCTAssertEqual(updated.duration, 0)
    }

    func testEditingComparisonRowChangesTheCanonicalInstant() {
        let start = TestSupport.date(2026, 1, 15, 12, 0, in: utc)
        let selection = TimeRangeSelection(start: start)

        let updated = engine.replacingStart(
            in: selection,
            with: TimeOfDay(hour: 8, minute: 0)!,
            viewedIn: newYork
        )

        XCTAssertEqual(updated.start, TestSupport.date(2026, 1, 15, 13, 0, in: utc))
        XCTAssertEqual(engine.timeOfDay(for: updated.start, in: newYork), TimeOfDay(hour: 8, minute: 0))
    }

    func testChangingStartReevaluatesWhetherEndCrossesMidnight() {
        let start = TestSupport.date(2026, 1, 15, 10, 0, in: utc)
        let end = TestSupport.date(2026, 1, 15, 12, 0, in: utc)
        let selection = TimeRangeSelection(start: start, end: end)

        let updated = engine.replacingStart(
            in: selection,
            with: TimeOfDay(hour: 13, minute: 0)!,
            viewedIn: utc
        )

        XCTAssertEqual(updated.start, TestSupport.date(2026, 1, 15, 13, 0, in: utc))
        XCTAssertEqual(updated.end, TestSupport.date(2026, 1, 16, 12, 0, in: utc))
    }

    func testNonexistentDSTTimeAdvancesPreservingMinutes() {
        let start = TestSupport.date(2026, 3, 8, 1, 0, in: newYork)
        let selection = TimeRangeSelection(start: start)

        let updated = engine.replacingStart(
            in: selection,
            with: TimeOfDay(hour: 2, minute: 30)!,
            viewedIn: newYork
        )

        XCTAssertEqual(engine.timeOfDay(for: updated.start, in: newYork), TimeOfDay(hour: 3, minute: 30))
    }

    func testRepeatedDSTTimeChoosesFirstOccurrence() {
        let start = TestSupport.date(2026, 11, 1, 0, 30, in: newYork)
        let selection = TimeRangeSelection(start: start)

        let updated = engine.replacingStart(
            in: selection,
            with: TimeOfDay(hour: 1, minute: 30)!,
            viewedIn: newYork
        )

        XCTAssertEqual(newYork.secondsFromGMT(for: updated.start), -4 * 60 * 60)
    }

    func testEndDuringRepeatedHourNeverPrecedesSecondOccurrenceStart() {
        let secondOccurrenceStart = TestSupport.date(2026, 11, 1, 6, 30, in: utc)
        let selection = TimeRangeSelection(start: secondOccurrenceStart)

        let equalEnd = engine.replacingEnd(
            in: selection,
            with: TimeOfDay(hour: 1, minute: 30)!,
            viewedIn: newYork
        )
        let laterEnd = engine.replacingEnd(
            in: selection,
            with: TimeOfDay(hour: 1, minute: 45)!,
            viewedIn: newYork
        )

        XCTAssertEqual(equalEnd.end, secondOccurrenceStart)
        XCTAssertEqual(equalEnd.duration, 0)
        XCTAssertEqual(laterEnd.end, TestSupport.date(2026, 11, 1, 6, 45, in: utc))
        XCTAssertEqual(laterEnd.duration, 15 * 60)
    }

    func testReportsDayOffsetsForConvertedTimes() {
        let reference = TestSupport.date(2026, 1, 15, 1, 0, in: utc)
        let losAngeles = TestSupport.timeZone("America/Los_Angeles")
        let tokyo = TestSupport.timeZone("Asia/Tokyo")

        XCTAssertEqual(engine.dayOffset(of: reference, in: losAngeles, relativeTo: reference, in: utc), -1)
        XCTAssertEqual(engine.dayOffset(of: reference, in: tokyo, relativeTo: reference, in: utc), 0)
    }

    func testFractionalHourTimezoneProjectionPreservesMinutes() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: utc)
        let kathmandu = TestSupport.timeZone("Asia/Kathmandu")

        XCTAssertEqual(engine.timeOfDay(for: instant, in: kathmandu), TimeOfDay(hour: 17, minute: 45))
    }

    func testRangeProjectsEachEndpointAcrossDSTWithItsOwnOffset() {
        let london = TestSupport.timeZone("Europe/London")
        let start = TestSupport.date(2026, 3, 29, 0, 30, in: utc)
        let end = TestSupport.date(2026, 3, 29, 2, 30, in: utc)

        XCTAssertEqual(engine.timeOfDay(for: start, in: london), TimeOfDay(hour: 0, minute: 30))
        XCTAssertEqual(engine.timeOfDay(for: end, in: london), TimeOfDay(hour: 3, minute: 30))
    }
}
