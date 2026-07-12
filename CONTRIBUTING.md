# Bijdragen aan Fluister

Fijn dat je meedoet. Fluister is klein en blijft klein, dus een paar dingen vooraf.

## Wat Fluister is (en blijft)

Lokaal dicteren op macOS. ⌥Space ingedrukt houden, praten, tekst op je cursor. Meer niet.

- **Alleen macOS** (Apple Silicon, macOS 14+). Geen Windows, geen iOS.
- **100% lokaal.** Geen cloud, geen telemetrie, geen accounts. Elke PR die daar
  aan tornt wordt niet gemerged.
- **Small-only.** Eén model, geen keuzemenu. Bewust simpel.

Ai-opschoning (filler eruit, interpunctie) is een aparte, latere laag, geen onderdeel
van deze kern.

## Bouwen

Je hebt volledige **Xcode** nodig (niet alleen Command Line Tools) en
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate          # genereert Fluister.xcodeproj uit project.yml
open Fluister.xcodeproj     # ontwikkelen in Xcode (Cmd R)
```

Het `.xcodeproj` is gegenereerd en staat niet in de repo, dus draai `xcodegen generate`
na het clonen. Alle projectconfiguratie leeft in `project.yml`.

## Testen

```bash
./test.sh
```

Draait de volledige XCTest-suite. Houd 'm groen: een PR met rode tests wordt niet
gemerged. Nieuw gedrag hoort een test te hebben.

## Stijl

- Volg de bestaande conventies (kleine, testbare naden; pure functies waar het kan).
- Commentaar en teksten mogen Nederlands zijn, net als de rest van de codebase.
- Houd changes klein en gericht. Eén ding per PR.

## Beveiliging

Vond je een beveiligingsprobleem? Meld het niet als publieke issue. Zie
[`SECURITY.md`](SECURITY.md).
