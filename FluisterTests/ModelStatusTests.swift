import XCTest
@testable import Fluister

/// Pure helpers rond de modelstatus: onboarding-stap 3, de "kan ik dicteren"-gate,
/// en de ⌥Space-hint die de eerste-start-download uitlegt.
final class ModelStatusTests: XCTestCase {

    func testModelStepDoneOnlyWhenReady() {
        XCTAssertTrue(modelStepDone(.ready))
        XCTAssertFalse(modelStepDone(.notLoaded))
        XCTAssertFalse(modelStepDone(.downloading(0.5)))
        XCTAssertFalse(modelStepDone(.loading))
        XCTAssertFalse(modelStepDone(.failed("x")))
    }

    func testOnboardingReadyRequiresBothPermissionsAndModel() {
        XCTAssertTrue(onboardingReadyToDictate(.ready, .ready))
        XCTAssertFalse(onboardingReadyToDictate(.ready, .downloading(0.9)))    // model nog bezig
        XCTAssertFalse(onboardingReadyToDictate(.ready, .loading))
        XCTAssertFalse(onboardingReadyToDictate(.ready, .notLoaded))
        XCTAssertFalse(onboardingReadyToDictate(.needsAccessibility, .ready))  // permissie mist
        XCTAssertFalse(onboardingReadyToDictate(.needsMicrophone, .notLoaded))
    }

    func testModelNotReadyHintMentionsPercentageWhileDownloading() {
        XCTAssertEqual(modelNotReadyHint(.downloading(0.42)), "Model wordt nog gedownload — 42% (eenmalig)")
        XCTAssertTrue(modelNotReadyHint(.loading).contains("voorbereid"))
        XCTAssertTrue(modelNotReadyHint(.notLoaded).contains("voorbereid"))
        XCTAssertTrue(modelNotReadyHint(.failed("x")).contains("mislukt"))
    }

    func testModelPctRoundsAndClamps() {
        XCTAssertEqual(modelPct(0), "0%")
        XCTAssertEqual(modelPct(0.4), "40%")
        XCTAssertEqual(modelPct(1), "100%")
        XCTAssertEqual(modelPct(1.5), "100%")   // boven 1 → geclamped
        XCTAssertEqual(modelPct(-0.2), "0%")    // onder 0 → geclamped
    }
}
