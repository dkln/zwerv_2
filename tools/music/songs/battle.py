"""Gevecht — RPG battle-screen loop in the house style (style.py), 168 BPM, 32 bars (~46 s), seamless.

Same heart as the main theme (Em F Am, sounding Fm Gb Bbm), faster and harder.

  bars  1-8   A: impact, galloping guitars, rolling bass, the motif as battle call (lead, 8-bit, guitar)
  bars  9-16  B: motif theme on synth lead + lead guitar, straight chugs (stutter into it)
  bars 17-24  C: two-octave pluck runs, e-piano, brass off-beats, motif calls on the 8-bit lead
  bars 25-32  A': battle call in harmony (filter build + impact into it), fill back to bar 1
"""
import instruments as inst
from style import (StyleTracks, arp_run, brass_stab, build_into, chip_line, chugs, crash, drop_hit, drums,
                   epiano_comp, filter_dip, filter_open_up, gallop, guitar_line, lead_line, motif_calls, pads, rolling_bass, snare_fill,
                   stutter_into, theme_from_chords)
from theory import CHORDS, midi

BPM = 168
BARS = 32

A_CHORDS = ["Em", "Em", "F", "Am", "Em", "Em", "F", "B7"]
B_CHORDS = ["Am", "F", "Em", "Em", "Am", "F", "Bm", "B7"]
C_CHORDS = ["F", "Em", "F", "Em", "Am", "G", "Bm", "B7"]


def section_a(song, tracks, first_bar, with_harmony=False):
    """Battle call: the motif on every chord, doubled by 8-bit and guitar."""
    drop_hit(song, tracks, first_bar)
    pads(song, tracks, first_bar, A_CHORDS)
    for offset, chord_name in enumerate(A_CHORDS):
        bar = first_bar + offset
        drums(song, tracks, bar, kit="battle")
        rolling_bass(song, tracks, bar, chord_name)
        gallop(song, tracks, bar, chord_name)
        arp_run(song, tracks, bar, chord_name, gain=0.8)
    for offset, phrase in enumerate(motif_calls(A_CHORDS)):
        lead_line(song, tracks, first_bar + offset, phrase, echo=offset % 2 == 1,
                  harmony_chords=[A_CHORDS[offset]] if with_harmony else None)
        if offset % 2 == 0:
            chip_line(song, tracks, first_bar + offset, phrase, gain=0.6)
            guitar_line(song, tracks, first_bar + offset, phrase, semitones=-12, gain=0.8)


def section_b(song, tracks, first_bar):
    pads(song, tracks, first_bar, B_CHORDS)
    for offset, chord_name in enumerate(B_CHORDS):
        bar = first_bar + offset
        drums(song, tracks, bar, kit="four" if offset >= 4 else "battle")
        rolling_bass(song, tracks, bar, chord_name)
        chugs(song, tracks, bar, chord_name)
        arp_run(song, tracks, bar, chord_name, gain=0.8)
    crash(song, tracks, song.at(first_bar))
    crash(song, tracks, song.at(first_bar + 4))
    filter_dip(song, first_bar + 6, down_beats=2, hold_beats=2, up_beats=4, lowest=800)
    theme = theme_from_chords(B_CHORDS)
    lead_line(song, tracks, first_bar, theme)
    guitar_line(song, tracks, first_bar, theme, semitones=-12, gain=0.8)


def section_c(song, tracks, first_bar):
    filter_open_up(song, first_bar, bars=4, lowest=500)
    pads(song, tracks, first_bar, C_CHORDS)
    for offset, chord_name in enumerate(C_CHORDS):
        bar = first_bar + offset
        drums(song, tracks, bar, kit="battle")
        rolling_bass(song, tracks, bar, chord_name, gain=0.9)
        epiano_comp(song, tracks, bar, chord_name, gain=0.8)
        for stab_beat in (1.5, 3.5):
            brass_stab(song, tracks, bar, chord_name, beat=stab_beat, beats=0.35, gain=0.7)
        arp = [midi(note) for note in CHORDS[chord_name]["arp"]]
        up = arp + [note + 12 for note in arp]
        run = up + up[::-1] if offset % 2 == 0 else up[::-1] + up
        for step, note in enumerate(run):
            track = tracks.arp_left if step % 2 == 0 else tracks.arp_right
            track.add(inst.synth_pluck(note, song.beat * 0.22, 6000, 0.2), song.at(bar, step * 0.25),
                      1.0 if step % 4 == 0 else 0.72)
    for offset, phrase in enumerate(motif_calls(C_CHORDS)):
        if offset % 2 == 0:
            chip_line(song, tracks, first_bar + offset, phrase)
    crash(song, tracks, song.at(first_bar))


def compose(song, first_bar):
    tracks = StyleTracks(song)
    section_a(song, tracks, first_bar)
    stutter_into(song, first_bar + 8, beats=1.0)
    section_b(song, tracks, first_bar + 8)
    section_c(song, tracks, first_bar + 16)
    build_into(song, tracks, first_bar + 24, bars=2)
    section_a(song, tracks, first_bar + 24, with_harmony=True)
    snare_fill(song, tracks, first_bar + 31)
    for step, note in enumerate(["B6", "A6", "F#6", "D#6", "B5", "A5", "F#5", "D#5"]):
        tracks.chip.add(inst.chip_arp(note, song.beat * 0.1), song.at(first_bar + 31, 2 + step * 0.25), 1.0)


RENDERS = [
    {"file": "gevecht_loop.ogg", "bpm": BPM, "bars": BARS, "compose": compose, "loop": True},
]
