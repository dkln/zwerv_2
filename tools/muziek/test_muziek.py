"""Unit tests of the music tools (docs/MUZIEK.md): the notation, the BIJSTELLING (score.tune),
the drum kits and sounds, the derived pieces of every composition (the map jingle short
enough, every piece there) and the VGM reader (vgm.py, on a small VGM made here). Every
function test_* is a test; plain asserts.
Run: tools/muziek/render.sh --test
"""
import contextlib
import glob
import gzip
import io
import math
import os
import struct
import sys
import tempfile
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import derive  # noqa: E402
import instruments  # noqa: E402
import notation  # noqa: E402
import score as score_module  # noqa: E402
import vgm  # noqa: E402
from notation import Hit, Note, cycle, drum_run, drums, notes, run  # noqa: E402
from score import Bar, Score  # noqa: E402

COMPOSITIONS = sorted(os.path.basename(path)[:-3] for path in glob.glob(os.path.join(HERE, "composities", "*.py"))
                      if not path.endswith("actief.py"))


# ----------------------------------------------------------------------------- notation

def test_pitches():
    assert notation.pitch("C4") == 60
    assert notation.pitch("A4") == 69
    assert notation.pitch("Bb1") == 34
    assert notation.pitch("F#3") == 54
    assert notation.pitches("E2+B2+E3") == (40, 47, 52)


def test_notes_with_position_length_and_velocity():
    line = notes("1.0 D5 1.5, 2.5 F5 0.5 0.6")
    assert [note.position for note in line] == [1.0, 2.5]
    assert [note.length for note in line] == [1.5, 0.5]
    assert line[1].velocity == 0.6 and line[0].velocity == 1.0


def test_cycle_and_run_fill_their_beats():
    sixteenths = cycle("E2 E2 E3 E2", 0.25)
    assert len(sixteenths) == 16 and sixteenths[-1].position == 4.75
    half = cycle("C2 C3", 0.25, 1, 3)
    assert len(half) == 8 and max(note.position for note in half) < 3.0
    once = run("A4 B4 C5 D5", 0.5, start=2)
    assert [note.position for note in once] == [2.0, 2.5, 3.0, 3.5]
    assert run("E5 - G5", 0.25)[1].position == 1.5   # "-" is a rest


def test_drum_patterns():
    pattern = drums(hihat="16-off", open="off", snare="2 4")
    hihats = [hit.position for hit in pattern if hit.drum == "hihat"]
    assert len(hihats) == 12 and 1.5 not in hihats            # the "and" left for the open hi-hat
    assert [hit.position for hit in pattern if hit.drum == "open"] == [1.5, 2.5, 3.5, 4.5]
    fill = drum_run("HT - MT LT", 0.25, start=4)
    assert [(hit.position, hit.drum) for hit in fill] == [(4.0, "tom_hoog"), (4.5, "tom_mid"), (4.75, "tom_laag")]


def test_chords():
    assert notation.chord_classes("Em")[:3] == (4, 7, 11)
    assert notation.chord_classes("E5") == (4, 11)
    assert notation.bar_chords("C5 D5", 4) == [("C5", 1.0, 2.0), ("D5", 3.0, 2.0)]
    assert len(notation.bar_chords("F5 F#5 G5 B5", 4)) == 4


# ----------------------------------------------------------------------------- BIJSTELLING

def _score(bars, sounds=None):
    return Score("proef", 140.0, 4, ("E", "mineur"), dict(sounds or {"lead": "fm_lead_helder", "bas": "fm_slapbas"}),
                 bars, [{"naam": "Thema", "soort": "thema", "maten": (1, len(bars))}])


def _groove_bar(number, kicks="1 1.5 2.5 3", snares="2 4"):
    return Bar(number, [("Em", 1.0, 4.0)], {"lead": notes("1 E5 1, 2 G5 1"), "bas": notes("1 E2 4")},
               drums(kick=kicks, snare=snares, hihat="8"), "Thema", "thema")


def test_another_sound_for_a_part():
    score = _score([_groove_bar(1), _groove_bar(2)])
    score_module.tune(score, {"klank": {"lead": "fm_housebas_lead"}})
    assert score.sounds["lead"] == "fm_housebas_lead"
    assert score.bars[0].parts["lead"] == notes("1 E5 1, 2 G5 1")   # the same notes


