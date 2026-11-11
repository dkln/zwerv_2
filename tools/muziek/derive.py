"""The pieces of the game, all made from one composition (docs/MUZIEK.md, "Afgeleide stukken").

The intro is the composition itself, bar for bar as the composer wrote it. Everything else is
made from its material: its bars, chords, melodies, sounds and drums, re-arranged; nothing is
written here that is not in the composition (except a pad or a bass line spelled from its
chords, and the slowed-down motif of the death tune). The derivations look for the sections by
their soort (intro, thema, opbouw, refrein, breakdown, finale), so they work for any composition
that has them; a missing one falls back to the nearest (Score.first_section).

    zwervr_intro           the composition, once, ringing out
    nachtstad_menu_loop    main menu: the breakdown and the theme, calm (pad, arp, bells)
    karakterkeuze_loop     character choice: the theme, its groove light, the melody on the PSG
    handelaar_loop         at a merchant: the lift's chords on an electric piano, a walking bass
    spel_loop              roaming the city: the song as a loop without its intro and ending
    deuntje_nieuwe_missie  a new mission: the motif (first bar of the theme), ending on the tonic
    deuntje_taak_klaar     a task done: a run up the dominant, landing on the tonic
    deuntje_gewonnen       a mission done: the last two bars of the composition (its finish)
    deuntje_level_omhoog   a level up: a run up the tonic chord to the high tonic
    deuntje_dood           death: the motif at half speed an octave down, falling to the low
                           tonic, a tape stop
"""
from dataclasses import replace

import notation
from mixer import Piece
from notation import Note, drums
from score import Bar, Score


# ----------------------------------------------------------------------------- bar helpers

def keep(bar: Bar, parts: tuple, keep_drums: bool = True) -> Bar:
    """A copy of the bar with only these parts (and its drums, or none)."""
    result = bar.copy()
    result.parts = {part: notes for part, notes in result.parts.items() if part in parts}
    if not keep_drums:
        result.hits = []
    return result


def recast(bar: Bar, old_part: str, new_part: str, semitones: int = 0, velocity: float = 1.0) -> Bar:
    """The bar with the notes of `old_part` moved to `new_part` (another sound)."""
    result = bar.copy()
    moved = [note.transposed(semitones).softer(velocity) for note in result.parts.pop(old_part, [])]
    if moved:
        result.parts[new_part] = result.parts.get(new_part, []) + moved
    return result


def softer(bar: Bar, part: str, factor: float) -> Bar:
    result = bar.copy()
    if part == "drums":
        result.hits = [replace(hit, velocity=hit.velocity * factor) for hit in result.hits]
    elif part in result.parts:
        result.parts[part] = [note.softer(factor) for note in result.parts[part]]
    return result


def with_drums(bar: Bar, hits: list) -> Bar:
    result = bar.copy()
    result.hits = list(hits)
    return result


def pad_from_chords(bar: Bar, lowest: int = 50, velocity: float = 0.8) -> list:
    """The bar's chords held, in close position from `lowest` (D3)."""
    return [Note(start, notation.chord_voicing(name, lowest)[:4], length, velocity)
            for name, start, length in bar.chords]


def roots(bar: Bar, lowest: int = 33) -> list:
    """[(root MIDI from `lowest`, start, length)] of the bar's chords (bass register: A1 up)."""
    return [(notation.chord_voicing(name, lowest)[0], start, length) for name, start, length in bar.chords]


def long_bass(bar: Bar, velocity: float = 0.9) -> list:
    return [Note(start, (root,), length, velocity) for root, start, length in roots(bar)]


def walking_bass(bar: Bar, velocity: float = 0.85) -> list:
    """Root, fifth, octave pop and root again in each chord: the relaxed bass of the shop."""
    result = []
    for root, start, length in roots(bar):
        result.append(Note(start, (root,), min(1.0, length), velocity))
        if length >= 2:
            result.append(Note(start + 1.0, (root + 7,), 0.5, velocity * 0.85))
            result.append(Note(start + 1.5, (root + 12,), 0.5, velocity * 0.7))
        if length >= 4:
            result.append(Note(start + 2.0, (root,), 1.0, velocity))
            result.append(Note(start + 3.0, (root + 7,), 0.5, velocity * 0.85))
            result.append(Note(start + 3.5, (root + 10,), 0.5, velocity * 0.75))
    return result


