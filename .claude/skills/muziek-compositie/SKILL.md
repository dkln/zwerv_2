---
name: muziek-compositie
description: Gebruik als de gebruiker een nieuwe compositie aanlevert en vraagt daar de muziek van ZWERVR van te maken. Er zijn drie basissoundtracks en de gebruiker zegt welke vervangen wordt - primair (de intro; daarvan afgeleid alle deuntjes en liedjes van het spel), secundair (het menu, letterlijk; daarvan afgeleid de karakterkeuze, het laadscherm, de stad, de beloning en level omhoog) of tertiair (de vechtscène, letterlijk). De voorkeursbron is een compositie in JSON (docs/MUZIEK_JSON.md: de export van de tracker van Gemini of een andere componist, met metadata, sections, synthParameters en bars, of de platte vorm met bpm bovenaan en per maat lead/brass/arp/bass/drums; tools/muziek/render.sh --json); het kan ook een uitgeschreven nummer zijn (tempo, toonsoort, instrumenten, akkoorden en noten per maat; in tools/muziek/composition.md of geplakt), een tracker-pagina (HTML, render.sh --tracker). Zet de compositie letterlijk om naar tools/muziek/composities/&lt;naam&gt;.py, zet hem op zijn plek in composities/actief.py (ACTIEF, MENU of GEVECHT), rendert alle stukken (intro, menu, karakterkeuze, handelaar, laadscherm, spel, deuntjes, ook het deuntje voor de start van de kaart en dat van een beloning, de drie muzaklussen van de supermarkten en de jingles van de twee supermarktketens, en de vechtscène als die er is) en controleert ze.
---

# Een nieuwe compositie wordt de muziek van ZWERVR

Lees eerst `docs/MUZIEK.md` (de regels, de notatie, de klanken, de afgeleide stukken) en het
vorige compositiebestand in `tools/muziek/composities/` als voorbeeld van de notatie (niet van de
inhoud: **niets** uit een vorige compositie overnemen). Werk zelfstandig door, zonder tussentijdse
vragen.

VGM-bestanden worden niet meer gelezen (de VGM-logica is weg): vraag dan om het JSON van de
componist (docs/MUZIEK_JSON.md).

## Welke basissoundtrack

Er zijn drie basissoundtracks, elk een plek in `tools/muziek/composities/actief.py`
(docs/MUZIEK.md, bovenaan). Een nieuwe compositie **vervangt er één**:

| plek | `actief.py` | klinkt letterlijk als | wordt ervan afgeleid |
| --- | --- | --- | --- |
| **primair** (intro) | `ACTIEF` | de intro (`zwervr_intro.ogg`, met `MOMENTEN`, `intro_timing.gd`) | de andere deuntjes en liedjes: handelaar, de kaart, missie- en taakdeuntjes, gewonnen, dood, de supermarkten en hun jingles |
| **secundair** (menu) | `MENU` | het hoofdmenu (`nachtstad_menu_loop.ogg`, als lus) | de karakterkeuze, het laadscherm, de stad (`spel_loop`), de beloning en level omhoog (`derive.SECONDARY_PIECES`) |
| **tertiair** (vechtscène) | `GEVECHT` | de vechtscène (`gevecht.ogg`: het hele nummer, één bestand) | niets |

Alle andere deuntjes en liedjes zijn op de primaire of de secundaire gebaseerd; voor het menu en
de vechtscène maak je **geen** afgeleide: daar klinkt het origineel, precies zoals aangeleverd.
De stukken die uit de secundaire komen houden de **eigen groove** van dat nummer (de bas en de drums
zoals geschreven: `derive.GROOVE_VARIANTS`), niet de bewerkingen die voor de primaire gemaakt zijn. Zegt de gebruiker niet welke
plek, vraag het dan (het is de enige vraag die je stelt). Een compositie voor het menu of de
vechtscène heeft geen `MOMENTEN` nodig (die zijn er alleen voor de intro). De andere plekken laat
je zoals ze zijn; de plek die je vervangt mag een vorige compositie hebben gehad (die blijft
staan in `composities/`).

## Stappen

1. **Lees de compositie** uit `tools/muziek/composition.md` (daar levert de gebruiker hem aan;
   geplakt: zet hem daar neer). **Bewaar het origineel** ook ongewijzigd als
   `tools/muziek/composities/<naam>.txt`
   (`<naam>`: de titel in kleine letters met underscores); `composition.md` zelf laat je staan.
