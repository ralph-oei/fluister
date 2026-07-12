import Foundation
import Combine

/// Persistente gebruikersvoorkeuren. Single source of truth voor taal + of de
/// eerste-start-onboarding is afgerond. Write-through naar UserDefaults;
/// injecteerbaar zodat tests een ephemeral suite kunnen gebruiken.
@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let language = "language"
        static let onboardingDone = "hasCompletedOnboarding"
    }

    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboardingDone) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // didSet vuurt niet tijdens init → geen premature schrijfactie.
        self.language = defaults.string(forKey: Keys.language) ?? "nl"
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingDone)
    }
}
