# Fluister — Personal Dictionary (design)

*2026-07-27 · doel: Wispr Flow's "Dictionary" klonen — eigen woorden/spellingen die Fluister
toepast, en die leren van jouw correcties. Scope-keuzes met Ralph: **replace-first** (deterministisch),
**fix-now** correctie-flow, prompt-bias uitgesteld tot na empirische test.*

## Probleem & doel

Whisper mist consequent bepaalde eigennamen, jargon en unieke spellingen (bv. "Naslag", "Zelesta",
klantnamen). Doel: een **persoonlijke woordenlijst** die Fluister bij elk dictaat toepast, plus een
manier om die lijst te **laten groeien uit je eigen correcties** — zonder ergens stiekem mee te kijken
(past bij Fluisters privacy-belofte).

## Scope (v1) & niet-doelen

**In v1 (deze spec):**
- Woordenlijst van **correctie-paren** (fout → goed), lokaal opgeslagen, handmatig te beheren.
- **Deterministische vervanging** van die paren in de dicteer-keten (ná transcriptie, vóór invoegen).
- **"Corrigeer laatste dictaat"-flow** met **fix-now**: je fixt een woord, Fluister (a) leert het paar
  en (b) vervangt de al-ingevoegde tekst meteen.
- Instellingen-UI om paren te beheren.

**Niet in v1 (uitgesteld / niet-doel):**
- **Prompt-bias** (`promptTokens` naar Whisper). Kansrijk maar probabilistisch en kan termen ten onrechte
  invoegen → eerst empirisch testen (aparte mini-batch), dán pas toevoegen. Het datamodel is er wél op
  voorbereid (zie hieronder).
- **Automatisch meekijken** met alle edits overal (de invasieve Wispr-variant). Bewust niet.
- Cloud/sync. Alles lokaal.

## Architectuur

Volgt Fluisters bestaande splitsing: pure, testbare logica los van UI/keten (zoals `AppSettings`
en de losgekoppelde `finish()`-naden).

### 1. `DictionaryStore` (opslag + model)

- Entry-model, nu al uitbreidbaar naar bias later:
  ```
  DictionaryEntry {
    wrong: String?      // wat Whisper produceert (nil = alleen term, voor latere bias)
    right: String       // de juiste spelling/term
  }
  ```
  In v1 zijn alle entries **paren** (`wrong` gevuld). Term-only entries (`wrong == nil`) zijn
  gereserveerd voor de latere bias-fase.
- Persistentie: JSON in Application Support (`~/Library/Application Support/Fluister/dictionary.json`),
  achter een injecteerbare naad (pad/loader) zodat tests een ephemeral store gebruiken — zelfde patroon
  als `AppSettings(defaults:)`.
- Pure helpers, geen UI/netwerk.

### 2. Toepassing in `DictationController.finish()`

Op de bewezen plek (ná de lege-check op de transcriptie, vóór `inserter.insert(...)`):
```
let out = DictionaryFormatter.apply(text, pairs: store.pairs)
inserter.insert(out)
```
- `DictionaryFormatter.apply(_:pairs:)` — **puur**. Voor elk paar: **hele-woord, case-bewuste**
  vervanging van `wrong` → `right`.
- **False-positive-discipline (geleerd van leestekens):** alleen op woordgrenzen (`\b`), zodat een
  paar geen deelwoorden of tokens (e-mails/URLs) raakt. Case-behoud: als de match met hoofdletter
  begint, `right` ook (of: `right` exact overnemen — te bepalen in het plan met tests).
- Volgorde: langste `wrong` eerst, zodat overlappende paren niet half matchen.

### 3. "Corrigeer laatste dictaat" (fix-now)

- Fluister onthoudt de **laatste ingevoegde tekst** (in `DictationController`/`AppModel`) plus wat 'ie
  invoegde (voor de fix-now-terugrol).
- Invocatie: menubar-item **"Corrigeer laatste dictaat"** + een sneltoets (default bv. ⌥⇧Space,
  instelbaar later).
- Flow:
  1. Klein venster toont de laatste tekst, bewerkbaar.
  2. Jij fixt een woord.
  3. Fluister **diff't** oud vs nieuw op woordniveau → de gewijzigde woorden worden **fout→goed-paren**
     en gaan de store in (dedup tegen bestaande).
  4. **Fix-now:** Fluister vervangt de al-ingevoegde tekst door de gecorrigeerde versie.
- **Fix-now-mechaniek:** werkt schoon als je 't **direct na een dictaat** doet (cursor staat nog achter
  de invoeging). Aanpak: Fluister weet wat 'ie invoegde en hoe lang → verwijder die tekens
  (backspace via CGEvent, zoals `TextInserter` al doet) en plak de gecorrigeerde tekst.
  **Fallback** als in-place onveilig is (focus/cursor verplaatst): gecorrigeerde tekst naar het klembord +
  melding "geplakt kon niet, staat op je klembord". Details/keuze → plan, test-first.

### 4. Instellingen-UI

Nieuw blok in `SettingsView` (of los venster): lijst van paren met **toevoegen / bewerken / verwijderen**.
Handmatig toevoegen = een `wrong → right`-paar invullen (voor v1; term-only volgt met bias).

## Risico's

- **Verkeerde vervanging** — een paar dat een correct woord raakt. Mitigatie: hele-woord-match, dedup,
  en de gebruiker beheert de lijst zelf (kan een paar verwijderen).
- **Fix-now cursor-aanname** — werkt het best direct na een dictaat; fallback naar klembord.
- **Case/meervoud** — "naslag" vs "Naslag" vs "naslags". v1: exacte hele-woord-match, case-behoud;
  meervoudsvormen zijn losse paren. Niet slimmer maken dan nodig.
- **Groei van de lijst** — bij honderden paren blijft hele-woord-scan snel genoeg (lineair over korte
  dictaten). Geen probleem op deze schaal.

## Testbaarheid

- `DictionaryStore` (default-leeg, persistentie, dedup) en `DictionaryFormatter.apply` (hele-woord,
  case, volgorde, token-veiligheid) zijn **puur → unit-getest** (zoals de vorige formatter/AppSettings).
- De diff (oud vs nieuw → paren) is puur → unit-getest.
- De correctie-UI + fix-now-invoeging = handmatige test.

## Vervolg na v1

- **Prompt-bias empirisch testen** (aparte mini-batch, zoals de interpunctie-test): term-entries als
  `promptTokens` meegeven, meten of Whisper ze vaker goed spelt én hoe vaak 'ie ze spookt. Bij positief
  resultaat: bias toevoegen als tweede laag (term-only entries activeren).
- Sneltoets voor "corrigeer" instelbaar maken; case-/meervoud-slimmer indien nodig.
