---
name: muziek-prompt
description: Gebruik als de gebruiker een muziekprompt of uitgeschreven compositie plakt (Gemini-, Suno-, Udio-beschrijving, akkoordschema, structuur, instrumenten, tempo) en vraagt de muziek van ZWERVR daarop aan te passen; zet die om in een nieuw stijlprofiel in Sega Mega Drive-klank en rendert alle muziek en deuntjes opnieuw.
---

# Muziekprompt → nieuwe huisstijl (Mega Drive)

Doel: een geplakte beschrijving snel omzetten naar **alle** muziek en deuntjes van het spel,
altijd in Sega Mega Drive-klank. Werk zelfstandig door; eerst het profiel, dan renderen.
Lees vooraf `docs/MUZIEK.md` (de huisstijl en de contracten) en `tools/megadrive/stijlen/synthwave_rpg.py`.

## Snelle weg (meestal genoeg)

1. **Lees de prompt uit**: tempo, maatsoort, toonsoort en modus, akkoordschema per sectie,
   structuur (intro/A/B/solo/climax/outro), instrumenten per rol, drums, sfeer, tijdstempels.
2. **Nieuw profiel**: kopieer `tools/megadrive/stijlen/synthwave_rpg.py` naar
   `stijlen/<korte_naam>.py` en vul in:
   - `KEY`, `MODE` (`style.SCALES`: minor, major, dorian, harmonic_minor, phrygian, mixolydian)
   - `TEMPOS` (per soort stuk), `DRUMS` (`kick`: tight/fat, `snare`: gated/plain, `gate_seconds`)
   - de akkoordschema's als trapnamen in de toonsoort (`i`, `VI`, `bVII`, `V7`, `IVmaj7`, `VIIsus`, ...):
     `CITY_SECTIONS`, `BATTLE_SECTIONS`, `MENU_SECTIONS`, `INTRO_SECTIONS`, `MERCHANT_CHORDS`,
     `LOADING_CHORDS`, `CHARACTER_CHORDS`
   - het motief (`MOTIF_RHYTHM` in zestienden, `MOTIF_VARIANTS` in akkoordtrappen R 3 5 7 8 9)
   - de patches (`PATCHES`: FM-operatoren, `drive` voor overdrive) en `PIECES` (swing, energie, bas, gitaar)
3. Zet `ACTIVE_STYLE` in `tools/megadrive/style.py` op de nieuwe naam (het oude profiel blijft staan).
4. **Render alles**: `tools/megadrive/render.sh` (en `render.sh deuntjes`), dan
   `uv run --with numpy --with soundfile python3 tools/megadrive/check_music.py`.
   Balans per spoor: `ZWERVR_MUZIEK_SPOREN=1 tools/megadrive/render.sh gevecht`.

De melodieën in de nummers staan in trappen van de toonladder (`^1..^7`) en akkoordtrappen, dus een
nieuwe toonsoort, modus en nieuwe akkoorden volgen vanzelf.

## Als de prompt meer vraagt

- **Uitgeschreven melodieën/riffs**: zet ze als tekst in de nummers (`gevecht.py` de themafrases,
  `nachtstad_menu.py`, `zwervr_intro.py`, `stad_plan.THEMES` voor alle wijken), in trappen
  (`^5:4 ^1':6 ~^3':4`); notatie: docstring van `style.py`. Elke frase moet precies zijn maten vullen
  (de helpers geven anders een fout).
- **Andere vorm**: pas de secties in het profiel en de sectielussen in de nummers aan.
- **Nieuwe klank**: een patch in het profiel; is er echt iets nieuws nodig in de chip, dan in
  `megadrive.py` (bijv. een nieuw DAC-drumgeluid), binnen de grenzen hieronder.

## Moderne instrumenten → Mega Drive

Grenzen: YM2612 = 6 FM-kanalen, waarvan 1 de DAC (drums) → **5 FM-stemmen tegelijk**, 4 operatoren
per stem; SN76489 = **3 blokgolven (alleen 50%) + ruis**; DAC-samples ~8-17 kHz, 8 bit.
- elektrische gitaar: FM met hoge feedback + `drive`, bends (`~`), vibrato; twee gitaren = `twin=True`
- powerchord: één FM-stem met operatoren op 1, 1,5 en 2 (`POWER_CHORD`)
- pads/strijkers/Juno: twee ontstemde FM-dragers, trage aanzet (een akkoord = tweeklank)
- piano/klavecimbel/akoestische gitaar: `pluck`; koper: `brass_stab`/`brass`; klokjes: `bell`/`chime`
- "25% pulse"/chiptune-lead: PSG-blokgolf met driver-vibrato (`chip_lead`)
- drummachine/Linndrum/gated reverb: DAC-kick en -snare (`DRUMS`); hats en bekkens: PSG-ruis
- vocals: niet (instrumentaal); delay/echo: een tweede kanaal later en zachter
- tape stop, filter sweeps: `Song.tape_stop`, `low_pass_hz` van `render`

## Vaste contracten (niet breken)

- dezelfde bestandsnamen in `assets/audio/muziek/` (zie de tabel in `docs/MUZIEK.md`)
- loops naadloos (de tracks wrappen), een geheel aantal maten
- **alle stadsloops even lang, zelfde tempo, zelfde akkoord per maat** (de HUD vloeit over op dezelfde positie)
- deuntjes: 4 s, kaart 6 s, nieuwe missie 2,2 s, taak klaar 2,8 s
- de intro is 120 s; verschuiven de ankerpunten, pas dan `scripts/ui/intro.gd` aan
  (`CRAWL_AT`, `CRAWL_CUES`, `END_AT`)
- luidheid: elk bestand -16 LUFS, pieken onder -1,5 dB (doet `render` zelf)
- geen bestaande nummers namaken: alleen klank en genre als inspiratie

## Afronden

- `docs/MUZIEK.md` bijwerken (stijl, toonsoort, tempo's, motief, de tabel met stukken) en de
  muziekregels in `INSTRUCTIONS.md`
- rapporteer per nummer kort wat het is, de controleresultaten letterlijk, en wat de gebruiker moet beluisteren
- **niet committen**: de gebruiker commit zelf. Geen Godot nodig (en niet starten).
