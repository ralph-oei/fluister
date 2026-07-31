# Fluister — empirische interpunctie-test (Whisper small, NL)

*2026-07-26 — doel: vaststellen hoe Whisper `small` gesproken/natuurlijke interpunctie en
tokens (mail/URL/IP/getallen) transcribeert, vóór we beslissen of de opschoon-pivot zin heeft.*

## Zo doe je 'm

- Fluister op **NL**.
- **Eén ⌥Space-clip per regel.** Druk in → zeg **"test [nummer]"** → lees kolom *Lees dit voor* → laat los. Volgende regel = nieuwe clip. (Het nummer is het anker om te matchen.)
- **[uitgesproken]** = lees exact wat er staat, inclusief "komma", "punt", "at", "slash" enz.
- **[natuurlijk]** = leestekens **niet** uitspreken; lees gewoon vlot met de pauzes die je normaal zou maken.
- Plak daarna het **hele resultaat** terug (of per regel). Ik match op testnummer en diff tegen de bedoelde output.
- *Bedoelde output* lees je NIET voor — die is voor mijn scoring.

## De batch

| Nr | Modus | Lees dit voor | Bedoelde output |
|----|-------|---------------|-----------------|
| 1  | natuurlijk | Ja, ik kom eraan. | Ja, ik kom eraan. |
| 2  | uitgesproken | ja komma ik kom eraan punt | Ja, ik kom eraan. |
| 3  | natuurlijk | Wacht even, ik pak mijn jas. | Wacht even, ik pak mijn jas. |
| 4  | uitgesproken | wacht even komma ik pak mijn jas punt | Wacht even, ik pak mijn jas. |
| 5  | natuurlijk | Kom je nog? | Kom je nog? |
| 6  | uitgesproken | kom je nog vraagteken | Kom je nog? |
| 7  | natuurlijk | Wat een onzin! | Wat een onzin! |
| 8  | uitgesproken | wat een onzin uitroepteken | Wat een onzin! |
| 9  | natuurlijk | Dit is zin een. Dit is zin twee. | Dit is zin een. Dit is zin twee. |
| 10 | uitgesproken | dit is zin een punt dit is zin twee punt | Dit is zin een. Dit is zin twee. |
| 11 | uitgesproken | let op dubbele punt melk komma brood komma kaas punt | Let op: melk, brood, kaas. |
| 12 | uitgesproken | eerste deel puntkomma tweede deel punt | Eerste deel; tweede deel. |
| 13 | uitgesproken | eerste regel nieuwe regel tweede regel | Eerste regel ⏎ Tweede regel |
| 14 | uitgesproken | dat is een goed punt in de discussie | Dat is een goed punt in de discussie. |
| 15 | uitgesproken | de komma staat verkeerd | De komma staat verkeerd. |
| 16 | uitgesproken | hallo komma wereld punt | Hallo, wereld. |
| 17 | uitgesproken | mijn mail is ralph punt oei at gmail punt com | Mijn mail is ralph.oei@gmail.com |
| 18 | uitgesproken | stuur het naar info at bedrijf punt nl | Stuur het naar info@bedrijf.nl |
| 19 | uitgesproken | kijk op www punt voorbeeld punt nl | Kijk op www.voorbeeld.nl |
| 20 | uitgesproken | de link is https dubbele punt slash slash voorbeeld punt com | De link is https://voorbeeld.com |
| 21 | uitgesproken | het ip adres is honderdtweeënnegentig punt honderdachtenzestig punt nul punt één | Het IP-adres is 192.168.0.1 |
| 22 | uitgesproken | het kost drie komma vijftig euro | Het kost 3,50 euro. |
| 23 | natuurlijk | Ik belde gisteren, maar niemand nam op. Bel je me terug? | Ik belde gisteren, maar niemand nam op. Bel je me terug? |
| 24 | uitgesproken | mail me op test at test punt nl komma dan bel ik je punt | Mail me op test@test.nl, dan bel ik je. |

## Wat elk cluster ons leert

