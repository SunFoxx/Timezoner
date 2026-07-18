import XCTest

@testable import TimezonerCore

@MainActor
final class TimezonerStateTests: XCTestCase {
    private let utc = TestSupport.timeZone("UTC")

    func testStartsAtNearestFiveMinuteCurrentTimeWithOneDisabledTargetRow() {
        let now = TestSupport.date(2026, 1, 15, 14, 2, in: utc)
        let store = InMemoryTimezoneRowsStore()
        let state = TimezonerState(now: now, localTimeZone: utc, rowsStore: store)

        XCTAssertEqual(state.selection.start, TestSupport.date(2026, 1, 15, 14, 0, in: utc))
        XCTAssertNil(state.selection.end)
        XCTAssertEqual(state.rows.count, 1)
        XCTAssertNil(state.rows[0].timeZoneIdentifier)
    }

    func testSelectingAddingAndRemovingRowsPersistsComposition() {
        let store = InMemoryTimezoneRowsStore()
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: store
        )
        let firstID = state.rows[0].id

        state.selectTimeZone("America/New_York", for: firstID)
        let secondID = state.addRow()
        state.selectTimeZone("GMT+0900", for: secondID)

        XCTAssertEqual(store.rows?.map(\.timeZoneIdentifier), ["America/New_York", "GMT+0900"])

