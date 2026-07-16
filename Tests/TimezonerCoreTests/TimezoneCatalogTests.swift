import XCTest

@testable import TimezonerCore

final class TimezoneCatalogTests: XCTestCase {
    func testUsesCompactGenericZonesInsteadOfCountrySpecificOptions() {
        let catalog = TimezoneCatalog()
        let leadingTitles = Array(catalog.options.prefix(5).map(\.title))

        XCTAssertEqual(leadingTitles, ["UTC / GMT", "PT · Pacific Time", "MT · Mountain Time", "CT · Central Time", "ET · Eastern Time"])
        XCTAssertFalse(
            catalog.options.contains { option in
                option.title.contains("America") || option.title.contains("Europe") || option.title.contains("Asia")
            })
        XCTAssertLessThan(catalog.options.count, 45)
    }

    func testLabelsContainFriendlyIdentifierAndCurrentOffset() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let option = TimezoneCatalog(referenceDate: instant).options.first { option in
            option.identifier == "America/New_York"
        }

        XCTAssertEqual(option?.title, "ET · Eastern Time")
        XCTAssertEqual(option?.offsetText, "UTC−05:00")
    }

    func testFixedOffsetsIncludeFractionalZonesInNumericOrder() {
        let catalog = TimezoneCatalog()
        let fixedOffsets = Array(catalog.options.dropFirst(5))
        let seconds = fixedOffsets.compactMap { option in
            TimeZone(identifier: option.identifier)?.secondsFromGMT()
        }

        XCTAssertEqual(seconds, seconds.sorted())
        XCTAssertTrue(fixedOffsets.contains { option in option.title == "UTC+05:30" })
        XCTAssertTrue(fixedOffsets.contains { option in option.title == "UTC+05:45" })
    }

    func testEveryFixedOffsetAppearsOnlyOnceAndSeasonalRulesStayDistinct() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let catalog = TimezoneCatalog(referenceDate: instant)
        let fixedOptions = catalog.options.filter { option in option.title == option.offsetText }
        let fixedOffsets = fixedOptions.compactMap { option in
            TimeZone(identifier: option.identifier)?.secondsFromGMT(for: instant)
        }
        let pacific = catalog.options.first { option in option.identifier == "America/Los_Angeles" }
        let fixedPacificOffset = fixedOptions.first { option in option.offsetText == "UTC−08:00" }

        XCTAssertEqual(fixedOffsets.count, Set(fixedOffsets).count)
        XCTAssertNotNil(pacific)
        XCTAssertNotNil(fixedPacificOffset)
        XCTAssertNotEqual(pacific?.identifier, fixedPacificOffset?.identifier)
    }

    func testSearchMatchesMergedTextAndNumericAliases() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let catalog = TimezoneCatalog(referenceDate: instant)
        let pacific = catalog.options.first { option in option.title.hasPrefix("PT") }
        let indiaOffset = catalog.options.first { option in option.title == "UTC+05:30" }
        let zero = catalog.options.first

        XCTAssertTrue(pacific?.matches(searchQuery: "PT") == true)
        XCTAssertTrue(pacific?.matches(searchQuery: "pacific") == true)
        XCTAssertTrue(pacific?.matches(searchQuery: "-8") == true)
        XCTAssertTrue(pacific?.matches(searchQuery: "UTC-08") == true)
        XCTAssertTrue(indiaOffset?.matches(searchQuery: "5:30") == true)
        XCTAssertTrue(indiaOffset?.matches(searchQuery: "530") == true)
        XCTAssertTrue(indiaOffset?.matches(searchQuery: "Asia/Calcutta") == true)
        XCTAssertTrue(indiaOffset?.matches(searchQuery: "Calcutta") == true)
        XCTAssertTrue(zero?.matches(searchQuery: "GMT") == true)
        XCTAssertTrue(zero?.matches(searchQuery: "0") == true)
    }

    func testFixedOffsetPickerLabelsPairUTCAndGMTValues() {
        let catalog = TimezoneCatalog()
        let positive = catalog.options.first { option in option.title == "UTC+05:30" }
        let negative = catalog.options.first { option in option.title == "UTC−09:30" }

        XCTAssertEqual(positive?.pickerLabel, "UTC+05:30 • GMT+05:30")
        XCTAssertEqual(negative?.pickerLabel, "UTC−09:30 • GMT−09:30")
    }
}
