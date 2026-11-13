"""A composition file read into bars: the score every piece is rendered from.

A composition file (tools/muziek/composities/<naam>.py, see docs/MUZIEK.md) holds, in Dutch:

    TITEL, TEMPO (BPM), TELLEN_PER_MAAT (4), TOONSOORT ("D", "mineur")
    KLANKEN    {part: sound}: which sound of instruments.SOUNDS plays each part
    MOMENTEN   {moment: bar}: where the intro's pictures change (logo, verhaal, hoogtepunt,
               duel, crash), as the bar they start on
    SECTIES    [{"naam", "soort", "maten": (first, last), "standaard": {part: ...}}]
               soort: intro, thema, opbouw, refrein, breakdown, finale (what the derived
               pieces look for); standaard: parts every bar of the section has unless the
               bar says otherwise (a bar's own [] is silence)
    MATEN      {bar number: {"akkoord": "Dm", part: [Note], "drums": [Hit]}}
    BIJSTELLING   (optional) a tuning laid over the literal bars when the music is made, on
               request of the user (the bars themselves stay as the composer wrote them):
               "tempo": BPM; "octaaf": {part: octaves}; "majeur_slot": True (the last chord,
               and the landing of the jingles, in major); for lists of section kinds:
               "kick_op_elke_tel" (four on the floor), "open_hihat" (on the off-beats),
               "handklap" (a clap with the snare on 2 and 4), "stoten" ({"secties": (...),
               "klank": sound}: short chord stabs on the off-beats, spelled from the chords)

    AFGELEID_OCTAAF   (optional) {part: octaves}: the part that many octaves higher (+) or
               lower (-) in the derived pieces only (not in the intro)
    AFGELEIDE_KLANKEN (optional) {sound or drum kit: sound or drum kit}: in every derived piece
               the first is replaced by the second (the voices of the source: "tracker_<voice>=<sound>")

Parts are free names (bas, pad, brass, lead, arp, gitaar, ...); each one is played by the sound
KLANKEN gives it. "drums" is always the drum kit.
"""
import copy
import importlib
import os
import sys
from dataclasses import dataclass, field

import notation

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
COMPOSITIONS_FOLDER = os.path.join(HERE, "composities")
SECTION_KINDS = ("intro", "thema", "opbouw", "refrein", "breakdown", "finale")


@dataclass
class Bar:
    number: int                       # in the composition (1 = the first)
    chords: list                      # [(name, position, length)]
    parts: dict                       # part -> [Note]
    hits: list                        # [Hit]
    section: str = ""
    kind: str = ""

    def copy(self) -> "Bar":
        return copy.deepcopy(self)

    def chord_at(self, position: float) -> str:
        current = self.chords[0][0] if self.chords else "C"
        for name, start, _length in self.chords:
            if start <= position + 1e-6:
                current = name
        return current


@dataclass
class Score:
    title: str
    tempo: float
    beats_per_bar: int
    key: tuple                        # (tonic, "mineur"/"majeur")
    sounds: dict                      # part -> sound name
    bars: list                        # [Bar]
    sections: list = field(default_factory=list)
    moments: dict = field(default_factory=dict)
    major_ending: bool = False        # BIJSTELLING majeur_slot: endings and landings in major
    tracker: str = ""                 # TRACKER: the tracker page or JSON the intro is played from (tracker.py)
    derived_octaves: dict = field(default_factory=dict)   # AFGELEID_OCTAAF
    derived_sounds: dict = field(default_factory=dict)    # AFGELEIDE_KLANKEN

    def for_derived(self) -> "Score":
        """The score the derived pieces are made from: the parts of AFGELEID_OCTAAF moved."""
        if not self.derived_octaves:
            return self
        moved = copy.copy(self)
        moved.bars = [bar.copy() for bar in self.bars]
        for part, octaves in self.derived_octaves.items():
            for bar in moved.bars:
                if part in bar.parts:
                    bar.parts[part] = [note.transposed(12 * octaves) for note in bar.parts[part]]
        return moved

    @property
    def bar_seconds(self) -> float:
        return 60.0 / self.tempo * self.beats_per_bar

    def section(self, kind: str) -> list:
        """The bars of the first section of `kind` (empty when there is none)."""
        for section in self.sections:
            if section["soort"] == kind:
                first, last = section["maten"]
                return [bar for bar in self.bars if first <= bar.number <= last]
        return []

    def first_section(self, *kinds: str) -> list:
        for kind in kinds:
            bars = self.section(kind)
            if bars:
                return bars
        return self.bars

    def tonic(self) -> int:
        """The key's tonic as a note class (0 = C)."""
        return notation.pitch(self.key[0] + "0") % 12

    def is_minor(self) -> bool:
        return self.key[1].startswith("min") or self.key[1].startswith("mol")


