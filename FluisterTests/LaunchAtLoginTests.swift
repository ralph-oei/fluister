import XCTest
@testable import Fluister

@MainActor
final class LaunchAtLoginTests: XCTestCase {

    private final class FakeItem: LoginItemControlling {
        var isEnabled = false
        var enableError: Error?
        func enable() throws { if let enableError { throw enableError }; isEnabled = true }
        func disable() throws { isEnabled = false }
    }

    func testEnableTogglesOn() {
        let fake = FakeItem()
        let controller = LaunchAtLoginController(item: fake)
        XCTAssertFalse(controller.isEnabled)

        controller.setEnabled(true)
        XCTAssertTrue(controller.isEnabled)
    }

    func testDisableTogglesOff() {
        let fake = FakeItem()
        fake.isEnabled = true
        let controller = LaunchAtLoginController(item: fake)

        controller.setEnabled(false)
        XCTAssertFalse(controller.isEnabled)
    }

    func testEnableFailureKeepsSystemStatus() {
        struct Boom: Error {}
        let fake = FakeItem()
        fake.enableError = Boom()
        let controller = LaunchAtLoginController(item: fake)

        controller.setEnabled(true)
        XCTAssertFalse(controller.isEnabled, "bij fout blijft de status wat het systeem zegt")
    }
}
