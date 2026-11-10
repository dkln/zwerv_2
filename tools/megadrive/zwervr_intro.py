"""'ZWERVR' intro: the music under the opening crawl (scripts/ui/intro.gd times everything on it).

Style profile: INTRO_SECTIONS, TEMPOS["intro"]; in synthwave_rpg 120 BPM (a bar is 2 s),
D minor, 60 bars = 120 s, a one-shot (no loop) that dies away at the end, where the menu takes
over. The sections sit exactly on the moments intro.gd uses (seconds from the start):

    bars  1-8   (0 - 16 s)    the intro: bone dry, a fast sparkling PSG arpeggio alone; after
                              two bars (4 s) the growling solid FM bass; the motif softly on the
                              lead at 6 s (the logo stands at 6.5); tight kick and the metallic
                              FM snare from 8 s; a roll into...
    bars  9-24  (16 - 48 s)   A, exploration (CRAWL_AT 16.0): the square-wave chiptune lead,
                              FM brass stabs at the end of every four bars, hats building; the
                              second time with the synth lead an octave down under it
    bars 25-40  (48 - 80 s)   B, the battle climax (CRAWL_CUES 48.0): four on the floor, gated
                              snare, power chords, the soaring synth lead, a counter-arpeggio
    bars 41-52  (80 - 104 s)  the duel (CRAWL_CUES 80.0): guitar solo and chiptune trading
                              licks, syncopated bass, double-time hats
    bar  53     (104.0 s)     "system crash" (CRAWL_CUES 104.0): the tape stops over the last
                              beat, one hard hit, a PSG dive
    bars 53-60  (104 - 120 s) the outro: the groove stripped back to kick and bass, then bass
                              alone, the nostalgic FM chime with its square-wave echo, a final
                              FM chord stab with a crash and the tape stopping (END_AT 120.0)

Render: tools/megadrive/render.sh zwervr_intro  (writes assets/audio/muziek/zwervr_intro.ogg)
"""
import megadrive
import style
from style import Song

PROFILE = style.PROFILE
SECTIONS = {name: (first_bar, section_chords) for name, first_bar, section_chords in style.plan(PROFILE.INTRO_SECTIONS)}

EXPLORATION = """
    M ^3':2 ^1':2 ^5:4
    ^6:3 ^5:1 ^4:2 ^3:2 ^4:4 ^6:4
    M ^7:2 ^1':2 ^3':4
    ^2':6 ^1':2 ^7:4 ^5:4
    M^ ^3':2 ^2':2 ^1':4
    ^6:2 ^1':2 ^2':2 ^3':2 ^4':4 ^3':2 ^2':2
    M ^7:2 ^1':2 ^2':4
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
    ^6:4 ^1':4 ^4':4 ^3':4
    ^2':6 ^1':2 ^7:4 ^2':4
    ^3':8 ^5:4 ^1':4
    ^1':12 -:4
    ^6:4 ^1':4 ^4':4 ^3':4
    ^5':6 ^4':2 ^3':4 ^2':4
    3':4 8:4 5:4 3:4
    M 3':4 5':4
"""
GUITAR_CALLS = [
    "~^4:3 ^6:1 ^1':2 ^6:2 ~^1':4 ^6:2 ^4:2 ^5:2 ^4:2 ^3:2 ^1:2 ~^3:6 ^2:2",
    "^4':4 ~^5':4 ^4':2 ^3':2 ^1':4 ^3':2 ^1':2 ^6:2 ^5:2 ~^1':8",
    "~^4:4 ^6:2 ^1':2 ^4':4 ^3':2 ^1':2 ^6:2 ^1':2 ^3':2 ^4':2 ~^5':6 ^4':2",
]
CHIP_ANSWERS = [
    "^6:1 ^1':1 ^3':1 ^1':1 ^6:1 ^1':1 ^3':1 ^4':1 ^3':2 ^1':2 ^6:2 ^5:2 "
    "^7:1 ^2':1 ^4':1 ^2':1 ^7:1 ^2':1 ^4':1 ^5':1 ^4':2 ^2':2 ^7:2 ^1':2",
    "^6:1 ^1':1 ^3':1 ^4':1 ^3':1 ^1':1 ^6:1 ^5:1 ^6:2 ^1':2 ^3':2 ^1':2 "
    "^7:1 ^2':1 ^4':1 ^5':1 ^4':1 ^2':1 ^7:1 ^5:1 ^7:2 ^2':2 ^4':4",
    "R:1 3:1 5:1 8:1 5:1 3:1 R:1 3:1 5:2 8:2 5:2 3:2 "
    "8:1 5:1 3:1 R:1 3:1 5:1 8:1 5:1 3':4 8:4",
]


