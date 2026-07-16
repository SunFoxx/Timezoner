import AppKit
import ServiceManagement
import SwiftUI
import TimezonerCore

@MainActor
final class TimezonerAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var state: TimezonerState?
    private var loginItemController: LaunchAtLoginController?
    private var deviceClock: DeviceClock?
    private var testingWindow: NSWindow?
    private var hasStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
    }

    func start() {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("--ui-testing")
        NSApplication.shared.setActivationPolicy(isUITesting ? .regular : .accessory)
        let state = TimezonerState()
        let deviceClock = DeviceClock()
        let loginItemController = LaunchAtLoginController(service: SystemLoginItemService())
        if !isUITesting {
            loginItemController.ensureEnabled()
        }
        self.state = state
        self.deviceClock = deviceClock
        self.loginItemController = loginItemController

        let contentView = MenuBarContentView(
            state: state,
            deviceClock: deviceClock,
            loginItemController: loginItemController,
            openLoginItemsSettings: {
                SMAppService.openSystemSettingsLoginItems()
            },
            quit: {
                NSApplication.shared.terminate(nil)
            }
        )

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: TimezonerTheme.popoverWidth, height: TimezonerTheme.popoverHeight)
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.delegate = self

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "clock.arrow.2.circlepath",
                accessibilityDescription: String(localized: "Timezoner")
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = String(localized: "Open Timezoner")
            button.target = self
            button.action = #selector(togglePopover)
        }
        self.statusItem = statusItem

        if isUITesting, arguments.contains("--show-popover") {
            showTestingWindow(contentView: contentView)
        } else if arguments.contains("--show-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        state?.menuDidClose(at: Date())
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(statusItem?.button)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button, !popover.isShown else {
            return
        }
        loginItemController?.ensureEnabled()
        state?.menuDidOpen(at: Date())
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showTestingWindow(contentView: MenuBarContentView) {
        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(width: TimezonerTheme.popoverWidth, height: TimezonerTheme.popoverHeight)
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Timezoner UI Test"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        testingWindow = window
    }
}
