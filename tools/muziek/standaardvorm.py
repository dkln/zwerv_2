"""The standard form of a composition in JSON (docs/MUZIEK_JSON.md, "De standaardvorm"): the one
structure every file in data/muziek/ has.

    metadata          title, bpm, timeSignature ("4/4"), stepsPerBar (16), totalBars, key, synth
    sections          [{name, startBar, endBar}]: together every bar, in order
    synthParameters   the voices
    master            (optional, synth "tracker") {volume}
    bars              [{barNumber, section, chord: {name, voicing...}, channels: {track: 16 cells}}]
    extra             (optional) what the composer wrote besides; kept, never read

`metadata.synth` says what plays the voices, and with it what a voice and a cell are:

    "tracker"   the rebuilt synth of the composer's tracker (tracker.py). The six voices of
                json_bron.VOICES with their `volume`, the six tracks of json_bron.TRACKS; a cell
                is a note, "---" or "=" (FM2_stabs 0 or 1, drums a drum name). This is the form
                json_bron.py has always read.
    "patches"   every voice its own sound: `ym2612Registers` (an FM patch, played by the chip
                imitation) or `sound` (a sound of instruments.SOUNDS), and `part` (the part of
                the score it is: bas, lead, ...). The tracks are the voices by name, and "drums"
                (the Mega Drive kit). A cell is "---" (nothing starts here), an event or a list
                of events: {"notes": [...], "steps": length, "velocity": 1..127}; in "drums"
                {"drum": "KCK", "velocity": 1..127}.

A file in another form (the flat form, the timeline, an export with patterns or events) is
brought to this one by naar_standaardvorm.py.
"""
import argparse
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import json_bron  # noqa: E402
import tijdlijn  # noqa: E402
import tracker  # noqa: E402

STEPS = 16
SYNTHS = ("tracker", "patches")
TOP_KEYS = ("metadata", "sections", "synthParameters", "master", "bars", "extra")
REQUIRED_TOP_KEYS = ("metadata", "sections", "synthParameters", "bars")
## The fields every file's metadata starts with, in this order.
METADATA_KEYS = ("title", "bpm", "timeSignature", "stepsPerBar", "totalBars", "key", "synth")
SECTION_KEYS = ("name", "startBar", "endBar")
BAR_KEYS = ("barNumber", "section", "chord", "channels")
DRUM_TRACK = "drums"
HOLD = "---"
## The registers of an operator of an FM patch (DT as the chip holds it: 0..3 up, 5..7 down).
OPERATOR_REGISTERS = ("DT", "MUL", "TL", "AR", "D1R", "D2R", "D1L", "RR")
## The drums of synth "patches": those of the tracker that the Mega Drive kit has, and its clap
## and crash.
PATCH_DRUMS = {"KCK": "kick", "SNR": "snare", "CLP": "clap", "CHH": "hihat", "OHH": "open", "CRS": "crash",
               "TOM1": "tom_hoog", "TOM2": "tom_mid", "TOM3": "tom_laag"}
DEFAULT_VELOCITY = 127
STRAIGHT_SWING = 50
NOTE_NAMES = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")


def note_name(midi_pitch: int) -> str:
    """The name of a MIDI pitch, with sharps: 60 "C4", 34 "A#1"."""
    return f"{NOTE_NAMES[midi_pitch % 12]}{midi_pitch // 12 - 1}"


def synth_of(data) -> str:
    metadata = data.get("metadata") if isinstance(data, dict) else None
    return metadata.get("synth", "") if isinstance(metadata, dict) else ""


def is_standard(data) -> bool:
    return not problems(data)


def events_of(cell) -> list:
    """The events of a cell of synth "patches": none ("---"), one or a list."""
    if cell == HOLD:
        return []
    return cell if isinstance(cell, list) else [cell]


# ----------------------------------------------------------------------------- checking

def _order_problem(found_keys: list, wanted_keys: tuple, where: str) -> list:
    """The known keys must come first and in their order."""
    known = [key for key in found_keys if key in wanted_keys]
    wanted = [key for key in wanted_keys if key in found_keys]
    if known != wanted or found_keys[:len(known)] != known:
        return [f"{where}: de velden staan niet in de vaste volgorde ({', '.join(wanted)}, dan de rest)"]
    return []


