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
    return Score(module.TITEL, float(module.TEMPO), beats_per_bar, tuple(module.TOONSOORT),
                 dict(module.KLANKEN), bars, sections, dict(getattr(module, "MOMENTEN", {})))
