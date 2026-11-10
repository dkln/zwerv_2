"""The house style shared by every piece, so all music is recognisably the same game.

The rules of the style are written down in docs/MUZIEK.md (in Dutch): sound palette, key and
harmony, the motif, tempos, grooves, form, mix levels, originality, and every piece with where it
plays. Every new piece follows that document; this module is its code.

Built on megadrive.py (the sound chip). Every piece has a file of its own that creates a `Song`
and composes with the helpers here; render.sh runs them all.

Ingredients (the agreement of the project, kept from the earlier generator):
  - key F minor; the heart of the harmony is i - bII - iv (Fm - Gb - Bbm), with Ab and Cm (and
    C7 as the way home) for colour. Dark and tough (the Phrygian bII), energetic, not corny.
  - THE MOTIF: four short, hard notes in two beats, rhythm eighth - sixteenth - sixteenth -
    quarter: root, third, the step above the root, then the fifth below; fitted to every chord
    (`motif_notes`). Over Fm: F5 Ab5 G5 C5. The tough variant ends on the flat seventh.
    It comes back clearly in every piece, always on the signature voice: the FM lead (`LEAD`).
  - the Mega Drive sound in the manner of early-90s 16-bit street-brawler soundtracks: club house
    and new-jack-swing grooves, FM slap or synth bass, FM electric piano and brass, FM strings,
    PSG square arpeggios, echoes and counter-lines, PCM drums (kick, snare, clap, toms) and
    PSG-noise hats and crashes.
  - one mix: the same tracks with the same pans and levels everywhere (`HouseTracks`), hard-ish
    panning per channel as on the console; every file ends at -16 LUFS, peaks under -1.5 dB (loudness.py).

Phrases are written as text, one token per note, `name:sixteenths`:
    "F5:4"   a note          "-:2"  a rest
    "M"      the motif on the chord of the bar it starts in (8 sixteenths)
    "M!"     the tough motif    "M+" / "M-"  the motif an octave up / down
    "R:2" "3:2" "5:2" "9:2" "8:2"  root, third, fifth, step (ninth) and octave of the bar's chord,
             in the melody register (roots between D5 and C#6)
"""
import os
import sys
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loudness  # noqa: E402
import megadrive  # noqa: E402
from megadrive import FmPatch, Operator, Track  # noqa: E402

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MUSIC_FOLDER = os.path.join(PROJECT, "assets", "audio", "muziek")

NOTE_NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}

CHORD_SHAPES = {
    "m": (0, 3, 7), "maj": (0, 4, 7), "m7": (0, 3, 7, 10), "m9": (0, 3, 7, 10, 14),
    "maj7": (0, 4, 7, 11), "6": (0, 4, 7, 9), "7": (0, 4, 7, 10), "sus": (0, 5, 7, 10),
    "m7b5": (0, 3, 6, 10), "add9": (0, 4, 7, 14),
}

MELODY_LOWEST = 74      # D5
MOTIF_STEPS = (2, 1, 1, 4)
MOTIF_ARTICULATION = (0.6, 0.75, 0.75, 0.7)   # short and hard


def midi(name: str) -> int:
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE_NAMES[pitch]


