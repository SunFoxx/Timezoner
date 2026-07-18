import Foundation

public struct TimezoneOption: Equatable, Identifiable, Sendable {
    public let identifier: String
    public let title: String
    public let offsetText: String
    public let abbreviation: String?

    private let normalizedSearchTerms: [String]
    private let compactSearchTerms: [String]

    init(
        identifier: String,
        title: String,
        offsetText: String,
        abbreviation: String?,
        searchTerms: [String]
    ) {
        self.identifier = identifier
        self.title = title
        self.offsetText = offsetText
        self.abbreviation = abbreviation

        let seasonalSuffix = abbreviation.map { value in " · \(value)" } ?? ""
        let label =
            title == offsetText
            ? "\(offsetText) • \(offsetText.replacingOccurrences(of: "UTC", with: "GMT"))"
            : "\(title) · \(offsetText)\(seasonalSuffix)"
        let rawTerms = [identifier, label] + searchTerms
        self.normalizedSearchTerms = Array(
            Set(rawTerms.map(SearchText.normalized).filter { term in !term.isEmpty })
        ).sorted()
        self.compactSearchTerms = Array(
            Set(
                rawTerms.compactMap { term in
                    guard !term.contains("/") else {
                        return nil
                    }
                    let compactTerm = SearchText.compact(SearchText.normalized(term))
                    return compactTerm.isEmpty ? nil : compactTerm
                }
            )
        ).sorted()
    }

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
        let normalizedQuery = SearchText.normalized(searchQuery)
        return matches(
            normalizedQuery: normalizedQuery,
            compactQuery: SearchText.compact(normalizedQuery)
        )
    }

    fileprivate func matches(normalizedQuery: String, compactQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else {
            return true
        }
        if normalizedSearchTerms.contains(where: { term in term.contains(normalizedQuery) }) {
            return true
        }
        return !compactQuery.isEmpty && compactSearchTerms.contains(where: { term in term.contains(compactQuery) })
    }
}

public struct TimezoneCatalog: Sendable {
    public let options: [TimezoneOption]

    private let referenceDate: Date
    private let normalizedIdentifierBySource: [String: String]
    private let sourceOffsets: [String: Int]

    public init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate

        let sourceIdentifiers = Self.sourceIdentifiers
        var aliasesBySource: [String: [String]] = [:]
        for identifier in sourceIdentifiers {
            aliasesBySource[identifier] = Self.identifierAliases(identifier)
        }
        for (abbreviation, identifier) in TimeZone.abbreviationDictionary {
            aliasesBySource[identifier, default: []].append(abbreviation)
        }
        for entry in CapitalCityIndex.entries {
            aliasesBySource[entry.timeZoneIdentifier, default: []].append(contentsOf: entry.names)
        }

        var sourceOffsets: [String: Int] = [:]
        for identifier in sourceIdentifiers {
            guard let timeZone = TimeZone(identifier: identifier) else {
                continue
            }
            sourceOffsets[identifier] = timeZone.secondsFromGMT(for: referenceDate)
        }

        let fixedIdentifiersByOffset = Dictionary(
            uniqueKeysWithValues: Set(sourceOffsets.values).compactMap { seconds -> (Int, String)? in
                guard seconds != 0, let timeZone = TimeZone(secondsFromGMT: seconds) else {
                    return nil
                }
                return (seconds, timeZone.identifier)
            }
        )

        let commonIdentifiers = Set(Self.commonZones.map(\.identifier))
        var normalizedIdentifierBySource: [String: String] = [:]
        for identifier in sourceIdentifiers {
            guard let timeZone = TimeZone(identifier: identifier) else {
                continue
            }
            let offset = timeZone.secondsFromGMT(for: referenceDate)
            if commonIdentifiers.contains(identifier) {
                normalizedIdentifierBySource[identifier] = identifier
            } else if offset == 0 {
                normalizedIdentifierBySource[identifier] = "UTC"
            } else if let commonIdentifier = Self.seasonalCommonIdentifier(
                matching: timeZone,
                around: referenceDate
            ) {
                normalizedIdentifierBySource[identifier] = commonIdentifier
            } else {
                normalizedIdentifierBySource[identifier] = fixedIdentifiersByOffset[offset]
            }
        }

        var aliasesByVisibleIdentifier: [String: [String]] = [:]
        for identifier in sourceIdentifiers {
            guard let visibleIdentifier = normalizedIdentifierBySource[identifier] else {
                continue
            }
            aliasesByVisibleIdentifier[visibleIdentifier, default: []].append(
                contentsOf: aliasesBySource[identifier] ?? []
            )
        }

        let commonOptions = Self.commonZones.compactMap { zone -> TimezoneOption? in
            guard let timeZone = TimeZone(identifier: zone.identifier) else {
                return nil
            }
            let seconds = timeZone.secondsFromGMT(for: referenceDate)
            return TimezoneOption(
                identifier: zone.identifier,
                title: zone.title,
                offsetText: Self.offsetText(secondsFromGMT: seconds),
                abbreviation: zone.showsSeasonalAbbreviation ? timeZone.abbreviation(for: referenceDate) : nil,
                searchTerms: zone.aliases + Self.numericAliases(secondsFromGMT: seconds)
                    + (aliasesByVisibleIdentifier[zone.identifier] ?? [])
            )
        }

