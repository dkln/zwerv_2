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
    laden_loop             the loading screen: the composition's own intro (the boot-up), twice,
                           first its pulse alone, then with its melody and the fill
    spel_loop              roaming the city: quiet and calm, the merchant's sound in half time,
                           varied like the merchant's loop (theme, lift, chorus, breakdown)
    deuntje_kaart_start    the map opens (at most 6 s): the first two bars of the composition's
                           intro (the start), landing on the tonic chord with a crash
    deuntje_nieuwe_missie  a new mission: the motif (first bar of the theme), ending on the tonic
    deuntje_taak_klaar     a task done: a run up the dominant, landing on the tonic
    deuntje_gewonnen       a mission done: the last two bars of the composition (its finish);
                           without an ending: its last bar, landing on the tonic chord
    deuntje_level_omhoog   a level up: a run up the tonic chord to the high tonic
    deuntje_beloning       a reward or an item got (the reward screen): the tonic chord
                           sparkling up and back in the arp, the high tonic rung out on top
    deuntje_dood           death: the motif at half speed an octave down, falling to the low
                           tonic, a tape stop
    supermarkt_muzak_1..3  the supermarkets (soft, in the background): muzak from the theme and
                           the chorus, chords sweetened, melody smoothed: a bossa nova, a slow
                           ballad, a light swing
    jingle_derrek, jingle_alfred_steyhn   the sound logo of each supermarket chain, before an
                           announcement in the shop
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


def tonic_chord(score: Score, lowest: int, landing: bool = False) -> tuple:
    """The tonic triad from `lowest`; a `landing` (the end of a jingle) in major when the
    BIJSTELLING asks for a major ending."""
    third = 3 if score.is_minor() and not (landing and score.major_ending) else 4
    root = lowest + (score.tonic() - lowest) % 12
    return (root, root + third, root + 7)


def dominant_seventh(score: Score, lowest: int) -> tuple:
    """V7 (in minor the harmonic minor's: with the raised seventh, as the cadences have it)."""
    root = lowest + (score.tonic() + 7 - lowest) % 12
    return (root, root + 4, root + 7, root + 10)


# ----------------------------------------------------------------------------- the pieces

def intro(score: Score) -> Piece:
    """The composition itself; one read from a VGM (score.vgm) is that VGM, played by the
    chip imitation (the bars are then only its length and its moments)."""
    return Piece("zwervr_intro", score.tempo, score.beats_per_bar, [bar.copy() for bar in score.bars],
                 score.sounds, loop=False, tail=2.5, vgm=score.vgm)


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


## The easy-going style of the shop and the city: an electric piano comping, a walking bass,
## kick on 1 and 3 with a clap on 2 and 4 (easy_bar).
EASY_DRUMS = drums(kick="1 3", clap="2 4", hihat="8", velocity=0.6) + drums(open="4.5", velocity=0.5)
EASY_SOUNDS = {"piano": "fm_piano", "melodie": "fm_piano", "bas": "fm_subbas"}


def easy_bar(bar: Bar, melody: bool, melody_semitones: int = -12) -> Bar:
    """The bar in the easy-going style: the piano on its chords (stabs on 1, the "a" of 1, the
    "and" of 2 and on 4), the walking bass, the light beat; with its melody on the piano too
    (`melody_semitones` lower) or without."""
    result = keep(bar, ("lead",) if melody else (), keep_drums=False)
    result = recast(result, "lead", "melodie", semitones=melody_semitones, velocity=0.85)
    result.parts["piano"] = comp(bar, (1.0, 1.75, 2.5, 4.0), velocity=0.6)
    result.parts["bas"] = walking_bass(bar)
    return with_drums(result, EASY_DRUMS)


