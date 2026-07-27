# Fluister Personal Dictionary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Een persoonlijke woordenlijst (fout→goed-paren) die Fluister deterministisch toepast op elk dictaat, plus een "corrigeer laatste dictaat"-flow die van je correctie leert én de al-ingevoegde tekst meteen vervangt (fix-now).

**Architecture:** Pure, testbare logica (`DictionaryFormatter` = vervanging, `DictionaryDiff` = woord-diff) los van UI/keten, zoals de bestaande `AppSettings`/naden-splitsing. Toepassing in `DictationController.finish()` (bewezen plek tussen transcribe en insert). Persistente store als JSON. Correctie-flow + beheer-UI in SwiftUI.

**Tech Stack:** Swift 5, SwiftUI, XcodeGen (`project.yml`), XCTest via `./test.sh`. Geen nieuwe dependencies. WhisperKit ongewijzigd (prompt-bias is uitgesteld, zie spec).

## Global Constraints

- **Geen nieuwe dependencies, alles lokaal.** Puur tekst-post-processing + JSON-opslag.
- **Pure logica** (`DictionaryFormatter`, `DictionaryDiff`) importeert alleen Foundation; geen UI/netwerk/state.
- **Testcommando:** `./test.sh` (volledige XCTest-suite via xcodebuild). Nieuwe bronbestanden vergen `xcodegen generate` vóór testen. Suite moet groen blijven.
- **False-positive-discipline (geleerd van leestekens):** vervanging alleen op **hele woorden** (woordgrenzen), langste `wrong` eerst; geen deelwoorden.
- **Nederlands** in alle UI-teksten.
- **Spec:** `docs/superpowers/specs/2026-07-27-fluister-personal-dictionary-design.md`. Scope v1 = **replace-first** (geen prompt-bias) + **fix-now** correctie-flow.
- **Geen release in dit plan** — versie-bump/DMG is een aparte stap (batchen met de UX-hint + de Info.plist-versiebug-fix, zie STATUS).

## File Structure

| Bestand | Verantwoordelijkheid | Nieuw/gewijzigd |
|---------|----------------------|-----------------|
| `Fluister/Dictionary/DictionaryFormatter.swift` | Pure: hele-woord, case-bewuste vervanging van paren | **nieuw** |
| `Fluister/Dictionary/DictionaryDiff.swift` | Pure: woord-diff oud vs nieuw → fout→goed-paren | **nieuw** |
| `Fluister/Dictionary/DictionaryStore.swift` | Persistente JSON-store van paren (injecteerbaar pad) | **nieuw** |
| `Fluister/DictationController.swift` | Past paren toe in `finish()`; onthoudt laatste tekst | gewijzigd |
| `Fluister/AppModel.swift` | Bezit de store; bedraadt paren → controller; `correctLastDictation` | gewijzigd |
| `Fluister/Insertion/TextInserter.swift` | `replaceLast(oldText:with:)` voor fix-now | gewijzigd |
| `Fluister/UI/CorrectionView.swift` | Venster: laatste tekst bewerken → leren + fix-now | **nieuw** |
| `Fluister/UI/SettingsView.swift` | Beheer van paren (lijst + toevoegen/verwijderen) | gewijzigd |
| `Fluister/UI/MenuBarView.swift` | Menu-item "Corrigeer laatste dictaat" | gewijzigd |
| `Fluister/FluisterApp.swift` | `Window`-scene voor CorrectionView | gewijzigd |
| `FluisterTests/*` | Unit-tests per pure unit + wiring | **nieuw** |

---

## Task 1: `DictionaryFormatter` — pure vervanging

**Files:**
- Create: `Fluister/Dictionary/DictionaryFormatter.swift`
- Test: `FluisterTests/DictionaryFormatterTests.swift`

**Interfaces:**
- Produces: `enum DictionaryFormatter { static func apply(_ text: String, pairs: [(wrong: String, right: String)]) -> String }`. Hele-woord, case-ongevoelige match op `wrong`, vervangen door `right`; langste `wrong` eerst; hoofdletter-behoud (begint de match met een hoofdletter, dan `right` ook).

