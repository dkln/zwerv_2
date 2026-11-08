"""'Gevecht': the battle loop. Fast and tough: the tough motif hammered on lead and brass.

House style (style.py), at full tilt: 16th synth bass, galloping kick, brass stabs on the
motif's rhythm, fast PSG arpeggios, tom fills.

150 BPM, F minor, 32 bars = 51.2 s, straight, loops seamlessly.

    bars  1-8   A   Fm Gb Fm Gb / Bbm Gb C7 C7: the tough motif on lead and brass, call and answer
    bars  9-16  B   the theme on the lead, PSG echo, open hats
    bars 17-24  C   half-time: heavy kick and snare, the motif traded between lead and PSG
    bars 25-32  A'  A again with the theme an octave up and a tom fill back to the top

Render: tools/megadrive/render.sh gevecht  (writes assets/audio/muziek/gevecht_loop.ogg)
"""
import style
from style import Song, chords

A_CHORDS = chords(["F m7", "Gb maj", "F m7", "Gb maj", "Bb m7", "Gb maj", "C 7", "C 7"])
C_CHORDS = chords(["Bb m7", "Bb m7", "Gb maj7", "Gb maj7", "Ab maj", "Ab maj", "C 7", "C 7"])

A_HITS = "M! -:8 M -:8 M! M! M -:8 M! -:8 M -:8 M -:8 M 5:2 3:2 9:2 R:2"
B_THEME = """
    M! C6:2 Ab5:2 F5:4
    M Db6:2 Bb5:2 Gb5:4
    M! Eb6:4 C6:4
    Bb5:2 Ab5:2 Gb5:2 F5:2 Db5:8
    M Db6:4 F6:4
    Eb6:4 Db6:2 Bb5:2 Gb5:8
    M G5:2 Bb5:2 C6:4
    E6:12 -:4
"""
C_CALLS = "M -:8 -:16 M -:8 -:16 M -:8 -:16 M -:8 M M"
A_THEME_HIGH = """
    M! C6:2 Ab5:2 F5:4
    M Db6:2 Bb5:2 Gb5:4
    M! Eb6:4 C6:4
    M Bb5:4 Gb5:4
    M Db6:4 F6:4
    Eb6:4 Db6:2 Bb5:2 Gb5:8
    M G5:2 Bb5:2 C6:4
    M E6:8
"""


def main() -> None:
    song = Song("gevecht_loop.ogg", bpm=150, bars=32, swing=0.0)

    def section_a(first_bar, theme, octave):
        style.lead(song, first_bar, theme, A_CHORDS, octave=octave)
        for offset, chord in enumerate(A_CHORDS):
            bar = first_bar + offset
            style.bass_bar(song, bar, chord, "drive", patch=style.SYNTH_BASS)
            style.brass_stabs(song, bar, chord, [(0, 2), (2, 1), (3, 1), (4, 4)] if offset % 2 == 0 else [(8, 2), (12, 2)])
            style.psg_arpeggio(song, bar, chord, "updown", 0.6)
            last = offset == 7
            style.drum_bar(song, bar, kick="gallop", clap=True, hats="sixteenths",
                           fill=("tom" if first_bar == 24 else "snare") if last else None, ghosts=False)
        style.crash(song, first_bar)

    section_a(0, A_HITS, 0)

    style.lead(song, 8, B_THEME, A_CHORDS, echo=True)
    for offset, chord in enumerate(A_CHORDS):
        bar = 8 + offset
        style.bass_bar(song, bar, chord, "house", patch=style.SYNTH_BASS)
        style.brass_pad(song, bar, chord, bars=1, velocity=0.7)
        style.drum_bar(song, bar, kick="push", clap=True, hats="open", fill="snare" if offset == 7 else None)
    style.crash(song, 8)

    # C: half-time, the lead calls the motif and the PSG answers it a bar later
    style.lead(song, 16, C_CALLS, C_CHORDS)
    for offset, chord in enumerate(C_CHORDS):
        bar = 16 + offset
        style.bass_bar(song, bar, chord, "pulse", patch=style.SYNTH_BASS)
        style.strings_pad(song, bar, chord, bars=1, velocity=0.7)
        style.psg_arpeggio(song, bar, chord, "up", 0.45, every=1, track=song.psg_one)
        if offset % 2 == 1:
            for pitch, step, steps_long in zip(style.motif_notes(chord, tough=True), (0, 2, 3, 4), style.MOTIF_STEPS):
                song.psg_two.add(song.at(bar, step), style.megadrive.psg_square(
                    pitch, song.sixteenths(steps_long * 0.7), 0.9, decay=0.1, sustain=0.5))
        style.drum_bar(song, bar, kick="half", snare="half", clap=True, hats="eighths",
                       fill="roll" if offset == 7 else None)

    section_a(24, A_THEME_HIGH, 0)
    song.render()


if __name__ == "__main__":
    main()
