import Foundation

public enum TimezoneRowsStoreFailure: Error, Equatable, Sendable {
    case decodingFailed
    case encodingFailed
}

public protocol TimezoneRowsStoring: AnyObject {
    func load() -> Result<[TimezoneRow]?, TimezoneRowsStoreFailure>
    func save(_ rows: [TimezoneRow]) -> Result<Void, TimezoneRowsStoreFailure>
}

public final class UserDefaultsTimezoneRowsStore: TimezoneRowsStoring {
    public static let storageKey = "selectedTimezoneRows"

    private let defaults: UserDefaults
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        defaults: UserDefaults = .standard,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.defaults = defaults
        self.decoder = decoder
        self.encoder = encoder
    }

    public func load() -> Result<[TimezoneRow]?, TimezoneRowsStoreFailure> {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .success(nil)
        }
        do {
            return .success(try decoder.decode([TimezoneRow].self, from: data))
        } catch {
            return .failure(.decodingFailed)
        }
    }

    public func save(_ rows: [TimezoneRow]) -> Result<Void, TimezoneRowsStoreFailure> {
        do {
            defaults.set(try encoder.encode(rows), forKey: Self.storageKey)
            return .success(())
        } catch {
            return .failure(.encodingFailed)
        }
    }
}
