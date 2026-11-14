# Een compositie aanleveren als JSON

De muziek van ZWERVR wordt gemaakt uit de basissoundtracks: een primaire (de intro), een secundaire
(het menu) en eventueel een tertiaire (de vechtscène); zie `docs/MUZIEK.md` en de skill
`muziek-compositie`. De beste manier om een nieuw nummer aan te leveren is JSON: de partituur als
gegevens, met een WAV erbij van hoe het moet klinken. Het formaat is dat van de export van de
tracker van de componist (Gemini); `tools/muziek/composities/nitro_overdrive_92.json` is het
voorbeeld. Een tracker-pagina kan ook, maar daar gaat makkelijk iets in verloren
(stemmen die niet worden weggeschreven, verkeerd omgerekende toonhoogtes).

Inlezen: `tools/muziek/render.sh --json <bestand.json> [naam]` (`--toon` laat alleen zien wat erin
zit, `--overschrijf` vervangt een bestaande compositie, `--meet [wav]` meet de weergave). Het
bestand wordt naast de compositie bewaard als `tools/muziek/composities/<naam>.json`.

## De prompt voor de componist

> Exporteer de compositie als één JSON-bestand in het formaat hieronder, en als WAV van het
> resultaat. Het JSON moet alles bevatten wat je zelf afspeelt: elke stem, elke noot, elke
> drumslag en de akkoorden met hun noten. Laat niets weg en reken geen toonhoogtes om: schrijf
> noten als naam met octaaf (`"E2"`, `"C#5"`). Elk spoor heeft precies 16 vakjes per maat.

## Het formaat

```json
{
  "metadata": {"title": "Nitro Overdrive '92", "bpm": 132, "timeSignature": "4/4", "stepsPerBar": 16,
               "totalBars": 32, "key": "E Mixolydian"},
  "sections": [
    {"id": "01_INTRO", "name": "01: INTRO — IGNITION", "startBar": 1, "endBar": 4},
    {"id": "02_VERSE_A", "name": "02: VERSE A — NIGHT HIGHWAY", "startBar": 5, "endBar": 12}
  ],
  "synthParameters": {
    "FM1_SlapBass": {"volume": 0.9},
    "FM2_PolyBrass": {"volume": 0.78},
    "FM3_OverdriveLead": {"volume": 0.88},
    "FM4_HarmonyLead": {"volume": 0.72},
    "PSG_SquareArp": {"volume": 0.65},
    "PCM_FM_Drums": {"volume": 0.92}
  },
  "master": {"volume": 0.85},
  "bars": [
    {
      "barNumber": 1,
      "section": "01: INTRO — IGNITION",
      "chord": {"name": "E5 / E7sus4",
                "voicingSteps_1_to_8": ["E3", "B3", "D4", "E4"],
                "voicingSteps_9_to_16": ["E3", "B3", "D4", "E4"]},
      "channels": {
        "FM1_bass":    ["E1", "E1", "E2", "E1", "---", "E1", "E2", "D2", "E1", "E1", "G1", "G#1", "A1", "B1", "D2", "B1"],
        "FM2_stabs":   [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0],
        "FM3_lead":    ["E4", "---", "G4", "G#4", "=", "---", "B4", "---", "---", "A4", "---", "G#4", "---", "---", "E4", "---"],
        "FM4_harmony": ["---", "---", "---", "---", "---", "---", "---", "---", "---", "---", "---", "---", "---", "---", "---", "---"],
        "PSG_arp":     ["E4", "B4", "D5", "E5", "B4", "D5", "E4", "B4", "D5", "E5", "B4", "D5", "E4", "B4", "D5", "B4"],
        "drums":       ["KCK", "CHH", "OHH", "KCK", "SNR", "CHH", "OHH", "KCK", "CHH", "KCK", "OHH", "CHH", "SNR", "CHH", "KCK", "SNR"]
      }
    }
  ]
}
```

## De velden

