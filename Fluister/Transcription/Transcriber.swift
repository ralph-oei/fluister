import Foundation
import WhisperKit

// U5 — lokale transcriptie via WhisperKit.
//
// `SpeechTranscribing` is de naad waarop we testen (fake in de tests); de echte
// `WhisperKitTranscriber` draait het model op de Neural Engine. `whisperLanguageCode`
// is pure taal-normalisatie (auto → nil = laat WhisperKit de taal detecteren).

protocol SpeechTranscribing {
    func prepare() async throws
    func transcribe(samples: [Float], language: String?) async throws -> String
}

/// Zet een UI-taalkeuze om naar een Whisper-taalcode. "auto"/leeg → nil (auto-detect).
func whisperLanguageCode(for selection: String) -> String? {
    let s = selection.lowercased()
    return (s == "auto" || s.isEmpty) ? nil : s
}

actor WhisperKitTranscriber: SpeechTranscribing {
    private var pipe: WhisperKit?
    private let model: String

    init(model: String) {
        self.model = model
    }

    /// Laadt, downloadt en prewarmt het model — zodat het zware compileer/laadwerk
    /// hier gebeurt (bij "Model laden") en de eerste transcriptie al snel is.
    func prepare() async throws {
        guard pipe == nil else { return }
        pipe = try await WhisperKit(WhisperKitConfig(model: model, prewarm: true, load: true))
    }

    func transcribe(samples: [Float], language: String?) async throws -> String {
        if pipe == nil { try await prepare() }
        guard let pipe else { return "" }
        let options = DecodingOptions(task: .transcribe, language: language)
        let batch = await pipe.transcribe(audioArrays: [samples], decodeOptions: options)
        let results = (batch.first ?? nil) ?? []
        return results.map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
