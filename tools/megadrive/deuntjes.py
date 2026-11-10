"""The short stingers (one-shots, no loop), all at 128 BPM in the house style (style.py), each one
built on the motif on the FM lead:

    deuntje_kaart_start.ogg   (6 s) start of the map: the motif as a fanfare on Db and Eb with
                              brass, landing on a big F major chord
    deuntje_gewonnen.ogg      (4 s) won: the motif fast and leaping up, an F major hit, a short
                              groove with the motif in major, a final hit
    deuntje_level_omhoog.ogg  (4 s) level up: a PSG run up like a filling XP bar, Db - Eb, the
                              motif in F major with bells, sparkle and crash
    deuntje_verloren.ogg      (4 s) lost: the motif begins, then sinks step by step over
                              Fm Gb Bbm C7 down to a low F
    deuntje_nieuwe_missie.ogg (2.2 s) a new mission: the motif quick on bells, a brass stab on
                              Db, then Eb, up to an open F with a little sparkle (a "go!")
    deuntje_dood.ogg          (4 s) death: a heavy low hit, a PSG pitch dive, the motif slowed
                              down an octave lower over a dark chord, dying away

Every stinger stops at its length with a short fade (`render(fade_out=...)`).
Render: tools/megadrive/render.sh deuntjes  (or a single one: render.sh deuntjes kaart_start)
"""
import sys

import megadrive
import style
from style import Chord, Song

BPM = 128