        let fixedOptions = fixedIdentifiersByOffset.keys.sorted().compactMap { seconds -> TimezoneOption? in
            guard let identifier = fixedIdentifiersByOffset[seconds] else {
                return nil
            }
            let offsetText = Self.offsetText(secondsFromGMT: seconds)
            return TimezoneOption(
                identifier: identifier,
                title: offsetText,
                offsetText: offsetText,
                abbreviation: nil,
                searchTerms: Self.numericAliases(secondsFromGMT: seconds)
                    + (aliasesByVisibleIdentifier[identifier] ?? [])
            )
        }

        self.options = commonOptions + fixedOptions
        self.normalizedIdentifierBySource = normalizedIdentifierBySource
        self.sourceOffsets = sourceOffsets
    }

    public func options(matching searchQuery: String) -> [TimezoneOption] {
        let normalizedQuery = SearchText.normalized(searchQuery)
        guard !normalizedQuery.isEmpty else {
            return options
        }
        let compactQuery = SearchText.compact(normalizedQuery)
        return options.filter { option in
            option.matches(normalizedQuery: normalizedQuery, compactQuery: compactQuery)
        }
    }

    public func normalizedIdentifier(_ identifier: String) -> String? {
        if let exactOption = options.first(where: { option in option.identifier == identifier }) {
            return exactOption.identifier
        }
        if let normalizedIdentifier = normalizedIdentifierBySource[identifier] {
            return normalizedIdentifier
        }
        guard let timeZone = TimeZone(identifier: identifier) else {
            return nil
        }
        let offset = timeZone.secondsFromGMT(for: referenceDate)
        if offset == 0 {
            return "UTC"
        }
        if let commonIdentifier = Self.seasonalCommonIdentifier(matching: timeZone, around: referenceDate) {
            return commonIdentifier
        }
        return options.first { option in
            option.title == option.offsetText
                && TimeZone(identifier: option.identifier)?.secondsFromGMT(for: referenceDate) == offset
        }?.identifier
    }

    public func hasSameSearchOffsets(at date: Date) -> Bool {
        return sourceOffsets.allSatisfy { identifier, referenceOffset in
            guard let timeZone = TimeZone(identifier: identifier) else {
                return false
            }
            return timeZone.secondsFromGMT(for: date) == referenceOffset
        }
    }

    public static func offsetText(secondsFromGMT: Int) -> String {
        let sign = secondsFromGMT < 0 ? "−" : "+"
        let absoluteSeconds = abs(secondsFromGMT)
        let hours = absoluteSeconds / 3_600
        let minutes = (absoluteSeconds % 3_600) / 60
        return String(format: "UTC%@%02d:%02d", sign, hours, minutes)
    }

    private static var sourceIdentifiers: [String] {
        return Set(
            TimeZone.knownTimeZoneIdentifiers
                + Array(TimeZone.abbreviationDictionary.values)
                + CapitalCityIndex.entries.map(\.timeZoneIdentifier)
        )
        .filter { identifier in
            TimeZone(identifier: identifier) != nil
        }
        .sorted()
    }

    private static func identifierAliases(_ identifier: String) -> [String] {
        guard !identifier.hasPrefix("Etc/GMT+"), !identifier.hasPrefix("Etc/GMT-") else {
            return []
        }
        let expandedIdentifier = identifier.replacingOccurrences(of: "_", with: " ")
        let components = expandedIdentifier.split(separator: "/").map(String.init)
        var aliases = [identifier]
        if let exemplarCity = components.last {
            aliases.append(exemplarCity)
        }
        return aliases
    }

    private static func seasonalCommonIdentifier(matching timeZone: TimeZone, around date: Date) -> String? {
        let matches = commonZones.filter { zone in
            guard zone.identifier != "UTC", let commonTimeZone = TimeZone(identifier: zone.identifier) else {
                return false
            }
            return hasSameRules(timeZone, commonTimeZone, around: date)
        }
        return matches.count == 1 ? matches[0].identifier : nil
    }

    private static func hasSameRules(_ first: TimeZone, _ second: TimeZone, around date: Date) -> Bool {
        let start = date.addingTimeInterval(-370 * 24 * 60 * 60)
        let end = date.addingTimeInterval(740 * 24 * 60 * 60)
        return ruleSignature(for: first, from: start, through: end)
            == ruleSignature(for: second, from: start, through: end)
    }

    private static func ruleSignature(for timeZone: TimeZone, from start: Date, through end: Date) -> RuleSignature {
        var transitions: [RuleTransition] = []
        var cursor = start
        while transitions.count < 12,
            let transition = timeZone.nextDaylightSavingTimeTransition(after: cursor),
            transition <= end
        {
            transitions.append(
                RuleTransition(
                    instant: Int64(transition.timeIntervalSinceReferenceDate.rounded()),
                    resultingOffset: timeZone.secondsFromGMT(for: transition.addingTimeInterval(1))
                )
            )
            cursor = transition.addingTimeInterval(1)
        }
        return RuleSignature(initialOffset: timeZone.secondsFromGMT(for: start), transitions: transitions)
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

private enum SearchText {
    static func normalized(_ text: String) -> String {
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

    static func compact(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = ""
        for (index, scalar) in scalars.enumerated() {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                continue
            }
            let isSign = scalar.value == 43 || scalar.value == 45
            let nextIsNumber =
                scalars.indices.contains(index + 1)
                && CharacterSet.decimalDigits.contains(scalars[index + 1])
            if isSign && nextIsNumber {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}

private struct CommonZone: Sendable {
    let identifier: String
    let title: String
    let aliases: [String]
    let showsSeasonalAbbreviation: Bool
}

private struct RuleSignature: Equatable {
    let initialOffset: Int
    let transitions: [RuleTransition]
}

private struct RuleTransition: Equatable {
    let instant: Int64
    let resultingOffset: Int
}
