"""Helpers to place notes on the song grid: melodies, arpeggios, step-sequencer drum grids.

Melodies are lists of (note, beats) pairs; "r" is a rest. Notes may also be a list of notes
(a chord) for instruments that accept several notes. Step grids are strings with one character
per step: "x" = hit, "X" = accented hit, "." or "-" = nothing; spaces and "|" are ignored.
"""
from theory import REST, transpose

ACCENT_GAIN = 1.0
NORMAL_GAIN = 0.65


def swung(position, swing):
    """Delay off-beat 8ths: swing 0 = straight, 1/3 = triplet feel ('shuffle')."""
    if swing and abs(position % 1.0 - 0.5) < 1e-6:
        return position + swing / 2
    return position


def play_melody(song, track, instrument, start_bar, melody, start_beat=0.0, legato=0.95,
                semitones=0, gain=1.0, swing=0.0, **instrument_settings):
    """Play a melody; returns the bar/beat position (in beats from start_bar) where it ended."""
    position = start_beat
    for note, length in melody:
        if note != REST:
            pitched = [transpose(part, semitones) for part in note] if isinstance(note, list) else transpose(note, semitones)
            audio = instrument(pitched, song.beats(length) * legato, **instrument_settings)
            track.add(audio, song.at(start_bar, swung(position, swing)), gain)
        position += length
    return position


def play_repeated(song, track, instrument, start_bar, bar_count, notes, step_beats,
                  gate_fraction=0.8, gain=1.0, semitones=0, end_time=None, **instrument_settings):
    """Cycle through `notes` on a fixed rhythmic step (arpeggios, bass pulses)."""
    steps = int(round(bar_count * song.beats_per_bar / step_beats))
    for step in range(steps):
        time = song.at(start_bar, step * step_beats)
        if end_time is not None and time >= end_time:
            break
        note = notes[step % len(notes)]
        if note == REST:
            continue
        audio = instrument(transpose(note, semitones), song.beats(step_beats) * gate_fraction, **instrument_settings)
        track.add(audio, time, gain)


def play_steps(song, track, sound, start_bar, grid, step_beats=0.25, gain=1.0, is_kick=False, swing=0.0):
    """Step sequencer. `sound` is a function without arguments returning the hit sample."""
    steps = [character for character in grid if character not in " |"]
    for step, character in enumerate(steps):
        if character in ".-":
            continue
        time = song.at(start_bar, swung(step * step_beats, swing))
        track.add(sound(), time, gain * (ACCENT_GAIN if character == "X" else NORMAL_GAIN))
        if is_kick:
            song.kick_times.append(time)


def chord_per_bar(progression, start_bar):
    """Expand ["Em", "Em", "C", ...] into {bar: chord_name} starting at start_bar."""
    return {start_bar + offset: chord for offset, chord in enumerate(progression)}
