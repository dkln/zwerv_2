"""Approach Vector — the main theme, F minor (written in E minor), 142 BPM, built on the house style.

The harmony follows the heart of the reference track: i - bII - iv (Em F Am, sounding Fm Gb Bbm),
with G and Bm as colours. Every lead line is generated from the motif (style.theme_from_chords).

Sections can be placed at any bar, so two arrangements share the material; each entry also says
which effect leads into the next section (stutter, tape stop, filter build):

  intro track (56 bars, ~1:35): intro swell 8 | drop 16 | breakdown 16 | riser 8 | climax 8
  menu loop   (64 bars, ~1:48): drop 16 | breakdown 16 | drop B 16 | riser 8 | climax 8

The intro track ends on the climax turnaround, which leads straight into bar 1 of the menu
loop; the menu loop is rendered seamless (its end flows into its own start).
"""
import instruments as inst
from patterns import play_melody, play_repeated
from style import (KIT, MOTIF, StyleTracks, arp_run, build_into, chip_line, chugs, crash, drop_hit, drums, epiano_comp,
                   filter_dip, filter_open_up, guitar_line, lead_line, motif_calls, octave_bass, open_chord, pads, rolling_bass, snare_fill,
                   stutter_into, tape_stop_into, theme_from_chords)
from synth import curve_over_time, lowpass_sweep
from theory import CHORDS

BPM = 142

INTRO_CHORDS = ["Em", "Em", "F", "F", "Am", "G", "B7", "B7"]
DROP_CHORDS = ["Em", "Em", "F", "Am", "Em", "Em", "F", "Am",
               "Em", "Em", "F", "Am", "Bm", "Bm", "Am", "Am"]
BREAKDOWN_CHORDS = ["Am", "Em", "Am", "Em", "F", "Em", "F", "Em",
                    "Am", "Am", "F", "F", "Bm", "Bm", "G", "B7"]
RISER_CHORDS = ["Am", "Am", "F", "F", "Em", "Em", "Bm", "B7"]
CLIMAX_CHORDS = ["Em", "Em", "F", "Am", "Em", "Em", "F", "Em"]

INTRO_ARP = {
    "Em": ["E3", "B3", "E4", "G4", "E4", "B3", "E3", "B3"],
    "F": ["F3", "C4", "F4", "A4", "F4", "C4", "F3", "C4"],
    "Am": ["A2", "E3", "A3", "C4", "A3", "E3", "A2", "E3"],
    "G": ["G3", "D4", "G4", "B4", "G4", "D4", "G3", "D4"],
}


# ---------------------------------------------------------------------------------------------
# Sections: each takes the song, its tracks and the bar where the section starts.
# ---------------------------------------------------------------------------------------------

def section_intro(song, tracks, first_bar):
    """8 bars: 8-bit motif over a closed pad, filter sweep, noise riser, silence + pitch drop."""
    def bar(offset):
        return first_bar + offset - 1

    drop_cut = song.at(bar(8), 3)
    sweep = curve_over_time(song, [(song.at(bar(1)), 200), (song.at(bar(3)), 250), (song.at(bar(5)), 4000),
                                   (song.at(bar(9)), 4000)], 200)
    tracks.intro_pad.process(lambda buffer: lowpass_sweep(buffer, sweep, resonance=1.4))
    tracks.chip_arp.process(lambda buffer: lowpass_sweep(buffer, sweep * 1.5, resonance=1.2))

    tracks.intro_pad.add(inst.supersaw_pad(["E2", "B2", "G3"], song.beats(8) - 0.05, attack=1.5), song.at(bar(1)))
    pads(song, tracks, bar(3), INTRO_CHORDS[2:], track=tracks.intro_pad, attack=0.3)
    for offset, gain in ((1, 0.5), (2, 0.65)):
        play_melody(song, tracks.chip, inst.chip_lead, bar(offset), MOTIF, gain=gain)
    for offset in (3, 4, 5, 6):
        chip_line(song, tracks, bar(offset), motif_calls([INTRO_CHORDS[offset - 1]])[0])
    for offset in range(1, 7):
        play_repeated(song, tracks.chip_arp, inst.chip_arp, bar(offset), 1, INTRO_ARP[INTRO_CHORDS[offset - 1]], 0.25)
    play_repeated(song, tracks.chip_arp, inst.chip_arp, bar(7), 2, ["B4", "D#5", "F#5", "A5", "B5", "D#6"], 0.125,
                  end_time=drop_cut, gain=0.9)
    for offset, note, bar_count in ((3, "F1", 2), (5, "A1", 1), (6, "G1", 1), (7, "B1", 2)):
        tracks.sub.add(inst.sub_bass(note, song.beats(4 * bar_count), attack=1.0 if offset == 3 else 0.1),
                       song.at(bar(offset)))
    tracks.noise.add(inst.chip_noise_sweep(song.beats(8), start_level=0.02, end_level=0.4), song.at(bar(3)))
    tracks.noise.add(inst.chip_noise_sweep(song.beats(7), start_level=0.05, end_level=1.0), song.at(bar(7)))
    song.silence(drop_cut, song.at(bar(9)), except_tracks=["fx"])
    tracks.fx.add(inst.chip_pitch_drop("E6", "E2", 0.2), drop_cut)


