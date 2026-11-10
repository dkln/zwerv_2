"""'Stad dorp': the city loop of the village (Voorburg): folky.

On the shared plan (stad_plan.py). A plucked FM voice strums the chords like a guitar, the
walking bass, soft brushes (the PSG noise in eighths) from B, a simple tune on the chiptune
lead, the city theme on the synth lead in C.
Render: tools/megadrive/render.sh stad_dorp
"""
import stad_plan
import style
from stad_plan import THEMES, bars_of, section

STRUM = (0, 1, 2, 6, 8, 9, 10, 14)


def village(song, bar, offset, bar_chord, last, brushes=False):
    style.bass_bar(song, bar, bar_chord, "walking")
    style.pluck_chord(song, bar, bar_chord, STRUM, 0.55, track=song.harmony)
    if brushes:
        style.drum_bar(song, bar, kick="half", snare="none", hats="eighths", hat_volume=0.45, ghosts=False)
        song.pcm.add(song.at(bar, 4), style.PLAIN_SNARE, 0.25)
        song.pcm.add(song.at(bar, 12), style.PLAIN_SNARE, 0.3)


def main() -> None:
    song = stad_plan.new_song("stad_dorp_loop.ogg", "stad_dorp")
    for name in ("A", "A2", "B", "break", "C", "D", "tag"):
        first_bar, section_chords = section(name)
        if name in ("A2", "D"):
            style.chip_lead(song, first_bar, THEMES[name], section_chords, volume=0.65, vibrato=0.15)
        elif name in ("B", "C"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.8, slides=True)
        elif name in ("break", "tag"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.65, patch=style.PLUCK, track=song.pad)
        for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
            if name == "break":
                style.pad(song, bar, bar_chord, velocity=0.6)
                style.bass_bar(song, bar, bar_chord, "hold")
                continue
            village(song, bar, offset, bar_chord, last, brushes=name in ("B", "C", "D", "tag"))
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
