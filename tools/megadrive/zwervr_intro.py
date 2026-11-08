"""'ZWERVR' intro: the music under the opening crawl (scripts/ui/intro.gd times everything on it).

House style (style.py). 128 BPM (a bar is 1.875 s), F minor, 64 bars = 120 s, a one-shot (no
loop): it dies away at the end, where the menu takes over. The sections sit exactly on the
moments intro.gd uses (bar numbers counted from 1, seconds from the start):

    bars  1-8   (0 - 15 s)    the swell: strings from nothing, PSG twinkle, the motif softly on
                              bar 5 (7.5 s, the logo stands at 6.5), a build into...
    bars  9-24  (15 - 45 s)   the chase (CRAWL_AT 15.0): crash, full groove, the chase theme;
                              from bar 17 an octave up with the PSG echo and brass stabs
    bars 25-32  (45 - 60 s)   the climb (CRAWL_CUES 45.0): Bbm Gb Ab Cm, driving bass, a roll
    bars 33-40  (60 - 75 s)   the chorus: the big theme with brass and strings
    bars 41-48  (75 - 90 s)   its second half (CRAWL_CUES 75.0): PSG harmony, brass stabs
    bars 49-56  (90 - 105 s)  the duel: the lead calls the motif, the PSG answers, galloping kick
    bar  57     (105.0 s)     "system crash" (CRAWL_CUES 105.0): one hard hit, a PSG dive and
                              a noise burst, then the drums are gone
    bars 57-64  (105 - 120 s) the outro: strings and piano, the motif slow one last time,
                              fading out to silence at 120.0 (END_AT)

Render: tools/megadrive/render.sh zwervr_intro  (writes assets/audio/muziek/zwervr_intro.ogg)
"""
import megadrive
import style
from style import Song, chords

SWELL_CHORDS = chords(["F m9", "F m9", "Gb maj7", "Gb maj7", "F m9", "Gb maj7", "Bb m7", "C 7"])
CHASE_CHORDS = chords(["F m7", "Gb maj7", "Bb m7", "F m7", "F m7", "Gb maj7", "Ab maj", "C 7"])
CLIMB_CHORDS = chords(["Bb m7", "Gb maj7", "Ab maj", "C m7", "Bb m7", "Gb maj7", "Ab maj", "C 7"])
CHORUS_CHORDS = chords(["Gb maj7", "Ab 6", "F m7", "F m7", "Gb maj7", "Ab 6", "Bb m7", "C 7"])
DUEL_CHORDS = chords(["F m7", "Gb maj", "F m7", "Gb maj", "Bb m7", "Gb maj", "C 7", "C 7"])
OUTRO_CHORDS = chords(["F m9", "F m9", "Gb maj7", "Gb maj7", "Bb m9", "Bb m9", "F m9", "F m9"])

SWELL_THEME = "-:16 -:16 -:16 -:16 M -:8 -:16 M -:8 M 5:4 3:4"
CHASE_THEME = """
    M 5:2 3:2 R:4
    Db6:4 Bb5:2 Gb5:2 F5:8
    M Db6:3 C6:1 Bb5:4
    Ab5:2 G5:2 F5:4 C5:8
    M! -:2 F5:1 Ab5:1 C6:4
    Db6:6 Bb5:2 Ab5:4 Gb5:4
    M C6:2 Eb6:2 C6:4
    M E5:2 G5:2 Bb5:4
"""
CLIMB_THEME = """
    Bb5:12 C6:2 Db6:2
    Bb5:8 Gb5:8
    C6:12 Db6:2 Eb6:2
    G5:8 C6:8
    Db6:12 Eb6:2 F6:2
    Db6:8 Bb5:8
    M Eb6:4 F6:4
    M E6:8
"""
CHORUS_THEME = """
    M Db6:6 F6:2
    Eb6:8 C6:4 Ab5:4
    M C6:4 Ab5:2 G5:2
    F5:10 -:2 Ab5:2 C6:2
    M F6:6 Eb6:2
    Eb6:4 F6:2 Eb6:2 C6:8
    M Db6:4 F6:4
    E6:4 D6:2 C6:2 G5:4 Bb5:4
"""
DUEL_CALLS = "M -:8 -:16 M! -:8 -:16 M -:8 -:16 M -:8 M M"