- [ ] **Step 1: Schrijf de falende test**

Create `FluisterTests/DictionaryFormatterTests.swift`:

```swift
import XCTest
@testable import Fluister

final class DictionaryFormatterTests: XCTestCase {

    func testVervangtHeelWoord() {
        XCTAssertEqual(
            DictionaryFormatter.apply("ik gebruik naslak elke dag", pairs: [("naslak", "Naslag")]),
            "ik gebruik Naslag elke dag")
    }

    func testCaseOngevoeligeMatch() {
        XCTAssertEqual(
            DictionaryFormatter.apply("NASLAK werkt", pairs: [("naslak", "Naslag")]),
            "Naslag werkt")
    }

    func testHoofdletterBehoud() {
        // match begint met hoofdletter, right is kleine letter → right krijgt hoofdletter
        XCTAssertEqual(
            DictionaryFormatter.apply("Naslak hier", pairs: [("naslak", "naslag")]),
            "Naslag hier")
    }

    func testGeenDeelwoord() {
        // 'naslakken' bevat 'naslak' maar mag niet geraakt worden (woordgrens)
        XCTAssertEqual(
            DictionaryFormatter.apply("naslakken zijn traag", pairs: [("naslak", "Naslag")]),
            "naslakken zijn traag")
    }

    func testLangstePaarEerst() {
        let pairs = [("dis", "Dis"), ("van dis", "Van Dis")]
        XCTAssertEqual(
            DictionaryFormatter.apply("boeken van dis", pairs: pairs),
            "boeken Van Dis")
    }

    func testMeerdereVoorkomens() {
        XCTAssertEqual(
            DictionaryFormatter.apply("naslak en naslak", pairs: [("naslak", "Naslag")]),
            "Naslag en Naslag")
    }

    func testLegePairsOngewijzigd() {
        XCTAssertEqual(DictionaryFormatter.apply("gewoon een zin", pairs: []), "gewoon een zin")
    }
}
```

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `xcodegen generate && ./test.sh`
Expected: FAIL — "cannot find 'DictionaryFormatter' in scope".

- [ ] **Step 3: Schrijf de implementatie**

Create `Fluister/Dictionary/DictionaryFormatter.swift`:

```swift
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
```

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS (7 nieuwe tests groen).

- [ ] **Step 5: Commit**

```bash
git add Fluister/Dictionary/DictionaryFormatter.swift FluisterTests/DictionaryFormatterTests.swift
git commit -m "feat: pure DictionaryFormatter (hele-woord paren-vervanging)"
```

---

## Task 2: `DictionaryDiff` — woord-diff → paren

**Files:**
- Create: `Fluister/Dictionary/DictionaryDiff.swift`
- Test: `FluisterTests/DictionaryDiffTests.swift`

**Interfaces:**
- Produces: `enum DictionaryDiff { static func pairs(old: String, new: String) -> [(wrong: String, right: String)] }`. Vergelijkt woord-voor-woord (whitespace-split). Bij gelijk aantal woorden: elk verschillend paar wordt een `(oud, nieuw)`-paar, met randinterpunctie eraf. Verschillend aantal woorden → `[]` (v1-beperking).

- [ ] **Step 1: Schrijf de falende test**

Create `FluisterTests/DictionaryDiffTests.swift`:

