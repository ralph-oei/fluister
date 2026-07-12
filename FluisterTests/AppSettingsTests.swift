import XCTest
@testable import Fluister

@MainActor
final class AppSettingsTests: XCTestCase {

    private func makeEphemeralDefaults() -> UserDefaults {
        // Aparte suite per test → geen kruisbesmetting, niets in .standard.
        UserDefaults(suiteName: "FluisterTests.\(UUID().uuidString)")!
    }

    func testDefaultsWhenStorageEmpty() {
        let settings = AppSettings(defaults: makeEphemeralDefaults())
        XCTAssertEqual(settings.language, "nl")
        XCTAssertFalse(settings.hasCompletedOnboarding)
    }

    func testWriteThroughSurvivesReload() {
        let defaults = makeEphemeralDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.language = "en"
        settings.hasCompletedOnboarding = true

        // Een vers object leest de opgeslagen waarden → overleeft "herstart".
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.language, "en")
        XCTAssertTrue(reloaded.hasCompletedOnboarding)
    }
}