def active_name() -> str:
    """The composition the music is made from: ZWERVR_COMPOSITIE, else ACTIEF in composities/."""
    name = os.environ.get("ZWERVR_COMPOSITIE")
    if name:
        return name
    sys.path.insert(0, COMPOSITIONS_FOLDER)
    import actief
    return actief.ACTIEF


def menu_name() -> str:
    """The second composition: the menu as written, and the pieces made from it (derive.SECONDARY_PIECES):
    ZWERVR_MENU_COMPOSITIE, else MENU in composities/actief.py (the first when it has none)."""
    name = os.environ.get("ZWERVR_MENU_COMPOSITIE")
    if name:
        return name
    sys.path.insert(0, COMPOSITIONS_FOLDER)
    import actief
    return getattr(actief, "MENU", "") or active_name()


def fight_name() -> str:
    """The third composition, of the fight scene (derive.fight_loop): ZWERVR_GEVECHT_COMPOSITIE,
    else GEVECHT in composities/actief.py; empty when there is none."""
    name = os.environ.get("ZWERVR_GEVECHT_COMPOSITIE")
    if name:
        return name
    sys.path.insert(0, COMPOSITIONS_FOLDER)
    import actief
    return getattr(actief, "GEVECHT", "")


def load(name: str = None) -> Score:
    name = name or active_name()
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    if COMPOSITIONS_FOLDER not in sys.path:
        sys.path.insert(0, COMPOSITIONS_FOLDER)
    module = importlib.import_module(name)
    beats_per_bar = getattr(module, "TELLEN_PER_MAAT", 4)
    sections = list(module.SECTIES)
    for section in sections:
        if section["soort"] not in SECTION_KINDS:
            raise ValueError(f"{name}: section {section['naam']!r} has unknown soort {section['soort']!r}")
    last_bar = max(section["maten"][1] for section in sections)
    bars = []
    chords_so_far = [("C", 1.0, float(beats_per_bar))]
    for number in range(1, last_bar + 1):
        section = next((section for section in sections
                        if section["maten"][0] <= number <= section["maten"][1]), None)
        written = dict(section.get("standaard", {})) if section else {}
        written.update(module.MATEN.get(number, {}))
        chord_text = written.pop("akkoord", None)
        chords = notation.bar_chords(chord_text, beats_per_bar) if chord_text else chords_so_far
        chords_so_far = chords
        hits = list(written.pop("drums", []))
        parts = {part: list(part_notes) for part, part_notes in written.items()}
        for part in parts:
            if part not in module.KLANKEN:
                raise ValueError(f"{name}: bar {number} has part {part!r} without a sound in KLANKEN")
        bars.append(Bar(number, chords, parts, hits, section["naam"] if section else "",
                        section["soort"] if section else ""))
    score = Score(module.TITEL, float(module.TEMPO), beats_per_bar, tuple(module.TOONSOORT),
                  dict(module.KLANKEN), bars, sections, dict(getattr(module, "MOMENTEN", {})))
    score.tracker = getattr(module, "TRACKER", "")
    score.derived_octaves = dict(getattr(module, "AFGELEID_OCTAAF", {}))
    score.derived_sounds = dict(getattr(module, "AFGELEIDE_KLANKEN", {}))
    tune(score, getattr(module, "BIJSTELLING", {}))
    return score


# ----------------------------------------------------------------------------- BIJSTELLING

def _on_beat(position: float) -> bool:
    return abs(position - round(position)) < 1e-6


