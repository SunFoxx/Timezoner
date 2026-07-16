import XCTest

@testable import TimezonerCore

final class TimezoneRowsStoreTests: XCTestCase {
    func testRoundTripsRowsInOrder() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = UserDefaultsTimezoneRowsStore(defaults: defaults)
        let rows = [
            TimezoneRow(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, timeZoneIdentifier: "America/New_York"),
            TimezoneRow(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, timeZoneIdentifier: "Asia/Tokyo")
        ]

        guard case .success = store.save(rows) else {
            return XCTFail("Expected rows to save")
        }
        XCTAssertEqual(store.load(), .success(rows))
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