def comp(bar: Bar, positions: tuple, length: float = 0.5, lowest: int = 55, velocity: float = 0.75) -> list:
    """Chord stabs on these beats, the chord of that moment."""
    return [Note(position, notation.chord_voicing(bar.chord_at(position), lowest)[:4], length, velocity)
            for position in positions]


def arp_from_chords(bar: Bar, lowest: int = 62, velocity: float = 0.8) -> list:
    """Root, third, fifth, octave in sixteenths, through each chord of the bar."""
    result = []
    for name, start, length in bar.chords:
        voicing = notation.chord_voicing(name, lowest)
        figure = list(voicing[:3]) + [voicing[0] + 12]
        steps = int(length / 0.25)
        result += [Note(start + step * 0.25, (figure[step % len(figure)],), 0.25, velocity) for step in range(steps)]
    return result


# ----------------------------------------------------------------------------- the material

def motif_bar(score: Score) -> Bar:
    """The bar the theme opens with (its first bar with a melody): the motif of the game."""
    for bar in score.first_section("thema", "refrein"):
        if bar.parts.get("lead"):
            return bar
    return next(bar for bar in score.bars if bar.parts.get("lead"))


def tonic_chord(score: Score, lowest: int) -> tuple:
    third = 3 if score.is_minor() else 4
    root = lowest + (score.tonic() - lowest) % 12
    return (root, root + third, root + 7)


def dominant_seventh(score: Score, lowest: int) -> tuple:
    """V7 (in minor the harmonic minor's: with the raised seventh, as the cadences have it)."""
    root = lowest + (score.tonic() + 7 - lowest) % 12
    return (root, root + 4, root + 7, root + 10)


# ----------------------------------------------------------------------------- the pieces

def intro(score: Score) -> Piece:
    return Piece("zwervr_intro", score.tempo, score.beats_per_bar, [bar.copy() for bar in score.bars],
                 score.sounds, loop=False, tail=2.5)


def menu_loop(score: Score) -> Piece:
    """Calm: the breakdown (without its crescendo) and the theme as pad, arp and bells."""
    breakdown = score.first_section("breakdown", "intro")
    theme = score.first_section("thema")
    calm_drums = drums(kick="1", snare="3", hihat="8", velocity=0.55)
    bars = []
    for bar in breakdown:
        bars.append(softer(with_drums(keep(bar, ("pad", "arp", "subbas", "bas")), calm_drums), "arp", 0.85))
    for bar in theme:
        calm = keep(bar, ("arp", "lead"), keep_drums=False)
        calm = recast(calm, "lead", "klok", velocity=0.8)
        calm.parts["pad"] = pad_from_chords(bar, velocity=0.7)
        calm.parts["subbas"] = long_bass(bar)
        bars.append(with_drums(calm, calm_drums))
    for bar in breakdown:
        bars.append(with_drums(keep(bar, ("pad", "arp", "subbas", "bas", "lead")), calm_drums))
    sounds = dict(score.sounds, klok="fm_klok")
    return Piece("nachtstad_menu_loop", score.tempo, score.beats_per_bar, bars, sounds,
                 part_gains={"arp": 0.9, "pad": 1.1})


def character_loop(score: Score) -> Piece:
    """The theme twice: first its groove alone (bass, arp, a pad), then the melody on the PSG."""
    theme = score.first_section("thema")
    light_drums = drums(kick="1 3", snare="2 4", hihat="8", velocity=0.7)
    bars = []
    for with_melody in (False, True):
        for bar in theme:
            light = keep(bar, ("bas", "arp", "lead") if with_melody else ("bas", "arp"), keep_drums=False)
            light = recast(light, "lead", "psg_melodie")
            light = softer(light, "bas", 0.8)
            light.parts["pad"] = pad_from_chords(bar, velocity=0.55)
            bars.append(with_drums(light, light_drums))
    sounds = dict(score.sounds, psg_melodie="psg_lead")
    return Piece("karakterkeuze_loop", score.tempo, score.beats_per_bar, bars, sounds)