def tune(score: Score, tuning: dict) -> None:
    """Lays the BIJSTELLING over the bars (see the module docstring)."""
    if not tuning:
        return
    score.tempo = float(tuning.get("tempo", score.tempo))
    if "drumstel" in tuning:
        score.sounds["drumstel"] = tuning["drumstel"]   # another drum kit (instruments.DRUM_KITS)
    for part, sound in tuning.get("klank", {}).items():
        score.sounds[part] = sound   # the same notes in another sound
    for part, sound in tuning.get("verdubbel", {}).items():
        # the same notes also in a second sound (a part of its own: "<part>_dubbel")
        double = part + "_dubbel"
        score.sounds[double] = sound
        for bar in score.bars:
            if part in bar.parts:
                bar.parts[double] = list(bar.parts[part])
    for part, octaves in tuning.get("octaaf", {}).items():
        for bar in score.bars:
            if part in bar.parts:
                bar.parts[part] = [note.transposed(12 * octaves) for note in bar.parts[part]]
    beats = score.beats_per_bar
    # the last bar is the song's ending (its final hits): the groove stays out of it
    for bar in score.bars[:-1]:
        drum_positions = {(hit.drum, round(hit.position, 4)) for hit in bar.hits}
        kicks = {position for drum, position in drum_positions if drum == "kick"}
        snares = {position for drum, position in drum_positions if drum == "snare"}
        # a break (kick and snare hitting together, all of them: an unison figure) is no groove
        is_break = bool(kicks) and kicks == snares
        has_groove = bool(kicks) and any(_on_beat(position) for position in snares) and not is_break
        is_fill_bar = sum(1 for drum, _ in drum_positions if drum.startswith("tom")) > 0
        if bar.kind in tuning.get("kick_op_elke_tel", ()) and has_groove:
            fill_from = min((hit.position for hit in bar.hits if hit.drum.startswith("tom")), default=beats + 1.0)
            kept = [hit for hit in bar.hits if hit.drum != "kick" or hit.position >= fill_from]
            bar.hits = kept + [notation.Hit(float(beat), "kick") for beat in range(1, beats + 1) if beat < fill_from]
        if bar.kind in tuning.get("open_hihat", ()) and has_groove:
            offbeats = [beat + 0.5 for beat in range(1, beats + 1)]
            fill_from = min((hit.position for hit in bar.hits if hit.drum.startswith("tom")), default=beats + 1.0)
            bar.hits = [hit for hit in bar.hits if not (hit.drum == "hihat" and round(hit.position, 4) in offbeats)]
            bar.hits += [notation.Hit(position, "open", 0.9) for position in offbeats
                         if position < fill_from and ("open", position) not in drum_positions]
        if bar.kind in tuning.get("handklap", ()) and not is_fill_bar:
            bar.hits += [notation.Hit(hit.position, "clap", 0.9) for hit in list(bar.hits)
                         if hit.drum == "snare" and _on_beat(hit.position) and int(round(hit.position)) % 2 == 0]
    stabs = tuning.get("stoten")
    if stabs:
        part = "stoot"
        score.sounds[part] = stabs["klank"]
        for bar in score.bars:
            if bar.kind not in stabs["secties"]:
                continue
            positions = [beat + 0.5 for beat in range(1, beats + 1)]
            bar.parts[part] = [notation.Note(position, notation.chord_voicing(bar.chord_at(position), 60)[:3], 0.25, 0.8)
                               for position in positions]
    if tuning.get("majeur_slot") and score.is_minor():
        score.major_ending = True
        _major_last_chord(score)


def _major_last_chord(score: Score) -> None:
    """The last bar's tonic notes get the major third with them (in the chord parts: pad,
    brass, stabs), so the song ends bright (the Picardy third)."""
    tonic = score.tonic()
    last = score.bars[-1]
    for part in ("pad", "brass", "stoot"):
        notes_with_third = []
        for note in last.parts.get(part, []):
            tonics = [pitch for pitch in note.pitches if pitch % 12 == tonic]
            if tonics and not any((pitch - tonic) % 12 in (3, 4) for pitch in note.pitches):
                third = min(tonics) + 4
                note = notation.Note(note.position, tuple(sorted(note.pitches + (third,))), note.length, note.velocity)
            notes_with_third.append(note)
        if part in last.parts:
            last.parts[part] = notes_with_third
