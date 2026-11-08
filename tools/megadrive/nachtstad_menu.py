"""'Nachtstad': the main menu loop. Energetic and straight (no swing), driving like a title screen.

House style (style.py). 128 BPM, F minor, 48 bars = 90 s, loops seamlessly. The motif opens
every section on the FM lead; the brass hits it along with the lead in the finale.

    bars  1-8   A       i - bII - iv - i twice: driving synth bass, brass stabs, the motif theme
    bars  9-16  B       Bbm Gb Ab Cm / Bbm Gb Ab C7: PSG counter-line, lead in long notes
    bars 17-24  A'      the theme an octave up with the PSG echo, open hats, PSG arpeggios
    bars 25-28  break   no kick: strings, the motif slow and soft, a snare roll
    bars 29-36  bridge  half-time, slap bass, electric piano, Ab Gb Fm Fm
    bars 37-44  finale  the A theme with brass doubling, tough motif hits
    bars 45-48  turn    Fm Gb Bbm C7 with a tom fill into the top

Render: tools/megadrive/render.sh nachtstad_menu  (writes assets/audio/muziek/nachtstad_menu_loop.ogg)
"""
import style
from style import Song, chords

A_CHORDS = chords(["F m7", "Gb maj7", "Bb m7", "F m7", "F m7", "Gb maj7", "Bb m7", "C 7"])
B_CHORDS = chords(["Bb m7", "Gb maj7", "Ab maj", "C m7", "Bb m7", "Gb maj7", "Ab maj", "C 7"])
BREAK_CHORDS = chords(["Gb maj7", "Gb maj7", "Bb m7", "C 7"])
BRIDGE_CHORDS = chords(["Ab maj7", "Gb maj7", "F m9", "F m9", "Ab maj7", "Gb maj7", "Bb m9", "C sus"])
TURN_CHORDS = chords(["F m7", "Gb maj7", "Bb m7", "C 7"])

# the theme states the motif in every bar and answers it in a four-bar cycle
A_THEME = """
    M 5:2 3:2 R:4
    M! -:8
    M 3:6 -:2
    M 5:2 3:2 9:2 R:2
    M 5:2 3:2 R:4
    M! Db6:2 Bb5:2 Gb5:4
    M 3:6 -:2
    M E5:2 G5:2 Bb5:2 C6:2
"""
B_THEME = """
    M Db6:8
    Bb5:6 Ab5:2 F5:8
    M C6:8
    Eb6:6 D6:2 C6:4 G5:4
    M F6:8
    Db6:6 Bb5:2 Ab5:4 F5:4
    Eb5:4 Ab5:4 C6:4 Eb6:4
    M -:8
"""
BREAK_THEME = "Gb5:4 Bb5:2 Ab5:2 Db5:8 -:16 Bb5:4 Db6:2 C6:2 F5:8 -:16"
BRIDGE_THEME = """
    -:16
    -:8 Bb5:2 Ab5:2 F5:4
    M Eb5:2 F5:2 Ab5:4
    G5:12 -:4
    -:16
    -:8 Bb5:2 Db6:2 F6:4
    M Ab5:4 Bb5:4
    C6:12 -:4
"""
TURN_THEME = "M -:8 M -:8 M -:8 M -:8"


def main() -> None:
    song = Song("nachtstad_menu_loop.ogg", bpm=128, bars=48, swing=0.0)

    def section_a(first_bar, octave, finale):
        style.lead(song, first_bar, A_THEME, A_CHORDS, octave=octave, echo=octave == 1, velocity=1.0)
        if finale:   # the brass hits the motif with the lead
            for offset, chord in enumerate(A_CHORDS):
                style.brass_stabs(song, first_bar + offset, chord, [(0, 2), (2, 1), (3, 1), (4, 4)], 0.8)
        for offset, chord in enumerate(A_CHORDS):
            bar = first_bar + offset
            style.bass_bar(song, bar, chord, "drive", patch=style.SYNTH_BASS, velocity=0.95)
            if not finale:
                style.brass_stabs(song, bar, chord, [(-2, 2), (6, 2), (10, 1)] if offset % 2 == 0 else [(6, 1), (8, 2)])
            if octave == 1:
                style.psg_arpeggio(song, bar, chord, "updown", 0.7)
            else:
                style.psg_arpeggio(song, bar, chord, "up", 0.5, every=2)
            last = offset == 7
            style.drum_bar(song, bar, kick="push" if finale else "four", clap=True,
                           hats="open" if octave == 1 or finale else "sixteenths",
                           fill="snare" if last else None, ghosts=False)
        style.crash(song, first_bar)

    section_a(0, 0, False)

    # B: lead in long notes, PSG harmony underneath, brass pads
    style.lead(song, 8, B_THEME, B_CHORDS, harmony=True, slides=True)
    for offset, chord in enumerate(B_CHORDS):
        bar = 8 + offset
        style.bass_bar(song, bar, chord, "offbeat", patch=style.SYNTH_BASS)
        style.bass_bar(song, bar, chord, "pulse", patch=style.SYNTH_BASS, velocity=0.6)
        style.brass_pad(song, bar, chord, bars=1, velocity=0.7)
        style.psg_arpeggio(song, bar, chord, "motif", 0.55, track=song.psg_one)
        style.drum_bar(song, bar, clap=True, hats="sixteenths", fill="tom" if offset == 7 else None, ghosts=False)

    section_a(16, 1, False)

    # break
    style.lead(song, 24, BREAK_THEME, BREAK_CHORDS, velocity=0.65)
    for offset, chord in enumerate(BREAK_CHORDS):
        bar = 24 + offset
        style.bass_bar(song, bar, chord, "whole", patch=style.SYNTH_BASS, velocity=0.8)
        if offset in (0, 2, 3):
            style.strings_pad(song, bar, chord, bars=2 if offset == 0 else 1)
        style.psg_arpeggio(song, bar, chord, "twinkle", 0.5)
        if offset == 3:
            style.drum_bar(song, bar, kick="none", snare="none", hats="sixteenths", hat_volume=0.6, fill="roll")
        elif offset == 2:
            style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", hat_volume=0.5, ghosts=False)

    # bridge: half-time, slap bass, piano
    style.lead(song, 28, BRIDGE_THEME, BRIDGE_CHORDS, slides=True)
    for offset, chord in enumerate(BRIDGE_CHORDS):
        bar = 28 + offset
        style.bass_bar(song, bar, chord, "funk_turn" if offset % 2 else "funk")
        style.piano_bar(song, bar, chord, "answer" if offset % 2 else "push")
        style.strings_pad(song, bar, chord, bars=1, velocity=0.6)
        style.drum_bar(song, bar, kick="half", snare="half", clap=True, hats="sixteenths",
                       fill="snare" if offset == 7 else None)
    style.crash(song, 28)

    section_a(36, 0, True)

    # turn: the motif on every chord, tom fill back to the top
    style.lead(song, 44, TURN_THEME, TURN_CHORDS)
    for offset, chord in enumerate(TURN_CHORDS):
        bar = 44 + offset
        style.bass_bar(song, bar, chord, "drive", patch=style.SYNTH_BASS)
        style.brass_stabs(song, bar, chord, [(0, 2), (2, 1), (3, 1), (4, 4)], 0.7)
        style.psg_arpeggio(song, bar, chord, "updown", 0.6)
        style.drum_bar(song, bar, kick="four", clap=True, hats="open", fill="tom" if offset == 3 else None, ghosts=False)

    song.render()


if __name__ == "__main__":
    main()
