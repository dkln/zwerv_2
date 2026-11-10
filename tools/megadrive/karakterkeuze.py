"""'Karakterkeuze': the soft loop of the character creation screen (character_creation.gd).

Style profile: CHARACTER_CHORDS, TEMPOS["karakterkeuze"]; in synthwave_rpg 96 BPM, D minor,
16 bars = 40 s. The pad, bells on the motif, a slow PSG arpeggio, a light kick; the second
time a soft tune on the chiptune lead.
Render: tools/megadrive/render.sh karakterkeuze  (writes assets/audio/muziek/karakterkeuze_loop.ogg)
"""
import style
from style import Song

PROFILE = style.PROFILE
CHOOSING_TUNE = """
    M -:8
    ^6:8 ^5:8
    M ^7:4 ^5:4
    ^5:8 ^4:8
    M -:8
    ^1':8 ^7:4 ^6:4
    ^5:8 ^4:4 ^5:4
    R:8 3:8
"""


def main() -> None:
    section_chords = style.chords(PROFILE.CHARACTER_CHORDS)
    song = Song("karakterkeuze_loop.ogg", bpm=style.tempo("karakterkeuze"), bars=len(section_chords),
                swing=style.piece("karakterkeuze")["swing"])
    style.chip_lead(song, 8, CHOOSING_TUNE, section_chords[8:], volume=0.6, vibrato=0.18)
    for bar, bar_chord in enumerate(section_chords):
        if bar % 2 == 0:
            style.pad(song, bar, bar_chord, bars=2, velocity=0.75)
        style.bass_bar(song, bar, bar_chord, "hold", velocity=0.7)
        style.arpeggio(song, bar, bar_chord, "up", 0.3, every=2, track=song.psg_three)
        if bar % 4 == 0:
            style.bells(song, bar, style.motif_notes(bar_chord, octave=1), (0, 2, 3, 4), 0.45)
        if bar >= 4:
            style.drum_bar(song, bar, kick="half", snare="none", hats="eighths" if bar >= 8 else "none",
                           hat_volume=0.4, ghosts=False, velocity=0.65)
    song.render(target_rms_db=-18.0)


if __name__ == "__main__":
    main()