def test_a_part_doubled_in_a_second_sound():
    score = _score([_groove_bar(1), _groove_bar(2)])
    score_module.tune(score, {"verdubbel": {"lead": "overdrive_gitaar_solo"}})
    assert score.sounds["lead_dubbel"] == "overdrive_gitaar_solo"
    assert all(bar.parts["lead_dubbel"] == bar.parts["lead"] for bar in score.bars)


def test_another_drum_kit():
    score = _score([_groove_bar(1), _groove_bar(2)])
    score_module.tune(score, {"drumstel": "dmx"})
    assert score.sounds["drumstel"] == "dmx"
    assert "dmx" in instruments.DRUM_KITS


def test_four_on_the_floor_leaves_breaks_and_fills_alone():
    groove = _groove_bar(1)
    unison = _groove_bar(2, kicks="1 1.75 2.5 3", snares="1 1.75 2.5 3")   # a break: kick and snare together
    fill = _groove_bar(3)
    fill.hits += drum_run("HT MT LT LT", 0.25, start=4)
    last = _groove_bar(4)
    score = _score([groove, unison, fill, last])
    score_module.tune(score, {"kick_op_elke_tel": ("thema",)})
    kicks = lambda bar: sorted(hit.position for hit in bar.hits if hit.drum == "kick")
    assert kicks(score.bars[0]) == [1.0, 2.0, 3.0, 4.0]
    assert kicks(score.bars[1]) == [1.0, 1.75, 2.5, 3.0], "the unison break stays as written"
    assert kicks(score.bars[2]) == [1.0, 2.0, 3.0], "no kick in the fill"
    assert kicks(score.bars[3]) == [1.0, 1.5, 2.5, 3.0], "the last bar (the ending) stays"


# ----------------------------------------------------------------------------- the compositions

def test_every_composition_has_its_sounds():
    for name in COMPOSITIONS:
        score = score_module.load(name)
        for part, sound in score.sounds.items():
            if part == "drumstel":
                assert sound in instruments.DRUM_KITS, (name, sound)
            else:
                assert sound in instruments.SOUNDS, (name, part, sound)


def test_every_composition_makes_every_piece():
    wanted = {"zwervr_intro", "nachtstad_menu_loop", "karakterkeuze_loop", "handelaar_loop", "laden_loop", "spel_loop",
              "deuntje_kaart_start", "deuntje_nieuwe_missie", "deuntje_taak_klaar", "deuntje_gewonnen",
              "deuntje_level_omhoog", "deuntje_beloning", "deuntje_dood", "supermarkt_muzak_1", "supermarkt_muzak_2",
              "supermarkt_muzak_3", "jingle_derrek", "jingle_alfred_steyhn"}
    for name in COMPOSITIONS:
        made = {piece.name for piece in derive.pieces(score_module.load(name))}
        assert wanted <= made, (name, wanted - made)


def test_the_map_jingle_is_short_enough():
    for name in COMPOSITIONS:
        score = score_module.load(name)
        for tempo in (score.tempo, 90.0, 180.0):
            score.tempo = tempo
            jingle = derive.map_start(score)
            assert jingle.seconds <= derive.MAP_JINGLE_LONGEST + 1e-6, (name, tempo, jingle.seconds)
            assert not jingle.loop


def test_the_supermarket_muzak_loops_and_the_chain_jingles_are_short():
    for name in COMPOSITIONS:
        score = score_module.load(name)
        made = {piece.name: piece for piece in derive.pieces(score)}
        for number in (1, 2, 3):
            muzak = made[f"supermarkt_muzak_{number}"]
            assert muzak.loop and 40.0 <= muzak.seconds <= 150.0, (name, muzak.name, muzak.seconds)
            for bar in muzak.bars:
                assert len(bar.chords) <= 2, (name, muzak.name, bar.number)
        for chain in ("derrek", "alfred_steyhn"):
            jingle = made["jingle_" + chain]
            assert not jingle.loop and jingle.seconds <= 6.0, (name, jingle.name, jingle.seconds)


