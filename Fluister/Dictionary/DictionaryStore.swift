import Foundation
import Combine

struct DictionaryEntry: Codable, Equatable {
    var wrong: String
    var right: String
}

/// Persistente persoonlijke woordenlijst (fout→goed-paren) als JSON. `url` is injecteerbaar zodat
/// tests een ephemeral bestand gebruiken (zelfde patroon als AppSettings(defaults:)).
@MainActor
final class DictionaryStore: ObservableObject {

    /// nonisolated: wordt als default-argument van `init` geëvalueerd, en dat gebeurt buiten de
    /// MainActor-isolatie van deze klasse. Raakt alleen FileManager, dus veilig.
    nonisolated static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fluister", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("dictionary.json")
    }

    @Published private(set) var entries: [DictionaryEntry] = []
    private let url: URL

    init(url: URL = DictionaryStore.defaultURL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
            entries = decoded
        }
    }

    var pairs: [(wrong: String, right: String)] {
        entries.map { ($0.wrong, $0.right) }
    }

    func add(wrong: String, right: String) {
        let w = wrong.trimmingCharacters(in: .whitespaces)
        let r = right.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty, !r.isEmpty else { return }
        entries.removeAll { $0.wrong.caseInsensitiveCompare(w) == .orderedSame }
        entries.append(DictionaryEntry(wrong: w, right: r))
        save()
    }

    func remove(wrong: String) {
        entries.removeAll { $0.wrong.caseInsensitiveCompare(wrong) == .orderedSame }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) { try? data.write(to: url) }
    }
}
