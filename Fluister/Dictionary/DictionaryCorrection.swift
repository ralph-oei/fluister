import Foundation

/// Verwerkt één correctie: leidt paren af, slaat ze op, en voert fix-now uit
/// (alleen als er iets wijzigde).
enum DictionaryCorrection {
    @MainActor
    static func apply(old: String, edited: String, store: DictionaryStore, inserter: TextInserting) {
        let pairs = DictionaryDiff.pairs(old: old, new: edited)
        guard !pairs.isEmpty else { return }
        for p in pairs { store.add(wrong: p.wrong, right: p.right) }
        inserter.replaceLast(oldText: old, with: edited)
    }
}
