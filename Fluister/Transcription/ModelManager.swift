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
