import Foundation
import OSLog
import ServiceManagement
import TimezonerCore

final class SystemLoginItemService: LoginItemServicing {
    private let service: SMAppService
    private let logger: Logger

    init(service: SMAppService = .mainApp) {
        self.service = service
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.sunfoxx.Timezoner",
            category: "LaunchAtLogin"
        )
    }

    var status: LoginItemStatus {
        switch service.status {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .notFound
        }
    }

    func register() -> Result<Void, LoginItemFailure> {
        do {
            try service.register()
            return .success(())
        } catch {
            logger.warning("Login item registration failed: \(error.localizedDescription, privacy: .public)")
            return .failure(.registrationFailed)
        }
    }
}