def test_muzak_sweetens_power_chords():
    score = _score([_groove_bar(1)])
    assert derive.sweetened("E5", score) == "Em7"
    assert derive.sweetened("C5", score) == "Cmaj7"
    assert derive.sweetened("B7", score) == "B7"


def test_the_notes_of_a_bar_stay_inside_it():
    for name in COMPOSITIONS:
        score = score_module.load(name)
        for bar in score.bars:
            for part, part_notes in bar.parts.items():
                for note in part_notes:
                    assert 1.0 <= note.position < score.beats_per_bar + 1.0, (name, bar.number, part, note.position)
            for hit in bar.hits:
                assert 1.0 <= hit.position < score.beats_per_bar + 1.0, (name, bar.number, hit.drum, hit.position)


# ----------------------------------------------------------------------------- the VGM reader

VGM_FM_CLOCK = 7670453
VGM_PSG_CLOCK = 3579545
## One sixteenth at 120 BPM in VGM samples (44100 a second).
VGM_STEP = 5512


def _vgm_file(events: list, total_samples: int) -> bytes:
    """A VGM (version 1.50, YM2612 and SN76489) of (sample time, command bytes) events."""
    stream = bytearray()
    now = 0
    for time, commands in sorted(events, key=lambda event: event[0]):
        while time > now:
            wait = min(65535, time - now)
            stream += bytes([0x61]) + struct.pack("<H", wait)
            now += wait
        stream += commands
    while total_samples > now:
        wait = min(65535, total_samples - now)
        stream += bytes([0x61]) + struct.pack("<H", wait)
        now += wait
    stream.append(0x66)
    header = bytearray(0x40)
    header[0:4] = b"Vgm "
    struct.pack_into("<I", header, 0x04, 0x40 + len(stream) - 4)
    struct.pack_into("<I", header, 0x08, 0x150)
    struct.pack_into("<I", header, 0x0C, VGM_PSG_CLOCK)
    struct.pack_into("<I", header, 0x18, total_samples)
    struct.pack_into("<I", header, 0x2C, VGM_FM_CLOCK)
    struct.pack_into("<I", header, 0x34, 0x0C)
    return bytes(header) + bytes(stream)


def _fm_patch(channel: int, algorithm: int, feedback: int) -> bytes:
    """Port 0 writes: the patch of FM channel 0-2 (all operators alike, the last one loudest)."""
    commands = bytes([0x52, 0xB0 + channel, (feedback << 3) | algorithm])
    for slot in range(4):
        register = slot * 4 + channel
        commands += bytes([0x52, 0x30 + register, 0x01, 0x52, 0x40 + register, 0x00 if slot == 3 else 0x18,
                           0x52, 0x50 + register, 0x1F, 0x52, 0x80 + register, 0x2A])
    return commands


