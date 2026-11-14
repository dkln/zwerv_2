"""A composition in JSON as a full timeline (docs/MUZIEK_JSON.md, "De tijdlijn"): the composer's
export with `metadata` (bpm, total_bars, loop_points), `hardware_patches` (the YM2612 FM patches of
its channels: algorithm, feedback, operators), `chord_dictionary`, `arrangement_structure` (the
sections), `full_track_timeline_<n>_bars` (per bar per step every channel) and
`flat_sequencer_events` (the notes of the melodic channels with their lengths).

    tools/muziek/render.sh --json <bestand.json> [naam]            (json_bron.py hands it over)
    ... --toon            only show what the file holds
    ... --overschrijf     replace an existing composities/<naam>.py

Written as an ordinary composition file (score.py), every note at its step with its length and
velocity, no tracker synth: the FM channels play their own patches from the file
("patch:<file>:<channel>", instruments.json_patches, played by chip.py), the PSG channels the
PSG sounds, the drums (DAC samples and noise hats) the Mega Drive kit. What cannot be played is
reported: a voice sample (VOX_GO), effects (vibrato, slides).
"""
import argparse
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import notation  # noqa: E402
import tracker  # noqa: E402
import fm  # noqa: E402

COMPOSITIONS_FOLDER = os.path.join(HERE, "composities")
STEPS = 16
## The parts of the composition: channel -> (part, the sound it is like; only for the record: the
## patch plays at its own level, its TLs as the file gives them).
FM_PARTS = {"FM1_SlapBass": ("bas", "fm_slapbas"), "FM2_HouseStabs": ("stoot", "synth_brass"),
            "FM3_LeadSynth": ("lead", "fm_lead_helder"), "FM4_SubPad": ("pad", "synthwave_pad"),
            "FM5_FMPerc": ("perc", "fm_klok")}
PSG_PARTS = {"PSG1_Arp": ("arp", "psg_arp"), "PSG2_CounterEcho": ("echo", "psg_lead")}
## The DAC samples and the noise hats as drums of the kit (several at once: a list).
SAMPLES = {"KICK": ["kick"], "KICK_SYNC": ["kick"], "KICK_SNARE_CLAP": ["kick", "snare", "clap"], "SNARE": ["snare"],
           "SNARE_GHOST": ["snare"], "CLAP": ["clap"], "TOM_FILL": ["tom_mid"]}
HATS = {"CH": "hihat", "OH": "open", "SH": "hihat", "CR": "crash"}
## FM5's percussion: a note on its patch (name_<note>), or a drum of the kit.
PERC_DRUMS = {"FM_TOM_SLIDE": "tom_laag"}
## Chord names of the file the notation does not spell (notation.CHORD_SHAPES).
CHORD_NAMES = {"Ebmaj7#11": "Ebmaj7"}


def is_timeline(data) -> bool:
    return isinstance(data, dict) and any(key.startswith("full_track_timeline") for key in data)


def _timeline(data: dict) -> list:
    return next(value for key, value in data.items() if key.startswith("full_track_timeline"))


def problems(data) -> list:
    """What is missing (Dutch, one line each); empty when the file can be used."""
    found = []
    metadata = data.get("metadata") or {}
    if not isinstance(metadata.get("bpm"), (int, float)):
        found.append("'metadata.bpm' ontbreekt")
    if int(metadata.get("steps_per_bar", STEPS)) != STEPS:
        found.append(f"'metadata.steps_per_bar' is {metadata.get('steps_per_bar')}: alleen {STEPS} wordt gelezen")
    bars = _timeline(data)
    for index, bar in enumerate(bars):
        if bar.get("bar") != index + 1:
            found.append(f"maat {index + 1}: 'bar' is {bar.get('bar')}, de maten moeten op volgorde staan")
        if len(bar.get("steps", [])) != STEPS:
            found.append(f"maat {index + 1}: {len(bar.get('steps', []))} stappen in plaats van {STEPS}")
    if not isinstance(data.get("hardware_patches"), dict):
        found.append("'hardware_patches' ontbreekt (de klanken)")
    return found


def _detune(value: int) -> int:
    """A signed detune (-3..3) as the YM2612's DT register (0..3 up, 5..7 down)."""
    value = int(value)
    return value if value >= 0 else 4 - value