```swift
import XCTest
@testable import Fluister

final class DictionaryDiffTests: XCTestCase {

    func testEenWoordGewijzigd() {
        let p = DictionaryDiff.pairs(old: "ik ga naar naslak", new: "ik ga naar Naslag")
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p.first?.wrong, "naslak")
        XCTAssertEqual(p.first?.right, "Naslag")
    }

    func testTweeWoordenGewijzigd() {
        let p = DictionaryDiff.pairs(old: "zelesta en naslak", new: "Zelesta en Naslag")
        XCTAssertEqual(p.count, 2)
    }

    func testGeenWijziging() {
        XCTAssertTrue(DictionaryDiff.pairs(old: "alles klopt", new: "alles klopt").isEmpty)
    }

    func testRandinterpunctieEraf() {
        // 'naslak.' → 'Naslag.' levert het paar zonder de punt
        let p = DictionaryDiff.pairs(old: "hallo naslak.", new: "hallo Naslag.")
        XCTAssertEqual(p.first?.wrong, "naslak")
        XCTAssertEqual(p.first?.right, "Naslag")
    }

    func testAlleenInterpunctieVerschil() {
        // 'test' vs 'test.' → geen woord-verschil na trimmen → geen paar
        XCTAssertTrue(DictionaryDiff.pairs(old: "een test", new: "een test.").isEmpty)
    }

    func testVerschillendAantalWoordenGeeftNiets() {
        XCTAssertTrue(DictionaryDiff.pairs(old: "ik ga", new: "ik ga naar huis").isEmpty)
    }
}
```

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `xcodegen generate && ./test.sh`
Expected: FAIL — "cannot find 'DictionaryDiff' in scope".

- [ ] **Step 3: Schrijf de implementatie**

Create `Fluister/Dictionary/DictionaryDiff.swift`:

```swift
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
            guard !wrong.isEmpty, !right.isEmpty, wrong.lowercased() != right.lowercased() else { continue }
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
```

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS (6 nieuwe tests groen).

- [ ] **Step 5: Commit**

```bash
git add Fluister/Dictionary/DictionaryDiff.swift FluisterTests/DictionaryDiffTests.swift
git commit -m "feat: pure DictionaryDiff (woord-diff naar fout->goed-paren)"
```

---

## Task 3: `DictionaryStore` — persistente JSON-store

**Files:**
- Create: `Fluister/Dictionary/DictionaryStore.swift`
- Test: `FluisterTests/DictionaryStoreTests.swift`

**Interfaces:**
- Consumes: niets.
- Produces:
  - `struct DictionaryEntry: Codable, Equatable { var wrong: String; var right: String }`
  - `@MainActor final class DictionaryStore: ObservableObject`
    - `init(url: URL = DictionaryStore.defaultURL)` — laadt bestaande JSON van `url`.
    - `@Published private(set) var entries: [DictionaryEntry]`
    - `var pairs: [(wrong: String, right: String)]` — `entries` als tuples voor `DictionaryFormatter`.
    - `func add(wrong: String, right: String)` — dedup op `wrong` (case-ongevoelig), schrijft weg.
    - `func remove(wrong: String)` — verwijdert (case-ongevoelig), schrijft weg.

- [ ] **Step 1: Schrijf de falende test**

Create `FluisterTests/DictionaryStoreTests.swift`:

```swift
import XCTest
@testable import Fluister

@MainActor
final class DictionaryStoreTests: XCTestCase {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fluister-dict-\(UUID().uuidString).json")
    }

    func testLeegBijStart() {
        let s = DictionaryStore(url: tempURL())
        XCTAssertTrue(s.entries.isEmpty)
    }

    func testAddEnPersistentie() {
        let url = tempURL()
        let s = DictionaryStore(url: url)
        s.add(wrong: "naslak", right: "Naslag")
        // verse instance leest hetzelfde bestand terug
        let s2 = DictionaryStore(url: url)
        XCTAssertEqual(s2.entries, [DictionaryEntry(wrong: "naslak", right: "Naslag")])
    }

    func testDedupOpWrong() {
        let s = DictionaryStore(url: tempURL())
        s.add(wrong: "naslak", right: "Naslag")
        s.add(wrong: "NASLAK", right: "Naslag2") // zelfde wrong, case-ongevoelig
        XCTAssertEqual(s.entries.count, 1)
        XCTAssertEqual(s.entries.first?.right, "Naslag2") // laatste wint
    }

    func testRemove() {
        let s = DictionaryStore(url: tempURL())
        s.add(wrong: "naslak", right: "Naslag")
        s.remove(wrong: "naslak")
        XCTAssertTrue(s.entries.isEmpty)
    }

    func testPairs() {
        let s = DictionaryStore(url: tempURL())
        s.add(wrong: "naslak", right: "Naslag")
        XCTAssertEqual(s.pairs.first?.wrong, "naslak")
        XCTAssertEqual(s.pairs.first?.right, "Naslag")
    }
}
```

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `xcodegen generate && ./test.sh`
Expected: FAIL — "cannot find 'DictionaryStore' in scope".

