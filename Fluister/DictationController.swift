import Foundation

// U7 — orkestreert de volledige dicteer-keten:
// hotkey start → opnemen → (hotkey stop) → transcriberen → invoegen → idle.
//
// Dependencies zijn achter naden (AudioRecording, ModelManager, TextInserting)
// zodat de state machine met fakes testbaar is.

@MainActor
final class DictationController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case inserting
        case blocked(String)
    }

    @Published private(set) var phase: Phase = .idle
    var language: String = "nl"

    /// Persoonlijke woordenlijst (fout→goed). Wordt door AppModel bedraad vanuit DictionaryStore.
    var dictionaryPairs: [(wrong: String, right: String)] = []

    /// Minimale opnameduur (~0,3s) om per ongeluk aantikken te negeren.
    private let minSamples = 4_800

    private let recorder: AudioRecording
    private let model: ModelManager
    private let inserter: TextInserting

    init(recorder: AudioRecording, model: ModelManager, inserter: TextInserting) {
        self.recorder = recorder
        self.model = model
        self.inserter = inserter
    }

    /// Sneltoets ingedrukt → start opname (mits model geladen).
    func startDictation() {
        guard phase == .idle else { return }
        guard model.state == .ready, model.transcriber != nil else {
            setBlocked(modelNotReadyHint(model.state))
            return
        }
        do {
            try recorder.start()
            phase = .recording
        } catch {
            setBlocked("opname mislukt: \(error.localizedDescription)")
        }
    }

    /// Sneltoets losgelaten → stop opname en verwerk de samples.
    func stopDictation() {
        guard phase == .recording else { return }
        let samples = recorder.stop()
        Task { await finish(samples: samples) }
    }

    /// Testbare kern: transcribeer en voeg in. Losgekoppeld van de hotkey.
    func finish(samples: [Float]) async {
        guard samples.count >= minSamples else {
            phase = .idle // te kort: stil overslaan
            return
        }
        guard let transcriber = model.transcriber else {
            phase = .idle
            return
        }
        phase = .transcribing
        do {
            let text = try await transcriber.transcribe(
                samples: samples,
                language: whisperLanguageCode(for: language)
            )
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                phase = .idle
                return
            }
            let out = DictionaryFormatter.apply(text, pairs: dictionaryPairs)
            phase = .inserting
            inserter.insert(out)
            phase = .idle
        } catch {
            setBlocked(error.localizedDescription)
        }
    }

    private func setBlocked(_ message: String) {
        phase = .blocked(message)
        // Na een korte tijd terug naar idle zodat de gebruiker opnieuw kan.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if case .blocked = self?.phase { self?.phase = .idle }
        }
    }
}
