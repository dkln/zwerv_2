# Een compositie aanleveren als JSON

De muziek van ZWERVR wordt gemaakt uit één compositie (zie `docs/MUZIEK.md` en de skill
`muziek-compositie`). De beste manier om een nieuw nummer aan te leveren is JSON: de partituur als
gegevens, met een WAV erbij van hoe het moet klinken. Het formaat is dat van de export van de
tracker van de componist (Gemini); `tools/muziek/composities/nitro_overdrive_92.json` is het
voorbeeld. Een VGM of een tracker-pagina kan ook, maar daar gaat makkelijk iets in verloren
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

## Wat een tracker-pagina nog meer exporteert

De pagina van de componist laat drie verschillende dingen horen: zijn eigen synth (bij afspelen;
die bouwen wij na), een WAV-export met een versimpelde synth, en een VGM-export. Bij
`nitro_overdrive_92` miste het VGM vier van de zes stemmen en waren de toonhoogtes fout omgerekend.
Lever daarom het JSON aan; de WAV dient alleen als meetlat.
