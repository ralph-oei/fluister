# Fluister Leestekens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zet een vaste kern-set uitgesproken leestekens ("komma" → `,`, "punt" → `.`, …) deterministisch en 100% lokaal om naar het teken, met een aan/uit-toggle in Instellingen (standaard aan). (GitHub issue #5.)

**Architecture:** Pure, testbare `PunctuationFormatter` (geen state/naden, spiegelt `whisperLanguageCode`) die tussen transcriptie en invoegen in `DictationController.finish()` draait. Een nieuwe `AppSettings`-sleutel stuurt de toggle; `AppModel` schuift wijzigingen live door naar de controller, exact zoals `language` al gaat.

**Tech Stack:** Swift 5, SwiftUI, XcodeGen (`project.yml`), XCTest (`./test.sh`), WhisperKit (ongewijzigd). Geen nieuwe dependencies.

## Global Constraints

- **Geen nieuwe dependencies, niets naar de cloud.** Puur lokale tekst-post-processing, geen LLM.
- **Pure logica bevat geen UI-/netwerk-/state-afhankelijkheden** (`PunctuationFormatter` importeert alleen Foundation).
- **Testcommando:** `./test.sh` (draait de hele XCTest-suite via xcodebuild). Startpunt: **64 tests groen**.
- **Nederlands** in alle UI-teksten.
- **Kern-set (exact, niets extra deze ronde):** NL `komma→, · punt→. · vraagteken→? · uitroepteken→! · dubbele punt→: · puntkomma→; · nieuwe regel→\n`; EN `comma→, · period/full stop→. · question mark→? · exclamation mark/point→! · colon→: · semicolon→; · new line→\n`.
- **Matching:** case-ongevoelig, op hele woorden (woordgrenzen); meerwoords/samengestelde commando's vóór enkele.
- **Toggle standaard AAN**, ook voor bestaande gebruikers (ontbrekende sleutel = `true`).
- **Release behoudt de downloadteller:** nooit de v0.1.0-asset clobberen; nieuwe tag `v0.2.0`, v0.1.0 blijft als archief. `MARKETING_VERSION 0.1.0→0.2.0`, `CURRENT_PROJECT_VERSION 3→4`.

---

> **Herzien na de whole-branch review (24-07):** Task 1's formatter is tijdens uitvoering
> vervangen door een **chirurgische** implementatie (sentinel-marker `\u{E000}` + assemblage die
> alleen ingevoegde tekens aanraakt; geen begin-hoofdletter; no-command-invoer blijft ongemoeid).
> Reden: de oorspronkelijke code mangelde e-mails/URLs/bestandsnamen (`ralph.oei@gmail.com` →
> `Ralph. Oei@gmail. Com`). Zie de bijgewerkte spec en commits `c3ff864` + `1fe30da`. De code/tests
> hieronder zijn de oorspronkelijke (niet-chirurgische) versie — de spec is leidend voor het eindgedrag.

## Task 1: Pure `PunctuationFormatter`

**Files:**
- Create: `Fluister/Transcription/PunctuationFormatter.swift`
- Test: `FluisterTests/PunctuationFormatterTests.swift`

**Interfaces:**
- Consumes: niets (alleen Foundation).
- Produces: `enum PunctuationFormatter { static func format(_ text: String, language: String) -> String }`. `language` begint met `"nl"` → NL-tabel; anders EN-tabel.

- [ ] **Step 1: Schrijf de falende test**

Create `FluisterTests/PunctuationFormatterTests.swift`:

```swift
import XCTest
@testable import Fluister

final class PunctuationFormatterTests: XCTestCase {

    // NL
    func testNLKommaEnPunt() {
        XCTAssertEqual(
            PunctuationFormatter.format("hallo komma wereld punt", language: "nl"),
            "Hallo, wereld.")
    }

    func testNLVraagEnUitroep() {
        XCTAssertEqual(
            PunctuationFormatter.format("echt vraagteken nee uitroepteken", language: "nl"),
            "Echt? Nee!")
    }

    func testNLSamengesteldeVoorEnkele() {
        // 'dubbele punt' en 'puntkomma' mogen niet als 'punt'/'komma' eindigen
        XCTAssertEqual(
            PunctuationFormatter.format("let op dubbele punt items puntkomma klaar", language: "nl"),
            "Let op: items; klaar")
    }

    func testNLNieuweRegel() {
        XCTAssertEqual(
            PunctuationFormatter.format("regel een nieuwe regel regel twee", language: "nl"),
            "Regel een\nRegel twee")
    }

    func testHoofdletterNaZinEinde() {
        XCTAssertEqual(
            PunctuationFormatter.format("dit is een test punt de tweede zin", language: "nl"),
            "Dit is een test. De tweede zin")
    }

    func testWoordgrensBlijftHeel() {
        // 'standpunt' bevat 'punt' maar mag niet geraakt worden
        XCTAssertEqual(
            PunctuationFormatter.format("mijn standpunt is duidelijk", language: "nl"),
            "Mijn standpunt is duidelijk")
    }

    func testBekendeValsPositiefGedocumenteerd() {
        // Inherent aan gesproken leestekens: het losse woord 'punt' wordt een teken.
        XCTAssertEqual(
            PunctuationFormatter.format("we hebben een goed punt", language: "nl"),
            "We hebben een goed.")
    }

    func testGeenLeestekensOngewijzigdBehalveHoofdletter() {
        XCTAssertEqual(
            PunctuationFormatter.format("gewoon een zin", language: "nl"),
            "Gewoon een zin")
    }

    // EN
    func testENSet() {
        XCTAssertEqual(
            PunctuationFormatter.format("hello comma world period new line done", language: "en"),
            "Hello, world.\nDone")
    }

    func testENFullStopEnExclamation() {
        XCTAssertEqual(
            PunctuationFormatter.format("stop full stop go exclamation mark", language: "en"),
            "Stop. Go!")
    }

    func testOnbekendeTaalGebruiktEN() {
        XCTAssertEqual(
            PunctuationFormatter.format("hello comma world", language: "de"),
            "Hello, world")
    }

    func testGetalMetPuntBlijftHeel() {
        // Reeds aanwezige interpunctie/getallen niet beschadigen
        XCTAssertEqual(
            PunctuationFormatter.format("versie 3.14 is klaar", language: "nl"),
            "Versie 3.14 is klaar")
    }
}
```

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `./test.sh`
Expected: FAIL — build-fout "cannot find 'PunctuationFormatter' in scope".

- [ ] **Step 3: Schrijf de minimale implementatie**

Create `Fluister/Transcription/PunctuationFormatter.swift`:

