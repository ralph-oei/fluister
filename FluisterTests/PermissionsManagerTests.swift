import XCTest
@testable import Fluister

final class PermissionsManagerTests: XCTestCase {

    // MARK: - Pure combinatie-logica

    func testReadyWhenMicGrantedAndAccessibilityTrusted() {
        XCTAssertEqual(dictationReadiness(mic: .granted, accessibilityTrusted: true), .ready)
    }

    func testNeedsAccessibilityWhenMicGrantedButNotTrusted() {
        XCTAssertEqual(dictationReadiness(mic: .granted, accessibilityTrusted: false), .needsAccessibility)
    }

    func testNeedsMicrophoneWhenNotDetermined() {
        XCTAssertEqual(dictationReadiness(mic: .notDetermined, accessibilityTrusted: true), .needsMicrophone)
        XCTAssertEqual(dictationReadiness(mic: .notDetermined, accessibilityTrusted: false), .needsMicrophone)
    }

    func testBlockedWhenMicDenied() {
        XCTAssertEqual(dictationReadiness(mic: .denied, accessibilityTrusted: true), .blocked)
        XCTAssertEqual(dictationReadiness(mic: .denied, accessibilityTrusted: false), .blocked)
    }

    // MARK: - Afgeleide onboarding-stapstatus (U3)

    func testMicrophoneStepDoneOnlyWhenMicGranted() {
        XCTAssertTrue(microphoneStepDone(.ready))
        XCTAssertTrue(microphoneStepDone(.needsAccessibility)) // mic ok, alleen AX ontbreekt
        XCTAssertFalse(microphoneStepDone(.needsMicrophone))
        XCTAssertFalse(microphoneStepDone(.blocked))
    }

    func testAccessibilityStepDoneOnlyWhenFullyReady() {
        XCTAssertTrue(accessibilityStepDone(.ready))
        XCTAssertFalse(accessibilityStepDone(.needsAccessibility))
        XCTAssertFalse(accessibilityStepDone(.needsMicrophone))
        XCTAssertFalse(accessibilityStepDone(.blocked))
    }

    // MARK: - Manager met geïnjecteerde fakes (autoPoll uit in tests)

    @MainActor
    func testManagerReflectsInjectedProviders() {
        let m = PermissionsManager(
            micStatusProvider: { .granted },
            accessibilityTrustedProvider: { true },
            requestMicAccess: { $0(true) },
            autoPoll: false
        )
        XCTAssertEqual(m.readiness, .ready)
    }

    @MainActor
    func testManagerNeedsAccessibilityWhenMicGrantedOnly() {
        let m = PermissionsManager(
            micStatusProvider: { .granted },
            accessibilityTrustedProvider: { false },
            requestMicAccess: { $0(true) },
            autoPoll: false
        )
        XCTAssertEqual(m.readiness, .needsAccessibility)
    }

    @MainActor
    func testRequestMicrophoneUpdatesStatusAfterGrant() {
        var status: MicPermission = .notDetermined
        let m = PermissionsManager(
            micStatusProvider: { status },
            accessibilityTrustedProvider: { true },
            requestMicAccess: { completion in
                status = .granted           // simuleer: gebruiker staat toe
                completion(true)
            },
            autoPoll: false
        )
        XCTAssertEqual(m.readiness, .needsMicrophone) // init met notDetermined

        let exp = expectation(description: "mic-permissie afgehandeld")
        m.requestMicrophoneIfNeeded { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(m.readiness, .ready)
    }

    @MainActor
    func testRequestMicrophoneSkipsWhenAlreadyDetermined() {
        var requested = false
        let m = PermissionsManager(
            micStatusProvider: { .granted },
            accessibilityTrustedProvider: { false },
            requestMicAccess: { _ in requested = true },
            autoPoll: false
        )

        let exp = expectation(description: "geen nieuwe aanvraag")
        m.requestMicrophoneIfNeeded { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertFalse(requested, "mic-toegang mag niet opnieuw gevraagd worden als de status al bepaald is")
        XCTAssertEqual(m.readiness, .needsAccessibility)
    }

    @MainActor
    func testRequestMicrophoneHandlesDenial() {
        var status: MicPermission = .notDetermined
        let m = PermissionsManager(
            micStatusProvider: { status },
            accessibilityTrustedProvider: { true },
            requestMicAccess: { completion in
                status = .denied            // simuleer: gebruiker weigert
                completion(false)
            },
            autoPoll: false
        )

        let exp = expectation(description: "weigering afgehandeld")
        m.requestMicrophoneIfNeeded { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(m.readiness, .blocked)
    }
}
