import Combine
import Foundation

public enum LoginItemStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

public enum LoginItemFailure: Error, Equatable, Sendable {
    case registrationFailed
    case serviceNotFound
}

public protocol LoginItemServicing: AnyObject {
    var status: LoginItemStatus { get }
    func register() -> Result<Void, LoginItemFailure>
}

@MainActor
public final class LaunchAtLoginController: ObservableObject {
    @Published public private(set) var status: LoginItemStatus
    @Published public private(set) var failure: LoginItemFailure?

    private let service: LoginItemServicing

    public init(service: LoginItemServicing) {
        self.service = service
        self.status = service.status
    }

    public func ensureEnabled() {
        refresh()
        switch status {
        case .enabled, .requiresApproval:
            return
        case .notFound:
            failure = .serviceNotFound
        case .notRegistered:
            register()
        }
    }

    public func refresh() {
        status = service.status
        switch status {
        case .enabled, .requiresApproval:
            failure = nil
        case .notFound:
            failure = .serviceNotFound
        case .notRegistered:
            break
        }
    }

    private func register() {
        switch service.register() {
        case .success:
            failure = nil
            status = service.status
        case .failure(let failure):
            self.failure = failure
            status = service.status
        }
    }
}
