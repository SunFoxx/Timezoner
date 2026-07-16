import Foundation

public struct TimezoneOption: Equatable, Identifiable, Sendable {
    public let identifier: String
    public let title: String
    public let offsetText: String
    public let abbreviation: String?
    let searchTerms: String

    public var id: String {
        return identifier
    }

    public var pickerLabel: String {
        if title == offsetText {
            let gmtText = offsetText.replacingOccurrences(of: "UTC", with: "GMT")
            return "\(offsetText) • \(gmtText)"
        }
        let seasonalSuffix = abbreviation.map { value in " · \(value)" } ?? ""
        return "\(title) · \(offsetText)\(seasonalSuffix)"
    }

    public func matches(searchQuery: String) -> Bool {
        let normalizedQuery = Self.normalized(searchQuery)
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let normalizedTerms = Self.normalized(
            "\(identifier) \(pickerLabel) \(searchTerms)"
        )
        if normalizedTerms.contains(normalizedQuery) {
            return true
        }

        let compactQuery = Self.compact(normalizedQuery)
        return !compactQuery.isEmpty && Self.compact(normalizedTerms).contains(compactQuery)
    }

    private static func normalized(_ text: String) -> String {
        return
            text
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "＋", with: "+")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func compact(_ text: String) -> String {
        return String(
            text.unicodeScalars.filter { scalar in
                CharacterSet.alphanumerics.contains(scalar) || scalar.value == 43 || scalar.value == 45
            })
    }
}

public struct TimezoneCatalog: Sendable {
    public let options: [TimezoneOption]
    private let referenceDate: Date