def merchant_loop(score: Score) -> Piece:
    """The lift's warm chords (and the theme's opening) on an electric piano over a walking
    bass, clap on 2 and 4: easy listening in the shop."""
    lift = score.first_section("opbouw", "thema")
    theme = score.first_section("thema")[:4]
    bars = [easy_bar(bar, False) for bar in lift] + [easy_bar(bar, True) for bar in lift]
    bars += [easy_bar(bar, True) for bar in theme] + [easy_bar(bar, True) for bar in lift]
    return Piece("handelaar_loop", score.tempo, score.beats_per_bar, bars, dict(score.sounds, **EASY_SOUNDS),
                 part_gains={"piano": 0.8, "drums": 0.8})


def loading_loop(score: Score) -> Piece:
    """Waiting while the city loads: the composition's intro section (its boot-up), first as a
    pulse (pad, bass, arp, a light beat), then as written, with its melody and its fill, which
    runs back into the start."""
    opening = score.first_section("intro", "thema")
    pulse_drums = drums(kick="1 3", hihat="16", velocity=0.6)
    bars = [with_drums(keep(bar, ("pad", "bas", "subbas", "arp")), pulse_drums) for bar in opening]
    bars += [softer(bar.copy(), "drums", 0.8) for bar in opening]
    return Piece("laden_loop", score.tempo, score.beats_per_bar, bars, score.sounds,
                 part_gains={"arp": 1.1})


def slow_bass(bar: Bar, velocity: float = 0.8) -> list:
    """Root and fifth in half notes: a bass that walks slowly (the half-time feel)."""
    result = []
    for root, start, length in roots(bar):
        if length >= 4:
            result += [Note(start, (root,), 2.0, velocity), Note(start + 2.0, (root + 7,), 2.0, velocity * 0.85)]
        else:
            result.append(Note(start, (root,), length, velocity))
    return result


def game_loop(score: Score) -> Piece:
    """The city's loop: quiet in the background, in the merchant's sound (electric piano, the
    bass, a clap) but in half time, so it feels calm: kick on 1, clap on 3, the piano holding its
    chords, the bass walking in half notes. Varied like the merchant's loop, the sections and
    their filling taking turns: the theme as chords alone; the theme with its melody bar by
    bar in turn (call and answer); the lift with the merchant's stabs; the chorus with its
    melody on the bells every other bar; the breakdown with piano and bass alone, running back
    to the start. No guitar, no bright lead, no running arpeggio, no shuffle."""
    half_time = drums(kick="1", clap="3", hihat="2 4", velocity=0.5) + drums(open="4.5", velocity=0.35)
    hats_only = drums(hihat="2 4", velocity=0.4)

    def calm_bar(bar: Bar, melody_sound: str = "", melody_now: bool = False, stabs: bool = False,
                 beat: list = half_time) -> Bar:
        result = keep(bar, ("lead",) if melody_sound and melody_now else (), keep_drums=False)
        result = recast(result, "lead", melody_sound or "melodie", semitones=-12, velocity=0.75)
        if stabs:
            result.parts["piano"] = comp(bar, (1.0, 1.75, 2.5, 4.0), velocity=0.5)
        else:
            result.parts["piano"] = [Note(start, notation.chord_voicing(name, 55)[:4], length, 0.55)
                                     for name, start, length in bar.chords]
        result.parts["bas"] = slow_bass(bar)
        return with_drums(result, beat)

    theme = score.first_section("thema")
    chorus = score.first_section("refrein", "thema")
    bars = [calm_bar(bar) for bar in theme]
    bars += [calm_bar(bar, "melodie", melody_now=index % 2 == 0) for index, bar in enumerate(theme)]
    bars += [calm_bar(bar, stabs=True) for bar in score.first_section("opbouw", "thema")]
    bars += [calm_bar(bar, "klok", melody_now=index % 2 == 0) for index, bar in enumerate(chorus)]
    bars += [calm_bar(bar, beat=hats_only) for bar in score.first_section("breakdown", "opbouw")]
    sounds = dict(score.sounds, **EASY_SOUNDS, klok="fm_klok")
    return Piece("spel_loop", score.tempo, score.beats_per_bar, bars, sounds,
                 part_gains={"piano": 0.8, "drums": 0.75})


