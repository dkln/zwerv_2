"""'Stad markt': the city loop of the market quarters (Schilderswijk with the Haagse Markt,
the Grote Markt): busy but easy, stalls, spices and voices.

One of the city loops on the shared plan (stad_plan.py: 104 BPM, F minor, 40 bars = 92 s;
the C7 in it gives the E natural of F harmonic minor, the colour of the music). Hand drums
instead of a kit: the low "dum" on the toms and the "tek" on soft claps in a darbuka
pattern, a plucked PSG line on the motif (like a saz), the lyrical bass with a light swing,
FM strings under it, and the lead ornamented with slides.

    A      hand drums, bass, the plucked line
    A'     the lead's ornamented theme
    B      strings, the lead with the PSG harmony
    break  only the hand drums and the plucked line, the motif
    C      everything, the theme again, the "tek" doubled
    tag    drums and pluck, a roll of dums into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_markt  (writes assets/audio/muziek/stad_markt_loop.ogg)
"""
import stad_plan
import style
from stad_plan import BARS, BPM, SECTIONS, bars_of, theme
from style import Song

## The darbuka pattern: (step, "dum" or "tek", velocity).
HAND_DRUMS = [(0, "dum", 0.8), (3, "tek", 0.35), (6, "tek", 0.45), (8, "dum", 0.7), (10, "tek", 0.4),
              (12, "tek", 0.45), (14, "tek", 0.3)]

THEMES = {
    "A2": theme("M 5:8", "3:4 R:4 3:8", "M 5:4 3:4", "R:12 -:4", "M 8:8", "5:4 3:4 5:8", "M 3:4 R:4", "5:12 -:4"),
    "B": theme("8:8 5:8", "3:4 5:4 3:8", "R:8 3:8", "5:12 -:4", "8:8 9:8", "8:4 5:4 3:8", "M R:8", "3:12 -:4"),
    "break": theme("M -:8", "-:16", "M -:8", "-:16"),
    "C": theme("M 5:8", "3:4 R:4 3:8", "M 5:4 3:4", "R:12 -:4", "M 8:8", "5:4 3:4 5:8", "M 3:4 R:4", "R:12 -:4"),
}


def hand_drums(song, bar, velocity=1.0, doubled=False):
    for step, stroke, stroke_velocity in HAND_DRUMS:
        sound = style.TOMS[2] if stroke == "dum" else style.CLAP
        song.pcm.add(song.at(bar, step), sound, stroke_velocity * velocity * (0.6 if stroke == "tek" else 1.0))
        if doubled and stroke == "tek":
            song.pcm.add(song.at(bar, step + 1), style.CLAP, stroke_velocity * velocity * 0.3)


def main() -> None:
    song = Song("stad_markt_loop.ogg", bpm=BPM, bars=BARS, swing=0.06)
    for name, first_bar, section_chords in SECTIONS:
        if name in THEMES:
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.7, slides=True,
                       harmony=name == "B")
        for bar, offset, chord, last in bars_of(first_bar, section_chords):
            style.psg_arpeggio(song, bar, chord, "motif", 0.3, every=1)
            hand_drums(song, bar, 0.9 if name != "break" else 0.7, doubled=name == "C")
            if name != "break":
                style.bass_bar(song, bar, chord, "lyrical", velocity=0.6)
            if name in ("B", "C"):
                style.strings_pad(song, bar, chord, bars=1, velocity=0.6)
            if name == "tag" and last:
                for step in (12, 13, 14, 15):
                    song.pcm.add(song.at(bar, step), style.TOMS[1], 0.5)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
