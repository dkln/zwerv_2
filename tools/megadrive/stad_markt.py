"""'Stad markt': the city loop of the markets (Grote Markt, Schilderswijk: de Haagse Markt):
hand drums and a plucked line.

On the shared plan (stad_plan.py). Hand drums in a darbuka pattern ("dum" on the low toms,
"tek" on soft claps), a plucked FM line on the arpeggio, the lyrical bass, the lead
ornamented with glides; the V chord brings the C# of D harmonic minor.
Render: tools/megadrive/render.sh stad_markt
"""
import stad_plan
import style
from stad_plan import THEMES, bars_of, section

DUM_TEK = [(0, "dum", 1.0), (3, "tek", 0.5), (4, "tek", 0.7), (6, "dum", 0.8), (8, "dum", 0.9), (11, "tek", 0.5),
           (12, "tek", 0.75), (14, "tek", 0.5), (15, "tek", 0.4)]


def market(song, bar, offset, bar_chord, last, kick=False):
    style.bass_bar(song, bar, bar_chord, "lyrical")
    style.pluck_chord(song, bar, bar_chord, (0, 3, 6, 8, 11, 14), 0.6, track=song.harmony)
    for step, drum, velocity in DUM_TEK:
        sound = style.TOMS[2] if drum == "dum" else style.CLAP
        song.pcm.add(song.at(bar, step), sound, velocity * (0.8 if drum == "tek" else 1.0))
    if kick:
        style.drum_bar(song, bar, kick="half", snare="none", hats="eighths", hat_volume=0.5, ghosts=False)
    if last:
        for step, tom in ((12, 0), (13, 1), (14, 1), (15, 2)):
            song.pcm.add(song.at(bar, step), style.TOMS[tom], 0.8)


def main() -> None:
    song = stad_plan.new_song("stad_markt_loop.ogg", "stad_markt")
    for name in ("A", "A2", "B", "break", "C", "D", "tag"):
        first_bar, section_chords = section(name)
        if name in ("A2", "C", "D"):
            style.lead(song, first_bar, THEMES[name], section_chords, slides=True, echo=name == "C")
        elif name == "B":
            style.chip_lead(song, first_bar, THEMES["B"], section_chords, volume=0.7)
        elif name in ("break", "tag"):
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.75, patch=style.PLUCK, track=song.pad)
        for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
            if name == "break":
                style.pad(song, bar, bar_chord, velocity=0.6)
                style.bass_bar(song, bar, bar_chord, "hold")
                continue
            market(song, bar, offset, bar_chord, last, kick=name in ("B", "C"))
            if name == "C":
                style.brass_stabs(song, bar, bar_chord, [(4, 1), (12, 1)], 0.6)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
