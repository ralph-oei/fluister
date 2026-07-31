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
        Button("Corrigeer laatste dictaat…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: FluisterWindow.correction)
        }
        .disabled(controller.lastInsertedText == nil)

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
            switch model.state {
            case .ready:              return "Houd ⌥Space ingedrukt en spreek"
            case .downloading(let f): return "Model downloaden… \(pct(f)) — eenmalig, even geduld"
            case .loading:            return "Model voorbereiden… — eenmalig, even geduld"
            case .notLoaded:          return "Model voorbereiden…"
            case .failed:             return "⚠︎ Model laden mislukt — herstart Fluister"
            }
        case .recording:    return "● Opname… (laat ⌥Space los)"
        case .transcribing: return "Transcriberen…"
        case .inserting:    return "Invoegen…"
        case .blocked(let m): return "⚠︎ \(m)"
        }
    }

    private var statusText: String {
        switch permissions.readiness {
        case .ready:
            // Permissies zijn rond, maar dicteren kan pas als het model klaar is.
            // De eerste keer duurt dat (download + compileren) — dat maken we zichtbaar.
            switch model.state {
            case .ready:              return "Status: klaar om te dicteren"
            case .downloading(let f): return "Status: model downloaden \(pct(f)) (eenmalig)"
            case .loading:            return "Status: model voorbereiden (eenmalig)"
            case .notLoaded:          return "Status: model voorbereiden"
            case .failed:             return "Status: model laden mislukt"
            }
        case .needsMicrophone:    return "Status: microfoon-toegang nodig"
        case .needsAccessibility: return "Status: toegankelijkheid nodig"
        case .blocked:            return "Status: microfoon geweigerd"
        }
    }

    /// Fractie 0…1 → afgerond percentage, bv. "42%".
    private func pct(_ f: Double) -> String {
        "\(Int((max(0, min(1, f)) * 100).rounded()))%"
    }
}