def _metadata_problems(metadata: dict, bar_count: int) -> list:
    found = []
    for key in METADATA_KEYS:
        if key not in metadata:
            found.append(f"'metadata.{key}' ontbreekt")
    found += _order_problem(list(metadata), METADATA_KEYS, "'metadata'")
    if not isinstance(metadata.get("bpm"), (int, float)) or metadata.get("bpm", 0) <= 0:
        found.append("'metadata.bpm' is geen getal boven 0")
    if metadata.get("timeSignature", "4/4") != "4/4":
        found.append(f"'metadata.timeSignature' is {metadata.get('timeSignature')!r}: alleen \"4/4\" wordt gelezen")
    if metadata.get("stepsPerBar", STEPS) != STEPS:
        found.append(f"'metadata.stepsPerBar' is {metadata.get('stepsPerBar')!r}: alleen {STEPS} wordt gelezen")
    if "totalBars" in metadata and metadata["totalBars"] != bar_count:
        found.append(f"'metadata.totalBars' is {metadata['totalBars']!r} maar 'bars' heeft {bar_count} maten")
    if "synth" in metadata and metadata["synth"] not in SYNTHS:
        found.append(f"'metadata.synth' is {metadata['synth']!r}: het is \"tracker\" of \"patches\"")
    swing = metadata.get("swingPercent", STRAIGHT_SWING)
    if not isinstance(swing, (int, float)) or not 50 <= swing <= 75:
        found.append(f"'metadata.swingPercent' is {swing!r}: een getal van 50 (recht) tot 75")
    elif swing != STRAIGHT_SWING and metadata.get("synth") == "tracker":
        found.append("'metadata.swingPercent': de synth \"tracker\" speelt geen swing (alleen \"patches\")")
    return found


def _section_problems(sections, bar_count: int) -> list:
    if not isinstance(sections, list) or not sections:
        return ["'sections' ontbreekt (de delen van het nummer met name, startBar en endBar)"]
    found = []
    expected_start = 1
    for index, section in enumerate(sections):
        where = f"sectie {index + 1}"
        if not isinstance(section, dict) or not isinstance(section.get("name"), str) \
                or not isinstance(section.get("startBar"), int) or not isinstance(section.get("endBar"), int):
            found.append(f"{where}: 'name', 'startBar' en 'endBar' horen erin")
            continue
        found += _order_problem(list(section), SECTION_KEYS, where)
        if section["startBar"] != expected_start or section["endBar"] < section["startBar"]:
            found.append(f"{where} ({section['name']}): loopt van maat {section['startBar']} tot {section['endBar']}, "
                         f"verwacht vanaf maat {expected_start} (de secties sluiten op elkaar aan)")
        expected_start = section["endBar"] + 1
    if not found and expected_start != bar_count + 1:
        found.append(f"de secties lopen tot maat {expected_start - 1} maar 'bars' heeft {bar_count} maten")
    return found


def _section_name_at(sections, bar_number: int):
    for section in sections if isinstance(sections, list) else []:
        if isinstance(section, dict) and isinstance(section.get("startBar"), int) and isinstance(section.get("endBar"), int) \
                and section["startBar"] <= bar_number <= section["endBar"]:
            return section.get("name")
    return None


