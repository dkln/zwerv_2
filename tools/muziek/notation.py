"""The notation a composition file (tools/muziek/composities/<naam>.py) is written in.

A composition is copied bar by bar from the composer's text (a Gemini answer), so the helpers
here read the way such a text writes music: beats counted from 1.0 ("tel 2.5" is the "and" of
beat 2), note names with octave numbers (C4 is middle C), lengths in beats.

    notes("1.0 D5 1.5, 2.5 F5 0.5, 3.0 G5 1.5")       a line of notes: position, pitch, length
    notes("1 D3+F3+A3+D4 4")                         a chord: pitches joined by +
    notes("1 D5 0.5 0.6")                            a fourth number: velocity (0..1, default 1)
    cycle("D2 D2 D3 D2", 0.25)                       a figure repeated through the bar in 16ths
    cycle("Bb1 Bb1 Bb2 Bb1", 0.25, start=1, end=3)   ... over beats 1-2 only
    run("D4 F4 G4 G#4 A4 C5 D5", 0.25, start=2.5)    a figure played once, one step each
    drums(kick="1 2.5 3", snare="2 4", hihat="16", crash="1")
    drum_run("S HT HT MT MT LT S S", 0.25, start=3)  a fill, one drum per step

Drum names: kick, snare, hihat, open (open hi-hat), crash, clap, tom_hoog, tom_mid, tom_laag;
in drum_run: K S HH OH CR CL HT MT LT ("-" a rest). For a drum in drums() the positions are
beats, or: "4" every beat, "8" every eighth, "16" every sixteenth, "off" the "and" of every
beat, "16off" the 2nd and 4th sixteenth of every beat, "16-off" every sixteenth but the "and"
(where an open hi-hat goes).

Chords (the "akkoord" of a bar; two chords in one bar split it in halves: "Bb A7"):
root (C, C#, Db, ... B) and a quality: "" m 5 6 m6 7 m7 maj7 9 m9 maj9 add9 sus2 sus4 7sus4
dim m7b5 aug; "Asus4->A7" and "Asus4 -> A7" are read as "Asus4 A7".
"""
from dataclasses import dataclass, replace

NOTE_CLASSES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
CHORD_QUALITIES = {
    "": (0, 4, 7), "m": (0, 3, 7), "5": (0, 7), "6": (0, 4, 7, 9), "m6": (0, 3, 7, 9),
    "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11), "9": (0, 4, 7, 10, 14),
    "m9": (0, 3, 7, 10, 14), "maj9": (0, 4, 7, 11, 14), "add9": (0, 4, 7, 14), "sus2": (0, 2, 7),
    "sus4": (0, 5, 7), "7sus4": (0, 5, 7, 10), "dim": (0, 3, 6), "m7b5": (0, 3, 6, 10), "aug": (0, 4, 8),
}
DRUM_SHORT_NAMES = {"K": "kick", "S": "snare", "HH": "hihat", "OH": "open", "CR": "crash", "CL": "clap",
                    "HT": "tom_hoog", "MT": "tom_mid", "LT": "tom_laag"}
DRUM_NAMES = set(DRUM_SHORT_NAMES.values())


@dataclass(frozen=True)
class Note:
    """One note (or chord: several pitches struck together) in a bar: `position` in beats from
    1.0, `length` in beats, MIDI pitches."""
    position: float
    pitches: tuple
    length: float
    velocity: float = 1.0

    def moved(self, beats: float) -> "Note":
        return replace(self, position=self.position + beats)

    def transposed(self, semitones: int) -> "Note":
        return replace(self, pitches=tuple(pitch + semitones for pitch in self.pitches))

    def softer(self, factor: float) -> "Note":
        return replace(self, velocity=self.velocity * factor)


@dataclass(frozen=True)
class Hit:
    """One drum hit: `position` in beats from 1.0, a drum name (DRUM_NAMES)."""
    position: float
    drum: str
    velocity: float = 1.0

    def moved(self, beats: float) -> "Hit":
        return replace(self, position=self.position + beats)


def pitch(name: str) -> int:
    """MIDI number of a note name with octave: "C4" 60, "Bb1" 34, "F#3" 54."""
    name = name.strip()
    note_class = NOTE_CLASSES[name[0].upper()]
    rest = name[1:]
    while rest and rest[0] in "#b":
        note_class += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + note_class


