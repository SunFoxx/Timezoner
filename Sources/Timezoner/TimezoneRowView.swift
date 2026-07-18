import SwiftUI
import TimezonerCore

struct TimezoneRowView: View {
    @ObservedObject var state: TimezonerState
    @ObservedObject private var deviceTimeZone: DeviceTimeZone

    let deviceClock: DeviceClock
    let row: TimezoneRow?
    let catalog: TimezoneCatalog
    let isLocal: Bool

    init(
        state: TimezonerState,
        deviceClock: DeviceClock,
        row: TimezoneRow?,
        catalog: TimezoneCatalog,
        isLocal: Bool
    ) {
        self.state = state
        self.deviceClock = deviceClock
        self.row = row
        self.catalog = catalog
        self.isLocal = isLocal
        _deviceTimeZone = ObservedObject(wrappedValue: deviceClock.timeZone)
    }

    private var timeZone: TimeZone? {
        if isLocal {
            return deviceTimeZone.current
        }
        guard let identifier = row?.timeZoneIdentifier else {
            return nil
        }
        return TimeZone(identifier: identifier)
    }

    private var isConfigured: Bool {
        return timeZone != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TimezonerTheme.rowSpacing) {
            HStack(alignment: .top, spacing: 12) {
                timezoneControl
                    .frame(width: TimezonerTheme.zoneColumnWidth, alignment: .leading)
                Spacer(minLength: 4)
                timeControls
                    .frame(width: TimezonerTheme.timeControlsWidth, alignment: .leading)
                rowAction
            }

            if let timeZone {
                TimeRangeSlider(
                    start: state.timeOfDay(for: state.selection.start, in: timeZone),
                    end: state.selection.end.map { end in state.timeOfDay(for: end, in: timeZone) },
                    crossesMidnight: rangeCrossesMidnight(in: timeZone),
                    isEnabled: true,
                    deviceClock: deviceClock,
                    timeZone: timeZone,
                    timezoneName: friendlyName(for: timeZone),
                    onStartChange: { time in
                        state.setStart(time, viewedIn: timeZone)
                    },
                    onEndChange: { time in
                        state.setEnd(time, viewedIn: timeZone)
                    }
                )
                HStack(spacing: 8) {
                    Label(rangeSummary(in: timeZone), systemImage: state.selection.end == nil ? "scope" : "arrow.left.and.right")
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .frame(width: TimezonerTheme.rangeSummaryWidth, alignment: .leading)
                    Spacer()
                    Text("All rows represent the same moment")
                        .lineLimit(1)
                        .frame(width: TimezonerTheme.synchronizationLabelWidth, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                TimeRangeSlider(
                    start: state.timeOfDay(for: state.selection.start, in: state.localTimeZone),
                    end: state.selection.end.map { end in state.timeOfDay(for: end, in: state.localTimeZone) },
                    crossesMidnight: false,
                    isEnabled: false,
                    deviceClock: deviceClock,
                    timeZone: nil,
                    timezoneName: "Unselected timezone",
                    onStartChange: { _ in },
                    onEndChange: { _ in }
                )
                Label("Choose a timezone to compare", systemImage: "arrow.up.left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(TimezonerTheme.rowPadding)
        .frame(height: TimezonerTheme.rowHeight, alignment: .topLeading)
        .background(
            isLocal ? TimezonerTheme.localBackground : (isConfigured ? TimezonerTheme.rowBackground : TimezonerTheme.disabledBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: TimezonerTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TimezonerTheme.cornerRadius, style: .continuous)
                .stroke(isLocal ? TimezonerTheme.accent.opacity(0.22) : Color.primary.opacity(0.06), lineWidth: 1)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private var rowAction: some View {
        if !isLocal, let row {
            Button {
                state.removeRow(id: row.id)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .frame(width: TimezonerTheme.rowActionWidth, height: TimezonerTheme.rowActionWidth)
            .contentShape(Rectangle())
            .help("Remove timezone row")
            .accessibilityLabel(removeRowAccessibilityLabel(for: row))
        } else {
            Color.clear
                .frame(width: TimezonerTheme.rowActionWidth, height: TimezonerTheme.rowActionWidth)
                .accessibilityHidden(true)
        }
    }

    func removeRowAccessibilityLabel(for row: TimezoneRow) -> String {
        guard let name = row.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return String(localized: "Remove timezone row")
        }
        return String(format: String(localized: "Remove %@ timezone row"), name)
    }

    @ViewBuilder
    private var timezoneControl: some View {
        if isLocal, let timeZone {
            VStack(alignment: .leading, spacing: 4) {
                Label("Local time", systemImage: "location.fill")
                    .font(.headline)
                    .foregroundStyle(TimezonerTheme.accent)
                Text(friendlyName(for: timeZone))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(timezoneMetadata(for: timeZone))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .help(timeZone.identifier)
        } else if let row {
            VStack(alignment: .leading, spacing: 5) {
                TextField(
                    "Row name",
                    text: rowNameBinding(for: row)
                )
                .textFieldStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(height: TimezonerTheme.rowNameFieldHeight, alignment: .leading)
                .accessibilityLabel("Row name")
                .accessibilityIdentifier("Row name \(row.id.uuidString)")
                TimezonePicker(
                    catalog: catalog,
                    selection: Binding(
                        get: {
                            row.timeZoneIdentifier
                        },
                        set: { identifier in
                            guard let identifier else {
                                return
                            }
                            state.selectTimeZone(identifier, for: row.id)
                        }
                    )
                )
                .frame(height: 24)
            }
        }
    }

    func rowNameBinding(for row: TimezoneRow) -> Binding<String> {
        return Binding(
            get: {
                return state.rows.first(where: { candidate in candidate.id == row.id })?.name ?? ""
            },
            set: { name in
                state.renameRow(name, for: row.id)
            }
        )
    }

    @ViewBuilder
    private var timeControls: some View {
        if let timeZone {
            let startTime = state.timeOfDay(for: state.selection.start, in: timeZone)
            HStack(alignment: .top, spacing: 8) {
                endpointControl(
                    title: "Start",
                    time: startTime,
                    instant: state.selection.start,
                    timeZone: timeZone,
                    onCommit: { time in
                        state.setStart(time, viewedIn: timeZone)
                    }
                )
                Text("→")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 23)
                if let end = state.selection.end {
                    endpointControl(
                        title: "End",
                        time: state.timeOfDay(for: end, in: timeZone),
                        instant: end,
                        timeZone: timeZone,
                        onCommit: { time in
                            state.setEnd(time, viewedIn: timeZone)
                        },
                        canClear: true
                    )
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("End")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(height: TimezonerTheme.endpointHeaderHeight, alignment: .leading)
                        Button("+ End") {
                            state.enableRange()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(
                            width: 76,
                            height: TimezonerTheme.timeFieldHeight,
                            alignment: .leading
                        )
                        .accessibilityIdentifier("Add end time")
                        .accessibilityLabel("Add end time")
                        Text("Optional")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: TimezonerTheme.endpointColumnWidth, alignment: .leading)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                disabledEndpoint(title: "Start")
                Text("→")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 23)
                disabledEndpoint(title: "End")
            }
        }
    }

    private func endpointControl(
        title: String,
        time: TimeOfDay,
        instant: Date,
        timeZone: TimeZone,
        onCommit: @escaping (TimeOfDay) -> Void,
        canClear: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if canClear {
                    Button {
                        state.clearEnd()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .frame(width: TimezonerTheme.inlineActionSize, height: TimezonerTheme.inlineActionSize)
                    .contentShape(Rectangle())
                    .help("Clear end time and switch to single time")
                    .accessibilityLabel("Clear end time and switch to single time")
                }
            }
            .frame(height: TimezonerTheme.endpointHeaderHeight, alignment: .leading)
            TimeInputField(
                value: time,
                accessibilityName: "\(friendlyName(for: timeZone)) \(title.lowercased()) time",
                isEnabled: true,
                onCommit: onCommit
            )
            Text(dayLabel(for: instant, in: timeZone))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(dayOffset(for: instant, in: timeZone) == 0 ? .secondary : TimezonerTheme.accent)
                .lineLimit(1)
                .frame(width: TimezonerTheme.endpointColumnWidth, alignment: .leading)
        }
        .frame(width: TimezonerTheme.endpointColumnWidth, alignment: .leading)
    }

    private func disabledEndpoint(title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(height: TimezonerTheme.endpointHeaderHeight, alignment: .leading)
            Text("--:--")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: TimezonerTheme.timeFieldWidth, height: TimezonerTheme.timeFieldHeight)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: TimezonerTheme.controlCornerRadius))
            Text("—")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: TimezonerTheme.endpointColumnWidth, alignment: .leading)
    }

    private func friendlyName(for timeZone: TimeZone) -> String {
        return timeZone.identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " / ")
    }

