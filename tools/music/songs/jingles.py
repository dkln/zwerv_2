"""Short stingers in the house style (style.py): same tracks and sounds as the songs, motif-based.

Every stinger quotes the motif (E G F# B):
  win   (max 4 s): the motif fast up into an E major hit, short groove with the motif in major
                   over E A B, final E major hit
  lose  (max 4 s): the motif starts, then sinks step by step (Em F Am B7 -> low E); no pitch bends
  death (max 4 s): low distorted hit, 8-bit crash down, the motif slowed down an octave lower
  level up (max 4 s): XP-bar run up, C -> D -> the motif in E major with bells and crash

`seconds` is the hard length; render.py cuts and fades there.
"""
import instruments as inst
from patterns import play_melody
from synth import glide, seconds_to_samples
from theory import frequency, midi
from style import KIT, MOTIF_MAJOR, MOTIF_NOTES, StyleTracks

def double_tracked_chord(song, tracks, notes, time, gate, palm_mute=False, gain=1.0):
    for guitar, offset in ((tracks.guitar_left, 0.0), (tracks.guitar_right, 0.008)):
        guitar.add(inst.guitar_chord(notes, gate, palm_mute=palm_mute), time + offset, gain)


def groove_from(song, tracks, first_bar, start_beat, end_beat, bass_note):
    """Four-on-the-floor kick, backbeat, 8th hats and octave bass between two beats."""
    beat_number = start_beat
    while beat_number < end_beat:
        time = song.at(first_bar, beat_number)
        tracks.kick.add(KIT.kick(), time, 0.8)
        song.kick_times.append(time)
        if int(beat_number - start_beat) % 2 == 1:
            tracks.snare.add(KIT.snare(), time, 0.6)
            tracks.clap.add(KIT.clap(), time, 0.8)
        for half in (0.0, 0.5):
            tracks.hats.add(KIT.hat(), song.at(first_bar, beat_number + half), 0.8)
            octave = 12 if half else 0
            tracks.bass.add(inst.retro_bass(midi(bass_note) + octave, song.beat * 0.35),
                            song.at(first_bar, beat_number + half), 0.9)
        beat_number += 1


def compose_win(song, first_bar):
    """The motif fast up into an E major hit, a short groove with the motif in major, final hit."""
    tracks = StyleTracks(song)
    beat = song.beat
    run = [("E5", 0.25), ("G5", 0.25), ("F#5", 0.25), ("B5", 0.25)]  # the motif, fast and leaping up
    play_melody(song, tracks.chip, inst.chip_lead, first_bar, run, duty=0.25, with_vibrato=False)
    play_melody(song, tracks.lead, inst.synth_lead, first_bar, run, gain=0.6)

    hit = song.at(first_bar, 1)
    tracks.lead.add(inst.synth_lead("E6", beat * 1.8, release=0.2), hit)
    tracks.chip.add(inst.chip_lead("B5", beat * 1.8, duty=0.5), hit, 0.6)
    double_tracked_chord(song, tracks, ["E2", "B2", "E3"], hit, beat * 1.8)
    tracks.brass.add(inst.poly_brass(["E3", "B3", "E4", "G#4"], beat * 1.8), hit)
    tracks.cymbals.add(inst.crash(), hit)
    tracks.sub.add(inst.sub_boom(1.2), hit, 0.6)
    groove_from(song, tracks, first_bar, 1, 7, "E2")

    for beat_number, voicing in ((1, ["E3", "B3", "E4", "G#4"]), (3, ["A2", "E3", "A3", "C#4"]),
                                 (5, ["B2", "F#3", "B3", "D#4"])):
        tracks.pad.add(inst.supersaw_pad(voicing, beat * 1.95, attack=0.03, release=0.2), song.at(first_bar, beat_number))
        for step, note in enumerate([voicing[3], voicing[2], voicing[1], voicing[2]] * 2):
            (tracks.arp_left if step % 2 == 0 else tracks.arp_right).add(inst.synth_pluck(midi(note) + 12, beat * 0.22, 6000, 0.2),
                           song.at(first_bar, beat_number + step * 0.25), 0.8)
    play_melody(song, tracks.lead, inst.synth_lead, first_bar, MOTIF_MAJOR, start_beat=3.0)
    play_melody(song, tracks.chip, inst.chip_lead, first_bar, MOTIF_MAJOR, start_beat=3.0, gain=0.5, duty=0.25)

    final = song.at(first_bar, 7)
    tracks.kick.add(KIT.kick(), final)
    tracks.snare.add(KIT.snare(), final, 0.8)
    tracks.cymbals.add(inst.crash(), final)
    double_tracked_chord(song, tracks, ["E2", "B2", "E3"], final, beat * 2.5)
    tracks.brass.add(inst.poly_brass(["E3", "B3", "E4", "G#4"], beat * 2.5), final)
    tracks.pad.add(inst.supersaw_pad(["E3", "B3", "E4", "G#4"], beat * 2.5, attack=0.02, release=0.6), final)
    tracks.lead.add(inst.synth_lead("E6", beat * 2.5, release=0.3), final, 0.8)
    for step, note in enumerate(["E5", "G#5", "B5", "E6", "G#6", "B6"]):
        tracks.chip_echo.add(inst.chip_arp(note, beat * 0.1), final + song.beats(0.125 * step), 0.8)


