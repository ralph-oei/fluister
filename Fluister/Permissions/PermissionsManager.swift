import Foundation
import AVFoundation
import ApplicationServices
import AppKit

// U2 — permissiebeheer voor Microfoon (U4) en Toegankelijkheid (U6, tekst-insertie).
//
// Microfoon heeft 3 relevante toestanden; Toegankelijkheid (AXIsProcessTrusted)
// is binair (wel/niet toegekend, geen "notDetermined"). De combinatie-logica
// (`dictationReadiness`) is een pure functie zodat 'ie zonder systeemcalls
// testbaar is. De manager wrapt de echte systeem-providers, die in tests
// vervangen worden door fakes.

enum MicPermission: Equatable {
    case notDetermined
    case granted
    case denied
}

enum DictationReadiness: Equatable {
    case ready              // mic toegekend + accessibility vertrouwd
    case needsMicrophone    // mic nog niet bepaald: we kunnen 't vragen
    case needsAccessibility // mic ok, accessibility ontbreekt nog
    case blocked            // mic geweigerd: alleen op te lossen in Systeeminstellingen
}

/// Pure combinatie-logica — geen systeemcalls, volledig unit-testbaar.
func dictationReadiness(mic: MicPermission, accessibilityTrusted: Bool) -> DictationReadiness {
    switch mic {
    case .notDetermined:
        return .needsMicrophone
    case .denied:
        return .blocked
    case .granted:
        return accessibilityTrusted ? .ready : .needsAccessibility
    }
}

// Afgeleide stap-status voor de onboarding (U3). Pure functies op de gecombineerde
// readiness, zodat de onboarding-UI per stap "klaar" kan tonen zonder aparte
// per-permissie state. Microfoon is toegekend zodra we voorbij mic-blokkades zijn
// (ready óf needsAccessibility); toegankelijkheid is pas klaar bij volledige ready.

/// Of de microfoon-stap als afgerond mag tonen.
func microphoneStepDone(_ readiness: DictationReadiness) -> Bool {
    readiness == .ready || readiness == .needsAccessibility
}

/// Of de toegankelijkheid-stap als afgerond mag tonen.
func accessibilityStepDone(_ readiness: DictationReadiness) -> Bool {
    readiness == .ready
}

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var readiness: DictationReadiness = .needsMicrophone

    private let micStatusProvider: () -> MicPermission
    private let accessibilityTrustedProvider: () -> Bool
    private let requestMicAccess: (@escaping (Bool) -> Void) -> Void
    private var pollTimer: Timer?

    init(
        micStatusProvider: @escaping () -> MicPermission = PermissionsManager.systemMicStatus,
        accessibilityTrustedProvider: @escaping () -> Bool = { AXIsProcessTrusted() },
        requestMicAccess: @escaping (@escaping (Bool) -> Void) -> Void = PermissionsManager.systemRequestMic,
        autoPoll: Bool = true
    ) {
        self.micStatusProvider = micStatusProvider
        self.accessibilityTrustedProvider = accessibilityTrustedProvider
        self.requestMicAccess = requestMicAccess
        refresh()
        // Accessibility kent geen change-callback; pollen zodat de status vanzelf
        // bijwerkt nadat de gebruiker 'm in Systeeminstellingen toekent.
        if autoPoll {
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }

    deinit { pollTimer?.invalidate() }

    /// Herbereken de status op basis van de huidige systeemtoestand.
    /// Accessibility kent geen callback, dus we pollen dit (bv. bij menu-openen).
    func refresh() {
        readiness = dictationReadiness(
            mic: micStatusProvider(),
            accessibilityTrusted: accessibilityTrustedProvider()
        )
    }

    /// Vraagt mic-toegang alleen als die nog niet bepaald is; ververst daarna.
    /// `completion` vuurt nadat de status is bijgewerkt (handig voor tests/UI).
    func requestMicrophoneIfNeeded(completion: (() -> Void)? = nil) {
        guard micStatusProvider() == .notDetermined else {
            refresh()
            completion?()
            return
        }
        requestMicAccess { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                completion?()
            }
        }
    }

    /// Toont eenmalig de systeem-dialoog voor Toegankelijkheid.
    func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func openMicrophoneSettings() { openSettings(pane: "Privacy_Microphone") }
    func openAccessibilitySettings() { openSettings(pane: "Privacy_Accessibility") }

    // MARK: - Systeem-providers (default)

    static func systemMicStatus() -> MicPermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    static func systemRequestMic(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    private func openSettings(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