def merchant_loop(score: Score) -> Piece:
    """The lift's warm chords (and the theme's opening) on an electric piano over a walking
    bass, clap on 2 and 4: easy listening in the shop."""
    lift = score.first_section("opbouw", "thema")
    theme = score.first_section("thema")[:4]
    shop_drums = drums(kick="1 3", clap="2 4", hihat="8", velocity=0.6) + drums(open="4.5", velocity=0.5)

    def shop_bar(bar: Bar, melody: bool) -> Bar:
        result = keep(bar, ("lead",) if melody else (), keep_drums=False)
        result = recast(result, "lead", "melodie", semitones=-12, velocity=0.85)
        result.parts["piano"] = comp(bar, (1.0, 1.75, 2.5, 4.0), velocity=0.6)
        result.parts["bas"] = walking_bass(bar)
        return with_drums(result, shop_drums)

    bars = [shop_bar(bar, False) for bar in lift] + [shop_bar(bar, True) for bar in lift]
    bars += [shop_bar(bar, True) for bar in theme] + [shop_bar(bar, True) for bar in lift]
    sounds = dict(score.sounds, piano="fm_piano", melodie="fm_piano", bas="fm_subbas")
    return Piece("handelaar_loop", score.tempo, score.beats_per_bar, bars, sounds,
                 part_gains={"piano": 0.8, "drums": 0.8})


def game_loop(score: Score) -> Piece:
    """The song as the city's loop: theme, lift, chorus, breakdown and the theme again with its
    melody on the PSG; no intro, no final hit, the lead and the guitar a little back."""
    bars = []
    for kind in ("thema", "opbouw", "refrein", "breakdown"):
        bars += [bar.copy() for bar in score.section(kind)]
    for bar in score.first_section("thema"):
        bars.append(recast(bar, "lead", "psg_melodie", velocity=0.95))
    sounds = dict(score.sounds, psg_melodie="psg_lead")
    return Piece("spel_loop", score.tempo, score.beats_per_bar, bars, sounds,
                 part_gains={"lead": 0.85, "gitaar": 0.8, "solo": 0.8})


def new_mission(score: Score) -> Piece:
    """The motif with its groove, landing on the tonic (lead, pad, bass and a crash)."""
    opening = motif_bar(score).copy()
    opening.hits = drums(kick="1 2.5 3", snare="2 4", hihat="8", crash="1") + notation.drum_run("S S S S", 0.25, start=4)
    opening.parts["brass"] = comp(opening, (1.0,), length=1.5, lowest=50, velocity=0.8)
    tonic = tonic_chord(score, 62)
    landing = Bar(0, opening.chords, {
        "lead": [Note(1.0, (tonic[0],), 2.0)],
        "pad": [Note(1.0, tonic_chord(score, 50) + (tonic[0],), 2.0, 0.85)],
        "bas": [Note(1.0, (tonic[0] - 24,), 2.0)],
        "arp": [Note(1.0, (tonic[2] + 12,), 1.0, 0.8)],
    }, drums(kick="1", crash="1"))
    return Piece("deuntje_nieuwe_missie", score.tempo, score.beats_per_bar, [opening, landing],
                 score.sounds, loop=False, tail=1.4, last_bar_beats=1.0)


