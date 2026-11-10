"""The short stingers (one-shots, no loop), in the house style (style.py, the active profile),
each one built on the motif of the profile; in synthwave_rpg at 120 BPM in D:

    deuntje_kaart_start.ogg   (6 s) start of the map: the motif as a fanfare on VI and VII
                              (Bb, C) with brass and power chords, landing on a big D major
    deuntje_gewonnen.ogg      (4 s) won: the motif fast and leaping up, a D major hit, a short
                              groove with the motif in major, the twin guitars, a final hit
    deuntje_level_omhoog.ogg  (4 s) level up: a PSG run up like a filling XP bar, Bb - C, the
                              motif in D major with bells, sparkle and crash
    deuntje_verloren.ogg      (4 s) lost: the motif begins, then sinks step by step over
                              i VI iv V down to a low D
    deuntje_nieuwe_missie.ogg (2.2 s) a new mission: the motif quick on bells, a brass stab on
                              Bb, then C, up to an open D with a little sparkle (a "go!")
    deuntje_taak_klaar.ogg    (2.8 s) a step of a mission done: a gated snare roll, a fanfare on
                              brass and lead up through D, G and A, a big D major with a crash,
                              bells and PSG sparkle (a whole mission is deuntje_gewonnen)
    deuntje_dood.ogg          (4 s) death: a heavy low hit, a PSG pitch dive, the motif slowed
                              down an octave lower over a dark chord, the tape stopping

Every stinger stops at its length with a short fade (`render(fade_out=...)`).
Render: tools/megadrive/render.sh deuntjes  (or a single one: render.sh deuntjes kaart_start)
"""
import sys

import megadrive
import style
from style import Song

BPM = style.tempo("deuntjes")
TONIC_MAJOR = style.chord("I")
TONIC_MINOR = style.chord("i")
FLAT_SIX = style.chord("VI")
FLAT_SEVEN = style.chord("VII")


