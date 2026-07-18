# Changelog

Alle noemenswaardige wijzigingen aan Fluister staan hier. Formaat volgt losjes
[Keep a Changelog](https://keepachangelog.com/); versies volgen [SemVer](https://semver.org/).

## [0.1.0] — 2026-07-13

Eerste publieke release.

### Toegevoegd
- Lokaal dicteren op macOS: ⌥Space ingedrukt houden, praten, loslaten, en de
  getranscribeerde tekst verschijnt op je cursor.
- Volledig lokale transcriptie via [WhisperKit](https://github.com/argmaxinc/WhisperKit)
  op de Neural Engine (model `small`).
- Menu-bar app zonder dock-icoon, met een begeleide eerste-start voor de microfoon-
  en toegankelijkheidspermissie.
- Instelbare taal (Nederlands / Engels), sneltoets en start-bij-inloggen.
- Klembord-veilige tekst-insertie met beveiliging tegen invoer in wachtwoordvelden.
- App-icoon en een gestileerde installer-DMG met sleep-naar-Programma's-instructie.
- Zichtbare voortgang bij de eenmalige model-download (percentage in het menu),
  zodat de eerste start niet lijkt vast te lopen.

### Gewijzigd (build 3)
- De eenmalige model-download is nu ook zichtbaar buiten het menu: het
  welkomstvenster toont een stap 3 "Taalmodel" met voortgangsbalk, en ⌥Space
  indrukken terwijl het model nog laadt haalt dat venster naar voren met de
  download-status. Voorheen stond het percentage alleen in het menu, dat mensen
  bij de eerste start niet openden ("app werkt niet na starten").
- De onboarding meldt pas "alles staat klaar" als óók het model geladen is,
  in plaats van zodra de permissies rond zijn.
- Onboarding-stapteksten wrappen nu netjes i.p.v. af te kappen.
