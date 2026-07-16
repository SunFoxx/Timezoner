import AppKit
import Combine
import Foundation

@MainActor
protocol DeviceClockTimerScheduling {
    func schedule(
        at fireDate: Date,
        repeating interval: TimeInterval,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> AnyCancellable
}

@MainActor
struct RunLoopDeviceClockTimerScheduler: DeviceClockTimerScheduling {
    func schedule(
        at fireDate: Date,
        repeating interval: TimeInterval,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> AnyCancellable {
        let timer = Timer(fire: fireDate, interval: interval, repeats: true) { _ in
            Task { @MainActor in
                action()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return AnyCancellable {
            timer.invalidate()
        }
    }
}

@MainActor
final class DeviceTimeZone: ObservableObject {
    @Published private(set) var current: TimeZone

    init(current: TimeZone) {
        self.current = current
    }

    func refresh(to timeZone: TimeZone) {
        current = timeZone
    }
}

@MainActor
final class DeviceClock: ObservableObject {
    @Published private(set) var now: Date
    let timeZone: DeviceTimeZone

    private let nowProvider: () -> Date
    private let timeZoneProvider: () -> TimeZone
    private let notificationCenter: NotificationCenter
    private let isTimerEnabled: Bool
    private let timerScheduler: DeviceClockTimerScheduling
    private var timerCancellation: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init(
        nowProvider: @escaping () -> Date = Date.init,
        timeZoneProvider: @escaping () -> TimeZone = { TimeZone.current },
        notificationCenter: NotificationCenter = .default,
        startsTimer: Bool = true,
        timerScheduler: DeviceClockTimerScheduling? = nil
    ) {
        self.nowProvider = nowProvider
        self.timeZoneProvider = timeZoneProvider
        self.notificationCenter = notificationCenter
        self.isTimerEnabled = startsTimer
        self.timerScheduler = timerScheduler ?? RunLoopDeviceClockTimerScheduler()
        self.now = nowProvider()
        self.timeZone = DeviceTimeZone(current: timeZoneProvider())

        notificationCenter.publisher(for: .NSSystemClockDidChange)
            .sink { [weak self] _ in
                self?.refreshFromSystem(realignTimer: true)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .NSSystemTimeZoneDidChange)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                timeZone.refresh(to: timeZoneProvider())
                refreshFromSystem(realignTimer: true)
            }
            .store(in: &cancellables)

        if startsTimer {
            scheduleMinuteTimer(after: now)
        }
    }

    func refresh(at date: Date) {
        now = date
    }

    private func refreshFromSystem(realignTimer: Bool) {
        let currentDate = nowProvider()
        refresh(at: currentDate)
        if realignTimer, isTimerEnabled {
            scheduleMinuteTimer(after: currentDate)
        }
    }

    private func scheduleMinuteTimer(after currentDate: Date) {
        timerCancellation?.cancel()
        let currentInterval = currentDate.timeIntervalSinceReferenceDate
        let nextMinuteInterval = (floor(currentInterval / 60) + 1) * 60
        let nextMinute = Date(timeIntervalSinceReferenceDate: nextMinuteInterval)
        timerCancellation = timerScheduler.schedule(at: nextMinute, repeating: 60) { [weak self] in
            self?.refreshFromSystem(realignTimer: false)
        }
    }
}
