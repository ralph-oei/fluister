import Foundation

// Beheert het laden/downloaden van het transcriptiemodel en levert de transcriber.
// De release-app draait vast op `small` (KTD2): snel op de Neural Engine, robuust
// op 8GB RAM en betrouwbaar Nederlands. Geen modelkeuze in de UI. `makeTranscriber`
// is injecteerbaar zodat dit testbaar is zonder echte WhisperKit.

@MainActor
final class ModelManager: ObservableObject {
    enum State: Equatable {
        case notLoaded
        case downloading(Double)   // eenmalige model-download, fractie 0…1
        case loading               // gedownload; nu compileren/prewarmen
        case ready
        case failed(String)
    }

    /// Het enige model dat de app gebruikt (small-only, KTD2).
    static let modelName = "small"

    @Published private(set) var state: State = .notLoaded
    private(set) var transcriber: SpeechTranscribing?
    private let makeTranscriber: (String) -> SpeechTranscribing

    init(makeTranscriber: @escaping (String) -> SpeechTranscribing = { WhisperKitTranscriber(model: $0) }) {
        self.makeTranscriber = makeTranscriber
    }

    func load() async {
        switch state {
        case .downloading, .loading, .ready: return
        case .notLoaded, .failed: break
        }
        state = .downloading(0)
        let t = makeTranscriber(ModelManager.modelName)
        do {
            try await t.prepare(onDownloadProgress: { [weak self] frac in
                Task { @MainActor in
                    guard let self else { return }
                    // Alleen bijwerken zolang we nog in de download-fase zitten;
                    // een late callback mag .loading/.ready niet terugzetten.
                    if frac >= 1.0 {
                        if case .downloading = self.state { self.state = .loading }
                    } else if case .downloading = self.state {
                        self.state = .downloading(frac)
                    }
                }
            })
            transcriber = t
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Pure helpers (testbaar, gedeeld door onboarding, menu en ⌥Space-hint)

/// Of het taalmodel klaar is om mee te dicteren (onboarding-stap 3 groen).
func modelStepDone(_ state: ModelManager.State) -> Bool {
    state == .ready
}

/// Of dicteren nú kan: permissies rond én model geladen. Voorkomt dat de onboarding
/// "alles staat klaar" toont terwijl het model nog aan het downloaden is.
func onboardingReadyToDictate(_ readiness: DictationReadiness, _ modelState: ModelManager.State) -> Bool {
    readiness == .ready && modelState == .ready
}

/// Korte uitleg waarom ⌥Space (nog) niks doet — met de download-% als die er is.
/// De eerste keer downloadt het model honderden MB; zonder deze hint lijkt de app kapot.
func modelNotReadyHint(_ state: ModelManager.State) -> String {
    switch state {
    case .downloading(let f): return "Model wordt nog gedownload — \(modelPct(f)) (eenmalig)"
    case .loading:            return "Model wordt voorbereid… (eenmalig)"
    case .notLoaded:          return "Model wordt voorbereid…"
    case .ready:              return "Klaar om te dicteren"
    case .failed:             return "Model laden mislukt — herstart Fluister"
    }
}

/// Fractie 0…1 → afgerond percentage, bv. "42%".
func modelPct(_ f: Double) -> String {
    "\(Int((max(0, min(1, f)) * 100).rounded()))%"
}
