"""The house style shared by every piece, so all music is recognisably the same game.

The rules are written down in docs/MUZIEK.md (in Dutch); this module is their code, built on
megadrive.py (the sound chip). What a style IS (tempo, key, chord plans, motif, patches, drum
kit, per-piece variations) lives in a style profile, tools/megadrive/stijlen/<name>.py; the
active one is ACTIVE_STYLE below (or the environment variable ZWERVR_MUZIEK_STIJL). Every
piece has a file of its own that creates a `Song` and composes with the helpers here, reading
its parameters from the profile (PROFILE, piece(), chord(), plan()); render.sh runs them all.

Phrases are written as text, one token per note, `name:sixteenths`:
    "D5:4"    a note                "-:2"  a rest
    "M"       the motif on the chord of the bar it starts in (8 sixteenths); "M^" "M!" its
              variants (the profile's MOTIF_VARIANTS), "M+" / "M-" an octave up / down
    "R:2" "3:2" "5:2" "7:2" "8:2" "9:2"   chord degrees: root, third, fifth, the step of the
              scale below the octave, the octave, the step above the root; roots between A4
              and G#5 (the melody register)
    "^1:4" .. "^7:4"   degrees of the scale of the key (^1 the tonic in the melody register),
              "'" an octave up, "," an octave down ("^5':2", "^7,:4")
    "~" before a note: a bend up into it from a whole tone below (the guitar: "~^5:4")
"""
import importlib
import os
import sys
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loudness  # noqa: E402
import megadrive  # noqa: E402
from megadrive import FmPatch, Track  # noqa: E402

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MUSIC_FOLDER = os.path.join(PROJECT, "assets", "audio", "muziek")

## The active style profile (tools/megadrive/stijlen/<name>.py).
ACTIVE_STYLE = os.environ.get("ZWERVR_MUZIEK_STIJL", "synthwave_rpg")
PROFILE = importlib.import_module("stijlen." + ACTIVE_STYLE)

NOTE_NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
SCALES = {
    "minor": (0, 2, 3, 5, 7, 8, 10), "major": (0, 2, 4, 5, 7, 9, 11), "dorian": (0, 2, 3, 5, 7, 9, 10),
    "harmonic_minor": (0, 2, 3, 5, 7, 8, 11), "phrygian": (0, 1, 3, 5, 7, 8, 10), "mixolydian": (0, 2, 4, 5, 7, 9, 10),
}
CHORD_SHAPES = {
    "m": (0, 3, 7), "maj": (0, 4, 7), "m7": (0, 3, 7, 10), "m9": (0, 3, 7, 10, 14), "maj7": (0, 4, 7, 11),
    "6": (0, 4, 7, 9), "7": (0, 4, 7, 10), "sus": (0, 5, 7), "7sus": (0, 5, 7, 10), "m7b5": (0, 3, 6, 10),
    "add9": (0, 4, 7, 14), "5": (0, 7),
}
ROMANS = {"I": 0, "II": 1, "III": 2, "IV": 3, "V": 4, "VI": 5, "VII": 6}

KEY_CLASS = NOTE_NAMES[PROFILE.KEY]
SCALE = SCALES[PROFILE.MODE]
SCALE_CLASSES = {(KEY_CLASS + interval) % 12 for interval in SCALE}
MELODY_LOWEST = 69      # A4: roots of the melody register between A4 and G#5
TONIC = MELODY_LOWEST + (KEY_CLASS - MELODY_LOWEST) % 12


def midi(name: str) -> int:
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE_NAMES[pitch]


def scale_note(token: str) -> int:
    """A scale degree of the key in the melody register: "^5", "^1'" (an octave up), "^7,"."""
    degree = int(token[1])
    octave = token.count("'") - token.count(",")
    return TONIC + SCALE[degree - 1] + 12 * octave