class Chord:
    """A chord from a label like "F m7" or "Gb maj7", with the voicings the style uses."""

    def __init__(self, label: str) -> None:
        root_name, shape = label.split()
        self.label = label
        self.root_class = NOTE_NAMES[root_name]
        self.intervals = CHORD_SHAPES[shape]
        self.is_minor = self.intervals[1] == 3
        self.bass_root = 33 + (self.root_class - 9) % 12                  # between A1 and G#2
        self.melody_root = MELODY_LOWEST + (self.root_class - MELODY_LOWEST) % 12   # D5 .. C#6
        upper = [interval % 12 for interval in self.intervals[:4]]
        self.voicing = sorted(53 + (self.root_class + interval - 5) % 12 for interval in upper)  # F3 .. E4
        if len(self.intervals) > 4:
            self.voicing.append(53 + (self.root_class + 2 - 5) % 12 + 12)
        self.pitch_classes = {(self.root_class + interval) % 12 for interval in self.intervals}

    @property
    def third(self) -> int:
        return self.intervals[1] if self.intervals[1] in (3, 4) else 4

    @property
    def fifth(self) -> int:
        return self.intervals[2]

    def bass_note(self, degree: str) -> int:
        seventh = self.intervals[3] if len(self.intervals) > 3 and self.intervals[3] < 12 else 12
        offsets = {"R": 0, "O": 12, "3": self.third, "5": self.fifth, "7": seventh, "-5": self.fifth - 12}
        return self.bass_root + offsets[degree]

    def melody_degree(self, degree: str) -> int:
        root = self.melody_root
        if degree == "R":
            return root
        if degree == "3":
            return root + self.third
        if degree == "5":
            return root + self.fifth if root + self.fifth <= 85 else root + self.fifth - 12
        if degree == "9":
            return root + self.step
        if degree == "8":
            return root + 12
        raise ValueError(degree)

    @property
    def step(self) -> int:
        return 1 if self.fifth == 6 else 2

    def tone_below(self, note: int, minimum_gap: int = 3) -> int:
        """The highest chord tone at least `minimum_gap` semitones under a melody note."""
        candidate = note - minimum_gap
        while candidate % 12 not in self.pitch_classes:
            candidate -= 1
        return candidate


def chords(labels) -> list:
    return [Chord(label) for label in labels]


def motif_notes(chord: Chord, tough: bool = False, octave: int = 0) -> list:
    """The motif on a chord: root, third, the step above the root, the fifth below
    (tough: the flat seventh below instead, on minor chords). Over Fm: F5 Ab5 G5 C5."""
    root = chord.melody_root + 12 * octave
    ending = root - 2 if tough and chord.is_minor else root - (12 - chord.fifth)
    return [root, root + chord.third, root + chord.step, ending]


@dataclass
class Note:
    step: int           # sixteenths from the start of the phrase
    length: int         # sixteenths
    pitch: int
    motif: bool = False
    articulation: float = 0.9