def main() -> None:
    song = Song("zwervr_intro.ogg", bpm=128, bars=64, loop=False, swing=0.0)

    # the swell (bars 1-8)
    for offset, chord in enumerate(SWELL_CHORDS):
        bar = offset
        swell = 0.35 + 0.65 * offset / 7
        if offset % 2 == 0 or offset >= 4:
            style.strings_pad(song, bar, chord, bars=2 if offset < 4 else 1, velocity=swell)
        song.bass.add(song.at(bar), megadrive.fm_note(style.SYNTH_BASS, float(chord.bass_root - 12),
                                                      song.sixteenths(15), 0.3 + 0.5 * swell))
        if offset >= 2:
            style.psg_arpeggio(song, bar, chord, "twinkle", 0.25 + 0.3 * swell)
        if offset == 3:
            style.brass_pad(song, bar, chord, bars=1, velocity=0.6)   # the logo fades in (5 - 6.5 s)
        if offset >= 6:
            style.psg_arpeggio(song, bar, chord, "up", 0.5, every=1 if offset == 7 else 2, track=song.psg_two)
        if offset == 6:
            for step in (0, 4, 8, 12):
                song.pcm.add(song.at(bar, step), style.KICK, 0.7)
            style.drum_bar(song, bar, kick="none", snare="none", hats="eighths", hat_volume=0.6, ghosts=False)
        if offset == 7:
            style.drum_bar(song, bar, kick="four", snare="none", hats="sixteenths", fill="roll")
    style.lead(song, 0, SWELL_THEME, SWELL_CHORDS, velocity=0.75)

    # the chase (bars 9-24, from 15.0 s)
    for half in range(2):
        first_bar = 8 + half * 8
        style.lead(song, first_bar, CHASE_THEME, CHASE_CHORDS, octave=half, echo=half == 1)
        if half == 1:
            style.crash(song, first_bar)
        for offset, chord in enumerate(CHASE_CHORDS):
            bar = first_bar + offset
            style.bass_bar(song, bar, chord, "house", patch=style.SYNTH_BASS)
            if half == 0:
                style.piano_bar(song, bar, chord, "answer" if offset % 2 else "push")
                style.psg_arpeggio(song, bar, chord, "up", 0.55, every=2)
            else:
                style.brass_stabs(song, bar, chord, [(-2, 2), (0, 1), (3, 1), (6, 2)] if offset % 2 == 0 else [(10, 1), (12, 2)])
                style.psg_arpeggio(song, bar, chord, "updown", 0.6, track=song.psg_one)
            style.drum_bar(song, bar, kick="four" if half == 0 else "push", clap=True,
                           hats="sixteenths" if half == 0 else "open", fill="snare" if offset == 7 else None)
    style.big_hit(song, 8, 0, CHASE_CHORDS[0], 6)

    # the climb (bars 25-32, from 45.0 s)
    style.lead(song, 24, CLIMB_THEME, CLIMB_CHORDS, slides=True)
    for offset, chord in enumerate(CLIMB_CHORDS):
        bar = 24 + offset
        style.bass_bar(song, bar, chord, "drive", patch=style.SYNTH_BASS, velocity=0.8 + 0.2 * offset / 7)
        style.brass_pad(song, bar, chord, bars=1, velocity=0.6 + 0.3 * offset / 7)
        style.psg_arpeggio(song, bar, chord, "updown", 0.4 + 0.3 * offset / 7)
        style.drum_bar(song, bar, kick="four", clap=True, hats="eighths" if offset < 4 else "sixteenths",
                       fill="roll" if offset == 7 else None, ghosts=False)
    style.crash(song, 24)

    # the chorus (bars 33-48, from 60.0 s; second half from 75.0 s)
    for half in range(2):
        first_bar = 32 + half * 8
        style.lead(song, first_bar, CHORUS_THEME, CHORUS_CHORDS, harmony=half == 1, echo=half == 0)
        style.big_hit(song, first_bar, 0, CHORUS_CHORDS[0], 4)
        for offset, chord in enumerate(CHORUS_CHORDS):
            bar = first_bar + offset
            style.bass_bar(song, bar, chord, "house", patch=style.SYNTH_BASS)
            style.strings_pad(song, bar, chord, bars=1, velocity=0.8)
            if half == 0:
                style.brass_pad(song, bar, chord, bars=1, velocity=0.75)
            else:
                style.brass_stabs(song, bar, chord, [(0, 2), (2, 1), (3, 1), (4, 4)] if offset % 2 == 0 else [(10, 1), (12, 2)])
                style.psg_arpeggio(song, bar, chord, "updown", 0.6)
            style.drum_bar(song, bar, kick="push", clap=True, hats="open",
                           fill=("tom" if half == 0 else "snare") if offset == 7 else None)

    # the duel (bars 49-56, from 90.0 s)
    style.lead(song, 48, DUEL_CALLS, DUEL_CHORDS)
    style.crash(song, 48)
    for offset, chord in enumerate(DUEL_CHORDS):
        bar = 48 + offset
        style.bass_bar(song, bar, chord, "drive", patch=style.SYNTH_BASS)
        style.brass_stabs(song, bar, chord, [(8, 2), (12, 2)])
        if offset % 2 == 1:     # the PSG answers the lead's motif
            for pitch, step, steps_long in zip(style.motif_notes(chord, tough=True), (0, 2, 3, 4), style.MOTIF_STEPS):
                song.psg_two.add(song.at(bar, step), megadrive.psg_square(pitch, song.sixteenths(steps_long * 0.7), 0.9,
                                                                          decay=0.1, sustain=0.5))
        style.psg_arpeggio(song, bar, chord, "up", 0.45)
        style.drum_bar(song, bar, kick="gallop", clap=True, hats="sixteenths",
                       fill="tom" if offset in (3, 7) else None, ghosts=False)

    # the system crash (bar 57, 105.0 s): one hard hit, a dive, then the outro
    crash_bar = 56
    style.big_hit(song, crash_bar, 0, chords(["F m"])[0], 10)
    song.pcm.add(song.at(crash_bar, 0), style.TOMS[2])
    song.psg_one.add(song.at(crash_bar, 0), megadrive.psg_sweep(96, 36, 1.2, 1.0))
    song.psg_two.add(song.at(crash_bar, 0), megadrive.psg_sweep(84, 30, 1.6, 0.8))
    song.noise.add(song.at(crash_bar, 0), megadrive.psg_noise(1.2, 1.0, 9000.0, 0.35, 3))
    for repeat in range(4):        # a stuttering, glitching echo of the hit
        song.pcm.add(song.at(crash_bar, 4 + repeat), style.SNARE, 0.5 - 0.1 * repeat)

    # the outro (bars 57-64): strings, piano, the motif slowly, dying out
    for offset, chord in enumerate(OUTRO_CHORDS):
        bar = crash_bar + offset
        if offset % 2 == 0:
            style.strings_pad(song, bar, chord, bars=2, velocity=0.85 - 0.06 * offset)
        if offset >= 1:
            style.piano_bar(song, bar, chord, "sparse", velocity=0.75 - 0.06 * offset)
            style.psg_arpeggio(song, bar, chord, "twinkle", 0.35 - 0.03 * offset)
        if offset % 2 == 0:
            song.bass.add(song.at(bar), megadrive.fm_note(style.SYNTH_BASS, float(chord.bass_root - 12),
                                                          song.sixteenths(30), 0.6))
    for bar, velocity in ((58, 0.75), (60, 0.6)):
        chord = OUTRO_CHORDS[bar - crash_bar]
        for pitch, step, steps_long in zip(style.motif_notes(chord), (0, 4, 6, 8), (4, 2, 2, 20)):
            song.lead.add(song.at(bar, step), megadrive.fm_note(style.LEAD, float(pitch),
                                                                song.sixteenths(steps_long * 0.9), velocity))

    song.render(fade_out=7.0)


if __name__ == "__main__":
    main()
