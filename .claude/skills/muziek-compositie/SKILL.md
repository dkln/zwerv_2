---
name: muziek-compositie
description: Gebruik als de gebruiker een nieuwe compositie aanlevert (een uitgeschreven nummer van Gemini of een andere componist: tempo, toonsoort, instrumenten, akkoorden en noten per maat; in tools/muziek/composition.md of geplakt) en vraagt daar de muziek van ZWERVR van te maken; zet de compositie letterlijk om naar tools/muziek/composities/<naam>.py, rendert de intro en alle afgeleide stukken (menu, karakterkeuze, handelaar, laadscherm, spel, deuntjes, ook het deuntje voor de start van de kaart) in Mega Drive-klank en controleert ze.
---

# Een nieuwe compositie wordt de muziek van ZWERVR

Lees eerst `docs/MUZIEK.md` (de regels, de notatie, de klanken, de afgeleide stukken) en het
vorige compositiebestand in `tools/muziek/composities/` als voorbeeld van de notatie (niet van de
inhoud: **niets** uit een vorige compositie overnemen). Werk zelfstandig door, zonder tussentijdse
vragen.

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
   `MAP_JINGLE` in `scripts/ui/hud.gd`); nooit een oud bestand van een vorige compositie laten
   staan. Gebruikt het spel een stuk dat `derive.py` nog niet maakt, voeg het daar toe (`ALL`) en in
   de tabel van `docs/MUZIEK.md`.
5. **Controleer**: `tools/muziek/render.sh --controle --balans`.
   - alles moet "muziek ok" zijn (lengte, -16 LUFS, piek, naad, geen stilte in een lus);
   - noten buiten de toonsoort: vergelijk met de tekst; staat het zo in de tekst, dan blijft het
     (chromatiek van de componist); anders is het een overschrijffout: verbeteren;
   - de balans (zie `docs/MUZIEK.md`): wijkt een partij meer dan 3 dB af van de richtlijn, pas
     dan het niveau van die klank aan (`gain` in `instruments.py`), niet de noten;
   - de energie per sectie: het refrein en de finale horen het luidst, de breakdown het zachtst.
6. **Past de vorm niet** bij de afleidingen (geen thema, geen finale, heel andere maatsoort),
   pas dan `tools/muziek/derive.py` algemeen aan (zodat het voor elke compositie werkt) en zet
   het in "Afgeleide stukken" van `docs/MUZIEK.md`.
7. **Speltests** (één tegelijk, headless):
   `tools/godot.sh --headless --script tools/check/intro_test.gd` en
   `tools/godot.sh --headless --script tools/check/city_music_test.gd`.
8. **Meld** aan de gebruiker: titel, tempo, toonsoort, lengte van de intro, wat er is afgeleid
   (welke gaten, met reden), nieuwe klanken, de uitkomst van de controle, en dat je het niet
   hebt beluisterd. Niet committen.