def _voice_problems(name: str, voice) -> list:
    """A voice of synth "patches": its part and its sound (an FM patch or a named sound)."""
    import instruments
    where = f"'synthParameters.{name}'"
    if not isinstance(voice, dict):
        return [f"{where}: geen object"]
    found = []
    if not isinstance(voice.get("part"), str) or not re.match(r"^[a-z_]+$", voice.get("part", "")) or voice.get("part") == DRUM_TRACK:
        found.append(f"{where}: 'part' ontbreekt (de partij in kleine letters: bas, lead, arp, ...)")
    registers = voice.get("ym2612Registers")
    sound = voice.get("sound")
    if (registers is None) == (sound is None):
        found.append(f"{where}: precies één van 'ym2612Registers' (een FM-patch) en 'sound' (een klank bij naam) hoort erin")
    if sound is not None and (not isinstance(sound, str) or sound.startswith(("tracker", "patch:")) or sound not in instruments.SOUNDS):
        found.append(f"{where}: 'sound' {sound!r} is geen klank (bekend: {', '.join(sorted(dict.keys(instruments.SOUNDS)))})")
    if registers is not None:
        if not isinstance(registers, dict):
            return found + [f"{where}: 'ym2612Registers' is geen object"]
        for register in ("algorithm", "feedback"):
            if not isinstance(registers.get(register), int) or not 0 <= registers[register] <= 7:
                found.append(f"{where}: 'ym2612Registers.{register}' is geen getal van 0 tot 7")
        operators = registers.get("operators")
        if not isinstance(operators, dict) or len(operators) != 4:
            found.append(f"{where}: 'ym2612Registers.operators' heeft niet precies vier operators")
        else:
            for operator_name, operator in operators.items():
                missing = [register for register in OPERATOR_REGISTERS
                           if not isinstance(operator, dict) or not isinstance(operator.get(register), int)]
                if missing:
                    found.append(f"{where}: operator {operator_name} mist {', '.join(missing)}")
    return found


def _event_problem(event, is_drum: bool) -> str:
    """What is wrong with one event of a cell (Dutch), or ""."""
    if not isinstance(event, dict):
        return f"{event!r} is geen gebeurtenis ({{...}}) of '---'"
    velocity = event.get("velocity", DEFAULT_VELOCITY)
    if not isinstance(velocity, (int, float)) or not 1 <= velocity <= 127:
        return f"'velocity' {velocity!r} is geen getal van 1 tot 127"
    if is_drum:
        if ("drum" in event) == ("sample" in event):
            return "precies één van 'drum' en 'sample' hoort erin"
        if "drum" in event and event["drum"] not in PATCH_DRUMS:
            return f"onbekende drum {event['drum']!r} (bekend: {', '.join(PATCH_DRUMS)})"
        if "sample" in event and not isinstance(event["sample"], str):
            return "'sample' is geen naam"
        return ""
    notes = event.get("notes")
    if not isinstance(notes, list) or not notes or not all(isinstance(note, str) and json_bron.NOTE.match(note) for note in notes):
        return f"'notes' {notes!r} is geen lijst noten (zoals [\"E2\"] of [\"G3\", \"A#3\"])"
    steps = event.get("steps")
    if not isinstance(steps, (int, float)) or steps <= 0:
        return f"'steps' {steps!r} is geen lengte in stappen boven 0"
    return ""


def _patch_bar_problems(data: dict) -> list:
    found = []
    voices = data.get("synthParameters")
    voices = voices if isinstance(voices, dict) else {}
    tracks = [name for name in voices if name != DRUM_TRACK] + [DRUM_TRACK]
    for index, bar in enumerate(data["bars"]):
        where = f"maat {index + 1}"
        if not isinstance(bar, dict):
            found.append(f"{where}: geen object")
            continue
        if bar.get("barNumber") != index + 1:
            found.append(f"{where}: 'barNumber' is {bar.get('barNumber')!r}, de maten moeten op volgorde staan")
        chord = bar.get("chord")
        if not isinstance(chord, dict) or not isinstance(chord.get("name"), str):
            found.append(f"{where}: 'chord' hoort een object met 'name' te zijn (een leeg \"\" mag)")
        elif "voicing" in chord and not (isinstance(chord["voicing"], list)
                                         and all(isinstance(note, str) and json_bron.NOTE.match(note) for note in chord["voicing"])):
            found.append(f"{where}: 'chord.voicing' is geen lijst noten")
        channels = bar.get("channels")
        if not isinstance(channels, dict):
            found.append(f"{where}: 'channels' ontbreekt (de sporen)")
            continue
        if list(channels) != tracks:
            found.append(f"{where}: de sporen zijn {', '.join(channels)}; verwacht de stemmen van 'synthParameters' en "
                         f"'drums', in die volgorde: {', '.join(tracks)}")
            continue
        for track, row in channels.items():
            if not isinstance(row, list) or len(row) != STEPS:
                found.append(f"{where}: spoor '{track}' heeft niet precies {STEPS} vakjes")
                continue
            for step, cell in enumerate(row):
                for event in events_of(cell):
                    wrong = _event_problem(event, track == DRUM_TRACK)
                    if wrong:
                        found.append(f"{where}, '{track}' stap {step + 1}: {wrong}")
    return found


