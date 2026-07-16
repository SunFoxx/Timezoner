import XCTest

@testable import TimezonerCore

final class TimeOfDayTests: XCTestCase {
    func testParsesAndFormatsTwentyFourHourTime() {
        XCTAssertEqual(TimeOfDay(text: "00:00"), TimeOfDay(hour: 0, minute: 0))
        XCTAssertEqual(TimeOfDay(text: "23:59"), TimeOfDay(hour: 23, minute: 59))
        XCTAssertEqual(TimeOfDay(hour: 7, minute: 5)?.formatted, "07:05")
    }

    func testRejectsInvalidOrAmbiguousInput() {
        XCTAssertNil(TimeOfDay(text: "24:00"))
        XCTAssertNil(TimeOfDay(text: "9:30"))
        XCTAssertNil(TimeOfDay(text: "09.30"))
        XCTAssertNil(TimeOfDay(text: ""))
    }

    func testSliderSnappingRoundsAndClampsToFiveMinuteGrid() {
        XCTAssertEqual(TimeOfDay(hour: 12, minute: 2)?.snappedToFiveMinutes, TimeOfDay(hour: 12, minute: 0))
        XCTAssertEqual(TimeOfDay(hour: 12, minute: 3)?.snappedToFiveMinutes, TimeOfDay(hour: 12, minute: 5))
        XCTAssertEqual(TimeOfDay(hour: 23, minute: 59)?.snappedToFiveMinutes, TimeOfDay(hour: 23, minute: 55))
    }
}