- [ ] **Step 3: Schrijf de implementatie**

Create `Fluister/Dictionary/DictionaryStore.swift`:

```swift
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

    static var defaultURL: URL {
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
```

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS (5 nieuwe tests groen).

- [ ] **Step 5: Commit**

```bash
git add Fluister/Dictionary/DictionaryStore.swift FluisterTests/DictionaryStoreTests.swift
git commit -m "feat: DictionaryStore (persistente fout->goed-paren als JSON)"
```

---

## Task 4: Vervanging toepassen in `finish()` + AppModel-bedrading

**Files:**
- Modify: `Fluister/DictationController.swift`
- Modify: `Fluister/AppModel.swift`
- Test: `FluisterTests/DictationControllerTests.swift`

**Interfaces:**
- Consumes: `DictionaryFormatter.apply` (Task 1); `DictionaryStore` (Task 3).
- Produces: `DictationController.dictionaryPairs: [(wrong: String, right: String)]` (default leeg); ingevoegde tekst is met de paren toegepast.

- [ ] **Step 1: Schrijf de falende test**

Append to `FluisterTests/DictationControllerTests.swift`:

```swift
    func testFinishPastWoordenlijstToe() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "ik gebruik naslak")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)
        c.dictionaryPairs = [("naslak", "Naslag")]

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertEqual(inserter.inserted, ["ik gebruik Naslag"])
    }

    func testFinishZonderParenOngewijzigd() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "ik gebruik naslak")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertEqual(inserter.inserted, ["ik gebruik naslak"])
    }
```

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `./test.sh`
Expected: FAIL — "value of type 'DictationController' has no member 'dictionaryPairs'".

- [ ] **Step 3: Implementatie**

In `Fluister/DictationController.swift`, naast `var language`:

```swift
    var dictionaryPairs: [(wrong: String, right: String)] = []
```

In `finish(samples:)`, ná de lege-check op de transcriptie en vóór `inserter.insert(...)`, vervang het invoeg-blok zodat het de paren toepast:

```swift
            let out = DictionaryFormatter.apply(text, pairs: dictionaryPairs)
            phase = .inserting
            inserter.insert(out)
            phase = .idle
```

In `Fluister/AppModel.swift`: voeg de store toe en bedraad 'm naar de controller.
- Property: `let dictionary = DictionaryStore()`
- In `init()` ná `controller.language = settings.language`: `controller.dictionaryPairs = dictionary.pairs`
- Subscriptie (zoals `settings.$language`): `dictionary.$entries.dropFirst().removeDuplicates().sink { [weak self] _ in self?.controller.dictionaryPairs = self?.dictionary.pairs ?? [] }.store(in: &cancellables)`

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS (2 nieuwe tests groen; suite groen).

- [ ] **Step 5: Commit**

```bash
git add Fluister/DictationController.swift Fluister/AppModel.swift FluisterTests/DictationControllerTests.swift
git commit -m "feat: pas woordenlijst toe in dicteer-keten + AppModel-bedrading"
```

---

## Task 5: Laatste dictaat onthouden + `TextInserter.replaceLast`

**Files:**
- Modify: `Fluister/DictationController.swift`
- Modify: `Fluister/Insertion/TextInserter.swift`
- Test: `FluisterTests/DictationControllerTests.swift`

