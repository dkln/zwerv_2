"""'Stad bos': the city loop of the woods (the Koekamp, the deer park at the Haagse Bos):
the calmest of all, trees and deer in the dark.

One of the city loops on the shared plan (stad_plan.py: 104 BPM, F minor, 40 bars = 92 s).
No drums: soft FM strings, a held bass, FM bells far apart, PSG birds now and then (quick
chirps sweeping up, high), and a gentle lead only in A' and C, in long notes.

    A      strings, bass, bells; birds
    A'     the lead's slow theme
    B      the bells closer together, more birds
    break  strings alone, one bell
    C      the theme again, the PSG under it
    tag    strings and a last bird into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_bos  (writes assets/audio/muziek/stad_bos_loop.ogg)
"""
import megadrive
import stad_plan
import style
from stad_plan import BARS, BPM, SECTIONS, bars_of, theme
from style import Song

THEMES = {
    "A2": theme("-:8 5:8", "3:16", "-:8 R:8", "5:16", "-:8 8:8", "5:16", "3:8 5:8", "R:16"),
    "C": theme("-:8 5:8", "3:16", "-:8 9:8", "8:16", "-:8 5:8", "3:16", "5:8 3:8", "R:16"),
}
## Bars with a bird (bar: step), heard as from the trees.
BIRDS = {2: 6, 5: 10, 11: 3, 18: 6, 20: 12, 22: 4, 30: 9, 33: 2, 38: 7}


def bird(song, bar, step):
    """A chirp: two quick PSG sweeps up, high and soft."""
    for offset in (0, 0.75):
        song.psg_one.add(song.at(bar, step + offset), megadrive.psg_sweep(98.0, 103.0, 0.06, 0.25))


def main() -> None:
    song = Song("stad_bos_loop.ogg", bpm=BPM, bars=BARS)
    for name, first_bar, section_chords in SECTIONS:
        if name in THEMES:
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.5, slides=True,
                       harmony=name == "C")
        for bar, offset, chord, last in bars_of(first_bar, section_chords):
            style.strings_pad(song, bar, chord, bars=1, velocity=0.75)
            style.bass_bar(song, bar, chord, "whole", velocity=0.5)
            top = max(chord.voicing) + 24
            if offset % 2 == 0 or name == "B":
                song.piano.add(song.at(bar, 4 if name != "B" else 8), megadrive.fm_note(style.BELL, float(top), song.sixteenths(8), 0.35))
            if bar in BIRDS:
                bird(song, bar, BIRDS[bar])
    stad_plan.finish(song, target_rms_db=-18.5)


if __name__ == "__main__":
    main()