class Chord:
    """A chord from an absolute label ("D m", "Bb maj7") or a Roman numeral in the key of the
    profile ("i", "VI", "V7", "VIIsus", "bII"), with the voicings the style uses."""

    def __init__(self, label: str) -> None:
        self.label = label
        if " " in label:
            root_name, shape = label.split()
            self.root_class = NOTE_NAMES[root_name]
        else:
            self.root_class, shape = _roman(label)
        self.intervals = CHORD_SHAPES[shape]
        self.is_minor = len(self.intervals) > 1 and self.intervals[1] == 3
        self.pitch_classes = {(self.root_class + interval) % 12 for interval in self.intervals}
        self.bass_root = 33 + (self.root_class - 9) % 12                               # A1 .. G#2
        self.melody_root = MELODY_LOWEST + (self.root_class - MELODY_LOWEST) % 12       # A4 .. G#5
        self.power_root = 40 + (self.root_class - 4) % 12                               # E2 .. D#3

    @property
    def third(self) -> int:
        for interval in self.intervals[1:]:
            if interval in (3, 4):
                return interval
        return 4 if (self.root_class + 4) % 12 in SCALE_CLASSES else 3

    @property
    def fifth(self) -> int:
        return 6 if 6 in self.intervals else 7

    def _scale_classes(self) -> set:
        """The scale of the key, with this chord's own notes where they differ (the C# of A)."""
        classes = set(SCALE_CLASSES)
        for pitch_class in sorted(self.pitch_classes - SCALE_CLASSES):
            # a chord note outside the scale takes the place of a scale note a semitone from
            # it: the one whose loss leaves the fewest semitone steps (the lower one if equal:
            # the raised leading tone, the C# of A in D minor)
            best = None
            for neighbour in ((pitch_class - 1) % 12, (pitch_class + 1) % 12):
                if neighbour not in classes or neighbour in self.pitch_classes:
                    continue
                trial = (classes - {neighbour}) | {pitch_class}
                semitones = sum(1 for note in trial if (note + 1) % 12 in trial)
                if best is None or semitones < best[0]:
                    best = (semitones, neighbour)
            if best is not None:
                classes.discard(best[1])
            classes.add(pitch_class)
        return classes

    def step_above(self, note: int) -> int:
        classes = self._scale_classes()
        candidate = note + 1
        while candidate % 12 not in classes:
            candidate += 1
        return candidate

    def step_below(self, note: int) -> int:
        classes = self._scale_classes()
        candidate = note - 1
        while candidate % 12 not in classes:
            candidate -= 1
        return candidate

    def melody_degree(self, token: str) -> int:
        octave = token.count("'") - token.count(",")
        degree = token.strip("',")
        root = self.melody_root
        offsets = {"R": root, "3": root + self.third, "5": root + self.fifth, "8": root + 12,
                   "7": self.step_below(root + 12), "9": self.step_above(root)}
        return offsets[degree] + 12 * octave

    def bass_note(self, degree: str) -> int:
        seventh = self.step_below(self.bass_root + 12) - self.bass_root
        offsets = {"R": 0, "O": 12, "3": self.third, "5": self.fifth, "7": seventh, "-5": self.fifth - 12,
                   "9": self.step_above(self.bass_root) - self.bass_root}
        return self.bass_root + offsets[degree]

    def arpeggio_notes(self, octave: int = 0) -> list:
        """Root, third, fifth and octave from the melody root (over Dm: D5 F5 A5 D6)."""
        root = self.melody_root + 12 * octave
        third = self.third if 3 in self.intervals or 4 in self.intervals else self.intervals[1]
        return [root, root + third, root + self.fifth, root + 12]

    def dyad(self, lowest: int = 62) -> list:
        """The two FM voices of a chord (brass, pad): its third and fifth (a sus chord its
        fourth and fifth) between D4 and C#5, or a seventh in place of the fifth on 7 chords."""
        upper = self.intervals[1] if len(self.intervals) > 1 else 7
        top = self.intervals[3] if len(self.intervals) > 3 and self.intervals[3] in (10, 11) else self.fifth
        return sorted(lowest + (self.root_class + interval - lowest) % 12 for interval in (upper, top))

    def tone_below(self, note: int, minimum_gap: int = 3) -> int:
        """The highest chord tone at least `minimum_gap` semitones under a melody note."""
        candidate = note - minimum_gap
        while candidate % 12 not in self.pitch_classes:
            candidate -= 1
        return candidate

    def third_below(self, note: int) -> int:
        """The note a third under `note` in the scale (with this chord's notes): the second
        guitar, harmonized in thirds."""
        return self.step_below(self.step_below(note))


def _roman(label: str):
    accidental = 0
    text = label
    while text and text[0] in "b#":
        accidental += -1 if text[0] == "b" else 1
        text = text[1:]
    numeral = ""
    while text and text[0].upper() in "IV":
        numeral += text[0]
        text = text[1:]
    degree = ROMANS[numeral.upper()]
    root_class = (KEY_CLASS + SCALE[degree] + accidental) % 12
    minor = numeral.islower()
    suffix = text
    if suffix == "":
        shape = "m" if minor else "maj"
    elif suffix == "7":
        shape = "m7" if minor else "7"
    elif suffix in ("maj7", "add9", "sus", "7sus", "m7b5", "5", "6", "m9"):
        shape = suffix
    elif suffix == "o":
        shape = "m7b5"
    else:
        raise ValueError(f"chord {label}: unknown suffix {suffix}")
    return root_class, shape


def chord(label: str) -> Chord:
    return Chord(label)


def chords(labels) -> list:
    return [Chord(label) for label in labels]


def plan(sections) -> list:
    """A plan of the profile ([(name, [romans])]) as [(name, first bar, [Chord])]."""
    result = []
    bar = 0
    for name, labels in sections:
        result.append((name, bar, chords(labels)))
        bar += len(labels)
    return result