def pitches(text: str) -> tuple:
    return tuple(pitch(part) for part in text.split("+") if part.strip())


def notes(text: str) -> list:
    """"1.0 D5 1.5, 2.5 F5 0.5": position, pitch(es), length in beats, optional velocity."""
    result = []
    for item in text.replace("\n", ",").split(","):
        fields = item.split()
        if not fields:
            continue
        velocity = float(fields[3]) if len(fields) > 3 else 1.0
        result.append(Note(float(fields[0]), pitches(fields[1]), float(fields[2]), velocity))
    return result


def cycle(figure: str, step: float, start: float = 1.0, end: float = 5.0, length: float = None,
          velocity: float = 1.0) -> list:
    """The figure (pitches, "-" a rest) repeated step by step from `start` up to `end`."""
    names = figure.split()
    result = []
    index = 0
    position = start
    while position < end - 1e-6:
        name = names[index % len(names)]
        if name != "-":
            result.append(Note(round(position, 4), pitches(name), length or step, velocity))
        index += 1
        position += step
    return result


def run(figure: str, step: float, start: float = 1.0, length: float = None, velocity: float = 1.0) -> list:
    """The figure played once from `start`, one step per pitch ("-" a rest)."""
    names = figure.split()
    return cycle(figure, step, start, start + step * len(names), length, velocity)


def _drum_positions(spec: str, beats_per_bar: int) -> list:
    if spec in ("4", "8", "16"):
        step = {"4": 1.0, "8": 0.5, "16": 0.25}[spec]
        return [1.0 + index * step for index in range(int(beats_per_bar / step))]
    if spec == "off":
        return [1.5 + beat for beat in range(beats_per_bar)]
    if spec == "16-off":
        return [1.0 + beat + offset for beat in range(beats_per_bar) for offset in (0.0, 0.25, 0.75)]
    if spec == "16off":
        return [1.0 + beat + offset for beat in range(beats_per_bar) for offset in (0.25, 0.75)]
    return [float(position) for position in spec.split()]


def drums(beats_per_bar: int = 4, velocity: float = 1.0, **positions) -> list:
    """Hits per drum: drums(kick="1 2.5 3", snare="2 4", hihat="16", crash="1")."""
    result = []
    for drum, spec in positions.items():
        if drum not in DRUM_NAMES:
            raise ValueError(f"unknown drum {drum!r} (one of {sorted(DRUM_NAMES)})")
        result += [Hit(position, drum, velocity) for position in _drum_positions(str(spec), beats_per_bar)]
    return result


def drum_run(figure: str, step: float, start: float = 1.0, velocity: float = 1.0) -> list:
    """A fill: "S HT HT MT" one drum per step from `start` ("-" a rest)."""
    result = []
    for index, short_name in enumerate(figure.split()):
        if short_name != "-":
            result.append(Hit(round(start + index * step, 4), DRUM_SHORT_NAMES[short_name], velocity))
    return result


def chord_parts(name: str) -> tuple:
    """("D", "m7") for "Dm7"."""
    name = name.strip()
    root_length = 2 if len(name) > 1 and name[1] in "#b" else 1
    return name[:root_length], name[root_length:]


def chord_classes(name: str) -> tuple:
    """The chord's tones as semitones above C (root first, may go past 12 for 9ths)."""
    root, quality = chord_parts(name)
    if quality not in CHORD_QUALITIES:
        raise ValueError(f"unknown chord {name!r}")
    root_class = pitch(root + "0") % 12
    return tuple(root_class + interval for interval in CHORD_QUALITIES[quality])


def bar_chords(text: str, beats_per_bar: int) -> list:
    """"Bb A7" -> [("Bb", 1.0, 2.0), ("A7", 3.0, 2.0)]: the chords of a bar, split evenly."""
    names = text.replace("->", " ").replace("→", " ").split()
    if not names:
        return []
    share = beats_per_bar / len(names)
    return [(chord_name, 1.0 + index * share, share) for index, chord_name in enumerate(names)]


def chord_voicing(name: str, lowest: int) -> tuple:
    """The chord's tones from `lowest` (MIDI) up, in close position, root first."""
    classes = chord_classes(name)
    root = lowest + (classes[0] - lowest) % 12
    return tuple(root + (interval - classes[0]) for interval in classes)