def compose_lose(song, first_bar):
    """The motif starts, then sinks step by step instead of landing: Em F Am B7 -> low E.
    No pitch bends anywhere: only sounds that stay on pitch (8-bit lead without vibrato, e-piano,
    pad, pluck)."""
    tracks = StyleTracks(song)
    beat = song.beat
    melody = [("E5", 0.5), ("G5", 0.25), ("F#5", 0.25),   # the motif begins...
              ("E5", 0.5), ("D5", 0.5),                    # ...hesitates
              ("C5", 1),
              ("B4", 2),                                   # lands too low, on the dominant
              ("E4", 1.5)]                                 # and gives up
    play_melody(song, tracks.chip, inst.chip_lead, first_bar, melody, with_vibrato=False, legato=0.9)
    play_melody(song, tracks.chip_echo, inst.chip_lead, first_bar, melody, start_beat=0.75, with_vibrato=False,
                duty=0.25, gain=0.5)
    for beat_number, length, voicing, root in ((0, 1, ["E3", "B3", "G4"], "E2"), (1, 1, ["F3", "A3", "E4"], "F1"),
                                               (2, 1, ["A2", "E3", "C4"], "A1"),
                                               (3, 2, ["B2", "D#3", "F#3", "A3"], "B1"),
                                               (5, 2, ["E2", "B2", "G3"], "E1")):
        time = song.at(first_bar, beat_number)
        tracks.pad.add(inst.supersaw_pad(voicing, beat * length * 0.95, attack=0.03, release=0.3), time, 0.8)
        tracks.epiano.add(inst.fm_epiano([midi(note) + 12 for note in voicing], beat * length * 0.9), time, 0.8)
        tracks.sub.add(inst.sub_bass(root, beat * length * 0.9, release=0.2), time, 0.6)
    tracks.kick.add(KIT.kick(), song.at(first_bar, 0), 0.5)
    tracks.kick.add(KIT.kick(), song.at(first_bar, 3), 0.5)
    tracks.kick.add(KIT.kick(), song.at(first_bar, 5), 0.4)
    for step, note in enumerate(["E5", "B4", "G4", "E4", "B3", "G3"]):
        tracks.arp_left.add(inst.synth_pluck(midi(note), beat * 0.22, 2600, 0.25), song.at(first_bar, 5 + step * 0.25), 0.6)


def compose_death(song, first_bar):
    tracks = StyleTracks(song)
    beat = song.beat
    start = song.at(first_bar)
    tracks.kick.add(KIT.kick(), start)
    tracks.snare.add(KIT.snare(), start, 0.9)
    tracks.cymbals.add(inst.crash(3.0), start)
    tracks.sub.add(inst.sub_boom(3.0), start)
    double_tracked_chord(song, tracks, ["E2", "B2", "E3"], start, beat * 3.0)
    drop = glide(frequency("E6"), frequency("E2"), seconds_to_samples(0.6))
    tracks.chip.add(inst.chip_lead(drop, 0.55, with_vibrato=False), start, 0.8)
    tracks.noise.add(inst.chip_noise_sweep(1.2, start_rate=20000, end_rate=600, start_level=1.0, end_level=0.05), start)
    slow_motif = list(zip(MOTIF_NOTES, [1, 0.5, 0.5, 3]))  # the motif notes, slowed down
    play_melody(song, tracks.lead_guitar, inst.guitar_lead, first_bar, slow_motif, start_beat=1.0, legato=0.98,
                semitones=-12)
    play_melody(song, tracks.chip, inst.chip_lead, first_bar, slow_motif, start_beat=1.0, gain=0.6, duty=0.25)
    tracks.pad.add(inst.supersaw_pad(["E2", "B2", "G3", "C4"], beat * 5.0, attack=0.4, release=1.2), start)
    tracks.kick.add(KIT.kick(), song.at(first_bar, 4.0), 0.7)
    tracks.sub.add(inst.sub_bass("E1", beat * 3.0, release=0.8), song.at(first_bar, 4.0), 0.8)