def patches(path: str) -> dict:
    """The file's FM patches, channel -> fm.FmVoice (operators in the order the file lists them).
    A file in the standard form (standaardvorm.py: "synthParameters") gives its voices' patches."""
    with open(path, encoding="utf-8") as json_file:
        data = json.load(json_file)
    if "synthParameters" in data:
        import standaardvorm
        return standaardvorm.patches(data)
    voices = {}
    for channel, patch in data.get("hardware_patches", {}).items():
        operators = list((patch.get("operators") or {}).values())
        if len(operators) != 4:
            continue
        voices[channel] = fm.FmVoice(
            algorithm=int(patch["algorithm"]), feedback=int(patch.get("feedback", 0)),
            multiples=tuple(int(op["MUL"]) for op in operators),
            total_levels=tuple(int(op["TL"]) for op in operators),
            attack_rates=tuple(int(op["AR"]) for op in operators),
            decay_rates=tuple(int(op["D1R"]) for op in operators),
            sustain_levels=tuple(int(op["D1L"]) for op in operators),
            detunes=tuple(_detune(op.get("DET", 0)) for op in operators),
            sustain_rates=tuple(int(op.get("D2R", 0)) for op in operators),
            release_rates=tuple(int(op.get("RR", 15)) for op in operators))
    return voices


def _kind(name: str, previous: str) -> str:
    """The soort of a section by its name (tracker.section_kind); a name without one of its words
    that continues a section of the same letter ("Section C2" after "C1") is of its kind."""
    kind = tracker.section_kind(name)
    if kind == "opbouw" and not any(word in name.upper() for word in ("PRE", "BUILD", "BRIDGE")) and previous:
        return previous
    return kind


def _position(step: int) -> float:
    return round(1.0 + (step - 1) * 0.25, 4)


def _velocity(value) -> float:
    return round(max(0.05, min(1.0, float(value or 100) / 127.0)), 2)


