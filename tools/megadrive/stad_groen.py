"""'Stad groen': the city loop of the parks (Malieveld, Koekamp): calmer and spacious, few drums.

One of the five neighbourhood loops on the shared plan (stad_plan.py: 104 BPM, F minor, 40 bars
= 92 s). Felt in half time: FM strings carry it, electric piano and FM bells in sparse
chords, a long held bass, PSG twinkles and a PSG line in long notes; the lead sings the motif
gently with space around it. Drums only as soft hats and a light broken kick in the fuller parts.

    A      strings, piano, twinkles; the motif on bar 5
    A'     the lead's slow theme, soft hats come in
    B      a light broken beat, the PSG line, the lead in answer phrases
    break  only strings and bells, the motif softly
    C      the fullest: broken beat, brass pad, the theme on the motif
    tag    strings and twinkles, nearly bare, into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_groen  (writes assets/audio/muziek/stad_groen_loop.ogg)
"""
import megadrive
import stad_plan
import style
from stad_plan import BARS, BPM, SECTIONS, bars_of
from style import Song

THEMES = {
    "A": "-:16 -:16 -:16 -:16 M 3:6 -:2 Db6:8 Bb5:8 M -:8 -:16",
    "A2": """
        M 5:8
        Bb5:16
        M R:8
        Ab5:8 G5:8
        M! -:8
        Db6:12 -:4
        M C6:8
        E5:8 G5:8
    """,
    "B": """
        -:16
        M Db6:8
        -:16
        Bb5:8 Ab5:8
        M -:8
        G5:16
        F5:8 G5:8
        E5:16
    """,
    "break": "M -:8 -:16 -:16 -:16",
    "C": """
        M Db6:8
        C6:16
        M C6:8
        Ab5:12 -:4
        M F5:8
        Eb6:16
        M -:8
        M -:8
    """,
}


def main() -> None:
    song = Song("stad_groen_loop.ogg", bpm=BPM, bars=BARS, swing=0.08)
    for name, first_bar, section_chords in SECTIONS:
        if name in THEMES:
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.7, slides=True)
        for bar, offset, chord, last in bars_of(first_bar, section_chords):
            style.strings_pad(song, bar, chord, bars=1, velocity=0.85)
            style.bass_bar(song, bar, chord, "whole", velocity=0.65)
            if name != "break":
                style.piano_bar(song, bar, chord, "sparse", velocity=0.8)
                style.psg_arpeggio(song, bar, chord, "twinkle", 0.4)
            if offset % 2 == 0 or name == "break":
                top = max(chord.voicing) + 24
                song.piano.add(song.at(bar, 8), megadrive.fm_note(style.BELL, float(top), song.sixteenths(6), 0.5))
            if name in ("B", "C"):   # the PSG line: one long chord tone a bar
                song.psg_two.add(song.at(bar, 0), megadrive.psg_square(
                    chord.tone_below(max(chord.voicing) + 12, 1), song.sixteenths(14), 0.55, decay=0.8, sustain=0.6,
                    release=0.3))
            if name == "C":
                style.brass_pad(song, bar, chord, bars=1, velocity=0.45)
            if name in ("B", "C"):
                style.drum_bar(song, bar, kick="broken", snare="none", hats="eighths", ghosts=False,
                               velocity=0.55, hat_volume=0.6, fill="drop" if last and name == "B" else None)
                song.pcm.add(song.at(bar, 12), style.CLAP, 0.35)
            elif name == "A2":
                style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", ghosts=False, hat_volume=0.45)
            elif name == "tag" and last:
                for step, tom_index in ((12, 0), (14, 1)):
                    song.pcm.add(song.at(bar, step), style.TOMS[tom_index], 0.45)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