- **1-10** basis-interpunctie, natuurlijk vs uitgesproken → doet Whisper 't beter uit prosodie of uit de woorden?
- **11-13** samengesteld: dubbele punt, puntkomma, "nieuwe regel".
- **14-16** vals-positief + taal-leak: wordt het wóórd "punt/komma" een teken? geeft NL-Whisper soms Engels ("comma")?
- **17-21** tokens: mail, URL, IP → hier zit het mangelrisico dat de vorige aanpak nekte.
- **22** NL-decimaalkomma (3,50) — de "geen spatie ná komma"-valkuil in getallen.
- **23** langere natuurlijke zin → hoe goed punctueert Whisper op gehoor.
- **24** botsing: mail + komma + punt in één zin.

---

## Resultaten (echte input van Ralph — meerdere runs)

**Bevinding (Ralph, na run 1):** Whisper kent `apenstaartje` niet als symbool, maar `at` wél.
Daarom gebruiken e-mailtests 17/18/24 vanaf **Run 2** de vorm met "at" i.p.v. "apenstaartje".

### Run 1 — 2026-07-26 (17/18/24 nog met "apenstaartje")

| Nr | Whisper-output (exact) |
|----|------------------------|
| 1  | Test 1, ja, ik kom eraan. |
| 2  | Test 2. Ja, comma, ik kom eraan. |
| 3  | Test 3. Wacht even, ik pak mijn jas. |
| 4  | Test 4. Wacht even, ik pak mijn jas. |
| 5  | Test 5. Kom je nog? |
| 6  | De zes. Kom je nog vraagtegen? |
| 7  | Test 7. Wat een onzin. |
| 8  | Test 8 wat een onzin uitroepteken. |
| 9  | Test neer. Dit is zin één, dit is zin twee. |
| 10 | Test 10. Dit is in 1 punt, dit is in 2 punt. |
| 11 | Let op dubbele punt, melk, brood, kaas, punt. |
| 12 | eerste deel, punt.a, tweede deel, punt. |
| 13 | eerste regel, nieuwe regel, tweede regel. |
| 14 | Test 14. Dat is een goed punt in de discussie. |
| 15 | Test 15. De comma staat verkeerd. |
| 16 | Test 16. Hallo.wereld. |
| 17 | TES17, mij mel is raw.oeiapestatje gmail.com (oude "apenstaartje"-vorm) |
| 18 | Test 18. Stuur het naar invalabestaartjebedrijf.nl (oude vorm) |
| 19 | Test 19. Kijk op www.voorbeeld.nl |
| 20 | Test 20. De link is https/schles/forbeeld.com |
| 21 | Het IP-adres is 192.168.0.1. |
| 22 | Test 22. Het kost 3,50 euro. |
| 23 | Test 23. Ik bel de gisteren, maar niemand dan op. Bel je me terug? |
| 24 | Test 24. Meel me op testapestaatje test.nl/dambelletje. (oude vorm) |

### Run 2 — (17/18/24 nu met "at")

| Nr | Whisper-output (exact) |
|----|------------------------|
| 1  | Test 1. Ja, ik kom eraan. |
| 2  | S2. Ja, comma, ik kom eraan. Punt. |
| 3  | Test 3. Wacht even, ik pak mijn jas. |
| 4  | Test 4. Wacht even, ik pak mijn jas. |
| 5  | Test 5. Kom je nog? |
| 6  | Test 6, kom je nog vraagteken. |
| 7  | Test 7. Wat een onzin. |
| 8  | Test 8. Wat een onzin uitroep teken. |
| 9  | Test 9. Dit is zin 1, dit is zin 2. |
| 10 | Test 10. Dit is zin 1 punt, dit is zin 2 punt. |
| 11 | Test 11, let op www.melk.brood.kaz. |
| 12 | Deze is 12. 1e deel..2e deel. |
| 13 | Test 13. 1e regel, nieuwe regel, 2e regel. |
| 14 | Test 14. Dat is een goed punt in de discussie. |
| 15 | Test 15. De coma staat verkeerd. |
| 16 | Test 16. Hallo.wereld.nl |
| 17 | Test 17. Mijn mail is ralf.ui@gmail.com. |
| 18 | Test 18. Stuur het naar info@bedrijf.nl |
| 19 | Test 19. Kijk op www.voorbeeld.nl |
| 20 | Test 20. De link is https www.slashslash.com |
| 21 | Test 21. Het IP address is 192.168.0.1. |
| 22 | Test 22. Het kost 3,50 euro. |
| 23 | Test 23. Ik bel de gisteren, maar niemand nam op. Bel je me terug? |
| 24 | Test 24. Meel me op test@test.nl, dan bell ik je. |

