"""Brings a composition in JSON to the standard form (standaardvorm.py, docs/MUZIEK_JSON.md): the
one structure every file in data/muziek/ has.

    tools/muziek/naar_standaardvorm.sh <bestand.json>               in place; the file as it was is kept
                                                                    in origineel/<bestand.json> next to it
    tools/muziek/naar_standaardvorm.sh <bestand.json> <uit.json>    written somewhere else, the source untouched
    tools/muziek/naar_standaardvorm.sh --controle <bestand.json>... only says whether each is in the standard form

The forms it knows (FORMS), each brought over note for note:

    standaard     already in the standard form: only its fields in their fixed order and layout
    gewoon        the usual form of the tracker (metadata, sections, synthParameters, bars) without `synth`
    plat          the flat form (bpm at the top, per bar lead/brass/arp/bass/drums)
    tijdlijn      the full timeline (hardware_patches, full_track_timeline_<n>_bars, flat_sequencer_events)
    gebeurtenissen   a list of events per bar and step (`full_event_timeline`) with the chips' patches
    tellen        a list of events per bar and beat (`sequenced_events`) with one drum grid for every bar
    patronen      a sketch: per section patterns of sixteenths (`..._16ths`) and a melody per bar

What the source says but the standard form does not play is kept in the file (`extra`, an
event's `effect` / `articulation` / `label`, a drum track's `sample`) and reported; what the
source leaves open and had to be chosen is reported as KEUZE.
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
import standaardvorm  # noqa: E402
import tijdlijn  # noqa: E402
import tracker  # noqa: E402

STEPS = standaardvorm.STEPS
HOLD = standaardvorm.HOLD
ORIGINALS_FOLDER = "origineel"
## An accented hit of a drum grid ("X") and a plain one ("x"), as velocities.
ACCENT_VELOCITY = 127
PLAIN_VELOCITY = 100
## The drums of the Mega Drive kit (tijdlijn.SAMPLES, HATS, PERC_DRUMS) as the standard form names them.
KIT_DRUMS = {kit_name: code for code, kit_name in standaardvorm.PATCH_DRUMS.items()}
## The names of a timeline's samples and hats that say no more than their drum (no `label` kept).
PLAIN_TIMELINE_DRUMS = ("KICK", "SNARE", "CLAP", "CH", "OH", "CR")


class Conversion:
    """What a conversion found: the choices it had to make and what it could not carry over."""

    def __init__(self) -> None:
        self.choices = []
        self.not_carried = []

    def choice(self, text: str) -> None:
        if text not in self.choices:
            self.choices.append(text)

    def lost(self, text: str) -> None:
        if text not in self.not_carried:
            self.not_carried.append(text)


def camel(name: str) -> str:
    """"time_signature" -> "timeSignature" (the spelling of the standard form's fields)."""
    words = [word for word in re.split(r"[_\s]+", name) if word]
    return words[0] + "".join(word[:1].upper() + word[1:] for word in words[1:]) if words else name


def _metadata(title, bpm, key, bar_count: int, synth: str, more: dict) -> dict:
    metadata = {"title": str(title or ""), "bpm": bpm, "timeSignature": "4/4", "stepsPerBar": STEPS, "totalBars": bar_count,
                "key": str(key or ""), "synth": synth}
    for name, value in more.items():
        if camel(name) not in metadata and value is not None:
            metadata[camel(name)] = value
    return metadata


def _registers(patch: dict, where: str, conversion: Conversion) -> dict:
    """An FM patch of a source as `ym2612Registers`: the operators in the order the source lists
    them, a signed detune (-3..3) as the chip's register, the sustain level under whatever name
    the source gives it. A register the source does not give is 0 (the chip's value after a reset)."""
    operators = {}
    for operator_name, source in patch["operators"].items():
        operator = {}
        for register, names in (("DT", ("DT", "DET")), ("MUL", ("MUL", "MULT")), ("TL", ("TL",)), ("AR", ("AR",)),
                                ("D1R", ("D1R", "DR")), ("D2R", ("D2R", "SR")), ("D1L", ("D1L", "S1L", "SL")), ("RR", ("RR",))):
            given = next((source[name] for name in names if name in source), None)
            if given is None:
                given = 0
                if register != "DT":
                    conversion.choice(f"{where}: het bestand geeft geen {register}; 0 genomen (de waarde van de chip na een reset)")
            operator[register] = tijdlijn._detune(given) if register == "DT" else int(given)
        if "RS" in source:
            operator["RS"] = int(source["RS"])
        operators[operator_name] = operator
    return {"algorithm": int(patch["algorithm"]), "feedback": int(patch.get("feedback", 0)), "operators": operators}


## The order of the voices of synth "patches" in a converted file, by their part.
PART_ORDER = ("bas", "stoot", "lead", "pad", "perc", "zuur", "arp", "echo")


def _in_order(mapping, first_keys: tuple):
    """A dict with these keys first, in this order (anything else: as it was)."""
    if not isinstance(mapping, dict):
        return mapping
    ordered = {key: mapping[key] for key in first_keys if key in mapping}
    ordered.update({key: value for key, value in mapping.items() if key not in ordered})
    return ordered


def _by_part(voices: dict) -> dict:
    """The voices in the order of their parts (PART_ORDER, then the others as they came)."""
    def rank(name: str) -> int:
        part = voices[name]["part"]
        return PART_ORDER.index(part) if part in PART_ORDER else len(PART_ORDER)
    return {name: voices[name] for name in sorted(voices, key=rank)}


def _pitch_classes(notes: list) -> set:
    import notation
    return {notation.pitch(note) % 12 for note in notes}


def _named_chord(played: list, named: list):
    """The entry of the file's own chord lists ({"chord", "notes"}) that the played notes are: the
    same notes in any octave, else the one on the same root that shares most with them; None when
    there is none."""
    classes = _pitch_classes(played)
    same = [entry for entry in named if _pitch_classes(entry.get("notes") or []) == classes]
    if same:
        return same[0]
    import notation
    root = notation.pitch(played[0]) % 12
    on_root = [entry for entry in named if entry.get("notes") and notation.pitch(entry["notes"][0]) % 12 == root]
    return max(on_root, key=lambda entry: len(_pitch_classes(entry["notes"]) & classes)) if on_root else None


def _has_patch(patch) -> bool:
    return isinstance(patch, dict) and isinstance(patch.get("operators"), dict) and len(patch["operators"]) == 4 \
        and isinstance(patch.get("algorithm"), int)


def _voice(part: str, patch, fallback_sound: str, where: str, conversion: Conversion, info: dict = None) -> dict:
    """A voice of synth "patches": its own FM patch when the source gives one with operators,
    else the named sound (a choice, unless the source's channel is not an FM channel)."""
    voice = {"part": part}
    for name, value in (info or {}).items():
        if name not in ("operators", "algorithm", "feedback", "part", "sound") and value is not None:
            voice[camel(name)] = value
    if _has_patch(patch):
        voice["ym2612Registers"] = _registers(patch, where, conversion)
    else:
        voice["sound"] = fallback_sound
        if isinstance(patch, dict) and "algorithm" in patch:
            conversion.choice(f"{where}: het bestand geeft geen operators voor deze FM-stem; de klank '{fallback_sound}' genomen")
    return voice


class Grid:
    """The bars of a file of synth "patches" being filled: per bar per track sixteen cells."""

    def __init__(self, tracks: list, bar_count: int) -> None:
        self.tracks = list(tracks) + [standaardvorm.DRUM_TRACK]
        self.cells = [{track: [[] for _step in range(STEPS)] for track in self.tracks} for _bar in range(bar_count)]

    def add(self, bar_number: int, step: int, track: str, event: dict) -> None:
        """`step` from 1."""
        self.cells[bar_number - 1][track][step - 1].append(event)

    def channels(self, bar_number: int) -> dict:
        return {track: [HOLD if not events else (events[0] if len(events) == 1 else events) for events in row]
                for track, row in self.cells[bar_number - 1].items()}


def _note(notes: list, steps, velocity=None, **kept) -> dict:
    event = {"notes": list(notes), "steps": int(steps) if float(steps) == int(steps) else round(float(steps), 4)}
    if velocity is not None:
        event["velocity"] = velocity
    event.update({name: value for name, value in kept.items() if value})
    return event


def _hit(drum: str, velocity=None, label: str = "") -> dict:
    event = {"drum": drum}
    if velocity is not None:
        event["velocity"] = velocity
    if label:
        event["label"] = label
    return event


def _sections_of_bars(sections: list, bar_count: int, conversion: Conversion) -> list:
    """The sections cut to the bars there are; a section past the last bar is not carried."""
    kept = []
    for section in sections:
        if section["startBar"] > bar_count:
            conversion.lost(f"sectie '{section['name']}' (maat {section['startBar']}-{section['endBar']}): het bestand "
                            "heeft er geen noten voor; niet overgenomen (staat in 'extra')")
            continue
        kept.append(dict(section, endBar=min(section["endBar"], bar_count)))
    return kept


def _bars(grid: Grid, sections: list, chords: list) -> list:
    return [{"barNumber": number, "section": standaardvorm._section_name_at(sections, number) or "",
             "chord": chords[number - 1], "channels": grid.channels(number)} for number in range(1, len(chords) + 1)]


def _bar_range(text) -> tuple:
    """"9-24" or [9, 24] -> (9, 24)."""
    if isinstance(text, (list, tuple)):
        return int(text[0]), int(text[-1])
    first, _dash, last = str(text).partition("-")
    return int(first), int(last or first)


def _grid_row(text: str) -> str:
    return re.sub(r"\s+", "", text)


# ----------------------------------------------------------------------------- the forms of the tracker synth

def from_usual(data: dict, conversion: Conversion) -> dict:
    """The usual form of the tracker: `synth` named, every voice its volume, every bar its fields."""
    metadata = dict(data["metadata"])
    bars = []
    sections = [dict(section, name=str(section.get("name", section.get("id", "")))) for section in data.get("sections", [])]
    for index, bar in enumerate(data["bars"]):
        number = bar.get("barNumber", index + 1)
        chord = bar.get("chord") if isinstance(bar.get("chord"), dict) else {"name": str(bar.get("chord", "") or "")}
        bars.append({"barNumber": number, "section": standaardvorm._section_name_at(sections, number) or str(bar.get("section", "")),
                     "chord": chord, "channels": _in_order(bar.get("channels"), tuple(json_bron.TRACKS))})
        if bar.get("section") not in (None, "", bars[-1]["section"]):
            conversion.choice(f"maat {number}: 'section' was {bar['section']!r}; de naam van de sectie uit 'sections' genomen")
    voices = dict(data.get("synthParameters") or {})
    filled = []
    for index, voice in enumerate(json_bron.VOICES):
        if not isinstance((voices.get(voice) or {}).get("volume"), (int, float)):
            voices[voice] = dict(voices.get(voice) or {}, volume=tracker.DEFAULT_VOLUMES[index])
            filled.append(f"{voice} {tracker.DEFAULT_VOLUMES[index]:g}")
    if filled:
        conversion.choice("'synthParameters' gaf geen volume voor " + ", ".join(filled)
                          + ": het volume van de tracker zelf ingevuld, zoals het al gespeeld werd")
    result = {"metadata": _metadata(metadata.pop("title", ""), metadata.pop("bpm", None), metadata.pop("key", ""), len(bars),
                                    "tracker", {name: value for name, value in metadata.items()
                                                if name not in ("timeSignature", "stepsPerBar", "totalBars", "synth")}),
              "sections": sections,
              "synthParameters": {voice: voices[voice] for voice in json_bron.VOICES}}
    if "master" in data:
        result["master"] = data["master"]
    result["bars"] = bars
    extra = {name: value for name, value in data.items() if name not in standaardvorm.TOP_KEYS}
    if extra or "extra" in data:
        result["extra"] = dict(data.get("extra") or {}, **extra)
    return result


def from_flat(data: dict, conversion: Conversion) -> dict:
    """The flat form, read the way json_bron reads it (json_bron.from_flat) and then as the usual form."""
    usual = json_bron.from_flat(data)
    for name, value in data.items():
        if name not in usual["metadata"] and name not in ("bars", "synthParameters", "master"):
            usual["metadata"][name] = value
    if any("T" in str(cell).split("+") for bar in data["bars"] for cell in bar.get("drums") or [] if cell):
        conversion.choice("de drum 'T' (een tom zonder toonhoogte) is de middelste tom (TOM2), zoals hij al gespeeld werd")
    conversion.choice("de platte vorm heeft geen harmoniespoor: 'FM4_harmony' is leeg")
    return from_usual(usual, conversion)


# ----------------------------------------------------------------------------- the full timeline

TIMELINE_VOICES = (("FM1_SlapBass", "bas", None), ("FM2_HouseStabs", "stoot", None), ("FM3_LeadSynth", "lead", None),
                   ("FM4_SubPad", "pad", None), ("FM5_FMPerc", "perc", None), ("PSG1_Arp", "arp", "psg_arp"),
                   ("PSG2_CounterEcho", "echo", "psg_lead"))


def from_timeline(data: dict, conversion: Conversion) -> dict:
    """The full timeline, every note where tijdlijn.read puts it: the FM channels' notes with their
    lengths from `flat_sequencer_events`, the pad held to its next chord, the echo to its next note."""
    wrong = tijdlijn.problems(data)
    if wrong:
        raise ValueError("de tijdlijn kan zo niet gebruikt worden:\n  " + "\n  ".join(wrong[:40]))
    metadata = dict(data["metadata"])
    timeline = tijdlijn._timeline(data)
    hardware = data["hardware_patches"]
    voices = {}
    for channel, part, sound in TIMELINE_VOICES:
        info = next((patch for name, patch in hardware.items() if channel.startswith(name)), None)
        if sound is None and not _has_patch(info):
            if any(step.get(channel) not in (None, "", HOLD) and (not isinstance(step.get(channel), dict)
                                                                   or step[channel].get("note", "x") != HOLD)
                   for bar in timeline for step in bar["steps"]):
                raise ValueError(f"het FM-kanaal {channel} speelt maar heeft geen patch met vier operators in 'hardware_patches'")
            continue
        voices[channel] = _voice(part, info, sound, f"'hardware_patches.{channel}'", conversion, info)
    drum_info = {name: patch for name, patch in hardware.items() if name in ("FM6_DAC_Drums", "PSG4_NoiseHats")}
    grid = Grid(list(voices), len(timeline))
    drum_velocity = {}
    for event in data.get("flat_sequencer_events", []):
        channel = event.get("channel")
        if channel in ("FM6_DAC_Drums", "PSG4_NoiseHats"):
            drum_velocity[(channel, event["bar"], event["step"])] = event.get("velocity") or 100
        elif channel in ("FM1_SlapBass", "FM2_HouseStabs", "FM3_LeadSynth") and channel in voices:
            midi_pitches = event["midi_notes"] if "midi_notes" in event else [event["midi"]]
            grid.add(event["bar"], event["step"], channel,
                     _note([standaardvorm.note_name(int(pitch)) for pitch in midi_pitches], event.get("duration_steps", 1),
                           event.get("velocity") or 100))
    for index, bar in enumerate(timeline):
        number = index + 1
        steps = bar["steps"]
        for step_data in steps:
            step = int(step_data["step"])
            lead = step_data.get("FM3_LeadSynth")
            stab = step_data.get("FM2_HouseStabs")
            for channel, effect in (("FM3_LeadSynth", lead.get("fx") if isinstance(lead, dict) else None),
                                    ("FM2_HouseStabs", stab.get("articulation") if isinstance(stab, dict)
                                     and "SLIDE" in str(stab.get("articulation", "")) else None)):
                if not effect:
                    continue
                started = grid.cells[index].get(channel, [[]] * STEPS)[step - 1]
                if started:
                    started[0]["effect"] = effect
                else:
                    conversion.lost(f"{channel}: effect {effect!r} op een stap waar geen noot begint (o.a. maat {number} stap {step})")
            pad = step_data.get("FM4_SubPad")
            if isinstance(pad, dict) and pad.get("notes") and "FM4_SubPad" in voices:
                later = [int(other["step"]) for other in steps if other["step"] > step and isinstance(other.get("FM4_SubPad"), dict)]
                grid.add(number, step, "FM4_SubPad", _note(pad["notes"], (later[0] if later else STEPS + 1) - step,
                                                           pad.get("velocity") or 100))
            perc = step_data.get("FM5_FMPerc")
            if isinstance(perc, str) and perc not in (HOLD, ""):
                perc_note = re.match(r"^[A-Z_]+_([A-G][#b]?\d)$", perc)
                if perc in tijdlijn.PERC_DRUMS:
                    grid.add(number, step, "drums", _hit(KIT_DRUMS[tijdlijn.PERC_DRUMS[perc]], 102, perc))
                elif perc_note and "FM5_FMPerc" in voices:
                    grid.add(number, step, "FM5_FMPerc", _note([perc_note.group(1)], 1, 102, label=perc))
                else:
                    grid.add(number, step, "drums", {"sample": perc})
            arp = step_data.get("PSG1_Arp")
            if isinstance(arp, dict) and arp.get("midi") is not None:
                grid.add(number, step, "PSG1_Arp", _note([standaardvorm.note_name(int(arp["midi"]))], 1, arp.get("velocity") or 100))
            echo = step_data.get("PSG2_CounterEcho")
            if isinstance(echo, dict) and echo.get("midi") is not None:
                later = [int(other["step"]) for other in steps
                         if other["step"] > step and isinstance(other.get("PSG2_CounterEcho"), dict)]
                grid.add(number, step, "PSG2_CounterEcho", _note([standaardvorm.note_name(int(echo["midi"]))],
                                                                 (later[0] if later else STEPS + 1) - step,
                                                                 echo.get("velocity") or 100))
            sample = step_data.get("FM6_DAC_Drums")
            if isinstance(sample, str) and sample not in (HOLD, ""):
                if sample in tijdlijn.SAMPLES:
                    velocity = drum_velocity.get(("FM6_DAC_Drums", number, step), 127)
                    for kit_drum in tijdlijn.SAMPLES[sample]:
                        grid.add(number, step, "drums", _hit(KIT_DRUMS[kit_drum], velocity,
                                                             "" if sample in PLAIN_TIMELINE_DRUMS else sample))
                else:
                    grid.add(number, step, "drums", {"sample": sample})
            hat = step_data.get("PSG4_NoiseHats")
            if isinstance(hat, str) and hat in tijdlijn.HATS:
                grid.add(number, step, "drums", _hit(KIT_DRUMS[tijdlijn.HATS[hat]], drum_velocity.get(("PSG4_NoiseHats", number, step), 127),
                                                     "" if hat in PLAIN_TIMELINE_DRUMS else hat))
    conversion.choice("de pad (FM4) houdt aan tot zijn volgende akkoord en de echo (PSG2) tot zijn volgende noot; FM5 en de "
                      "FM-tom op velocity 102: zoals de tijdlijn al gespeeld werd (tijdlijn.py)")
    sections = [{"name": str(section["section"]), "startBar": int(section["start_bar"]), "endBar": int(section["end_bar"]),
                 **{camel(name): value for name, value in section.items() if name not in ("section", "start_bar", "end_bar")}}
                for section in data.get("arrangement_structure", [])]
    chords = []
    for bar in timeline:
        chord = {"name": str(bar.get("chord", "")).replace("_over_", "/")}
        if bar.get("chord_notes"):
            chord["voicing"] = list(bar["chord_notes"])
        chords.append(chord)
    loop = metadata.pop("loop_points", None) or {}
    more = {name: value for name, value in metadata.items()
            if name not in ("title", "bpm", "time_signature", "steps_per_bar", "total_bars", "key_signature", "key")}
    if "seamless_loop_start_bar" in loop:
        more["loopStartBar"] = loop["seamless_loop_start_bar"]
    if "seamless_loop_end_bar" in loop:
        more["loopEndBar"] = loop["seamless_loop_end_bar"]
    more.update({name: value for name, value in loop.items() if not name.startswith("seamless_loop")})
    if drum_info:
        voices["drums"] = drum_info
    result = {"metadata": _metadata(metadata.get("title"), metadata["bpm"], metadata.get("key_signature", metadata.get("key")),
                                    len(timeline), "patches", more),
              "sections": sections, "synthParameters": voices, "bars": _bars(grid, sections, chords)}
    extra = {name: value for name, value in data.items()
             if name not in ("metadata", "hardware_patches", "arrangement_structure", "flat_sequencer_events")
             and not name.startswith("full_track_timeline")}
    if extra:
        result["extra"] = extra
    return result


# ----------------------------------------------------------------------------- events per bar and step

EVENT_DRUMS = (("KICK", ("KCK",)), ("SNARE_CLAP", ("SNR", "CLP")), ("SNARE", ("SNR",)), ("CLAP", ("CLP",)),
               ("OPEN", ("OHH",)), ("CLOSED", ("CHH",)), ("HAT", ("CHH",)), ("CRASH", ("CRS",)), ("TOM", ("TOM2",)))


def _event_drums(instrument: str):
    upper = instrument.upper()
    for word, drums in EVENT_DRUMS:
        if word in upper:
            return drums
    return None


def from_step_events(data: dict, conversion: Conversion) -> dict:
    """`full_event_timeline`: every event at its bar and step with its length in steps and its
    velocity; the patches of the chips' channels (`sound_chips`)."""
    events = data["full_event_timeline"]
    bar_count = max(event["bar"] for event in events)
    fm_channels = {int(channel["channel"]): channel for channel in data.get("sound_chips", {}).get("YM2612_FM", {}).get("channels", [])
                   if isinstance(channel.get("channel"), int)}
    parts = (("LEAD", "lead", "fm_lead_helder"), ("BASS", "bas", "fm_slapbas"), ("STAB", "stoot", "synth_brass"),
             ("CHORD", "stoot", "synth_brass"), ("PAD", "pad", "synthwave_pad"), ("ARP", "arp", "psg_arp"),
             ("ACID", "zuur", "fm_lead_zuur"), ("PLUCK", "zuur", "fm_lead_zuur"))
    voices = {}
    drum_channels = set()
    for event in events:
        channel = event["channel"]
        instrument = str(event.get("instrument", ""))
        if "note" not in event and "chord_notes" not in event or "DAC" in channel.upper() or "NOISE" in channel.upper():
            drum_channels.add(channel)
            continue
        if channel in voices:
            continue
        part, sound = next(((part, sound) for word, part, sound in parts if word in instrument.upper()), (camel(instrument).lower(), "psg_lead"))
        number = re.search(r"CH(\d)", channel)
        patch = fm_channels.get(int(number.group(1))) if number and "YM2612" in channel else None
        if patch is None and "PSG" not in channel.upper():
            conversion.choice(f"kanaal {channel}: geen patch in het bestand; de klank '{sound}' genomen")
        voices[channel] = _voice(part, patch, sound, f"kanaal {channel}", conversion,
                                 dict({name: value for name, value in (patch or {}).items() if name != "channel"}, instrument=instrument))
    voices = _by_part(voices)
    grid = Grid(list(voices), bar_count)
    for event in events:
        channel = event["channel"]
        if channel in drum_channels:
            drums = _event_drums(str(event.get("instrument", "")))
            if drums is None:
                grid.add(event["bar"], event["step"], "drums", {"sample": str(event.get("instrument", ""))})
                continue
            for drum in drums:
                grid.add(event["bar"], event["step"], "drums", _hit(drum, event.get("velocity"),
                                                                    str(event.get("instrument", "")) if len(drums) > 1 else ""))
            continue
        notes = event["chord_notes"] if "chord_notes" in event else [event["note"]]
        grid.add(event["bar"], event["step"], channel,
                 _note(notes, event.get("duration_steps", 1), event.get("velocity"), articulation=event.get("articulation")))
    if any(len(_event_drums(str(event.get("instrument", ""))) or ()) > 1 for event in events if event["channel"] in drum_channels):
        conversion.choice("een sample dat twee drums in één is (snare met clap) is beide drums tegelijk, zoals bij de tijdlijn")
    conversion.lost("de lengte van een drumslag ('duration_steps'): een drum klinkt zo lang als zijn sample")
    sections = _sections_of_bars([{"name": str(section["section"]), "startBar": _bar_range(section["bars"])[0],
                                   "endBar": _bar_range(section["bars"])[1],
                                   **{camel(name): value for name, value in section.items() if name not in ("section", "bars")}}
                                  for section in data.get("song_structure", [])], bar_count, conversion)
    # the chord of a bar: the progression entry whose notes the bar's first chord event plays
    named = [entry for progression in (data.get("chord_progressions") or {}).values() for entry in progression]
    conversion.choice("de akkoordnaam van een maat: die uit 'chord_progressions' met dezelfde noten als het akkoord dat de maat "
                      "speelt (in welk octaaf ook), anders die op dezelfde grondtoon die er het meest op lijkt")
    chords = []
    for number in range(1, bar_count + 1):
        played = next((event["chord_notes"] for event in events if event["bar"] == number and "chord_notes" in event), None)
        entry = _named_chord(played, named) if played else None
        if entry:
            chords.append({"name": str(entry["chord"]), "voicing": list(played)})
        elif played:
            chords.append({"name": tracker.chord_from_notes([standaardvorm.note_name(_pitch(note)) for note in played]),
                           "voicing": list(played)})
            conversion.choice("een akkoord dat een maat speelt maar dat niet in 'chord_progressions' staat is naar zijn noten genoemd")
        else:
            chords.append({"name": ""})
    if any(not chord["name"] for chord in chords):
        empty = [str(number) for number, chord in enumerate(chords, start=1) if not chord["name"]]
        conversion.lost(f"de akkoordnaam van maat {', '.join(empty)}: daar speelt geen akkoord en het bestand zegt niet welke "
                        "reeks van 'chord_progressions' er geldt; leeg gelaten")
    more = {name: value for name, value in data.items()
            if not isinstance(value, (dict, list)) or name in ("artist_inspiration", "inspiration")}
    if "swing_percentage" in more:
        more["swingPercent"] = more.pop("swing_percentage")
    for name in ("title", "tempo_bpm", "bpm", "time_signature", "key", "key_signature"):
        more.pop(name, None)
    result = {"metadata": _metadata(data.get("title"), data.get("tempo_bpm", data.get("bpm")), data.get("key", data.get("key_signature")),
                                    bar_count, "patches", more),
              "sections": sections, "synthParameters": voices, "bars": _bars(grid, sections, chords),
              "extra": {name: data[name] for name in ("sound_chips", "chord_progressions", "song_structure", "patterns") if name in data}}
    return result


def _pitch(note: str) -> int:
    import notation
    return notation.pitch(note)


# ----------------------------------------------------------------------------- events per bar and beat

def _beat_step(beat: float, where: str) -> int:
    step = (float(beat) - 1.0) * 4.0 + 1.0
    if abs(step - round(step)) > 1e-6:
        raise ValueError(f"{where}: tel {beat} valt niet op een zestiende (de standaardvorm heeft 16 stappen per maat)")
    return int(round(step))


def from_beat_events(data: dict, conversion: Conversion) -> dict:
    """`sequenced_events`: every event at its bar and beat with its length in beats; one drum
    grid (`drum_pattern_grid_16th`) that every bar plays."""
    events = data["sequenced_events"]
    bar_count = max(event["bar"] for event in events)
    described = {str(channel.get("channel_id", "")): channel for channel in data.get("channels", [])}
    parts = (("BASS", "bas", "fm_slapbas"), ("CHORD", "stoot", "synth_brass"), ("STAB", "stoot", "synth_brass"),
             ("LEAD", "lead", "fm_lead_helder"), ("PAD", "pad", "synthwave_pad"), ("ARP", "arp", "psg_arp"))
    voices = {}
    for event in events:
        channel = event["channel"]
        if channel in voices:
            continue
        part, sound = next(((part, sound) for word, part, sound in parts if word in channel.upper()), (channel.lower(), "psg_lead"))
        # "FM2_FM3_Chords" is the channel "FM2_FM3", "FM1_Slap_Bass" the channel "FM1"
        info = next((described[name] for name in sorted(described, key=len, reverse=True) if channel.startswith(name)), None)
        voices[channel] = _voice(part, info, sound, f"kanaal {channel}", conversion,
                                 {name: value for name, value in (info or {}).items() if name != "channel_id"})
    voices = _by_part(voices)
    grid = Grid(list(voices), bar_count)
    chords = [{"name": ""} for _bar in range(bar_count)]
    for index, event in enumerate(events):
        where = f"gebeurtenis {index + 1} (maat {event['bar']})"
        notes = event["notes"] if "notes" in event else [event["note"]]
        grid.add(event["bar"], _beat_step(event["beat"], where), event["channel"],
                 _note(notes, float(event["duration_beats"]) * 4.0, event.get("velocity"), articulation=event.get("articulation")))
        if "chord" in event and not chords[event["bar"] - 1]["name"]:
            chords[event["bar"] - 1] = {"name": str(event["chord"]), "voicing": list(event["notes"])}
    drum_grid = data.get("drum_pattern_grid_16th") or {}
    for row_name, row in drum_grid.items():
        upper = row_name.upper()
        if row_name == "legend" or "STAB" in upper or "CHORD" in upper:
            continue    # the stabs' rhythm: the chord events themselves say it
        marks = _grid_row(row)
        if len(marks) != STEPS:
            raise ValueError(f"'drum_pattern_grid_16th.{row_name}' heeft {len(marks)} vakjes in plaats van {STEPS}")
        for step, mark in enumerate(marks, start=1):
            if mark == ".":
                continue
            velocity = ACCENT_VELOCITY if mark.isupper() else PLAIN_VELOCITY
            if "KICK" in upper:
                drum = "KCK"
            elif "SNARE" in upper:
                drum = "SNR"
            elif "CLAP" in upper:
                drum = "CLP"
            else:
                drum = "OHH" if mark in "oO" else "CHH"
            for number in range(1, bar_count + 1):
                grid.add(number, step, "drums", _hit(drum, velocity))
    if drum_grid:
        conversion.choice(f"het drumraster ('drum_pattern_grid_16th', één maat) speelt in elke maat (1-{bar_count}); een "
                          f"geaccentueerde slag (X) is velocity {ACCENT_VELOCITY}, een gewone (x, o) {PLAIN_VELOCITY}")
    if not any("velocity" in event for event in events):
        conversion.choice("de noten hebben geen velocity in het bestand: op volle sterkte (127)")
    sections = _sections_of_bars([{"name": str(section["name"]), "startBar": _bar_range(section["bars"])[0],
                                   "endBar": _bar_range(section["bars"])[1], "id": section.get("section_id", section.get("id"))}
                                  for section in data.get("sections", [])], bar_count, conversion)
    more = {name: value for name, value in data.items() if not isinstance(value, (dict, list)) or name == "inspiration"}
    for name in ("title", "tempo_bpm", "bpm", "time_signature", "key", "key_signature"):
        more.pop(name, None)
    return {"metadata": _metadata(data.get("title"), data.get("tempo_bpm", data.get("bpm")), data.get("key_signature", data.get("key")),
                                  bar_count, "patches", more),
            "sections": sections, "synthParameters": voices, "bars": _bars(grid, sections, chords),
            "extra": {name: data[name] for name in ("sound_chip_configuration", "channels", "sections", "drum_pattern_grid_16th")
                      if name in data}}


# ----------------------------------------------------------------------------- patterns per section

## The pattern fields of a section: field -> (the channel of `patches` that plays it, part, the
## sound when that channel has no operators).
PATTERN_TRACKS = {"bassline_pattern_16ths": ("FM1", "bas", "fm_slapbas"),
                  "psg_arpeggio_pattern_16ths": ("PSG1", "arp", "psg_arp"),
                  "fm_acid_line_16ths": ("FM5", "zuur", "fm_lead_zuur")}
LEAD_FIELD = ("lead_melody_notes", "FM3", "lead", "fm_lead_helder")


def from_patterns(data: dict, conversion: Conversion) -> dict:
    """A sketch in patterns: per section its chords per bar, patterns of sixteenths and a melody
    per bar, each a few bars long. A pattern plays in its own section, over and over; a part a
    section has no pattern for is silent there."""
    source_sections = data["sections"]
    sections = [{"name": str(section["name"]), "startBar": _bar_range(section["bars"])[0], "endBar": _bar_range(section["bars"])[1],
                 "id": section.get("id"), "style": section.get("style")} for section in source_sections]
    sections = [{name: value for name, value in section.items() if value is not None} for section in sections]
    bar_count = max(section["endBar"] for section in sections)
    patches = {str(patch.get("channel", "")): patch for patch in data.get("patches", [])}

    def patch_of(channel_prefix: str):
        return next((patch for name, patch in patches.items() if name.startswith(channel_prefix)), None)

    used = [(field, *PATTERN_TRACKS[field]) for field in PATTERN_TRACKS if any(field in section for section in source_sections)]
    if any(LEAD_FIELD[0] in section for section in source_sections):
        used.insert(1, LEAD_FIELD)
    voices = {}
    track_of = {}
    for field, channel_prefix, part, sound in used:
        info = patch_of(channel_prefix)
        track = str(info.get("channel", channel_prefix)) if info else channel_prefix
        track_of[field] = track
        voices[track] = _voice(part, info, sound, f"'patches' {track}", conversion,
                               {name: value for name, value in (info or {}).items() if name != "channel"})
    voices = _by_part(voices)
    grid = Grid(list(voices), bar_count)
    chords = [{"name": ""} for _bar in range(bar_count)]
    for section, source in zip(sections, source_sections):
        first, last = section["startBar"], section["endBar"]
        progression = source.get("chord_progression") or []
        for number in range(first, last + 1):
            if progression:
                entry = progression[(number - first) % len(progression)]
                chords[number - 1] = {"name": str(entry.get("chord", "")), "voicing": list(entry.get("notes", []))}
        for field in PATTERN_TRACKS:
            pattern = source.get(field)
            if not pattern:
                continue
            if len(pattern) % STEPS:
                raise ValueError(f"sectie '{section['name']}': '{field}' heeft {len(pattern)} vakjes, geen heel aantal maten")
            for number in range(first, last + 1):
                for step in range(1, STEPS + 1):
                    cell = pattern[((number - first) * STEPS + step - 1) % len(pattern)]
                    if cell not in (".", "-", HOLD, None, ""):
                        grid.add(number, step, track_of[field], _note([cell], 1))
        melody = source.get(LEAD_FIELD[0]) or []
        for number in range(first, last + 1):
            if melody:
                for event in melody[(number - first) % len(melody)]["events"]:
                    grid.add(number, event["step"], track_of[LEAD_FIELD[0]],
                             _note([event["note"]], event.get("duration_16ths", 1), event.get("velocity"),
                                   articulation=event.get("articulation") if event.get("articulation") != "normal" else None))
        for row_name, row in (source.get("drum_pattern_16ths") or {}).items():
            marks = _grid_row(row)
            if len(marks) % STEPS:
                raise ValueError(f"sectie '{section['name']}': het drumpatroon '{row_name}' heeft {len(marks)} vakjes")
            upper = row_name.upper()
            for number in range(first, last + 1):
                for step in range(1, STEPS + 1):
                    mark = marks[((number - first) * STEPS + step - 1) % len(marks)]
                    if mark == ".":
                        continue
                    drum = "KCK" if "KICK" in upper else "SNR" if "SNARE" in upper else "CLP" if "CLAP" in upper \
                        else ("OHH" if mark in "oO" else "CHH")
                    grid.add(number, step, "drums", _hit(drum, ACCENT_VELOCITY if mark.isupper() else PLAIN_VELOCITY))
        missing = [part for field, _prefix, part, _sound in used if not source.get(field)]
        if not source.get("drum_pattern_16ths"):
            missing.append("drums")
        if missing:
            conversion.lost(f"sectie '{section['name']}' (maat {first}-{last}): het bestand schrijft geen patroon voor "
                            f"{', '.join(missing)}; die zwijgen daar")
    conversion.choice("een patroon (een paar maten lang) speelt in zijn eigen sectie, steeds opnieuw, tot de sectie om is; "
                      "elke noot van een patroon duurt één stap; geen velocity in het bestand: noten op volle sterkte (127), "
                      f"een drumslag met hoofdletter (X, O) {ACCENT_VELOCITY}, met kleine letter (x) {PLAIN_VELOCITY}")
    conversion.lost("de akkoordstoten (FM2) en de tegenstem (FM4): het bestand noemt de akkoorden per maat maar schrijft "
                    "geen ritme voor ze; de akkoorden staan als 'chord' bij de maat, ze klinken niet")
    more = {name: value for name, value in data.items() if not isinstance(value, (dict, list))}
    for name in ("title", "tempo_bpm", "bpm", "time_signature", "key", "key_signature"):
        more.pop(name, None)
    return {"metadata": _metadata(data.get("title"), data.get("bpm", data.get("tempo_bpm")), data.get("key", data.get("key_signature")),
                                  bar_count, "patches", more),
            "sections": sections, "synthParameters": voices, "bars": _bars(grid, sections, chords),
            "extra": {name: data[name] for name in ("hardware_spec", "patches", "sections") if name in data}}


# ----------------------------------------------------------------------------- which form, and the conversion

def _is_usual(data) -> bool:
    return isinstance(data.get("metadata"), dict) and isinstance(data.get("bars"), list)


def _is_patterns(data) -> bool:
    return isinstance(data.get("sections"), list) and any(
        isinstance(section, dict) and any(name.endswith("_16ths") for name in section) for section in data["sections"])


## (name, what it is in Dutch, how to know it, how to convert it); the first that fits.
FORMS = (
    ("tijdlijn", "de tijdlijn (full_track_timeline_<n>_bars)", tijdlijn.is_timeline, from_timeline),
    ("gebeurtenissen", "gebeurtenissen per maat en stap (full_event_timeline)",
     lambda data: isinstance(data.get("full_event_timeline"), list), from_step_events),
    ("tellen", "gebeurtenissen per maat en tel (sequenced_events)",
     lambda data: isinstance(data.get("sequenced_events"), list), from_beat_events),
    ("plat", "de platte vorm (bpm bovenaan, per maat lead/brass/arp/bass/drums)", json_bron.is_flat, from_flat),
    ("gewoon", "de gewone vorm van de tracker (zonder 'synth')", _is_usual, from_usual),
    ("patronen", "een schets in patronen per sectie (..._16ths)", _is_patterns, from_patterns),
)


def form_of(data) -> str:
    """The name of the form the file is in ("standaard", or one of FORMS), "" when unknown."""
    if not isinstance(data, dict):
        return ""
    if standaardvorm.is_standard(data):
        return "standaard"
    return next((name for name, _description, fits, _convert in FORMS if fits(data)), "")


def convert(data) -> tuple:
    """(the composition in the standard form, the name of the form it was in, the Conversion with
    the choices made and what was not carried over). A ValueError (Dutch) when it cannot be done."""
    conversion = Conversion()
    form = form_of(data)
    if not form:
        keys = ", ".join(str(key) for key in data) if isinstance(data, dict) else type(data).__name__
        raise ValueError("onbekende vorm: geen van de vormen die omgezet kunnen worden ("
                         + "; ".join(description for _name, description, _fits, _convert in FORMS)
                         + f").\n  Het bestand heeft: {keys}")
    if form == "standaard":
        return standaardvorm.normalised(data), form, conversion
    converter = next(convert_form for name, _description, _fits, convert_form in FORMS if name == form)
    try:
        result = standaardvorm.normalised(converter(data, conversion))
    except (KeyError, TypeError, IndexError) as error:
        raise ValueError(f"het bestand lijkt op de vorm '{form}' maar is niet compleet: {error!r}")
    wrong = standaardvorm.problems(result)
    if wrong:
        raise ValueError(f"de vorm '{form}' is omgezet maar het resultaat is niet de standaardvorm:\n  " + "\n  ".join(wrong[:40]))
    return result, form, conversion


def _load(path: str):
    if not os.path.isfile(path):
        raise ValueError("het bestand bestaat niet")
    try:
        with open(path, encoding="utf-8") as json_file:
            return json.load(json_file)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError(f"geen geldig JSON ({error})")


def check(paths: list) -> int:
    failed = 0
    for path in paths:
        try:
            wrong = standaardvorm.problems(_load(path))
        except ValueError as error:
            wrong = [str(error)]
        if wrong:
            failed += 1
            print(f"NIET in de standaardvorm: {path}\n  " + "\n  ".join(wrong[:20]))
        else:
            print(f"standaardvorm: {path}")
    return 1 if failed else 0


def main(arguments: list = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("json", nargs="+", help="the composition in JSON (with --controle: one or more)")
    parser.add_argument("--controle", action="store_true", help="only say whether the files are in the standard form")
    options = parser.parse_args(arguments)
    if options.controle:
        return check(options.json)
    if len(options.json) > 2:
        print("naar_standaardvorm: geef één bestand, of een bestand en waar het resultaat heen moet", file=sys.stderr)
        return 2
    source_path = os.path.abspath(options.json[0])
    target_path = os.path.abspath(options.json[1]) if len(options.json) == 2 else source_path
    try:
        data = _load(source_path)
        result, form, conversion = convert(data)
    except ValueError as error:
        print(f"naar_standaardvorm: {source_path}: {error}", file=sys.stderr)
        return 1
    text = standaardvorm.dumps(result)
    with open(source_path, encoding="utf-8") as source_file:
        unchanged = source_file.read() == text
    print(f"bron: {source_path} (vorm: {form})")
    for choice in conversion.choices:
        print("KEUZE: " + choice)
    for lost in conversion.not_carried:
        print("NIET OVERGENOMEN: " + lost)
    metadata = result["metadata"]
    seconds = metadata["totalBars"] * 4 * 60.0 / metadata["bpm"]
    print(f"{metadata['title']}: {metadata['bpm']:g} BPM, {metadata['totalBars']} maten = {seconds:.1f} s, synth \"{metadata['synth']}\"")
    print("noten per spoor: " + ", ".join(f"{track} {count}" for track, count in standaardvorm.note_counts(result).items()))
    if target_path == source_path:
        if unchanged:
            print("al in de standaardvorm, niets veranderd")
            return 0
        if form != "standaard":
            originals = os.path.join(os.path.dirname(source_path), ORIGINALS_FOLDER)
            kept = os.path.join(originals, os.path.basename(source_path))
            if os.path.exists(kept):
                print(f"naar_standaardvorm: {kept} bestaat al (een eerder origineel); haal het weg of geef een ander "
                      "doelbestand op", file=sys.stderr)
                return 1
            os.makedirs(originals, exist_ok=True)
            shutil.copyfile(source_path, kept)
            print(f"origineel bewaard: {kept}")
    with open(target_path, "w", encoding="utf-8") as target_file:
        target_file.write(text)
    print(f"geschreven: {target_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