def section_drop(song, tracks, first_bar, variant=False):
    """16 bars: full groove, rolling bass, chugs, ping-pong motif arp, motif theme on lead + guitar."""
    drop_hit(song, tracks, first_bar)
    pads(song, tracks, first_bar, DROP_CHORDS)
    for offset, chord_name in enumerate(DROP_CHORDS):
        bar = first_bar + offset
        drums(song, tracks, bar)
        rolling_bass(song, tracks, bar, chord_name)
        chugs(song, tracks, bar, chord_name, gain=0.9)
        arp_run(song, tracks, bar, chord_name, gain=0.7 if offset < 8 else 0.85)
    snare_fill(song, tracks, first_bar + 15)
    crash(song, tracks, song.at(first_bar + 8))
    # Filter move: dull at the end of the first half, bright again for the second half.
    filter_dip(song, first_bar + 6, down_beats=4, hold_beats=2, up_beats=2, lowest=380)
    if variant:
        filter_dip(song, first_bar + 12, beat=2, down_beats=2, up_beats=4, lowest=900)
    theme = theme_from_chords(DROP_CHORDS)
    lead_line(song, tracks, first_bar, theme, harmony_chords=DROP_CHORDS if variant else None,
              semitones=12 if variant else 0, gain=0.8 if variant else 1.0)
    guitar_line(song, tracks, first_bar, theme, semitones=-12 if not variant else 0, gain=0.8)
    if variant:
        for offset, phrase in enumerate(motif_calls(DROP_CHORDS[8:])):
            chip_line(song, tracks, first_bar + 8 + offset, phrase, gain=0.6)


def section_breakdown(song, tracks, first_bar):
    """16 bars: e-piano, pad and the motif arp in front; halftime with octave bass, then the full
    groove with rolling bass; in the second half the 8-bit lead calls the motif on every chord.
    Starts dull and opens up over the first four bars."""
    filter_open_up(song, first_bar, bars=4, lowest=320)
    pads(song, tracks, first_bar, BREAKDOWN_CHORDS)
    for offset, chord_name in enumerate(BREAKDOWN_CHORDS):
        bar = first_bar + offset
        arp_run(song, tracks, bar, chord_name, gain=1.0 if offset < 8 else 0.8)
        epiano_comp(song, tracks, bar, chord_name, gain=1.0 if offset < 8 else 0.7)
        if offset < 8:
            octave_bass(song, tracks, bar, chord_name, gain=0.85)
            drums(song, tracks, bar, kit="halftime")
        else:
            rolling_bass(song, tracks, bar, chord_name)
            drums(song, tracks, bar)
    for offset, phrase in enumerate(motif_calls(BREAKDOWN_CHORDS[8:])):
        chip_line(song, tracks, first_bar + 8 + offset, phrase)
    crash(song, tracks, song.at(first_bar))
    crash(song, tracks, song.at(first_bar + 8))
    snare_fill(song, tracks, first_bar + 15)


def section_riser(song, tracks, first_bar):
    """8 bars: a tight build: four-on-the-floor, arps and chugs getting louder, motif calls."""
    pads(song, tracks, first_bar, RISER_CHORDS)
    for offset, chord_name in enumerate(RISER_CHORDS):
        bar = first_bar + offset
        drums(song, tracks, bar, kit="four", gain=0.8 + 0.03 * offset)
        rolling_bass(song, tracks, bar, chord_name, gain=0.85 + 0.02 * offset)
        arp_run(song, tracks, bar, chord_name, gain=0.7 + 0.04 * offset)
        chugs(song, tracks, bar, chord_name, gain=0.6 + 0.05 * offset)
    for offset, phrase in enumerate(motif_calls(RISER_CHORDS)):
        chip_line(song, tracks, first_bar + offset, phrase, gain=0.8)
    tracks.noise.add(inst.chip_noise_sweep(song.beats(32), start_level=0.02, end_level=0.45), song.at(first_bar))
    crash(song, tracks, song.at(first_bar))
    snare_fill(song, tracks, first_bar + 7)


