"""'Stad torens': the city loop of the office towers (Centraal Station, De Resident,
Beatrixkwartier, Prins Clauslaan): cool and glossy, glass and steel at night.

One of the five neighbourhood loops on the shared plan (stad_plan.py: 104 BPM, F minor, 40 bars
= 92 s). Straight (no swing) deep house: synth bass on the off-beats, electric piano in
off-beat chords, glittering PSG arpeggios with a PSG echo, FM bells, string pads, and the lead
in long, cool notes, each phrase opening with the motif.

    A      piano off-beats, bells, glitter arpeggio, kick and open hats, no lead
    A'     the lead's cool theme (the motif and long notes)
    B      strings and soft brass, the lead high and slow
    break  kick out: bells, strings, the motif once, hats creeping in
    C      everything, the theme with the PSG echo
    tag    the A texture, tom fill into the top

House style: style.py, docs/MUZIEK.md.
Render: tools/megadrive/render.sh stad_torens  (writes assets/audio/muziek/stad_torens_loop.ogg)
"""
import megadrive
import stad_plan
import style
from stad_plan import BARS, BPM, SECTIONS, bars_of
from style import Song

THEMES = {
    "A2": """
        M -:4 C6:4
        Bb5:12 -:4
        M -:4 Db6:4
        C6:8 Ab5:8
        M! -:4 Eb6:4
        Db6:8 Bb5:4 F5:4
        M -:4 Eb6:4
        M -:4 E6:4
    """,
    "B": """
        F6:8 Eb6:4 Db6:4
        C6:16
        Db6:8 Bb5:8
        F5:16
        Eb6:8 C6:8
        Bb5:8 G5:8
        F5:8 G5:8
        M -:8
    """,
    "break": "-:16 -:16 M -:8 -:16",
    "C": """
        M Db6:4 F6:4
        Eb6:12 C6:4
        M C6:8
        Ab5:16
        M Bb5:4 Db6:4
        C6:8 Eb6:8
        M Bb5:8
        M -:8
    """,
    "tag": "M -:8 -:16 -:16 -:16",
}


def bells(song, bar, chord, velocity=0.6):
    """Two FM bell notes per bar on chord tones, high up: the glint on the glass."""
    top = sorted(chord.voicing)
    for step, note in ((0, top[-1] + 24), (10, top[1] + 24)):
        song.piano.add(song.at(bar, step), megadrive.fm_note(style.BELL, float(note), song.sixteenths(5), velocity))


def main() -> None:
    song = Song("stad_torens_loop.ogg", bpm=BPM, bars=BARS, swing=0.0)
    for name, first_bar, section_chords in SECTIONS:
        if name in THEMES:
            style.lead(song, first_bar, THEMES[name], section_chords, velocity=0.9,
                       echo=name == "C", slides=name == "B")
        if name in ("A", "C"):
            style.crash(song, first_bar, volume=0.7)
        for bar, offset, chord, last in bars_of(first_bar, section_chords):
            if name in ("A", "A2", "C", "tag"):
                style.bass_bar(song, bar, chord, "offbeat", patch=style.SYNTH_BASS)
                style.bass_bar(song, bar, chord, "pulse", patch=style.SYNTH_BASS, velocity=0.45)
                style.piano_bar(song, bar, chord, "offbeats", velocity=0.85)
                style.psg_arpeggio(song, bar, chord, "up_octave", 0.55 if name != "A2" else 0.4)
                if offset % 2 == 0:
                    bells(song, bar, chord)
                fill = "tom" if (name == "tag" and last) else ("snare" if last else None)
                style.drum_bar(song, bar, kick="four", snare="none", clap=True, hats="open",
                               fill=fill, ghosts=False, hat_volume=0.8)
                if name == "C":
                    style.strings_pad(song, bar, chord, bars=1, velocity=0.55)
            elif name == "B":
                style.bass_bar(song, bar, chord, "offbeat", patch=style.SYNTH_BASS)
                style.strings_pad(song, bar, chord, bars=1, velocity=0.8)
                style.brass_pad(song, bar, chord, bars=1, velocity=0.5)
                style.psg_arpeggio(song, bar, chord, "up", 0.4, every=2)
                style.drum_bar(song, bar, kick="four", snare="none", clap=True, hats="eighths",
                               fill="drop" if last else None, ghosts=False, hat_volume=0.8)
            else:   # break
                style.bass_bar(song, bar, chord, "whole", patch=style.SYNTH_BASS, velocity=0.7)
                if offset in (0, 2, 3):
                    style.strings_pad(song, bar, chord, bars=2 if offset == 0 else 1)
                bells(song, bar, chord, 0.7)
                style.psg_arpeggio(song, bar, chord, "twinkle", 0.45)
                if offset >= 2:
                    style.drum_bar(song, bar, kick="none", snare="none", hats="sixteenths", hat_volume=0.4 + 0.2 * offset,
                                   fill="roll" if last else None, ghosts=False)
    stad_plan.finish(song)


if __name__ == "__main__":
    main()