**Interfaces:**
- Produces:
  - `DictationController.lastInsertedText: String?` — de laatst ingevoegde tekst (nil tot eerste invoeging).
  - `TextInserting.replaceLast(oldText: String, with newText: String)` — protocol-methode voor fix-now (verwijdert `oldText` via backspaces, plakt `newText`).

- [ ] **Step 1: Schrijf de falende test**

Breid `FakeInserter` in `FluisterTests/DictationControllerTests.swift` uit en voeg een test toe:

```swift
// In FakeInserter:
    private(set) var replaced: [(old: String, new: String)] = []
    func replaceLast(oldText: String, with newText: String) { replaced.append((oldText, newText)) }
```

```swift
    func testFinishOnthoudtLaatsteTekst() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "ik gebruik naslak")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)
        c.dictionaryPairs = [("naslak", "Naslag")]

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertEqual(c.lastInsertedText, "ik gebruik Naslag")
    }
```

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `./test.sh`
Expected: FAIL — `TextInserting` heeft geen `replaceLast` / `lastInsertedText` ontbreekt.

- [ ] **Step 3: Implementatie**

In `Fluister/DictationController.swift`:
- Property: `private(set) var lastInsertedText: String?`
- In `finish(samples:)`, direct ná `inserter.insert(out)`: `lastInsertedText = out`

In `Fluister/Insertion/TextInserter.swift`:
- Voeg aan het `TextInserting`-protocol toe: `func replaceLast(oldText: String, with newText: String)`
- Implementatie in `TextInserter`: respecteer de bestaande secure-input-guard; stuur `oldText.count` backspaces (CGEvent keycode `51` = delete) en plak daarna `newText` via het bestaande paste-pad. Bij actieve secure input: niet vervangen, val terug op klembord (zet `newText` op het klembord). Volg exact het bestaande CGEvent/secure-input-patroon in dit bestand.

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Fluister/DictationController.swift Fluister/Insertion/TextInserter.swift FluisterTests/DictationControllerTests.swift
git commit -m "feat: onthoud laatste dictaat + TextInserter.replaceLast (fix-now basis)"
```

---

## Task 6: Correctie-flow — leren + fix-now (logica + venster)

**Files:**
- Modify: `Fluister/AppModel.swift` (testbare `correctLastDictation`)
- Create: `Fluister/UI/CorrectionView.swift`
- Modify: `Fluister/UI/MenuBarView.swift` (menu-item)
- Modify: `Fluister/FluisterApp.swift` (Window-scene)
- Test: `FluisterTests/AppModelDictionaryTests.swift`

**Interfaces:**
- Consumes: `DictionaryDiff.pairs` (Task 2), `DictionaryStore.add` (Task 3), `TextInserting.replaceLast` (Task 5), `DictationController.lastInsertedText` (Task 5).
- Produces: `AppModel.correctLastDictation(edited: String)` — diff't `lastInsertedText` vs `edited`, slaat de paren op in de store, en roept `inserter.replaceLast(old, edited)` aan (fix-now).

- [ ] **Step 1: Schrijf de falende test**

Create `FluisterTests/AppModelDictionaryTests.swift`. Omdat `AppModel` veel bedraadt, test de correctie-logica via een kleine helper die dezelfde stappen doet met injecteerbare store + inserter. Als `AppModel` lastig te instantiëren is in een test, extraheer de logica naar een vrije functie/`enum`:

```swift
import XCTest
@testable import Fluister

@MainActor
final class AppModelDictionaryTests: XCTestCase {

    func testCorrectieLeertPaarEnDoetFixNow() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dict-\(UUID().uuidString).json")
        let store = DictionaryStore(url: url)
        let inserter = FakeInserter()

        // De pure correctie-stap (zoals AppModel.correctLastDictation 'm aanroept):
        DictionaryCorrection.apply(old: "ik ga naar naslak", edited: "ik ga naar Naslag",
                                   store: store, inserter: inserter)