def main() -> None:
    song = Song("zwervr_intro.ogg", bpm=style.tempo("intro"), bars=style.plan_bars(PROFILE.INTRO_SECTIONS), loop=False,
                swing=style.piece("zwervr_intro")["swing"])

    # the intro (0 - 16 s)
    first_bar, section_chords = SECTIONS["intro"]
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.arpeggio(song, bar, bar_chord, "up", 0.55 + 0.03 * offset)
        if offset >= 2:
            style.bass_bar(song, bar, bar_chord, "solid" if offset >= 4 else "pulse", velocity=0.8 + 0.03 * offset)
        if 4 <= offset < 7:
            style.drum_bar(song, bar, kick="four", hats="eighths" if offset < 6 else "sixteenths", ghosts=False,
                           fm_snare=True, hat_volume=0.6)
        if offset == 7:
            style.drum_bar(song, bar, kick="four", hats="sixteenths", fill="roll")
        if offset in (4, 6):
            style.pad(song, bar, bar_chord, bars=2, velocity=0.5)
    style.lead(song, first_bar + 3, "M -:8", section_chords[3:4], velocity=0.7)     # 6.0 s
    style.lead(song, first_bar + 5, "M -:8 M^ -:8", section_chords[5:7], velocity=0.8)

    # A, exploration (16 - 48 s)
    first_bar, section_chords = SECTIONS["A"]
    for half in range(2):
        half_bar = first_bar + half * 8
        half_chords = section_chords[half * 8:half * 8 + 8]
        style.chip_lead(song, half_bar, EXPLORATION, half_chords)
        if half == 1:
            style.lead(song, half_bar, EXPLORATION, half_chords, velocity=0.65, octave=-1)
        for offset, bar_chord in enumerate(half_chords):
            bar = half_bar + offset
            style.bass_bar(song, bar, bar_chord, "solid_turn" if offset % 4 == 3 else "solid")
            style.brass_stabs(song, bar, bar_chord, [(4, 1), (12, 1)] + ([(14, 1), (15, 1)] if offset % 4 == 3 else []))
            style.arpeggio(song, bar, bar_chord, "up", 0.45, track=song.psg_three)
            style.drum_bar(song, bar, kick="four", hats="double" if half else "sixteenths", fm_snare=True,
                           hat_volume=0.65 + 0.03 * offset, fill="snare" if offset == 7 else None)
        style.crash(song, half_bar)

    # B, the battle climax (48 - 80 s)
    first_bar, section_chords = SECTIONS["B"]
    style.lead(song, first_bar, SOARING, section_chords, echo=True)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "solid_turn" if offset % 4 == 3 else "solid")
        style.power_chords(song, bar, bar_chord, "anthem" if offset < 8 else "push")
        style.arpeggio(song, bar, bar_chord, "updown", 0.42, octave=1, track=song.psg_three)
        if offset >= 8:
            style.brass_stabs(song, bar, bar_chord, [(4, 1), (12, 1)], 0.75)
        style.drum_bar(song, bar, kick="four", clap=True, hats="open", fill="tom" if offset in (7, 15) else None)
    style.big_hit(song, first_bar, 0, section_chords[0], 3)
    style.crash(song, first_bar + 8)

    # the duel (80 - 104 s)
    first_bar, section_chords = SECTIONS["duel"]
    for pair in range(3):
        call_bar = first_bar + pair * 4
        style.guitar(song, call_bar, GUITAR_CALLS[pair], section_chords[pair * 4:pair * 4 + 2],
                     octave=-1 if pair == 1 else 0, echo=True)
        style.chip_lead(song, call_bar + 2, CHIP_ANSWERS[pair], section_chords[pair * 4 + 2:pair * 4 + 4], volume=0.9)
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        style.bass_bar(song, bar, bar_chord, "syncopated")
        if offset % 4 >= 2:
            style.power_chords(song, bar, bar_chord, "hits", 0.7)
        else:
            style.brass_stabs(song, bar, bar_chord, [(6, 1), (14, 1)], 0.7)
        style.drum_bar(song, bar, kick="drive", hats="double", fill="snare" if offset in (3, 7) else None)
    style.crash(song, first_bar)

    # the system crash (104 s): the tape stops over the last beat, a hard hit, a PSG dive
    first_bar, section_chords = SECTIONS["outro"]
    song.tape_stop(first_bar - 1, 12, 1.0)
    style.big_hit(song, first_bar, 0, section_chords[0], 6)
    song.psg_one.add(song.at(first_bar, 0), megadrive.psg_sweep(96, 36, 1.2, 0.9))
    song.noise.add(song.at(first_bar, 0), megadrive.psg_noise(1.0, 0.9, 9000.0, 0.35, 3))

    # the outro (104 - 120 s): kick and bass, then the bass alone, the chime, a final stab
    for offset, bar_chord in enumerate(section_chords):
        bar = first_bar + offset
        if offset < 6:
            style.bass_bar(song, bar, bar_chord, "solid" if offset < 4 else "pulse", velocity=0.9 - 0.06 * offset)
        if 1 <= offset < 4:
            style.drum_bar(song, bar, kick="four", snare="none", hats="eighths", hat_volume=0.5 - 0.1 * offset, ghosts=False)
        if offset in (1, 3, 5):
            chime = style.motif_notes(bar_chord, octave=1 if offset < 5 else 0)
            style.bells(song, bar, chime, (0, 2, 3, 4), 0.75 - 0.1 * offset, track=song.lead, patch=style.CHIME)
            for pitch, step in zip(chime, (6, 8, 9, 10)):
                song.psg_two.add(song.at(bar, step), megadrive.psg_square(pitch, song.sixteenths(1.5), 0.45 - 0.05 * offset,
                                                                          decay=0.2, sustain=0.2))
        if offset % 2 == 0 and offset < 6:
            style.pad(song, bar, bar_chord, bars=2, velocity=0.6 - 0.07 * offset)
    final_bar = first_bar + 6
    song.brass.add(song.at(final_bar, 0), megadrive.fm_chord(style.BRASS_STAB, style.chord("i").dyad(), song.sixteenths(6), 1.0))
    song.guitar.add(song.at(final_bar, 0), megadrive.fm_note(style.POWER_CHORD, float(style.chord("i").power_root),
                                                             song.sixteenths(6), 0.9))
    song.pcm.add(song.at(final_bar, 0), style.FAT_KICK)
    style.crash(song, final_bar)
    song.tape_stop(final_bar, 4, 1.6)
    song.render(fade_out=2.0)


if __name__ == "__main__":
    main()
