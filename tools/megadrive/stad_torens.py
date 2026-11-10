"""'Stad torens': the city loop of the office towers (Centraal Station, De Resident,
Beatrixkwartier, Prins Clauslaan): cool and glassy, straight synthwave.

On the shared plan (stad_plan.py). Offbeat bass, bells, sparkling arpeggios an octave up, the
chiptune lead in A2, long notes on the synth lead in B and C, open hats; no guitar.
Render: tools/megadrive/render.sh stad_torens
"""
import stad_plan
import style
from stad_plan import THEMES, bars_of, section


def glass(song, bar, offset, bar_chord, last, kick="four", hats="open", fill="snare"):
    style.bass_bar(song, bar, bar_chord, "offbeat")
    style.arpeggio(song, bar, bar_chord, "updown", 0.45, octave=1)
    if offset % 2 == 0:
        style.bells(song, bar, style.motif_notes(bar_chord, octave=1)[:2], (0, 6), 0.45)
    style.drum_bar(song, bar, kick=kick, hats=hats, hat_volume=0.8, fill=fill if last else None, ghosts=False)


def main() -> None:
    song = stad_plan.new_song("stad_torens_loop.ogg", "stad_torens")
    first_bar, section_chords = section("A")
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        glass(song, bar, offset, bar_chord, last, hats="sixteenths")
    first_bar, section_chords = section("A2")
    style.chip_lead(song, first_bar, THEMES["A2"], section_chords, volume=0.75)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        glass(song, bar, offset, bar_chord, last)
    first_bar, section_chords = section("B")
    style.lead(song, first_bar, THEMES["B"], section_chords, harmony=True)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        if offset % 2 == 0:
            style.pad(song, bar, bar_chord, bars=2, velocity=0.7)
        glass(song, bar, offset, bar_chord, last, fill="drop")
    style.crash(song, first_bar)
    first_bar, section_chords = section("break")
    style.lead(song, first_bar, THEMES["break"], section_chords, velocity=0.65, patch=style.BELL, track=song.pad)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.pad(song, bar, bar_chord)
        style.bass_bar(song, bar, bar_chord, "whole")
        style.arpeggio(song, bar, bar_chord, "twinkle", 0.4)
        if last:
            style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", hat_volume=0.5, fill="roll")
    first_bar, section_chords = section("C")
    style.lead(song, first_bar, THEMES["C"], section_chords, echo=True)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.brass_stabs(song, bar, bar_chord, [(2, 1), (10, 1)], 0.7)
        glass(song, bar, offset, bar_chord, last, kick="push")
    style.crash(song, first_bar)
    first_bar, section_chords = section("D")
    style.chip_lead(song, first_bar, THEMES["D"], section_chords, volume=0.7, octave=1)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.pad(song, bar, bar_chord, velocity=0.75)
        glass(song, bar, offset, bar_chord, last, kick="half", hats="eighths")
    first_bar, section_chords = section("tag")
    style.lead(song, first_bar, THEMES["tag"], section_chords, velocity=0.8)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        glass(song, bar, offset, bar_chord, last, fill="tom")
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
