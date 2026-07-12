import SwiftUI
import AppKit

// Menu-inhoud van de shipping-app: status, dicteer-hint, over/site, instellingen,
// en stoppen. Geen model- of testknoppen (release-polish) — het model laadt
// automatisch zodra de permissies "klaar" zijn.
struct MenuBarView: View {
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject var model: ModelManager
    @ObservedObject var controller: DictationController

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Fluister")
            .font(.headline)

        Text(statusText)
            .foregroundStyle(.secondary)

        Divider()

        switch permissions.readiness {
        case .ready:
            Text(dictationHint)
        case .needsMicrophone:
            Button("Sta microfoon toe…") {
                permissions.requestMicrophoneIfNeeded()
            }
        case .needsAccessibility:
            Button("Toegankelijkheid inschakelen…") {
                permissions.promptAccessibility()
                permissions.openAccessibilitySettings()
            }
        case .blocked:
            Button("Open Microfoon-instellingen…") {
                permissions.openMicrophoneSettings()
            }
        }

        Divider()

        // Zelfde pad als het over-venster: eerst de app naar voren halen, dán het
        // venster openen. Menu-bar-apps komen anders niet vanzelf naar de voorgrond.
        Button("Instellingen…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: FluisterWindow.settings)
        }
        .keyboardShortcut(",")

        Button("Over Fluister…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: FluisterWindow.about)
        }

        Link("ralphoei.ai openen", destination: URL(string: "https://ralphoei.ai")!)

        Divider()

        Button("Stop Fluister") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: - Afgeleide teksten

    private var dictationHint: String {
        switch controller.phase {
        case .idle:
            return model.state == .ready
                ? "Houd ⌥Space ingedrukt en spreek"
                : "Model wordt geladen…"
        case .recording:    return "● Opname… (laat ⌥Space los)"
        case .transcribing: return "Transcriberen…"
        case .inserting:    return "Invoegen…"
        case .blocked(let m): return "⚠︎ \(m)"
        }
    }

    private var statusText: String {
        switch permissions.readiness {
        case .ready:              return "Status: klaar"
        case .needsMicrophone:    return "Status: microfoon-toegang nodig"
        case .needsAccessibility: return "Status: toegankelijkheid nodig"
        case .blocked:            return "Status: microfoon geweigerd"
        }
    }
}