def one_shot(file_name: str, seconds: float) -> Song:
    bar_seconds = 60.0 / BPM * 4
    return Song(file_name, bpm=BPM, bars=int(seconds // bar_seconds) + 1, loop=False, seconds=seconds)


def four_on_the_floor(song: Song, bar: int, first_step: int, last_step: int, chord: Chord) -> None:
    for step in range(first_step, last_step):
        if step % 4 == 0:
            song.pcm.add(song.at(bar, step), style.KICK, 0.8)
            song.bass.add(song.at(bar, step + 2), megadrive.fm_note(style.SYNTH_BASS, float(chord.bass_root + 12),
                                                                    song.sixteenths(1.6), 0.9))
        if step % 8 == 4:
            song.pcm.add(song.at(bar, step), style.CLAP, 0.7)
        if step % 2 == 0:
            song.noise.add(song.at(bar, step), megadrive.psg_noise(0.05, 0.6, 32000.0, 0.018, step))


def map_start() -> None:
    song = one_shot("deuntje_kaart_start.ogg", 6.0)
    fanfare = style.chords(["Db maj", "Eb maj", "F maj"])
    style.lead(song, 0, "M -:8 M -:8 R:16", fanfare)
    for bar, chord in enumerate(fanfare[:2]):
        style.brass_stabs(song, bar, chord, [(0, 2), (2, 1), (3, 1), (4, 4), (12, 2), (14, 2)], 1.0)
        style.bass_bar(song, bar, chord, "pulse", patch=style.SYNTH_BASS)
        style.drum_bar(song, bar, clap=True, hats="sixteenths", ghosts=False, fill="snare" if bar == 1 else None)
        style.psg_arpeggio(song, bar, chord, "up", 0.6)
    style.big_hit(song, 2, 0, fanfare[2], 20)
    for step, pitch in enumerate([65, 69, 72, 77, 81, 84, 89, 93]):
        song.psg_one.add(song.at(2, step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.7, decay=0.05))
    song.render(target_rms_db=-14.0, fade_out=1.2)


def won() -> None:
    song = one_shot("deuntje_gewonnen.ogg", 4.0)
    tonic = Chord("F maj")
    run = [Chord("F maj").melody_root + interval for interval in (0, 4, 2, 7)]   # the motif, leaping up
    for step, pitch in enumerate(run):
        song.lead.add(song.at(0, step), megadrive.fm_note(style.LEAD, float(pitch), song.sixteenths(0.8), 1.0))
        song.psg_two.add(song.at(0, step), megadrive.psg_square(pitch + 12, song.sixteenths(0.8), 0.6))
    style.big_hit(song, 0, 4, tonic, 6)
    song.lead.add(song.at(0, 4), megadrive.fm_note(style.LEAD, float(tonic.melody_root + 12), song.sixteenths(5), 1.0))
    four_on_the_floor(song, 0, 4, 16, tonic)
    four_on_the_floor(song, 1, 0, 8, tonic)
    style.lead(song, 0, "-:12 M -:4 -:8", [tonic, Chord("Bb maj")])
    style.psg_arpeggio(song, 1, Chord("Bb maj"), "up", 0.55)
    style.big_hit(song, 1, 8, tonic, 10)
    song.lead.add(song.at(1, 8), megadrive.fm_note(style.LEAD, float(tonic.melody_root + 12), song.sixteenths(9), 1.0))
    for step, pitch in enumerate([77, 81, 84, 89, 93, 96]):
        song.psg_one.add(song.at(1, 8 + step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.6))
    song.render(target_rms_db=-14.0, fade_out=0.8)


def level_up() -> None:
    song = one_shot("deuntje_level_omhoog.ogg", 4.0)
    for step, pitch in enumerate(range(65, 89, 3)):          # the XP bar filling up
        song.psg_one.add(song.at(0, step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.75, decay=0.08))
        song.noise.add(song.at(0, step * 0.5), megadrive.psg_noise(0.03, 0.3, 32000.0, 0.01, step))
    for step, label in ((4, "Db maj"), (8, "Eb maj")):
        chord = Chord(label)
        song.brass.add(song.at(0, step), megadrive.fm_chord(style.BRASS_STAB, [note + 12 for note in chord.voicing],
                                                             song.sixteenths(3.5), 1.0))
        song.pcm.add(song.at(0, step), style.KICK, 0.8)
        song.bass.add(song.at(0, step), megadrive.fm_note(style.SYNTH_BASS, float(chord.bass_root), song.sixteenths(3.5)))
    tonic = Chord("F maj")
    style.lead(song, 0, "-:12 M -:4 -:8", [tonic, tonic])
    for pitch, step in zip(style.motif_notes(tonic, octave=1), (12, 14, 15, 16)):
        song.piano.add(song.at(0, step), megadrive.fm_note(style.BELL, float(pitch), song.sixteenths(4), 0.9))
    song.pcm.add(song.at(0, 12), style.SNARE, 0.7)
    style.big_hit(song, 1, 4, tonic, 12)
    song.lead.add(song.at(1, 4), megadrive.fm_note(style.LEAD, float(tonic.melody_root + 12), song.sixteenths(11), 0.9))
    for step, pitch in enumerate([89, 93, 96, 101, 96, 101, 105, 108]):
        song.psg_two.add(song.at(1, 4 + step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.5, decay=0.06))
        song.piano.add(song.at(1, 4 + step), megadrive.fm_note(style.BELL, float(pitch - 12), song.sixteenths(2), 0.5))
    song.render(target_rms_db=-14.0, fade_out=0.8)


def new_mission() -> None:
    song = one_shot("deuntje_nieuwe_missie.ogg", 2.2)
    tonic = Chord("F maj")
    for pitch, step in zip(style.motif_notes(tonic, octave=1), (0, 1, 2, 3)):
        song.piano.add(song.at(0, step), megadrive.fm_note(style.BELL, float(pitch), song.sixteenths(3), 0.9))
        song.psg_two.add(song.at(0, step), megadrive.psg_square(pitch + 12, song.sixteenths(0.8), 0.4, decay=0.06))
    for step, label in ((4, "Db maj"), (6, "Eb maj")):
        chord = Chord(label)
        song.brass.add(song.at(0, step), megadrive.fm_chord(style.BRASS_STAB, [note + 12 for note in chord.voicing],
                                                             song.sixteenths(1.6), 0.9))
        song.pcm.add(song.at(0, step), style.KICK, 0.7)
        song.bass.add(song.at(0, step), megadrive.fm_note(style.SYNTH_BASS, float(chord.bass_root), song.sixteenths(1.6)))
    style.big_hit(song, 0, 8, tonic, 8)
    song.lead.add(song.at(0, 8), megadrive.fm_note(style.LEAD, float(tonic.melody_root + 12), song.sixteenths(6), 0.8))
    for step, pitch in enumerate([84, 89, 93, 96]):
        song.psg_one.add(song.at(0, 8 + step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.45, decay=0.05))
    song.render(target_rms_db=-14.0, fade_out=0.6)


def lost() -> None:
    song = one_shot("deuntje_verloren.ogg", 4.0)
    sinking = style.chords(["F m", "Gb maj", "Bb m", "C 7", "F m"])
    # the motif begins (F Ab G) ... then hesitates and sinks instead of landing
    melody = [(0, 2, 77), (2, 1, 80), (3, 1, 79), (4, 2, 77), (6, 2, 75), (8, 4, 73), (12, 6, 72), (18, 10, 65)]
    for step, steps_long, pitch in melody:
        song.lead.add(song.at(0, step), megadrive.fm_note(style.LEAD, float(pitch), song.sixteenths(steps_long * 0.92), 0.85))
        song.psg_two.add(song.at(0, step + 3), megadrive.psg_square(pitch, song.sixteenths(steps_long * 0.8), 0.4,
                                                                     decay=0.2, sustain=0.4))
    for chord, step, steps_long in zip(sinking, (0, 4, 8, 12, 18), (4, 4, 4, 6, 12)):
        song.strings.add(song.at(0, step), megadrive.fm_chord(style.STRINGS, [note + 12 for note in chord.voicing],
                                                              song.sixteenths(steps_long * 0.95), 0.9))
        song.piano.add(song.at(0, step), megadrive.fm_chord(style.ELECTRIC_PIANO, chord.voicing,
                                                            song.sixteenths(steps_long * 0.9), 0.8))
        song.bass.add(song.at(0, step), megadrive.fm_note(style.SLAP_BASS, float(chord.bass_root - (12 if step == 18 else 0)),
                                                          song.sixteenths(steps_long * 0.9), 0.8))
    for step in (0, 12, 18):
        song.pcm.add(song.at(0, step), style.KICK, 0.55)
    for step, pitch in enumerate([77, 72, 68, 65, 60, 56]):
        song.psg_one.add(song.at(1, 2 + step), megadrive.psg_square(pitch, song.sixteenths(0.8), 0.5, decay=0.1))
    song.render(target_rms_db=-15.0, fade_out=1.0)


def death() -> None:
    song = one_shot("deuntje_dood.ogg", 4.0)
    dark = Chord("F m")
    song.pcm.add(song.at(0, 0), style.KICK)
    song.pcm.add(song.at(0, 0), style.SNARE, 0.9)
    song.pcm.add(song.at(0, 0), style.TOMS[2], 0.9)
    style.crash(song, 0)
    song.bass.add(song.at(0, 0), megadrive.fm_note(style.SYNTH_BASS, float(dark.bass_root - 12), song.sixteenths(26), 1.0))
    song.brass.add(song.at(0, 0), megadrive.fm_chord(style.BRASS_STAB, [53, 60, 65, 68], song.sixteenths(4), 1.0))
    song.psg_one.add(song.at(0, 0), megadrive.psg_sweep(88, 41, 0.7, 0.9))
    song.noise.add(song.at(0, 0), megadrive.psg_noise(1.0, 0.8, 6000.0, 0.4, 7))
    # the motif slowed down, an octave lower: F4 Ab4 G4 C4
    for pitch, step, steps_long in zip(style.motif_notes(dark, octave=-1), (4, 8, 10, 12), (4, 2, 2, 14)):
        song.lead.add(song.at(0, step), megadrive.fm_note(style.LEAD, float(pitch), song.sixteenths(steps_long * 0.9), 0.8))
    song.strings.add(song.at(0, 4), megadrive.fm_chord(style.STRINGS, [53, 56, 60, 61], song.sixteenths(24), 0.9))
    song.piano.add(song.at(0, 12), megadrive.fm_chord(style.ELECTRIC_PIANO, [48, 53, 56], song.sixteenths(12), 0.6))
    song.render(target_rms_db=-15.0, fade_out=1.2)


STINGERS = {"kaart_start": map_start, "gewonnen": won, "level_omhoog": level_up, "verloren": lost, "nieuwe_missie": new_mission, "dood": death}


def main() -> None:
    names = sys.argv[1:] or list(STINGERS)
    for stinger_number, name in enumerate(names, 1):
        print(f"[ {stinger_number}/{len(names)} ] {name}", flush=True)
        STINGERS[name]()


if __name__ == "__main__":
    main()