def landing_bar(score: Score, chords: list, beats: float) -> Bar:
    """A landing on the tonic chord (lead, pad, bass, a note of the arp) with a kick and a
    crash, held `beats` long: the arrival after a run-up."""
    tonic = tonic_chord(score, 62, landing=True)
    landing = Bar(0, chords, {
        "lead": [Note(1.0, (tonic[0] + 12,), beats)],
        "pad": [Note(1.0, tonic_chord(score, 50, landing=True) + (tonic[0],), beats, 0.85)],
        "bas": [Note(1.0, (tonic[0] - 24,), beats)],
        "arp": [Note(1.0, (tonic[2] + 12,), 1.0, 0.8)],
    }, drums(kick="1", crash="1"))
    # (a part the composition doubles, BIJSTELLING "verdubbel": the landing doubled too)
    for part in list(score.sounds):
        if part.endswith("_dubbel") and part[:-len("_dubbel")] in landing.parts:
            landing.parts[part] = list(landing.parts[part[:-len("_dubbel")]])
    return landing


def has_ending(score: Score) -> bool:
    """Whether the composition comes to an end in its last bar (a held last note or chord, or
    a crash), instead of running on into a repeat (a VGM of a looping tune ends in mid-run)."""
    last = score.bars[-1]
    held = any(note.length >= 1.5 for part_notes in last.parts.values() for note in part_notes)
    return held or any(hit.drum == "crash" for hit in last.hits)


## The map jingle plays when the game opens the map (scripts/ui/hud.gd MAP_JINGLE): at most this
## many seconds, tail included.
MAP_JINGLE_LONGEST = 6.0


def map_start(score: Score) -> Piece:
    """The opening of the composition (its intro: the start of the song) for the opening of the
    map: two bars of it (one if two would last longer than MAP_JINGLE_LONGEST), then a landing
    on the tonic chord with a crash, as long as the time left allows."""
    opening = score.first_section("intro", "thema")
    bar_seconds = 60.0 / score.tempo * score.beats_per_bar
    tail = 1.2
    count = 2 if 2 * bar_seconds + 0.5 * bar_seconds + tail <= MAP_JINGLE_LONGEST else 1
    bars = [bar.copy() for bar in opening[:count]]
    landing_beats = max(1.0, min(2.0, (MAP_JINGLE_LONGEST - tail - count * bar_seconds) / (60.0 / score.tempo)))
    landing = landing_bar(score, bars[-1].chords, landing_beats)
    return Piece("deuntje_kaart_start", score.tempo, score.beats_per_bar, bars + [landing],
                 score.sounds, loop=False, tail=tail, last_bar_beats=landing_beats)


def new_mission(score: Score) -> Piece:
    """The motif with its groove, landing on the tonic (lead, pad, bass and a crash)."""
    opening = motif_bar(score).copy()
    opening.hits = drums(kick="1 2.5 3", snare="2 4", hihat="8", crash="1") + notation.drum_run("S S S S", 0.25, start=4)
    opening.parts["brass"] = comp(opening, (1.0,), length=1.5, lowest=50, velocity=0.8)
    tonic = tonic_chord(score, 62, landing=True)
    landing = Bar(0, opening.chords, {
        "lead": [Note(1.0, (tonic[0],), 2.0)],
        "pad": [Note(1.0, tonic_chord(score, 50, landing=True) + (tonic[0],), 2.0, 0.85)],
        "bas": [Note(1.0, (tonic[0] - 24,), 2.0)],
        "arp": [Note(1.0, (tonic[2] + 12,), 1.0, 0.8)],
    }, drums(kick="1", crash="1"))
    return Piece("deuntje_nieuwe_missie", score.tempo, score.beats_per_bar, [opening, landing],
                 score.sounds, loop=False, tail=1.4, last_bar_beats=1.0)


