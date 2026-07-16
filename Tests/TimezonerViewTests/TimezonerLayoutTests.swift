import XCTest

@testable import Timezoner
@testable import TimezonerCore

final class TimezonerLayoutTests: XCTestCase {
    func testComparisonScrollViewportFitsExactlyTwoRowsWithoutExposingAThird() {
        let expectedScrollableHeight =
            (TimezonerTheme.rowHeight * CGFloat(TimezonerTheme.visibleComparisonRowCount))
            + TimezonerTheme.comparisonRowSpacing
        let expectedSectionHeight =
            expectedScrollableHeight + (TimezonerTheme.comparisonVerticalPadding * 2)

        XCTAssertEqual(TimezonerTheme.visibleComparisonRowCount, 2)
        XCTAssertEqual(TimezonerTheme.comparisonScrollableHeight, expectedScrollableHeight)
        XCTAssertEqual(TimezonerTheme.comparisonViewportHeight, expectedSectionHeight)
    }

    func testPopoverHeightAccountsForPinnedLocalAndFixedComparisonSections() {
        let expectedHeight =
            TimezonerTheme.headerHeight
            + TimezonerTheme.dividerThickness
            + TimezonerTheme.pinnedLocalSectionHeight
            + TimezonerTheme.comparisonViewportHeight
            + TimezonerTheme.dividerThickness
            + TimezonerTheme.footerHeight

        XCTAssertEqual(TimezonerTheme.popoverHeight, expectedHeight)
    }

    func testCurrentTimeMarkerProjectsTheDeviceInstantIntoEachRowTimezone() {
        let instant = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
        let metrics = SliderMetrics(width: 500)
        let utc = TimeZone(secondsFromGMT: 0)!
        let plusFiveThirty = TimeZone(secondsFromGMT: (5 * 60 * 60) + (30 * 60))!

        let utcProjection = CurrentTimeMarkerProjection(instant: instant, timeZone: utc)
        let offsetProjection = CurrentTimeMarkerProjection(instant: instant, timeZone: plusFiveThirty)

        XCTAssertEqual(utcProjection.time, TimeOfDay(hour: 12, minute: 0))
        XCTAssertEqual(offsetProjection.time, TimeOfDay(hour: 17, minute: 30))
        XCTAssertEqual(utcProjection.x(in: metrics), metrics.x(for: TimeOfDay(hour: 12, minute: 0)!))
        XCTAssertEqual(offsetProjection.x(in: metrics), metrics.x(for: TimeOfDay(hour: 17, minute: 30)!))
    }

    func testCurrentTimeMarkerHoverTextUsesTheProjectedRowTime() {
        let instant = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
        let plusFiveThirty = TimeZone(secondsFromGMT: (5 * 60 * 60) + (30 * 60))!

        let projection = CurrentTimeMarkerProjection(instant: instant, timeZone: plusFiveThirty)

        XCTAssertEqual(projection.hoverText, "17:30")
    }

    func testCurrentTimeMarkerHoverRegionUsesSliderCoordinates() {
        let instant = ISO8601DateFormatter().date(from: "2026-01-15T17:15:00Z")!
        let utc = TimeZone(secondsFromGMT: 0)!
        let projection = CurrentTimeMarkerProjection(instant: instant, timeZone: utc)
        let metrics = SliderMetrics(width: 500)
        let markerCenter = CGPoint(x: projection.x(in: metrics), y: metrics.trackY)

        XCTAssertTrue(projection.isHovered(at: markerCenter, in: metrics))
        XCTAssertFalse(
            projection.isHovered(
                at: CGPoint(
                    x: markerCenter.x + TimezonerTheme.currentTimeHoverTargetWidth,
                    y: markerCenter.y
                ),
                in: metrics
            )
        )
    }

    func testCurrentTimeMarkerMovesWhenTheDeviceClockChanges() {
        let formatter = ISO8601DateFormatter()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let metrics = SliderMetrics(width: 500)
        let first = CurrentTimeMarkerProjection(
            instant: formatter.date(from: "2026-01-15T12:00:00Z")!,
            timeZone: timeZone
        )
        let second = CurrentTimeMarkerProjection(
            instant: formatter.date(from: "2026-01-15T12:01:00Z")!,
            timeZone: timeZone
        )

        XCTAssertEqual(first.time, TimeOfDay(hour: 12, minute: 0))
        XCTAssertEqual(second.time, TimeOfDay(hour: 12, minute: 1))
        XCTAssertNotEqual(first.x(in: metrics), second.x(in: metrics))
    }
}