def read(path: str) -> dict:
    """The file as bars of parts and drums: {"title", "tempo", "key", "loop", "sections",
    "bars": [{"chord", part: [(position, pitches, length, velocity)], "drums": [(position, drum,
    velocity)]}], "warnings"}."""
    with open(path, encoding="utf-8") as json_file:
        data = json.load(json_file)
    wrong = problems(data)
    if wrong:
        raise ValueError(f"{path}: de compositie kan zo niet gebruikt worden:\n  " + "\n  ".join(wrong[:40]))
    metadata = data["metadata"]
    timeline = _timeline(data)
    bars = [{"chord": "", "drums": []} for _bar in timeline]
    warnings = []
    # the melodic FM channels with their lengths: the flat events
    for event in data.get("flat_sequencer_events", []):
        channel = event.get("channel")
        if channel not in ("FM1_SlapBass", "FM2_HouseStabs", "FM3_LeadSynth"):
            continue
        part = FM_PARTS[channel][0]
        pitches = tuple(event["midi_notes"]) if "midi_notes" in event else (int(event["midi"]),)
        bars[event["bar"] - 1].setdefault(part, []).append(
            (_position(event["step"]), pitches, int(event.get("duration_steps", 1)) * 0.25, _velocity(event["velocity"])))
    # the velocity of every drum hit as the file gives it (the flat events)
    drum_velocity = {}
    for event in data.get("flat_sequencer_events", []):
        if event.get("channel") in ("FM6_DAC_Drums", "PSG4_NoiseHats"):
            drum_velocity[(event["channel"], event["bar"], event["step"])] = _velocity(event.get("velocity"))
    effects = set()
    dropped = {}
    for index, bar in enumerate(timeline):
        out = bars[index]
        out["chord"] = str(bar.get("chord", ""))
        steps = bar["steps"]
        for step_data in steps:
            step = int(step_data["step"])
            at = _position(step)
            lead = step_data.get("FM3_LeadSynth")
            if isinstance(lead, dict) and lead.get("fx"):
                effects.add(f"FM3 {lead['fx']}")
            stab = step_data.get("FM2_HouseStabs")
            if isinstance(stab, dict) and "SLIDE" in str(stab.get("articulation", "")):
                effects.add(f"FM2 {stab['articulation']}")
            pad = step_data.get("FM4_SubPad")
            if isinstance(pad, dict) and pad.get("notes"):
                # held until the next chord of the pad, or the end of the bar
                later = [int(s["step"]) for s in steps if s["step"] > step and isinstance(s.get("FM4_SubPad"), dict)]
                until = (later[0] if later else STEPS + 1) - step
                out.setdefault("pad", []).append((at, tuple(notation.pitch(note) for note in pad["notes"]),
                                                  until * 0.25, _velocity(pad.get("velocity"))))
            perc = step_data.get("FM5_FMPerc")
            if isinstance(perc, str) and perc not in ("---", ""):
                note = re.match(r"^[A-Z_]+_([A-G][#b]?\d)$", perc)
                if perc in PERC_DRUMS:
                    out["drums"].append((at, PERC_DRUMS[perc], 0.8))
                elif note:
                    out.setdefault("perc", []).append((at, (notation.pitch(note.group(1)),), 0.25, 0.8))
                else:
                    dropped[f"FM5 {perc}"] = dropped.get(f"FM5 {perc}", 0) + 1
            arp = step_data.get("PSG1_Arp")
            if isinstance(arp, dict) and arp.get("midi") is not None:
                out.setdefault("arp", []).append((at, (int(arp["midi"]),), 0.25, _velocity(arp.get("velocity"))))
            echo = step_data.get("PSG2_CounterEcho")
            if isinstance(echo, dict) and echo.get("midi") is not None:
                # it sustains (the file: "Sustain with fast release") until its next note
                later = [int(s["step"]) for s in steps if s["step"] > step and isinstance(s.get("PSG2_CounterEcho"), dict)]
                length = (later[0] if later else STEPS + 1) - step
                out.setdefault("echo", []).append((at, (int(echo["midi"]),), length * 0.25, _velocity(echo.get("velocity"))))
            sample = step_data.get("FM6_DAC_Drums")
            if isinstance(sample, str) and sample not in ("---", ""):
                if sample in SAMPLES:
                    velocity = drum_velocity.get(("FM6_DAC_Drums", index + 1, step), 1.0)
                    out["drums"] += [(at, drum, velocity) for drum in SAMPLES[sample]]
                else:
                    dropped[f"DAC {sample}"] = dropped.get(f"DAC {sample}", 0) + 1
            hat = step_data.get("PSG4_NoiseHats")
            if isinstance(hat, str) and hat in HATS:
                out["drums"].append((at, HATS[hat], drum_velocity.get(("PSG4_NoiseHats", index + 1, step), 1.0)))
    for name, count in sorted(dropped.items()):
        warnings.append(f"{name} ({count}x) niet nagespeeld: geen klank voor (een sample of onbekend)")
    for effect in sorted(effects):
        warnings.append(f"effect niet nagespeeld: {effect} (de noot klinkt zonder)")
    sections = []
    for section in data.get("arrangement_structure", []):
        previous = sections[-1]["soort"] if sections else ""
        sections.append({"naam": str(section["section"]), "soort": _kind(str(section["section"]), previous),
                         "maten": (int(section["start_bar"]), int(section["end_bar"]))})
    loop = metadata.get("loop_points") or {}
    key = str(metadata.get("key_signature", metadata.get("key", "C")))
    return {"title": str(metadata.get("title", "")), "tempo": float(metadata["bpm"]), "key": key,
            "loop": (int(loop.get("seamless_loop_start_bar", 1)), int(loop.get("seamless_loop_end_bar", len(timeline)))),
            "sections": sections, "bars": bars, "warnings": warnings,
            "patches": sorted(patches(path)), "chords": data.get("chord_dictionary", {})}


def _chord_name(name: str) -> str:
    name = CHORD_NAMES.get(name, name).replace("_over_", "/")
    return name


def _key(text: str) -> tuple:
    match = re.match(r"^([A-G][#b]?)\s*(\w+)?", text)
    tonic = match.group(1) if match else "C"
    mode = (match.group(2) or "").lower()
    names = {"dorian": "dorisch", "minor": "mineur", "major": "majeur", "mixolydian": "mixolydisch"}
    return tonic, names.get(mode, "mineur" if "m" in mode[:1] else "majeur")


