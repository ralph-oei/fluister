import Foundation
import WhisperKit

// U5 — lokale transcriptie via WhisperKit.
//
// `SpeechTranscribing` is de naad waarop we testen (fake in de tests); de echte
// `WhisperKitTranscriber` draait het model op de Neural Engine. `whisperLanguageCode`
// is pure taal-normalisatie (auto → nil = laat WhisperKit de taal detecteren).

protocol SpeechTranscribing {
    /// Downloadt (eenmalig) en laadt het model. `onDownloadProgress` rapporteert de
    /// download-fractie (0…1) zodat de UI echte voortgang kan tonen i.p.v. een
    /// statische "laden"-tekst waar gebruikers op afhaken.
    func prepare(onDownloadProgress: @escaping @Sendable (Double) -> Void) async throws
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

    /// Downloadt (eenmalig, mét voortgang) en laadt/prewarmt het model — zodat het
    /// zware compileer/laadwerk hier gebeurt en de eerste transcriptie al snel is.
    func prepare(onDownloadProgress: @escaping @Sendable (Double) -> Void) async throws {
        guard pipe == nil else { return }
        // Splits download en laden: de download levert echte voortgang; daarna
        // laden we uit de lokale map zonder opnieuw te downloaden.
        let folder = try await WhisperKit.download(variant: model, progressCallback: { progress in
            onDownloadProgress(progress.fractionCompleted)
        })
        pipe = try await WhisperKit(WhisperKitConfig(
            model: model, modelFolder: folder.path, prewarm: true, load: true, download: false))
    }

    func transcribe(samples: [Float], language: String?) async throws -> String {
        if pipe == nil { try await prepare(onDownloadProgress: { _ in }) }
        guard let pipe else { return "" }
        let options = DecodingOptions(task: .transcribe, language: language)
        let batch = await pipe.transcribe(audioArrays: [samples], decodeOptions: options)
        let results = (batch.first ?? nil) ?? []
        return results.map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
