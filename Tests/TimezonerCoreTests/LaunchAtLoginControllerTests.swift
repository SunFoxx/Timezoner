import XCTest

@testable import TimezonerCore

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testFirstLaunchRegistersWhenNotRegistered() {
        let service = FakeLoginItemService(status: .notRegistered)
        let controller = LaunchAtLoginController(service: service)

        controller.ensureEnabled()

        XCTAssertEqual(service.registrationCount, 1)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertNil(controller.failure)
    }

    func testDoesNotRepeatedlyRegisterWhenApprovalIsRequired() {
        let service = FakeLoginItemService(status: .requiresApproval)
        let controller = LaunchAtLoginController(service: service)

        controller.ensureEnabled()

        XCTAssertEqual(service.registrationCount, 0)
        XCTAssertEqual(controller.status, .requiresApproval)
    }

    func testRegistrationFailureIsExposedWithoutThrowing() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registrationResult = .failure(.registrationFailed)
        let controller = LaunchAtLoginController(service: service)

        controller.ensureEnabled()

        XCTAssertEqual(controller.status, .notRegistered)
        XCTAssertEqual(controller.failure, .registrationFailed)
    }

    func testRefreshReflectsAnExternalApprovalChange() {
        let service = FakeLoginItemService(status: .requiresApproval)
        let controller = LaunchAtLoginController(service: service)

        service.status = .enabled
        controller.refresh()

        XCTAssertEqual(controller.status, .enabled)
    }

    func testRefreshClearsAStaleFailureAfterExternalRecovery() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registrationResult = .failure(.registrationFailed)
        let controller = LaunchAtLoginController(service: service)
        controller.ensureEnabled()
        XCTAssertEqual(controller.failure, .registrationFailed)

        service.status = .enabled
        controller.refresh()

        XCTAssertNil(controller.failure)
    }

    func testEnsureEnabledRepairsAnExternallyDisabledLoginItem() {
        let service = FakeLoginItemService(status: .enabled)
        let controller = LaunchAtLoginController(service: service)

        service.status = .notRegistered
        controller.ensureEnabled()

        XCTAssertEqual(service.registrationCount, 1)
        XCTAssertEqual(controller.status, .enabled)
    }
}

private final class FakeLoginItemService: LoginItemServicing {
    var status: LoginItemStatus
    var registrationResult: Result<Void, LoginItemFailure> = .success(())
    private(set) var registrationCount = 0

    init(status: LoginItemStatus) {
        self.status = status
    }

    func register() -> Result<Void, LoginItemFailure> {
        registrationCount += 1
        if case .success = registrationResult {
            status = .enabled
        }
        return registrationResult
    }
}
