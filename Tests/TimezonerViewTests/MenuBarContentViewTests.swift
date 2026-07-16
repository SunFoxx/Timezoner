import AppKit
import SwiftUI
import XCTest

@testable import Timezoner
@testable import TimezonerCore

@MainActor
final class MenuBarContentViewTests: XCTestCase {
    func testMountedRangeInputsShareTheSameVerticalOrigin() {
        let instant = ISO8601DateFormatter().date(from: "2026-07-15T12:50:00Z")!
        let utc = TimeZone(secondsFromGMT: 0)!
        let state = TimezonerState(
            now: instant,
            localTimeZone: utc,
            rowsStore: ViewTestRowsStore(rows: [TimezoneRow()])
        )
        state.enableRange()
        state.setEnd(TimeOfDay(hour: 18, minute: 15)!, viewedIn: utc)
        let deviceClock = DeviceClock(
            nowProvider: { instant },
            timeZoneProvider: { utc },
            notificationCenter: NotificationCenter(),
            startsTimer: false
        )
        let hostingView = NSHostingView(
            rootView: TimezoneRowView(
                state: state,
                deviceClock: deviceClock,
                row: nil,
                catalog: state.catalog,
                isLocal: true
            )
        )
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: TimezonerTheme.popoverWidth,
            height: TimezonerTheme.rowHeight
        )
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFrontRegardless()
        defer {
            window.orderOut(nil)
        }
        hostingView.layoutSubtreeIfNeeded()

        let startFrame = accessibilityFrame(
            in: hostingView,
            role: .textField,
            value: "12:50"
        )
        let endFrame = accessibilityFrame(
            in: hostingView,
            role: .textField,
            value: "18:15"
        )