def task_done(score: Score) -> Piece:
    """A run of sixteenths up the dominant seventh (as the intro's break), landing on the tonic."""
    dominant = dominant_seventh(score, 57)
    figure = list(dominant) + [pitch + 12 for pitch in dominant]
    tonic = tonic_chord(score, 62, landing=True)
    parts = {
        "arp": [Note(1.0 + step * 0.25, (pitch,), 0.25, 0.9) for step, pitch in enumerate(figure)],
        "lead": [Note(3.0, (tonic[0] + 12,), 1.0)],
        "pad": [Note(3.0, tonic_chord(score, 50, landing=True) + (tonic[0],), 1.0, 0.8)],
        "bas": [Note(3.0, (tonic[0] - 24,), 1.0)],
    }
    hits = drums(hihat="1 1.5 2 2.5", velocity=0.7) + drums(kick="3", crash="3")
    return Piece("deuntje_taak_klaar", score.tempo, score.beats_per_bar, [Bar(0, [], parts, hits)],
                 score.sounds, loop=False, tail=1.0, last_bar_beats=3.5)


def mission_done(score: Score) -> Piece:
    """The finish of the composition: its last two bars. A composition without an ending
    (has_ending) gives its last bar as a run-up, landing on the tonic chord with a crash."""
    if has_ending(score):
        return Piece("deuntje_gewonnen", score.tempo, score.beats_per_bar, [bar.copy() for bar in score.bars[-2:]],
                     score.sounds, loop=False, tail=1.5)
    run_up = score.bars[-1].copy()
    return Piece("deuntje_gewonnen", score.tempo, score.beats_per_bar, [run_up, landing_bar(score, run_up.chords, 2.0)],
                 score.sounds, loop=False, tail=1.5, last_bar_beats=2.0)


def level_up(score: Score) -> Piece:
    """Up the tonic chord in sixteenths to the high tonic, held with the guitar and a crash."""
    tonic = tonic_chord(score, 62, landing=True)
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


def reward(score: Score) -> Piece:
    """Short and bright: the tonic chord up and back in sixteenths (a sparkle), the high tonic
    rung out over it with the pad, a soft crash; shorter than a task done."""
    tonic = tonic_chord(score, 62, landing=True)
    up = [tonic[0], tonic[1], tonic[2], tonic[0] + 12]
    figure = up + [tonic[2], tonic[0] + 12]
    high = tonic[0] + 24 if tonic[0] + 24 <= 88 else tonic[0] + 12
    parts = {
        "arp": [Note(1.0 + step * 0.25, (pitch,), 0.25, 0.85) for step, pitch in enumerate(figure)],
        "lead": [Note(2.5, (high,), 1.5, 0.9)],
        "pad": [Note(2.5, tonic_chord(score, 50, landing=True), 1.5, 0.7)],
        "bas": [Note(2.5, (tonic[0] - 24,), 1.5, 0.8)],
    }
    hits = drums(hihat="1 1.5 2", velocity=0.5) + drums(kick="2.5", crash="2.5", velocity=0.6)
    return Piece("deuntje_beloning", score.tempo, score.beats_per_bar, [Bar(0, [], parts, hits)],
                 score.sounds, loop=False, tail=1.0, last_bar_beats=3.5)


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


# ----------------------------------------------------------------------------- the supermarkets

## The muzak of the supermarkets (scripts/world/interiors/interiors.gd SUPERMARKET_MUZAK: each branch
## plays one of the three, soft, under the sound of the shop). Easy listening made from the
## composition's own melodies and chords: the chords sweetened (a power chord or a triad gets
## the third of the key and a seventh: muzak harmony), the melody smoothed (only the notes on
## the beat grid, each held to the next), at a tempo of its own, in soft sounds (flute,
## vibraphone, strings, electric piano). Bars with more than two chords (the chromatic
## climbs) stay out.
MUZAK_TEMPOS = {"bossa": 100.0, "ballade": 76.0, "swing": 112.0}
## The seventh chord each degree of the key gets (semitones above the tonic -> quality).
MUZAK_QUALITIES_MINOR = {0: "m7", 1: "maj7", 2: "m7b5", 3: "maj7", 5: "m7", 7: "7", 8: "maj7", 10: "6"}
MUZAK_QUALITIES_MAJOR = {0: "maj7", 2: "m7", 4: "m7", 5: "maj7", 7: "7", 9: "m7", 11: "m7b5"}
MUZAK_SOUNDS = {"fluit": "fm_fluit", "vibrafoon": "fm_vibrafoon", "strijkers": "fm_strijkers",
                "piano": "fm_piano", "klok": "fm_klok", "bas": "fm_subbas", "drumstel": "standaard"}