2. **Zet het letterlijk over** naar `tools/muziek/composities/<naam>.py`, maat voor maat:
   - `TITEL`, `TEMPO`, `TELLEN_PER_MAAT`, `TOONSOORT` zoals de tekst ze geeft;
   - `KLANKEN`: elke partij (kanaal) van de tekst een klank uit `tools/muziek/instruments.py`
     (`SOUNDS`); past er geen, maak dan een nieuwe klank erbij (een `FmPatch` of PSG-instelling,
     naam die zegt wat hij is) en zet hem in de klanktabel van `docs/MUZIEK.md`;
   - `SECTIES` zoals de tekst ze indeelt, elk met een `soort` (intro, thema, opbouw, refrein,
     breakdown, finale: de functie in het nummer, niet de naam), en in `standaard` wat elke
     maat van die sectie speelt als de tekst het voor de hele sectie zegt (vaak de drums);
   - `MATEN`: elke uitgeschreven noot op zijn tel met zijn lengte (`notes`, `cycle`, `run`), de
     akkoorden, de drums en fills (`drums`, `drum_run`);
   - **gaten**: speelt een partij volgens de tekst wel maar staan haar noten er niet (bijv. "de
     bas speelt pompende octaven" maar een sectie noemt de bas niet), vul dan uit die beschrijving
     in dezelfde tekst, en schrijf bij de maat `# afgeleid: ...` met de reden;
   - (alleen primair) `MOMENTEN` voor de intro (`logo`, `verhaal`, `hoogtepunt`, `duel`, `crash`, `rust`): het
     logo op de eerste grote inzet (na ten minste 6 s: daarvoor staat de openingsregel), het
     verhaal een paar maten later, de volgende drie op de grootste wendingen (refrein, breakdown,
     finale), oplopend, en `rust` als (maat, tel) op de eindklap. Kies ze zo dat het verhaal
     gelijkmatig rolt (in `scripts/ui/intro.gd` wijst `CRAWL_CUES` de alinea's aan die op
     hoogtepunt, duel en crash binnenkomen: pas die aan als het tempo van het rollen anders
     ongelijk wordt; streef naar gelijke tijd per alinea).
   - **Een wens van de gebruiker** (blijer, sneller, een stijl als voorbeeld): niet in de maten,
     maar in `BIJSTELLING` (docs/MUZIEK.md), met de reden en de datum als commentaar. Bij een
     voorbeeld uit een bestaand nummer alleen kenmerken (groove, tempo, klankkleur), nooit noten.
3. **Zet hem op zijn plek** in `tools/muziek/composities/actief.py` ("Welke basissoundtrack"):
   `ACTIEF = "<naam>"` (primair), `MENU = "<naam>"` (secundair) of `GEVECHT = "<naam>"`
   (tertiair). De docstring van het compositiebestand zegt welke plek het is (de omzetter schrijft
   "de intro": pas dat aan voor het menu of de vechtscène). Zet in `docs/MUZIEK.md` bij "Nu op de
   plekken" wat er nu staat.
4. **Render**: `tools/muziek/render.sh` (alles naar `assets/audio/muziek/`, plus
   `scripts/ui/intro_timing.gd`). Een fout in het compositiebestand geeft een melding met de
   maat; verbeter en render opnieuw.
   Alle stukken uit "Afgeleide stukken" van `docs/MUZIEK.md` moeten er komen, ook de deuntjes en
   **altijd het deuntje voor de start van de kaart** (`deuntje_kaart_start.ogg`, hooguit 6 s:
   `MAP_JINGLE` in `scripts/ui/hud.gd`), en **altijd de supermarkten**: de drie muzaklussen
   `supermarkt_muzak_1.ogg` (bossa), `_2` (ballade), `_3` (lichte swing), zacht op de
   achtergrond in elk filiaal (`SUPERMARKET_MUZAK` in `scripts/world/interiors/interiors.gd`), en de
   jingles `jingle_derrek.ogg` en `jingle_alfred_steyhn.ogg` (voor de omroep in de winkel,
   `scripts/world/interiors/supermarket_announcer.gd`, hooguit 6 s); `derive.py` maakt ze uit het thema en
   het refrein (zie "De muzak" in `docs/MUZIEK.md`), dus ze komen vanzelf mee. Heeft een
   compositie geen thema of refrein, of klinkt de gezoete harmonie vreemd (andere toonsoort,
   modus), pas dan `derive.py` algemeen aan. Nooit een oud bestand van een vorige compositie laten
   staan. Gebruikt het spel een stuk dat `derive.py` nog niet maakt, voeg het daar toe (`ALL`) en in
   de tabel van `docs/MUZIEK.md`.
5. **Controleer**: `tools/muziek/render.sh --test` (de unit tests: alles moet slagen) en
   `tools/muziek/render.sh --controle --balans`.
   - alles moet "muziek ok" zijn (lengte, -16 LUFS, piek, naad, geen stilte in een lus);
   - noten buiten de toonsoort: vergelijk met de tekst; staat het zo in de tekst, dan blijft het
     (chromatiek van de componist); anders is het een overschrijffout: verbeteren;
   - de balans (zie `docs/MUZIEK.md`): wijkt een partij meer dan 3 dB af van de richtlijn, pas
     dan het niveau van die klank aan (`gain` in `instruments.py`), niet de noten;
   - de energie per sectie: het refrein en de finale horen het luidst, de breakdown het zachtst.
   - de muzak: drie lussen van ongeveer een minuut, zonder naad; in de balans hoort de melodie
     (fluit, vibrafoon, piano, klokken) boven de begeleiding, de strijkers en de drums ver
     eronder (achtergrond); de jingles kort en in majeur.
6. **Past de vorm niet** bij de afleidingen (geen thema, geen finale, heel andere maatsoort),
   pas dan `tools/muziek/derive.py` algemeen aan (zodat het voor elke compositie werkt) en zet
   het in "Afgeleide stukken" van `docs/MUZIEK.md`.
7. **Speltests** (één tegelijk, headless):
   `tests/run_integration_tests.sh intro` en
   `tests/run_integration_tests.sh city_music` (bij een secundaire ook het menu en het laadscherm:
   de categorie `ui`).

Op Windows heeft elk script een `.ps1` ernaast met dezelfde argumenten (`tools\muziek\render.ps1`,
`tests\run_integration_tests.ps1`); verander je een `.sh`, verander dan de `.ps1` mee, en andersom.
## Een compositie in JSON (de voorkeursbron)

Een JSON-bestand zoals `docs/MUZIEK_JSON.md` het beschrijft (de export van de tracker van de
componist: `metadata`, `sections`, `synthParameters`, `bars` met per maat het akkoord en zes sporen
van zestien stappen) is de beste bron: de partituur staat er letterlijk in, niets hoeft terug
geluisterd of omgerekend.

1. Bekijk wat erin zit: `tools/muziek/render.sh --json <bestand.json> [naam] --toon`. Een bestand
   dat niet compleet is wordt geweigerd met per regel wat er mis is (een spoor dat ontbreekt, een
   spoor met een ander aantal vakjes dan 16, een onbekende noot of drum, maten niet op volgorde):
   geef dat door aan de gebruiker, verzin niets erbij. De **platte vorm** (`bpm` bovenaan, per maat
   `bar`, `lead`, `brass`, `arp`, `bass`, `drums`: docs/MUZIEK_JSON.md) wordt ook gelezen; meld
   wat daarbij geduid is (geen harmoniespoor, de drum `T` als middelste tom). Is het een andere vorm
   die nog niet gelezen wordt, voeg dan een vertaling toe in `json_bron.py` (zoals `from_flat`), met
   een unit test, en zet de vorm in docs/MUZIEK_JSON.md.
2. Schrijf de compositie: `tools/muziek/render.sh --json <bestand.json> [naam] --overschrijf`. Het
   JSON wordt naast de compositie bewaard (`composities/<naam>.json`) en `composities/<naam>.py`
   krijgt elke rij zoals het JSON hem geeft, met `TRACKER = "<naam>.json"`.
3. Zet hem op zijn plek (`composities/actief.py`: `ACTIEF`, `MENU` of `GEVECHT`), render alles (`tools/muziek/render.sh`), draai
   `render.sh --test` en `render.sh --controle`.
4. Meet de weergave: `render.sh --json composities/<naam>.json <naam> --meet [wav]`: de toonhoogte
   van de stemmen tegen de noten van de bron, links tegen rechts, de balans, en met een WAV van de
   componist erbij ook het spectrum en het niveau daartegen.

De intro is de partituur één keer gespeeld door de nagebouwde synth van de tracker van de
componist (`tools/muziek/tracker.py`: zijn zes stemmen, panning, mastervolume en compressor); de
afgeleide stukken gebruiken dezelfde stemmen (`tracker_bas`, `tracker_brass`, `tracker_lead`,
`tracker_harmonie`, `tracker_arp`, drumstel `tracker`).

**Let op bij wat een tracker-pagina exporteert.** Zo'n pagina kan drie verschillende dingen laten
horen: zijn eigen synth (wat je hoort bij afspelen: dát bouwen wij na), een WAV-export met een
versimpelde synth, en een VGM-export. Bij `nitro_overdrive_92` miste het VGM vier van de zes
stemmen en waren de toonhoogtes fout omgerekend (afgekapt op F-number 2047). Vertrouw dus het
JSON (of de pagina zelf, `render.sh --tracker <pagina.html>`), niet het VGM van zo'n pagina.

## Melden

8. **Meld** aan de gebruiker: welke plek vervangen is (primair, secundair, tertiair), titel,
   tempo, toonsoort, lengte van de intro (of het menu, de vechtscène), de lengte van de drie
   muzaklussen en de jingles, wat er is afgeleid
   (welke gaten, met reden), nieuwe klanken, de uitkomst van de controle, en dat je het niet
   hebt beluisterd. Niet committen.