| veld | wat |
|---|---|
| `metadata` | `title`, `bpm` (verplicht), `stepsPerBar` (16: zestienden; iets anders wordt niet gelezen), `key` (bv. `"E Mixolydian"`, `"D minor"`) |
| `sections` | de delen van het nummer met `startBar` en `endBar` (verplicht) en een `name` of `id`; aan de naam wordt de soort afgelezen: INTRO, VERSE/THEME (thema), PRE/BUILD/BRIDGE (opbouw), CHORUS (refrein), BREAK (breakdown), FINAL/OUTRO/CLIMAX (finale). De afgeleide stukken zoeken op die soorten |
| `synthParameters` | per stem (`FM1_SlapBass`, `FM2_PolyBrass`, `FM3_OverdriveLead`, `FM4_HarmonyLead`, `PSG_SquareArp`, `PCM_FM_Drums`) zijn `volume` (0..1); ontbreekt een stem, dan geldt het volume van de tracker zelf. Wat de componist er verder bij zet (`ym2612Registers`, `webAudioModel`) wordt bewaard maar niet gelezen: de klank is de nagebouwde synth van de tracker (`tools/muziek/tracker.py`) |
| `master` | optioneel: `volume` (anders 0,85) |
| `bars` | de maten, op volgorde, `barNumber` vanaf 1 |
| `bars[].chord` | `name` en de noten van het akkoord: `voicingSteps_1_to_8` en `voicingSteps_9_to_16` (een wissel halverwege), `voicingBeat1` .. `voicingBeat4` (een akkoord per tel), of `voicing` voor de hele maat. Verplicht als de maat akkoorden aanslaat |
| `bars[].channels` | de zes sporen, elk precies 16 vakjes: `FM1_bass`, `FM2_stabs`, `FM3_lead`, `FM4_harmony`, `PSG_arp`, `drums` |

Een vakje in een spoor is een noot (`"E2"`, `"C#5"`), `"---"` (de vorige noot klinkt door, of rust als
er geen was) of `"="` / `"==="` (de noot stopt hier). In `FM2_stabs` is het `1` (het akkoord van dat
moment wordt aangeslagen) of `0`. In `drums` is het een drum: `KCK` (kick), `SNR` (snare), `CHH`
(dichte hi-hat), `OHH` (open hi-hat), `TOM1` .. `TOM4` (hoog naar laag), of `"---"`.

Een bestand dat niet compleet is wordt geweigerd, met per regel wat er mis is en in welke maat.
Alles wat de componist zelf afspeelt hoort erin: een stem die niet in het JSON staat, bestaat voor
ons niet.

## De platte vorm

Een andere export van de tracker zet alles plat (`street_viper_92.json` is het voorbeeld). Die
wordt ook gelezen: `json_bron.from_flat` maakt er de vorm hierboven van, en daarna gaat alles
hetzelfde.

```json
{
  "title": "Street Viper '92", "bpm": 128, "timeSignature": "4/4", "stepsPerBar": 16, "key": "E Mixolydian",
  "bars": [
    {"bar": 1, "section": "A - Intro: Igniter", "chord": "E5",
     "lead":  [null, "---", "E5", ...],
     "brass": [["E4", "B4"], "---", null, ...],
     "arp":   ["E5", null, "B4", ...],
     "bass":  ["E2", null, "E2", "E3", ...],
     "drums": ["K+H", "H", "S+O", null, ...]}
  ]
}
```

| veld | wat het wordt |
|---|---|
| `title`, `bpm`, `key`, `stepsPerBar` bovenaan | `metadata` |
| `bars[].bar` | `barNumber` |
| `bars[].section` | de secties: elke reeks maten met dezelfde naam is een sectie (de soort uit de naam, zie hierboven; ook MAIN of GROOVE = thema) |
| `bars[].chord` (een naam) | `chord.name` |
| `bass`, `lead`, `arp` | `FM1_bass`, `FM3_lead`, `PSG_arp` |
| `brass`: per stap een lijst noten (een aanslag) of `"---"` / `null` | `FM2_stabs` (1 bij een lijst) en vanaf elke aanslag zijn noten als het akkoord (`voicingSteps_<van>_to_<tot>`) |
| (geen harmoniespoor) | `FM4_harmony` leeg |
| `drums`: letters, samen met `+` | `K` kick, `S` snare, `H` dichte hi-hat, `O` open hi-hat, `T` een tom (geen toonhoogte genoemd: de middelste, `TOM2`); `"K+H"` wordt `"KCK+CHH"`: meer drums op dezelfde stap |

