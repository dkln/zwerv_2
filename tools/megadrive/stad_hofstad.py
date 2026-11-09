"""'Stad hofstad': the city loop of the court quarter (Paleis Noordeinde, Lange Voorhout):
stately and calm, palaces and lime trees at night.

One of the city loops on the shared plan (stad_plan.py: 104 BPM, F minor, 40 bars = 92 s).
No beat: FM strings carry it, a harpsichord-like PSG arpeggio picks the chords up and down, a
held bass, FM bells on the downbeats, soft timpani (toms) at the turns, and a noble lead in
long notes that opens its phrases with the motif; a soft brass pad in C, the royal moment.

    A      strings, bass, the harpsichord arpeggio; bells
    A'     the lead's noble theme
    B      the arpeggio up an octave, the lead answers
    break  only strings and bells, the motif once
    C      brass pad, the theme again with the PSG harmony, timpani
    tag    strings and arpeggio, timpani into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_hofstad  (writes assets/audio/muziek/stad_hofstad_loop.ogg)
"""
import megadrive
import stad_plan
import style
from stad_plan import BARS, BPM, SECTIONS, bars_of, theme
from style import Song

THEMES = {
    "A2": theme("M R:8", "5:16", "M 3:8", "R:12 -:4", "M R:8", "3:8 5:8", "M 8:8", "5:12 -:4"),
    "B": theme("-:8 5:8", "3:16", "-:8 9:8", "R:16", "-:8 5:8", "8:16", "5:8 3:8", "R:12 -:4"),
    "break": theme("-:16", "M -:8", "-:16", "-:16"),
    "C": theme("M R:8", "5:16", "M 3:8", "R:12 -:4", "M R:8", "3:8 5:8", "M 9:8", "R:12 -:4"),
}


def timpani(song, bar, step=0, velocity=0.4):
    for offset, tom_index in ((0, 2), (2, 2)):
        song.pcm.add(song.at(bar, step + offset), style.TOMS[tom_index], velocity)


def main() -> None:
    song = Song("stad_hofstad_loop.ogg", bpm=BPM, bars=BARS)
    for name, first_bar, section_chords in SECTIONS:
        if name in THEMES:
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.62, slides=True,
                       harmony=name == "C")
        for bar, offset, chord, last in bars_of(first_bar, section_chords):
            style.strings_pad(song, bar, chord, bars=1, velocity=0.8)
            style.bass_bar(song, bar, chord, "hold", velocity=0.55)
            if name != "break":
                style.psg_arpeggio(song, bar, chord, "updown", 0.32, every=2, octave=2 if name == "B" else 1)
            top = max(chord.voicing) + 24
            song.piano.add(song.at(bar, 0), megadrive.fm_note(style.BELL, float(top), song.sixteenths(8), 0.4))
            if name == "C":
                style.brass_pad(song, bar, chord, bars=1, velocity=0.35)
            if offset == 0 and name in ("A2", "C"):
                timpani(song, bar)
            if last and name in ("C", "tag"):
                timpani(song, bar, 12, 0.5)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