        let accessibilitySummary = accessibilityDebugSummary(in: hostingView)
        XCTAssertNotNil(startFrame, "Accessibility elements: \(accessibilitySummary)")
        XCTAssertNotNil(endFrame, "Accessibility elements: \(accessibilitySummary)")
        XCTAssertEqual(startFrame?.minY ?? 0, endFrame?.minY ?? 1, accuracy: 1)
    }

    func testMountedCurrentTimeMarkerRemainsIndependentFromTheSelection() {
        let instant = ISO8601DateFormatter().date(from: "2026-07-15T16:00:00Z")!
        let utc = TimeZone(secondsFromGMT: 0)!
        let state = TimezonerState(
            now: instant,
            localTimeZone: utc,
            rowsStore: ViewTestRowsStore(rows: [TimezoneRow()])
        )
        let deviceClock = DeviceClock(
            nowProvider: { instant },
            timeZoneProvider: { utc },
            notificationCenter: NotificationCenter(),
            startsTimer: false
        )
        let hostingView = NSHostingView(
            rootView: TimezoneRowView(
                state: state,
                deviceClock: deviceClock,
                row: nil,
                catalog: state.catalog,
                isLocal: true
            )
        )
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: TimezonerTheme.popoverWidth,
            height: TimezonerTheme.rowHeight
        )
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFrontRegardless()
        defer {
            window.orderOut(nil)
        }
        hostingView.layoutSubtreeIfNeeded()

        state.setStart(TimeOfDay(hour: 18, minute: 0)!, viewedIn: utc)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        hostingView.layoutSubtreeIfNeeded()

        let markerCenterX = currentTimeMarkerCenterX(in: hostingView)
        let sliderWidth = TimezonerTheme.popoverWidth - (TimezonerTheme.rowPadding * 2)
        let metrics = SliderMetrics(width: sliderWidth)
        let expectedCurrentTimeX = TimezonerTheme.rowPadding + metrics.x(for: TimeOfDay(hour: 16, minute: 0)!)
        let selectedTimeX = TimezonerTheme.rowPadding + metrics.x(for: TimeOfDay(hour: 18, minute: 0)!)

        XCTAssertNotNil(markerCenterX)
        XCTAssertEqual(markerCenterX ?? 0, expectedCurrentTimeX, accuracy: 3)
        XCTAssertGreaterThan(abs((markerCenterX ?? 0) - selectedTimeX), 20)
    }

    func testMountedLocalRowRefreshesWhenTheDeviceTimezoneChanges() {
        let instant = ISO8601DateFormatter().date(from: "2026-07-15T16:00:00Z")!
        let utc = TimeZone(secondsFromGMT: 0)!
        var suppliedTimeZone = utc
        let notificationCenter = NotificationCenter()
        let state = TimezonerState(
            now: instant,
            localTimeZone: utc,
            rowsStore: ViewTestRowsStore(rows: [TimezoneRow()])
        )
        let deviceClock = DeviceClock(
            nowProvider: { instant },
            timeZoneProvider: { suppliedTimeZone },
            notificationCenter: notificationCenter,
            startsTimer: false
        )
        let hostingView = NSHostingView(
            rootView: TimezoneRowView(
                state: state,
                deviceClock: deviceClock,
                row: nil,
                catalog: state.catalog,
                isLocal: true
            )
        )
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: TimezonerTheme.popoverWidth,
            height: TimezonerTheme.rowHeight
        )
        hostingView.layoutSubtreeIfNeeded()
        let initialAccessibility = accessibilityStrings(in: hostingView)
        XCTAssertTrue(initialAccessibility.contains("16:00"))

        suppliedTimeZone = TimeZone(secondsFromGMT: 6 * 60 * 60)!
        notificationCenter.post(name: .NSSystemTimeZoneDidChange, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        hostingView.layoutSubtreeIfNeeded()

        let updatedAccessibility = accessibilityStrings(in: hostingView)
        XCTAssertTrue(updatedAccessibility.contains("22:00"))
        XCTAssertFalse(updatedAccessibility.contains("16:00"))
    }

    func testMountedComparisonScrollViewportExposesExactlyTwoRowHeights() {
        let instant = ISO8601DateFormatter().date(from: "2026-07-15T16:00:00Z")!
        let utc = TimeZone(secondsFromGMT: 0)!
        let state = TimezonerState(
            now: instant,
            localTimeZone: utc,
            rowsStore: ViewTestRowsStore(rows: [
                TimezoneRow(timeZoneIdentifier: "America/Los_Angeles"),
                TimezoneRow(timeZoneIdentifier: "GMT+0600"),
                TimezoneRow()
            ])
        )
        let deviceClock = DeviceClock(
            nowProvider: { instant },
            timeZoneProvider: { utc },
            notificationCenter: NotificationCenter(),
            startsTimer: false
        )
        let loginController = LaunchAtLoginController(service: ViewTestLoginItemService())
        let rootView = MenuBarContentView(
            state: state,
            deviceClock: deviceClock,
            loginItemController: loginController,
            openLoginItemsSettings: {},
            quit: {}
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: TimezonerTheme.popoverWidth,
            height: TimezonerTheme.popoverHeight
        )
        hostingView.layoutSubtreeIfNeeded()

        let scrollViews = descendants(of: hostingView).compactMap { view in
            view as? NSScrollView
        }

        XCTAssertEqual(scrollViews.count, 1)
        guard let scrollView = scrollViews.first else {
            return
        }
        let frame = scrollView.convert(scrollView.bounds, to: hostingView)
        XCTAssertEqual(frame.height, TimezonerTheme.comparisonScrollableHeight, accuracy: 1)
        XCTAssertEqual(
            frame.minY,
            TimezonerTheme.headerHeight
                + TimezonerTheme.dividerThickness
                + TimezonerTheme.pinnedLocalSectionHeight
                + TimezonerTheme.comparisonVerticalPadding,
            accuracy: 1
        )
    }

    private func descendants(of view: NSView) -> [NSView] {
        return view.subviews.flatMap { child in
            [child] + descendants(of: child)
        }
    }

    private func accessibilityStrings(in root: NSObject) -> Set<String> {
        var strings = Set<String>()
        for object in accessibilityObjects(in: root) {
            for key in ["accessibilityIdentifier", "accessibilityLabel", "accessibilityValue", "accessibilityHelp"] {
                guard object.responds(to: NSSelectorFromString(key)) else {
                    continue
                }
                if let value = object.value(forKey: key) as? String {
                    strings.insert(value)
                }
            }
        }
        return strings
    }

    private func accessibilityFrame(
        in root: NSObject,
        role: NSAccessibility.Role,
        value: String
    ) -> NSRect? {
        for object in accessibilityObjects(in: root) {
            guard object.responds(to: NSSelectorFromString("accessibilityRole")),
                object.responds(to: NSSelectorFromString("accessibilityValue")),
                object.responds(to: NSSelectorFromString("accessibilityFrame")),
                let objectRole = object.value(forKey: "accessibilityRole") as? String,
                objectRole == role.rawValue,
                let objectValue = object.value(forKey: "accessibilityValue") as? String,
                objectValue == value,
                let frameValue = object.value(forKey: "accessibilityFrame") as? NSValue
            else {
                continue
            }
            return frameValue.rectValue
        }
        return nil
    }

    private func accessibilityObjects(in root: NSObject) -> [NSObject] {
        var visited = Set<ObjectIdentifier>()
        var objects: [NSObject] = []

        func visit(_ object: NSObject) {
            guard visited.insert(ObjectIdentifier(object)).inserted else {
                return
            }
            objects.append(object)
            if let view = object as? NSView {
                view.subviews.forEach(visit)
            }
            guard object.responds(to: NSSelectorFromString("accessibilityChildren")) else {
                return
            }
            let children = object.value(forKey: "accessibilityChildren") as? [NSObject] ?? []
            children.forEach(visit)
        }

        visit(root)
        return objects
    }

    private func accessibilityDebugSummary(in root: NSObject) -> [String] {
        return accessibilityObjects(in: root).compactMap { object in
            let role =
                object.responds(to: NSSelectorFromString("accessibilityRole"))
                ? object.value(forKey: "accessibilityRole") as? String
                : nil
            let label =
                object.responds(to: NSSelectorFromString("accessibilityLabel"))
                ? object.value(forKey: "accessibilityLabel") as? String
                : nil
            let value =
                object.responds(to: NSSelectorFromString("accessibilityValue"))
                ? object.value(forKey: "accessibilityValue") as? String
                : nil
            let title =
                object.responds(to: NSSelectorFromString("accessibilityTitle"))
                ? object.value(forKey: "accessibilityTitle") as? String
                : nil
            guard role != nil || label != nil || value != nil else {
                return nil
            }
            return "role=\(role ?? "nil") label=\(label ?? "nil") title=\(title ?? "nil") value=\(value ?? "nil")"
        }
    }

    private func currentTimeMarkerCenterX(in view: NSView) -> CGFloat? {
        guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return nil
        }
        view.cacheDisplay(in: view.bounds, to: image)
        let scale = CGFloat(image.pixelsWide) / view.bounds.width
        var xTotal: CGFloat = 0
        var pixelCount: CGFloat = 0

        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
                    continue
                }
                guard color.redComponent > 0.82,
                    color.greenComponent > 0.2,
                    color.greenComponent < 0.56,
                    color.blueComponent < 0.5,
                    color.alphaComponent > 0.75
                else {
                    continue
                }
                xTotal += CGFloat(x)
                pixelCount += 1
            }
        }

        guard pixelCount > 0 else {
            return nil
        }
        return (xTotal / pixelCount) / scale
    }
}

private final class ViewTestRowsStore: TimezoneRowsStoring {
    private var rows: [TimezoneRow]

    init(rows: [TimezoneRow]) {
        self.rows = rows
    }

    func load() -> Result<[TimezoneRow]?, TimezoneRowsStoreFailure> {
        return .success(rows)
    }

    func save(_ rows: [TimezoneRow]) -> Result<Void, TimezoneRowsStoreFailure> {
        self.rows = rows
        return .success(())
    }
}

private final class ViewTestLoginItemService: LoginItemServicing {
    var status: LoginItemStatus = .enabled

    func register() -> Result<Void, LoginItemFailure> {
        return .success(())
    }
}
