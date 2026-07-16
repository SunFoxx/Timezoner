import AppKit
import SwiftUI
import TimezonerCore

struct MenuBarContentView: View {
    @ObservedObject var state: TimezonerState
    @ObservedObject var loginItemController: LaunchAtLoginController
    @State private var pendingScrollRowID: UUID?

    let deviceClock: DeviceClock
    let openLoginItemsSettings: () -> Void
    let quit: () -> Void

    init(
        state: TimezonerState,
        deviceClock: DeviceClock,
        loginItemController: LaunchAtLoginController,
        openLoginItemsSettings: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.state = state
        self.deviceClock = deviceClock
        self.loginItemController = loginItemController
        self.openLoginItemsSettings = openLoginItemsSettings
        self.quit = quit
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            pinnedLocalRow
            comparisonRows
            Divider()
            footer
        }
        .frame(width: TimezonerTheme.popoverWidth, height: TimezonerTheme.popoverHeight)
        .background(.regularMaterial)
    }

    private var pinnedLocalRow: some View {
        TimezoneRowView(
            state: state,
            deviceClock: deviceClock,
            row: nil,
            catalog: state.catalog,
            isLocal: true
        )
        .padding(.horizontal, TimezonerTheme.rowListHorizontalPadding)
        .padding(.vertical, TimezonerTheme.pinnedLocalVerticalPadding)
        .frame(height: TimezonerTheme.pinnedLocalSectionHeight)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .zIndex(1)
    }

    private var comparisonRows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: TimezonerTheme.comparisonRowSpacing) {
                    ForEach(state.rows) { row in
                        TimezoneRowView(
                            state: state,
                            deviceClock: deviceClock,
                            row: row,
                            catalog: state.catalog,
                            isLocal: false
                        )
                        .id(row.id)
                    }
                }
                .padding(.horizontal, TimezonerTheme.rowListHorizontalPadding)
            }
            .frame(height: TimezonerTheme.comparisonScrollableHeight)
            .onChange(of: pendingScrollRowID) { rowID in
                guard let rowID else {
                    return
                }
                DispatchQueue.main.async {
                    proxy.scrollTo(rowID, anchor: .bottom)
                    pendingScrollRowID = nil
                }
            }
        }
        .padding(.vertical, TimezonerTheme.comparisonVerticalPadding)
        .frame(height: TimezonerTheme.comparisonViewportHeight)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [TimezonerTheme.accent, TimezonerTheme.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Timezoner")
                    .font(.title3.weight(.bold))
                Text("24-hour timezone range translator")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                state.menuDidOpen(at: Date())
            } label: {
                Label("Now", systemImage: "dot.scope")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Reset the start to the current time")

            settingsMenu
        }
        .padding(.horizontal, TimezonerTheme.headerPadding)
        .frame(height: TimezonerTheme.headerHeight)
    }

    private var settingsMenu: some View {
        Menu {
            if loginItemController.status == .enabled {
                Label("Launches at Login", systemImage: "checkmark.circle.fill")
            } else {
                Label("Launch at Login Needs Attention", systemImage: "exclamationmark.triangle")
            }
            if loginItemController.status == .requiresApproval {
                Button("Open Login Items Settings") {
                    openLoginItemsSettings()
                }
            }
            Divider()
            Button("Quit Timezoner") {
                quit()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 24)
        .accessibilityLabel("Timezoner settings")
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                pendingScrollRowID = state.addRow()
            } label: {
                Label("Add timezone", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(TimezonerTheme.accent)
            .controlSize(.small)

            if let footerWarningMessage {
                Label(footerWarningMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(TimezonerTheme.warning)
                    .lineLimit(1)
                if loginItemController.status == .requiresApproval {
                    Button("Open Settings") {
                        openLoginItemsSettings()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }

            Spacer(minLength: 8)
            if footerWarningMessage == nil {
                Text("Rows are remembered · Time resets to now when closed")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, TimezonerTheme.headerPadding)
        .frame(height: TimezonerTheme.footerHeight)
    }

    private var footerWarningMessage: String? {
        let hasLoginWarning = loginItemController.status == .requiresApproval || loginItemController.failure != nil
        let hasPersistenceWarning = state.persistenceFailure != nil
        switch (hasLoginWarning, hasPersistenceWarning) {
        case (true, true):
            return String(localized: "Login setup and row saving need attention")
        case (true, false):
            return String(localized: "Launch at Login needs attention")
        case (false, true):
            return String(localized: "Timezone rows could not be saved")
        case (false, false):
            return nil
        }
    }
}