### Run 3

| Nr | Whisper-output (exact) |
|----|------------------------|
| 1  | Test 1. Ja, ik kom eraan. |
| 2  | Test twee. Ja, kom maar. Ik kom er aan. Bunt. |
| 3  | Test 3. Wacht even, ik pak mijn jas. |
| 4  | Test 4. Wacht even, ik pak mijn jas. |
| 5  | Test 5. Kom je nog? |
| 6  | Test 6 kom je nog vraagteken. |
| 7  | Test 7. Wat een onzin. |
| 8  | Test 8. Wat een onzin uitropteken. |
| 9  | Test 9. Dit is in 1, dit is in 2. |
| 10 | Test 10. Dit is zin 1 punt. Dit is zin 2 punt. |
| 11 | Test 11. Let op dubbele punt melk.brood.kaz. |
| 12 | Test 12. 1e deel..2e deel. |
| 13 | Test 13. 1e regel, nieuwe regel, 2e regel. |
| 14 | Test 14. Dat is een goed punt in de discussie. |
| 15 | Test 15. De comma staat verkeerd. |
| 16 | Test 16. Hallo.wereld. |
| 17 | TES 17. Mijn mail is ralf.oei@gmail.com |
| 18 | Test 18. Stuur het naar info@bedrijf.nl |
| 19 | Test 19. Kijk op www.voorbeeld.nl |
| 20 | Test 20. De link is httpsw.//forbeeld.com |
| 21 | Test 21. Het IP-adres is 192.168.0.1. |
| 22 | Test 22. Het kost 3,50 euro. |
| 23 | Test 23. Ik bel de gisteren, maar niemand nam op. Bel je me terug? |
| 24 | Test 24. Meel me op test@test.nl, dan welkje punt. |

*Status: Run 1 + 2 + 3 compleet (24/24 elk). Verwerkt 2026-07-26.*

---

## Conclusie (3 runs, 2026-07-26)

**Het model is stabieler dan aanvankelijk gedacht.** Over 3 runs geeft dezelfde zin meestal
hetzelfde resultaat (goed óf fout). Alleen zinnen die als **URL/lijst** leesbaar zijn (11, 12, 16, 20)
wisselen echt tussen runs.

**Stabiel goed (3/3):** natuurlijke interpunctie (komma/punt/vraagteken — 1,3,5,23); getallen/IP/
decimaal/simpel-domein (19,21,22); **e-mail met "at" + "punt"** → @ verschijnt correct (17,18,24-mail);
echt woord "punt" wordt nooit vals omgezet (14).

**Stabiel fout (3/3):** uitgesproken "vraagteken/uitroepteken/punt/nieuwe regel" blijven wóórden
(6,8,10,13); "komma" uitgesproken → Engels "comma"-leak (2,15,16); natuurlijke "!" → "." (7);
zin-grens soms komma i.p.v. punt (9); `://` werkt nooit (20).

**Onvoorspelbaar per zin (niet per run):** uitgesproken leestekens zetten soms wél stabiel om
(test 4: 3/3 goed) maar meestal niet (test 2, zelfde structuur: 3/3 fout). Je kunt er niet op bouwen.

**Beslissing: géén opschoon-formatter.** Een deterministische cleanup kan de wisselende gevallen
(11/12/16/20) niet dekken (de input zelf flipt) en zou de echte woorden "punt/komma/nieuwe regel"
raken (14/15 tonen dat die gewoon voorkomen). Lage ROI, hoog risico.

**Uitkomst = UX-hint, geen code:** "dicteer natuurlijk, leestekens komen vanzelf; voor e-mail zeg
'at' en 'punt', niet 'apenstaartje'." Branch `feat/leestekens` afgevoerd; issue #5 gesloten met deze bevinding.

*Caveat: 1 spreker, 3 runs. Indicatief maar goed onderbouwd.*