def chord_root(name: str) -> str:
    return name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]


def sweetened(name: str, score: Score) -> str:
    """The chord as muzak plays it: a power chord or a plain triad gets the third of the key
    and a seventh (MUZAK_QUALITIES_*); a chord that already says more stays as it is."""
    root = chord_root(name)
    quality = name[len(root):]
    if quality not in ("", "5", "m"):
        return name
    degree = (notation.pitch(root + "0") - score.tonic()) % 12
    qualities = MUZAK_QUALITIES_MINOR if score.is_minor() else MUZAK_QUALITIES_MAJOR
    return root + qualities.get(degree, quality if quality != "5" else "")


def sweet_bar(bar: Bar, score: Score) -> Bar:
    result = bar.copy()
    result.chords = [(sweetened(name, score), start, length) for name, start, length in bar.chords]
    return result


def plain_bars(bars: list) -> list:
    """The bars with one or two chords (the chromatic climbs left out)."""
    return [bar for bar in bars if len(bar.chords) <= 2]


def smooth_melody(bar: Bar, grid: float = 0.5, semitones: int = -12, velocity: float = 0.8,
                  longest: float = 2.0, beats: int = 4) -> list:
    """The bar's melody (lead) with only its notes on the grid, each held to the next one."""
    kept = [note for note in bar.parts.get("lead", [])
            if abs((note.position - 1.0) / grid - round((note.position - 1.0) / grid)) < 1e-6]
    result = []
    for index, note in enumerate(kept):
        next_start = kept[index + 1].position if index + 1 < len(kept) else beats + 1.0
        length = min(longest, max(note.length, next_start - note.position))
        result.append(Note(note.position, tuple(pitch + semitones for pitch in note.pitches), length,
                           velocity * note.velocity))
    return result


def bossa_bass(bar: Bar, velocity: float = 0.8) -> list:
    """Root (dotted quarter), fifth, fifth (dotted quarter), root: the bossa nova bass."""
    result = []
    for root, start, length in roots(bar):
        result.append(Note(start, (root,), 1.5, velocity))
        result.append(Note(start + 1.5, (root + 7,), 0.5, velocity * 0.8))
        if length >= 4:
            result.append(Note(start + 2.0, (root + 7,), 1.5, velocity * 0.9))
            result.append(Note(start + 3.5, (root,), 0.5, velocity * 0.8))
    return result


def broken_chords(bar: Bar, lowest: int = 55, velocity: float = 0.45) -> list:
    """The chords broken in eighths, up and down (a gentle piano)."""
    result = []
    for name, start, length in bar.chords:
        voicing = list(notation.chord_voicing(name, lowest)[:4])
        figure = voicing + voicing[-2:0:-1]
        for step in range(int(length / 0.5)):
            result.append(Note(start + step * 0.5, (figure[step % len(figure)],), 0.5, velocity))
    return result


def strings_pad(bar: Bar, velocity: float = 0.6) -> list:
    return pad_from_chords(bar, lowest=52, velocity=velocity)