def plan_bars(sections) -> int:
    return sum(len(labels) for _, labels in sections)


def piece(name: str) -> dict:
    """The settings of a piece in the profile (PIECES), with defaults."""
    settings = {"swing": 0.0, "energy": 0.8, "bass": "solid", "guitar": True}
    settings.update(PROFILE.PIECES.get(name, {}))
    return settings


def tempo(kind: str) -> float:
    return PROFILE.TEMPOS[kind]


def motif_notes(on_chord: Chord, variant: str = "", octave: int = 0) -> list:
    """The motif of the profile on a chord (over Dm in synthwave_rpg: D5 A5 D6 C6)."""
    return [on_chord.melody_degree(degree) + 12 * octave for degree in PROFILE.MOTIF_VARIANTS[variant]]


@dataclass
class Note:
    step: int           # sixteenths from the start of the phrase
    length: int         # sixteenths
    pitch: int
    motif: bool = False
    articulation: float = 0.9
    bend: bool = False


def phrase(text: str, bar_chords) -> list:
    """Parses a phrase (see the module docstring) against one chord per bar."""
    notes = []
    step = 0
    for token in text.split():
        bar_chord = bar_chords[min(step // 16, len(bar_chords) - 1)]
        if token.startswith("M"):
            octave = 1 if "+" in token else (-1 if token.endswith("-") else 0)
            variant = "^" if "^" in token else ("!" if "!" in token else "")
            pitches = motif_notes(bar_chord, variant, octave)
            for pitch, steps_long, articulation in zip(pitches, PROFILE.MOTIF_RHYTHM, PROFILE.MOTIF_ARTICULATION):
                notes.append(Note(step, steps_long, pitch, True, articulation))
                step += steps_long
            continue
        name, length_text = token.split(":")
        length = int(length_text)
        bend = name.startswith("~")
        name = name.lstrip("~")
        if name != "-":
            if name.startswith("^"):
                pitch = scale_note(name)
            elif name.strip("',") in ("R", "3", "5", "7", "8", "9"):
                pitch = bar_chord.melody_degree(name)
            else:
                pitch = midi(name)
            notes.append(Note(step, length, pitch, False, 0.92 if length > 1 else 0.75, bend))
        step += length
    return notes


def phrase_length(text: str) -> int:
    motif_steps = sum(PROFILE.MOTIF_RHYTHM)
    return sum(motif_steps if token.startswith("M") else int(token.split(":")[1]) for token in text.split())


# ----------------------------------------------------------------------------- the instruments

PATCHES = PROFILE.PATCHES
SIGNATURE: FmPatch = PATCHES[PROFILE.SIGNATURE]
LEAD = SIGNATURE
GUITAR = PATCHES.get("guitar", SIGNATURE)
POWER_CHORD = PATCHES.get("power", GUITAR)
SOLID_BASS = PATCHES.get("solid_bass")
SLAP_BASS = PATCHES.get("slap_bass", SOLID_BASS)
SYNTH_BASS = SOLID_BASS
BRASS = PATCHES["brass"]
BRASS_STAB = PATCHES["brass_stab"]
PAD = PATCHES["pad"]
BELL = PATCHES["bell"]
CHIME = PATCHES.get("chime", BELL)
PLUCK = PATCHES.get("pluck", BELL)
FM_SNARE = PATCHES.get("fm_snare")
METAL = PATCHES.get("metal", BELL)

KICK = megadrive.make_tight_kick() if PROFILE.DRUMS.get("kick") == "tight" else megadrive.make_kick()
FAT_KICK = megadrive.make_kick()
SNARE = (megadrive.make_gated_snare(PROFILE.DRUMS.get("gate_seconds", 0.17))
         if PROFILE.DRUMS.get("snare") == "gated" else megadrive.make_snare())
PLAIN_SNARE = megadrive.make_snare()
CLAP = megadrive.make_clap()
TOMS = [megadrive.make_tom(frequency) for frequency in (210.0, 165.0, 125.0)]

BASS_GROOVES = {
    # (step, length in sixteenths, chord degree, velocity); degrees R, O (octave), 3, 5, 7, 9, -5
    # the solid bass: sixteenths on the root, jumping to the octave, accents on the beats
    "solid": [(step, 1, "O" if step in (2, 6, 10, 13, 14) else "R",
               1.0 if step % 4 == 0 else (0.85 if step % 2 == 0 else 0.6)) for step in range(16)],
    "solid_turn": [(step, 1, "O" if step in (2, 6, 10) else ("5" if step == 13 else ("7" if step == 14 else ("O" if step == 15 else "R"))),
                    1.0 if step % 4 == 0 else (0.85 if step % 2 == 0 else 0.6)) for step in range(16)],
    "slap": [(0, 2, "R", 1.0), (2, 1, "R", 0.45), (3, 1, "O", 0.9), (5, 1, "R", 0.5), (6, 2, "7", 0.85),
             (8, 1, "R", 1.0), (10, 1, "O", 0.9), (11, 1, "R", 0.5), (12, 2, "5", 0.8), (14, 1, "O", 0.9),
             (15, 1, "7", 0.7)],
    "drive": [(step, 1, "R", 1.0 if step % 4 == 0 else 0.75) for step in range(16)],
    "gallop": [(step, 1 if step % 4 else 2, "O" if step % 8 == 6 else "R", 1.0 if step % 4 == 0 else 0.7)
               for step in (0, 2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15)],
    "offbeat": [(step, 2, "R" if step % 8 == 2 else "O", 0.9) for step in (2, 6, 10, 14)],
    "pulse": [(step, 1, "R", 0.9 if step % 4 == 0 else 0.7) for step in range(0, 16, 2)],
    "lyrical": [(0, 3, "R", 1.0), (3, 1, "R", 0.5), (4, 2, "O", 0.85), (6, 1, "R", 0.6), (7, 2, "7", 0.8),
                (10, 2, "R", 0.9), (12, 1, "O", 0.85), (13, 1, "5", 0.6), (14, 2, "3", 0.8)],
    "walking": [(0, 3, "R", 1.0), (4, 3, "3", 0.85), (8, 3, "5", 0.9), (12, 2, "O", 0.8), (14, 2, "5", 0.7)],
    "syncopated": [(0, 2, "R", 1.0), (3, 1, "R", 0.7), (6, 2, "O", 0.9), (10, 1, "R", 0.8), (11, 1, "O", 0.7),
                   (12, 2, "5", 0.85), (14, 1, "7", 0.75), (15, 1, "O", 0.8)],
    "hold": [(0, 12, "R", 0.85), (12, 2, "5", 0.6), (14, 2, "O", 0.7)],
    "whole": [(0, 15, "R", 0.85)],
}
BASS_PATCHES = {"solid": "solid_bass", "solid_turn": "solid_bass", "drive": "solid_bass", "gallop": "solid_bass",
                "offbeat": "solid_bass", "pulse": "solid_bass", "slap": "slap_bass", "lyrical": "slap_bass",
                "walking": "slap_bass", "syncopated": "solid_bass", "hold": "solid_bass", "whole": "solid_bass"}


# ----------------------------------------------------------------------------- the song


class Song:
    """A piece: tempo, length, the house tracks and the helpers to put notes on its grid.
    Loops wrap everything that rings past the end onto the start; one-shots stop there.
    The tracks are the chip's voices: five FM (bass, lead, guitar, harmony and the chords of
    brass and pad, which take turns), the DAC drums (pcm), three PSG squares and the noise."""

    def __init__(self, file_name: str, bpm: float, bars: int, loop: bool = True, swing: float = 0.0,
                 seconds: float = None) -> None:
        self.file_name = file_name
        self.bpm = bpm
        self.step = 60.0 / bpm / 4
        self.bar_seconds = self.step * 16
        self.bars = bars
        self.loop = loop
        self.swing = swing
        self.seconds = seconds if seconds is not None else self.bar_seconds * bars
        self.tape_stops = []
        sample_count = int(round(self.seconds * megadrive.SAMPLE_RATE))

        def track(name, pan, gain):
            return Track(name, sample_count, pan=pan, gain=gain, wrap=loop)

        # one mix for every piece (Mega Drive style panning, a little softer for headphones)
        self.bass = track("bass", 0.0, 0.6)
        self.lead = track("lead", 0.05, 0.58)
        self.guitar = track("guitar", -0.4, 0.32)
        self.harmony = track("harmony", 0.4, 0.32)
        self.brass = track("brass", 0.5, 0.62)
        self.pad = track("pad", -0.45, 0.6)
        self.psg_one = track("psg 1", 0.35, 0.2)
        self.psg_two = track("psg 2", -0.35, 0.19)
        self.psg_three = track("psg 3", 0.15, 0.2)
        self.noise = track("psg noise", 0.2, 0.3)
        self.pcm = track("pcm drums", 0.0, 0.7)
        self.fm_drums = track("fm drums", 0.0, 0.25)
        self.tracks = [self.bass, self.lead, self.guitar, self.harmony, self.brass, self.pad, self.psg_one,
                       self.psg_two, self.psg_three, self.noise, self.pcm, self.fm_drums]

    def at(self, bar: int, step: float = 0) -> float:
        """Seconds from the start, with the swing on odd sixteenths."""
        late = self.swing * self.step if step == int(step) and int(step) % 2 == 1 else 0.0
        return bar * self.bar_seconds + step * self.step + late

    def sixteenths(self, count: float) -> float:
        return round(count * self.step, 4)

    def tape_stop(self, bar: int, step: float, seconds: float) -> None:
        """The mix slows down to a standstill from here (see megadrive.tape_stop)."""
        self.tape_stops.append((self.at(bar, step), seconds))

    def render(self, target_rms_db: float = -14.0, peak_db: float = -1.5, fade_out: float = 0.0,
               low_pass_hz: float = 11000.0) -> None:
        if os.environ.get("ZWERVR_MUZIEK_SPOREN"):
            # the balance of the mix: every track's level (with its gain) against the loudest
            levels = {track.name: 20 * megadrive.numpy.log10(megadrive.numpy.sqrt(megadrive.numpy.mean(
                (track.buffer * track.gain) ** 2)) + 1e-9) for track in self.tracks}
            loudest = max(levels.values())
            print("  sporen: " + ", ".join(f"{name} {level - loudest:+.1f}" for name, level in levels.items() if level > -150))
        stereo = megadrive.master(self.tracks, target_rms_db=target_rms_db, peak_db=peak_db, low_pass_hz=low_pass_hz)
        for at_seconds, seconds in self.tape_stops:
            stereo = megadrive.tape_stop(stereo, at_seconds, seconds)
        if not self.loop:   # the filtering smears a hit at 0 a hair backwards: start from silence
            fade_in_samples = int(0.003 * megadrive.SAMPLE_RATE)
            stereo[:fade_in_samples] *= megadrive.numpy.linspace(0.0, 1.0, fade_in_samples)[:, None]
        if fade_out and not self.loop:
            fade_samples = int(fade_out * megadrive.SAMPLE_RATE)
            fade = megadrive.numpy.linspace(1.0, 0.0, fade_samples) ** 2
            stereo[-fade_samples:] *= fade[:, None]
        # target_rms_db only sets how hard the mix hits the limiter (the density); every file
        # ends at one loudness (loudness.py), so the game alone decides how loud a piece plays
        stereo = loudness.level(stereo, one_shot=False, ceiling_db=peak_db)
        target = os.path.join(MUSIC_FOLDER, self.file_name)
        megadrive.write_ogg(target, stereo)
        print(f"written: {target}  ({self.bars} bars at {self.bpm:g} BPM, {self.seconds:.2f} s"
              f"{', loop' if self.loop else ''}, style {ACTIVE_STYLE})")


# ----------------------------------------------------------------------------- composing helpers


def lead(song: Song, first_bar: int, text: str, bar_chords, velocity: float = 1.0, echo: bool = False,
         harmony: bool = False, slides: bool = False, octave: int = 0, patch: FmPatch = None,
         track: Track = None, thirds: Track = None) -> None:
    """A melody on an FM voice (the signature voice unless `patch`). `echo`: the PSG plays it
    again three sixteenths later (the one-channel echo); `harmony`: the PSG a chord tone under
    every note; `thirds`: a second FM voice on that track a third below (the twin guitars);
    `slides`: small steps glide; "~" notes bend up a whole tone."""
    patch = patch or SIGNATURE
    track = track or song.lead
    total_steps = phrase_length(text)
    if total_steps != 16 * len(bar_chords):
        raise ValueError(f"phrase is {total_steps} sixteenths, its {len(bar_chords)} bars need {16 * len(bar_chords)}")
    previous_pitch = None
    for note in phrase(text, bar_chords):
        bar_offset, step_in_bar = divmod(note.step, 16)
        bar_chord = bar_chords[min(bar_offset, len(bar_chords) - 1)]
        start = song.at(first_bar + bar_offset, step_in_bar)
        length = song.sixteenths(note.length * note.articulation)
        pitch = note.pitch + 12 * octave
        slide = None
        slide_time = 0.05
        if note.bend:
            slide = float(pitch - 2)
            slide_time = min(0.18, length * 0.5)
        elif slides and not note.motif and previous_pitch is not None and 0 < abs(previous_pitch - pitch) <= 3:
            slide = float(previous_pitch)
        accent = velocity if note.motif else velocity * 0.92
        track.add(start, megadrive.fm_note(patch, float(pitch), length, round(accent, 3), slide, slide_time))
        if thirds is not None:
            below = bar_chord.third_below(pitch)
            thirds.add(start, megadrive.fm_note(patch, float(below), length, round(accent * 0.85, 3),
                                                None if slide is None else float(slide - (pitch - below)), slide_time))
        if harmony:
            song.psg_two.add(start, megadrive.psg_square(bar_chord.tone_below(pitch), length, 0.8, decay=0.4, sustain=0.6))
        if echo:
            song.psg_two.add(start + 3 * song.step, megadrive.psg_square(pitch, length, 0.55, decay=0.12, sustain=0.4))
        previous_pitch = pitch


def guitar(song: Song, first_bar: int, text: str, bar_chords, velocity: float = 1.0, twin: bool = False,
           octave: int = 0, echo: bool = False) -> None:
    """The lead guitar (an overdriven FM voice) with bends and vibrato; `twin`: the second
    guitar a third below on the harmony track; `echo`: a tape delay on the other side."""
    lead(song, first_bar, text, bar_chords, velocity, patch=GUITAR, track=song.guitar, octave=octave,
         thirds=song.harmony if twin else None, slides=True)
    if echo:
        for note in phrase(text, bar_chords):
            bar_offset, step_in_bar = divmod(note.step, 16)
            start = song.at(first_bar + bar_offset, step_in_bar) + 6 * song.step
            song.harmony.add(start, megadrive.fm_note(GUITAR, float(note.pitch + 12 * octave),
                                                      song.sixteenths(note.length * 0.8), round(velocity * 0.4, 3)))


def chip_lead(song: Song, first_bar: int, text: str, bar_chords, volume: float = 0.85, octave: int = 0,
              track: Track = None, vibrato: float = 0.28) -> None:
    """The square-wave chiptune lead on the PSG: a fast driver vibrato, short and bright."""
    track = track or song.psg_one
    total_steps = phrase_length(text)
    if total_steps != 16 * len(bar_chords):
        raise ValueError(f"chip phrase is {total_steps} sixteenths, its {len(bar_chords)} bars need {16 * len(bar_chords)}")
    for note in phrase(text, bar_chords):
        bar_offset, step_in_bar = divmod(note.step, 16)
        length = song.sixteenths(note.length * (0.85 if note.length > 1 else 0.7))
        track.add(song.at(first_bar + bar_offset, step_in_bar),
                  megadrive.psg_square(float(note.pitch + 12 * octave), length, volume, decay=0.25, sustain=0.65,
                                       vibrato_depth=vibrato if note.length >= 2 else 0.0))


def bass_bar(song: Song, bar: int, on_chord: Chord, groove: str, patch: FmPatch = None,
             velocity: float = 1.0, until_step: int = 16) -> None:
    patch = patch or PATCHES[BASS_PATCHES.get(groove, "solid_bass")]
    for step, steps_long, degree, note_velocity in BASS_GROOVES[groove]:
        if step >= until_step:
            continue
        song.bass.add(song.at(bar, step), megadrive.fm_note(patch, float(on_chord.bass_note(degree)),
                                                              song.sixteenths(steps_long * 0.85),
                                                              round(note_velocity * velocity, 3)))


POWER_RHYTHMS = {
    "held": [(0, 15, 1.0)],
    "anthem": [(0, 3, 1.0), (3, 3, 0.9), (6, 4, 0.95), (10, 2, 0.85), (12, 4, 0.95)],
    "chug": [(step, 1, 0.9 if step % 4 == 0 else 0.65) for step in range(0, 16, 2)],
    "hits": [(0, 2, 1.0), (6, 2, 0.9), (12, 3, 0.95)],
    "push": [(0, 6, 1.0), (6, 2, 0.8), (8, 6, 0.95), (14, 2, 0.8)],
}


def power_chords(song: Song, bar: int, on_chord: Chord, rhythm: str = "anthem", velocity: float = 0.9) -> None:
    """Distorted power chords (one FM voice: root, fifth and octave in its operators)."""
    for step, steps_long, hit_velocity in POWER_RHYTHMS[rhythm]:
        length = song.sixteenths(steps_long * (0.55 if rhythm == "chug" else 0.92))
        song.guitar.add(song.at(bar, step), megadrive.fm_note(POWER_CHORD, float(on_chord.power_root), length,
                                                               round(hit_velocity * velocity, 3)))


def brass_stabs(song: Song, bar: int, on_chord: Chord, hits=((4, 1), (12, 1)), velocity: float = 0.9) -> None:
    """Staccato brass on two FM voices; hits (step, sixteenths), by default on 2 and 4; a
    negative step is an anticipation in the bar before."""
    for step, steps_long in hits:
        start = song.at(bar, step) if step >= 0 else bar * song.bar_seconds + step * song.step
        song.brass.add(start, megadrive.fm_chord(BRASS_STAB, on_chord.dyad(), song.sixteenths(steps_long * 0.85), velocity))


def brass_pad(song: Song, bar: int, on_chord: Chord, bars: float = 1, velocity: float = 0.8) -> None:
    song.brass.add(song.at(bar), megadrive.fm_chord(BRASS, [note + 12 for note in on_chord.dyad()],
                                                     song.sixteenths(16 * bars * 0.96), velocity))


def pad(song: Song, bar: int, on_chord: Chord, bars: float = 1, velocity: float = 0.85, octave: int = 0) -> None:
    """The warm two-voice pad."""
    song.pad.add(song.at(bar), megadrive.fm_chord(PAD, [note + 12 * octave for note in on_chord.dyad()],
                                                  song.sixteenths(16 * bars * 0.97), velocity))


ARPEGGIO_PATTERNS = {
    "up": [0, 1, 2, 3] * 4,
    "updown": [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3],
    "down": [3, 2, 1, 0] * 4,
    "rolling": [0, 2, 1, 3, 0, 2, 1, 3, 2, 3, 1, 2, 0, 1, 2, 3],
}


def arpeggio(song: Song, bar: int, on_chord: Chord, pattern: str = "up", volume: float = 0.7,
             every: int = 1, octave: int = 0, track: Track = None, from_step: int = 0, until_step: int = 16) -> None:
    """The fast PSG arpeggio in sixteenths (over Dm: D5 F5 A5 D6); "twinkle": sparse high notes."""
    track = track or song.psg_one
    notes = on_chord.arpeggio_notes(octave)
    if pattern == "twinkle":
        for step in range(from_step, until_step, 2):
            note = notes[(step // 2 * 3) % 4] + 12
            track.add(song.at(bar, step), megadrive.psg_square(note, song.sixteenths(1.5), volume, decay=0.12,
                                                               sustain=0.0, release=0.1))
        return
    order = ARPEGGIO_PATTERNS[pattern]
    for step in range(from_step, until_step, every):
        track.add(song.at(bar, step), megadrive.psg_square(notes[order[step]], song.sixteenths(0.7 * every), volume,
                                                           decay=0.05, sustain=0.25, release=0.03))


def pluck_chord(song: Song, bar: int, on_chord: Chord, steps=(0, 3, 6, 8, 11, 14), velocity: float = 0.7,
                track: Track = None) -> None:
    """A plucked chord, strummed (the notes of the arpeggio one after the other)."""
    track = track or song.pad
    for index, step in enumerate(steps):
        note = on_chord.arpeggio_notes(-1)[index % 4]
        track.add(song.at(bar, step), megadrive.fm_note(PLUCK, float(note), song.sixteenths(2.5), velocity))


def bells(song: Song, bar: int, pitches, steps, velocity: float = 0.6, track: Track = None, patch: FmPatch = None) -> None:
    track = track or song.pad
    for pitch, step in zip(pitches, steps):
        track.add(song.at(bar, step), megadrive.fm_note(patch or BELL, float(pitch), song.sixteenths(4), velocity))


def crash(song: Song, bar: int, step: float = 0, volume: float = 1.0) -> None:
    song.noise.add(song.at(bar, step), megadrive.psg_noise(1.6, volume, 26000.0, 0.55, 99))


KICK_PATTERNS = {"four": (0, 4, 8, 12), "push": (0, 4, 8, 12, 14), "rock": (0, 8, 10), "drive": (0, 6, 8, 10),
                 "broken": (0, 7, 10), "half": (0, 10), "gallop": (0, 3, 4, 8, 11, 12), "one": (0,), "none": ()}
SNARE_PATTERNS = {"backbeat": (4, 12), "half": (8,), "none": ()}


def drum_bar(song: Song, bar: int, kick: str = "four", snare: str = "backbeat", clap: bool = False,
             hats: str = "sixteenths", fill: str = None, ghosts: bool = True, velocity: float = 1.0,
             hat_volume: float = 1.0, fm_snare: bool = False) -> None:
    """One bar of drums. hats: sixteenths, eighths, open (off-beats), double (sixteenths with
    a rattle of thirty-seconds at the end of every beat), none.
    fill: snare (last beat), tom (toms back to the one), roll (16ths, building), drop (silence
    on the last beat). `fm_snare`: the metallic FM layer over the snare."""
    cut_at = 12 if fill in ("snare", "tom", "drop") else 16
    if fill == "roll":
        cut_at = 0
    for step in KICK_PATTERNS[kick]:
        if step < cut_at or fill == "roll":
            song.pcm.add(song.at(bar, step), KICK, velocity * (1.0 if step % 4 == 0 else 0.7))
    for step in SNARE_PATTERNS[snare]:
        if step < cut_at:
            song.pcm.add(song.at(bar, step), SNARE, 0.85 * velocity)
            if clap:
                song.pcm.add(song.at(bar, step), CLAP, 0.55 * velocity)
            if fm_snare and FM_SNARE is not None:
                song.fm_drums.add(song.at(bar, step), megadrive.fm_note(FM_SNARE, 55.0, 0.08, velocity))
    if clap and snare == "none":
        for step in (4, 12):
            if step < cut_at:
                song.pcm.add(song.at(bar, step), CLAP, 0.85 * velocity)
    if ghosts and fill is None and snare != "none":
        song.pcm.add(song.at(bar, 15), PLAIN_SNARE, 0.2 * velocity)
        if bar % 2 == 1:
            song.pcm.add(song.at(bar, 7), PLAIN_SNARE, 0.16 * velocity)

    if hats != "none":
        for step in range(min(cut_at, 16) if fill != "roll" else 16):
            offbeat = step % 4 == 2
            if hats == "open" and offbeat:
                song.noise.add(song.at(bar, step), megadrive.psg_noise(0.2, 0.9 * hat_volume, 30000.0, 0.09, step))
            elif hats in ("sixteenths", "open", "double") or (hats == "eighths" and step % 2 == 0):
                hat_level = 0.75 if offbeat else (0.45 if step % 2 == 0 else 0.3)
                song.noise.add(song.at(bar, step), megadrive.psg_noise(0.05, hat_level * hat_volume, 32000.0, 0.018, step * 7))
                if hats == "double" and step % 4 == 3:
                    song.noise.add(song.at(bar, step + 0.5), megadrive.psg_noise(0.04, 0.4 * hat_volume, 32000.0, 0.012, step * 11))

    if fill == "snare":
        for step, fill_velocity in ((12, 0.6), (13, 0.5), (14, 0.8), (15, 0.95)):
            song.pcm.add(song.at(bar, step), SNARE if step >= 14 else PLAIN_SNARE, fill_velocity * velocity)
    elif fill == "tom":
        for step, tom_index, fill_velocity in ((12, 0, 0.9), (13, 1, 0.85), (14, 2, 0.95), (15, 2, 0.8)):
            song.pcm.add(song.at(bar, step), TOMS[tom_index], fill_velocity * velocity)
        song.pcm.add(song.at(bar, 12), PLAIN_SNARE, 0.5 * velocity)
    elif fill == "roll":
        for step in range(16):
            if step < 8 and step % 2:
                continue
            song.pcm.add(song.at(bar, step), PLAIN_SNARE, (0.2 + 0.75 * step / 15) * velocity)
        song.pcm.add(song.at(bar, 15), SNARE, 0.9 * velocity)


## Drum solos: one bar each, (step, drum, velocity); drum K kick, S snare, C clap, T0..T2 the
## toms high to low, X a crash.
DRUM_SOLOS = {
    "toms_down": [(0, "K", 1.0), (0, "S", 0.9), (2, "T0", 0.8), (3, "T0", 0.6), (4, "T0", 0.9), (5, "T1", 0.7),
                  (6, "T1", 0.85), (7, "T1", 0.6), (8, "K", 0.9), (8, "T1", 0.9), (9, "T2", 0.7), (10, "T2", 0.85),
                  (11, "T2", 0.65), (12, "S", 0.8), (13, "S", 0.6), (14, "T0", 0.9), (15, "T2", 1.0)],
    "accents": [(0, "K", 1.0), (0, "X", 0.6), (3, "S", 0.9), (3, "C", 0.6), (6, "S", 0.9), (6, "C", 0.6),
                (8, "K", 0.9), (10, "S", 0.9), (10, "C", 0.6), (12, "T2", 0.8), (13, "T1", 0.85), (14, "T0", 0.9),
                (15, "T0", 1.0)],
    "roll": [(step * 0.5, "S", 0.25 + 0.75 * step / 31) for step in range(32)] + [(0, "K", 1.0), (8, "K", 0.9)],
}


def drum_solo(song: Song, bar: int, solo: str, velocity: float = 1.0) -> None:
    sounds = {"K": KICK, "S": SNARE, "C": CLAP, "T0": TOMS[0], "T1": TOMS[1], "T2": TOMS[2]}
    for step, drum, hit_velocity in DRUM_SOLOS[solo]:
        if drum == "X":
            crash(song, bar, step, hit_velocity)
        else:
            song.pcm.add(song.at(bar, step), sounds[drum] if drum != "S" else PLAIN_SNARE, hit_velocity * velocity)


def big_hit(song: Song, bar: int, step: float, on_chord: Chord, sixteenths: float) -> None:
    """Everything at once: kick and snare, crash, brass, a power chord, the low bass."""
    song.pcm.add(song.at(bar, step), FAT_KICK)
    song.pcm.add(song.at(bar, step), SNARE, 0.85)
    crash(song, bar, step)
    song.brass.add(song.at(bar, step), megadrive.fm_chord(BRASS, [note + 12 for note in on_chord.dyad()],
                                                          song.sixteenths(sixteenths), 1.0))
    song.guitar.add(song.at(bar, step), megadrive.fm_note(POWER_CHORD, float(on_chord.power_root),
                                                          song.sixteenths(sixteenths), 0.9))
    song.bass.add(song.at(bar, step), megadrive.fm_note(SOLID_BASS, float(on_chord.bass_root),
                                                        song.sixteenths(sixteenths), 1.0))