        XCTAssertEqual(store.entries, [DictionaryEntry(wrong: "naslak", right: "Naslag")])
        XCTAssertEqual(inserter.replaced.first?.old, "ik ga naar naslak")
        XCTAssertEqual(inserter.replaced.first?.new, "ik ga naar Naslag")
    }

    func testCorrectieZonderWijzigingDoetNiets() {
        let store = DictionaryStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("dict-\(UUID().uuidString).json"))
        let inserter = FakeInserter()
        DictionaryCorrection.apply(old: "alles klopt", edited: "alles klopt", store: store, inserter: inserter)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(inserter.replaced.isEmpty)
    }
}
```

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `xcodegen generate && ./test.sh`
Expected: FAIL — "cannot find 'DictionaryCorrection'".

- [ ] **Step 3: Implementatie**

Create the testable correctie-stap als vrije enum (pure orkestratie, injecteerbaar) — plaats in `Fluister/Dictionary/DictionaryCorrection.swift`:

```swift
import Foundation

/// Verwerkt één correctie: leidt paren af, slaat ze op, en voert fix-now uit (alleen als er iets wijzigde).
enum DictionaryCorrection {
    @MainActor
    static func apply(old: String, edited: String, store: DictionaryStore, inserter: TextInserting) {
        let pairs = DictionaryDiff.pairs(old: old, new: edited)
        guard !pairs.isEmpty else { return }
        for p in pairs { store.add(wrong: p.wrong, right: p.right) }
        inserter.replaceLast(oldText: old, with: edited)
    }
}
```

In `Fluister/AppModel.swift`: `func correctLastDictation(edited: String) { guard let old = controller.lastInsertedText else { return }; DictionaryCorrection.apply(old: old, edited: edited, store: dictionary, inserter: inserter) }`

Create `Fluister/UI/CorrectionView.swift`: SwiftUI-venster met een `TextEditor` gevuld met `controller.lastInsertedText`, een knop "Opslaan + corrigeren" die `app.correctLastDictation(edited:)` aanroept en het venster sluit, en een "Annuleren". NL-teksten, bestaande design-tokens/stijl.

In `Fluister/FluisterApp.swift`: voeg een `Window`-scene `FluisterWindow.correction` toe (zelfde patroon als het over-/instellingen-venster).

In `Fluister/UI/MenuBarView.swift`: menu-item **"Corrigeer laatste dictaat"** dat het correction-venster opent (`openWindow`); disabled als `lastInsertedText == nil`.

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS (2 nieuwe tests groen).

- [ ] **Step 5: Handmatige test**

Run: `./build.sh`. Dicteer een zin met een woord dat Whisper verkeerd spelt. Menu → "Corrigeer laatste dictaat" → venster toont de tekst → fix het woord → "Opslaan + corrigeren". Verwacht: de tekst in je doelvenster wordt vervangen (fix-now, mits je 't direct doet), en het paar staat voortaan in de lijst (volgende dictaat corrigeert automatisch).

- [ ] **Step 6: Commit**

```bash
git add Fluister/Dictionary/DictionaryCorrection.swift Fluister/AppModel.swift Fluister/UI/CorrectionView.swift Fluister/UI/MenuBarView.swift Fluister/FluisterApp.swift FluisterTests/AppModelDictionaryTests.swift
git commit -m "feat: corrigeer-laatste-dictaat flow (leren + fix-now)"
```

---

## Task 7: Instellingen-UI voor woordenlijst-beheer

**Files:**
- Modify: `Fluister/UI/SettingsView.swift`
- Modify: `Fluister/UI/SettingsView.swift`-aanroep in `FluisterApp.swift` (indien `SettingsView` de store nog niet krijgt)

**Interfaces:**
- Consumes: `DictionaryStore` (Task 3) — doorgegeven vanuit `AppModel`.

- [ ] **Step 1: Store doorgeven aan SettingsView**

In `FluisterApp.swift` / waar `SettingsView` wordt gebouwd: geef `app.dictionary` mee als `@ObservedObject`.

- [ ] **Step 2: Woordenlijst-sectie**

In `Fluister/UI/SettingsView.swift`, voeg een sectie toe (onder de bestaande instellingen):

```swift
            Divider()
            Text("Woordenlijst").font(.headline)
            Text("Woorden die Whisper vaak verkeerd spelt, en hoe ze moeten. Fluister past ze automatisch toe.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            ForEach(dictionary.entries, id: \.wrong) { e in
                HStack {
                    Text(e.wrong).foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                    Text(e.right)
                    Spacer()
                    Button(role: .destructive) { dictionary.remove(wrong: e.wrong) } label: {
                        Image(systemName: "trash")
                    }.buttonStyle(.borderless)
                }
            }

            HStack {
                TextField("hoort als…", text: $newWrong)
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                TextField("moet zijn…", text: $newRight)
                Button("Voeg toe") {
                    dictionary.add(wrong: newWrong, right: newRight); newWrong = ""; newRight = ""
                }.disabled(newWrong.isEmpty || newRight.isEmpty)
            }
