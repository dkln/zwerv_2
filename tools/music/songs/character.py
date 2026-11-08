"""Karakterkeuze — the soft loop under the character creation screen, in the house style
(style.py), 92 BPM, 16 bars (~42 s), seamless.

The quietest piece: it sits behind the choice, so no drops, no guitars, no 8-bit voices. A
slow supersaw pad, the e-piano on the chords, the pluck arpeggio far back and dull, a
halftime beat at low gain, and the motif only now and then on a soft, dull lead. Same
heart (Em F Am G, sounding Fm Gb Bbm Ab).

  bars  1-8   A:  pad, e-piano, dull arpeggio, halftime beat; motif calls in bars 3 and 7
  bars  9-16  B:  Am F Em G / Am F Bm Em, the theme once softly on the lead, filter slowly
                  opening and closing again, so bar 16 runs into bar 1
"""
from style import (StyleTracks, arp_run, drums, epiano_comp, filter_dip, filter_open_up, lead_line,
                   motif_calls, pads, theme_from_chords)

BPM = 92
BARS = 16

A_CHORDS = ["Em", "Em", "F", "Am", "Em", "Em", "G", "Em"]
B_CHORDS = ["Am", "F", "Em", "G", "Am", "F", "Bm", "Em"]

QUIET = {"synth_lead": 0.45, "synth_echo": 0.6, "kick": 0.45, "snare": 0.35, "clap": 0.25,
         "ghost_snare": 0.4, "hats": 0.55, "open_hats": 0.4, "arp_left": 0.55, "arp_right": 0.55,
         "bass": 0.0, "sub": 0.0, "epiano": 0.9, "pad": 1.1}


def backing(song, tracks, first_bar, chords):
    pads(song, tracks, first_bar, chords, attack=1.2)
    for offset, chord_name in enumerate(chords):
        bar = first_bar + offset
        drums(song, tracks, bar, kit="halftime", gain=0.6)
        arp_run(song, tracks, bar, chord_name, gain=0.7, brightness=2200)
        epiano_comp(song, tracks, bar, chord_name, gain=0.85)


def compose(song, first_bar):
    tracks = StyleTracks(song, levels=QUIET)
    backing(song, tracks, first_bar, A_CHORDS)
    calls = motif_calls(A_CHORDS)
    lead_line(song, tracks, first_bar + 2, calls[2], gain=0.6)
    lead_line(song, tracks, first_bar + 6, calls[6], gain=0.6)
    filter_dip(song, first_bar + 4, down_beats=4, hold_beats=2, up_beats=6, lowest=900)

    backing(song, tracks, first_bar + 8, B_CHORDS)
    filter_open_up(song, first_bar + 8, bars=4, lowest=1200)
    lead_line(song, tracks, first_bar + 8, theme_from_chords(B_CHORDS), gain=0.55)
    filter_dip(song, first_bar + 14, down_beats=4, hold_beats=0, up_beats=4, lowest=1100)


RENDERS = [
    {"file": "karakterkeuze_loop.ogg", "bpm": BPM, "bars": BARS, "compose": compose, "loop": True},
]
