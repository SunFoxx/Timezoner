import Foundation

public struct TimezoneRow: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String?
    public let timeZoneIdentifier: String?

    public init(id: UUID = UUID(), name: String? = nil, timeZoneIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public func selecting(_ timeZoneIdentifier: String?) -> TimezoneRow {
        return TimezoneRow(id: id, name: name, timeZoneIdentifier: timeZoneIdentifier)
    }

    public func renaming(_ name: String?) -> TimezoneRow {
        return TimezoneRow(id: id, name: name, timeZoneIdentifier: timeZoneIdentifier)
    }
}