        state.removeRow(id: firstID)
        XCTAssertEqual(state.rows.map(\.timeZoneIdentifier), ["GMT+0900"])
        XCTAssertEqual(store.rows?.map(\.timeZoneIdentifier), ["GMT+0900"])
    }

    func testRenamingARowPersistsAndSurvivesTimezoneChanges() {
        let store = InMemoryTimezoneRowsStore()
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: store
        )
        let rowID = state.rows[0].id

        XCTAssertTrue(state.renameRow("West Coast team", for: rowID))
        XCTAssertTrue(state.selectTimeZone("America/Los_Angeles", for: rowID))

        XCTAssertEqual(state.rows[0].name, "West Coast team")
        XCTAssertEqual(store.rows?[0].name, "West Coast team")
        XCTAssertEqual(store.rows?[0].timeZoneIdentifier, "America/Los_Angeles")

        let restoredState = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 13, 0, in: utc),
            localTimeZone: utc,
            rowsStore: store
        )
        XCTAssertEqual(restoredState.rows[0].name, "West Coast team")
        XCTAssertEqual(restoredState.rows[0].timeZoneIdentifier, "America/Los_Angeles")
    }

    func testRenamingAnUnknownRowDoesNotMutatePersistence() {
        let store = InMemoryTimezoneRowsStore()
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: store
        )

        XCTAssertFalse(state.renameRow("Missing", for: UUID()))
        XCTAssertNil(store.rows)
    }

    func testDuplicateComparisonTimezonesAreRejectedAndSanitized() {
        let store = InMemoryTimezoneRowsStore(rows: [
            TimezoneRow(timeZoneIdentifier: "GMT+0530"),
            TimezoneRow(timeZoneIdentifier: "GMT+0530")
        ])
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: store
        )

        XCTAssertEqual(state.rows.map(\.timeZoneIdentifier), ["GMT+0530"])
        XCTAssertEqual(store.rows?.map(\.timeZoneIdentifier), ["GMT+0530"])

        let secondID = state.addRow()
        XCTAssertFalse(state.selectTimeZone("GMT+0530", for: secondID))
        XCTAssertNil(state.rows.last?.timeZoneIdentifier)
    }

    func testLoadsValidRowsAndDisablesUnavailableTimezones() {
        let store = InMemoryTimezoneRowsStore(rows: [
            TimezoneRow(name: "Tokyo office", timeZoneIdentifier: "Asia/Tokyo"),
            TimezoneRow(name: "Former office", timeZoneIdentifier: "Invalid/Removed")
        ])
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: store
        )

        XCTAssertEqual(state.rows.map(\.timeZoneIdentifier), ["GMT+0900", nil])
        XCTAssertEqual(state.rows.map(\.name), ["Tokyo office", "Former office"])
    }

    func testEditingAnyConfiguredRowUpdatesCanonicalSelection() {
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: InMemoryTimezoneRowsStore()
        )
        let newYork = TestSupport.timeZone("America/New_York")

        state.setStart(TimeOfDay(hour: 8, minute: 0)!, viewedIn: newYork)

        XCTAssertEqual(state.selection.start, TestSupport.date(2026, 1, 15, 13, 0, in: utc))
    }

    func testClearingEndFromAnyRowDisablesRangeGlobally() {
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: InMemoryTimezoneRowsStore()
        )

        state.enableRange()
        XCTAssertEqual(state.selection.duration, 60 * 60)

        state.clearEnd()
        XCTAssertNil(state.selection.end)
    }

    func testMenuLifecycleResamplesNowAndPreservesActiveDuration() {
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 9, 0, in: utc),
            localTimeZone: utc,
            rowsStore: InMemoryTimezoneRowsStore()
        )
        state.enableRange()
        state.setEnd(TimeOfDay(hour: 11, minute: 30)!, viewedIn: utc)

        state.menuDidClose(at: TestSupport.date(2026, 1, 15, 14, 2, in: utc))
        XCTAssertEqual(state.selection.start, TestSupport.date(2026, 1, 15, 14, 0, in: utc))
        XCTAssertEqual(state.selection.end, TestSupport.date(2026, 1, 15, 16, 30, in: utc))

        state.menuDidOpen(at: TestSupport.date(2026, 1, 15, 17, 4, in: utc))
        XCTAssertEqual(state.selection.start, TestSupport.date(2026, 1, 15, 17, 5, in: utc))
        XCTAssertEqual(state.selection.end, TestSupport.date(2026, 1, 15, 19, 35, in: utc))
    }

    func testMenuLifecycleRefreshesCatalogAcrossSeasonalOffsetChanges() {
        let winter = TestSupport.date(2026, 1, 15, 12, 0, in: utc)
        let summer = TestSupport.date(2026, 7, 15, 12, 0, in: utc)
        let state = TimezonerState(
            now: winter,
            localTimeZone: utc,
            rowsStore: InMemoryTimezoneRowsStore()
        )

        let winterPacific = state.catalog.options.first { option in
            option.identifier == "America/Los_Angeles"
        }
        XCTAssertEqual(winterPacific?.offsetText, "UTC−08:00")

        state.menuDidOpen(at: summer)

        let summerPacific = state.catalog.options.first { option in
            option.identifier == "America/Los_Angeles"
        }
        let fixedPacificOffset = state.catalog.options.first { option in
            option.title == "UTC−07:00"
        }
        XCTAssertEqual(summerPacific?.offsetText, "UTC−07:00")
        XCTAssertNotNil(fixedPacificOffset)
        XCTAssertNotEqual(summerPacific?.identifier, fixedPacificOffset?.identifier)
    }

    func testSeasonalCatalogRefreshPreservesConfiguredFixedOffset() {
        let summer = TestSupport.date(2026, 7, 15, 12, 0, in: utc)
        let winter = TestSupport.date(2026, 1, 15, 12, 0, in: utc)
        let store = InMemoryTimezoneRowsStore(rows: [
            TimezoneRow(timeZoneIdentifier: "GMT-0800")
        ])
        let state = TimezonerState(now: summer, localTimeZone: utc, rowsStore: store)

        XCTAssertEqual(state.rows[0].timeZoneIdentifier, "GMT-0800")

        state.menuDidOpen(at: winter)

        XCTAssertEqual(state.rows[0].timeZoneIdentifier, "GMT-0800")
        XCTAssertEqual(store.rows?[0].timeZoneIdentifier, "GMT-0800")
        XCTAssertTrue(
            state.catalog.options.contains { option in
                option.identifier == state.rows[0].timeZoneIdentifier
            })
    }

    func testEditingAcrossDSTRefreshesCatalogWithoutChangingFixedRows() {
        let beforeTransition = TestSupport.date(2026, 3, 8, 6, 30, in: utc)
        let store = InMemoryTimezoneRowsStore(rows: [
            TimezoneRow(timeZoneIdentifier: "GMT-0400")
        ])
        let state = TimezonerState(now: beforeTransition, localTimeZone: utc, rowsStore: store)

        XCTAssertEqual(state.rows[0].timeZoneIdentifier, "GMT-0400")

        state.setStart(TimeOfDay(hour: 7, minute: 30)!, viewedIn: utc)

        XCTAssertEqual(state.rows[0].timeZoneIdentifier, "GMT-0400")
        XCTAssertEqual(store.rows?[0].timeZoneIdentifier, "GMT-0400")
        XCTAssertEqual(
            state.catalog.options.first { option in option.identifier == "America/New_York" }?.offsetText,
            "UTC−04:00"
        )
    }

    func testCatalogUsesRoundedCanonicalStartAtOffsetTransition() {
        let justBeforeTransition = TestSupport.date(2026, 3, 8, 6, 58, in: utc)
        let state = TimezonerState(
            now: justBeforeTransition,
            localTimeZone: utc,
            rowsStore: InMemoryTimezoneRowsStore()
        )

        XCTAssertEqual(state.selection.start, TestSupport.date(2026, 3, 8, 7, 0, in: utc))
        XCTAssertEqual(
            state.catalog.options.first { option in option.identifier == "America/New_York" }?.offsetText,
            "UTC−04:00"
        )
    }

    func testLoadFailureRepairsStorageAndSurfacesTheRecovery() {
        let store = InMemoryTimezoneRowsStore(loadFailure: .decodingFailed)

        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: store
        )

        XCTAssertEqual(state.rows.count, 1)
        XCTAssertNil(state.rows[0].timeZoneIdentifier)
        XCTAssertEqual(store.rows, state.rows)
        XCTAssertEqual(state.persistenceFailure, .decodingFailed)
    }

    func testSaveFailureIsSurfacedAndClearsAfterASuccessfulRetry() {
        let store = InMemoryTimezoneRowsStore(saveFailure: .encodingFailed)
        let state = TimezonerState(
            now: TestSupport.date(2026, 1, 15, 12, 0, in: utc),
            localTimeZone: utc,
            rowsStore: store
        )
        let rowID = state.rows[0].id

        state.selectTimeZone("America/New_York", for: rowID)
        XCTAssertEqual(state.persistenceFailure, .encodingFailed)

        store.saveFailure = nil
        state.selectTimeZone("America/Los_Angeles", for: rowID)
        XCTAssertNil(state.persistenceFailure)
        XCTAssertEqual(store.rows?[0].timeZoneIdentifier, "America/Los_Angeles")
    }
}

private final class InMemoryTimezoneRowsStore: TimezoneRowsStoring {
    var rows: [TimezoneRow]?
    var loadFailure: TimezoneRowsStoreFailure?
    var saveFailure: TimezoneRowsStoreFailure?

    init(
        rows: [TimezoneRow]? = nil,
        loadFailure: TimezoneRowsStoreFailure? = nil,
        saveFailure: TimezoneRowsStoreFailure? = nil
    ) {
        self.rows = rows
        self.loadFailure = loadFailure
        self.saveFailure = saveFailure
    }

    func load() -> Result<[TimezoneRow]?, TimezoneRowsStoreFailure> {
        if let loadFailure {
            return .failure(loadFailure)
        }
        return .success(rows)
    }

    func save(_ rows: [TimezoneRow]) -> Result<Void, TimezoneRowsStoreFailure> {
        if let saveFailure {
            return .failure(saveFailure)
        }
        self.rows = rows
        return .success(())
    }
}
