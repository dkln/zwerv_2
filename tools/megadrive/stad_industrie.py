"""'Stad industrie': the city loop of industry and motorway (Binckhorst, A12): hard and
mechanical.

On the shared plan (stad_plan.py). The kick on every beat, the bass driving in sixteenths, FM
metal clangs on the off-beats, a PSG ostinato, palm-muted chugs and power chords, the motif
hammered on the synth lead, the city theme on the twin guitars in C.
Render: tools/megadrive/render.sh stad_industrie
"""
import megadrive
import stad_plan
import style
from stad_plan import THEMES, bars_of, section

HAMMER = "M -:8 M -:8 M -:8 M -:8 M -:8 M -:8 M M M M^"


def machine(song, bar, offset, bar_chord, last, chug=True, fill="snare", hats="sixteenths"):
    style.bass_bar(song, bar, bar_chord, "drive")
    style.arpeggio(song, bar, bar_chord, "rolling", 0.4, every=1, track=song.psg_three)
    for step in (2, 6, 10, 14):
        song.fm_drums.add(song.at(bar, step), megadrive.fm_note(style.METAL, float(bar_chord.melody_root - 12),
                                                                song.sixteenths(1), 0.55 if step % 8 == 2 else 0.4))
    if chug:
        style.power_chords(song, bar, bar_chord, "chug", 0.65)
    style.drum_bar(song, bar, kick="four", hats=hats, fill=fill if last else None, ghosts=False, fm_snare=True)


def main() -> None:
    song = stad_plan.new_song("stad_industrie_loop.ogg", "stad_industrie")
    first_bar, section_chords = section("A")
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        machine(song, bar, offset, bar_chord, last, chug=offset >= 4)
    first_bar, section_chords = section("A2")
    style.lead(song, first_bar, HAMMER, section_chords)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        machine(song, bar, offset, bar_chord, last)
    first_bar, section_chords = section("B")
    style.lead(song, first_bar, THEMES["B"], section_chords, echo=True)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        machine(song, bar, offset, bar_chord, last, chug=False, fill="drop", hats="double")
        style.power_chords(song, bar, bar_chord, "held", 0.6)
    style.crash(song, first_bar)
    first_bar, section_chords = section("break")
    style.lead(song, first_bar, THEMES["break"], section_chords, velocity=0.75)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        style.bass_bar(song, bar, bar_chord, "pulse")
        style.pad(song, bar, bar_chord, velocity=0.6)
        style.drum_bar(song, bar, kick="four" if offset >= 2 else "none", snare="none", hats="eighths",
                       hat_volume=0.6, ghosts=False, fill="roll" if last else None)
    first_bar, section_chords = section("C")
    style.guitar(song, first_bar, THEMES["C"], section_chords, twin=True, octave=-1)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        machine(song, bar, offset, bar_chord, last, chug=False)
        style.brass_stabs(song, bar, bar_chord, [(4, 1), (12, 1)], 0.7)
    style.crash(song, first_bar)
    first_bar, section_chords = section("D")
    style.chip_lead(song, first_bar, THEMES["D"], section_chords, volume=0.75)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        machine(song, bar, offset, bar_chord, last, chug=offset % 2 == 0)
    first_bar, section_chords = section("tag")
    style.lead(song, first_bar, "M -:8 M -:8 M -:8 M M", section_chords)
    for bar, offset, bar_chord, last in bars_of(first_bar, section_chords):
        machine(song, bar, offset, bar_chord, last, fill="tom")
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