def problems(data) -> list:
    """Why the file is not in the standard form (Dutch, one line each); empty when it is."""
    if not isinstance(data, dict):
        return ["het bestand is geen JSON-object ({...})"]
    found = []
    for unknown in [key for key in data if key not in TOP_KEYS]:
        found.append(f"onbekend veld '{unknown}' (de standaardvorm heeft: {', '.join(TOP_KEYS)})")
    for key in REQUIRED_TOP_KEYS:
        if key not in data:
            found.append(f"'{key}' ontbreekt")
    if found:
        return found
    found += _order_problem(list(data), TOP_KEYS, "het bestand")
    bars = data["bars"]
    if not isinstance(bars, list) or not bars:
        return found + ["'bars' is geen lijst maten"]
    metadata = data["metadata"]
    if not isinstance(metadata, dict):
        return found + ["'metadata' is geen object"]
    found += _metadata_problems(metadata, len(bars))
    found += _section_problems(data["sections"], len(bars))
    for index, bar in enumerate(bars):
        if isinstance(bar, dict):
            found += _order_problem(list(bar), BAR_KEYS, f"maat {index + 1}")
            if list(bar) != list(BAR_KEYS):
                found.append(f"maat {index + 1}: heeft de velden {', '.join(bar)}; verwacht precies {', '.join(BAR_KEYS)}")
            wanted_section = _section_name_at(data["sections"], index + 1)
            if wanted_section is not None and bar.get("section") != wanted_section:
                found.append(f"maat {index + 1}: 'section' is {bar.get('section')!r} maar de maat ligt in sectie {wanted_section!r}")
    voices = data["synthParameters"]
    if not isinstance(voices, dict):
        return found + ["'synthParameters' is geen object"]
    synth = metadata.get("synth")
    if synth == "tracker":
        found += json_bron.problems(data)
        for voice in json_bron.VOICES:
            if not isinstance((voices.get(voice) or {}).get("volume"), (int, float)):
                found.append(f"'synthParameters.{voice}.volume' ontbreekt (0..1)")
        for unknown in [name for name in voices if name not in json_bron.VOICES]:
            found.append(f"'synthParameters.{unknown}': de synth \"tracker\" heeft alleen de stemmen {', '.join(json_bron.VOICES)}")
    elif synth == "patches":
        if "master" in data:
            found.append("'master' hoort bij de synth \"tracker\" (bij \"patches\" wordt het niet gelezen)")
        played = [name for name in voices if name != DRUM_TRACK]
        if not played:
            found.append("'synthParameters' heeft geen stemmen")
        for name in played:
            found += _voice_problems(name, voices[name])
        parts = [voices[name].get("part") for name in played if isinstance(voices[name], dict)]
        for part in sorted({part for part in parts if part and parts.count(part) > 1}):
            found.append(f"'synthParameters': de partij '{part}' staat bij meer dan één stem")
        found += _patch_bar_problems(data)
    return found


# ----------------------------------------------------------------------------- writing

def _fits_on_a_line(value) -> bool:
    """A value that is written on one line: a scalar, a list of scalars (a row of cells, a
    voicing), or an object of those that stays short (an event, an operator)."""
    if not isinstance(value, (dict, list)):
        return True
    if isinstance(value, list):
        return all(not isinstance(item, (dict, list)) for item in value)
    flat = all(not isinstance(item, dict) and (not isinstance(item, list) or _fits_on_a_line(item)) for item in value.values())
    return flat and len(json.dumps(value, ensure_ascii=False)) <= 110


