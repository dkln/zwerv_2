"""Renders a Piece (bars of a score, the sounds of its parts) to a stereo buffer.

A loop is exactly its bars long and wraps what rings past the end to the start (megadrive.Track),
so the file loops without a seam; a one-shot gets `tail` seconds to ring out. Everything ends at
the house loudness (tools/megadrive/loudness.py: integrated -16 LUFS, peaks under -1.5 dB).
"""
import os
import sys
from dataclasses import dataclass, field

import numpy

import chip
import tracker
import instruments

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "megadrive"))
import loudness  # noqa: E402
import megadrive  # noqa: E402

SAMPLE_RATE = megadrive.SAMPLE_RATE
MUSIC_CEILING_DB = -1.5
## The sound of a part the composition has no sound for (a derived piece may add a part).
DEFAULT_PART_SOUNDS = {
    "bas": "fm_slapbas", "subbas": "fm_subbas", "pad": "synthwave_pad", "brass": "synth_brass",
    "lead": "fm_lead_helder", "arp": "psg_arp", "gitaar": "overdrive_gitaar", "solo": "overdrive_gitaar_solo",
}


@dataclass
class Piece:
    name: str                       # the file name in assets/audio/muziek/, without .ogg
    tempo: float
    beats_per_bar: int
    bars: list                      # [score.Bar]
    sounds: dict                    # part -> sound name (instruments.SOUNDS)
    loop: bool = True
    tail: float = 2.0               # one-shot: seconds after the last bar
    part_gains: dict = field(default_factory=dict)   # part (or "drums") -> factor
    tape_stop: tuple = None         # (at seconds, seconds): the music slows to a standstill
    fade_out: float = 0.0           # one-shot: seconds of fade at the very end
    last_bar_beats: float = None    # one-shot: the last bar only this long (then the tail)
    swing: float = 0.0              # 0 straight, 1 a full shuffle (the "and" on the last triplet)
    tracker: str = ""               # a tracker page or JSON (in composities/): the piece as its synth plays it (tracker.py)

    @property
    def beat_seconds(self) -> float:
        return 60.0 / self.tempo

    @property
    def bars_seconds(self) -> float:
        beats = len(self.bars) * self.beats_per_bar
        if self.last_bar_beats is not None and not self.loop:
            beats -= self.beats_per_bar - self.last_bar_beats
        return beats * self.beat_seconds

    def sound_of(self, part: str) -> str:
        return self.sounds.get(part) or DEFAULT_PART_SOUNDS[part]

    @property
    def seconds(self) -> float:
        return self.bars_seconds + (0.0 if self.loop else self.tail)


class _Tracks:
    """The mixer channels of a piece, made as they are first needed."""

    def __init__(self, sample_count: int, wrap: bool) -> None:
        self.sample_count = sample_count
        self.wrap = wrap
        self.by_key = {}

    def get(self, key: str, pan: float) -> megadrive.Track:
        if key not in self.by_key:
            self.by_key[key] = megadrive.Track(key, self.sample_count, pan=pan, wrap=self.wrap)
        return self.by_key[key]