Een vakje `null` is stilte: direct na een noot stopt die daar (`"==="`), anders is het een rust
(`"---"`). `"---"` houdt de noot aan. Ontbreekt `synthParameters`, dan gelden de volumes van de
tracker zelf (het wordt gemeld).

## Wat een tracker-pagina nog meer exporteert

De pagina van de componist laat drie verschillende dingen horen: zijn eigen synth (bij afspelen;
die bouwen wij na), een WAV-export met een versimpelde synth, en een VGM-export. Bij
`nitro_overdrive_92` miste het VGM vier van de zes stemmen en waren de toonhoogtes fout omgerekend.
Lever daarom het JSON aan; de WAV dient alleen als meetlat.

## De tijdlijn

Een volledige export met de klanken erbij (`neon_knuckle.json` is het voorbeeld) wordt gelezen door
`tools/muziek/tijdlijn.py` (`render.sh --json` geeft hem door): `metadata` (`bpm`, `steps_per_bar` 16,
`loop_points`), `hardware_patches` (per YM2612-kanaal `algorithm`, `feedback` en vier `operators` met
`MUL`, `DET` (-3..3), `TL`, `AR`, `D1R`, `D2R`, `D1L`, `RR`), `arrangement_structure` (de secties),
`full_track_timeline_<n>_bars` (per maat per stap elk kanaal) en `flat_sequencer_events` (de noten van
FM1-FM3 met hun lengte en velocity, en de velocity van elke drumslag).

Het wordt een gewoon compositiebestand, elke noot letterlijk: de FM-kanalen spelen hun eigen patch
uit het bestand (`patch:<bestand>:<kanaal>`, door de chipnabootsing, op hun eigen niveau), de PSG-kanalen
de PSG-klanken, de DAC-samples en ruis-hats het Mega Drive-drumstel (`KICK_SNARE_CLAP` drie slagen
tegelijk). Wat het bestand niet zegt: de pad (FM4) houdt aan tot zijn volgende akkoord, de echo (PSG2)
tot zijn volgende noot ("sustain"). Niet nagespeeld en gemeld: samples zonder klank (een stem), en
effecten (vibrato, slides).

## Eén compositie beluisteren

Een JSON-bestand horen zonder iets aan het spel te veranderen: `tools/muziek/json_naar_ogg.sh`
(Windows: `json_naar_ogg.ps1`) maakt er één OGG van, op de plek die je opgeeft.

```sh
tools/muziek/json_naar_ogg.sh <compositie.json> <uitvoer.ogg>
tools/muziek/json_naar_ogg.sh data/muziek/street_viper_92.json ~/Desktop/street_viper_92.ogg
```

De compositie klinkt letterlijk zoals geschreven, één keer gespeeld met 2,5 s uitklinken, door
dezelfde synth en mastering als de intro van het spel (de gewone en de platte vorm door de
nagebouwde synth van de tracker, de tijdlijn in haar eigen patches; -16 LUFS). Er wordt niets
afgeleid en niets van het spel geraakt: geen `composities/<naam>.py`, niet `composities/actief.py`,
niets in `assets/audio/muziek/` (uitvoer daarheen wordt geweigerd). Wat het bestand vraagt maar niet
nagespeeld wordt, staat als `LET OP:` in de uitvoer; een bestand in een andere vorm dan de drie
hierboven wordt geweigerd met de velden die het wel heeft. De uitvoer noemt het bestand en de duur
in seconden.