def task_done(score: Score) -> Piece:
    """A run of sixteenths up the dominant seventh (as the intro's break), landing on the tonic."""
    dominant = dominant_seventh(score, 57)
    figure = list(dominant) + [pitch + 12 for pitch in dominant]
    tonic = tonic_chord(score, 62)
    parts = {
        "arp": [Note(1.0 + step * 0.25, (pitch,), 0.25, 0.9) for step, pitch in enumerate(figure)],
        "lead": [Note(3.0, (tonic[0] + 12,), 1.0)],
        "pad": [Note(3.0, tonic_chord(score, 50) + (tonic[0],), 1.0, 0.8)],
        "bas": [Note(3.0, (tonic[0] - 24,), 1.0)],
    }
    hits = drums(hihat="1 1.5 2 2.5", velocity=0.7) + drums(kick="3", crash="3")
    return Piece("deuntje_taak_klaar", score.tempo, score.beats_per_bar, [Bar(0, [], parts, hits)],
                 score.sounds, loop=False, tail=1.0, last_bar_beats=3.5)


def mission_done(score: Score) -> Piece:
    """The finish of the composition: its last two bars."""
    return Piece("deuntje_gewonnen", score.tempo, score.beats_per_bar, [bar.copy() for bar in score.bars[-2:]],
                 score.sounds, loop=False, tail=1.5)


def level_up(score: Score) -> Piece:
    """Up the tonic chord in sixteenths to the high tonic, held with the guitar and a crash."""
    tonic = tonic_chord(score, 62)
    figure = [tonic[0], tonic[1], tonic[2], tonic[0] + 12, tonic[1] + 12, tonic[2] + 12]
    high = tonic[0] + 24 if tonic[0] + 24 <= 88 else tonic[0] + 12
    parts = {
        "arp": [Note(1.0 + step * 0.25, (pitch,), 0.25, 0.9) for step, pitch in enumerate(figure)],
        "lead": [Note(1.0 + step * 0.25, (pitch,), 0.25, 0.8) for step, pitch in enumerate(figure[:4])]
        + [Note(2.5, (high,), 1.5)],
        "gitaar": [Note(2.5, (tonic[0] - 12, tonic[0] - 5, tonic[0]), 1.5)],
        "bas": [Note(2.5, (tonic[0] - 24,), 1.5)],
    }
    hits = drums(snare="1 1.25 1.5 1.75 2 2.25", velocity=0.55) + drums(kick="2.5", snare="2.5", crash="2.5")
    return Piece("deuntje_level_omhoog", score.tempo, score.beats_per_bar, [Bar(0, [], parts, hits)],
                 score.sounds, loop=False, tail=1.2, last_bar_beats=4.0)


def death(score: Score) -> Piece:
    """The motif at half speed an octave down, falling to the low tonic; the tape stops."""
    opening = motif_bar(score)
    melody = [note.transposed(-12) for note in opening.parts["lead"]]
    tonic = tonic_chord(score, 50)
    first = Bar(0, opening.chords, {
        "lead": melody,
        "pad": [Note(1.0, tonic_chord(score, 50) + (tonic[0] + 12,), 4.0, 0.8)],
        "subbas": [Note(1.0, (tonic[0] - 12,), 4.0)],
    }, drums(kick="1", snare="3", velocity=0.7) + drums(crash="1", velocity=0.6))
    fall = [tonic[2], tonic[1], tonic[0]]
    second = Bar(0, opening.chords, {
        "lead": [Note(1.0 + index * 0.5, (pitch,), 0.5 if index < 2 else 1.5) for index, pitch in enumerate(fall)],
        "pad": [Note(1.0, tonic_chord(score, 38), 2.0, 0.8)],
        "subbas": [Note(1.0, (tonic[0] - 24,), 2.0)],
    }, drums(kick="1", velocity=0.8))
    tempo = score.tempo / 2.0
    beat = 60.0 / tempo
    bar_seconds = beat * score.beats_per_bar
    return Piece("deuntje_dood", tempo, score.beats_per_bar, [first, second], score.sounds, loop=False,
                 tail=0.6, last_bar_beats=2.0, tape_stop=(bar_seconds + beat * 1.0, beat * 1.6))


ALL = (intro, menu_loop, character_loop, merchant_loop, game_loop,
       new_mission, task_done, mission_done, level_up, death)


def pieces(score: Score) -> list:
    return [make(score) for make in ALL]