def composition_source(source: dict, name: str, json_name: str) -> str:
    tonic, mode = _key(source["key"])
    out = [f'"""{source["title"]}: de partituur van {json_name} (de tijdlijn van de componist, letterlijk:',
           "elke noot op zijn stap met zijn lengte en velocity, tools/muziek/tijdlijn.py).", "",
           "De tertiaire basis van de muziek (composities/actief.py GEVECHT): de vechtscène, zoals geschreven.",
           "De FM-kanalen spelen hun eigen patches uit het bestand (patch:...), de PSG-kanalen de PSG-klanken,",
           "de drums (DAC-samples en ruis-hats) het Mega Drive-drumstel. Het hele nummer is gevecht.ogg.", ""]
    out += [f"Niet nagespeeld: {warning}" for warning in source["warnings"]]
    out += ['"""', "from notation import Hit, Note", "",
            f"TITEL = {json.dumps(source['title'], ensure_ascii=False)}",
            f"TEMPO = {source['tempo']:g}", "TELLEN_PER_MAAT = 4",
            f'TOONSOORT = ("{tonic}", "{mode}")   # het bestand: {source["key"]}', "",
            f"# de luspunten van het bestand (loop_points, ter informatie: gevecht.ogg is het hele nummer)",
            f"LUSPUNTEN = {source['loop']!r}", "",
            "# elk kanaal zijn eigen klank: de FM-patches uit het bestand, op hun eigen niveau (hun TL's)",
            "KLANKEN = {"]
    for channel, (part, reference) in FM_PARTS.items():
        if channel in source["patches"]:
            out.append(f'    "{part}": "patch:{json_name}:{channel}",'.ljust(56) + f"# zoals {reference}")
    for channel, (part, sound) in PSG_PARTS.items():
        out.append(f'    "{part}": "{sound}",   # {channel}')
    out += ['    "drumstel": "standaard",', "}", "", "SECTIES = ["]
    for section in source["sections"]:
        out.append(f'    {{"naam": {json.dumps(section["naam"], ensure_ascii=False)}, "soort": "{section["soort"]}", '
                   f'"maten": {section["maten"]!r}}},')
    out += ["]", "", "MATEN = {"]
    for number, bar in enumerate(source["bars"], start=1):
        entries = [f'"akkoord": "{_chord_name(bar["chord"])}"'] if bar["chord"] else []
        for part in ("bas", "stoot", "lead", "pad", "perc", "arp", "echo"):
            notes = bar.get(part, [])
            if notes:
                text = ", ".join(f"Note({at:g}, {tuple(pitches)!r}, {length:g}, {velocity:g})"
                                 for at, pitches, length, velocity in sorted(notes))
                entries.append(f'"{part}": [{text}]')
        hits = ", ".join(f'Hit({at:g}, "{drum}", {velocity:g})' for at, drum, velocity in sorted(bar["drums"]))
        entries.append(f'"drums": [{hits}]')
        out.append(f"    {number}: {{" + ",\n        ".join(entries) + "},")
    out.append("}")
    return "\n".join(out) + "\n"


def report(source: dict) -> str:
    seconds = len(source["bars"]) * 4 * 60.0 / source["tempo"]
    lines = [f"tijdlijn: {source['title']}",
             f"tempo {source['tempo']:g} BPM, {len(source['bars'])} maten = {seconds:.1f} s; toonsoort {source['key']}",
             f"luspunten volgens het bestand: maat {source['loop'][0]}-{source['loop'][1]} (ter informatie: het hele nummer wordt gevecht.ogg)",
             "FM-patches: " + ", ".join(source["patches"]),
             "secties: " + ", ".join(f"{s['naam']} ({s['soort']}) maat {s['maten'][0]}-{s['maten'][1]}" for s in source["sections"])]
    counts = {}
    for bar in source["bars"]:
        for part, notes in bar.items():
            if isinstance(notes, list):
                counts[part] = counts.get(part, 0) + len(notes)
    lines.append("noten: " + ", ".join(f"{part} {count}" for part, count in sorted(counts.items())))
    return "\n".join(lines)


def main(arguments: list = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("json")
    parser.add_argument("naam", nargs="?")
    parser.add_argument("--toon", action="store_true")
    parser.add_argument("--overschrijf", action="store_true")
    options = parser.parse_args(arguments)
    try:
        source = read(options.json)
    except (ValueError, OSError, KeyError) as error:
        print(error)
        return 1
    name = options.naam or tracker.default_name(options.json)
    print(report(source))
    for warning in source["warnings"]:
        print("LET OP: " + warning)
    if options.toon:
        return 0
    target = os.path.join(COMPOSITIONS_FOLDER, name + ".py")
    if os.path.exists(target) and not options.overschrijf:
        print(f"{target} bestaat al: geef --overschrijf om het te vervangen")
        return 1
    kept = os.path.join(COMPOSITIONS_FOLDER, name + ".json")
    if os.path.abspath(kept) != os.path.abspath(options.json):
        shutil.copyfile(options.json, kept)
        print(f"bron bewaard: {kept}")
    with open(target, "w", encoding="utf-8") as composition_file:
        composition_file.write(composition_source(source, name, name + ".json"))
    print(f"geschreven: {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