def _lines(value, indent: int) -> str:
    if _fits_on_a_line(value):
        return json.dumps(value, ensure_ascii=False)
    pad = "  " * (indent + 1)
    if isinstance(value, dict):
        items = [f"{pad}{json.dumps(key, ensure_ascii=False)}: {_lines(item, indent + 1)}" for key, item in value.items()]
        return "{\n" + ",\n".join(items) + "\n" + "  " * indent + "}"
    items = [pad + _lines(item, indent + 1) for item in value]
    return "[\n" + ",\n".join(items) + "\n" + "  " * indent + "]"


def dumps(data: dict) -> str:
    """The file's text: two spaces per level, a row of cells, an event and an operator each on
    one line."""
    return _lines(data, 0) + "\n"


def _ordered(mapping: dict, first_keys: tuple) -> dict:
    ordered = {key: mapping[key] for key in first_keys if key in mapping}
    ordered.update({key: value for key, value in mapping.items() if key not in first_keys})
    return ordered


def normalised(data: dict) -> dict:
    """The same composition with every field in its fixed place (nothing added or left out)."""
    result = _ordered(data, TOP_KEYS)
    result["metadata"] = _ordered(data["metadata"], METADATA_KEYS)
    result["sections"] = [_ordered(section, SECTION_KEYS) for section in data["sections"]]
    result["bars"] = [_ordered(bar, BAR_KEYS) for bar in data["bars"]]
    return result


# ----------------------------------------------------------------------------- reading synth "patches"

def _register_voice(registers: dict):
    import fm
    operators = list(registers["operators"].values())
    return fm.FmVoice(
        algorithm=int(registers["algorithm"]), feedback=int(registers["feedback"]),
        multiples=tuple(int(operator["MUL"]) for operator in operators),
        total_levels=tuple(int(operator["TL"]) for operator in operators),
        attack_rates=tuple(int(operator["AR"]) for operator in operators),
        decay_rates=tuple(int(operator["D1R"]) for operator in operators),
        sustain_levels=tuple(int(operator["D1L"]) for operator in operators),
        detunes=tuple(int(operator["DT"]) for operator in operators),
        rate_scalings=tuple(int(operator.get("RS", 0)) for operator in operators),
        sustain_rates=tuple(int(operator["D2R"]) for operator in operators),
        release_rates=tuple(int(operator["RR"]) for operator in operators))


def patches(data: dict) -> dict:
    """The FM patches of a file of synth "patches": voice -> fm.FmVoice (tijdlijn.patches hands
    a standard file over to this)."""
    return {name: _register_voice(voice["ym2612Registers"]) for name, voice in data.get("synthParameters", {}).items()
            if isinstance(voice, dict) and isinstance(voice.get("ym2612Registers"), dict)
            and isinstance(voice["ym2612Registers"].get("operators"), dict)}


def step_position(step_index: int, swing_percent: float = STRAIGHT_SWING) -> float:
    """Where a step (0..15) starts, in beats from 1.0. With swing every second sixteenth comes
    later: at `swing_percent` of its eighth instead of halfway (50)."""
    eighth, second_sixteenth = divmod(step_index, 2)
    return round(1.0 + eighth * 0.5 + (0.5 * swing_percent / 100.0 if second_sixteenth else 0.0), 4)


def _velocity(event: dict) -> float:
    return round(max(0.05, min(1.0, float(event.get("velocity", DEFAULT_VELOCITY)) / 127.0)), 2)


def _chord_name(chord: dict) -> str:
    """The bar's chord in the notation's spelling: its name when that is one, else named by
    its voicing, else none."""
    readable = tracker._readable_chord(str(chord.get("name", "")))
    if readable:
        return readable
    return tracker.chord_from_notes(chord["voicing"]) if chord.get("voicing") else ""