    private func timezoneMetadata(for timeZone: TimeZone) -> String {
        let abbreviation = timeZone.abbreviation(for: state.selection.start) ?? timeZone.identifier
        let offset = TimezoneCatalog.offsetText(secondsFromGMT: timeZone.secondsFromGMT(for: state.selection.start))
        return "\(abbreviation) · \(offset) · fixed"
    }

    private func dayLabel(for instant: Date, in timeZone: TimeZone) -> String {
        let formatter = Date.FormatStyle(locale: .current, timeZone: timeZone)
            .weekday(.abbreviated)
            .month(.abbreviated)
            .day(.defaultDigits)
        let offset = dayOffset(for: instant, in: timeZone)
        if offset == 0 {
            return instant.formatted(formatter)
        }
        let sign = offset > 0 ? "+" : "−"
        return "\(instant.formatted(formatter)) · \(sign)\(abs(offset))d"
    }

    private func dayOffset(for instant: Date, in timeZone: TimeZone) -> Int {
        return state.dayOffset(of: instant, in: timeZone)
    }

    private func rangeCrossesMidnight(in timeZone: TimeZone) -> Bool {
        guard let end = state.selection.end else {
            return false
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startDay = calendar.startOfDay(for: state.selection.start)
        let endDay = calendar.startOfDay(for: end)
        return endDay > startDay
    }

    private func rangeSummary(in timeZone: TimeZone) -> String {
        guard let duration = state.selection.duration else {
            return String(localized: "Single time")
        }
        let totalMinutes = max(Int(duration.rounded() / 60), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let durationText: String
        if hours > 0, minutes > 0 {
            durationText = "\(hours)h \(minutes)m"
        } else if hours > 0 {
            durationText = "\(hours)h"
        } else {
            durationText = "\(minutes)m"
        }
        return rangeCrossesMidnight(in: timeZone) ? "\(durationText) range · Overnight" : "\(durationText) range"
    }
}