def compose_level_up(song, first_bar):
    tracks = StyleTracks(song)
    beat = song.beat
    start = song.at(first_bar)
    # XP bar filling up: fast 32nd run plus a rising noise sweep.
    for step, note in enumerate(["E4", "G4", "B4", "E5", "G5", "B5", "E6", "G6"]):
        tracks.chip.add(inst.chip_arp(note, beat * 0.1), start + song.beats(step * 0.125), 0.8)
    tracks.noise.add(inst.chip_noise_sweep(beat, start_rate=2000, end_rate=22000, start_level=0.1, end_level=0.8), start)

    # C -> D steps, then the E major landing.
    for beat_number, chord, power, lead_note in ((1, ["C3", "G3", "C4", "E4"], ["C3", "G3", "C4"], "G5"),
                                                 (2, ["D3", "A3", "D4", "F#4"], ["D3", "A3", "D4"], "A5")):
        time = song.at(first_bar, beat_number)
        tracks.lead.add(inst.synth_lead(lead_note, beat * 0.9, release=0.08), time)
        tracks.chip.add(inst.chip_lead(lead_note, beat * 0.9, with_vibrato=False), time, 0.6)
        tracks.pad.add(inst.supersaw_pad(chord, beat * 0.95, attack=0.02, release=0.2), time)
        double_tracked_chord(song, tracks, power, time, beat * 0.9, gain=0.8)
        tracks.kick.add(KIT.kick(), time, 0.8)
        tracks.snare.add(KIT.snare(), time, 0.6)

    landing = song.at(first_bar, 3)
    major_motif = [("E6", 1), ("G#6", 0.5), ("F#6", 0.5), ("B6", 2.5)]  # the motif, now in E major
    play_melody(song, tracks.lead, inst.synth_lead, first_bar, major_motif, start_beat=3.0, legato=1.0)
    play_melody(song, tracks.lead_guitar, inst.guitar_lead, first_bar, major_motif, start_beat=3.0, legato=1.0,
                semitones=-12, gain=0.8)
    tracks.chip.add(inst.chip_lead("G#5", beat * 4.5), song.at(first_bar, 3.5), 0.5)
    tracks.pad.add(inst.supersaw_pad(["E3", "B3", "E4", "G#4", "B4"], beat * 4.5, attack=0.03, release=1.0), landing)
    double_tracked_chord(song, tracks, ["E2", "B2", "E3"], landing, beat * 4.0)
    tracks.brass.add(inst.poly_brass(["E3", "B3", "E4", "G#4"], beat * 4.0), landing)
    tracks.clap.add(KIT.clap(), landing)
    tracks.kick.add(KIT.kick(), landing)
    tracks.snare.add(KIT.snare(), landing, 0.9)
    tracks.cymbals.add(inst.crash(), landing)
    tracks.sub.add(inst.sub_boom(2.0), landing, 0.8)
    sparkle = ["E5", "G#5", "B5", "E6", "G#6", "B6", "G#6", "E6"]
    for step in range(12):
        tracks.chip_echo.add(inst.chip_arp(sparkle[step % len(sparkle)], beat * 0.1), song.at(first_bar, 3.5 + step * 0.25), 0.7)
    for step, note in enumerate(["B6", "E7", "G#6", "B6"]):
        tracks.chip_echo.add(inst.bell(note, beat * 0.3), song.at(first_bar, 4 + step * 0.75), 0.9)


RENDERS = [
    {"file": "deuntje_gewonnen.ogg", "bpm": 150, "seconds": 4.0, "compose": compose_win},
    {"file": "deuntje_verloren.ogg", "bpm": 110, "seconds": 4.0, "compose": compose_lose},
    {"file": "deuntje_dood.ogg", "bpm": 110, "seconds": 4.0, "compose": compose_death},
    {"file": "deuntje_level_omhoog.ogg", "bpm": 140, "seconds": 4.0, "compose": compose_level_up},
]
