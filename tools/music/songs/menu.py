"""Nachtstad — the main menu loop, in the house style (style.py) but its own piece, so the
menu does not sound like the intro going on: other chords (Am F C G in front, the intro's
Em F Am only as colour), brass stabs and the e-piano driving it, the 8-bit voice and the
synth lead taking turns with the motif. Energetic, as there is a lot going on behind the
menu (traffic, fire, the helicopter): 134 BPM (the intro is 142), the full groove and
four-on-the-floor from the first bar, the rolling bass, off-beat brass, a drop hit at the
top of every section, light guitar chugs in B. 48 bars (~1:26), seamless.

  bars  1-16  A:  a drop hit, the groove, rolling bass, e-piano and off-beat brass, the
                  arpeggio; the 8-bit voice plays the theme in the second half
  bars 17-32  B:  Em C D Bm, four-on-the-floor, light chugs, bright arpeggios, the synth
                  lead with harmony
  bars 33-48  C:  a short dull breath (four bars), then it opens up with the full groove,
                  motif calls on the 8-bit voice and a build back into bar 1
"""
from style import (StyleTracks, arp_run, brass_stab, build_into, chip_line, chugs, crash, drop_hit, drums, epiano_comp,
                   filter_dip, filter_open_up, lead_line, motif_calls, octave_bass, pads, rolling_bass,
                   snare_fill, theme_from_chords)

BPM = 134
BARS = 48

A_CHORDS = ["Am", "Am", "F", "F", "C", "C", "G", "B7",
            "Am", "Am", "F", "F", "C", "G", "Em", "Em"]
B_CHORDS = ["Em", "C", "D", "Bm", "Em", "C", "D", "B7",
            "Em", "C", "Am", "B7", "Em", "C", "D", "D"]
C_CHORDS = ["F", "F", "Am", "Am", "C", "C", "G", "G",
            "F", "F", "Am", "Am", "Bm", "Bm", "B7", "B7"]

LEVELS = {"synth_lead": 0.9, "chip_lead": 1.1, "brass": 1.25, "epiano": 1.0, "guitar_left": 0.6, "guitar_right": 0.6}


def section_a(song, tracks, first_bar):
    drop_hit(song, tracks, first_bar)
    pads(song, tracks, first_bar, A_CHORDS, attack=0.2)
    for offset, chord_name in enumerate(A_CHORDS):
        bar = first_bar + offset
        drums(song, tracks, bar, kit="groove")
        rolling_bass(song, tracks, bar, chord_name, gain=0.9)
        epiano_comp(song, tracks, bar, chord_name, gain=0.85)
        brass_stab(song, tracks, bar, chord_name, beat=1.5, beats=0.5, gain=0.6)
        brass_stab(song, tracks, bar, chord_name, beat=3.5, beats=0.5, gain=0.5)
        arp_run(song, tracks, bar, chord_name, gain=0.7, brightness=5000)
    crash(song, tracks, song.at(first_bar + 8), 0.8)
    chip_line(song, tracks, first_bar + 8, theme_from_chords(A_CHORDS[8:]), gain=0.8)
    filter_dip(song, first_bar + 3, beat=2, down_beats=1, up_beats=1, lowest=1200)
    filter_dip(song, first_bar + 7, beat=2, down_beats=1, up_beats=1, lowest=1000)
    snare_fill(song, tracks, first_bar + 15, gain=0.85)


def section_b(song, tracks, first_bar):
    drop_hit(song, tracks, first_bar)
    pads(song, tracks, first_bar, B_CHORDS)
    for offset, chord_name in enumerate(B_CHORDS):
        bar = first_bar + offset
        drums(song, tracks, bar, kit="four")
        rolling_bass(song, tracks, bar, chord_name)
        chugs(song, tracks, bar, chord_name, gain=0.55)
        arp_run(song, tracks, bar, chord_name, gain=0.85, brightness=6500)
        brass_stab(song, tracks, bar, chord_name, beat=0.0 if offset % 2 == 0 else 2.5, beats=1.0, gain=0.6)
    crash(song, tracks, song.at(first_bar + 8), 0.9)
    lead_line(song, tracks, first_bar, theme_from_chords(B_CHORDS), harmony_chords=B_CHORDS, gain=0.9)
    filter_dip(song, first_bar + 5, beat=2, down_beats=1, up_beats=1, lowest=1100)
    filter_dip(song, first_bar + 11, down_beats=2, up_beats=2, lowest=900)
    snare_fill(song, tracks, first_bar + 15)


def section_c(song, tracks, first_bar):
    filter_open_up(song, first_bar, bars=4, lowest=400)
    pads(song, tracks, first_bar, C_CHORDS)
    for offset, chord_name in enumerate(C_CHORDS):
        bar = first_bar + offset
        arp_run(song, tracks, bar, chord_name, gain=0.9)
        epiano_comp(song, tracks, bar, chord_name, gain=0.8)
        if offset < 4:
            drums(song, tracks, bar, kit="halftime", gain=0.9)
            octave_bass(song, tracks, bar, chord_name, gain=0.85)
        else:
            drums(song, tracks, bar, kit="four" if offset >= 12 else "groove")
            rolling_bass(song, tracks, bar, chord_name)
            brass_stab(song, tracks, bar, chord_name, beat=1.5, beats=0.5, gain=0.55)
    for offset, phrase in enumerate(motif_calls(C_CHORDS[4:])):
        chip_line(song, tracks, first_bar + 4 + offset, phrase, gain=0.85)
    crash(song, tracks, song.at(first_bar + 4))
    build_into(song, tracks, first_bar + 16, bars=2, lowest_cutoff=1000)
    snare_fill(song, tracks, first_bar + 15)


def compose(song, first_bar):
    tracks = StyleTracks(song, levels=LEVELS)
    section_a(song, tracks, first_bar)
    section_b(song, tracks, first_bar + 16)
    section_c(song, tracks, first_bar + 32)


RENDERS = [
    {"file": "nachtstad_menu_loop.ogg", "bpm": BPM, "bars": BARS, "compose": compose, "loop": True},
]