def phrase(text: str, bar_chords) -> list:
    """Parses a phrase (see the module docstring) against one chord per bar."""
    notes = []
    step = 0
    for token in text.split():
        chord = bar_chords[min(step // 16, len(bar_chords) - 1)]
        if token.startswith("M"):
            octave = 1 if "+" in token else (-1 if token.endswith("-") else 0)
            pitches = motif_notes(chord, tough="!" in token, octave=octave)
            for pitch, steps_long, articulation in zip(pitches, MOTIF_STEPS, MOTIF_ARTICULATION):
                notes.append(Note(step, steps_long, pitch, True, articulation))
                step += steps_long
            continue
        name, length_text = token.split(":")
        length = int(length_text)
        if name != "-":
            pitch = chord.melody_degree(name) if name in ("R", "3", "5", "9", "8") else midi(name)
            notes.append(Note(step, length, pitch, False, 0.9 if length > 1 else 0.75))
        step += length
    return notes


# ----------------------------------------------------------------------------- the instruments

SLAP_BASS = FmPatch("slap bass", algorithm=4, feedback=0.9, operators=(
    Operator(ratio=1.0, level=3.0, attack=0.001, decay=0.06, sustain=0.25, release=0.03, velocity_to_level=0.8),
    Operator(ratio=1.0, level=0.9, attack=0.001, decay=0.5, sustain=0.6, release=0.03),
    Operator(ratio=3.0, level=1.8, attack=0.001, decay=0.02, sustain=0.0, release=0.02, velocity_to_level=0.9),
    Operator(ratio=1.0, detune_cents=4, level=0.5, attack=0.001, decay=0.25, sustain=0.4, release=0.03),
))

SYNTH_BASS = FmPatch("synth bass", algorithm=4, feedback=1.0, operators=(
    Operator(ratio=1.0, level=2.2, attack=0.001, decay=0.12, sustain=0.45, release=0.03, velocity_to_level=0.7),
    Operator(ratio=1.0, level=0.85, attack=0.001, decay=0.4, sustain=0.8, release=0.03),
    Operator(ratio=0.5, level=1.0, attack=0.001, decay=0.1, sustain=0.4, release=0.03),
    Operator(ratio=0.5, level=0.45, attack=0.001, decay=0.5, sustain=0.8, release=0.03),
))

ELECTRIC_PIANO = FmPatch("electric piano", algorithm=4, feedback=0.0, operators=(
    Operator(ratio=1.0, level=1.3, attack=0.001, decay=0.5, sustain=0.15, release=0.15),
    Operator(ratio=1.0, level=0.55, attack=0.002, decay=1.2, sustain=0.3, release=0.18),
    Operator(ratio=14.0, level=1.4, attack=0.001, decay=0.04, sustain=0.0, release=0.05),
    Operator(ratio=1.0, detune_cents=6, level=0.35, attack=0.002, decay=0.8, sustain=0.2, release=0.18),
))

BRASS = FmPatch("brass", algorithm=4, feedback=0.6, vibrato_depth=0.08, vibrato_delay=0.3, operators=(
    Operator(ratio=1.0, level=1.9, attack=0.045, decay=0.4, sustain=0.65, release=0.08),
    Operator(ratio=1.0, level=0.5, attack=0.015, decay=0.6, sustain=0.8, release=0.08),
    Operator(ratio=1.0, detune_cents=8, level=1.3, attack=0.06, decay=0.5, sustain=0.6, release=0.08),
    Operator(ratio=1.0, detune_cents=-7, level=0.45, attack=0.02, decay=0.6, sustain=0.8, release=0.08),
))

BRASS_STAB = FmPatch("brass stab", algorithm=4, feedback=0.7, operators=(
    Operator(ratio=1.0, level=2.2, attack=0.008, decay=0.12, sustain=0.4, release=0.05),
    Operator(ratio=1.0, level=0.55, attack=0.004, decay=0.2, sustain=0.5, release=0.05),
    Operator(ratio=2.0, detune_cents=6, level=0.9, attack=0.01, decay=0.1, sustain=0.3, release=0.05),
    Operator(ratio=1.0, detune_cents=-6, level=0.45, attack=0.004, decay=0.2, sustain=0.5, release=0.05),
))

# the signature voice: every statement of the motif is played on this
LEAD = FmPatch("lead", algorithm=4, feedback=1.15, vibrato_depth=0.22, vibrato_rate=5.8, vibrato_delay=0.22,
               operators=(
    Operator(ratio=1.0, level=1.4, attack=0.004, decay=0.3, sustain=0.7, release=0.07),
    Operator(ratio=1.0, level=0.55, attack=0.004, decay=0.8, sustain=0.75, release=0.07),
    Operator(ratio=2.0, detune_cents=5, level=0.8, attack=0.01, decay=0.25, sustain=0.5, release=0.07),
    Operator(ratio=1.0, detune_cents=-5, level=0.4, attack=0.004, decay=0.8, sustain=0.75, release=0.07),
))

STRINGS = FmPatch("strings", algorithm=5, feedback=0.8, vibrato_depth=0.1, vibrato_rate=5.0, vibrato_delay=0.4,
                  operators=(
    Operator(ratio=1.0, level=0.9, attack=0.35, decay=1.0, sustain=0.8, release=0.4),
    Operator(ratio=1.0, detune_cents=-9, level=0.3, attack=0.3, decay=1.0, sustain=0.9, release=0.45),
    Operator(ratio=1.0, detune_cents=9, level=0.3, attack=0.3, decay=1.0, sustain=0.9, release=0.45),
    Operator(ratio=2.0, detune_cents=3, level=0.12, attack=0.4, decay=1.0, sustain=0.9, release=0.45),
))

BELL = FmPatch("bell", algorithm=4, feedback=0.0, operators=(
    Operator(ratio=3.5, level=2.0, attack=0.001, decay=0.3, sustain=0.0, release=0.3),
    Operator(ratio=1.0, level=0.6, attack=0.001, decay=0.9, sustain=0.0, release=0.4),
    Operator(ratio=7.0, level=1.0, attack=0.001, decay=0.15, sustain=0.0, release=0.2),
    Operator(ratio=2.0, level=0.3, attack=0.001, decay=0.5, sustain=0.0, release=0.3),
))

KICK = megadrive.make_kick()
SNARE = megadrive.make_snare()
CLAP = megadrive.make_clap()
TOMS = [megadrive.make_tom(frequency) for frequency in (210.0, 165.0, 125.0)]

BASS_GROOVES = {
    # (step, length in sixteenths, chord degree, velocity); degrees R, O (octave), 3, 5, 7, -5
    "funk": [(0, 2, "R", 1.0), (2, 1, "R", 0.45), (3, 1, "O", 0.9), (5, 1, "R", 0.5), (6, 2, "7", 0.85),
             (8, 1, "R", 1.0), (10, 1, "O", 0.9), (11, 1, "R", 0.5), (12, 2, "5", 0.8), (14, 1, "O", 0.9),
             (15, 1, "7", 0.7)],
    "funk_turn": [(0, 2, "R", 1.0), (2, 1, "R", 0.45), (3, 1, "O", 0.9), (5, 1, "R", 0.5), (6, 2, "7", 0.85),
                  (8, 1, "R", 1.0), (10, 1, "O", 0.9), (11, 1, "R", 0.5), (12, 1, "3", 0.8), (13, 1, "5", 0.6),
                  (14, 2, "O", 0.9)],
    "lyrical": [(0, 3, "R", 1.0), (3, 1, "R", 0.5), (4, 2, "O", 0.85), (6, 1, "R", 0.6), (7, 2, "7", 0.8),
                (10, 2, "R", 0.9), (12, 1, "O", 0.85), (13, 1, "5", 0.6), (14, 2, "3", 0.8)],
    "house": [(0, 1, "R", 1.0), (2, 1, "O", 0.9), (3, 1, "R", 0.5), (4, 1, "R", 0.9), (6, 1, "O", 0.9),
              (7, 1, "7", 0.6), (8, 1, "R", 1.0), (10, 1, "O", 0.9), (11, 1, "R", 0.5), (12, 1, "R", 0.9),
              (13, 1, "3", 0.7), (14, 1, "O", 0.9), (15, 1, "5", 0.7)],
    "drive": [(step, 1, "O" if step % 4 == 2 else "R", 1.0 if step % 4 == 0 else (0.85 if step % 2 == 0 else 0.6))
              for step in range(16)],
    "offbeat": [(step, 2, "R" if step % 8 == 2 else "O", 0.9) for step in (2, 6, 10, 14)],
    "pulse": [(step, 1, "R", 0.9 if step % 4 == 0 else 0.7) for step in range(0, 16, 2)],
    "hold": [(0, 12, "R", 0.85), (12, 2, "5", 0.6), (14, 2, "O", 0.7)],
    "whole": [(0, 15, "R", 0.85)],
    # ska: a walking line, a note on every beat climbing through the chord, a push into the next
    "walking": [(0, 3, "R", 1.0), (4, 3, "3", 0.85), (8, 3, "5", 0.9), (12, 2, "7", 0.8), (14, 2, "5", 0.7)],
    "walking_up": [(0, 3, "R", 1.0), (4, 3, "5", 0.85), (8, 3, "O", 0.9), (12, 2, "5", 0.8), (14, 2, "3", 0.75)],
    "new_jack": [(0, 3, "R", 1.0), (3, 1, "O", 0.8), (6, 1, "R", 0.7), (7, 2, "7", 0.85), (10, 1, "R", 0.9),
                 (11, 1, "O", 0.7), (13, 1, "5", 0.7), (14, 2, "3", 0.8)],
}


# ----------------------------------------------------------------------------- the song


class Song:
    """A piece: tempo, length, the house tracks and the helpers to put notes on its grid.
    Loops wrap everything that rings past the end onto the start; one-shots stop there."""

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
        sample_count = int(round(self.seconds * megadrive.SAMPLE_RATE))

        def track(name, pan, gain):
            return Track(name, sample_count, pan=pan, gain=gain, wrap=loop)

        # one mix for every piece (Mega Drive style panning, a little softer for headphones)
        self.bass = track("bass", 0.0, 0.6)
        self.piano = track("electric piano", -0.55, 0.4)
        self.brass = track("brass", 0.5, 0.42)
        self.strings = track("strings", -0.3, 0.5)
        self.lead = track("lead", 0.0, 0.6)
        self.psg_one = track("psg 1", 0.35, 0.2)
        self.psg_two = track("psg 2", -0.35, 0.2)
        self.noise = track("psg noise", 0.2, 0.3)
        self.pcm = track("pcm drums", 0.0, 0.7)
        self.tracks = [self.bass, self.piano, self.brass, self.strings, self.lead, self.psg_one,
                       self.psg_two, self.noise, self.pcm]

    def at(self, bar: int, step: float = 0) -> float:
        """Seconds from the start, with the swing on odd sixteenths."""
        late = self.swing * self.step if step == int(step) and int(step) % 2 == 1 else 0.0
        return bar * self.bar_seconds + step * self.step + late

    def sixteenths(self, count: float) -> float:
        return round(count * self.step, 4)

    def render(self, target_rms_db: float = -14.0, peak_db: float = -1.5, fade_out: float = 0.0,
               low_pass_hz: float = 11000.0) -> None:
        stereo = megadrive.master(self.tracks, target_rms_db=target_rms_db, peak_db=peak_db, low_pass_hz=low_pass_hz)
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
              f"{', loop' if self.loop else ''})")


# ----------------------------------------------------------------------------- composing helpers


def lead(song: Song, first_bar: int, text: str, bar_chords, velocity: float = 1.0, echo: bool = False,
         harmony: bool = False, slides: bool = False, octave: int = 0, patch: FmPatch = LEAD) -> None:
    """A melody on the signature voice. `echo`: the PSG plays it again three sixteenths later
    (the classic one-channel echo); `harmony`: the PSG plays a chord tone under every note."""
    total_steps = sum(8 if token.startswith("M") else int(token.split(":")[1]) for token in text.split())
    if total_steps != 16 * len(bar_chords):
        raise ValueError(f"phrase is {total_steps} sixteenths, its {len(bar_chords)} bars need {16 * len(bar_chords)}")
    previous_pitch = None
    for note in phrase(text, bar_chords):
        bar_offset, step_in_bar = divmod(note.step, 16)
        chord = bar_chords[min(bar_offset, len(bar_chords) - 1)]
        start = song.at(first_bar + bar_offset, step_in_bar)
        length = song.sixteenths(note.length * note.articulation)
        pitch = note.pitch + 12 * octave
        slide = None
        if slides and not note.motif and previous_pitch is not None and 0 < abs(previous_pitch - pitch) <= 3:
            slide = float(previous_pitch)
        accent = velocity if note.motif else velocity * 0.92
        song.lead.add(start, megadrive.fm_note(patch, float(pitch), length, round(accent, 3), slide))
        if harmony:
            song.psg_two.add(start, megadrive.psg_square(chord.tone_below(pitch), length, 0.8, decay=0.4, sustain=0.6))
        if echo:
            song.psg_two.add(start + 3 * song.step, megadrive.psg_square(pitch, length, 0.55, decay=0.12, sustain=0.4))
        previous_pitch = pitch


def bass_bar(song: Song, bar: int, chord: Chord, groove: str, patch: FmPatch = SLAP_BASS,
             velocity: float = 1.0, until_step: int = 16) -> None:
    for step, steps_long, degree, note_velocity in BASS_GROOVES[groove]:
        if step >= until_step:
            continue
        song.bass.add(song.at(bar, step), megadrive.fm_note(patch, float(chord.bass_note(degree)),
                                                              song.sixteenths(steps_long * 0.85),
                                                              round(note_velocity * velocity, 3)))


PIANO_RHYTHMS = {
    "push": [(0, 3, 1.0), (3, 2, 0.7), (6, 1, 0.8), (10, 3, 0.9), (14, 1, 0.6)],
    "answer": [(0, 2, 0.9), (4, 1, 0.6), (6, 3, 0.85), (11, 2, 0.8), (14, 2, 0.7)],
    "offbeats": [(2, 2, 0.85), (6, 2, 0.8), (10, 2, 0.85), (14, 2, 0.75)],
    # ska: the skank, short and hard on every upbeat; the "bubble" doubles each one
    "skank": [(2, 1, 0.95), (6, 1, 0.9), (10, 1, 0.95), (14, 1, 0.85)],
    "bubble": [(2, 1, 0.9), (3, 1, 0.5), (6, 1, 0.85), (7, 1, 0.5), (10, 1, 0.9), (11, 1, 0.5), (14, 1, 0.85), (15, 1, 0.5)],
    "sparse": [(0, 3, 0.6), (10, 3, 0.6)],
    "held": [(0, 15, 0.7)],
}


def piano_bar(song: Song, bar: int, chord: Chord, rhythm: str, velocity: float = 1.0, octave: int = 0) -> None:
    voicing = [note + 12 * octave for note in chord.voicing]
    for step, steps_long, note_velocity in PIANO_RHYTHMS[rhythm]:
        song.piano.add(song.at(bar, step), megadrive.fm_chord(ELECTRIC_PIANO, voicing, song.sixteenths(steps_long * 0.9),
                                                              round(note_velocity * velocity, 3)))


def brass_pad(song: Song, bar: int, chord: Chord, bars: float = 1, velocity: float = 0.85) -> None:
    song.brass.add(song.at(bar), megadrive.fm_chord(BRASS, [note + 12 for note in chord.voicing[:4]],
                                                     song.sixteenths(16 * bars * 0.96), velocity))


def brass_stabs(song: Song, bar: int, chord: Chord, hits, velocity: float = 0.95) -> None:
    """hits: (step, length in sixteenths); a negative step is an anticipation in the bar before."""
    voicing = [note + 12 for note in chord.voicing[:4]]
    for step, steps_long in hits:
        start = song.at(bar, step) if step >= 0 else bar * song.bar_seconds + step * song.step
        song.brass.add(start, megadrive.fm_chord(BRASS_STAB, voicing, song.sixteenths(steps_long * 0.85), velocity))


def strings_pad(song: Song, bar: int, chord: Chord, bars: float = 1, velocity: float = 1.0, octave: int = 1) -> None:
    song.strings.add(song.at(bar), megadrive.fm_chord(STRINGS, [note + 12 * octave for note in chord.voicing],
                                                       song.sixteenths(16 * bars * 0.97), velocity))


ARPEGGIO_PATTERNS = {
    "up": ([0, 1, 2, 3] * 4, [0] * 16),
    "up_octave": ([0, 1, 2, 3] * 4, [0, 0, 0, 0, 12, 12, 12, 12] * 2),
    "updown": ([0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 3], [0] * 8 + [12] * 8),
    "motif": ([0, 1, 0, 2, 3, 2, 1, 0] * 2, [0] * 16),
}


def psg_arpeggio(song: Song, bar: int, chord: Chord, pattern: str = "up", volume: float = 0.75,
                 every: int = 1, octave: int = 1, track: Track = None) -> None:
    track = track or song.psg_one
    notes = [note + 12 * octave for note in chord.voicing[:4]]
    if pattern == "twinkle":
        for step in range(0, 16, 2):
            note = notes[(step // 2 * 3) % 4] + 12
            track.add(song.at(bar, step), megadrive.psg_square(note, song.sixteenths(1.5), volume, decay=0.12,
                                                               sustain=0.0, release=0.1))
        return
    order, lift = ARPEGGIO_PATTERNS[pattern]
    for step in range(0, 16, every):
        note = notes[order[step] % len(notes)] + lift[step]
        track.add(song.at(bar, step), megadrive.psg_square(note, song.sixteenths(0.7 * every), volume, decay=0.05,
                                                           sustain=0.25, release=0.03))


def crash(song: Song, bar: int, step: float = 0, volume: float = 1.0) -> None:
    song.noise.add(song.at(bar, step), megadrive.psg_noise(1.6, volume, 26000.0, 0.55, 99))


KICK_PATTERNS = {"four": (0, 4, 8, 12), "push": (0, 4, 8, 12, 14), "broken": (0, 7, 10), "half": (0, 10),
                 "ska": (0, 8), "ska_push": (0, 8, 11),
                 "gallop": (0, 3, 4, 8, 11, 12), "none": ()}
SNARE_PATTERNS = {"backbeat": (4, 12), "half": (8,), "none": ()}


def drum_bar(song: Song, bar: int, kick: str = "four", snare: str = "backbeat", clap: bool = False,
             hats: str = "sixteenths", fill: str = None, ghosts: bool = True, velocity: float = 1.0,
             hat_volume: float = 1.0) -> None:
    """One bar of drums. hats: sixteenths, eighths, open (house off-beats), none.
    fill: snare (last beat), tom (toms back to the one), roll (16ths, building), drop (silence
    on the last beat)."""
    cut_at = 12 if fill in ("snare", "tom", "drop") else 16
    if fill == "roll":
        cut_at = 0
    for step in KICK_PATTERNS[kick]:
        if step < cut_at or fill == "roll":
            song.pcm.add(song.at(bar, step), KICK, velocity * (1.0 if step % 4 == 0 else 0.6))
    for step in SNARE_PATTERNS[snare]:
        if step < cut_at:
            if snare != "none":
                song.pcm.add(song.at(bar, step), SNARE, 0.85 * velocity)
            if clap:
                song.pcm.add(song.at(bar, step), CLAP, 0.6 * velocity)
    if clap and snare == "none":
        for step in (4, 12):
            if step < cut_at:
                song.pcm.add(song.at(bar, step), CLAP, 0.85 * velocity)
    if ghosts and fill is None and snare != "none":
        song.pcm.add(song.at(bar, 15), SNARE, 0.22 * velocity)
        if bar % 2 == 1:
            song.pcm.add(song.at(bar, 7), SNARE, 0.18 * velocity)

    for step in range(min(cut_at, 16) if fill != "roll" else 16):
        offbeat = step % 4 == 2
        if hats == "open" and offbeat:
            song.noise.add(song.at(bar, step), megadrive.psg_noise(0.2, 0.9 * hat_volume, 30000.0, 0.09, step))
        elif hats in ("sixteenths", "open") or (hats == "eighths" and step % 2 == 0):
            hat_level = 0.75 if offbeat else (0.45 if step % 2 == 0 else 0.3)
            song.noise.add(song.at(bar, step), megadrive.psg_noise(0.05, hat_level * hat_volume, 32000.0, 0.018, step * 7))

    if fill == "snare":
        for step, fill_velocity in ((12, 0.6), (13, 0.5), (14, 0.8), (15, 0.95)):
            song.pcm.add(song.at(bar, step), SNARE, fill_velocity * velocity)
        if clap:
            song.pcm.add(song.at(bar, 14), CLAP, 0.7 * velocity)
    elif fill == "tom":
        for step, tom_index, fill_velocity in ((12, 0, 0.9), (13, 1, 0.85), (14, 2, 0.95), (15, 2, 0.8)):
            song.pcm.add(song.at(bar, step), TOMS[tom_index], fill_velocity * velocity)
        song.pcm.add(song.at(bar, 12), SNARE, 0.5 * velocity)
    elif fill == "roll":
        for step in range(16):
            if step < 8 and step % 2:
                continue
            song.pcm.add(song.at(bar, step), SNARE, (0.2 + 0.75 * step / 15) * velocity)
        song.pcm.add(song.at(bar, 15), CLAP, 0.9 * velocity)


## Drum solos: one bar each, (step, drum, velocity); drum K kick, S snare, C clap, T0..T2 the
## toms high to low, X a crash.
DRUM_SOLOS = {
    # down the toms in sixteenths, kicks under the ones
    "toms_down": [(0, "K", 1.0), (0, "S", 0.9), (2, "T0", 0.8), (3, "T0", 0.6), (4, "T0", 0.9), (5, "T1", 0.7),
                  (6, "T1", 0.85), (7, "T1", 0.6), (8, "K", 0.9), (8, "T1", 0.9), (9, "T2", 0.7), (10, "T2", 0.85),
                  (11, "T2", 0.65), (12, "S", 0.8), (13, "S", 0.6), (14, "T0", 0.9), (15, "T2", 1.0)],
    # snare and kick trading, syncopated, as a ska drummer
    "trade": [(0, "K", 1.0), (2, "S", 0.9), (3, "S", 0.5), (4, "K", 0.8), (6, "S", 0.95), (7, "K", 0.7),
              (9, "S", 0.6), (10, "S", 0.9), (11, "K", 0.7), (12, "S", 0.7), (13, "S", 0.8), (14, "S", 0.9),
              (15, "S", 1.0)],
    # accents with a clap, then a tom run up to the one
    "accents": [(0, "K", 1.0), (0, "X", 0.6), (3, "S", 0.9), (3, "C", 0.6), (6, "S", 0.9), (6, "C", 0.6),
                (8, "K", 0.9), (10, "S", 0.9), (10, "C", 0.6), (12, "T2", 0.8), (13, "T1", 0.85), (14, "T0", 0.9),
                (15, "T0", 1.0)],
    # a building snare roll in thirty-seconds
    "roll": [(step * 0.5, "S", 0.25 + 0.75 * step / 31) for step in range(32)] + [(0, "K", 1.0), (8, "K", 0.9)],
}


def drum_solo(song: Song, bar: int, solo: str, velocity: float = 1.0) -> None:
    """One bar of a drum solo (DRUM_SOLOS), the drums alone."""
    sounds = {"K": KICK, "S": SNARE, "C": CLAP, "T0": TOMS[0], "T1": TOMS[1], "T2": TOMS[2]}
    for step, drum, hit_velocity in DRUM_SOLOS[solo]:
        if drum == "X":
            crash(song, bar, step, hit_velocity)
        else:
            song.pcm.add(song.at(bar, step), sounds[drum], hit_velocity * velocity)


def big_hit(song: Song, bar: int, step: float, chord: Chord, sixteenths: float) -> None:
    """Everything at once: kick, snare and clap, crash, brass, strings, low bass."""
    song.pcm.add(song.at(bar, step), KICK)
    song.pcm.add(song.at(bar, step), SNARE, 0.8)
    song.pcm.add(song.at(bar, step), CLAP, 0.6)
    crash(song, bar, step)
    voicing = [note + 12 for note in chord.voicing[:4]]
    song.brass.add(song.at(bar, step), megadrive.fm_chord(BRASS, voicing, song.sixteenths(sixteenths), 1.0))
    song.strings.add(song.at(bar, step), megadrive.fm_chord(STRINGS, voicing + [voicing[0] + 12],
                                                            song.sixteenths(sixteenths), 1.0))
    song.bass.add(song.at(bar, step), megadrive.fm_note(SYNTH_BASS, float(chord.bass_root - 12),
                                                        song.sixteenths(sixteenths), 1.0))
