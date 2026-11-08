# Muziekgenerator

Alle muziek wordt met Python gesynthetiseerd (numpy/scipy, geen samples) en als Ogg Vorbis
geschreven naar `assets/audio/muziek/`.

```sh
tools/music/render.sh                 # alles renderen
tools/music/render.sh --list          # overzicht van alle bestanden
tools/music/render.sh --only gevecht  # alleen bestanden met 'gevecht' in de naam
tools/music/render.sh --only intro --bars 33-48   # snelle preview van maat 33-48 (*_preview.ogg)
```

De eerste keer maakt `render.sh` een eigen Python-omgeving in `tools/music/.venv` (numpy,
scipy, soundfile). Die map staat in `.gitignore`.

## Bestanden

| Bestand | Wat | Lengte |
|---|---|---|
| `approach_vector_intro.ogg` | hele track met de aanzwellende intro; het einde loopt door in de menu-loop | 1:35 |
| `approach_vector_menu_loop.ogg` | menu-loop: drop, breakdown, drop B, riser, climax | 1:48, loop |
| `gevecht_loop.ogg` | RPG-gevechtsscherm, 168 BPM | 0:46, loop |
| `handelaar_loop.ogg` | bij een merchant, 130 BPM, alleen synths | 0:59, loop |
| `deuntje_gewonnen.ogg` | gewonnen | 4 s |
| `deuntje_verloren.ogg` | verloren | 4 s |
| `deuntje_dood.ogg` | dood | 4 s |
| `deuntje_level_omhoog.ogg` | genoeg XP voor een level | 4 s |

De loops zijn naadloos over het hele bestand: zet in Godot bij de import **Loop** aan
(loop offset 0). Galm en echo's van het einde lopen al door in het begin.

## Eén stijl

Alle stukken bouwen op `style.py`, de "huisstijl": dezelfde sporen met vaste klanken en mix,
hetzelfde drumstel en dezelfde bouwstenen. Daardoor klinkt alles als dezelfde game:

- toonsoort F mineur. Alles staat in E mineur genoteerd (makkelijke nootnamen) en klinkt een halve
  toon hoger (`theory.KEY_TRANSPOSE`)
- het hart van de akkoorden volgt `voorbeeld.mp3`: i – bII – iv (Em–F–Am, klinkt als Fm–Gb–Bbm),
  met G en Bm als kleur. Energiek maar niet corny blij
- het motief: vier korte, harde noten in twee tellen (grondtoon, terts, secunde, kwint omlaag), dat
  zich aan elk akkoord aanpast (`motif_for`, `motif_calls`); `theme_from_chords()` maakt er een
  melodie van die het motief in elke maat speelt
- effecten bij overgangen: `build_into` (master-filter dicht + omgekeerd bekken), `drop_hit`
  (impact), `tape_stop_into`, `stutter_into`
- supersaw-pad met chorus, polysynth-brass, DX7-achtige e-piano, pluck-arpeggio's in zestienden
- pompende octaafbas, drumcomputer (kick, gated snare + handclap, hi-hats, open hi-hats)
- de 8-bit square-lead als herkenningsstem van het motief, darksynth-gitaren voor actie

Klinkt een klank of spoor overal te hard of te zacht, pas het dan aan in `StyleTracks`; een
stuk kan per spoor afwijken met `StyleTracks(song, levels={"synth_lead": 0.65})`.

## Drums

Nu speelt de Roland TR-707 (public domain samples in `tools/music/drums/`, zie de LEESMIJ daar). Zonder samples speelt de klassieke synth-kit (909-kick, warme snare zonder filter, 808-clap en -hi-hats; de 909-snare is `inst.classic_snare`, de gated snare `inst.gated_snare`). Liever echte
drums? Zet one-shots in `tools/music/drums/` met de namen `kick`, `snare`, `clap`, `hat`,
`open_hat` en `tom` (.wav, .ogg, .flac of .aif) en render opnieuw: die samples worden dan overal
gebruikt, en wat ontbreekt wordt aangevuld met de synth-kit. De andere synth-kits (`HARD_KIT`,
`WARM_KIT`) kies je met `KIT` in `style.py`.

## Vergelijken met een voorbeeld

```sh
tools/music/analyze.sh voorbeeld.mp3 assets/audio/muziek/approach_vector_intro.ogg
```

Geeft per bestand tempo, toonsoort, akkoorden per maat, klankbalans per frequentieband,
helderheid, stereobreedte, dynamiek en een drumgrid. Zo kun je zien waar onze muziek afwijkt.

## Opbouw

- `synth.py`: oscillatoren, envelopes, filters, effecten (galm, sidechain, ping-pong delay), mix en export.
- `instruments.py`: alle klanken (chiptune, pads, bas, vervormde gitaar, leads, drums). Nieuw geluid = nieuwe functie hier.
- `theory.py`: nootnamen (`"F#5"`), akkoorden (`CHORDS`) en harmonie (terts erboven).
- `patterns.py`: noten op het grid zetten: `play_melody` (lijst van `(noot, tellen)`, `"r"` = rust),
  `play_repeated` (arpeggio's, baspulsen) en `play_steps` (step-sequencer: `"X... x... "`).
- `style.py`: de huisstijl (zie hierboven), gebruik dit voor elk nieuw stuk.
- `analyze.py`: de analysetool hierboven.
- `songs/*.py`: één bestand per nummer. Elk bestand heeft een lijst `RENDERS` met
  `file`, `bpm`, `bars` (of `seconds`), `compose(song, first_bar)` en eventueel `loop: True`.

Een nieuw nummer maken: kopieer bijvoorbeeld `songs/merchant.py`, pas de akkoorden en melodieën
aan en geef het een eigen bestandsnaam in `RENDERS`. Het wordt dan vanzelf mee gerenderd.

Het volume van een spoor zet je bij het aanmaken van de tracks (`volume`, `pan`, `reverb_send`,
`sidechain`). Bij het renderen staat per spoor de piek en de RMS, zodat je ziet welk spoor overheerst.
