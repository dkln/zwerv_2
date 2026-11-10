"""'Stad groen': the city loop of the parks (Malieveld): calm and wide.

On the shared plan (stad_plan.py). Half-time feeling: the kick on one and the "and" of three,
the snare only in B and C, long held bass, the warm pad, bells on the motif, the chiptune lead
softly in A2, the synth lead in C, the lyrical theme on the bells in D.
Render: tools/megadrive/render.sh stad_groen
"""
import stad_plan
import style
from stad_plan import THEMES, bars_of, section


def calm(song, bar, offset, bar_chord, snare="none"):
    style.bass_bar(song, bar, bar_chord, "hold")
    if offset % 2 == 0:
        style.pad(song, bar, bar_chord, bars=2, velocity=0.75)
    style.arpeggio(song, bar, bar_chord, "up", 0.3, every=2)
    style.drum_bar(song, bar, kick="half", snare=snare if snare != "none" else "none", hats="eighths",
                   hat_volume=0.45, ghosts=False)


def main() -> None:
    song = stad_plan.new_song("stad_groen_loop.ogg", "stad_groen")
    for name in ("A", "A2", "B", "break", "C", "D", "tag"):
        first_bar, section_chords = section(name)
        if name == "A2":
            style.chip_lead(song, first_bar, THEMES["A2"], section_chords, volume=0.6, vibrato=0.2)
        elif name in ("B", "C"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.75, slides=True)
        elif name == "D":
            style.lead(song, first_bar, THEMES["D"], section_chords, velocity=0.7, patch=style.BELL, track=song.pad)
        elif name in ("break", "tag"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.6, patch=style.CHIME, track=song.pad)
        for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
            if name == "break":
                style.pad(song, bar, bar_chord)
                style.bass_bar(song, bar, bar_chord, "whole")
                style.arpeggio(song, bar, bar_chord, "twinkle", 0.35)
                continue
            calm(song, bar, offset, bar_chord, snare="half" if name in ("B", "C") else "none")
            if offset % 4 == 0:
                style.bells(song, bar, style.motif_notes(bar_chord, octave=1), (0, 2, 3, 4), 0.4)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
