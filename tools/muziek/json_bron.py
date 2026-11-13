"""A composition in JSON as the source of the music (docs/MUZIEK_JSON.md): the form the
composer (Gemini) exports from its tracker: `metadata` (title, bpm, key), `sections`,
`synthParameters` (per voice its volume) and `bars` (per bar its chord with its voicings and
six tracks of sixteen steps: bass, chord stabs, lead, harmony, arpeggio, drums).

    tools/muziek/render.sh --json <bestand.json> [naam]              write composities/<naam>.py
    tools/muziek/render.sh --json <bestand.json> [naam] --toon       only show what the file holds
    tools/muziek/render.sh --json <bestand.json> [naam] --meet [wav] measure the render (and against a WAV)
    ... --overschrijf       replace an existing composities/<naam>.py

The file is read into the same score a tracker page gives (tracker.Tracker), so everything
after it is shared: the composition file with every row as written (tracker.composition_source),
the intro played by the rebuilt synth of the tracker (tracker.render: what the composer's page
sounds like), the derived pieces in those voices. A file that is not complete is refused, with
what is wrong and where (problems): a voice that is not in the JSON does not exist for us.
"""
import argparse
import json
import os
import re
import shutil
import sys

import tracker

HERE = os.path.dirname(os.path.abspath(__file__))
STEPS = 16
## The tracks of a bar ("channels") and the row of the tracker's score each one is.
TRACKS = {"FM1_bass": "bass", "FM2_stabs": "stabTrig", "FM3_lead": "lead", "FM4_harmony": "harm", "PSG_arp": "arp",
          "drums": "drums"}
## The voices of `synthParameters` in the order of the tracker's channels (their volumes).
VOICES = ("FM1_SlapBass", "FM2_PolyBrass", "FM3_OverdriveLead", "FM4_HarmonyLead", "PSG_SquareArp", "PCM_FM_Drums")
HOLD = "---"
STOPS = ("===", "=")
NOTE = re.compile(r"^[A-G][#b]?-?\d$")


def problems(data) -> list:
    """What is wrong with the file (Dutch, one line each); empty when it can be used."""
    if not isinstance(data, dict):
        return ["het bestand is geen JSON-object ({...})"]
    found = []
    metadata = data.get("metadata")
    if not isinstance(metadata, dict):
        found.append("'metadata' ontbreekt (titel, bpm, toonsoort)")
        metadata = {}
    if not isinstance(metadata.get("bpm"), (int, float)) or metadata.get("bpm", 0) <= 0:
        found.append("'metadata.bpm' ontbreekt of is geen getal boven 0")
    if int(metadata.get("stepsPerBar", STEPS)) != STEPS:
        found.append(f"'metadata.stepsPerBar' is {metadata.get('stepsPerBar')}: alleen {STEPS} stappen per maat (zestienden) wordt gelezen")
    sections = data.get("sections")
    if not isinstance(sections, list) or not sections:
        found.append("'sections' ontbreekt (de delen van het nummer met startBar en endBar)")
    else:
        for index, section in enumerate(sections):
            if not isinstance(section, dict) or not isinstance(section.get("startBar"), int) or not isinstance(section.get("endBar"), int):
                found.append(f"sectie {index + 1}: 'startBar' en 'endBar' ontbreken")
    bars = data.get("bars")
    if not isinstance(bars, list) or not bars:
        found.append("'bars' ontbreekt (de maten)")
        return found
    for index, bar in enumerate(bars):
        number = bar.get("barNumber", index + 1) if isinstance(bar, dict) else index + 1
        where = f"maat {number}"
        if not isinstance(bar, dict):
            found.append(f"{where}: geen object")
            continue
        if bar.get("barNumber") != index + 1:
            found.append(f"{where}: 'barNumber' is {bar.get('barNumber')}, de maten moeten op volgorde staan (verwacht {index + 1})")
        channels = bar.get("channels")
        if not isinstance(channels, dict):
            found.append(f"{where}: 'channels' ontbreekt (de sporen)")
            continue
        for unknown in sorted(set(channels) - set(TRACKS)):
            found.append(f"{where}: onbekend spoor '{unknown}' (bekend: {', '.join(TRACKS)})")
        for name in TRACKS:
            row = channels.get(name)
            if not isinstance(row, list):
                found.append(f"{where}: spoor '{name}' ontbreekt")
                continue
            if len(row) != STEPS:
                found.append(f"{where}: spoor '{name}' heeft {len(row)} vakjes in plaats van {STEPS}")
                continue
            for step, cell in enumerate(row):
                if name == "FM2_stabs":
                    if cell not in (0, 1):
                        found.append(f"{where}, '{name}' stap {step + 1}: {cell!r} is geen 0 of 1")
                elif name == "drums":
                    if cell != HOLD and cell not in tracker.DRUM_NAMES:
                        found.append(f"{where}, '{name}' stap {step + 1}: onbekende drum {cell!r} (bekend: {', '.join(tracker.DRUM_NAMES)})")
                elif cell != HOLD and cell not in STOPS and not (isinstance(cell, str) and NOTE.match(cell)):
                    found.append(f"{where}, '{name}' stap {step + 1}: {cell!r} is geen noot (zoals 'E2' of 'C#5'), '---' of '='")
        if isinstance(channels.get("FM2_stabs"), list) and any(cell == 1 for cell in channels["FM2_stabs"]):
            chord = bar.get("chord")
            if not isinstance(chord, dict) or not _voicings(chord):
                found.append(f"{where}: er worden akkoorden aangeslagen maar 'chord' heeft geen noten (voicingSteps_1_to_8, voicingBeat1, ...)")
    return found


