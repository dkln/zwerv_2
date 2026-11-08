"""'Karakterkeuze': soft loop under the character creation screen.

House style (style.py), turned down: FM strings and electric piano, a slow PSG arpeggio, a
soft broken beat (no four-on-the-floor) and the motif on the FM lead, gently, every four bars.

96 BPM, F minor, 16 bars = 40 s, light swing, loops seamlessly.

    bars  1-8   Fm9 Gbmaj7 Bbm9 Fm9 / Abmaj7 Gbmaj7 Bbm9 Csus   the motif in bars 1 and 5
    bars  9-16  the same with a soft beat and a PSG counter-line; the motif in bars 9 and 13

Render: tools/megadrive/render.sh karakterkeuze  (writes assets/audio/muziek/karakterkeuze_loop.ogg)
"""
import style
from style import Song, chords

CHORDS = chords(["F m9", "Gb maj7", "Bb m9", "F m9", "Ab maj7", "Gb maj7", "Bb m9", "C sus"])

THEME = """
    M 3:6 -:2
    Bb5:8 -:8
    -:16
    -:16
    M 5:4 3:4
    Bb5:6 Ab5:2 F5:8
    -:16
    -:8 G5:4 Bb5:4
"""


def main() -> None:
    song = Song("karakterkeuze_loop.ogg", bpm=96, bars=16, swing=0.1)
    for half in range(2):
        first_bar = half * 8
        style.lead(song, first_bar, THEME, CHORDS, velocity=0.62)
        for offset, chord in enumerate(CHORDS):
            bar = first_bar + offset
            style.strings_pad(song, bar, chord, bars=1, velocity=0.8)
            style.piano_bar(song, bar, chord, "sparse", velocity=0.85)
            style.psg_arpeggio(song, bar, chord, "up", 0.45, every=2)
            style.bass_bar(song, bar, chord, "whole", velocity=0.7)
            if half == 1:
                style.drum_bar(song, bar, kick="broken", snare="none", hats="eighths", ghosts=False,
                               velocity=0.5, hat_volume=0.55)
                song.pcm.add(song.at(bar, 12), style.SNARE, 0.3)
                # a quiet PSG line, a chord tone under the pad's top
                top = chord.voicing[-1] + 12
                song.psg_two.add(song.at(bar, 8), style.megadrive.psg_square(
                    chord.tone_below(top, 1), song.sixteenths(7), 0.5, decay=0.5, sustain=0.5, release=0.2))
            else:
                style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", ghosts=False,
                               hat_volume=0.35 if offset >= 4 else 0.0)
    song.render(target_rms_db=-16.0)


if __name__ == "__main__":
    main()
