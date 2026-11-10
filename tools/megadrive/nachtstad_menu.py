"""'Nachtstad': the main menu loop, as 2 Tone ska (The Specials, Madness) on the Mega Drive:
fast and upright, the organ skanking on every upbeat, a walking bass, the brass playing the
motif, the drums on one and three with the snare on the backbeat and open hats on the
upbeats, and drum solos between the sections (style.drum_solo).

House style (style.py). 168 BPM, F minor, 40 bars = 57 s, loops seamlessly. The motif opens
every section on the FM lead; the brass doubles it in the finale.

    bars  1-8   A       Fm Gb Bbm Fm twice: skank organ, walking bass, ska drums, the theme
    bars  9-10  solo    the drums alone: down the toms, then snare and kick trading
    bars 11-18  B       Bbm Gb Ab Cm / Bbm Gb Ab C7: lead with harmony, the organ bubbling,
                        brass stabs, PSG counter-line
    bars 19-20  solo    accents with claps, a tom run up
    bars 21-28  A'      the theme an octave up with the PSG echo, brass stabs
    bars 29-32  solo    four bars: toms down, trading, accents, a building roll; brass hits the one
    bars 33-40  finale  the A theme with brass doubling, a tom fill back to the top

Render: tools/megadrive/render.sh nachtstad_menu  (writes assets/audio/muziek/nachtstad_menu_loop.ogg)
"""
import style
from style import Song, chords

A_CHORDS = chords(["F m7", "Gb maj7", "Bb m7", "F m7", "F m7", "Gb maj7", "Bb m7", "C 7"])
B_CHORDS = chords(["Bb m7", "Gb maj7", "Ab maj", "C m7", "Bb m7", "Gb maj7", "Ab maj", "C 7"])

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


def main() -> None:
    song = Song("nachtstad_menu_loop.ogg", bpm=168, bars=40, swing=0.0)

    def ska_bar(bar, chord, organ="skank", bass="walking", fill=None, hats="open", velocity=1.0):
        style.piano_bar(song, bar, chord, organ, velocity=0.9 * velocity, octave=1)
        style.bass_bar(song, bar, chord, bass, patch=style.SLAP_BASS, velocity=0.95 * velocity)
        style.drum_bar(song, bar, kick="ska_push" if bar % 4 == 3 else "ska", clap=False, hats=hats,
                       fill=fill, ghosts=True, velocity=velocity)

    def section_a(first_bar, octave, finale):
        style.lead(song, first_bar, A_THEME, A_CHORDS, octave=octave, echo=octave == 1, velocity=1.0)
        style.crash(song, first_bar)
        for offset, chord in enumerate(A_CHORDS):
            bar = first_bar + offset
            if finale:   # the brass hits the motif with the lead
                style.brass_stabs(song, bar, chord, [(0, 2), (2, 1), (3, 1), (4, 4)], 0.8)
            elif offset % 2 == 1:
                style.brass_stabs(song, bar, chord, [(10, 1), (14, 2)], 0.7)
            if octave == 1:
                style.psg_arpeggio(song, bar, chord, "updown", 0.55, every=2)
            last = first_bar + 7 == bar and finale
            ska_bar(bar, chord, organ="bubble" if finale else "skank",
                    bass="walking_up" if offset % 2 else "walking", fill="tom" if last else None)

    def solo(first_bar, solos, chord):
        for offset, name in enumerate(solos):
            style.drum_solo(song, first_bar + offset, name)
        # the brass hits the one, then leaves the drums alone
        style.brass_stabs(song, first_bar, chord, [(0, 2)], 0.9)
        style.bass_bar(song, first_bar, chord, "hold", patch=style.SLAP_BASS, velocity=0.6)

    section_a(0, 0, False)
    solo(8, ["toms_down", "trade"], A_CHORDS[0])

    # B: lead with harmony over the bubbling organ, brass stabs, PSG counter-line
    style.lead(song, 10, B_THEME, B_CHORDS, harmony=True, slides=True)
    style.crash(song, 10, volume=0.7)
    for offset, chord in enumerate(B_CHORDS):
        bar = 10 + offset
        style.brass_stabs(song, bar, chord, [(0, 2), (6, 1), (10, 2)] if offset % 2 == 0 else [(4, 1), (12, 2)], 0.7)
        style.psg_arpeggio(song, bar, chord, "motif", 0.5, track=song.psg_one)
        ska_bar(bar, chord, organ="bubble", bass="walking_up" if offset % 2 else "walking")
    solo(18, ["accents", "trade"], B_CHORDS[-1])

    section_a(20, 1, False)
    solo(28, ["toms_down", "trade", "accents", "roll"], A_CHORDS[0])

    section_a(32, 0, True)

    song.render()


if __name__ == "__main__":
    main()
