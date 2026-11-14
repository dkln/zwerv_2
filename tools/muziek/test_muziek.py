"""Unit tests of the music tools (docs/MUZIEK.md): the notation, the BIJSTELLING (score.tune),
the drum kits and sounds, the derived pieces of every composition (the map jingle short
enough, every piece there), the chip imitation and the readers of the composer's JSON. Every
function test_* is a test; plain asserts.
Run: tools/muziek/render.sh --test
"""
import contextlib
import glob
import io
import math
import os
import json
import sys
import tempfile
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import numpy  # noqa: E402

import chip  # noqa: E402
import derive  # noqa: E402
import instruments  # noqa: E402
import notation  # noqa: E402
import score as score_module  # noqa: E402
import fm  # noqa: E402
import json_bron  # noqa: E402
import json_naar_ogg  # noqa: E402
import mixer  # noqa: E402
import tracker  # noqa: E402
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


# ----------------------------------------------------------------------------- the chips

FM_CLOCK = 7670453
PSG_CLOCK = 3579545


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


# ----------------------------------------------------------------------------- the chip imitation

def _sine_voice(release_rate: int = 15, **changes):
    """A patch that is one sine: algorithm 7 with only operator 4 sounding."""
    settings = dict(algorithm=7, feedback=0, multiples=(1, 1, 1, 1), total_levels=(127, 127, 127, 0),
                    attack_rates=(31, 31, 31, 31), decay_rates=(0, 0, 0, 0), sustain_levels=(0, 0, 0, 0),
                    detunes=(0, 0, 0, 0), rate_scalings=(0, 0, 0, 0), sustain_rates=(0, 0, 0, 0),
                    release_rates=(release_rate,) * 4)
    settings.update(changes)
    return fm.FmVoice(**settings)


def _period_hz(signal, wanted_hz: float) -> float:
    """The frequency a signal repeats with, near `wanted_hz` (zero crossings upward, interpolated)."""
    signs = numpy.signbit(signal)
    rising = numpy.nonzero(signs[:-1] & ~signs[1:])[0]
    exact = rising + signal[rising] / (signal[rising] - signal[rising + 1])
    assert len(exact) > 4, wanted_hz
    return chip.OUTPUT_RATE * (len(exact) - 1) / (exact[-1] - exact[0])


def test_chip_plays_the_frequency_of_f_number_and_block():
    clock = float(FM_CLOCK)
    for f_number, block in ((1083, 4), (2047, 1), (644, 3), (181, 5)):
        hertz = fm.fm_hz(f_number, block, clock)
        events = chip.voice_events(_sine_voice()) + [(0, "frequency", f_number, block), (0, "key", 0x0F)]
        mono, _left, _right = chip.fm_channel(events, 30000)
        played = chip.resample(mono, chip.native_rate(clock))
        found = _period_hz(played[2000:22000], hertz)
        assert abs(1200.0 * math.log2(found / hertz)) < 0.5, (f_number, block, hertz, found)
    # no rounding to a note: F-number 2047 in block 1 is 103.98 Hz, 2.5 cents above G#2
    assert abs(fm.fm_hz(2047, 1, clock) - 103.98) < 0.01


def test_chip_envelope_attack_decay_sustain_and_release():
    clock = float(FM_CLOCK)
    rate = chip.native_rate(clock)
    # decay rate 12 with the key scaling of this pitch (rate 26: 6/8 of a step every 32 envelope ticks
    # of 3 samples) falls 39 dB a second to the sustain level (2: 6 dB down), then holds (sustain rate 0)
    voice = _sine_voice(release_rate=10, decay_rates=(12,) * 4, sustain_levels=(2,) * 4)
    events = chip.voice_events(voice) + [(0, "frequency", 1083, 4), (0, "key", 0x0F), (int(1.0 * rate), "key", 0)]
    mono, _left, _right = chip.fm_channel(events, int(1.6 * rate))
    peak = lambda start, end: float(numpy.abs(mono[int(start * rate):int(end * rate)]).max())
    assert peak(0.0, 0.01) > 0.95, "the attack at rate 31 is at once"
    assert abs(20 * math.log10(peak(0.1, 0.11)) + 3.9) < 0.4, peak(0.1, 0.11)       # 39 dB/s for 0.1 s
    assert abs(20 * math.log10(peak(0.6, 0.9)) + 6.0) < 0.3, peak(0.6, 0.9)         # the sustain level
    assert peak(1.3, 1.6) == 0.0, "released: silent 0.3 s after the key-off"


