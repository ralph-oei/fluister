# Fluister — Uitgesproken leestekens omzetten (design)

*2026-07-24 · aanleiding: GitHub issue #5 (petervanrijt)*

## Probleem & doel

Gebruikers spreken leestekens uit ("komma", "punt") maar krijgen ze als **los woord** in de
tekst i.p.v. als teken. Verzoek: een **aan/uit-optie** om uitgesproken leestekens als het
daadwerkelijke teken weer te geven, zoals Apple-dictee.

**Doel:** een deterministische, 100% lokale post-processing die een vaste **kern-set** gesproken
leestekens omzet naar tekens, met nette spatiëring en hoofdletter na een zin-einde. Toggle in
Instellingen, **standaard aan** (ook voor bestaande gebruikers).

Past bij het uitgangspunt van de app: alleen verbeteren waar gebruikers tegenaan lopen, klein
maar fijn, geen dependencies, niets naar de cloud. Geen LLM.

## Scope

**Kern-set (afgesproken):**

| Gesproken (NL) | Gesproken (EN) | Teken |
|---|---|---|
| komma | comma | `,` |
| punt | period · full stop | `.` |
| vraagteken | question mark | `?` |
| uitroepteken | exclamation mark · exclamation point | `!` |
| dubbele punt | colon | `:` |
| puntkomma | semicolon | `;` |
| nieuwe regel | new line | `\n` |

**Extra netheid (chirurgisch — alleen rond ingevoegde tekens):** geen spatie vóór een ingevoegd
teken, wél een spatie erná (behalve `\n`); **hoofdletter alleen ná een uitgesproken `.` `?` `!`**.
Géén geforceerde hoofdletter aan het begin van de dictaat (Whisper kapitaliseert de zinsstart al).
Bestaande interpunctie, e-mailadressen, URLs, bestandsnamen en getallen worden **niet aangeraakt**.

**Buiten scope (deze ronde):** haakjes, aanhalingstekens, losse "hoofdletter"-commando's,
"wis dat"/undo, emoji. Kan later als iemand erom vraagt.

## Ontwerp

### Pure formatter (testbaar, geen naden nodig)

Nieuw bestand `Fluister/Transcription/PunctuationFormatter.swift`:

```
enum PunctuationFormatter {
    static func format(_ text: String, language: String) -> String
}
```

Geen `import` buiten Foundation, geen state → volledig unit-testbaar (spiegelt de bestaande
`whisperLanguageCode`/pure-helper-stijl). `language` selecteert de commando-tabel (`"nl"` →
NL-set, anders EN-set; bij onbekende taal EN als val-terug).

### Verwerkingsvolgorde (belangrijk)

1. **Vervang commando's door een MARKER + het teken, langste eerst.** Elk ingevoegd teken krijgt
   een sentinel-marker (`\u{E000}`, Private Use Area) ervoor, zodat de assemblage-stap wéét welke
   tekens door ons zijn ingevoegd en de rest ongemoeid laat. Meerwoords/samengestelde commando's
   vóór enkele (`dubbele punt`/`puntkomma`/`nieuwe regel` vóór `punt`/`komma`). Matching is
   **case-ongevoelig** en op **hele woorden** (woordgrenzen), zodat `standpunt`/`kommavrij` heel blijven.
2. **Assembleer, en raak ALLEEN gemarkeerde tekens aan.** Loop de string door: bij een marker →
   verwijder een spatie ervóór, plak het teken, en zet één spatie erná (bij `.`/`?`/`!` óók een
   hoofdletter-vlag voor het volgende woord); `\n` krijgt geen spaties eromheen. **Ongemarkeerde
   tekens** (bestaande punten in e-mails/URLs/bestandsnamen, door Whisper geplaatste interpunctie
   en hoofdletters) gaan **onaangeroerd** door. Geen begin-hoofdletter, geen globale herspatiëring.

### Bekende beperking (bewust)

Zuivere tekst-post-processing kan niet horen of iemand het teken bedoelde of het wóórd. "We
hebben een goed **punt**" wordt "We hebben een goed." Dit is inherent aan gesproken-leestekens
(Apple-dictee heeft hetzelfde) en precies waarom het een **toggle** is. We houden de kern-set
klein om vals-positieven te beperken; documenteren in de release-notes.

### Bedrading

- **`AppSettings`**: nieuwe sleutel `punctuationEnabled: Bool`, **default `true` als de sleutel
  ontbreekt** (`defaults.object(forKey:) == nil ? true : defaults.bool(...)` — bestaande
  gebruikers krijgen 'm dus aan). Write-through zoals `language`.
- **`DictationController`**: nieuwe `var punctuationEnabled: Bool = true`. In `finish()`, ná de
  lege-check op de ruwe transcriptie en vóór `inserter.insert(...)`:
  `let out = punctuationEnabled ? PunctuationFormatter.format(text, language: language) : text`.
- **`AppModel`**: init zet `controller.punctuationEnabled = settings.punctuationEnabled`; een
  `settings.$punctuationEnabled.dropFirst().removeDuplicates()`-subscriptie schuift wijzigingen
  live door (exact het `language`-patroon).
- **`SettingsView`**: `Toggle("Uitgesproken leestekens omzetten", isOn: $settings.punctuationEnabled)`
  met korte hulptekst ("Zet 'komma', 'punt' enz. om naar het teken.").

## Tests

- **`PunctuationFormatterTests.swift`** (nieuw): NL- en EN-mappings; volgorde (`dubbele punt`→`:`
  en `puntkomma`→`;` vóór `punt`/`komma`); spatiëring ("hallo komma wereld" → "hallo, wereld");
  hoofdletter na `.`; `nieuwe regel`/`new line` → `\n`; woordgrens (`standpunt` blijft heel);
  vals-positief gedocumenteerd ("goed punt" → "goed."); onbekende taal → EN-set.
- **`AppSettingsTests`**: `punctuationEnabled` = `true` bij ontbrekende sleutel; blijft bewaard;
  respecteert een expliciete `false`.
- **`DictationControllerTests`**: aan → "hallo komma wereld" wordt "hallo, wereld" ingevoegd;
  uit → ruwe tekst ingevoegd.

## Release (Ralphs eis: teller behouden)

Niet de v0.1.0-asset clobberen (dat reset de downloadteller). In plaats daarvan:

- **Versie-bump** in `project.yml`: `MARKETING_VERSION 0.1.0 → 0.2.0`, `CURRENT_PROJECT_VERSION 3 → 4`.
- **CHANGELOG**: nieuwe `## [0.2.0]`-sectie (leestekens-feature + issue #5-credit).
- **Nieuwe GitHub-release met een nieuwe tag `v0.2.0`** (`gh release create`, geen `--clobber`);
  de v0.1.0-release blijft staan **als archief** met zijn downloadstats.
- Genotariseerde `Fluister-0.2.0.dmg` + `.sha256`, release altijd **detached** draaien
  (`nohup ./scripts/release.sh & disown`).
- **README download-link** naar `/releases/latest` zodat volgende bumps geen README-edit vergen.
- Release = naar buiten → **wacht op Ralphs go**; daarna issue #5 sluiten met een verwijzing.

## Niet-doelen

- Geen LLM/Ollama (Spoor B blijft geparkeerd; Whisper dropt eh/uh al zelf — geverifieerd 24-07).
- Geen acoustische leesteken-detectie; puur tekst-post-processing.
- Geen configureerbare commando-woorden in deze ronde.
