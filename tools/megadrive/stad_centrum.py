"""'Stad centrum': the city loop of the old town (Centrum and the neighbourhoods without a loop
of their own): lively 16-bit synthwave, the shopping streets at night.

On the shared plan (stad_plan.py: in synthwave_rpg 120 BPM, D minor, 48 bars = 96 s).
    A      groove: solid bass in sixteenths with octave jumps, the PSG arpeggio, brass stabs on
           2 and 4, tight kick and gated snare
    A2     + the city theme on the synth lead with the PSG echo
    B      power chords, the climbing theme
    break  pad, the motif softly twice, a roll
    C      the peak: the theme on the lead, the twin guitars an octave down, brass, claps
    D      the lyrical theme on the guitar with its tape delay, pads
    tag    the groove, the motif once more, a tom fill to the top
Render: tools/megadrive/render.sh stad_centrum
"""
import stad_plan
import style
from stad_plan import THEMES, bars_of, section

PIECE = style.piece("stad_centrum")


def groove(song, bar, offset, bar_chord, last, fill="snare", hats="sixteenths", clap=False):
    style.bass_bar(song, bar, bar_chord, "solid_turn" if offset % 4 == 3 else "solid")
    style.arpeggio(song, bar, bar_chord, "up", 0.55)
    style.brass_stabs(song, bar, bar_chord, velocity=0.8)
    style.drum_bar(song, bar, kick="four", hats=hats, clap=clap, fill=fill if last else None)


def main() -> None:
    song = stad_plan.new_song("stad_centrum_loop.ogg", "stad_centrum")
    first_bar, section_chords = section("A")
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        groove(song, bar, offset, bar_chord, last)
    style.crash(song, first_bar)

    first_bar, section_chords = section("A2")
    style.lead(song, first_bar, THEMES["A2"], section_chords, echo=True)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        groove(song, bar, offset, bar_chord, last, clap=True)

    first_bar, section_chords = section("B")
    style.lead(song, first_bar, THEMES["B"], section_chords, slides=True)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.bass_bar(song, bar, bar_chord, "solid")
        style.power_chords(song, bar, bar_chord, "push", 0.75)
        style.arpeggio(song, bar, bar_chord, "updown", 0.4, octave=1, every=2, track=song.psg_three)
        style.drum_bar(song, bar, kick="four", clap=True, hats="open", fill="drop" if last else None)
    style.crash(song, first_bar)

    first_bar, section_chords = section("break")
    style.lead(song, first_bar, THEMES["break"], section_chords, velocity=0.7)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.pad(song, bar, bar_chord)
        style.bass_bar(song, bar, bar_chord, "hold")
        style.arpeggio(song, bar, bar_chord, "twinkle", 0.4)
        if last:
            style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", hat_volume=0.6, fill="roll")

    first_bar, section_chords = section("C")
    style.lead(song, first_bar, THEMES["C"], section_chords, echo=True)
    if PIECE["guitar"]:
        style.guitar(song, first_bar, THEMES["C"], section_chords, velocity=0.65, twin=True, octave=-1)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.bass_bar(song, bar, bar_chord, "solid_turn" if offset % 2 else "solid")
        style.brass_stabs(song, bar, bar_chord, [(-2, 2), (4, 1), (12, 1)] if offset % 2 == 0 else [(4, 1), (10, 1), (12, 2)])
        style.arpeggio(song, bar, bar_chord, "rolling", 0.45, octave=1, track=song.psg_three)
        style.drum_bar(song, bar, kick="push", clap=True, hats="open", fill="snare" if last else None)
    style.crash(song, first_bar)

    first_bar, section_chords = section("D")
    style.guitar(song, first_bar, THEMES["D"], section_chords, velocity=0.75, echo=True)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.pad(song, bar, bar_chord, velocity=0.7)
        style.bass_bar(song, bar, bar_chord, "lyrical")
        style.arpeggio(song, bar, bar_chord, "up", 0.35, every=2)
        style.drum_bar(song, bar, kick="rock", hats="eighths", fill="snare" if last else None)
    style.crash(song, first_bar, volume=0.7)

    first_bar, section_chords = section("tag")
    style.lead(song, first_bar, THEMES["tag"], section_chords, velocity=0.85)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        groove(song, bar, offset, bar_chord, last, fill="tom")
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
