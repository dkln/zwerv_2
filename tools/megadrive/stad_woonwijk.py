"""'Stad woonwijk': the city loop of the neighbourhoods (Bezuidenhout, Bezuidenhout-Oost,
Schilderswijk, Laak, Voorburg): raw, street, a heavy new-jack-swing shuffle.

One of the five neighbourhood loops on the shared plan (stad_plan.py: 104 BPM, F minor, 40 bars
= 92 s). Heavy swing, broken kick with a hard snare and clap, the slap bass in its new-jack
pattern, brass stabs, and the lead in short riffs that keep hitting the tough motif, with a
PSG harmony line under it.

    A      the beat and the bass, brass stabs on the motif's rhythm, no lead
    A'     the lead's street riff (tough motif, answers)
    B      piano chords, the lead and the PSG harmony
    break  only bass, claps and the tough motif twice; a roll back in
    C      the riff theme with brass and PSG arpeggios, extra kicks
    tag    the tough motif, beat and bass, tom fill into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_woonwijk  (writes assets/audio/muziek/stad_woonwijk_loop.ogg)
"""
import stad_plan
import style
from stad_plan import BARS, BPM, SECTIONS, bars_of
from style import Song

THEMES = {
    "A2": """
        M! -:2 F5:1 F5:1 Ab5:2 F5:2
        Gb5:2 F5:2 Db5:4 -:8
        M! -:2 Bb5:1 Bb5:1 Db6:2 Bb5:2
        C6:2 Ab5:2 F5:4 -:8
        M! -:2 F5:1 F5:1 Ab5:2 C6:2
        Db6:4 Bb5:2 Gb5:2 -:8
        M -:2 Eb6:1 C6:1 Ab5:4
        M -:2 G5:1 Bb5:1 C6:4
    """,
    "B": """
        M! Db6:2 C6:2 Bb5:4
        F5:6 Ab5:2 Bb5:8
        M Ab5:4 F5:4
        Db5:8 -:8
        M Eb6:4 C6:4
        Bb5:6 G5:2 Eb5:8
        F5:4 G5:4 Bb5:4 C6:4
        M -:8
    """,
    "break": "M! -:8 -:16 M! -:8 -:16",
    "C": """
        M Db6:2 Bb5:2 Gb5:4
        M Eb6:2 C6:2 Ab5:4
        M! M!
        F5:2 Ab5:2 C6:2 Eb6:2 F6:8
        M Db6:2 Bb5:2 Gb5:4
        M Eb6:2 C6:2 Ab5:4
        M Db6:2 C6:2 Bb5:4
        M E6:8
    """,
    "tag": "M! -:8 -:16 M! -:8 -:16",
}


def main() -> None:
    song = Song("stad_woonwijk_loop.ogg", bpm=BPM, bars=BARS, swing=0.24)
    for name, first_bar, section_chords in SECTIONS:
        if name in THEMES:
            style.lead(song, first_bar, THEMES[name], section_chords, harmony=name == "B")
        if name in ("A", "C"):
            style.crash(song, first_bar, volume=0.8)
        for bar, offset, chord, last in bars_of(first_bar, section_chords):
            if name == "break":
                style.bass_bar(song, bar, chord, "new_jack", velocity=0.8)
                for step in (4, 12):
                    song.pcm.add(song.at(bar, step), style.CLAP, 0.7)
                if last:
                    style.drum_bar(song, bar, kick="none", snare="none", hats="sixteenths", hat_volume=0.6, fill="roll")
                else:
                    style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", hat_volume=0.5, ghosts=False)
                continue
            style.bass_bar(song, bar, chord, "new_jack")
            if name in ("A", "tag"):
                style.brass_stabs(song, bar, chord, [(0, 2), (2, 1), (3, 1), (4, 4)] if offset % 2 == 0 else [(10, 1), (14, 2)], 0.85)
            elif name == "A2":
                style.brass_stabs(song, bar, chord, [(10, 1), (14, 2)], 0.75)
            elif name == "B":
                style.piano_bar(song, bar, chord, "answer" if offset % 2 else "push", velocity=0.9)
            else:   # C
                style.brass_stabs(song, bar, chord, [(-2, 2), (0, 1), (3, 1), (6, 2)] if offset % 2 == 0 else [(10, 1), (12, 2)])
                style.psg_arpeggio(song, bar, chord, "motif", 0.55)
            fill = "tom" if name == "tag" and last else ("snare" if last else None)
            style.drum_bar(song, bar, kick="broken", snare="backbeat", clap=True, hats="sixteenths", fill=fill)
            if name == "C":
                song.pcm.add(song.at(bar, 3), style.KICK, 0.6)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