def test_chip_feedback_and_modulation_change_the_sound_not_the_pitch():
    clock = float(FM_CLOCK)
    plain = chip.voice_note(_sine_voice(), clock, 220.0, 0.3)
    modulated_voice = _sine_voice(algorithm=0, feedback=3, total_levels=(22, 22, 22, 0))
    modulated = chip.voice_note(modulated_voice, clock, 220.0, 0.3)
    harmonics = lambda signal: float(numpy.abs(numpy.fft.rfft(signal[2000:12000]))[int(1500 * 10000 / 44100):].sum())
    assert harmonics(modulated) > 5 * harmonics(plain), "FM adds overtones"
    spectrum = numpy.abs(numpy.fft.rfft(modulated[2000:12000] * numpy.hanning(10000), 1 << 16)) ** 2
    spacing = 220.0 * (1 << 16) / 44100
    near_partials = sum(spectrum[int(round(spacing * partial)) - 20:int(round(spacing * partial)) + 21].sum()
                        for partial in range(1, 40))
    assert near_partials > 0.9 * spectrum.sum(), "the overtones are multiples of the note"


def test_chip_psg_squares_volumes_and_noise():
    rate = 53267.0
    period = 254                                                    # A4: 3579545 / (32 * 254) = 440.4 Hz
    writes = [(0, 0x80 | (period & 0x0F)), (0, period >> 4), (0, 0x90), (20000, 0x93)]
    tone = chip.psg(writes, 40000, float(PSG_CLOCK), rate)
    wanted = PSG_CLOCK / (32.0 * period)
    assert abs(_period_hz(tone[1000:19000], wanted) * rate / chip.OUTPUT_RATE - wanted) < 0.5
    loud, soft = numpy.abs(tone[1000:19000]).max(), numpy.abs(tone[21000:39000]).max()
    assert abs(loud - chip.PSG_LEVEL) < 0.01 and abs(20 * math.log10(soft / loud) + 6.0) < 0.2, (loud, soft)
    white = chip.psg([(0, 0xE4), (0, 0xF0)], 30000, float(PSG_CLOCK), rate)
    periodic = chip.psg([(0, 0xE0), (0, 0xF0)], 30000, float(PSG_CLOCK), rate)
    assert set(numpy.unique(numpy.abs(white[2000:]))) == {chip.PSG_LEVEL}
    # periodic noise repeats every 16 shifts (6991 shifts a second), white noise does not
    repeat = int(round(16 * rate / (PSG_CLOCK / 512.0)))
    alike = lambda signal: float(numpy.mean(signal[2000:20000] * signal[2000 + repeat:20000 + repeat])) / chip.PSG_LEVEL ** 2
    assert alike(periodic) > 0.8 and abs(alike(white)) < 0.2, (alike(periodic), alike(white))


def test_the_kinds_of_sound_cover_every_sound():
    listed = {sound for sounds in fm.SOUND_KINDS.values() for sound in sounds}
    plain = {name for name in instruments.SOUNDS if not name.startswith(("tracker", "patch:"))}
    assert listed == plain, (listed ^ plain)
    assert set(fm.DRUM_KIT_NAMES) == {name for name in instruments.DRUM_KITS if not name.startswith("tracker")}


# ----------------------------------------------------------------------------- a composition in JSON

