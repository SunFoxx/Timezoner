import AppKit
import Combine
import XCTest

@testable import Timezoner

@MainActor
final class DeviceClockTests: XCTestCase {
    func testTimerSchedulingUsesTheSameInitialSampleAsPublishedTime() {
        let initial = date("2026-01-15T12:00:59Z")
        let unexpectedSecondSample = date("2026-01-15T12:01:00Z")
        var samples = [initial, unexpectedSecondSample]
        let scheduler = RecordingDeviceClockTimerScheduler()

        let clock = DeviceClock(
            nowProvider: { samples.removeFirst() },
            notificationCenter: NotificationCenter(),
            timerScheduler: scheduler
        )

        XCTAssertEqual(clock.now, initial)
        XCTAssertEqual(samples, [unexpectedSecondSample])
        XCTAssertEqual(scheduler.scheduledFireDates, [date("2026-01-15T12:01:00Z")])
        XCTAssertEqual(scheduler.scheduledIntervals, [60])
    }

    func testScheduledTimerRefreshesFromTheProvider() {
        var suppliedDate = date("2026-01-15T12:00:59Z")
        let scheduler = RecordingDeviceClockTimerScheduler()
        let clock = DeviceClock(
            nowProvider: { suppliedDate },
            notificationCenter: NotificationCenter(),
            timerScheduler: scheduler
        )
        suppliedDate = date("2026-01-15T12:01:00Z")

        scheduler.fire()

        XCTAssertEqual(clock.now, suppliedDate)
        XCTAssertEqual(scheduler.scheduledFireDates.count, 1)
    }

    func testClockChangeRealignmentUsesOneFreshSystemSample() {
        let initial = date("2026-01-15T12:00:30Z")
        let updated = date("2026-01-15T15:45:30Z")
        let unexpectedSecondSample = date("2026-01-15T15:46:00Z")
        var samples = [initial, updated, unexpectedSecondSample]
        let notificationCenter = NotificationCenter()
        let scheduler = RecordingDeviceClockTimerScheduler()
        let clock = DeviceClock(
            nowProvider: { samples.removeFirst() },
            notificationCenter: notificationCenter,
            timerScheduler: scheduler
        )

        notificationCenter.post(name: .NSSystemClockDidChange, object: nil)

        XCTAssertEqual(clock.now, updated)
        XCTAssertEqual(samples, [unexpectedSecondSample])
        XCTAssertEqual(
            scheduler.scheduledFireDates,
            [date("2026-01-15T12:01:00Z"), date("2026-01-15T15:46:00Z")]
        )
    }

    func testRunLoopTimerSchedulerInvokesItsAction() async {
        let scheduler = RunLoopDeviceClockTimerScheduler()
        let fired = expectation(description: "The device clock timer fires")
        let cancellable = scheduler.schedule(
            at: Date().addingTimeInterval(0.02),
            repeating: 60
        ) {
            fired.fulfill()
        }

        await fulfillment(of: [fired], timeout: 1)
        withExtendedLifetime(cancellable) {}
    }

    func testManualRefreshPublishesTheNewDeviceTime() {
        let initial = date("2026-01-15T12:00:00Z")
        let updated = date("2026-01-15T12:01:00Z")
        let clock = DeviceClock(
            nowProvider: { initial },
            notificationCenter: NotificationCenter(),
            startsTimer: false
        )

        clock.refresh(at: updated)

        XCTAssertEqual(clock.now, updated)
    }

    func testSystemClockChangeRefreshesImmediatelyFromTheProvider() {
        var suppliedDate = date("2026-01-15T12:00:00Z")
        let updated = date("2026-01-15T15:45:00Z")
        let notificationCenter = NotificationCenter()
        let clock = DeviceClock(
            nowProvider: { suppliedDate },
            notificationCenter: notificationCenter,
            startsTimer: false
        )

        suppliedDate = updated
        notificationCenter.post(name: .NSSystemClockDidChange, object: nil)

        XCTAssertEqual(clock.now, updated)
    }

    func testSystemTimezoneChangeRefreshesEvenWithinTheSameMinute() {
        let instant = date("2026-01-15T12:00:30Z")
        let notificationCenter = NotificationCenter()
        var suppliedTimeZone = TimeZone(secondsFromGMT: 0)!
        let clock = DeviceClock(
            nowProvider: { instant },
            timeZoneProvider: { suppliedTimeZone },
            notificationCenter: notificationCenter,
            startsTimer: false
        )

        var updates = 0
        let cancellable = clock.$now.dropFirst().sink { _ in
            updates += 1
        }
        suppliedTimeZone = TimeZone(secondsFromGMT: 6 * 60 * 60)!
        notificationCenter.post(name: .NSSystemTimeZoneDidChange, object: nil)

        XCTAssertEqual(updates, 1)
        XCTAssertEqual(clock.timeZone.current.secondsFromGMT(for: instant), 6 * 60 * 60)
        withExtendedLifetime(cancellable) {}
    }

    private func date(_ text: String) -> Date {
        guard let value = ISO8601DateFormatter().date(from: text) else {
            preconditionFailure("The test date must be valid ISO-8601")
        }
        return value
    }
}

@MainActor
private final class RecordingDeviceClockTimerScheduler: DeviceClockTimerScheduling {
    private(set) var scheduledFireDates: [Date] = []
    private(set) var scheduledIntervals: [TimeInterval] = []
    private var action: (@MainActor @Sendable () -> Void)?

    func schedule(
        at fireDate: Date,
        repeating interval: TimeInterval,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> AnyCancellable {
        scheduledFireDates.append(fireDate)
        scheduledIntervals.append(interval)
        self.action = action
        return AnyCancellable {}
    }

    func fire() {
        action?()
    }
}