```swift
import Foundation

/// Zet uitgesproken leestekens ("komma", "punt", …) om naar het teken. Puur en
/// deterministisch — geen state, geen netwerk, geen UI. De taaltabel volgt de
/// dicteertaal; een onbekende taal valt terug op de Engelse set.
///
/// Beperking (bewust): tekst-post-processing kan niet horen of iemand het teken
/// of het wóórd bedoelde ("een goed punt" wordt "een goed."). Daarom staat het
/// achter een toggle. De kern-set is klein gehouden om vals-positieven te beperken.
enum PunctuationFormatter {

    // Volgorde = toepassingsvolgorde: meerwoords/samengestelde commando's eerst,
    // zodat 'punt'/'komma' de deelwoorden van 'dubbele punt'/'puntkomma' niet opeten.
    private static let nl: [(word: String, symbol: String)] = [
        ("dubbele punt", ":"),
        ("nieuwe regel", "\n"),
        ("puntkomma", ";"),
        ("komma", ","),
        ("vraagteken", "?"),
        ("uitroepteken", "!"),
        ("punt", "."),
    ]

    private static let en: [(word: String, symbol: String)] = [
        ("exclamation mark", "!"),
        ("exclamation point", "!"),
        ("question mark", "?"),
        ("full stop", "."),
        ("new line", "\n"),
        ("semicolon", ";"),
        ("colon", ":"),
        ("comma", ","),
        ("period", "."),
    ]

    static func format(_ text: String, language: String) -> String {
        let table = language.lowercased().hasPrefix("nl") ? nl : en
        var s = text
        for (word, symbol) in table {
            s = replaceWholeWord(word, with: symbol, in: s)
        }
        s = normalizeSpacing(s)
        s = capitalizeSentences(s)
        return s
    }

    /// Case-ongevoelige vervanging van een heel woord/zin (woordgrenzen) zodat
    /// 'standpunt' en 'kommavrij' heel blijven.
    private static func replaceWholeWord(_ word: String, with symbol: String, in text: String) -> String {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let template = NSRegularExpression.escapedTemplate(for: symbol)
        return re.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    /// Nette spatiëring: geen spatie vóór een leesteken; één spatie erná als er een
    /// letter volgt (getallen zoals "3.14" blijven heel); geen spaties rond newline;
    /// dubbele spaties samengeklapt; rand-witruimte getrimd.
    private static func normalizeSpacing(_ text: String) -> String {
        let punct: Set<Character> = [",", ".", ";", ":", "!", "?"]
        var result: [Character] = []
        for ch in text {
            if punct.contains(ch) {
                while result.last == " " { result.removeLast() }
                result.append(ch)
            } else if ch == "\n" {
                while result.last == " " { result.removeLast() }
                result.append(ch)
            } else if ch == " " {
                if result.last == " " || result.last == "\n" { continue }
                result.append(ch)
            } else {
                if let last = result.last, punct.contains(last), ch.isLetter {
                    result.append(" ")
                }
                result.append(ch)
            }
        }
        return String(result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Kapitaliseer de eerste letter van de tekst en de eerste letter na '.', '?',
    /// '!' of een newline. Unicode-veilig (scant tekens i.p.v. ASCII-regex).
    private static func capitalizeSentences(_ text: String) -> String {
        var result = ""
        var capitalizeNext = true
        for ch in text {
            if capitalizeNext, ch.isLetter {
                result += String(ch).uppercased()
                capitalizeNext = false
            } else {
                result.append(ch)
                if ch == "." || ch == "?" || ch == "!" || ch == "\n" {
                    capitalizeNext = true
                } else if !ch.isWhitespace {
                    capitalizeNext = false
                }
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS (12 nieuwe tests groen; totaal 76).

- [ ] **Step 5: Commit**

```bash
git add Fluister/Transcription/PunctuationFormatter.swift FluisterTests/PunctuationFormatterTests.swift
git commit -m "feat: pure PunctuationFormatter (gesproken leestekens -> tekens)"
```

---

## Task 2: `AppSettings.punctuationEnabled` (default aan)

**Files:**
- Modify: `Fluister/Settings/AppSettings.swift`
- Test: `FluisterTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: niets.
- Produces: `@Published var punctuationEnabled: Bool` op `AppSettings`, default `true` als de UserDefaults-sleutel ontbreekt; write-through naar UserDefaults onder key `"punctuationEnabled"`.

- [ ] **Step 1: Schrijf de falende test**

Append to `FluisterTests/AppSettingsTests.swift` (binnen de bestaande `AppSettingsTests`-klasse; gebruik het bestaande ephemeral-suite-patroon van dat bestand):

```swift
    func testPunctuationDefaultsTrueWhenUnset() {
        let suite = UserDefaults(suiteName: "test.punct.default.\(UUID().uuidString)")!
        let settings = AppSettings(defaults: suite)
        XCTAssertTrue(settings.punctuationEnabled, "ontbrekende sleutel moet default true zijn")
    }

    func testPunctuationPersistsFalse() {
        let name = "test.punct.persist.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        let settings = AppSettings(defaults: suite)
        settings.punctuationEnabled = false
        // Verse instance leest dezelfde suite terug.
        let reloaded = AppSettings(defaults: suite)
        XCTAssertFalse(reloaded.punctuationEnabled, "false moet bewaard blijven")
    }
```

> Als `AppSettingsTests.swift` geen ephemeral-suite gebruikt maar `.standard`, volg dan het patroon dat er al staat; de assertie-inhoud blijft gelijk.

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `./test.sh`
Expected: FAIL — build-fout "value of type 'AppSettings' has no member 'punctuationEnabled'".

- [ ] **Step 3: Schrijf de minimale implementatie**

In `Fluister/Settings/AppSettings.swift`, voeg de key toe aan `Keys`:

```swift
        static let punctuation = "punctuationEnabled"
```

Voeg de property toe (na `hasCompletedOnboarding`):