def _voicings(chord: dict) -> list:
    """[(first step, last step, notes)] of a bar's chord: "voicingSteps_1_to_8", "voicingBeat2"
    (a beat is four steps), or "voicing" / "notes" for the whole bar."""
    spans = []
    for key, notes in chord.items():
        if not isinstance(notes, list):
            continue
        steps = re.match(r"^voicingSteps_(\d+)_to_(\d+)$", key)
        beat = re.match(r"^voicingBeat(\d+)$", key)
        if steps:
            spans.append((int(steps.group(1)) - 1, int(steps.group(2)) - 1, notes))
        elif beat:
            spans.append(((int(beat.group(1)) - 1) * 4, int(beat.group(1)) * 4 - 1, notes))
        elif key in ("voicing", "notes"):
            spans.append((0, STEPS - 1, notes))
    return sorted(spans)


def _holds(row: list) -> list:
    """Per step how many steps the note that starts there sounds (0: no note starts there)."""
    holds = []
    for step, cell in enumerate(row):
        if cell == HOLD or cell in STOPS:
            holds.append(0)
            continue
        held = 1
        for later in row[step + 1:]:
            if later != HOLD:
                break
            held += 1
        holds.append(held)
    return holds


def read(path: str) -> tracker.Tracker:
    """The composition of the file as the score of a tracker (tracker.Tracker)."""
    with open(path, encoding="utf-8") as json_file:
        try:
            data = json.load(json_file)
        except json.JSONDecodeError as error:
            raise ValueError(f"{path}: geen geldig JSON ({error})") from error
    wrong = problems(data)
    if wrong:
        raise ValueError(f"{path}: de compositie kan zo niet gebruikt worden:\n  " + "\n  ".join(wrong[:40]))
    metadata = data["metadata"]
    bars = []
    for bar in data["bars"]:
        channels = bar["channels"]
        rows = {}
        for name, row_name in TRACKS.items():
            rows[row_name] = ["===" if cell in STOPS else cell for cell in channels[name]]
        chord = bar.get("chord") or {}
        chords = [[] for _step in range(STEPS)]
        for first, last, notes in _voicings(chord):
            for step in range(max(0, first), min(STEPS - 1, last) + 1):
                chords[step] = list(notes)
        section_name = str(bar.get("section", ""))
        bars.append({"barNum": bar["barNumber"], "section": section_name, "chordName": str(chord.get("name", "")),
                     "stabTrig": rows["stabTrig"], "bass": rows["bass"], "lead": rows["lead"], "harm": rows["harm"],
                     "arp": rows["arp"], "drums": rows["drums"], "chords": chords,
                     "holds": {"bass": _holds(rows["bass"]), "lead": _holds(rows["lead"]), "harm": _holds(rows["harm"])}})
    # a section's name on every bar of it (the tracker's own bars carry it; here from `sections`)
    for section in data.get("sections", []):
        for bar in bars:
            if section["startBar"] <= bar["barNum"] <= section["endBar"] and not bar["section"]:
                bar["section"] = str(section.get("name", section.get("id", "")))
    synth = data.get("synthParameters") or {}
    volumes = tuple(float((synth.get(voice) or {}).get("volume", tracker.DEFAULT_VOLUMES[index]))
                    for index, voice in enumerate(VOICES))
    master = data.get("master") or {}
    source = tracker.Tracker(path, str(metadata.get("title", "")), str(metadata.get("key", "")).upper(),
                             float(metadata["bpm"]), float(master.get("volume", tracker.DEFAULT_MASTER_VOLUME)), volumes,
                             bars, {}, "")
    for voice in VOICES:
        if voice not in synth:
            source.warnings.append(f"'synthParameters.{voice}' ontbreekt: het volume van de tracker zelf genomen")
    return source


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("json", help="the composition in JSON")
    parser.add_argument("naam", nargs="?", help="the name of the composition (default: the file name)")
    parser.add_argument("--toon", action="store_true")
    parser.add_argument("--meet", nargs="?", const="", default=None, metavar="WAV",
                        help="measure the render; with a WAV of the piece also against that")
    parser.add_argument("--overschrijf", action="store_true")
    parser.add_argument("--titel")
    arguments = parser.parse_args()
    try:
        source = read(arguments.json)
    except (ValueError, OSError) as error:
        print(error)
        return 1
    name = arguments.naam or tracker.default_name(arguments.json)
    print(tracker.report(source))
    for warning in source.warnings:
        print("LET OP: " + warning)
    if arguments.toon:
        return 0
    if arguments.meet is not None:
        intro_path = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "audio", "muziek", "zwervr_intro.ogg")
        for line in tracker.measure(source, arguments.meet or None, intro_path):
            print("VERSCHIL: " + line)
        return 0
    target = os.path.join(tracker.COMPOSITIONS_FOLDER, name + ".py")
    if os.path.exists(target) and not arguments.overschrijf:
        print(f"{target} bestaat al (handwerk erin gaat verloren): geef --overschrijf om het te vervangen")
        return 1
    kept = os.path.join(tracker.COMPOSITIONS_FOLDER, name + ".json")
    if os.path.abspath(kept) != os.path.abspath(arguments.json):
        shutil.copyfile(arguments.json, kept)
        print(f"bron bewaard: {kept}")
        source.path = kept
    with open(target, "w", encoding="utf-8") as composition_file:
        composition_file.write(tracker.composition_source(source, name, arguments.titel or tracker.default_title(source)))
    print(f"geschreven: {target}")
    return 0


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    sys.exit(main())
