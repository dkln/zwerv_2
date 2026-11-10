"""'Handelaar': the loop inside a shop (the snack bars: scripts/world/interiors.gd). A laid-back
variant of the style: the same tempo as the city loops, so it can flow over smoothly.

Style profile: MERCHANT_CHORDS, TEMPOS["handelaar"]; in synthwave_rpg 120 BPM, D minor,
16 bars = 32 s, a light swing. The slap bass, plucked chords on the off-beats, soft brass
stabs, a broken beat with claps, a friendly tune on the chiptune lead; the second time the
synth lead takes it with the PSG echo.
Render: tools/megadrive/render.sh handelaar  (writes assets/audio/muziek/handelaar_loop.ogg)
"""
import style
from style import Song

PROFILE = style.PROFILE
SHOP_TUNE = """
    M -:4 ^5:4
    ^6:4 ^5:2 ^4:2 ^3:8
    M ^1':4 ^7:4
    ^7:6 ^5:2 ^2':8
    ^4:4 ^6:4 ^1':4 ^6:4
    ^5:8 ^3:4 ^4:4
    ^5:6 ^4:2 ^2:8
    M 3:4 R:4
"""


def main() -> None:
    section_chords = style.chords(PROFILE.MERCHANT_CHORDS)
    song = Song("handelaar_loop.ogg", bpm=style.tempo("handelaar"), bars=len(section_chords),
                swing=style.piece("handelaar")["swing"])
    style.chip_lead(song, 0, SHOP_TUNE, section_chords[:8], volume=0.75, vibrato=0.2)
    style.lead(song, 8, SHOP_TUNE, section_chords[8:], echo=True, slides=True)
    for bar, bar_chord in enumerate(section_chords):
        style.bass_bar(song, bar, bar_chord, "slap")
        style.pluck_chord(song, bar, bar_chord, (2, 6, 10, 14), 0.55, track=song.harmony)
        style.brass_stabs(song, bar, bar_chord, [(7, 1), (12, 1)], 0.55)
        if bar >= 8:
            style.pad(song, bar, bar_chord, velocity=0.5)
        drums_last = bar % 8 == 7
        style.drum_bar(song, bar, kick="broken", snare="none", clap=True, hats="eighths", hat_volume=0.6,
                       fill="tom" if bar == 15 else ("drop" if drums_last else None))
    song.render(target_rms_db=-15.0)


if __name__ == "__main__":
    main()
