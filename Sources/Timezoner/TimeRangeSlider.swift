import SwiftUI
import TimezonerCore

struct TimeRangeSlider: View {
    private static let coordinateSpaceName = "TimeRangeSlider"

    @State private var isCurrentTimeHovered = false

    let start: TimeOfDay
    let end: TimeOfDay?
    let crossesMidnight: Bool
    let isEnabled: Bool
    let deviceClock: DeviceClock
    let timeZone: TimeZone?
    let timezoneName: String
    let onStartChange: (TimeOfDay) -> Void
    let onEndChange: (TimeOfDay) -> Void

    var body: some View {
        GeometryReader { geometry in
            let metrics = SliderMetrics(width: geometry.size.width)
            ZStack(alignment: .topLeading) {
                track(metrics: metrics)
                ticks(metrics: metrics)
                rangeFill(metrics: metrics)
                currentTimeMarker(metrics: metrics)
                handles(metrics: metrics)
                labels(metrics: metrics)
            }
            .coordinateSpace(name: Self.coordinateSpaceName)
            .onContinuousHover { phase in
                updateCurrentTimeHover(phase, metrics: metrics)
            }
        }
        .frame(height: TimezonerTheme.sliderHeight)
        .opacity(isEnabled ? 1 : 0.42)
        .allowsHitTesting(isEnabled)
        .accessibilityHidden(!isEnabled)
    }

    @ViewBuilder
    private func currentTimeMarker(metrics: SliderMetrics) -> some View {
        if let timeZone {
            LiveCurrentTimeMarker(
                metrics: metrics,
                deviceClock: deviceClock,
                timeZone: timeZone,
                timezoneName: timezoneName,
                isHovering: isCurrentTimeHovered
            )
        }
    }

    private func updateCurrentTimeHover(_ phase: HoverPhase, metrics: SliderMetrics) {
        let isHovering: Bool
        switch phase {
        case .active(let location):
            guard let timeZone else {
                isCurrentTimeHovered = false
                return
            }
            let projection = CurrentTimeMarkerProjection(
                instant: deviceClock.now,
                timeZone: timeZone
            )
            isHovering = projection.isHovered(at: location, in: metrics)
        case .ended:
            isHovering = false
        }
        guard isCurrentTimeHovered != isHovering else {
            return
        }
        isCurrentTimeHovered = isHovering
    }

    private func track(metrics: SliderMetrics) -> some View {
        Capsule()
            .fill(Color.primary.opacity(0.14))
            .frame(width: metrics.usableWidth, height: TimezonerTheme.sliderTrackHeight)
            .position(x: metrics.midX, y: metrics.trackY)
    }

    private func ticks(metrics: SliderMetrics) -> some View {
        ForEach(0...24, id: \.self) { hour in
            let isMajor = hour.isMultiple(of: 6)
            Rectangle()
                .fill(Color.secondary.opacity(isMajor ? 0.42 : 0.20))
                .frame(width: 1, height: isMajor ? 7 : 4)
                .position(x: metrics.x(forHour: hour), y: metrics.trackY)
        }
    }

    @ViewBuilder
    private func rangeFill(metrics: SliderMetrics) -> some View {
        if let end {
            let startX = metrics.x(for: start)
            let endX = metrics.x(for: end)
            if crossesMidnight {
                rangeSegment(from: startX, to: metrics.rightX, metrics: metrics)
                rangeSegment(from: metrics.leftX, to: endX, metrics: metrics)
            } else {
                rangeSegment(from: startX, to: endX, metrics: metrics)
            }
        }
    }

