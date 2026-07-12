import Foundation

// Beheert het laden/downloaden van het transcriptiemodel en levert de transcriber.
// De release-app draait vast op `small` (KTD2): snel op de Neural Engine, robuust
// op 8GB RAM en betrouwbaar Nederlands. Geen modelkeuze in de UI. `makeTranscriber`
// is injecteerbaar zodat dit testbaar is zonder echte WhisperKit.

@MainActor
final class ModelManager: ObservableObject {
    enum State: Equatable {
        case notLoaded
        case loading
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
        case .loading, .ready: return
        case .notLoaded, .failed: break
        }
        state = .loading
        let t = makeTranscriber(ModelManager.modelName)
        do {
            try await t.prepare()
            transcriber = t
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