def _json_source() -> dict:
    """A small valid composition in the composer's JSON form: two bars, every track."""
    def bar(number: int) -> dict:
        return {"barNumber": number, "section": "01: INTRO",
                "chord": {"name": "E7sus4", "voicingSteps_1_to_8": ["E3", "B3", "D4", "E4"],
                          "voicingSteps_9_to_16": ["D3", "A3", "B3", "F#4"]},
                "channels": {
                    "FM1_bass": ["E1", "E1", "E2", "---"] * 4,
                    "FM2_stabs": [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
                    "FM3_lead": ["E4", "---", "=", "---"] + ["---"] * 12,
                    "FM4_harmony": ["---"] * 16,
                    "PSG_arp": ["E4", "B4", "D5", "E5"] * 4,
                    "drums": ["KCK", "CHH", "SNR", "---"] * 3 + ["TOM1", "TOM2", "TOM3", "TOM4"]}}
    return {"metadata": {"title": "Proef", "bpm": 120, "stepsPerBar": 16, "key": "E Mixolydian"},
            "sections": [{"id": "01_INTRO", "name": "01: INTRO", "startBar": 1, "endBar": 2}],
            "synthParameters": {"FM1_SlapBass": {"volume": 0.5}},
            "bars": [bar(1), bar(2)]}


def _json_file(data: dict) -> str:
    folder = tempfile.mkdtemp()
    path = os.path.join(folder, "proef.json")
    with open(path, "w", encoding="utf-8") as json_file:
        json.dump(data, json_file)
    return path


def test_rows_of_steps_as_a_tracker_writes_them():
    row = notation.steps("E1 --- --- E2 === --- G1 ---")
    assert [(note.position, note.pitches, note.length) for note in row] == [
        (1.0, (28,), 0.75), (1.75, (40,), 0.25), (2.5, (31,), 0.5)], row
    hits = notation.drum_steps("KCK --- SNR TOM4")
    assert [(hit.position, hit.drum) for hit in hits] == [(1.0, "kick"), (1.5, "snare"), (1.75, "tom_vloer")]
    two = notation.stabs("1 0 0 0 1 0 0 0", "C3+G3", "D3+A3")
    assert [(note.position, note.pitches) for note in two] == [(1.0, (48, 55)), (2.0, (50, 57))], two
    assert abs(two[0].length - 0.6) < 1e-6, "a stab sounds 2.4 steps"
    assert notation.chord_classes("Dadd9/E") == notation.chord_classes("Dadd9"), "a slash chord is the chord before the slash"


def test_a_json_composition_is_read_track_by_track():
    source = json_bron.read(_json_file(_json_source()))
    assert source.bpm == 120.0 and source.title == "Proef" and source.mode == "E MIXOLYDIAN"
    assert len(source.bars) == 2 and source.volumes[0] == 0.5 and source.volumes[5] == tracker.DEFAULT_VOLUMES[5]
    first = source.bars[0]
    assert first["bass"][:4] == ["E1", "E1", "E2", "---"] and first["holds"]["bass"][:4] == [1, 1, 2, 0]
    assert first["lead"][2] == "===", "a single '=' stops the note, as '==='"
    assert first["holds"]["lead"][0] == 2, "held until the stop"
    assert first["chords"][0] == ["E3", "B3", "D4", "E4"] and first["chords"][8] == ["D3", "A3", "B3", "F#4"]
    played = tracker.render(source, 0.2)
    assert played.shape[1] == 2 and abs(len(played) / 44100.0 - (2 * 16 * 0.125 + 0.2)) < 0.01
    assert float(numpy.abs(played).max()) > 0.05, "it sounds"


def test_a_json_composition_that_is_not_complete_is_refused():
    def wrong(change) -> str:
        data = _json_source()
        change(data)
        return " | ".join(json_bron.problems(data))

    assert json_bron.problems(_json_source()) == []
    assert "bpm" in wrong(lambda data: data["metadata"].pop("bpm"))
    assert "'PSG_arp' ontbreekt" in wrong(lambda data: data["bars"][1]["channels"].pop("PSG_arp"))
    assert "15 vakjes" in wrong(lambda data: data["bars"][0]["channels"]["FM1_bass"].pop())
    assert "geen noot" in wrong(lambda data: data["bars"][0]["channels"]["FM3_lead"].__setitem__(0, "H9"))
    assert "onbekende drum" in wrong(lambda data: data["bars"][0]["channels"]["drums"].__setitem__(0, "BOEM"))
    assert "geen 0 of 1" in wrong(lambda data: data["bars"][0]["channels"]["FM2_stabs"].__setitem__(0, 2))
    assert "onbekend spoor" in wrong(lambda data: data["bars"][0]["channels"].__setitem__("FM9", []))
    assert "geen noten" in wrong(lambda data: data["bars"][0].__setitem__("chord", {"name": "E"}))
    assert "op volgorde" in wrong(lambda data: data["bars"][1].__setitem__("barNumber", 5))
    assert "'sections' ontbreekt" in wrong(lambda data: data.pop("sections"))
    try:
        json_bron.read(_json_file({"metadata": {}}))
        assert False, "refused"
    except ValueError as error:
        assert "kan zo niet gebruikt worden" in str(error)


def _flat_source() -> dict:
    """A small composition in the flat form of the composer's export (json_bron.from_flat)."""
    def bar(number: int, section: str) -> dict:
        return {"bar": number, "section": section, "chord": "E5",
                "lead": ["E4", "---", None, "G4"] + [None] * 12,
                "brass": [["E4", "B4"], "---", None, None] + [None] * 4 + [["D4", "A4"], "---"] + [None] * 6,
                "arp": ["E5", None] * 8,
                "bass": ["E2", None, "E2", "E3"] + [None] * 12,
                "drums": ["K+H", "H", "S+O", None] + ["H"] * 10 + ["T", "T"]}
    return {"title": "Plat", "bpm": 128, "stepsPerBar": 16, "key": "E Mixolydian",
            "bars": [bar(1, "A - Intro: Start"), bar(2, "B - Main Groove: Gas")]}


def test_a_flat_json_composition_is_read_as_the_usual_one():
    data = _flat_source()
    assert json_bron.is_flat(data) and json_bron.problems(data) == []
    source = json_bron.read(_json_file(data))
    assert source.bpm == 128.0 and source.title == "Plat" and len(source.bars) == 2
    first = source.bars[0]
    assert first["lead"][:4] == ["E4", "---", "===", "G4"], "null right after a note stops it"
    assert first["holds"]["lead"][0] == 2 and first["bass"][1] == "===" and first["arp"][1] == "==="
    assert first["stabTrig"][0] == 1 and first["stabTrig"][8] == 1 and sum(first["stabTrig"]) == 2
    assert first["chords"][0] == ["E4", "B4"] and first["chords"][8] == ["D4", "A4"], "each stab its own chord"
    assert first["harm"] == ["---"] * 16, "no harmony track in the flat form"
    assert first["drums"][:4] == ["KCK+CHH", "CHH", "SNR+OHH", "---"] and first["drums"][14] == "TOM2"
    kinds = [tracker.section_kind(bar["section"]) for bar in source.bars]
    assert kinds == ["intro", "thema"], kinds
    hits = notation.drum_steps("KCK+CHH --- SNR+OHH")
    assert [(hit.position, hit.drum) for hit in hits] == [(1.0, "kick"), (1.0, "hihat"), (1.5, "snare"), (1.5, "open")]
    played = tracker.render(source, 0.2)
    assert float(numpy.abs(played).max()) > 0.05, "it sounds"


def test_the_menu_is_the_second_composition_as_written_and_the_fight_scene_the_third():
    trackers = [score_module.load(name) for name in COMPOSITIONS if score_module.load(name).tracker]
    first, second = trackers[0], trackers[-1]
    made = {piece.name: piece for piece in derive.pieces(first, second, second)}
    menu = made["nachtstad_menu_loop"]
    assert menu.loop and menu.tracker == second.tracker and len(menu.bars) == len(second.bars), "the menu as written"
    assert made["zwervr_intro"].tracker == first.tracker, "the intro stays the first"
    assert len(made["karakterkeuze_loop"].bars) and made["handelaar_loop"].tempo == first.tempo
    assert made["laden_loop"].tempo == second.tempo, "the loading screen made from the second"
    for name in ("spel_loop", "deuntje_beloning", "deuntje_level_omhoog"):
        assert made[name].sounds == derive.in_own_voices(made[name], second).sounds, (name, "in the second's voices")
    second_tonic = second.tonic()
    rewarded = made["deuntje_beloning"].bars[0].parts["arp"][0].pitches[0]
    assert rewarded % 12 == second_tonic, "the reward on the second's tonic"
    assert made["deuntje_dood"].tempo == first.tempo / 2.0, "death stays the first"
    # the second's pieces keep its own groove: its bass and its drums as written
    own = [([(note.position, note.pitches) for note in bar.parts.get("bas", [])], [(hit.position, hit.drum) for hit in bar.hits])
           for bar in second.bars]
    for name in ("spel_loop", "karakterkeuze_loop", "laden_loop"):
        for bar in made[name].bars:
            mine = ([(note.position, note.pitches) for note in bar.parts.get("bas", [])], [(hit.position, hit.drum) for hit in bar.hits])
            assert mine in own, (name, "a bar with a bass or drums of its own")
    assert made["gevecht"].loop and made["gevecht"].tracker == second.tracker and len(made["gevecht"].bars) == len(second.bars)
    assert "gevecht" not in {piece.name for piece in derive.pieces(first, second)}, "no fight scene without a third"
    assert score_module.menu_name() in COMPOSITIONS


def _timeline_source() -> dict:
    """A small full timeline (tijdlijn.py): two bars, an intro bar and a loop bar."""
    operator = {"MUL": 1, "DET": -2, "TL": 10, "AR": 31, "D1R": 8, "D2R": 2, "D1L": 2, "RR": 7}
    def step(number: int) -> dict:
        return {"step": number,
                "FM1_SlapBass": {"note": "G1", "midi": 31, "velocity": 127} if number == 1 else {"note": "---", "velocity": 0},
                "FM2_HouseStabs": None, "FM3_LeadSynth": {"note": "---", "velocity": 0},
                "FM4_SubPad": {"notes": ["G3", "D4"], "velocity": 95} if number == 1 else None,
                "FM5_FMPerc": "RIMSHOT_D5" if number == 5 else ("FM_TOM_SLIDE" if number == 9 else "---"),
                "FM6_DAC_Drums": "KICK_SNARE_CLAP" if number == 1 else ("VOX_GO" if number == 13 else "---"),
                "PSG1_Arp": {"note": "G4", "midi": 67, "velocity": 88},
                "PSG2_CounterEcho": {"midi": 70, "velocity": 75} if number in (3, 4) else None,
                "PSG4_NoiseHats": "OH" if number % 4 == 3 else "CH"}
    bars = [{"bar": number, "section": "Intro" if number == 1 else "Section A1: Groove", "chord": "Gm7",
             "steps": [step(index) for index in range(1, 17)]} for number in (1, 2)]
    return {"metadata": {"title": "Proef", "bpm": 126, "steps_per_bar": 16, "key_signature": "G Dorian",
                         "loop_points": {"seamless_loop_start_bar": 2, "seamless_loop_end_bar": 2}},
            "hardware_patches": {"FM1_SlapBass": {"algorithm": 4, "feedback": 6, "operators": {f"OP{i}": operator for i in range(1, 5)}}},
            "arrangement_structure": [{"section": "Intro", "start_bar": 1, "end_bar": 1},
                                      {"section": "Section A1: Groove", "start_bar": 2, "end_bar": 2}],
            "full_track_timeline_2_bars": bars,
            "flat_sequencer_events": [{"bar": b, "step": 1, "channel": "FM1_SlapBass", "note": "G1", "midi": 31,
                                       "duration_steps": 2, "velocity": 127} for b in (1, 2)]}


def test_a_full_timeline_is_read_note_for_note_with_its_own_patches():
    import tijdlijn
    path = _json_file(_timeline_source())
    voice = tijdlijn.patches(path)["FM1_SlapBass"]
    assert voice.algorithm == 4 and voice.feedback == 6 and voice.detunes == (6, 6, 6, 6), "DET -2 is register 6"
    source = tijdlijn.read(path)
    assert source["loop"] == (2, 2) and source["tempo"] == 126.0
    first = source["bars"][0]
    assert first["bas"] == [(1.0, (31,), 0.5, 1.0)], "the bass with its length from the flat events"
    assert first["pad"][0][2] == 4.0, "the pad holds the whole bar"
    assert len(first["arp"]) == 16 and first["echo"][0][2] == 0.25 and first["echo"][1][2] == 3.25, "the echo sustains"
    assert (1.0, "kick", 1.0) in first["drums"] and (1.0, "clap", 1.0) in first["drums"], "KICK_SNARE_CLAP: three at once"
    assert (3.0, "tom_laag", 0.8) in first["drums"] and first["perc"][0][1] == (notation.pitch("D5"),)
    assert any("VOX_GO" in warning for warning in source["warnings"]), "a voice sample is reported"
    assert [section["soort"] for section in source["sections"]] == ["intro", "thema"]
    text = tijdlijn.composition_source(source, "proef", "proef.json")
    assert "LUSPUNTEN = (2, 2)" in text and '"patch:proef.json:FM1_SlapBass",' in text, "the patch at its own level"


def test_a_composition_from_json_plays_its_source_and_its_voices():
    found = 0
    for name in COMPOSITIONS:
        score = score_module.load(name)
        if not score.tracker:
            continue
        found += 1
        source = tracker.tracker_in_compositions(score.tracker)
        assert len(source.bars) == len(score.bars), (name, len(source.bars), len(score.bars))
        intro = derive.pieces(score)[0]
        assert intro.name == "zwervr_intro" and intro.tracker == score.tracker, "the intro is the source itself"
        # every row of the composition file is the row of the source
        for bar, written in zip(source.bars, score.bars):
            starts = sum(1 for cell in bar["bass"] if cell not in ("---", "==="))
            assert len(written.parts.get("bas", [])) == starts, (name, bar["barNum"])
            assert len(written.hits) == sum(len(cell.split("+")) for cell in bar["drums"] if cell != "---"), \
                (name, bar["barNum"])
        for piece in derive.pieces(score)[1:]:
            for part in {part for bar in piece.bars for part in bar.parts}:
                assert piece.sound_of(part).startswith("tracker_"), (piece.name, part, piece.sound_of(part))
            assert piece.sounds.get("drumstel", "standaard") == "tracker", piece.name
    assert found >= 1, "the active composition comes from a JSON"


def test_the_voices_and_the_drums_of_the_tracker():
    for voice_name in ("bas", "brass", "lead", "harmonie", "arp"):
        sound = instruments.SOUNDS["tracker_" + voice_name]
        note = sound.render((57,), 0.3, 1.0)
        assert len(note) > 0 and float(numpy.abs(note).max()) > 0.01, voice_name
    placed = instruments.SOUNDS["tracker_lead=fm_lead_helder"]
    assert placed.pan == instruments.SOUNDS["fm_lead_helder"].pan
    kit = instruments.DRUM_KITS["tracker"]
    assert set(notation.DRUM_NAMES) <= set(kit), set(notation.DRUM_NAMES) - set(kit)
    kick = numpy.abs(numpy.fft.rfft(kit["kick"].samples, 16384))
    assert int(kick.argmax()) * 44100.0 / 16384 < 120.0, "the kick is low"


# ----------------------------------------------------------------------------- one JSON to one OGG

def _quiet(function, *arguments):
    """The function's result, and what it printed (stdout and stderr together)."""
    printed = io.StringIO()
    with contextlib.redirect_stdout(printed), contextlib.redirect_stderr(printed):
        result = function(*arguments)
    return result, printed.getvalue()


def test_a_json_composition_as_written_is_one_piece_played_once():
    path = _json_file(_json_source())
    piece, warnings = json_naar_ogg.piece_as_written(path, "proef")
    assert piece.name == "proef" and not piece.loop and piece.tempo == 120.0 and len(piece.bars) == 2
    assert piece.tracker == os.path.abspath(path), "played from the file where it is"
    assert tracker.tracker_in_compositions(piece.tracker).bpm == 120.0
    assert any("FM2_PolyBrass" in warning for warning in warnings), "a volume the file does not give is reported"
    stereo = mixer.render(piece)
    assert len(stereo) == int(round((4.0 + piece.tail) * mixer.SAMPLE_RATE)) and float(numpy.abs(stereo).max()) > 0.05
    flat_piece, _warnings = json_naar_ogg.piece_as_written(_json_file(_flat_source()), "plat")
    assert flat_piece.tracker and not flat_piece.loop, "the flat form the same way"


def test_a_timeline_as_written_plays_its_own_patches_from_where_the_file_is():
    data = _timeline_source()
    # every FM channel that plays has its patch (the small timeline gives only FM1 one)
    for channel in ("FM2_HouseStabs", "FM3_LeadSynth", "FM4_SubPad", "FM5_FMPerc"):
        data["hardware_patches"][channel] = data["hardware_patches"]["FM1_SlapBass"]
    path = _json_file(data)
    piece, warnings = json_naar_ogg.piece_as_written(path, "proef")
    assert not piece.tracker and not piece.loop and len(piece.bars) == 2 and piece.tempo == 126.0
    assert piece.sounds["bas"].startswith("patch:") and piece.sounds["bas"].endswith("proef.json:FM1_SlapBass")
    assert instruments.SOUNDS[piece.sounds["bas"]].chip_voice.algorithm == 4, "the patch of the file itself"
    assert any("VOX_GO" in warning for warning in warnings)
    assert float(numpy.abs(mixer.render(piece)).max()) > 0.05, "it sounds"


def test_json_to_ogg_writes_only_the_file_asked_for():
    path = _json_file(_json_source())
    folder = os.path.dirname(path)
    compositions_before = sorted(os.listdir(score_module.COMPOSITIONS_FOLDER))
    result, printed = _quiet(json_naar_ogg.main, [path, os.path.join(folder, "uit.ogg")])
    assert result == 0 and "uit.ogg" in printed and "6.50 s" in printed, printed
    assert sorted(os.listdir(folder)) == ["proef.json", "uit.ogg"] and os.path.getsize(os.path.join(folder, "uit.ogg")) > 5000
    assert sorted(os.listdir(score_module.COMPOSITIONS_FOLDER)) == compositions_before, "composities/ untouched"
    assert not [name for name in sys.modules if name.startswith(json_naar_ogg.MODULE_PREFIX)]


def test_json_to_ogg_refuses_what_it_cannot_make():
    path = _json_file(_json_source())
    folder = os.path.dirname(path)

    def refused(json_path: str, ogg_path: str) -> str:
        result, printed = _quiet(json_naar_ogg.main, [json_path, ogg_path])
        assert result == 1, printed
        return printed

    assert "bestaat niet" in refused(os.path.join(folder, "weg.json"), os.path.join(folder, "uit.ogg"))
    assert "moet op .ogg eindigen" in refused(path, os.path.join(folder, "uit.wav"))
    assert "map voor de uitvoer bestaat niet" in refused(path, os.path.join(folder, "nergens", "uit.ogg"))
    assert "muziek van het spel" in refused(path, os.path.join(json_naar_ogg.MUSIC_FOLDER, "zwervr_intro.ogg"))
    broken = os.path.join(folder, "kapot.json")
    with open(broken, "w", encoding="utf-8") as json_file:
        json_file.write('{"metadata": ')
    assert "geen geldig JSON" in refused(broken, os.path.join(folder, "uit.ogg"))
    assert "onbekende vorm" in refused(_json_file({"title": "Proef", "tempo_bpm": 120, "patterns": {}}),
                                       os.path.join(folder, "uit.ogg"))
    incomplete = _json_source()
    del incomplete["bars"][0]["channels"]["FM3_lead"]
    assert "FM3_lead" in refused(_json_file(incomplete), os.path.join(folder, "uit.ogg"))
    assert "'pad'" in refused(_json_file(_timeline_source()), os.path.join(folder, "uit.ogg")), "a channel without its patch"
    assert sorted(os.listdir(folder)) == ["kapot.json", "proef.json"], "nothing written on a refusal"


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