```swift
    @Published var punctuationEnabled: Bool {
        didSet { defaults.set(punctuationEnabled, forKey: Keys.punctuation) }
    }
```

En in `init(defaults:)`, ná de bestaande toewijzingen, met **default true bij ontbrekende sleutel**:

```swift
        // Ontbrekende sleutel → aan (ook voor bestaande gebruikers).
        self.punctuationEnabled = defaults.object(forKey: Keys.punctuation) == nil
            ? true
            : defaults.bool(forKey: Keys.punctuation)
```

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS (2 nieuwe tests groen; totaal 78).

- [ ] **Step 5: Commit**

```bash
git add Fluister/Settings/AppSettings.swift FluisterTests/AppSettingsTests.swift
git commit -m "feat: AppSettings.punctuationEnabled (default aan)"
```

---

## Task 3: Bedrading in `DictationController` + `AppModel`

**Files:**
- Modify: `Fluister/DictationController.swift`
- Modify: `Fluister/AppModel.swift`
- Test: `FluisterTests/DictationControllerTests.swift`

**Interfaces:**
- Consumes: `PunctuationFormatter.format(_:language:)` (Task 1); `AppSettings.punctuationEnabled` (Task 2).
- Produces: `DictationController.punctuationEnabled: Bool` (default `true`); ingevoegde tekst is geformatteerd wanneer aan, ruw wanneer uit.

- [ ] **Step 1: Schrijf de falende test**

Append to `FluisterTests/DictationControllerTests.swift` (binnen `DictationControllerTests`):

```swift
    func testFinishFormatsPunctuationWhenEnabled() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "hallo komma wereld")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)
        c.language = "nl"
        c.punctuationEnabled = true

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertEqual(inserter.inserted, ["Hallo, wereld"])
    }

    func testFinishKeepsRawWhenDisabled() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "hallo komma wereld")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)
        c.language = "nl"
        c.punctuationEnabled = false

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertEqual(inserter.inserted, ["hallo komma wereld"])
    }
```

- [ ] **Step 2: Draai de test — verwacht FAIL**

Run: `./test.sh`
Expected: FAIL — build-fout "value of type 'DictationController' has no member 'punctuationEnabled'".

- [ ] **Step 3: Schrijf de minimale implementatie**

In `Fluister/DictationController.swift`, voeg naast `var language` toe:

```swift
    var punctuationEnabled: Bool = true
```

In `finish(samples:)`, vervang het invoeg-blok. Van:

```swift
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                phase = .idle
                return
            }
            phase = .inserting
            inserter.insert(text)
            phase = .idle
```

naar:

```swift
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                phase = .idle
                return
            }
            let out = punctuationEnabled
                ? PunctuationFormatter.format(text, language: language)
                : text
            phase = .inserting
            inserter.insert(out)
            phase = .idle
```

In `Fluister/AppModel.swift`, in `init()` ná `controller.language = settings.language`:

```swift
        controller.punctuationEnabled = settings.punctuationEnabled
```

En ná de bestaande `settings.$language`-subscriptie een parallelle subscriptie:

```swift
        settings.$punctuationEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.controller.punctuationEnabled = enabled
            }
            .store(in: &cancellables)
```

**Pre-existing test aanpassen (nodig):** de controller-default `punctuationEnabled = true` laat de
formatter nu op élke dictaat draaien (incl. hoofdletter-aan-het-begin). De bestaande test
`testFinishTranscribesAndInserts` gebruikt een fake die de kleine-letter-tekst `"dit is een test"`
teruggeeft en verwacht die ruw terug — dat is een pure transcribe→insert-test, niet over deze
feature. Houd 'm zuiver door de toggle in díe test uit te zetten (verwachting blijft ongewijzigd).
Voeg vóór `await c.finish(...)` in `testFinishTranscribesAndInserts` toe:

```swift
        c.punctuationEnabled = false
```

- [ ] **Step 4: Draai de test — verwacht PASS**

Run: `./test.sh`
Expected: PASS (2 nieuwe tests groen; totaal 80).

- [ ] **Step 5: Commit**

```bash
git add Fluister/DictationController.swift Fluister/AppModel.swift FluisterTests/DictationControllerTests.swift
git commit -m "feat: pas leestekens toe in dicteer-keten + live toggle-bedrading"
```

