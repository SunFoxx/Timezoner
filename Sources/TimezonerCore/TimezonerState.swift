import Combine
import Foundation

@MainActor
public final class TimezonerState: ObservableObject {
    @Published public private(set) var selection: TimeRangeSelection
    @Published public private(set) var rows: [TimezoneRow]
    @Published public private(set) var catalog: TimezoneCatalog
    @Published public private(set) var persistenceFailure: TimezoneRowsStoreFailure?

    public let localTimeZone: TimeZone

    private let engine: TimezoneConversionEngine
    private let rowsStore: TimezoneRowsStoring

    public init(
        now: Date = Date(),
        localTimeZone: TimeZone = .autoupdatingCurrent,
        rowsStore: TimezoneRowsStoring = UserDefaultsTimezoneRowsStore(),
        engine: TimezoneConversionEngine = TimezoneConversionEngine()
    ) {
        self.localTimeZone = localTimeZone
        self.rowsStore = rowsStore
        self.engine = engine
        let start = engine.roundedToNearestFiveMinutes(now)
        let initialCatalog = TimezoneCatalog(referenceDate: start)
        self.selection = TimeRangeSelection(start: start)
        self.catalog = initialCatalog

        switch rowsStore.load() {
        case .success(let savedRows):
            let sanitizedRows = Self.sanitizedRows(savedRows, catalog: initialCatalog)
            self.rows = sanitizedRows
            if let savedRows, savedRows != sanitizedRows {
                switch rowsStore.save(sanitizedRows) {
                case .success:
                    self.persistenceFailure = nil
                case .failure(let failure):
                    self.persistenceFailure = failure
                }
            } else {
                self.persistenceFailure = nil
            }
        case .failure(let failure):
            let fallbackRows = [TimezoneRow()]
            self.rows = fallbackRows
            switch rowsStore.save(fallbackRows) {
            case .success:
                self.persistenceFailure = failure
            case .failure(let repairFailure):
                self.persistenceFailure = repairFailure
            }
        }
    }

    @discardableResult
    public func addRow() -> UUID {
        let row = TimezoneRow()
        rows.append(row)
        persistRows()
        return row.id
    }

    public func removeRow(id: UUID) {
        rows.removeAll { row in
            row.id == id
        }
        persistRows()
    }

    @discardableResult
    public func renameRow(_ name: String, for rowID: UUID) -> Bool {
        guard let index = rows.firstIndex(where: { row in row.id == rowID }) else {
            return false
        }
        let persistedName = name.isEmpty ? nil : name
        guard rows[index].name != persistedName else {
            return true
        }
        rows[index] = rows[index].renaming(persistedName)
        persistRows()
        return true
    }

    @discardableResult
    public func selectTimeZone(_ identifier: String, for rowID: UUID) -> Bool {
        guard catalog.options.contains(where: { option in option.identifier == identifier }) else {
            return false
        }
        guard
            !rows.contains(where: { row in
                row.id != rowID && row.timeZoneIdentifier == identifier
            })
        else {
            return false
        }
        guard let index = rows.firstIndex(where: { row in row.id == rowID }) else {
            return false
        }
        rows[index] = rows[index].selecting(identifier)
        persistRows()
        return true
    }

    public func setStart(_ time: TimeOfDay, viewedIn timeZone: TimeZone) {
        let updatedSelection = engine.replacingStart(in: selection, with: time, viewedIn: timeZone)
        guard updatedSelection != selection else {
            return
        }
        selection = updatedSelection
        refreshCatalog(at: updatedSelection.start, force: false)
    }

    public func setEnd(_ time: TimeOfDay, viewedIn timeZone: TimeZone) {
        let updatedSelection = engine.replacingEnd(in: selection, with: time, viewedIn: timeZone)
        guard updatedSelection != selection else {
            return
        }
        selection = updatedSelection
    }

    public func enableRange() {
        guard selection.end == nil else {
            return
        }
        selection = TimeRangeSelection(start: selection.start, end: selection.start.addingTimeInterval(60 * 60))
    }

    public func clearEnd() {
        selection = TimeRangeSelection(start: selection.start)
    }

    public func menuDidOpen(at now: Date = Date()) {
        resetToNow(now)
    }

    public func menuDidClose(at now: Date = Date()) {
        resetToNow(now)
    }

    public func timeOfDay(for instant: Date, in timeZone: TimeZone) -> TimeOfDay {
        return engine.timeOfDay(for: instant, in: timeZone)
    }

    public func dayOffset(of instant: Date, in timeZone: TimeZone) -> Int {
        return engine.dayOffset(
            of: instant,
            in: timeZone,
            relativeTo: selection.start,
            in: localTimeZone
        )
    }

    private func resetToNow(_ now: Date) {
        let duration = selection.duration
        let start = engine.roundedToNearestFiveMinutes(now)
        let end = duration.map { duration in
            start.addingTimeInterval(duration)
        }
        selection = TimeRangeSelection(start: start, end: end)
        refreshCatalog(at: start, force: true)
    }

    private func persistRows() {
        switch rowsStore.save(rows) {
        case .success:
            persistenceFailure = nil
        case .failure(let failure):
            persistenceFailure = failure
        }
    }

    private func refreshCatalog(at referenceDate: Date, force: Bool) {
        guard force || !catalog.hasSameSearchOffsets(at: referenceDate) else {
            return
        }
        let refreshedCatalog = TimezoneCatalog(referenceDate: referenceDate)
        guard refreshedCatalog.options != catalog.options else {
            return
        }
        let normalizedRows = Self.sanitizedRows(rows, catalog: refreshedCatalog)
        catalog = refreshedCatalog
        guard normalizedRows != rows else {
            return
        }
        rows = normalizedRows
        persistRows()
    }

    private static func sanitizedRows(_ savedRows: [TimezoneRow]?, catalog: TimezoneCatalog) -> [TimezoneRow] {
        guard let savedRows, !savedRows.isEmpty else {
            return [TimezoneRow()]
        }
        var configuredIdentifiers = Set<String>()
        return savedRows.compactMap { row in
            guard let identifier = row.timeZoneIdentifier else {
                return row
            }
            guard let normalizedIdentifier = catalog.normalizedIdentifier(identifier) else {
                return row.selecting(nil)
            }
            guard configuredIdentifiers.insert(normalizedIdentifier).inserted else {
                return nil
            }
            return row.selecting(normalizedIdentifier)
        }
    }
}
