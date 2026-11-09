"""'Laden': the waiting music of the loading screen (scripts/ui/loading_screen.gd).

House style (style.py), light and bouncy like the hold music of an old console while the town is
put together: the electric piano on the off-beats, a PSG arpeggio ticking like a clock, the
lyrical bass, a soft broken beat with a clap, and a cheerful little tune on the FM lead built
on the motif, every other phrase answered by the PSG.

112 BPM, F minor, 16 bars = 34 s, a little swing, loops seamlessly (the loading may take a while).

    bars  1-8   Fm9 Dbmaj7 Bbm9 Csus / Fm9 Dbmaj7 Gbmaj7 C7   the tune
    bars  9-16  the same, the PSG answering the tune, a fill into the top

Render: tools/megadrive/render.sh laden  (writes assets/audio/muziek/laden_loop.ogg)
"""
import megadrive
import style
from style import Song, chords

CHORDS = chords(["F m9", "Db maj7", "Bb m9", "C sus", "F m9", "Db maj7", "Gb maj7", "C 7"])

THEME = " ".join([
    "M 5:4 3:4",
    "R:6 -:2 3:4 5:4",
    "M 8:8",
    "5:8 -:8",
    "M 3:4 5:4",
    "8:6 -:2 9:4 8:4",
    "M 5:8",
    "3:12 -:4",
])


def main() -> None:
    song = Song("laden_loop.ogg", bpm=112, bars=16, swing=0.08)
    for half in range(2):
        first_bar = half * 8
        style.lead(song, first_bar, THEME, CHORDS, velocity=0.6, echo=half == 1)
        for offset, chord in enumerate(CHORDS):
            bar = first_bar + offset
            style.piano_bar(song, bar, chord, "offbeats", velocity=0.7)
            style.psg_arpeggio(song, bar, chord, "up", 0.3, every=2)
            style.bass_bar(song, bar, chord, "lyrical", velocity=0.6)
            style.strings_pad(song, bar, chord, bars=1, velocity=0.4)
            last = half == 1 and offset == 7
            style.drum_bar(song, bar, kick="broken", snare="none", clap=True, hats="eighths", ghosts=False,
                           velocity=0.45, hat_volume=0.45, fill="tom" if last else None)
            # the clock: a soft tick on every beat, high on the PSG
            for step in (0, 4, 8, 12):
                song.psg_two.add(song.at(bar, step), megadrive.psg_square(
                    96.0 if step % 8 == 0 else 91.0, song.sixteenths(0.4), 0.18, decay=0.03, sustain=0.0, release=0.02))
    song.render(target_rms_db=-16.0)


if __name__ == "__main__":
    main()
