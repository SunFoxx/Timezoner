import SwiftUI

@main
struct TimezonerApp: App {
    @NSApplicationDelegateAdaptor(TimezonerAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
