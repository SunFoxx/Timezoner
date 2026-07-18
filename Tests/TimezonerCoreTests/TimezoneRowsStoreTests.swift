import XCTest

@testable import TimezonerCore

final class TimezoneRowsStoreTests: XCTestCase {
    func testRoundTripsRowsInOrder() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = UserDefaultsTimezoneRowsStore(defaults: defaults)
        let rows = [
            TimezoneRow(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "New York team",
                timeZoneIdentifier: "America/New_York"
            ),
            TimezoneRow(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Tokyo office",
                timeZoneIdentifier: "Asia/Tokyo"
            )
        ]

        guard case .success = store.save(rows) else {
            return XCTFail("Expected rows to save")
        }
        XCTAssertEqual(store.load(), .success(rows))
    }

    func testLoadsLegacyRowsThatHaveNoNameField() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let legacyJSON = """
            [{
              "id": "00000000-0000-0000-0000-000000000001",
              "timeZoneIdentifier": "America/New_York"
            }]
            """
        defaults.set(Data(legacyJSON.utf8), forKey: UserDefaultsTimezoneRowsStore.storageKey)
        let store = UserDefaultsTimezoneRowsStore(defaults: defaults)

        guard case .success(let rows) = store.load() else {
            return XCTFail("Expected a legacy row to decode")
        }
        XCTAssertEqual(rows?.count, 1)
        XCTAssertNil(rows?.first?.name)
        XCTAssertEqual(rows?.first?.timeZoneIdentifier, "America/New_York")
    }

    func testCorruptPersistenceReturnsFailureInsteadOfThrowing() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(Data("not-json".utf8), forKey: UserDefaultsTimezoneRowsStore.storageKey)
        let store = UserDefaultsTimezoneRowsStore(defaults: defaults)

        guard case .failure = store.load() else {
            return XCTFail("Expected corrupt persisted rows to fail")
        }
    }
}
