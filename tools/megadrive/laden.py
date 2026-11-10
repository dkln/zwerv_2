"""'Laden': the waiting music of the loading screen (scripts/ui/loading_screen.gd).

House style (style.py), laid back like the merchant's loop (handelaar.py): a slow, heavy shuffle,
the FM slap bass in new jack style, the electric piano pushing and answering the chords, a soft
broken beat with a lazy backbeat, and the tune on the FM lead, relaxed, sliding into its notes,
the PSG answering it the second time round. Nothing hurries: you wait while the town is put
together.

92 BPM, F minor, 16 bars = 41.7 s, heavy swing, loops seamlessly (the loading may take a while).

    bars  1-8   Fm9 Dbmaj7 Bbm9 Ab6 / Fm9 Dbmaj7 Gbmaj7 C7   the tune
    bars  9-16  the same, the PSG answering, a lazy snare fill into the top

Render: tools/megadrive/render.sh laden  (writes assets/audio/muziek/laden_loop.ogg)
"""
import style
from style import Song, chords

CHORDS = chords(["F m9", "Db maj7", "Bb m9", "Ab 6", "F m9", "Db maj7", "Gb maj7", "C 7"])

THEME = """
    M -:2 Ab5:1 G5:1 F5:4
    -:6 C6:2 Bb5:2 Ab5:6
    M -:8
    -:4 Ab5:2 F5:2 Eb5:8
    M -:2 C6:1 Bb5:1 Ab5:4
    -:4 Bb5:2 Db6:2 C6:8
    M! -:8
    -:8 E5:2 G5:2 C6:4
"""


def main() -> None:
    song = Song("laden_loop.ogg", bpm=92, bars=16, swing=0.22)
    for half in range(2):
        first_bar = half * 8
        style.lead(song, first_bar, THEME, CHORDS, velocity=0.6, slides=True, harmony=half == 1)
        for offset, chord in enumerate(CHORDS):
            bar = first_bar + offset
            style.bass_bar(song, bar, chord, "new_jack", velocity=0.7)
            style.piano_bar(song, bar, chord, "answer" if offset % 2 else "push", velocity=0.75)
            style.strings_pad(song, bar, chord, bars=1, velocity=0.3)
            if half == 1:
                style.psg_arpeggio(song, bar, chord, "motif", 0.3, every=2)
            last = half == 1 and offset == 7
            style.drum_bar(song, bar, kick="broken", snare="backbeat", clap=False, hats="sixteenths", ghosts=True,
                           velocity=0.55, hat_volume=0.5, fill="snare" if last else None)
    style.crash(song, 0, volume=0.35)
    song.render(target_rms_db=-16.0)


if __name__ == "__main__":
    main()
