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

    func testSignedNumericSearchNeverReturnsTheOppositeOffset() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let catalog = TimezoneCatalog(referenceDate: instant)

        let positiveMatches = catalog.options(matching: "+8")
        let negativeMatches = catalog.options(matching: "UTC-08")
        let positiveGMTMatches = catalog.options(matching: "GMT+5")

        XCTAssertFalse(positiveMatches.isEmpty)
        XCTAssertTrue(positiveMatches.allSatisfy { option in option.offsetText.contains("+") })
        XCTAssertFalse(negativeMatches.isEmpty)
        XCTAssertTrue(negativeMatches.allSatisfy { option in option.offsetText.contains("−") })
        XCTAssertFalse(positiveGMTMatches.isEmpty)
        XCTAssertTrue(positiveGMTMatches.allSatisfy { option in option.offsetText.contains("+") })
    }

    func testCompactCitySearchDoesNotCrossIdentifierBoundaries() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let catalog = TimezoneCatalog(referenceDate: instant)

        XCTAssertEqual(catalog.options(matching: "Aden").map(\.title), ["UTC+03:00"])
        XCTAssertEqual(catalog.options(matching: "Port au Prince").count, 1)
    }

    func testSearchMatchesHiddenCountryCapitalAliasesWithoutChangingLabels() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let catalog = TimezoneCatalog(referenceDate: instant)
        let ottawaMatches = catalog.options(matching: "Ottawa")
        XCTAssertEqual(ottawaMatches.map(\.identifier), ["America/New_York"])
        let fixedExpectations = [
            (query: "Brasilia", title: "UTC−03:00"),
            (query: "Abuja", title: "UTC+01:00"),
            (query: "Canberra", title: "UTC+11:00"),
            (query: "New Delhi", title: "UTC+05:30")
        ]
        for expectation in fixedExpectations {
            let matches = catalog.options(matching: expectation.query)
            XCTAssertEqual(matches.map(\.title), [expectation.title])
            XCTAssertFalse(matches.first?.pickerLabel.localizedCaseInsensitiveContains(expectation.query) == true)
        }
    }

    func testSearchNormalizesLatinCitySpellingAndReturnsOneGenericOption() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let catalog = TimezoneCatalog(referenceDate: instant)

        let queries = ["Brasília", "Sao_Paulo", "sao paulo", "Buenos Aires", "Port au Prince"]
        for query in queries {
            let matches = catalog.options(matching: query)
            XCTAssertEqual(matches.count, 1, "Expected one generic option for \(query)")
            XCTAssertFalse(matches.first?.pickerLabel.localizedCaseInsensitiveContains(query) == true)
        }
    }

    func testSeasonalCityAliasesOnlyUseCommonOptionsWhenRulesMatch() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let catalog = TimezoneCatalog(referenceDate: instant)

        XCTAssertEqual(catalog.options(matching: "Vancouver").map(\.identifier), ["America/Los_Angeles"])
        XCTAssertEqual(catalog.options(matching: "Phoenix").map(\.title), ["UTC−07:00"])
    }

    func testCityAliasAssignmentsRefreshAcrossNonUSSeasonalChanges() {
        let utc = TestSupport.timeZone("UTC")
        let winter = TestSupport.date(2026, 1, 15, 12, 0, in: utc)
        let summer = TestSupport.date(2026, 7, 15, 12, 0, in: utc)
        let winterCatalog = TimezoneCatalog(referenceDate: winter)
        let summerCatalog = TimezoneCatalog(referenceDate: summer)

        XCTAssertEqual(winterCatalog.options(matching: "London").first?.identifier, "UTC")
        XCTAssertEqual(summerCatalog.options(matching: "London").first?.title, "UTC+01:00")
        XCTAssertFalse(winterCatalog.hasSameSearchOffsets(at: summer))
    }

    func testCapitalCityIndexCoversCountryAndTerritoryCapitals() {
        XCTAssertEqual(CapitalCityIndex.entries.count, 244)
        XCTAssertTrue(
            CapitalCityIndex.entries.allSatisfy { entry in
                !entry.names.isEmpty && TimeZone(identifier: entry.timeZoneIdentifier) != nil
            })
    }

    func testEveryCapitalAliasIsReachableThroughTheGenericCatalog() {
        let instant = TestSupport.date(2026, 1, 15, 12, 0, in: TestSupport.timeZone("UTC"))
        let catalog = TimezoneCatalog(referenceDate: instant)

        for entry in CapitalCityIndex.entries {
            for name in entry.names {
                XCTAssertFalse(catalog.options(matching: name).isEmpty, "Missing hidden capital alias: \(name)")
            }
        }
    }

    func testFixedOffsetPickerLabelsPairUTCAndGMTValues() {
        let catalog = TimezoneCatalog()
        let positive = catalog.options.first { option in option.title == "UTC+05:30" }
        let negative = catalog.options.first { option in option.title == "UTC−09:30" }

        XCTAssertEqual(positive?.pickerLabel, "UTC+05:30 • GMT+05:30")
        XCTAssertEqual(negative?.pickerLabel, "UTC−09:30 • GMT−09:30")
    }
}
