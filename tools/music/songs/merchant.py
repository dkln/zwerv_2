"""Handelaar — merchant/shop loop in the house style (style.py), 130 BPM, 32 bars (~59 s), seamless.

The lightest piece: synths only (no 8-bit voices, no guitars), softer lead, calmer bass in the
first half. Same heart (Em F Am G, sounding Fm Gb Bbm Ab) and the motif in every bar.

  bars  1-8   A:  motif theme on the synth lead, octave bass
  bars  9-16  B:  Am F Em G / Am F Bm B7, motif theme, octave bass (music filter dips into it)
  bars 17-24  A': theme with harmony in thirds, rolling bass, brass (filter build into it)
  bars 25-32  C:  starts dull and opens up, halftime then groove, motif calls over louder runs, fill back to bar 1
"""
from style import (StyleTracks, arp_run, brass_stab, build_into, crash, drums, epiano_comp, filter_dip,
                   filter_open_up, lead_line, motif_calls, octave_bass, pads, rolling_bass, snare_fill,
                   theme_from_chords)

BPM = 130
BARS = 32

A_CHORDS = ["Em", "Em", "F", "Am", "Em", "Em", "G", "Em"]
B_CHORDS = ["Am", "F", "Em", "G", "Am", "F", "Bm", "B7"]

SOFTER = {"synth_lead": 0.65, "synth_echo": 0.75, "synth_harmony": 0.75, "brass": 0.7, "kick": 0.85,
          "snare": 0.85, "arp_left": 0.75, "arp_right": 0.75}


def backing(song, tracks, first_bar, chords, kit="four", runs_gain=1.0, brass=False, rolling=False):
    pads(song, tracks, first_bar, chords)
    for offset, chord_name in enumerate(chords):
        bar = first_bar + offset
        drums(song, tracks, bar, kit=kit)
        if rolling:
            rolling_bass(song, tracks, bar, chord_name, gain=0.85)
        else:
            octave_bass(song, tracks, bar, chord_name, gain=0.9)
        arp_run(song, tracks, bar, chord_name, gain=runs_gain, brightness=4500)
        epiano_comp(song, tracks, bar, chord_name)
        if brass:
            brass_stab(song, tracks, bar, chord_name, beats=1.5, gain=0.7)
    crash(song, tracks, song.at(first_bar), 0.7)


def compose(song, first_bar):
    tracks = StyleTracks(song, levels=SOFTER)
    backing(song, tracks, first_bar, A_CHORDS)
    lead_line(song, tracks, first_bar, theme_from_chords(A_CHORDS))

    filter_dip(song, first_bar + 6, down_beats=4, hold_beats=2, up_beats=2, lowest=700)
    backing(song, tracks, first_bar + 8, B_CHORDS)
    lead_line(song, tracks, first_bar + 8, theme_from_chords(B_CHORDS))

    build_into(song, tracks, first_bar + 16, bars=1, lowest_cutoff=1200)
    backing(song, tracks, first_bar + 16, A_CHORDS, brass=True, rolling=True)
    lead_line(song, tracks, first_bar + 16, theme_from_chords(A_CHORDS), harmony_chords=A_CHORDS)

    filter_open_up(song, first_bar + 24, bars=4, lowest=500)
    backing(song, tracks, first_bar + 24, A_CHORDS[:4], kit="halftime", runs_gain=1.3)
    backing(song, tracks, first_bar + 28, A_CHORDS[4:], runs_gain=1.15, rolling=True)
    for offset, phrase in enumerate(motif_calls(A_CHORDS)):
        lead_line(song, tracks, first_bar + 24 + offset, phrase)
    snare_fill(song, tracks, first_bar + 31, gain=0.7)


RENDERS = [
    {"file": "handelaar_loop.ogg", "bpm": BPM, "bars": BARS, "compose": compose, "loop": True},
]
