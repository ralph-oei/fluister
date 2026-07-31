import SwiftUI
import AppKit

// Fluister — lokale WhisperFlow-variant (macOS menu-bar dicteer-app).
// ⌥Space ingedrukt houden → praten → loslaten → getranscribeerde tekst op de
// cursor. 100% lokaal (WhisperKit op de Neural Engine), geen cloud.

/// Venster-ids voor de losse scenes (eerste-start-onboarding + over-venster).
enum FluisterWindow {
    static let onboarding = "onboarding"
    static let about = "about"
    static let settings = "settings"
    static let correction = "correction"
}

@main
struct FluisterApp: App {
    @StateObject private var app = AppModel()
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                permissions: app.permissions,
                model: app.model,
                controller: app.controller
            )
        } label: {
            MenuBarLabel(
                app: app,
                permissions: app.permissions,
                controller: app.controller,
                settings: app.settings
            )
        }
        .menuBarExtraStyle(.menu)

        // Bewust een gewone Window-scene i.p.v. de standaard Settings-scene: voor
        // een menu-bar-app (accessory) haalt de Settings-scene de app niet naar
        // voren, waardoor het venster achter andere apps verdween of stil niet
        // opende. Nu via hetzelfde bewezen pad als het over-venster (NSApp.activate
        // + openWindow) in MenuBarView.
        Window("Instellingen", id: FluisterWindow.settings) {
            SettingsView(
                settings: app.settings,
                launchAtLogin: app.launchAtLogin,
                dictionary: app.dictionary,
                onHotkeyChange: { app.applyHotkey($0) }
            )
        }
        .windowResizability(.contentSize)

        Window("Welkom bij Fluister", id: FluisterWindow.onboarding) {
            OnboardingView(permissions: app.permissions, settings: app.settings, model: app.model)
        }
        .windowResizability(.contentSize)

        Window("Over Fluister", id: FluisterWindow.about) {
            AboutView()
        }
        .windowResizability(.contentSize)

        Window("Corrigeer laatste dictaat", id: FluisterWindow.correction) {
            CorrectionView(
                controller: app.controller,
                onSave: { edited in
                    app.correctLastDictation(edited: edited)
                    dismissWindow(id: FluisterWindow.correction)
                },
                onCancel: { dismissWindow(id: FluisterWindow.correction) }
            )
        }
        .windowResizability(.contentSize)
    }
}

/// Het menubalk-icoon, dat reageert op status en opname. Opent bij eerste start
/// (zolang de onboarding niet is afgerond) het welkomstvenster.
struct MenuBarLabel: View {
    @ObservedObject var app: AppModel
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject var controller: DictationController
    @ObservedObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: iconName)
            .onAppear {
                guard !settings.hasCompletedOnboarding else { return }
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: FluisterWindow.onboarding)
            }
            // ⌥Space terwijl het model nog laadt → haal het voortgang-venster naar
            // voren, zodat de eerste-start-download zichtbaar wordt.
            .onChange(of: app.modelHintPulse) { _, _ in
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: FluisterWindow.onboarding)
            }
    }

    private var iconName: String {
        switch controller.phase {
        case .recording: return "waveform"
        case .transcribing, .inserting: return "waveform.badge.magnifyingglass"
        case .blocked: return "mic.slash"
        case .idle: return permissions.readiness == .ready ? "mic.fill" : "mic.slash"
        }
    }
}
