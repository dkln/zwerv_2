"""'Nachtstad menu': the main menu loop, the title screen of the cartridge. Heroic and full of
drive: the kick goes on all the time.

Style profile: MENU_SECTIONS, TEMPOS["menu"]; in synthwave_rpg 120 BPM, D minor, 32 bars = 64 s:

    bars  1-8   A   the motif as a fanfare on the synth lead over the solid bass, the fast
                    PSG arpeggio, brass stabs on 2 and 4
    bars  9-16  B   power chords, the singing theme climbing to the dominant, the chiptune
                    echoing it, open hats
    bars 17-24  C   the peak: the big theme with the PSG echo, twin guitars on the long
                    notes, brass, rolling arpeggios, claps
    bars 25-32  D   pads and bells, the guitars in thirds slowly, the kick alone and then a
                    roll back to the top

Render: tools/megadrive/render.sh nachtstad_menu  (writes assets/audio/muziek/nachtstad_menu_loop.ogg)
"""
import style
from style import Song

PROFILE = style.PROFILE
SECTIONS = {name: (first_bar, section_chords) for name, first_bar, section_chords in style.plan(PROFILE.MENU_SECTIONS)}

FANFARE = """
    M -:4 ^5:2 ^7:2
    M -:8
    M ^1':2 ^2':2 ^3':4
    ^2':6 ^1':2 ^7:8
    M -:4 ^5:2 ^7:2
    M ^3':4 ^1':4
    M ^2':2 ^3':2 ^4':4
    ^5':12 -:4
"""
CLIMB = """
    ^6:4 ^1':4 ^4':4 ^3':4
    ^2':6 ^1':2 ^7:4 ^2':4
    ^3':8 ^5:4 ^1':4
    ^1':12 -:4
    ^6:4 ^1':4 ^4':4 ^3':4
    ^5':6 ^4':2 ^3':4 ^2':4
    3':4 8:4 5:4 3:4
    M 3':4 5':4
"""
PEAK = """
    ^1':4 ^7:2 ^1':2 ^2':4 ^3':4
    ^4':6 ^3':2 ^1':4 ^6:4
    ^5:4 ^1':4 ^3':6 ^2':2
    ^2':8 ^7:4 ^5:4
    M ^4':4 ^2':4
    ^3':4 ^1':4 ^6:4 ^1':4
    ^2':6 ^1':2 ^7:8
    M 5:4 3:4
"""
SLOW = """
    ^6:8 ^5:8
    ^7:8 ^2':8
    ^3':12 ^2':4
    ^1':16
    ^7:8 ^6:8
    ^5:12 ^3:4
    R:4 3:4 5:4 8:4
    M 8:8
"""


def main() -> None:
    song = Song("nachtstad_menu_loop.ogg", bpm=style.tempo("menu"), bars=style.plan_bars(PROFILE.MENU_SECTIONS),
                swing=style.piece("nachtstad_menu")["swing"])

    first_bar, section_chords = SECTIONS["A"]
    style.lead(song, first_bar, FANFARE, section_chords)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "solid_turn" if offset % 4 == 3 else "solid")
        style.arpeggio(song, bar, bar_chord, "up", 0.6)
        style.brass_stabs(song, bar, bar_chord)
        style.drum_bar(song, bar, kick="four", hats="sixteenths", fill="snare" if offset == 7 else None, fm_snare=True)
    style.crash(song, first_bar)

    first_bar, section_chords = SECTIONS["B"]
    style.lead(song, first_bar, CLIMB, section_chords, echo=True, slides=True)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "solid")
        style.power_chords(song, bar, bar_chord, "push")
        style.arpeggio(song, bar, bar_chord, "updown", 0.4, octave=1, track=song.psg_three, every=2)
        style.drum_bar(song, bar, kick="four", clap=True, hats="open", fill="tom" if offset == 7 else None)
    style.crash(song, first_bar)

    first_bar, section_chords = SECTIONS["C"]
    style.lead(song, first_bar, PEAK, section_chords, echo=True)
    style.guitar(song, first_bar, PEAK, section_chords, velocity=0.7, twin=True, octave=-1)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "solid_turn" if offset % 2 else "solid")
        style.brass_stabs(song, bar, bar_chord, [(-2, 2), (4, 1), (12, 1)] if offset % 2 == 0 else [(4, 1), (10, 1), (12, 2)])
        style.arpeggio(song, bar, bar_chord, "rolling", 0.5, octave=1, track=song.psg_three)
        style.drum_bar(song, bar, kick="push", clap=True, hats="open", fill="snare" if offset == 7 else None)
    style.crash(song, first_bar)
    style.crash(song, first_bar + 4, volume=0.7)

    first_bar, section_chords = SECTIONS["D"]
    style.guitar(song, first_bar, SLOW, section_chords, velocity=0.75, twin=True, octave=-1, echo=True)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.pad(song, bar, bar_chord, bars=1)
        style.bass_bar(song, bar, bar_chord, "pulse" if offset < 6 else "solid")
        style.arpeggio(song, bar, bar_chord, "twinkle", 0.4)
        style.bells(song, bar, style.motif_notes(bar_chord, octave=1), (0, 2, 3, 4), 0.45)
        if offset < 7:
            style.drum_bar(song, bar, kick="four", snare="none" if offset < 4 else "backbeat", hats="eighths",
                           hat_volume=0.6, ghosts=False)
        else:
            style.drum_bar(song, bar, kick="four", hats="sixteenths", fill="roll")
    style.crash(song, first_bar, volume=0.6)
    song.render()


if __name__ == "__main__":
    main()
