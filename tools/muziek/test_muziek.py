"""Unit tests of the music tools (docs/MUZIEK.md): the notation, the BIJSTELLING (score.tune),
the drum kits and sounds, and the derived pieces of every composition (the map jingle short
enough, every piece there). Every function test_* is a test; plain asserts.
Run: tools/muziek/render.sh --test
"""
import glob
import os
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import derive  # noqa: E402
import instruments  # noqa: E402
import notation  # noqa: E402
import score as score_module  # noqa: E402
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
              "deuntje_level_omhoog", "deuntje_dood"}
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


def test_the_notes_of_a_bar_stay_inside_it():
    for name in COMPOSITIONS:
        score = score_module.load(name)
        for bar in score.bars:
            for part, part_notes in bar.parts.items():
                for note in part_notes:
                    assert 1.0 <= note.position < score.beats_per_bar + 1.0, (name, bar.number, part, note.position)
            for hit in bar.hits:
                assert 1.0 <= hit.position < score.beats_per_bar + 1.0, (name, bar.number, hit.drum, hit.position)


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
