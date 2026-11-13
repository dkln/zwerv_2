---
name: muziek-compositie
description: Gebruik als de gebruiker een nieuwe compositie aanlevert (een uitgeschreven nummer van Gemini of een andere componist: tempo, toonsoort, instrumenten, akkoorden en noten per maat; in tools/muziek/composition.md of geplakt; of een VGM-bestand, .vgm/.vgz, het registerlog van de Mega Drive-geluidschips) en vraagt daar de muziek van ZWERVR van te maken; zet de compositie letterlijk om naar tools/muziek/composities/<naam>.py (een VGM met tools/muziek/render.sh --vgm: de intro is dan het VGM zelf, exact nagebootst uit het registerlog, en de afgeleide stukken klinken met de patches van het VGM), rendert de intro en alle afgeleide stukken (menu, karakterkeuze, handelaar, laadscherm, spel, deuntjes, ook het deuntje voor de start van de kaart, de drie muzaklussen van de supermarkten en de jingles van de twee supermarktketens) in Mega Drive-klank en controleert ze.
---

# Een nieuwe compositie wordt de muziek van ZWERVR

Lees eerst `docs/MUZIEK.md` (de regels, de notatie, de klanken, de afgeleide stukken) en het
vorige compositiebestand in `tools/muziek/composities/` als voorbeeld van de notatie (niet van de
inhoud: **niets** uit een vorige compositie overnemen). Werk zelfstandig door, zonder tussentijdse
vragen.

Levert de gebruiker een **VGM-bestand** (`.vgm` of `.vgz`) in plaats van een tekst, dan gaan
stap 1 en 2 anders: zie "Een VGM-bestand" hieronder; stap 3 tot en met 8 blijven gelijk.

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
   - `MOMENTEN` voor de intro (`logo`, `verhaal`, `hoogtepunt`, `duel`, `crash`, `rust`): het
     logo op de eerste grote inzet (na ten minste 6 s: daarvoor staat de openingsregel), het
     verhaal een paar maten later, de volgende drie op de grootste wendingen (refrein, breakdown,
     finale), oplopend, en `rust` als (maat, tel) op de eindklap. Kies ze zo dat het verhaal
     gelijkmatig rolt (in `scripts/ui/intro.gd` wijst `CRAWL_CUES` de alinea's aan die op
     hoogtepunt, duel en crash binnenkomen: pas die aan als het tempo van het rollen anders
     ongelijk wordt; streef naar gelijke tijd per alinea).
   - **Een wens van de gebruiker** (blijer, sneller, een stijl als voorbeeld): niet in de maten,
     maar in `BIJSTELLING` (docs/MUZIEK.md), met de reden en de datum als commentaar. Bij een
     voorbeeld uit een bestaand nummer alleen kenmerken (groove, tempo, klankkleur), nooit noten.
3. **Zet hem actief**: `ACTIEF = "<naam>"` in `tools/muziek/composities/actief.py`.
4. **Render**: `tools/muziek/render.sh` (alles naar `assets/audio/muziek/`, plus
   `scripts/ui/intro_timing.gd`). Een fout in het compositiebestand geeft een melding met de
   maat; verbeter en render opnieuw.
   Alle stukken uit "Afgeleide stukken" van `docs/MUZIEK.md` moeten er komen, ook de deuntjes en
   **altijd het deuntje voor de start van de kaart** (`deuntje_kaart_start.ogg`, hooguit 6 s:
   `MAP_JINGLE` in `scripts/ui/hud.gd`), en **altijd de supermarkten**: de drie muzaklussen
   `supermarkt_muzak_1.ogg` (bossa), `_2` (ballade), `_3` (lichte swing), zacht op de
   achtergrond in elk filiaal (`SUPERMARKET_MUZAK` in `scripts/world/interiors.gd`), en de
   jingles `jingle_derrek.ogg` en `jingle_alfred_steyhn.ogg` (voor de omroep in de winkel,
   `scripts/world/supermarket_announcer.gd`, hooguit 6 s); `derive.py` maakt ze uit het thema en
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
   `tests/run_integration_tests.sh city_music`.
## Een VGM-bestand

Een VGM is het logboek van de registers van de YM2612 (FM) en de SN76489 (PSG). Het wordt
**exact** de muziek (docs/MUZIEK.md, "Een VGM als compositie"): de **intro is het VGM zelf**,
gespeeld door de nabootsing van de chips (`tools/muziek/chip.py`: de patches, de exacte
frequenties uit F-number en blok, de envelopes, de volumes, de panning), en de afgeleide stukken
klinken met de **stemmen van het VGM** (de patches van zijn kanalen, een drumstel van zijn
PSG-ruis). Dus: geen bestaande klanken uit `instruments.py` in plaats van de patches, geen
octaaf verschoven in de intro, geen noten met de hand overschrijven of "verbeteren".