    private func rangeSegment(from startX: CGFloat, to endX: CGFloat, metrics: SliderMetrics) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [TimezonerTheme.accent, TimezonerTheme.secondaryAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: max(abs(endX - startX), TimezonerTheme.sliderTrackHeight), height: TimezonerTheme.sliderTrackHeight)
            .position(x: (startX + endX) / 2, y: metrics.trackY)
    }

    @ViewBuilder
    private func handles(metrics: SliderMetrics) -> some View {
        let samePosition = end == start
        sliderHandle(
            time: start,
            role: .start,
            x: metrics.x(for: start),
            y: samePosition ? metrics.trackY - TimezonerTheme.coincidentHandleOffset : metrics.trackY,
            hitSize: samePosition ? TimezonerTheme.coincidentHandleHitSize : TimezonerTheme.sliderHitSize,
            metrics: metrics,
            onChange: onStartChange
        )
        if let end {
            sliderHandle(
                time: end,
                role: .end,
                x: metrics.x(for: end),
                y: samePosition ? metrics.trackY + TimezonerTheme.coincidentHandleOffset : metrics.trackY,
                hitSize: samePosition ? TimezonerTheme.coincidentHandleHitSize : TimezonerTheme.sliderHitSize,
                metrics: metrics,
                onChange: onEndChange
            )
        }
    }

    private func sliderHandle(
        time: TimeOfDay,
        role: SliderHandleRole,
        x: CGFloat,
        y: CGFloat,
        hitSize: CGFloat,
        metrics: SliderMetrics,
        onChange: @escaping (TimeOfDay) -> Void
    ) -> some View {
        SliderHandle(role: role)
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
            .position(x: x, y: y)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpaceName))
                    .onChanged { gesture in
                        onChange(metrics.time(at: gesture.location.x))
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("\(timezoneName) \(role.accessibilityName) time")
            .accessibilityValue(time.formatted)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    onChange(adjust(time: time, by: TimeOfDay.sliderStepMinutes))
                case .decrement:
                    onChange(adjust(time: time, by: -TimeOfDay.sliderStepMinutes))
                @unknown default:
                    return
                }
            }
    }

    private func labels(metrics: SliderMetrics) -> some View {
        Canvas { context, _ in
            for hour in [0, 6, 12, 18, 24] {
                context.draw(
                    Text(String(format: "%02d", hour))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: metrics.x(forHour: hour), y: metrics.labelY)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func adjust(time: TimeOfDay, by delta: Int) -> TimeOfDay {
        let wrappedMinutes = (time.minutesSinceMidnight + delta + TimeOfDay.minutesPerDay) % TimeOfDay.minutesPerDay
        guard let adjusted = TimeOfDay(minutesSinceMidnight: wrappedMinutes) else {
            return time
        }
        return adjusted
    }
}

struct CurrentTimeMarkerProjection {
    let time: TimeOfDay

    var hoverText: String {
        return time.formatted
    }

    init(
        instant: Date,
        timeZone: TimeZone,
        engine: TimezoneConversionEngine = TimezoneConversionEngine()
    ) {
        self.time = engine.timeOfDay(for: instant, in: timeZone)
    }

    func x(in metrics: SliderMetrics) -> CGFloat {
        return metrics.x(for: time)
    }

    func isHovered(at location: CGPoint, in metrics: SliderMetrics) -> Bool {
        let center = CGPoint(x: x(in: metrics), y: metrics.trackY)
        let target = CGRect(
            x: center.x - (TimezonerTheme.currentTimeHoverTargetWidth / 2),
            y: center.y - (TimezonerTheme.currentTimeHoverTargetHeight / 2),
            width: TimezonerTheme.currentTimeHoverTargetWidth,
            height: TimezonerTheme.currentTimeHoverTargetHeight
        )
        return target.contains(location)
    }
}

private struct LiveCurrentTimeMarker: View {
    let metrics: SliderMetrics
    @ObservedObject var deviceClock: DeviceClock
    let timeZone: TimeZone
    let timezoneName: String
    let isHovering: Bool

    var body: some View {
        let projection = CurrentTimeMarkerProjection(
            instant: deviceClock.now,
            timeZone: timeZone
        )
        ZStack {
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.88))
                .frame(width: 5, height: 28)
            Capsule()
                .fill(TimezonerTheme.currentTimeMarker)
                .frame(width: 3, height: 26)
        }
        .overlay(alignment: .top) {
            if isHovering {
                Text(projection.hoverText)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .frame(width: TimezonerTheme.currentTimeHoverLabelWidth)
                    .padding(.vertical, 4)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(
                            cornerRadius: TimezonerTheme.currentTimeHoverCornerRadius,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: TimezonerTheme.currentTimeHoverCornerRadius,
                            style: .continuous
                        )
                        .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.22), radius: 3, y: 2)
                    .fixedSize()
                    .offset(y: TimezonerTheme.currentTimeHoverVerticalOffset)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .shadow(color: Color.black.opacity(0.22), radius: 1, y: 1)
        .position(x: projection.x(in: metrics), y: metrics.trackY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current device time in \(timezoneName)")
        .accessibilityValue(projection.time.formatted)
        .allowsHitTesting(false)
    }
}

private enum SliderHandleRole {
    case start
    case end

    var accessibilityName: String {
        switch self {
        case .start:
            return "start"
        case .end:
            return "end"
        }
    }
}

private struct SliderHandle: View {
    let role: SliderHandleRole

    var body: some View {
        ZStack {
            Circle()
                .fill(role == .start ? TimezonerTheme.accent : Color(nsColor: .windowBackgroundColor))
            Circle()
                .stroke(TimezonerTheme.accent, lineWidth: role == .start ? 0 : 2.5)
        }
        .frame(width: TimezonerTheme.sliderHandleSize, height: TimezonerTheme.sliderHandleSize)
        .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
    }
}

struct SliderMetrics {
    let width: CGFloat

    var leftX: CGFloat {
        return TimezonerTheme.sliderHitSize / 2
    }

    var rightX: CGFloat {
        return width - (TimezonerTheme.sliderHitSize / 2)
    }

    var usableWidth: CGFloat {
        return max(rightX - leftX, 1)
    }

    var midX: CGFloat {
        return leftX + (usableWidth / 2)
    }

    var trackY: CGFloat {
        return 14
    }

    var labelY: CGFloat {
        return 34
    }

    func x(for time: TimeOfDay) -> CGFloat {
        let fraction = min(Double(time.minutesSinceMidnight) / Double(TimeOfDay.minutesPerDay), 1)
        return leftX + (CGFloat(fraction) * usableWidth)
    }

    func x(forHour hour: Int) -> CGFloat {
        let fraction = CGFloat(hour) / 24
        return leftX + (fraction * usableWidth)
    }

    func time(at x: CGFloat) -> TimeOfDay {
        let clampedX = min(max(x, leftX), rightX)
        let fraction = Double((clampedX - leftX) / usableWidth)
        let rawMinutes = fraction * Double(TimeOfDay.minutesPerDay)
        let roundedMinutes = Int((rawMinutes / Double(TimeOfDay.sliderStepMinutes)).rounded()) * TimeOfDay.sliderStepMinutes
        let snappedMinutes = min(roundedMinutes, TimeOfDay.minutesPerDay - TimeOfDay.sliderStepMinutes)
        guard let time = TimeOfDay(minutesSinceMidnight: snappedMinutes) else {
            preconditionFailure("A clamped slider position must produce a valid time")
        }
        return time
    }
}
