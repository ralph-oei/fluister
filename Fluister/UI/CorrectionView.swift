import SwiftUI

/// "Corrigeer laatste dictaat": toont de zojuist ingevoegde tekst, laat je 'm fixen, en doet
/// twee dingen tegelijk — het gewijzigde woord komt in je woordenlijst (zodat het de volgende
/// keer meteen goed gaat), en de al-ingevoegde tekst wordt vervangen (fix-now).
///
/// Observeert de controller in plaats van een meegegeven string: een scene-argument wordt
/// eenmalig geëvalueerd bij het opbouwen van de app-body, waardoor het venster leeg bleef.
struct CorrectionView: View {
    @ObservedObject var controller: DictationController
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var edited: String = ""

    private var original: String { controller.lastInsertedText ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Corrigeer laatste dictaat")
                .font(.headline)

            Text("Fix het woord dat Whisper verkeerd schreef. Fluister onthoudt de correctie en past 'm voortaan automatisch toe.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $edited)
                .font(.body)
                .frame(width: 420, height: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            if original.isEmpty {
                Text("Nog geen dictaat om te corrigeren. Dicteer eerst iets.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Werkt het best direct na een dictaat. Staat je cursor ergens anders, dan komt de gecorrigeerde tekst op je klembord.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Annuleren", role: .cancel) { onCancel() }
                Button("Opslaan en corrigeren") { onSave(edited) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || edited == original)
            }
        }
        .padding(20)
        .onAppear { edited = original }
        .onChange(of: controller.lastInsertedText) { _, _ in edited = original }
    }
}