def section_climax(song, tracks, first_bar):
    """8 bars: everything together, the motif theme on lead, guitar and 8-bit, Em hit, turnaround."""
    beat = song.beat
    drop_hit(song, tracks, first_bar)
    filter_dip(song, first_bar + 3, beat=2, down_beats=2, up_beats=2, lowest=1200)
    pads(song, tracks, first_bar, CLIMAX_CHORDS[:7])
    for offset, chord_name in enumerate(CLIMAX_CHORDS[:7]):
        bar = first_bar + offset
        drums(song, tracks, bar)
        rolling_bass(song, tracks, bar, chord_name)
        chugs(song, tracks, bar, chord_name)
        arp_run(song, tracks, bar, chord_name, gain=0.9)
    crash(song, tracks, song.at(first_bar + 4))
    theme = theme_from_chords(CLIMAX_CHORDS[:7])
    lead_line(song, tracks, first_bar, theme)
    guitar_line(song, tracks, first_bar, theme, semitones=-12, gain=0.8)
    chip_line(song, tracks, first_bar, theme[:16], gain=0.6)

    # Last bar: Em hit, bass turnaround, falling 8-bit fill -> next section starts on Em.
    last_bar = first_bar + 7
    tracks.kick.add(KIT.kick(), song.at(last_bar))
    song.kick_times.append(song.at(last_bar))
    tracks.snare.add(KIT.snare(), song.at(last_bar))
    tracks.clap.add(KIT.clap(), song.at(last_bar))
    crash(song, tracks, song.at(last_bar))
    tracks.sub.add(inst.sub_boom(), song.at(last_bar), 0.9)
    open_chord(song, tracks, last_bar, 0, "Em", 0.9)
    tracks.pad.add(inst.supersaw_pad(CHORDS["Em"]["pad"], beat * 1.5, attack=0.02), song.at(last_bar))
    lead_line(song, tracks, last_bar, [("E5", 1)], echo=False)
    play_melody(song, tracks.bass, inst.retro_bass, last_bar,
                [("E2", 0.5), ("G2", 0.5), ("A2", 0.5), ("A#2", 0.5), ("B2", 1)], start_beat=1.0, legato=0.8)
    for step, note in enumerate(["B6", "F#6", "D#6", "B5", "F#5", "D#5", "B4", "F#4"]):
        tracks.chip.add(inst.chip_arp(note, beat * 0.1), song.at(last_bar, 3 + step * 0.125))


def section_drop_b(song, tracks, first_bar):
    section_drop(song, tracks, first_bar, variant=True)


# (section, bars, effect leading into the next section)
INTRO_ARRANGEMENT = [(section_intro, 8, None), (section_drop, 16, "stutter"), (section_breakdown, 16, "stutter"),
                     (section_riser, 8, "build"), (section_climax, 8, None)]
MENU_ARRANGEMENT = [(section_drop, 16, "stutter"), (section_breakdown, 16, "build"), (section_drop_b, 16, "tape"),
                    (section_riser, 8, "build"), (section_climax, 8, None)]


def transition(song, tracks, next_bar, kind):
    if kind == "stutter":
        stutter_into(song, next_bar, beats=1.0)
    elif kind == "tape":
        tape_stop_into(song, next_bar, beats=2.0)
    elif kind == "build":
        build_into(song, tracks, next_bar, bars=2)


def arrangement_composer(arrangement):
    def compose(song, first_bar):
        tracks = StyleTracks(song)
        bar = first_bar
        for section, bar_count, effect in arrangement:
            section(song, tracks, bar)
            bar += bar_count
            if effect:
                transition(song, tracks, bar, effect)
    return compose


def bar_count(arrangement):
    return sum(bars for _, bars, _ in arrangement)


# What render.py writes (into assets/audio/muziek/ unless --out-dir is given).
RENDERS = [
    {"file": "approach_vector_intro.ogg", "bpm": BPM, "bars": bar_count(INTRO_ARRANGEMENT),
     "compose": arrangement_composer(INTRO_ARRANGEMENT)},
    {"file": "approach_vector_menu_loop.ogg", "bpm": BPM, "bars": bar_count(MENU_ARRANGEMENT),
     "compose": arrangement_composer(MENU_ARRANGEMENT), "loop": True},
]