def one_shot(file_name: str, seconds: float) -> Song:
    bar_seconds = 60.0 / BPM * 4
    return Song(file_name, bpm=BPM, bars=int(seconds // bar_seconds) + 1, loop=False, seconds=seconds)


def four_on_the_floor(song: Song, bar: int, first_step: int, last_step: int, on_chord) -> None:
    for step in range(first_step, last_step):
        if step % 4 == 0:
            song.pcm.add(song.at(bar, step), style.KICK, 0.85)
        if step % 8 == 4:
            song.pcm.add(song.at(bar, step), style.SNARE, 0.7)
        if step % 2 == 0:
            song.noise.add(song.at(bar, step), megadrive.psg_noise(0.05, 0.6, 32000.0, 0.018, step))
        song.bass.add(song.at(bar, step), megadrive.fm_note(style.SOLID_BASS, float(on_chord.bass_note("O" if step % 4 == 2 else "R")),
                                                            song.sixteenths(0.8), 0.85))


def map_start() -> None:
    song = one_shot("deuntje_kaart_start.ogg", 6.0)
    fanfare = [FLAT_SIX, FLAT_SEVEN, TONIC_MAJOR]
    style.lead(song, 0, "M -:8 M -:8 R:16", fanfare)
    for bar, bar_chord in enumerate(fanfare[:2]):
        style.brass_stabs(song, bar, bar_chord, [(0, 2), (2, 1), (3, 1), (4, 4), (12, 2), (14, 2)], 1.0)
        style.power_chords(song, bar, bar_chord, "push", 0.8)
        style.bass_bar(song, bar, bar_chord, "solid")
        style.drum_bar(song, bar, clap=True, hats="sixteenths", ghosts=False, fill="snare" if bar == 1 else None)
        style.arpeggio(song, bar, bar_chord, "up", 0.6)
    style.big_hit(song, 2, 0, TONIC_MAJOR, 20)
    for step, pitch in enumerate(TONIC_MAJOR.arpeggio_notes() + TONIC_MAJOR.arpeggio_notes(1)):
        song.psg_one.add(song.at(2, step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.7, decay=0.05))
    song.render(target_rms_db=-14.0, fade_out=1.2)


def won() -> None:
    song = one_shot("deuntje_gewonnen.ogg", 4.0)
    for step, pitch in enumerate(style.motif_notes(TONIC_MAJOR)):          # the motif, leaping up
        song.lead.add(song.at(0, step), megadrive.fm_note(style.LEAD, float(pitch), song.sixteenths(0.8), 1.0))
        song.psg_two.add(song.at(0, step), megadrive.psg_square(pitch + 12, song.sixteenths(0.8), 0.6))
    style.big_hit(song, 0, 4, TONIC_MAJOR, 6)
    song.lead.add(song.at(0, 4), megadrive.fm_note(style.LEAD, float(TONIC_MAJOR.melody_root + 12), song.sixteenths(5), 1.0))
    four_on_the_floor(song, 0, 4, 16, TONIC_MAJOR)
    four_on_the_floor(song, 1, 0, 8, FLAT_SEVEN)
    style.guitar(song, 0, "-:12 M -:4 -:8", [TONIC_MAJOR, FLAT_SEVEN], twin=True)
    style.arpeggio(song, 1, FLAT_SEVEN, "up", 0.55, until_step=8)
    style.big_hit(song, 1, 8, TONIC_MAJOR, 10)
    song.lead.add(song.at(1, 8), megadrive.fm_note(style.LEAD, float(TONIC_MAJOR.melody_root + 12), song.sixteenths(9), 1.0))
    for step, pitch in enumerate(TONIC_MAJOR.arpeggio_notes(1)[:3] + TONIC_MAJOR.arpeggio_notes(2)[:3]):
        song.psg_one.add(song.at(1, 8 + step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.6))
    song.render(target_rms_db=-14.0, fade_out=0.8)


def level_up() -> None:
    song = one_shot("deuntje_level_omhoog.ogg", 4.0)
    start = TONIC_MAJOR.melody_root - 12
    for step, pitch in enumerate(range(start, start + 24, 3)):          # the XP bar filling up
        song.psg_one.add(song.at(0, step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.75, decay=0.08))
        song.noise.add(song.at(0, step * 0.5), megadrive.psg_noise(0.03, 0.3, 32000.0, 0.01, step))
    for step, bar_chord in ((4, FLAT_SIX), (8, FLAT_SEVEN)):
        song.brass.add(song.at(0, step), megadrive.fm_chord(style.BRASS_STAB, [note + 12 for note in bar_chord.dyad()],
                                                             song.sixteenths(3.5), 1.0))
        song.pcm.add(song.at(0, step), style.KICK, 0.8)
        song.bass.add(song.at(0, step), megadrive.fm_note(style.SOLID_BASS, float(bar_chord.bass_root), song.sixteenths(3.5)))
    style.lead(song, 0, "-:12 M -:4 -:8", [TONIC_MAJOR, TONIC_MAJOR])
    style.bells(song, 0, style.motif_notes(TONIC_MAJOR, octave=1), (12, 14, 15, 16), 0.9)
    song.pcm.add(song.at(0, 12), style.SNARE, 0.7)
    style.big_hit(song, 1, 4, TONIC_MAJOR, 12)
    song.lead.add(song.at(1, 4), megadrive.fm_note(style.LEAD, float(TONIC_MAJOR.melody_root + 12), song.sixteenths(11), 0.9))
    sparkle = TONIC_MAJOR.arpeggio_notes(1) + TONIC_MAJOR.arpeggio_notes(2)
    for step, pitch in enumerate(sparkle):
        song.psg_two.add(song.at(1, 4 + step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.5, decay=0.06))
        song.pad.add(song.at(1, 4 + step), megadrive.fm_note(style.BELL, float(pitch - 12), song.sixteenths(2), 0.5))
    song.render(target_rms_db=-14.0, fade_out=0.8)


def new_mission() -> None:
    song = one_shot("deuntje_nieuwe_missie.ogg", 2.2)
    style.bells(song, 0, style.motif_notes(TONIC_MAJOR, octave=1), (0, 1, 2, 3), 0.9)
    for pitch, step in zip(style.motif_notes(TONIC_MAJOR, octave=1), (0, 1, 2, 3)):
        song.psg_two.add(song.at(0, step), megadrive.psg_square(pitch + 12, song.sixteenths(0.8), 0.4, decay=0.06))
    for step, bar_chord in ((4, FLAT_SIX), (6, FLAT_SEVEN)):
        song.brass.add(song.at(0, step), megadrive.fm_chord(style.BRASS_STAB, [note + 12 for note in bar_chord.dyad()],
                                                             song.sixteenths(1.6), 0.9))
        song.guitar.add(song.at(0, step), megadrive.fm_note(style.POWER_CHORD, float(bar_chord.power_root), song.sixteenths(1.6), 0.7))
        song.pcm.add(song.at(0, step), style.KICK, 0.7)
        song.bass.add(song.at(0, step), megadrive.fm_note(style.SOLID_BASS, float(bar_chord.bass_root), song.sixteenths(1.6)))
    style.big_hit(song, 0, 8, TONIC_MAJOR, 8)
    song.lead.add(song.at(0, 8), megadrive.fm_note(style.LEAD, float(TONIC_MAJOR.melody_root + 12), song.sixteenths(6), 0.8))
    for step, pitch in enumerate(TONIC_MAJOR.arpeggio_notes(1)):
        song.psg_one.add(song.at(0, 8 + step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.45, decay=0.05))
    song.render(target_rms_db=-14.0, fade_out=0.6)


def task_done() -> None:
    song = one_shot("deuntje_taak_klaar.ogg", 2.8)
    for step in range(8):          # a snare roll swelling up to the one
        song.pcm.add(song.at(0, step * 0.5), style.PLAIN_SNARE, 0.25 + 0.08 * step)
    # the fanfare: up through I, IV and V on brass and lead, the PSG an octave up
    for step, bar_chord in ((4, TONIC_MAJOR), (6, style.chord("IV")), (8, style.chord("V"))):
        song.brass.add(song.at(0, step), megadrive.fm_chord(style.BRASS_STAB, [note + 12 for note in bar_chord.dyad()],
                                                             song.sixteenths(1.7), 1.0))
        song.lead.add(song.at(0, step), megadrive.fm_note(style.LEAD, float(bar_chord.melody_root + 12), song.sixteenths(1.7), 1.0))
        song.psg_two.add(song.at(0, step), megadrive.psg_square(bar_chord.melody_root + 24, song.sixteenths(1.2), 0.45, decay=0.06))
        song.pcm.add(song.at(0, step), style.KICK, 0.9)
        song.pcm.add(song.at(0, step), style.CLAP, 0.5)
        song.bass.add(song.at(0, step), megadrive.fm_note(style.SOLID_BASS, float(bar_chord.bass_root), song.sixteenths(1.7)))
    style.big_hit(song, 0, 10, TONIC_MAJOR, 10)
    song.lead.add(song.at(0, 10), megadrive.fm_note(style.LEAD, float(TONIC_MAJOR.melody_root + 12), song.sixteenths(9), 1.0))
    style.bells(song, 0, [pitch + 12 for pitch in style.motif_notes(TONIC_MAJOR, octave=1)], (10, 11, 11.5, 12), 0.8)
    sparkle = TONIC_MAJOR.arpeggio_notes(1) + TONIC_MAJOR.arpeggio_notes(2)[:3] + TONIC_MAJOR.arpeggio_notes(1)[2:]
    for step, pitch in enumerate(sparkle):
        song.psg_one.add(song.at(0, 10 + step * 0.5), megadrive.psg_square(pitch, song.sixteenths(0.5), 0.45, decay=0.05))
    song.render(target_rms_db=-13.0, fade_out=0.6)


def lost() -> None:
    song = one_shot("deuntje_verloren.ogg", 4.0)
    sinking = [TONIC_MINOR, FLAT_SIX, style.chord("iv"), style.chord("V"), TONIC_MINOR]
    root = TONIC_MINOR.melody_root
    # the motif begins (root, fifth) ... then hesitates and sinks instead of leaping up
    melody = [(0, 2, root), (2, 1, root + 7), (3, 1, root + 5), (4, 2, root + 3), (6, 2, root + 2), (8, 4, root),
              (12, 6, root - 1), (18, 10, root - 12)]
    for step, steps_long, pitch in melody:
        song.lead.add(song.at(0, step), megadrive.fm_note(style.LEAD, float(pitch), song.sixteenths(steps_long * 0.92), 0.85))
        song.psg_two.add(song.at(0, step + 3), megadrive.psg_square(pitch, song.sixteenths(steps_long * 0.8), 0.4,
                                                                     decay=0.2, sustain=0.4))
    for bar_chord, step, steps_long in zip(sinking, (0, 4, 8, 12, 18), (4, 4, 4, 6, 12)):
        song.pad.add(song.at(0, step), megadrive.fm_chord(style.PAD, bar_chord.dyad(), song.sixteenths(steps_long * 0.95), 0.9))
        song.bass.add(song.at(0, step), megadrive.fm_note(style.SLAP_BASS, float(bar_chord.bass_root - (12 if step == 18 else 0)),
                                                          song.sixteenths(steps_long * 0.9), 0.8))
    for step in (0, 12, 18):
        song.pcm.add(song.at(0, step), style.KICK, 0.55)
    for step, pitch in enumerate([root + 12, root + 7, root + 3, root, root - 5, root - 9]):
        song.psg_one.add(song.at(1, 2 + step), megadrive.psg_square(pitch, song.sixteenths(0.8), 0.5, decay=0.1))
    song.render(target_rms_db=-15.0, fade_out=1.0)


def death() -> None:
    song = one_shot("deuntje_dood.ogg", 4.0)
    song.pcm.add(song.at(0, 0), style.FAT_KICK)
    song.pcm.add(song.at(0, 0), style.SNARE, 0.9)
    song.pcm.add(song.at(0, 0), style.TOMS[2], 0.9)
    style.crash(song, 0)
    song.bass.add(song.at(0, 0), megadrive.fm_note(style.SOLID_BASS, float(TONIC_MINOR.bass_root - 12), song.sixteenths(26), 1.0))
    song.guitar.add(song.at(0, 0), megadrive.fm_note(style.POWER_CHORD, float(TONIC_MINOR.power_root - 12), song.sixteenths(6), 1.0))
    song.psg_one.add(song.at(0, 0), megadrive.psg_sweep(TONIC_MINOR.melody_root + 12, TONIC_MINOR.melody_root - 36, 0.7, 0.9))
    song.noise.add(song.at(0, 0), megadrive.psg_noise(1.0, 0.8, 6000.0, 0.4, 7))
    # the motif slowed down, an octave lower
    for pitch, step, steps_long in zip(style.motif_notes(TONIC_MINOR, octave=-1), (4, 8, 10, 12), (4, 2, 2, 14)):
        song.lead.add(song.at(0, step), megadrive.fm_note(style.LEAD, float(pitch), song.sixteenths(steps_long * 0.9), 0.8))
    song.pad.add(song.at(0, 4), megadrive.fm_chord(style.PAD, [note - 12 for note in TONIC_MINOR.dyad()], song.sixteenths(24), 0.9))
    song.tape_stop(1, 4, 1.4)
    song.render(target_rms_db=-15.0, fade_out=1.0)


STINGERS = {"kaart_start": map_start, "gewonnen": won, "level_omhoog": level_up, "verloren": lost, "nieuwe_missie": new_mission,
            "taak_klaar": task_done, "dood": death}


def main() -> None:
    names = sys.argv[1:] or list(STINGERS)
    for stinger_number, name in enumerate(names, 1):
        print(f"[ {stinger_number}/{len(names)} ] {name}", flush=True)
        STINGERS[name]()


if __name__ == "__main__":
    main()