def _fm_key_on(channel: int, midi_pitch: int, f_number: int = None) -> bytes:
    """Key off, the frequency (F-number and block) of the pitch, key on: as a sound driver does."""
    block = max(0, min(7, midi_pitch // 12 - 1))
    hertz = 440.0 * 2 ** ((midi_pitch - 69) / 12.0)
    if f_number is None:
        f_number = int(round(hertz * 144.0 * 2 ** (21 - block) / VGM_FM_CLOCK))
    return bytes([0x52, 0x28, channel, 0x52, 0xA4 + channel, (block << 3) | (f_number >> 8),
                  0x52, 0xA0 + channel, f_number & 0xFF, 0x52, 0x28, 0xF0 | channel])


def _fm_key_off(channel: int) -> bytes:
    return bytes([0x52, 0x28, channel])


def _psg_tone(channel: int, midi_pitch: int, attenuation: int) -> bytes:
    period = int(round(VGM_PSG_CLOCK / (32.0 * 440.0 * 2 ** ((midi_pitch - 69) / 12.0))))
    return bytes([0x50, 0x80 | (channel << 5) | (period & 0x0F), 0x50, period >> 4,
                  0x50, 0x90 | (channel << 5) | attenuation])


def _psg_noise(attenuation: int) -> bytes:
    """White noise struck again (the control register) at this attenuation (15: silent)."""
    return bytes([0x50, 0xE4, 0x50, 0xF0 | attenuation])


def _proef_events() -> list:
    """Eight bars at 120 BPM: a bass in eighths on FM channel 1 (E2, the last of every bar a D3
    held a quarter), from bar 5 a melody in quarters on FM channel 2, a loud noise hit on
    beats 2 and 4 and a soft one on the "and" of every beat."""
    events = [(0, _fm_patch(0, 0, 6) + _fm_patch(1, 4, 2))]
    melody = [64, 67, 71, 76, 74, 71, 69, 67, 66, 69, 73, 78, 76, 73, 71, 69]
    for bar in range(8):
        for step in range(16):
            time = (bar * 16 + step) * VGM_STEP
            if step % 2 == 0 and step < 14:
                events.append((time, _fm_key_on(0, 50 if step == 12 else 40)))
                if step < 12:
                    events.append((time + VGM_STEP, _fm_key_off(0)))
            if bar >= 4 and step % 4 == 0:
                events.append((time, _fm_key_on(1, melody[((bar - 4) * 4 + step // 4) % len(melody)])))
            if step in (4, 12):
                events.append((time, _psg_noise(1)))
            elif step % 4 == 2:
                events.append((time, _psg_noise(6)))
            else:
                events.append((time, _psg_noise(15)))
    return events


def _proef_song(folder: str, file_name: str = "proef_120.vgm", zipped: bool = False):
    data = _vgm_file(_proef_events(), 8 * 16 * VGM_STEP)
    path = os.path.join(folder, file_name)
    with open(path, "wb") as vgm_file:
        vgm_file.write(gzip.compress(data) if zipped else data)
    return vgm.read(path)


def test_vgm_fm_notes_have_pitch_start_and_length():
    with tempfile.TemporaryDirectory() as folder:
        song = _proef_song(folder)
    assert song.chips == [f"YM2612 ({VGM_FM_CLOCK} Hz)", f"SN76489 ({VGM_PSG_CLOCK} Hz)"]
    bass = [note for note in song.notes if note.channel == "fm1"]
    assert len(bass) == 8 * 7 and song.key_ons["fm1"] == 56
    assert [round(note.pitch) for note in bass[:7]] == [40] * 6 + [50]
    assert all(abs(note.pitch - round(note.pitch)) < 0.05 for note in bass), "within 5 cents of the note"
    assert [note.start for note in bass[:3]] == [0, 2 * VGM_STEP, 4 * VGM_STEP]
    assert bass[0].end - bass[0].start == VGM_STEP                 # key-off a step later
    assert bass[6].end - bass[6].start == 4 * VGM_STEP             # held to the next key-on
    melody = [note for note in song.notes if note.channel == "fm2"]
    assert [round(note.pitch) for note in melody[:4]] == [64, 67, 71, 76]
    assert melody[0].start == 4 * 16 * VGM_STEP
    assert song.voices["fm1"].algorithm == 0 and song.voices["fm1"].feedback == 6
    assert song.voices["fm2"].algorithm == 4 and song.voices["fm2"].carriers() == (1, 3)


def test_vgm_psg_tones_and_noise_drums():
    events = [(0, _psg_tone(0, 69, 2)), (VGM_STEP, _psg_tone(0, 72, 2)), (2 * VGM_STEP, _psg_tone(0, 72, 15)),
              (0, _psg_noise(0)), (VGM_STEP, _psg_noise(8)), (2 * VGM_STEP, _psg_noise(15)),
              # periodic noise, and white noise left ringing: a low tom and a crash
              (4 * VGM_STEP, bytes([0x50, 0xE0, 0x50, 0xF2])), (5 * VGM_STEP, bytes([0x50, 0xE4, 0x50, 0xF2]))]
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "psg.vgm")
        with open(path, "wb") as vgm_file:
            vgm_file.write(_vgm_file(events, 16 * VGM_STEP))
        song = vgm.read(path)
    tones = [(note.channel, round(note.pitch), note.start, note.end) for note in song.notes]
    assert tones == [("psg1", 69, 0, VGM_STEP), ("psg1", 72, VGM_STEP, 2 * VGM_STEP)], tones
    assert [(hit.drum, hit.start) for hit in song.hits] == [
        ("snare", 0), ("hihat", VGM_STEP), ("tom_laag", 4 * VGM_STEP), ("crash", 5 * VGM_STEP)], song.hits


def _dac_burst(start: int, samples: list) -> list:
    """A sample through the DAC at 8820 Hz (a write every 5 VGM samples)."""
    return [(start + index * 5, bytes([0x52, 0x2A, value])) for index, value in enumerate(samples)]


def test_vgm_dac_samples_are_drums():
    thump = [int(128 + 100 * math.sin(2 * math.pi * 70.0 * index / 8820.0)) for index in range(900)]
    tone = [int(128 + 100 * math.sin(2 * math.pi * 260.0 * index / 8820.0)) for index in range(900)]
    hiss = [(index * 7919 + (index * index * 31) % 251) % 256 for index in range(900)]
    events = [(0, bytes([0x52, 0x2B, 0x80]))]
    events += _dac_burst(0, thump) + _dac_burst(2 * VGM_STEP, hiss) + _dac_burst(4 * VGM_STEP, tone)
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "dac.vgm")
        with open(path, "wb") as vgm_file:
            vgm_file.write(_vgm_file(events, 8 * VGM_STEP))
        song = vgm.read(path)
    assert [(hit.source, hit.drum, hit.start) for hit in song.hits] == [
        ("dac", "kick", 0), ("dac", "snare", 2 * VGM_STEP), ("dac", "tom_mid", 4 * VGM_STEP)], song.hits


def test_vgm_tempo_from_the_notes_checked_against_the_file_name():
    with tempfile.TemporaryDirectory() as folder:
        named_right = vgm.find_timing(_proef_song(folder, "proef_120.vgm"))
        named_wrong = vgm.find_timing(_proef_song(folder, "proef_92.vgm"))
        unnamed = vgm.find_timing(_proef_song(folder, "proef.vgm"))
    for timing in (named_right, named_wrong, unnamed):
        assert timing.tempo == 120.0 and timing.steps_per_beat == 4 and timing.beats_per_bar == 4, timing
        assert timing.fit < 0.01
    assert named_right.name_tempo == 120.0 and named_right.name_tempo_fits
    assert named_wrong.name_tempo == 92.0 and not named_wrong.name_tempo_fits
    assert unnamed.name_tempo is None


def test_vgm_gzipped_reads_the_same():
    with tempfile.TemporaryDirectory() as folder:
        plain = _proef_song(folder, "proef.vgm")
        zipped = _proef_song(folder, "proef.vgz", zipped=True)
    assert [(note.channel, note.start, note.end, note.pitch) for note in plain.notes] == [
        (note.channel, note.start, note.end, note.pitch) for note in zipped.notes]
    assert len(zipped.hits) == len(plain.hits) > 0


def test_vgm_clipped_f_numbers_are_reported():
    events = [(0, _fm_patch(0, 4, 3)), (0, _fm_key_on(0, 45, f_number=2047)), (VGM_STEP, _fm_key_on(0, 52)),
              (2 * VGM_STEP, _fm_key_off(0))]
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "afgekapt.vgm")
        with open(path, "wb") as vgm_file:
            vgm_file.write(_vgm_file(events, 4 * VGM_STEP))
        song = vgm.read(path)
    assert [note.saturated for note in song.notes] == [True, False]
    assert any("F-number" in warning for warning in song.warnings)


def test_vgm_parts_key_chords_and_sections():
    with tempfile.TemporaryDirectory() as folder:
        song = _proef_song(folder)
    arrangement = vgm.arrange(song, vgm.find_timing(song))
    assert arrangement.part_channels == {"bas": ["fm1"], "lead": ["fm2"]}
    assert arrangement.sounds == {"bas": "fm_housebas", "lead": "fm_lead_helder"}
    assert all(sound in instruments.SOUNDS for sound in arrangement.sounds.values())
    assert arrangement.bar_count == 8
    assert arrangement.key[0] in ("E", "A", "D") and arrangement.key[1] in ("majeur", "mineur"), arrangement.key
    assert all(vgm._root(arrangement.chords[bar].split()[0]) == "E" for bar in range(1, 5)), arrangement.chords
    assert [(section["soort"], section["maten"]) for section in arrangement.sections] == [
        ("intro", (1, 4)), ("thema", (5, 8))]
    assert _drum_counts(arrangement) == {"snare": 16, "hihat": 32}
    # the melody is written in the octave of the VGM and stays where it is (E4..F#5 is high enough);
    # a melody as low as the bass would be raised by the BIJSTELLING
    assert arrangement.octaves.get("lead", 0) in (0, 1)


def _drum_counts(arrangement) -> dict:
    counts = {}
    for hit in arrangement.hits:
        counts[hit.drum] = counts.get(hit.drum, 0) + 1
    return counts


def test_vgm_becomes_a_composition_every_piece_is_made_from():
    name = "vgm_proef_compositie"
    with tempfile.TemporaryDirectory() as folder:
        song = _proef_song(folder)
        arrangement = vgm.arrange(song, vgm.find_timing(song))
        with open(os.path.join(folder, name + ".py"), "w") as composition_file:
            composition_file.write(vgm.composition_source(arrangement, name, "Proef"))
        sys.path.insert(0, folder)
        try:
            score = score_module.load(name)
            with contextlib.redirect_stdout(io.StringIO()):
                problems = vgm.compare(arrangement, name)
        finally:
            sys.path.remove(folder)
            sys.modules.pop(name, None)
    assert problems == [], problems
    assert score.title == "Proef" and score.tempo == 120.0 and len(score.bars) == 8
    assert score.bars[0].parts["bas"][0] == Note(1.0, (40,), 0.25)
    assert score.bars[0].parts["bas"][6] == Note(4.0, (50,), 1.0)
    assert sorted(hit.position for hit in score.bars[0].hits if hit.drum == "snare") == [2.0, 4.0]
    pieces = {piece.name: piece for piece in derive.pieces(score)}
    assert abs(pieces["zwervr_intro"].bars_seconds - song.seconds) < 0.05, "the intro as long as the VGM"
    assert len(pieces) == len(derive.ALL)


def test_every_vgm_composition_still_matches_its_vgm():
    for name in COMPOSITIONS:
        for extension in (".vgm", ".vgz"):
            path = os.path.join(HERE, "composities", name + extension)
            if not os.path.exists(path):
                continue
            song = vgm.read(path)
            arrangement = vgm.arrange(song, vgm.find_timing(song, score_module.load(name).tempo))
            with contextlib.redirect_stdout(io.StringIO()):
                problems = vgm.compare(arrangement, name)
            assert problems == [], (name, problems)


def test_a_composition_without_an_ending_lands_its_win_jingle():
    held_end = _score([_groove_bar(1), Bar(2, [("Em", 1.0, 4.0)], {"lead": notes("1 E6 3.5")}, drums(crash="1"),
                                           "Thema", "thema")])
    assert derive.has_ending(held_end)
    assert len(derive.mission_done(held_end).bars) == 2 and derive.mission_done(held_end).last_bar_beats is None
    running = _score([_groove_bar(1), Bar(2, [("Em", 1.0, 4.0)], {"lead": run("E5 F5 F#5 G5", 0.25, start=4)},
                                          drums(hihat="8"), "Thema", "thema")])
    assert not derive.has_ending(running)
    jingle = derive.mission_done(running)
    assert jingle.bars[0].parts["lead"] == running.bars[-1].parts["lead"]
    assert jingle.bars[-1].parts["lead"][0].pitches[0] % 12 == running.tonic(), "lands on the tonic"
    assert any(hit.drum == "crash" for hit in jingle.bars[-1].hits) and jingle.last_bar_beats == 2.0


def main() -> int:
    tests = [(name, function) for name, function in sorted(globals().items()) if name.startswith("test_")]
    failed = 0
    for name, function in tests:
        try:
            function()
            print(f"ok    {name}")
        except Exception:   # noqa: BLE001 (any failure is a failed test)
            failed += 1
            print(f"FOUT  {name}")
            traceback.print_exc()
    print(f"muziektests: {len(tests) - failed} geslaagd, {failed} mislukt")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