def muzak_bar(bar: Bar, score: Score, style: str, melody_part: str = "", grid: float = 0.5,
              semitones: int = -12) -> Bar:
    """One bar of muzak in `style` (bossa, ballade, swing), its melody on `melody_part` (or none)."""
    sweet = sweet_bar(bar, score)
    result = Bar(bar.number, sweet.chords, {}, [], bar.section, bar.kind)
    if melody_part:
        result.parts[melody_part] = smooth_melody(bar, grid, semitones)
    if style == "bossa":
        result.parts["vibrafoon" if melody_part != "vibrafoon" else "piano"] = comp(
            sweet, (1.0, 2.5, 4.0), length=0.75, lowest=57, velocity=0.4)
        result.parts["bas"] = bossa_bass(sweet)
        result.parts["strijkers"] = strings_pad(sweet, 0.45)
        result.hits = (drums(hihat="8", velocity=0.3) + drums(kick="1 2.5 3 4.5", velocity=0.4)
                       + drums(tom_hoog="1 2.5 4", velocity=0.18))
    elif style == "ballade":
        result.parts["piano"] = broken_chords(sweet)
        result.parts["bas"] = long_bass(sweet, 0.75)
        result.parts["strijkers"] = strings_pad(sweet, 0.6)
        result.hits = drums(kick="1", clap="3", velocity=0.3) + drums(hihat="8", velocity=0.2)
    else:   # swing
        result.parts["vibrafoon" if melody_part != "vibrafoon" else "piano"] = comp(
            sweet, (2.0, 4.0), length=0.5, lowest=57, velocity=0.4)
        result.parts["bas"] = walking_bass(sweet, 0.75)
        result.hits = drums(kick="1 3", clap="2 4", velocity=0.3) + drums(hihat="8", velocity=0.3)
    return result


def _muzak_piece(name: str, score: Score, style: str, bars: list) -> Piece:
    return Piece(name, MUZAK_TEMPOS[style], score.beats_per_bar, bars, dict(score.sounds, **MUZAK_SOUNDS),
                 part_gains={"drums": 0.55, "strijkers": 0.9, "bas": 0.9},
                 swing=0.6 if style == "swing" else 0.0)


def supermarket_muzak_bossa(score: Score) -> Piece:
    """Muzak 1, a bossa nova: the theme's chords alone (four bars), the theme on the flute,
    the theme on the vibraphone, the chorus on the flute."""
    theme = plain_bars(score.first_section("thema"))
    chorus = plain_bars(score.first_section("refrein", "thema"))
    bars = [muzak_bar(bar, score, "bossa") for bar in theme[:4]]
    bars += [muzak_bar(bar, score, "bossa", "fluit") for bar in theme]
    bars += [muzak_bar(bar, score, "bossa", "vibrafoon") for bar in theme]
    bars += [muzak_bar(bar, score, "bossa", "fluit") for bar in chorus]
    return _muzak_piece("supermarkt_muzak_1", score, "bossa", bars)


def supermarket_muzak_ballad(score: Score) -> Piece:
    """Muzak 2, a slow ballad: the breakdown's chords (strings, broken piano), the chorus on
    the vibraphone, the theme on the flute."""
    breakdown = plain_bars(score.first_section("breakdown", "opbouw", "thema"))
    chorus = plain_bars(score.first_section("refrein", "thema"))
    theme = plain_bars(score.first_section("thema"))
    opening = (breakdown * 2)[:4]
    bars = [muzak_bar(bar, score, "ballade") for bar in opening]
    bars += [muzak_bar(bar, score, "ballade", "vibrafoon") for bar in chorus]
    bars += [muzak_bar(bar, score, "ballade", "fluit") for bar in theme]
    return _muzak_piece("supermarkt_muzak_2", score, "ballade", bars)


def supermarket_muzak_swing(score: Score) -> Piece:
    """Muzak 3, a cheerful light swing: the theme on the electric piano, the chorus on the
    bells, the theme on the vibraphone, the chorus on the piano; a walking bass."""
    theme = plain_bars(score.first_section("thema"))
    chorus = plain_bars(score.first_section("refrein", "thema"))
    bars = [muzak_bar(bar, score, "swing", "piano") for bar in theme]
    bars += [muzak_bar(bar, score, "swing", "klok") for bar in chorus]
    bars += [muzak_bar(bar, score, "swing", "vibrafoon") for bar in theme]
    bars += [muzak_bar(bar, score, "swing", "piano") for bar in chorus]
    return _muzak_piece("supermarkt_muzak_3", score, "swing", bars)


