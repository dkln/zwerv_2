"""'Stad bos': the city loop of the woods (Koekamp, the deer camp by the Haagse Bos): the
calmest of all, no drums.

On the shared plan (stad_plan.py). The warm pad, a long bass, bells far apart, little PSG
birds now and then, the chime on the motif in the break and the tag, the lead only in A2 and C.
Render: tools/megadrive/render.sh stad_bos
"""
import megadrive
import stad_plan
import style
from stad_plan import THEMES, bars_of, section

## Where a bird sings (bar, step) and its little call (pitches, high on the PSG).
BIRDS = [(3, 6), (10, 12), (19, 2), (26, 8), (33, 10), (41, 4), (46, 9)]
CALL = (96, 100, 98, 103)


def main() -> None:
    song = stad_plan.new_song("stad_bos_loop.ogg", "stad_bos")
    for name in ("A", "A2", "B", "break", "C", "D", "tag"):
        first_bar, section_chords = section(name)
        if name in ("A2", "C"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.6, slides=True)
        elif name in ("break", "tag"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.55, patch=style.CHIME, track=song.pad)
        for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
            if offset % 2 == 0:
                style.pad(song, bar, bar_chord, bars=2, velocity=0.7)
            style.bass_bar(song, bar, bar_chord, "whole", velocity=0.7)
            if offset % 4 == 2:
                style.bells(song, bar, [bar_chord.melody_root + 12, bar_chord.melody_root + 7], (0, 8), 0.35)
    for bar, step in BIRDS:
        for index, pitch in enumerate(CALL):
            song.psg_one.add(song.at(bar, step + index * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.4), 0.35,
                                                                                    decay=0.03, sustain=0.0))
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