def read(path: str) -> dict:
    """A file of synth "patches" as bars of parts and drums, the way tijdlijn.read gives a
    timeline: {"title", "tempo", "key", "loop", "sections", "voices": [(part, voice name, sound
    or None for its own patch)], "bars": [{"chord", "drums": [(position, drum, velocity)], part:
    [(position, pitches, length, velocity)]}], "warnings"}."""
    import notation
    with open(path, encoding="utf-8") as json_file:
        data = json.load(json_file)
    wrong = problems(data)
    if not wrong and synth_of(data) != "patches":
        wrong = ["'metadata.synth' is niet \"patches\" (een bestand voor de synth \"tracker\" leest json_bron.py)"]
    if wrong:
        raise ValueError(f"{path}: niet in de standaardvorm (docs/MUZIEK_JSON.md):\n  " + "\n  ".join(wrong[:40]))
    metadata = data["metadata"]
    swing = metadata.get("swingPercent", STRAIGHT_SWING)
    voices = [(voice["part"], name, voice.get("sound")) for name, voice in data["synthParameters"].items() if name != DRUM_TRACK]
    bars = []
    not_played = {}
    for bar in data["bars"]:
        out = {"chord": _chord_name(bar["chord"]), "drums": []}
        for part, name, _sound in voices:
            for step_index, cell in enumerate(bar["channels"][name]):
                for event in events_of(cell):
                    out.setdefault(part, []).append((step_position(step_index, swing),
                                                     tuple(notation.pitch(note) for note in event["notes"]),
                                                     round(float(event["steps"]) * 0.25, 4), _velocity(event)))
                    for effect in ("effect", "articulation"):
                        if event.get(effect):
                            counts = not_played.setdefault(f"{name}: de noot klinkt zonder zijn '{effect}'", {})
                            counts[str(event[effect])] = counts.get(str(event[effect]), 0) + 1
        for step_index, cell in enumerate(bar["channels"][DRUM_TRACK]):
            for event in events_of(cell):
                if "sample" in event:
                    counts = not_played.setdefault("drums: een 'sample' zonder klank klinkt niet", {})
                    counts[str(event["sample"])] = counts.get(str(event["sample"]), 0) + 1
                else:
                    out["drums"].append((step_position(step_index, swing), PATCH_DRUMS[event["drum"]], _velocity(event)))
        bars.append(out)
    sections = []
    for section in data["sections"]:
        previous = sections[-1]["soort"] if sections else ""
        sections.append({"naam": section["name"], "soort": tijdlijn._kind(section["name"], previous),
                         "maten": (section["startBar"], section["endBar"])})
    warnings = [f"niet nagespeeld: {label} (" + ", ".join(f"{what} {count}x" for what, count in sorted(counts.items())) + ")"
                for label, counts in sorted(not_played.items())]
    return {"title": str(metadata["title"]), "tempo": float(metadata["bpm"]), "key": str(metadata["key"]),
            "loop": (int(metadata.get("loopStartBar", 1)), int(metadata.get("loopEndBar", len(bars)))),
            "sections": sections, "voices": voices, "bars": bars, "warnings": warnings}


def note_counts(data: dict) -> dict:
    """Per track how many notes (chords count once) or drum hits start in the file: the same
    count for both synths, to compare a file with its source."""
    counts = {}
    is_patches = synth_of(data) == "patches"
    for bar in data["bars"]:
        for track, row in bar["channels"].items():
            if is_patches:
                started = sum(len([event for event in events_of(cell) if "sample" not in event]) for cell in row)
            elif track == DRUM_TRACK:
                started = sum(len(str(cell).split("+")) for cell in row if cell != HOLD)
            elif track == "FM2_stabs":
                started = sum(1 for cell in row if cell == 1)
            else:
                started = sum(1 for cell in row if cell != HOLD and cell not in json_bron.STOPS)
            counts[track] = counts.get(track, 0) + started
    return counts