def _chain_jingle(name: str, score: Score, opening: Bar, melody_sound: str, chord_sound: str,
                  tempo: float, drum_hits: list) -> Piece:
    """A chain's jingle (its sound logo before an announcement): the first half of `opening`'s
    melody, landing on beat 3 on the high tonic over the tonic chord in major (a shop is happy)."""
    tonic = score.tonic()
    melody = [note for note in opening.parts.get("lead", []) if note.position < 3.0 - 1e-6]
    melody = [Note(note.position, note.pitches, min(note.length, 3.0 - note.position), 0.9) for note in melody]
    landing_root = 64 + (tonic - 64) % 12          # the tonic from E4 up
    major = (landing_root - 12, landing_root - 8, landing_root - 5, landing_root - 1)   # maj7 under it
    parts = {
        "melodie": melody + [Note(3.0, (landing_root + 12,), 2.0)],
        "akkoord": [Note(3.0, major, 2.0, 0.8)],
        "bas": [Note(1.0, (landing_root - 24,), 2.0, 0.8), Note(3.0, (landing_root - 24,), 2.0, 0.9)],
    }
    sounds = dict(score.sounds, melodie=melody_sound, akkoord=chord_sound, bas="fm_subbas", drumstel="standaard")
    return Piece(name, tempo, score.beats_per_bar, [Bar(0, [], parts, drum_hits)], sounds, loop=False,
                 tail=1.6, last_bar_beats=4.0, part_gains={"drums": 0.6})


def jingle_derrek(score: Score) -> Piece:
    """DERREK (cheap and cheerful, red): the motif bright on the PSG, brass on the landing."""
    hits = drums(hihat="1 1.5 2 2.5", velocity=0.5) + drums(kick="1 3", velocity=0.7) + drums(crash="3", velocity=0.5)
    return _chain_jingle("jingle_derrek", score, motif_bar(score), "psg_lead_fel", "synth_brass", 132.0, hits)


def jingle_alfred_steyhn(score: Score) -> Piece:
    """ALFRED STEYHN (the chic one, blue): the chorus's opening on the bells, strings under the
    landing, no drums but a soft cymbal."""
    chorus = plain_bars(score.first_section("refrein", "thema"))
    opening = next((bar for bar in chorus if bar.parts.get("lead")), motif_bar(score))
    return _chain_jingle("jingle_alfred_steyhn", score, opening, "fm_klok", "fm_strijkers", 100.0,
                         drums(crash="3", velocity=0.3))


ALL = (intro, menu_loop, character_loop, merchant_loop, loading_loop, game_loop,
       map_start, new_mission, task_done, mission_done, level_up, reward, death,
       supermarket_muzak_bossa, supermarket_muzak_ballad, supermarket_muzak_swing,
       jingle_derrek, jingle_alfred_steyhn)


def in_own_voices(piece: Piece, score: Score) -> Piece:
    """The piece with the sounds and the drum kit of AFGELEIDE_KLANKEN in place of the usual
    ones (a composition read from a VGM: everything in the voices of that VGM)."""
    if not score.derived_sounds:
        return piece
    parts = {part for bar in piece.bars for part in bar.parts}
    sounds = dict(piece.sounds)
    for part in parts:
        usual = piece.sound_of(part)
        sounds[part] = score.derived_sounds.get(usual, usual)
    usual_kit = piece.sounds.get("drumstel", "standaard")
    sounds["drumstel"] = score.derived_sounds.get(usual_kit, usual_kit)
    return replace(piece, sounds=sounds)


def pieces(score: Score) -> list:
    """Every piece: the intro from the score as written, the others from the score for the
    derived pieces (AFGELEID_OCTAAF), in the composition's own voices (AFGELEIDE_KLANKEN)."""
    derived = score.for_derived()
    return [in_own_voices(make(score if make is intro else derived), score) for make in ALL]
