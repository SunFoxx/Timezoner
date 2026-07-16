import Foundation

public struct TimezoneRow: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let timeZoneIdentifier: String?

    public init(id: UUID = UUID(), timeZoneIdentifier: String? = nil) {
        self.id = id
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public func selecting(_ timeZoneIdentifier: String?) -> TimezoneRow {
        return TimezoneRow(id: id, timeZoneIdentifier: timeZoneIdentifier)
    }
}
