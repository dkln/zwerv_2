"""'Stad centrum': the city loop of the old town (Centrum, Grote Markt, Paleis Noordeinde,
Lange Voorhout): funky and lively, shopping streets at night.

One of the five neighbourhood loops on the shared plan (stad_plan.py: 104 BPM, F minor, 40 bars
= 92 s, the same chords, so the HUD can crossfade between them). Club house with a light
new-jack-swing shuffle, FM slap bass, FM electric piano, brass and strings, the motif on the FM
lead, PSG arpeggios, echo and harmony line, PCM drums and PSG-noise hats.

    A      groove: bass, electric piano, PSG arpeggio, snare
    A'     + the lead's theme, built on the motif
    B      brass pads, the second theme (motif first), PSG harmony line
    break  no kick, FM strings, the motif softly twice, a snare roll to build up
    C      peak: riff theme with a PSG echo, brass stabs, open hats
    tag    the A groove, thinner, the motif once more, tom fill into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_centrum  (writes assets/audio/muziek/stad_centrum_loop.ogg)
"""
import stad_plan
import style
from stad_plan import A_CHORDS, B_CHORDS, BARS, BPM, BREAK_CHORDS, C_CHORDS, TAG_CHORDS
from style import Song

A_THEME = """
    M -:2 Eb5:1 F5:1 Ab5:2 G5:2
    Bb5:6 Ab5:2 Gb5:2 F5:2 Db5:4
    M Db6:3 C6:1 Bb5:2 Ab5:2
    F5:10 -:2 C5:1 Eb5:1 F5:2
    M! -:2 F5:1 Ab5:1 C6:4
    Db6:4 Bb5:2 Gb5:2 Ab5:4 Bb5:4
    M C6:2 Eb6:2 C6:2 Ab5:2
    M -:2 E5:1 G5:1 Bb5:4
"""
B_THEME = """
    M F5:4 Db5:2 C5:2
    Eb5:6 F5:2 C5:8
    Bb5:8 F5:4 Gb5:2 Ab5:2
    F5:12 -:4
    Ab5:4 C6:4 F6:4 Eb6:2 Db6:2
    Eb6:6 Bb5:2 G5:4 Bb5:4
    C6:4 F5:4 G5:4 Bb5:4
    G5:2 E5:2 C5:2 Bb4:2 E5:4 G5:4
"""
BREAK_THEME = "M -:8 -:16 M -:8 -:16"
C_THEME = """
    F5:1 Bb5:1 Db6:2 Bb5:1 Db6:1 Eb6:2 Db6:1 Bb5:1 Gb5:2 F5:2 Gb5:2
    Ab5:1 C6:1 Eb6:2 C6:1 Eb6:1 F6:2 Eb6:1 C6:1 Ab5:2 C6:4
    M C6:4 Bb5:2 Ab5:2
    F5:10 -:2 C5:1 Eb5:1 F5:2
    M Db6:2 Bb5:2 Db6:2 F6:2
    Eb6:1 F6:1 Eb6:2 C6:1 Ab5:1 Eb6:2 C6:2 Ab5:2 C6:4
    M Db6:2 C6:2 Bb5:2 G5:2
    M E6:6 -:2
"""
TAG_THEME = "M -:8 -:16 -:16 -:16"


def main() -> None:
    song = Song("stad_centrum_loop.ogg", bpm=BPM, bars=BARS, swing=0.14)

    # A: groove only
    for offset, chord in enumerate(A_CHORDS):
        bar = offset
        style.bass_bar(song, bar, chord, "funk_turn" if offset % 2 else "funk")
        style.piano_bar(song, bar, chord, "answer" if offset % 2 else "push")
        style.psg_arpeggio(song, bar, chord, "up", 0.75)
        style.drum_bar(song, bar, fill="snare" if offset == 7 else None)
    style.crash(song, 0)

    # A': the theme
    style.lead(song, 8, A_THEME, A_CHORDS)
    for offset, chord in enumerate(A_CHORDS):
        bar = 8 + offset
        style.bass_bar(song, bar, chord, "funk_turn" if offset % 2 else "funk")
        style.piano_bar(song, bar, chord, "answer" if offset % 2 else "push")
        style.psg_arpeggio(song, bar, chord, "up_octave", 0.5)
        style.drum_bar(song, bar, clap=True, fill="snare" if offset == 7 else None)
        if offset % 4 == 3:
            song.pcm.add(song.at(bar, 14), style.KICK, 0.55)
    style.crash(song, 8)

    # B: brass pads, second theme with a harmony line
    style.lead(song, 16, B_THEME, B_CHORDS, harmony=True, slides=True)
    for offset, chord in enumerate(B_CHORDS):
        bar = 16 + offset
        style.bass_bar(song, bar, chord, "lyrical")
        if offset in (0, 2):
            style.brass_pad(song, bar, chord, bars=2)
        elif offset >= 4:
            style.brass_pad(song, bar, chord, bars=1)
        style.drum_bar(song, bar, snare="none", clap=True, hats="eighths", ghosts=False,
                       fill="drop" if offset == 7 else None)

    # break: strings, long bass, twinkling PSG, the motif softly, a roll into C
    style.lead(song, 24, BREAK_THEME, BREAK_CHORDS, velocity=0.7)
    for offset, chord in enumerate(BREAK_CHORDS):
        bar = 24 + offset
        style.bass_bar(song, bar, chord, "hold")
        if offset in (0, 2, 3):
            style.strings_pad(song, bar, chord, bars=2 if offset == 0 else 1)
        style.piano_bar(song, bar, chord, "sparse")
        style.psg_arpeggio(song, bar, chord, "twinkle", 0.45)
        if offset == 2:
            style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", hat_volume=0.5, ghosts=False)
        if offset == 1:
            song.pcm.add(song.at(bar, 12), style.CLAP, 0.5)
        if offset == 3:
            style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", hat_volume=0.6, fill="roll")

    # C: the peak
    style.lead(song, 28, C_THEME, C_CHORDS, echo=True)
    for offset, chord in enumerate(C_CHORDS):
        bar = 28 + offset
        style.bass_bar(song, bar, chord, "house")
        style.brass_stabs(song, bar, chord, [(-2, 2), (0, 1), (3, 1), (6, 2)] if offset % 2 == 0 else [(10, 1), (12, 2)])
        style.psg_arpeggio(song, bar, chord, "updown", 0.75)
        style.drum_bar(song, bar, kick="push", clap=True, hats="open", fill="snare" if offset == 7 else None)
    style.crash(song, 28)

    # tag: back to the groove, tom fill into the top
    style.lead(song, 36, TAG_THEME, TAG_CHORDS, velocity=0.85)
    for offset, chord in enumerate(TAG_CHORDS):
        bar = 36 + offset
        style.bass_bar(song, bar, chord, "funk_turn" if offset % 2 else "funk")
        style.piano_bar(song, bar, chord, "answer" if offset % 2 else "push")
        style.psg_arpeggio(song, bar, chord, "up", 0.75, every=2)
        style.drum_bar(song, bar, fill="tom" if offset == 3 else None)

    stad_plan.finish(song)


if __name__ == "__main__":
    main()
