# Beveiliging & privacy

Fluister is een lokale dicteer-app. De kern van het ontwerp is dat **je stem en je
tekst je Mac niet verlaten**. Dit document legt uit wat de app wél en niet doet,
waarom bepaalde permissies nodig zijn, en hoe je een kwetsbaarheid meldt.

## Wat Fluister doet

- Neemt je microfoon op zolang je de sneltoets ingedrukt houdt (push-to-talk).
- Transcribeert die opname **lokaal** op de Neural Engine via
  [WhisperKit](https://github.com/argmaxinc/WhisperKit).
- Voegt de getranscribeerde tekst in op je cursor via een synthetische ⌘V.

## Wat Fluister níét doet

- **Geen keylogger.** De app leest je toetsaanslagen niet en registreert ze niet.
  De Toegankelijkheid-permissie wordt uitsluitend gebruikt om tekst te *plakken*
  op je cursorpositie, niet om invoer te lezen.
- **Geen telemetrie, geen analytics, geen accounts.** De app stuurt geen gebruiks-,
  crash- of identiteitsgegevens naar wie dan ook.
- **Geen logging van transcripties.** Je gesproken tekst wordt niet naar schijf
  geschreven of ergens bewaard buiten het tekstveld waar jij 'm invoegt.
- **Geen cloud-transcriptie.** Er is geen server-fallback; alle inferentie is lokaal.

## Netwerkverkeer — eerlijk en volledig

De app maakt **één** soort netwerkverbinding:

- **Eenmalige modeldownload.** Bij het eerste gebruik downloadt WhisperKit het
  `small` Whisper-model van Hugging Face en cachet dat lokaal. Daarna werkt Fluister
  volledig offline.

Er is geen enkele andere uitgaande verbinding. De "ralphoei.ai openen"-link opent
je browser wanneer je er zelf op klikt; de app zelf haalt niets van die site op.

## Waarom deze permissies

| Permissie | Waarom | Zonder deze permissie |
|-----------|--------|-----------------------|
| Microfoon | Om je stem lokaal te transcriberen | Geen opname mogelijk |
| Toegankelijkheid | Om de tekst op je cursor in te voegen (⌘V) | Tekst kan niet worden geplakt |
| Niet-gesandboxt | System-wide tekst invoegen kan niet vanuit de App Sandbox | Insertie werkt alleen binnen de app zelf |

De app is bewust **niet** via de Mac App Store gedistribueerd, omdat system-wide
tekst-insertie niet is toegestaan binnen de sandbox. Distributie gaat via een
Developer ID-gesigneerde, door Apple genotariseerde build.

## Extra waarborg

- Fluister injecteert **geen** synthetische toetsaanslagen wanneer een beveiligd
  invoerveld actief is (wachtwoordvelden): de app detecteert `IsSecureEventInput`
  en slaat de insertie dan over.
- Het klembord wordt vóór het plakken opgeslagen en direct daarna hersteld, zodat
  je bestaande klembord-inhoud niet verloren gaat.
- Alle afhankelijkheden staan gepind in `Package.resolved` (WhisperKit,
  KeyboardShortcuts en hun transitieve dependencies, alle permissief gelicenseerd).

## Ondersteunde versies

Beveiligingsupdates gelden voor de laatste release. Vereist macOS 14 of nieuwer op
Apple Silicon.

## Een kwetsbaarheid melden

Vond je een beveiligingsprobleem? Mail **hallo@ralphoei.ai** met een beschrijving en,
indien mogelijk, reproductiestappen. Meld het bij voorkeur privé (niet als publieke
issue) totdat er een fix is. Je krijgt binnen 5 werkdagen een reactie.
