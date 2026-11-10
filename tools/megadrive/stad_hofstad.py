"""'Stad hofstad': the city loop of the court quarter (Paleis Noordeinde, Lange Voorhout):
stately, without a beat.

On the shared plan (stad_plan.py). The warm pad, a harpsichord-like plucked FM arpeggio up and
down, a bell on the one, timpani (the low tom) at the turns of the sections, a noble melody
on the FM brass, the synth lead in C, the chiptune lead softly in D.
Render: tools/megadrive/render.sh stad_hofstad
"""
import stad_plan
import style
from stad_plan import THEMES, bars_of, section

HARPSICHORD_STEPS = (0, 2, 4, 6, 8, 10, 12, 14)


def court(song, bar, offset, bar_chord, last):
    style.pad(song, bar, bar_chord, velocity=0.75)
    style.bass_bar(song, bar, bar_chord, "whole")
    style.pluck_chord(song, bar, bar_chord, HARPSICHORD_STEPS, 0.55, track=song.harmony)
    style.bells(song, bar, [bar_chord.melody_root + 12], (0,), 0.4)
    if last:
        for step, velocity in ((8, 0.6), (12, 0.75), (14, 0.85)):
            song.pcm.add(song.at(bar, step), style.TOMS[2], velocity)


def main() -> None:
    song = stad_plan.new_song("stad_hofstad_loop.ogg", "stad_hofstad")
    for name in ("A", "A2", "B", "break", "C", "D", "tag"):
        first_bar, section_chords = section(name)
        if name in ("A2", "B"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.85, patch=style.BRASS, track=song.brass)
        elif name == "C":
            style.lead(song, first_bar, THEMES["C"], section_chords, velocity=0.8, slides=True)
        elif name == "D":
            style.chip_lead(song, first_bar, THEMES["D"], section_chords, volume=0.6, vibrato=0.18)
        elif name in ("break", "tag"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.7, patch=style.CHIME, track=song.pad)
        for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
            court(song, bar, offset, bar_chord, last)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