def swung(position: float, swing: float) -> float:
    """A position (beats from 1.0) with the swing of the eighths: the first half of every beat
    stretched, the second half squeezed, so the "and" moves from 0.5 towards 2/3 of the beat
    (swing 1: a full triplet shuffle); the beats themselves stay where they are."""
    if not swing:
        return position
    beat = int((position - 1.0) // 1.0)
    within = position - 1.0 - beat
    off_beat = 0.5 + swing * (2.0 / 3.0 - 0.5)
    if within < 0.5:
        within = within / 0.5 * off_beat
    else:
        within = off_beat + (within - 0.5) / 0.5 * (1.0 - off_beat)
    return 1.0 + beat + within


def _play(piece: Piece) -> list:
    """Every note and hit of the piece on its mixer channel: the channels, not yet mixed."""
    sample_count = int(round(piece.seconds * SAMPLE_RATE))
    tracks = _Tracks(sample_count, piece.loop)
    beat = piece.beat_seconds
    for bar_index, bar in enumerate(piece.bars):
        bar_start = bar_index * piece.beats_per_bar * beat
        for part, part_notes in bar.parts.items():
            sound = instruments.SOUNDS[piece.sound_of(part)]
            gain = sound.gain * piece.part_gains.get(part, 1.0)
            for note in part_notes:
                at = bar_start + (swung(note.position, piece.swing) - 1.0) * beat
                length = note.length * beat
                if sound.width:
                    for side in (-1.0, 1.0):
                        samples = sound.render(note.pitches, length, note.velocity, side * sound.width * 0.5)
                        tracks.get(f"{part}_{side}", max(-1.0, min(1.0, sound.pan + side * 0.65))).add(at, samples, gain * 0.75)
                    continue
                samples = sound.render(note.pitches, length, note.velocity)
                tracks.get(part, sound.pan).add(at, samples, gain)
                if sound.echo:
                    echo_track = tracks.get(f"{part}_echo", -sound.pan * 2.5 if sound.pan else 0.5)
                    for repeat in range(1, sound.echo_repeats + 1):
                        echo_track.add(at + repeat * sound.echo * beat, samples, gain * sound.echo_level ** repeat)
        drum_gain = piece.part_gains.get("drums", 1.0)
        kit = instruments.DRUM_KITS[piece.sounds.get("drumstel", "standaard")]
        for hit in bar.hits:
            drum = kit[hit.drum]
            at = bar_start + (swung(hit.position, piece.swing) - 1.0) * beat
            tracks.get(f"drum_{hit.drum}", drum.pan).add(at, drum.samples, drum.gain * hit.velocity * drum_gain)
    if not tracks.by_key:
        raise ValueError(f"{piece.name}: nothing to play")
    return list(tracks.by_key.values())


def raw_mix(piece: Piece) -> numpy.ndarray:
    """The channels summed to mono at their levels in the mix, unfiltered and not levelled
    (for comparing parts: check.py --balans)."""
    return sum(track.buffer * track.gain for track in _play(piece))


def _play_tracker(piece: Piece) -> list:
    """The score of the piece's tracker (a page or a JSON composition) as its own synth plays
    it (tracker.render: its voices, panning, master volume and compressor), as long as the
    piece: a left and a right mixer channel."""
    source = tracker.tracker_in_compositions(piece.tracker)
    sample_count = int(round(piece.seconds * SAMPLE_RATE))
    played = tracker.render(source, piece.tail + (2.0 if piece.loop else 0.5))
    if piece.loop:
        # a loop: what rings past the end wraps to the start (no seam, as megadrive.Track does)
        ringing = played[sample_count:]
        played = played[:sample_count].copy()
        played[:len(ringing)] += ringing[:sample_count]
    played = played[:sample_count]
    tracks = []
    for side, pan in ((0, -1.0), (1, 1.0)):
        track = megadrive.Track(f"tracker_{side}", sample_count, pan=pan, wrap=False)
        track.buffer[:len(played)] = played[:, side]
        tracks.append(track)
    return tracks


def render(piece: Piece) -> numpy.ndarray:
    """The piece mastered: filtered like the Model 1, at the house loudness, peaks limited."""
    if piece.tracker:
        channels = _play_tracker(piece)
    else:
        channels = _play(piece)
    stereo = megadrive.master(channels, target_rms_db=-14.0, peak_db=-1.0)
    if piece.tape_stop:
        stereo = megadrive.tape_stop(stereo, *piece.tape_stop)
    if not piece.loop:
        stereo = _fade_tail(stereo, piece.fade_out)
    return loudness.level(stereo, one_shot=False, ceiling_db=MUSIC_CEILING_DB)


def _fade_tail(stereo: numpy.ndarray, fade_seconds: float) -> numpy.ndarray:
    """A one-shot ends in silence: a short fade at the very end (longer when asked)."""
    fade = max(int(0.05 * SAMPLE_RATE), int(fade_seconds * SAMPLE_RATE))
    fade = min(fade, len(stereo))
    result = stereo.copy()
    result[-fade:] *= numpy.linspace(1.0, 0.0, fade)[:, None]
    return result


def write(piece: Piece, folder: str) -> str:
    stereo = render(piece)
    path = os.path.join(folder, piece.name + ".ogg")
    megadrive.write_ogg(path, stereo)
    lufs = loudness.integrated_lufs(stereo)
    peak = 20 * numpy.log10(numpy.abs(stereo).max() + 1e-12)
    kind = "lus" if piece.loop else "eenmalig"
    print(f"geschreven: {path}  ({len(stereo) / SAMPLE_RATE:.2f} s, {kind}, {lufs:.1f} LUFS, piek {peak:.1f} dB)")
    return path