def composition_source(source: dict, json_name: str) -> str:
    """The text of a composition file (score.py) of a file read by `read`: every note at its
    place with its length and velocity; an FM voice plays its own patch from the file
    ("patch:<json_name>:<voice>", instruments.json_patches)."""
    tonic, mode = tijdlijn._key(source["key"])
    out = [f'"""{source["title"]}: de partituur van {json_name} (de standaardvorm, synth "patches": elke noot',
           "op zijn stap met zijn lengte en velocity, tools/muziek/standaardvorm.py).", "",
           "De FM-stemmen spelen hun eigen patches uit het bestand (patch:...), de andere de klank die het bestand",
           "noemt, de drums het Mega Drive-drumstel.", ""]
    out += [f"LET OP: {warning}" for warning in source["warnings"]]
    out += ['"""', "from notation import Hit, Note", "",
            f"TITEL = {json.dumps(source['title'], ensure_ascii=False)}",
            f"TEMPO = {source['tempo']:g}", "TELLEN_PER_MAAT = 4",
            f'TOONSOORT = ("{tonic}", "{mode}")   # het bestand: {source["key"]}', "",
            "# de luspunten van het bestand (ter informatie)",
            f"LUSPUNTEN = {source['loop']!r}", "",
            "KLANKEN = {"]
    for part, name, sound in source["voices"]:
        out.append(f'    "{part}": {json.dumps(sound or f"patch:{json_name}:{name}", ensure_ascii=False)},   # {name}')
    out += ['    "drumstel": "standaard",', "}", "", "SECTIES = ["]
    for section in source["sections"]:
        out.append(f'    {{"naam": {json.dumps(section["naam"], ensure_ascii=False)}, "soort": "{section["soort"]}", '
                   f'"maten": {section["maten"]!r}}},')
    out += ["]", "", "MATEN = {"]
    for number, bar in enumerate(source["bars"], start=1):
        entries = [f'"akkoord": {json.dumps(bar["chord"], ensure_ascii=False)}'] if bar["chord"] else []
        for part, _name, _sound in source["voices"]:
            if bar.get(part):
                text = ", ".join(f"Note({at:g}, {tuple(pitches)!r}, {length:g}, {velocity:g})"
                                 for at, pitches, length, velocity in sorted(bar[part]))
                entries.append(f'"{part}": [{text}]')
        hits = ", ".join(f'Hit({at:g}, "{drum}", {velocity:g})' for at, drum, velocity in sorted(bar["drums"]))
        entries.append(f'"drums": [{hits}]')
        out.append(f"    {number}: {{" + ",\n        ".join(entries) + "},")
    out.append("}")
    return "\n".join(out) + "\n"


def report(source: dict) -> str:
    seconds = len(source["bars"]) * 4 * 60.0 / source["tempo"]
    counts = {}
    for bar in source["bars"]:
        for part, started in bar.items():
            if isinstance(started, list):
                counts[part] = counts.get(part, 0) + len(started)
    return "\n".join([
        f"standaardvorm (patches): {source['title']}",
        f"tempo {source['tempo']:g} BPM, {len(source['bars'])} maten = {seconds:.1f} s; toonsoort {source['key']}",
        "stemmen: " + ", ".join(f"{part} ({name}: {sound or 'eigen FM-patch'})" for part, name, sound in source["voices"]),
        "secties: " + ", ".join(f"{section['naam']} ({section['soort']}) maat {section['maten'][0]}-{section['maten'][1]}"
                                for section in source["sections"]),
        "noten: " + ", ".join(f"{part} {count}" for part, count in sorted(counts.items()))])


def main(arguments: list = None) -> int:
    """A file of synth "patches" to composities/<naam>.py (json_bron.py hands it over, the way it
    does a timeline)."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("json")
    parser.add_argument("naam", nargs="?")
    parser.add_argument("--toon", action="store_true")
    parser.add_argument("--overschrijf", action="store_true")
    options = parser.parse_args(arguments)
    try:
        source = read(options.json)
    except (ValueError, OSError) as error:
        print(error)
        return 1
    name = options.naam or tracker.default_name(options.json)
    print(report(source))
    for warning in source["warnings"]:
        print("LET OP: " + warning)
    if options.toon:
        return 0
    target = os.path.join(tijdlijn.COMPOSITIONS_FOLDER, name + ".py")
    if os.path.exists(target) and not options.overschrijf:
        print(f"{target} bestaat al: geef --overschrijf om het te vervangen")
        return 1
    kept = os.path.join(tijdlijn.COMPOSITIONS_FOLDER, name + ".json")
    if os.path.abspath(kept) != os.path.abspath(options.json):
        shutil.copyfile(options.json, kept)
        print(f"bron bewaard: {kept}")
    with open(target, "w", encoding="utf-8") as composition_file:
        composition_file.write(composition_source(source, name + ".json"))
    print(f"geschreven: {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
