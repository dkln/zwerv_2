"""'Stad dorp': the city loop of the village (Voorburg, the old village over the motorway):
gentle and homely, a church tower, a canal, quiet streets.

One of the city loops on the shared plan (stad_plan.py: 104 BPM, F minor, 40 bars = 92 s).
Folky: the PSG picks the chords like a guitar (every other sixteenth), the electric piano in
sparse chords, a held bass, soft brushes (quiet hats, a half-time kick) from B on, and a
simple lead tune that keeps coming back to the motif.

    A      picking, piano, bass
    A'     the lead's tune
    B      brushes come in, strings
    break  picking alone, the motif once
    C      the tune again with the PSG harmony, brushes
    tag    picking and piano into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_dorp  (writes assets/audio/muziek/stad_dorp_loop.ogg)
"""
import stad_plan
import style
from stad_plan import BARS, BPM, SECTIONS, bars_of, theme
from style import Song

THEMES = {
    "A2": theme("M 3:8", "5:8 3:8", "M R:8", "3:12 -:4", "M 5:8", "8:8 5:8", "M 3:8", "R:12 -:4"),
    "B": theme("5:8 8:8", "5:16", "3:8 5:8", "R:16", "5:8 8:8", "9:8 8:8", "5:8 3:8", "5:12 -:4"),
    "break": theme("-:16", "M -:8", "-:16", "-:16"),
    "C": theme("M 3:8", "5:8 3:8", "M R:8", "3:12 -:4", "M 5:8", "8:8 5:8", "M 3:8", "R:12 -:4"),
}


def main() -> None:
    song = Song("stad_dorp_loop.ogg", bpm=BPM, bars=BARS, swing=0.04)
    for name, first_bar, section_chords in SECTIONS:
        if name in THEMES:
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.6,
                       harmony=name == "C")
        for bar, offset, chord, last in bars_of(first_bar, section_chords):
            style.psg_arpeggio(song, bar, chord, "up_octave", 0.3, every=2)
            if name != "break":
                style.piano_bar(song, bar, chord, "sparse", velocity=0.7)
                style.bass_bar(song, bar, chord, "hold", velocity=0.55)
            if name in ("B", "C"):
                style.strings_pad(song, bar, chord, bars=1, velocity=0.5)
                style.drum_bar(song, bar, kick="half", snare="none", hats="eighths", ghosts=False,
                               velocity=0.45, hat_volume=0.4)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
