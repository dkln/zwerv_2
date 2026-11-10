"""'Gevecht': the battle loop, the full action-RPG battle theme of the style.

Style profile (stijlen/<active>.py): BATTLE_SECTIONS, TEMPOS["gevecht"]; in synthwave_rpg
120 BPM, D minor, 32 bars = 64 s, straight, loops seamlessly:

    bars  1-8   A       exploration: the square-wave chiptune lead with a fast vibrato over
                        the solid bass, FM brass stabs on 2 and 4 (doubled at the end of every
                        four bars), the PSG arpeggio, hats building with rolls
    bars  9-16  B       battle climax: four on the floor, gated snare and claps, distorted
                        power chords, the soaring synth lead on i-VI-III-VII, a sparkling
                        counter-arpeggio
    bars 17-24  solo    the duel: the guitar solos two bars (bends, vibrato), the chiptune
                        answers two bars in fast runs, syncopated bass, double-time hats
    bars 25-32  climax  the twin guitars in thirds with the synth lead, pads and brass, high
                        arpeggios, the heaviest beat; a tom fill back to the top

Render: tools/megadrive/render.sh gevecht  (writes assets/audio/muziek/gevecht_loop.ogg)
"""
import style
from style import Song

PROFILE = style.PROFILE
SECTIONS = {name: (first_bar, section_chords) for name, first_bar, section_chords in style.plan(PROFILE.BATTLE_SECTIONS)}

EXPLORATION = """
    M ^3':2 ^1':2 ^5:4
    ^6:3 ^5:1 ^4:2 ^3:2 ^4:4 ^6:4
    M ^7:2 ^1':2 ^3':4
    ^2':6 ^1':2 ^7:4 ^5:4
    M^ ^3':2 ^2':2 ^1':4
    ^6:2 ^1':2 ^2':2 ^3':2 ^4':4 ^3':2 ^2':2
    M ^2':2 ^7:2 ^5:4
    ^7:4 ^1':4 ^2':8
"""
SOARING = """
    ^5:4 ^1':6 ^2':2 ^3':4
    ^4':6 ^3':2 ^2':4 ^1':4
    M ^1':4 ^7:4
    ^7:6 ^1':2 ^2':8
    ^5:4 ^1':6 ^2':2 ^3':4
    ^4':4 ^3':4 ^2':4 ^4':4
    ^3':6 ^2':2 ^1':4 ^7:4
    M^ ^2':8
"""
GUITAR_CALLS = [
    "~^4:3 ^6:1 ^1':2 ^6:2 ~^1':4 ^6:2 ^4:2 ^5:2 ^4:2 ^3:2 ^1:2 ~^3:6 ^2:2",
    "^4':4 ~^5':4 ^4':2 ^3':2 ^1':4 ^3':2 ^1':2 ^6:2 ^5:2 ~^1':8",
]
CHIP_ANSWERS = [
    "^6:1 ^1':1 ^3':1 ^1':1 ^6:1 ^1':1 ^3':1 ^4':1 ^3':2 ^1':2 ^6:2 ^5:2 "
    "^7:1 ^2':1 ^4':1 ^2':1 ^7:1 ^2':1 ^4':1 ^5':1 ^4':2 ^2':2 ^7:2 ^1':2",
    "R:1 3:1 5:1 8:1 5:1 3:1 R:1 3:1 5:2 8:2 5:2 3:2 "
    "8:1 5:1 3:1 R:1 3:1 5:1 8:1 5:1 3':4 8:4",
]
FINAL = """
    ^5:4 ^1':6 ^2':2 ^3':4
    ^4':6 ^3':2 ^2':4 ^1':4
    M ^1':4 ^7:4
    ^7:6 ^1':2 ^2':8
    ^6:4 ^1':4 ^4':6 ^3':2
    ^5':6 ^4':2 ^3':4 ^2':4
    8:4 3':4 5':8
    M 5:2 3:2 R:4
"""


def main() -> None:
    song = Song("gevecht_loop.ogg", bpm=style.tempo("gevecht"), bars=style.plan_bars(PROFILE.BATTLE_SECTIONS),
                swing=style.piece("gevecht")["swing"])

    # A: exploration
    first_bar, section_chords = SECTIONS["A"]
    style.chip_lead(song, first_bar, EXPLORATION, section_chords)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "solid_turn" if offset % 4 == 3 else "solid")
        hits = [(4, 1), (12, 1)] + ([(14, 1), (15, 1)] if offset % 4 == 3 else [])
        style.brass_stabs(song, bar, bar_chord, hits)
        style.arpeggio(song, bar, bar_chord, "up", 0.5, track=song.psg_three)
        style.drum_bar(song, bar, kick="four", hats="double" if offset >= 4 else "sixteenths",
                       hat_volume=0.7 + 0.04 * offset, fm_snare=True, fill="snare" if offset == 7 else None)
    style.crash(song, first_bar)

    # B: the battle climax
    first_bar, section_chords = SECTIONS["B"]
    style.lead(song, first_bar, SOARING, section_chords, echo=True)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "solid")
        style.power_chords(song, bar, bar_chord, "anthem")
        style.arpeggio(song, bar, bar_chord, "updown", 0.42, octave=1, track=song.psg_three)
        style.drum_bar(song, bar, kick="four", clap=True, hats="open", fill="tom" if offset == 7 else None)
    style.crash(song, first_bar)
    style.crash(song, first_bar + 4, volume=0.7)

    # solo: guitar and chiptune trade licks
    first_bar, section_chords = SECTIONS["solo"]
    for pair in range(2):
        call_bar = first_bar + pair * 4
        style.guitar(song, call_bar, GUITAR_CALLS[pair], section_chords[pair * 4:pair * 4 + 2], octave=-1 if pair else 0,
                     echo=True)
        style.chip_lead(song, call_bar + 2, CHIP_ANSWERS[pair], section_chords[pair * 4 + 2:pair * 4 + 4], volume=0.9)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "syncopated")
        if offset % 4 >= 2:
            style.power_chords(song, bar, bar_chord, "hits", 0.7)
        else:
            style.brass_stabs(song, bar, bar_chord, [(6, 1), (14, 1)], 0.7)
        style.drum_bar(song, bar, kick="drive", hats="double", fill="snare" if offset == 7 else None)

    # climax: twin guitars in thirds with the synth lead, pad and brass, high arpeggios
    first_bar, section_chords = SECTIONS["climax"]
    style.lead(song, first_bar, FINAL, section_chords)
    style.guitar(song, first_bar, FINAL, section_chords, velocity=0.8, twin=True, octave=-1)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "solid_turn" if offset % 2 else "solid")
        if offset % 2 == 0:
            style.pad(song, bar, bar_chord, bars=2, velocity=0.75)
        style.brass_stabs(song, bar, bar_chord, [(4, 1), (12, 1)], 0.8)
        style.arpeggio(song, bar, bar_chord, "rolling", 0.45, octave=1, track=song.psg_three)
        style.drum_bar(song, bar, kick="push", clap=True, hats="open", fill="tom" if offset == 7 else None)
    style.crash(song, first_bar)
    style.big_hit(song, first_bar, 0, section_chords[0], 3)

    song.render()


if __name__ == "__main__":
    main()
