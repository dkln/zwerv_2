"""'Stad woonwijk': the city loop of the neighbourhoods (Bezuidenhout, Bezuidenhout-Oost, Laak):
rough and street, a heavy shuffle.

On the shared plan (stad_plan.py). Broken kick and the gated snare hard on 2 and 4, the slap
bass, palm-muted power-chord chugs, short riffs on the tough motif (M!), the city themes on
the guitar in C and D, the synth lead in B.
Render: tools/megadrive/render.sh stad_woonwijk
"""
import stad_plan
import style
from stad_plan import THEMES, bars_of, section

RIFF = "M! -:8 -:8 M! M! -:8 -:8 M! M! -:8 -:8 M! M! -:8 -:8 M^"


def street(song, bar, offset, bar_chord, last, chug=True, fill="snare"):
    style.bass_bar(song, bar, bar_chord, "slap")
    if chug:
        style.power_chords(song, bar, bar_chord, "chug", 0.7)
    style.drum_bar(song, bar, kick="broken", hats="sixteenths", fill=fill if last else None)


def main() -> None:
    song = stad_plan.new_song("stad_woonwijk_loop.ogg", "stad_woonwijk")
    first_bar, section_chords = section("A")
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        street(song, bar, offset, bar_chord, last, chug=offset >= 4)
    first_bar, section_chords = section("A2")
    style.lead(song, first_bar, RIFF, section_chords)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        street(song, bar, offset, bar_chord, last)
        style.brass_stabs(song, bar, bar_chord, [(7, 1), (10, 1)], 0.7)
    first_bar, section_chords = section("B")
    style.lead(song, first_bar, THEMES["B"], section_chords, harmony=True)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        street(song, bar, offset, bar_chord, last, chug=False, fill="drop")
        style.power_chords(song, bar, bar_chord, "hits", 0.75)
    first_bar, section_chords = section("break")
    style.lead(song, first_bar, THEMES["break"], section_chords, velocity=0.7)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.bass_bar(song, bar, bar_chord, "hold")
        style.pad(song, bar, bar_chord, velocity=0.6)
        style.drum_bar(song, bar, kick="none", snare="half", hats="none" if not last else "eighths",
                       ghosts=False, fill="roll" if last else None)
    first_bar, section_chords = section("C")
    style.guitar(song, first_bar, THEMES["C"], section_chords, twin=True, octave=-1)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        street(song, bar, offset, bar_chord, last, chug=False)
        style.brass_stabs(song, bar, bar_chord, [(4, 1), (12, 1)], 0.75)
    style.crash(song, first_bar)
    first_bar, section_chords = section("D")
    style.guitar(song, first_bar, THEMES["D"], section_chords, velocity=0.8, echo=True)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        street(song, bar, offset, bar_chord, last, chug=offset % 2 == 1)
    first_bar, section_chords = section("tag")
    style.lead(song, first_bar, "M! -:8 -:16 M! -:8 -:16", section_chords)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        street(song, bar, offset, bar_chord, last, fill="tom")
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