1. **Bekijk het bestand**: `tools/muziek/render.sh --vgm <bestand> [naam] --toon` (`<naam>`:
   standaard de bestandsnaam in kleine letters met underscores). Lees wat het meldt: de chips, per
   kanaal het aantal noten en het bereik, het tempo (en of een getal in de bestandsnaam, bv.
   `_92`, het tempo is: alleen als het op het raster van de noten past), de maatsoort, de
   toonsoort, de secties, de akkoorden en elke "let op".
2. **Zet het om**: `tools/muziek/render.sh --vgm <bestand> [naam]` schrijft
   `tools/muziek/composities/<naam>.py` en bewaart het VGM ongewijzigd als
   `tools/muziek/composities/<naam>.vgm` (de intro wordt daaruit gespeeld: het moet daar blijven;
   staat het VGM elders in het project, haal het daar dan weg). Klopt het tempo niet (de noten
   liggen ver van het raster, of het getal in de naam is wel het tempo maar wordt niet gevonden),
   geef dan `--tempo <BPM>`; bestaat het bestand al, dan `--overschrijf`. Het bestand heeft
   `VGM` (de intro), `KLANKEN` en `AFGELEIDE_KLANKEN` met `vgm:<bestand>:<kanaal>=<klank>` (de
   patch van dat kanaal, op de plek in de mix van die klank) en zo nodig `AFGELEID_OCTAAF`
   (alleen de afgeleide stukken). Lees het na en verbeter met de hand alleen wat de omzetter
   raadt, met de reden als commentaar:
   - de `soort` van de secties (en hun grenzen) als de vorm anders is dan gevonden;
   - akkoorden die niet bij de noten van de maat passen;
   - `MOMENTEN` (zelfde regels als bij een tekst, stap 2 hierboven);
   - welke patch van het VGM welke soort klank speelt in de afgeleide stukken
     (`AFGELEIDE_KLANKEN`: altijd een `vgm:`-stem van ditzelfde VGM, nooit een gewone klank);
   - de noten in `MATEN` **niet**, en `VGM` niet weghalen: zonder `VGM` wordt de intro weer uit
     de noten nagespeeld in plaats van uit het log.
   Een wens van de gebruiker die de intro verandert (ander tempo, andere klank) kan niet samen
   met "exact het VGM": zeg dat, en doe het alleen als de gebruiker het dan nog wil.
3. Ga verder met stap 3 tot en met 7 hierboven (actief zetten, renderen, controleren, de vorm,
   de speltests). Bij het **controleren** komt erbij:
   - `tools/muziek/render.sh --vgm <bestand> [naam] --vergelijk`: elke partij van het
     compositiebestand moet "gelijk" zijn aan het VGM (aantal noten, plek, toonhoogte, lengte, de
     drums); "ANDERS" is een fout;
   - `tools/muziek/render.sh --vgm <bestand> [naam] --meet` (na het renderen): de nabootsing
     tegen het registerlog (de toonhoogte van elke noot per kanaal in cent, het niveau van de
     ruis-slagen) en de intro tegen de nabootsing (lengte, correlatie, niveau per deel); het
     moet eindigen met "de nabootsing komt overeen met het registerlog", en elke regel "niet
     nagebootst" (LFO, SSG-EG, CSM) moet in het verslag;
   - de balans van de intro is die van het VGM (`--balans` laat zijn kanalen zien): niet
     bijstellen, ook niet als hij van de richtlijn afwijkt.
   De unit tests doen de vergelijking en kijken of de intro het VGM is en de afgeleide stukken
   alleen `vgm:`-stemmen gebruiken, voor elke compositie met een `.vgm` ernaast.
4. **Meld** (stap 8) ook: wat het VGM bevatte (chips, kanalen en hun partij, tempo en hoe het
   met de bestandsnaam zat, toonsoort, lengte); dat de intro het VGM zelf is en wat daarin
   exact is en wat benaderd (docs/MUZIEK.md, "De nabootsing van de chips") of niet nagebootst;
   de uitkomst van `--meet`; welke patch welke klank speelt in de afgeleide stukken en welke
   drums afgeleid zijn (wat het VGM zelf niet heeft: bv. kick, crash); wat de omzetter heeft
   afgeleid (akkoorden, secties, octaven) en wat je met de hand hebt verbeterd; en elke "let op"
   (afgekapte F-numbers, overgeslagen commando's), kanalen zonder noten, ontbrekende drums.

## Melden

8. **Meld** aan de gebruiker: titel, tempo, toonsoort, lengte van de intro, de lengte van de drie
   muzaklussen en de jingles, wat er is afgeleid
   (welke gaten, met reden), nieuwe klanken, de uitkomst van de controle, en dat je het niet
   hebt beluisterd. Niet committen.
