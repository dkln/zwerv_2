"""'Handelaar': the loop at a merchant. Laid-back new jack swing, only synths, a bit of a smirk.

House style (style.py): heavy swing, broken kick, FM slap bass, electric piano carrying the
chords, a PSG counter-line, the motif on the FM lead in a relaxed register.

128 BPM, F minor, 16 bars = 30 s, loops seamlessly.

    bars  1-8   Fm9 Gbmaj7 Bbm9 Ab6 twice: piano, bass, the motif in bars 1, 3, 5 and 7
    bars  9-16  Gbmaj7 Ab6 Fm9 Fm9 / Gbmaj7 Ab6 Bbm9 C7: lead answers, PSG harmony, a snare fill home

Render: tools/megadrive/render.sh handelaar  (writes assets/audio/muziek/handelaar_loop.ogg)
"""
import style
from style import Song, chords

A_CHORDS = chords(["F m9", "Gb maj7", "Bb m9", "Ab 6", "F m9", "Gb maj7", "Bb m9", "Ab 6"])
B_CHORDS = chords(["Gb maj7", "Ab 6", "F m9", "F m9", "Gb maj7", "Ab 6", "Bb m9", "C 7"])

A_THEME = """
    M -:2 Ab5:1 G5:1 F5:4
    -:4 Db6:2 Bb5:2 F5:8
    M -:4 Db6:2 C6:2
    Ab5:8 -:8
    M -:2 C6:1 Bb5:1 Ab5:4
    -:4 Bb5:2 Db6:2 F6:8
    M! -:8
    -:8 Eb6:2 C6:2 Ab5:4
"""
B_THEME = """
    Bb5:6 Ab5:2 F5:4 Gb5:4
    Ab5:6 C6:2 Eb6:8
    M 3:4 R:4
    -:16
    Db6:6 C6:2 Bb5:4 F5:4
    Eb6:6 C6:2 Ab5:8
    M Db6:4 C6:4
    M -:8
"""


def main() -> None:
    song = Song("handelaar_loop.ogg", bpm=128, bars=16, swing=0.22)
    style.lead(song, 0, A_THEME, A_CHORDS, velocity=0.85, slides=True)
    style.lead(song, 8, B_THEME, B_CHORDS, velocity=0.85, slides=True, harmony=True)
    for offset, chord in enumerate(A_CHORDS + B_CHORDS):
        bar = offset
        style.bass_bar(song, bar, chord, "new_jack")
        style.piano_bar(song, bar, chord, "answer" if offset % 2 else "push", velocity=1.0)
        if offset >= 8:
            style.psg_arpeggio(song, bar, chord, "motif", 0.4, every=2)
        last = offset == 15
        style.drum_bar(song, bar, kick="broken", snare="backbeat", clap=offset >= 8, hats="sixteenths",
                       fill="snare" if last else None, hat_volume=0.8)
    style.crash(song, 0, volume=0.6)
    song.render()


if __name__ == "__main__":
    main()
