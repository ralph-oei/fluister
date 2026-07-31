import Foundation

/// Leidt fout→goed-paren af uit een correctie: vergelijkt de oude transcriptie met de door de
/// gebruiker gecorrigeerde versie, woord voor woord. Puur.
/// v1: alleen bij gelijk aantal woorden (de gangbare "één woord gefixt"-correctie); anders leeg.
enum DictionaryDiff {

    static func pairs(old: String, new: String) -> [(wrong: String, right: String)] {
        let o = old.split(separator: " ").map(String.init)
        let n = new.split(separator: " ").map(String.init)
        guard o.count == n.count else { return [] }

        var result: [(wrong: String, right: String)] = []
        for (ow, nw) in zip(o, n) where ow != nw {
            let wrong = trimEdges(ow)
            let right = trimEdges(nw)
            // Exacte vergelijking, niet case-insensitief: "zelesta" → "Zelesta" is juist het
            // hoofdgeval van een woordenlijst (eigennamen die Whisper met kleine letter schrijft).
            // Een case-insensitieve guard zou die stil weggooien; alleen-interpunctie-verschillen
            // vallen al af doordat trimEdges beide kanten strippt.
            guard !wrong.isEmpty, !right.isEmpty, wrong != right else { continue }
            result.append((wrong, right))
        }
        return result
    }

    /// Strip niet-alfanumerieke tekens aan begin en eind (leestekens rond het woord).
    private static func trimEdges(_ s: String) -> String {
        let set = CharacterSet.alphanumerics.inverted
        var chars = Array(s)
        while let f = chars.first, String(f).rangeOfCharacter(from: set) != nil { chars.removeFirst() }
        while let l = chars.last, String(l).rangeOfCharacter(from: set) != nil { chars.removeLast() }
        return String(chars)
    }
}
