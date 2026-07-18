import SwiftUI

/// Begeleide eerste-start: loodst de gebruiker door microfoon- en toegankelijkheids-
/// toestemming tot alles klaar is, zodat 'ie niet zelf door Systeeminstellingen hoeft
/// te zoeken. Verschijnt zolang `hasCompletedOnboarding` false is; de readiness-status
/// werkt live bij dankzij de polling in PermissionsManager.
struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var model: ModelManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welkom bij Fluister")
                    .font(.largeTitle.bold())
                Text("Dicteer overal op je Mac — 100% lokaal. Zet twee toestemmingen aan en je kunt beginnen.")
                    .foregroundStyle(.secondary)
            }

            micStep
            accessibilityStep
            modelStep

            Divider()

            if onboardingReadyToDictate(permissions.readiness, model.state) {
                Label("Alles staat klaar. Houd ⌥Space ingedrukt en spreek.",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Aan de slag") { finish() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Text(bottomHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Later") { finish() }
                        .buttonStyle(.link)
                }
            }
        }
        .padding(28)
        .frame(width: 470)
    }

    // MARK: - Stappen

    @ViewBuilder
    private var micStep: some View {
        stepRow(
            done: microphoneStepDone(permissions.readiness),
            index: "1",
            title: "Microfoon",
            detail: "Om je stem lokaal te transcriberen. Er wordt niets naar de cloud gestuurd."
        ) {
            if permissions.readiness == .blocked {
                Button("Open Microfoon-instellingen…") {
                    permissions.openMicrophoneSettings()
                }
            } else {
                Button("Microfoon toestaan") {
                    permissions.requestMicrophoneIfNeeded()
                }
            }
        }
    }

    @ViewBuilder
    private var accessibilityStep: some View {
        stepRow(
            done: accessibilityStepDone(permissions.readiness),
            index: "2",
            title: "Toegankelijkheid",
            detail: "Om de getranscribeerde tekst op je cursor in te voegen. Fluister leest je toetsaanslagen niet."
        ) {
            Button("Toegankelijkheid openen…") {
                permissions.promptAccessibility()
                permissions.openAccessibilitySettings()
            }
        }
    }

    @ViewBuilder
    private var modelStep: some View {
        stepRow(
            done: modelStepDone(model.state),
            index: "3",
            title: "Taalmodel",
            detail: "Wordt bij de eerste start eenmalig gedownload (honderden MB) en draait daarna volledig lokaal, ook offline."
        ) {
            modelProgress
        }
    }

    @ViewBuilder
    private var modelProgress: some View {
        switch model.state {
        case .downloading(let f):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: f)
                    .frame(maxWidth: 280)
                Text("\(modelPct(f)) gedownload — eenmalig")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Model wordt voorbereid…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .notLoaded:
            Text("Start zodra de microfoon en toegankelijkheid groen zijn.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let m):
            Text("Laden mislukt: \(m). Herstart Fluister.")
                .font(.caption)
                .foregroundStyle(.red)
        case .ready:
            EmptyView()
        }
    }

    /// Contextuele regel onderaan zolang dicteren nog niet kan.
    private var bottomHint: String {
        if permissions.readiness == .ready && !modelStepDone(model.state) {
            return "Nog heel even: het taalmodel wordt gedownload. Je kunt dit venster open laten; dicteren kan zodra stap 3 groen is."
        }
        return "Zodra alle stappen groen zijn, kun je meteen dicteren."
    }

    @ViewBuilder
    private func stepRow<Action: View>(
        done: Bool,
        index: String,
        title: String,
        detail: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(index).circle")
                .font(.title2)
                .foregroundStyle(done ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
                if !done { action() }
            }
            Spacer(minLength: 0)
        }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        dismiss()
    }
}