```

Voeg boven in de view `@ObservedObject var dictionary: DictionaryStore` en `@State private var newWrong = ""`, `@State private var newRight = ""` toe.

- [ ] **Step 3: Regressietest (compilatie + suite)**

Run: `./test.sh`
Expected: PASS (UI-wijziging breekt niets).

- [ ] **Step 4: Handmatige test**

Run: `./build.sh` → Instellingen (⌘,). Voeg een paar toe (fout→goed), zie 't in de lijst, verwijder 't. Dicteer een zin met de "fout"-vorm → wordt automatisch vervangen. Herstart → paren blijven bewaard.

- [ ] **Step 5: Commit**

```bash
git add Fluister/UI/SettingsView.swift Fluister/FluisterApp.swift
git commit -m "feat: instellingen-UI voor woordenlijst-beheer"
```

---

## Self-Review

**Spec-dekking:**
- Woordenlijst van fout→goed-paren, lokaal, handmatig beheerbaar → Task 3 (store) + Task 7 (UI) ✓
- Deterministische hele-woord-vervanging in `finish()` → Task 1 (pure) + Task 4 (wiring) ✓
- "Corrigeer laatste dictaat" met fix-now → Task 2 (diff) + Task 5 (onthoud + replaceLast) + Task 6 (flow/UI) ✓
- Instellingen-UI → Task 7 ✓
- Prompt-bias uitgesteld, model erop voorbereid → geen bias-taak; `DictionaryEntry` uitbreidbaar (noot) ✓
- False-positive-discipline (hele woord, langste eerst) → Task 1 ✓
- Testbaarheid pure logica → Tasks 1/2/3/6 (DictionaryCorrection) ✓

**Placeholder-scan:** geen TBD/TODO; pure units volledig uitgeschreven; UI-stappen concreet met codeblokken. De secure-input-/CGEvent-details in Task 5 verwijzen bewust naar het bestaande patroon in `TextInserter.swift` (bestaande, te volgen code) i.p.v. het te dupliceren.

**Type-consistentie:** `apply(_:pairs:)` met `[(wrong,right)]` identiek in Task 1/4. `DictionaryEntry{wrong,right}` in Task 3/6/7. `DictionaryStore.pairs/add/remove/entries` consistent. `replaceLast(oldText:with:)` in protocol (Task 5), fake (Task 5), en aanroep (Task 6). `DictionaryDiff.pairs(old:new:)` in Task 2/6. Consistent.

**Scope:** één samenhangende feature (v1 replace-first + fix-now). Prompt-bias en instelbare sneltoets bewust uit scope (spec). Geen release-taken (aparte batch).

**Bekende beperkingen (in het plan verwerkt):** diff alleen bij gelijk woordaantal; `\b`-match kan een term binnen een e-mail/URL raken (zeldzaam, gebruiker beheert de lijst); fix-now werkt schoon direct na een dictaat, anders klembord-fallback.
