"""'Laden': the waiting music under the loading screen (scripts/ui/loading_screen.gd), fading in
and out. A calm variant of the style.

Style profile: LOADING_CHORDS, TEMPOS["laden"]; in synthwave_rpg 100 BPM, D minor, 16 bars =
38.4 s, a light swing. Half-time: the kick on one and the "and" of three, a soft snare on
three, the solid bass pulsing softly, the warm pad, the chime on the motif, plucked chords;
the second time a gentle tune on the synth lead.
Render: tools/megadrive/render.sh laden  (writes assets/audio/muziek/laden_loop.ogg)
"""
import style
from style import Song

PROFILE = style.PROFILE
WAITING_TUNE = """
    ^5:8 ^1':8
    ^7:12 ^6:4
    ^5:4 ^6:4 ^1':8
    ^7:16
    ^4:8 ^6:8
    ^5:12 ^4:4
    ^2':8 ^7:8
    M -:8
"""


def main() -> None:
    section_chords = style.chords(PROFILE.LOADING_CHORDS)
    song = Song("laden_loop.ogg", bpm=style.tempo("laden"), bars=len(section_chords), swing=style.piece("laden")["swing"])
    style.lead(song, 8, WAITING_TUNE, section_chords[8:], velocity=0.7, slides=True)
    for bar, bar_chord in enumerate(section_chords):
        style.pad(song, bar, bar_chord, velocity=0.7)
        style.bass_bar(song, bar, bar_chord, "pulse", velocity=0.75)
        style.pluck_chord(song, bar, bar_chord, (0, 3, 6, 10), 0.45, track=song.harmony)
        if bar % 2 == 0:
            style.bells(song, bar, style.motif_notes(bar_chord, octave=1), (0, 2, 3, 4), 0.4, patch=style.CHIME)
        style.drum_bar(song, bar, kick="half", snare="half", hats="eighths", hat_volume=0.45, ghosts=False,
                       velocity=0.75, fill="tom" if bar == 15 else None)
    song.render(target_rms_db=-17.0)


if __name__ == "__main__":
    main()