    public init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
        let commonIdentifiers = Set(Self.commonZones.map(\.identifier))
        var mergedAliasesByOffset: [Int: [String]] = [:]
        for identifier in TimeZone.knownTimeZoneIdentifiers.sorted() where !commonIdentifiers.contains(identifier) {
            guard let timeZone = TimeZone(identifier: identifier) else {
                continue
            }
            let seconds = timeZone.secondsFromGMT(for: referenceDate)
            mergedAliasesByOffset[seconds, default: []].append(identifier)
            mergedAliasesByOffset[seconds, default: []].append(
                identifier
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "/", with: " ")
            )
        }

        var commonOptions: [TimezoneOption] = []
        for zone in Self.commonZones {
            guard let timeZone = TimeZone(identifier: zone.identifier) else {
                continue
            }
            let seconds = timeZone.secondsFromGMT(for: referenceDate)
            let mergedAliases = zone.identifier == "UTC" ? (mergedAliasesByOffset[seconds] ?? []) : []
            commonOptions.append(
                TimezoneOption(
                    identifier: zone.identifier,
                    title: zone.title,
                    offsetText: Self.offsetText(secondsFromGMT: seconds),
                    abbreviation: zone.showsSeasonalAbbreviation ? timeZone.abbreviation(for: referenceDate) : nil,
                    searchTerms: (zone.aliases + Self.numericAliases(secondsFromGMT: seconds) + mergedAliases).joined(
                        separator: " "
                    )
                )
            )
        }

        let knownOffsets = Set(mergedAliasesByOffset.keys)
        let fixedOptions: [TimezoneOption] =
            knownOffsets
            .filter { seconds in seconds != 0 }
            .sorted()
            .compactMap { seconds -> TimezoneOption? in
                guard let timeZone = TimeZone(secondsFromGMT: seconds) else {
                    return nil
                }
                let offsetText = Self.offsetText(secondsFromGMT: seconds)
                return TimezoneOption(
                    identifier: timeZone.identifier,
                    title: offsetText,
                    offsetText: offsetText,
                    abbreviation: nil,
                    searchTerms: (Self.numericAliases(secondsFromGMT: seconds) + (mergedAliasesByOffset[seconds] ?? []))
                        .joined(separator: " ")
                )
            }
        self.options = commonOptions + fixedOptions
    }

    public func normalizedIdentifier(_ identifier: String) -> String? {
        if let exactOption = options.first(where: { option in option.identifier == identifier }) {
            return exactOption.identifier
        }
        guard let timeZone = TimeZone(identifier: identifier) else {
            return nil
        }
        let offset = timeZone.secondsFromGMT(for: referenceDate)
        return options.first { option in
            option.title == option.offsetText
                && TimeZone(identifier: option.identifier)?.secondsFromGMT(for: referenceDate) == offset
        }?.identifier
            ?? options.first { option in
                TimeZone(identifier: option.identifier)?.secondsFromGMT(for: referenceDate) == offset
            }?.identifier
    }

    public func hasSameCommonOffsets(at date: Date) -> Bool {
        return Self.commonZones.allSatisfy { zone in
            guard
                let timeZone = TimeZone(identifier: zone.identifier),
                let option = options.first(where: { option in option.identifier == zone.identifier })
            else {
                return false
            }
            return option.offsetText == Self.offsetText(secondsFromGMT: timeZone.secondsFromGMT(for: date))
        }
    }

    public static func offsetText(secondsFromGMT: Int) -> String {
        let sign = secondsFromGMT < 0 ? "−" : "+"
        let absoluteSeconds = abs(secondsFromGMT)
        let hours = absoluteSeconds / 3_600
        let minutes = (absoluteSeconds % 3_600) / 60
        return String(format: "UTC%@%02d:%02d", sign, hours, minutes)
    }

    private static func numericAliases(secondsFromGMT: Int) -> [String] {
        let sign = secondsFromGMT < 0 ? "-" : "+"
        let absoluteSeconds = abs(secondsFromGMT)
        let hours = absoluteSeconds / 3_600
        let minutes = (absoluteSeconds % 3_600) / 60
        let paddedHours = String(format: "%02d", hours)
        let paddedMinutes = String(format: "%02d", minutes)
        let signedHour = "\(sign)\(hours)"
        let signedPaddedHour = "\(sign)\(paddedHours)"
        let signedClock = "\(signedHour):\(paddedMinutes)"
        let signedCompact = "\(signedHour)\(paddedMinutes)"
        let unsignedClock = "\(hours):\(paddedMinutes)"
        let unsignedCompact = "\(hours)\(paddedMinutes)"

        return [
            signedHour,
            signedPaddedHour,
            signedClock,
            signedCompact,
            unsignedClock,
            unsignedCompact,
            "UTC\(signedHour)",
            "UTC\(signedPaddedHour)",
            "GMT\(signedHour)",
            "GMT\(signedPaddedHour)"
        ]
    }

    private static let commonZones: [CommonZone] = [
        CommonZone(
            identifier: "UTC",
            title: "UTC / GMT",
            aliases: ["UTC", "GMT", "Z", "Zulu", "zero", "0"],
            showsSeasonalAbbreviation: false
        ),
        CommonZone(
            identifier: "America/Los_Angeles",
            title: "PT · Pacific Time",
            aliases: ["PT", "PST", "PDT", "Pacific", "Pacific Time"],
            showsSeasonalAbbreviation: true
        ),
        CommonZone(
            identifier: "America/Denver",
            title: "MT · Mountain Time",
            aliases: ["MT", "MST", "MDT", "Mountain", "Mountain Time"],
            showsSeasonalAbbreviation: true
        ),
        CommonZone(
            identifier: "America/Chicago",
            title: "CT · Central Time",
            aliases: ["CT", "CST", "CDT", "Central", "Central Time"],
            showsSeasonalAbbreviation: true
        ),
        CommonZone(
            identifier: "America/New_York",
            title: "ET · Eastern Time",
            aliases: ["ET", "EST", "EDT", "Eastern", "Eastern Time"],
            showsSeasonalAbbreviation: true
        )
    ]
}

private struct CommonZone: Sendable {
    let identifier: String
    let title: String
    let aliases: [String]
    let showsSeasonalAbbreviation: Bool
}