---

## Task 4: Toggle in `SettingsView`

Deliverable: een aan/uit-schakelaar in het Instellingen-venster, gebonden aan `AppSettings.punctuationEnabled`. SwiftUI-view → handmatig getest.

**Files:**
- Modify: `Fluister/UI/SettingsView.swift`

**Interfaces:**
- Consumes: `AppSettings.punctuationEnabled` (Task 2).

- [ ] **Step 1: Voeg de toggle toe**

In `Fluister/UI/SettingsView.swift`, binnen de `Form`, ná de `KeyboardShortcuts.Recorder` en vóór de "Start bij inloggen"-toggle:

```swift
            Toggle("Uitgesproken leestekens omzetten", isOn: $settings.punctuationEnabled)
            Text("Zet gesproken 'komma', 'punt', 'nieuwe regel' enz. om naar het teken.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
```

- [ ] **Step 2: Regressietest (compilatie + suite)**

Run: `./test.sh`
Expected: PASS (80 tests groen; UI-wijziging breekt niets).

- [ ] **Step 3: Handmatige test (lokaal)**

Run: `./build.sh` → app start. Open Instellingen (⌘,). Verwacht: de nieuwe toggle staat **aan**, met de hulptekst eronder (wrapt netjes). Dicteer met ⌥Space "test komma nog een test punt" → tekst verschijnt als "Test, nog een test." Zet de toggle uit → dezelfde dictaat levert de ruwe woorden. Herstart → toggle-stand blijft bewaard.

- [ ] **Step 4: Commit**

```bash
git add Fluister/UI/SettingsView.swift
git commit -m "feat: instellingen-toggle voor leestekens omzetten"
```

---

## Task 5: Versie-bump + CHANGELOG + README-link

Deliverable: het project staat klaar voor een 0.2.0-release; geen release-actie zelf.

**Files:**
- Modify: `project.yml`
- Modify: `CHANGELOG.md`
- Modify: `README.md`

- [ ] **Step 1: Versie bumpen in `project.yml`**

In `settings.base`: `MARKETING_VERSION` `"0.1.0"` → `"0.2.0"`, `CURRENT_PROJECT_VERSION` `"3"` → `"4"`. Regenereer het project:

```bash
xcodegen generate
```

- [ ] **Step 2: CHANGELOG-sectie toevoegen**

Boven de bestaande `## [0.1.0]`-sectie in `CHANGELOG.md`:

```markdown
## [0.2.0] — 2026-07-24

### Toegevoegd
- Uitgesproken leestekens worden nu omgezet naar het teken: "komma" → `,`, "punt" → `.`,
  "vraagteken" → `?`, "uitroepteken" → `!`, "dubbele punt" → `:`, "puntkomma" → `;`,
  "nieuwe regel" → een nieuwe regel (NL + EN). Standaard aan; uit te zetten in Instellingen.
  Dank aan @petervanrijt voor het verzoek (#5).
```

- [ ] **Step 3: README download-link toekomstbestendig maken**

In `README.md`, laat de download-/release-verwijzing naar de **laatste** release wijzen zodat volgende versies geen edit vergen. Vervang een expliciete `.../releases/tag/v0.1.0`-link door:

```markdown
https://github.com/ralph-oei/fluister/releases/latest
```

