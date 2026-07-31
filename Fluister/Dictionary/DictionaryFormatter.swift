import Foundation

/// Past een persoonlijke woordenlijst toe: vervangt bekende mis-transcripties (`wrong`) door de
/// juiste spelling (`right`). Puur en deterministisch — geen state, netwerk of UI.
/// Hele-woord (woordgrenzen) zodat deelwoorden en tokens niet geraakt worden; langste `wrong` eerst.
enum DictionaryFormatter {

    static func apply(_ text: String, pairs: [(wrong: String, right: String)]) -> String {
        var out = text
        for pair in pairs.sorted(by: { $0.wrong.count > $1.wrong.count }) {
            let w = pair.wrong.trimmingCharacters(in: .whitespaces)
            guard !w.isEmpty else { continue }
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: w) + "\\b"
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }

            let ns = out as NSString
            var result = ""
            var last = 0
            re.enumerateMatches(in: out, options: [], range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                guard let m = m else { return }
                result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let matched = ns.substring(with: m.range)
                result += adaptCase(of: pair.right, like: matched)
                last = m.range.location + m.range.length
            }
            result += ns.substring(from: last)
            out = result
        }
        return out
    }

    /// Als de match met een hoofdletter begint en `replacement` niet, geef `replacement` een hoofdletter.
    private static func adaptCase(of replacement: String, like matched: String) -> String {
        guard let mFirst = matched.first, mFirst.isUppercase,
              let rFirst = replacement.first, rFirst.isLowercase else { return replacement }
        return String(rFirst).uppercased() + replacement.dropFirst()
    }
}
