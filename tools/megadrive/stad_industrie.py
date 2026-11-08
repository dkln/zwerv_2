"""'Stad industrie': the city loop of the industrial zone and the motorway (Binckhorst, A12):
hard, mechanical, techno.

One of the five neighbourhood loops on the shared plan (stad_plan.py: 128 BPM, F minor, 40 bars
= 75 s). Dead straight: kick on every beat throughout (except the break), 16th synth bass, a
repeating PSG ostinato, clangs of an inharmonic FM "metal" patch like machines, toms, and the
lead hammering the motif (often twice a bar), long robotic notes in B.

    A      kick, bass, ostinato, clangs; the tough motif on bars 1 and 5
    A'     the motif hammered, brass stabs
    B      the lead in long notes over the machine, open hats
    break  no kick: clangs and the ostinato, the motif once, a roll
    C      everything: motif on every chord, PSG arpeggios, extra kicks
    tag    the A machine, tom fill into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_industrie  (writes assets/audio/muziek/stad_industrie_loop.ogg)
"""
import megadrive
import style
from megadrive import FmPatch, Operator
from stad_plan import BARS, BPM, SECTIONS, bars_of
from style import Song

# an inharmonic, clangy FM patch: struck metal in a hall
METAL = FmPatch("metal", algorithm=4, feedback=0.4, operators=(
    Operator(ratio=1.41, level=3.0, attack=0.001, decay=0.12, sustain=0.0, release=0.1),
    Operator(ratio=1.0, level=0.6, attack=0.001, decay=0.35, sustain=0.0, release=0.15),
    Operator(ratio=3.73, level=2.0, attack=0.001, decay=0.06, sustain=0.0, release=0.05),
    Operator(ratio=0.5, level=0.4, attack=0.001, decay=0.25, sustain=0.0, release=0.1),
))

THEMES = {
    "A": "M! -:8 -:16 -:16 -:16 M! -:8 -:16 -:16 -:16",
    "A2": "M! M! M -:8 M! M! -:16 M! M! M -:8 M M M M",
    "B": "F6:16 Db6:16 Bb5:16 Db6:16 C6:16 Bb5:16 C6:16 M -:8",
    "break": "-:16 -:16 -:16 M -:8",
    "C": "M M M M M! M! M! C6:4 Ab5:4 M M M M M M M E6:8",
    "tag": "M! -:8 -:16 -:16 -:16",
}

OSTINATO = (0, 2, 1, 0, 3, 0, 2, 1)     # chord-tone indices, an eighth each


def ostinato(song, bar, chord, volume=0.6):
    notes = [note + 12 for note in sorted(chord.voicing)[:4]]
    for step in range(0, 16, 2):
        song.psg_one.add(song.at(bar, step), megadrive.psg_square(notes[OSTINATO[step // 2]], song.sixteenths(1.2),
                                                                  volume, decay=0.04, sustain=0.2, release=0.02))


def clangs(song, bar, chord, steps=(6, 14), velocity=0.7):
    for step in steps:
        song.brass.add(song.at(bar, step), megadrive.fm_note(METAL, float(chord.bass_root + 24), song.sixteenths(2), velocity))


def main() -> None:
    song = Song("stad_industrie_loop.ogg", bpm=BPM, bars=BARS, swing=0.0)
    for name, first_bar, section_chords in SECTIONS:
        style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.95)
        if name in ("A", "A2", "C"):
            style.crash(song, first_bar, volume=0.8)
        for bar, offset, chord, last in bars_of(first_bar, section_chords):
            if name == "break":
                style.bass_bar(song, bar, chord, "whole", patch=style.SYNTH_BASS, velocity=0.8)
                ostinato(song, bar, chord, 0.5)
                clangs(song, bar, chord, (0, 6, 10, 14), 0.6)
                style.drum_bar(song, bar, kick="none", snare="none", hats="sixteenths", hat_volume=0.5,
                               fill="roll" if last else None, ghosts=False)
                continue
            style.bass_bar(song, bar, chord, "drive", patch=style.SYNTH_BASS)
            ostinato(song, bar, chord, 0.6 if name != "B" else 0.45)
            clangs(song, bar, chord)
            if name == "A2":
                style.brass_stabs(song, bar, chord, [(8, 1), (11, 1), (14, 2)], 0.8)
            if name == "B":
                style.strings_pad(song, bar, chord, bars=1, velocity=0.5)
            if name == "C":
                style.psg_arpeggio(song, bar, chord, "updown", 0.5, track=song.psg_two)
                style.brass_stabs(song, bar, chord, [(-2, 2), (6, 2)], 0.8)
            fill = "tom" if name == "tag" and last else ("snare" if last else None)
            style.drum_bar(song, bar, kick="four" if name != "C" else "push", snare="none", clap=True,
                           hats="open" if name in ("B", "C") else "sixteenths", fill=fill, ghosts=False)
            if offset % 2 == 1 and not last:
                song.pcm.add(song.at(bar, 15), style.TOMS[2], 0.5)
    song.render()


if __name__ == "__main__":
    main()