(Als de README al naar `/releases` of `/releases/latest` wijst, laat 'm staan en noteer dat in de commit.)

- [ ] **Step 4: Regressietest**

Run: `./test.sh`
Expected: PASS (80 tests groen — versie/docs raken code niet).

- [ ] **Step 5: Commit**

```bash
git add project.yml Fluister.xcodeproj CHANGELOG.md README.md
git commit -m "chore: bump 0.2.0 (build 4) + CHANGELOG + README latest-link"
```

---

## Task 6: Release v0.2.0 (nieuwe tag, archief behouden) — WACHT OP RALPHS GO

Deliverable: genotariseerde `Fluister-0.2.0.dmg` als **nieuwe** GitHub-release `v0.2.0`; de v0.1.0-release blijft als archief staan (downloadteller intact). Naar buiten → expliciete go van Ralph vereist vóór deze taak draait.

**Files:** geen code (build + release).

- [ ] **Step 1: Genotariseerde DMG bouwen (detached)**

De notarization duurt ~20 min; draai **detached** zodat een achtergrond-task 'm niet meekilt:

```bash
cd /Users/ralpho/Claude_Workspace/projects/Fluister
nohup ./scripts/release.sh > scratchpad-release.log 2>&1 & disown
```

Volg met `tail -f scratchpad-release.log`. Verwacht: `dist/Fluister-0.2.0.dmg` + `.sha256`, app + DMG genotariseerd + gestapled, Gatekeeper `accepted`.

- [ ] **Step 2: Verifieer notarisatie**

```bash
spctl -a -vv -t install dist/Fluister-0.2.0.dmg
```
Expected: `accepted` / `source=Notarized Developer ID`.

- [ ] **Step 3: Nieuwe release aanmaken (GEEN clobber)**

```bash
cd /Users/ralpho/Claude_Workspace/projects/Fluister
shasum -a 256 dist/Fluister-0.2.0.dmg | tee dist/Fluister-0.2.0.dmg.sha256
gh release create v0.2.0 \
  dist/Fluister-0.2.0.dmg dist/Fluister-0.2.0.dmg.sha256 \
  --title "Fluister 0.2.0" \
  --notes "Uitgesproken leestekens omzetten (komma, punt, …) — standaard aan, uit te zetten in Instellingen. Dank @petervanrijt (#5). SHA-256 in de .sha256-asset. De v0.1.0-release blijft als archief staan."
```

De v0.1.0-tag/-release blijft ongemoeid → downloadstats behouden.

- [ ] **Step 4: Issue #5 sluiten**

```bash
gh issue comment 5 --body "Zit in v0.2.0: uitgesproken leestekens worden nu omgezet naar het teken (komma, punt, vraagteken, uitroepteken, dubbele punt, puntkomma, nieuwe regel), standaard aan en uit te zetten in Instellingen. Bedankt voor het verzoek! Download: https://github.com/ralph-oei/fluister/releases/latest"
gh issue close 5
```

- [ ] **Step 5: Push code + STATUS bijwerken**

```bash
git push origin main
```
Werk `projects/Fluister/STATUS.md` bij: 0.2.0 live, leestekens-feature, issue #5 gesloten, nieuwe DMG-SHA noteren, teller behouden.

---

## Self-Review

**Spec-dekking:**
- Kern-set NL+EN → Task 1 (tabellen + tests) ✓
- Meerwoords/samengesteld vóór enkel → Task 1 (volgorde + `testNLSamengesteldeVoorEnkele`) ✓
- Woordgrens / geen valse deelwoord-hits → Task 1 (`\b` + `testWoordgrensBlijftHeel`) ✓
- Spatiëring + hoofdletter na zin-einde + newline → Task 1 (`normalizeSpacing`/`capitalizeSentences` + tests) ✓
- Getallen/bestaande interpunctie niet beschadigen → Task 1 (`testGetalMetPuntBlijftHeel`) ✓
- Toggle default aan, ook bestaande gebruikers → Task 2 (`object(forKey:)==nil ? true`) ✓
- Live doorschuiven van de toggle → Task 3 (AppModel-subscriptie, `language`-patroon) ✓
- Toepassen tussen transcriptie en invoegen → Task 3 (`finish()`) ✓
- Instellingen-toggle + hulptekst → Task 4 ✓
- Bekende beperking gedocumenteerd → spec + Task 1 (`testBekendeValsPositiefGedocumenteerd`) + release-notes ✓
- Release met nieuwe tag, archief behouden, versie-bump → Task 5 + Task 6 ✓

**Placeholder-scan:** geen TBD/TODO; alle Swift + testcode volledig uitgeschreven; commando's concreet.

**Type-consistentie:** `PunctuationFormatter.format(_:language:)` identiek in Task 1/3. `punctuationEnabled: Bool` identiek in `AppSettings` (Task 2), `DictationController` (Task 3), `SettingsView`-binding (Task 4), AppModel-subscriptie (Task 3). Key-string `"punctuationEnabled"` één keer in `AppSettings.Keys`. Consistent.

**Scope:** één samenhangende feature + de bijbehorende release; geen decompositie in aparte plannen nodig.
