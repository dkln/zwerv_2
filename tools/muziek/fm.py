"""What the music tools share about the YM2612 and the sounds (docs/MUZIEK.md): the patch of an
FM channel (FmVoice, played by chip.py), the chip's clock, which sounds are of which kind (the
voices a composition gives its derived pieces: tracker.py) and the moments of the intro from
named sections.
"""
import math
from dataclasses import dataclass

## The YM2612's clock on an NTSC Mega Drive (Hz).
DEFAULT_YM2612_CLOCK = 7670453
## Per algorithm the operators (0-3, operators 1-4) that are carriers (heard), the others modulate.
CARRIERS = ((3,), (3,), (3,), (3,), (1, 3), (1, 2, 3), (1, 2, 3), (0, 1, 2, 3))

## The sounds of instruments.SOUNDS by the kind of voice that takes their place in a composition's
## own voices (tracker.composition_source: AFGELEIDE_KLANKEN).
SOUND_KINDS = {
    "bas": ("fm_slapbas", "fm_housebas", "fm_subbas"),
    "lead": ("fm_lead_helder", "fm_lead_snerpend", "fm_lead_zuur", "fm_housebas_lead", "psg_lead_arp", "psg_lead_fel",
             "psg_lead", "overdrive_gitaar_solo", "clean_gitaar_solo"),
    "zacht": ("psg_arp", "fm_klok", "fm_vibrafoon", "fm_fluit"),
    "akkoord": ("synthwave_pad", "synth_brass", "fm_stoot_metaal", "overdrive_gitaar", "clean_gitaar", "fm_piano",
                "fm_strijkers"),
}
DRUM_KIT_NAMES = ("standaard", "dmx")

## The intro's logo comes no earlier than this (seconds: the opening line stands before it),
## the story a phrase (bars) after it.
LOGO_EARLIEST_SECONDS = 6.0
PHRASE_BARS = 4


@dataclass(frozen=True)
class FmVoice:
    """The patch of an FM channel as the registers hold it (operators 1-4 in order)."""
    algorithm: int
    feedback: int
    multiples: tuple
    total_levels: tuple
    attack_rates: tuple
    decay_rates: tuple
    sustain_levels: tuple
    detunes: tuple = (0, 0, 0, 0)
    rate_scalings: tuple = (0, 0, 0, 0)
    sustain_rates: tuple = (0, 0, 0, 0)
    release_rates: tuple = (15, 15, 15, 15)

    def carriers(self) -> tuple:
        return CARRIERS[self.algorithm]

    def modulators(self) -> tuple:
        return tuple(operator for operator in range(4) if operator not in self.carriers())

    def describe(self) -> str:
        return (f"algoritme {self.algorithm}, feedback {self.feedback}, MUL {'/'.join(map(str, self.multiples))}, "
                f"TL {'/'.join(map(str, self.total_levels))}, AR {'/'.join(map(str, self.attack_rates))}")


def moments_from_sections(sections: list, bar_count: int, bar_seconds: float) -> dict:
    """MOMENTEN from sections that are known by name (a tracker, a JSON composition): the logo
    on the theme, the story a phrase later, the chorus, the breakdown, the finale, the rest on
    the last bar; spread evenly where they do not come in that order."""
    def first_bar(kind: str):
        return next((section["maten"][0] for section in sections if section["soort"] == kind), None)

    earliest = int(math.ceil(LOGO_EARLIEST_SECONDS / bar_seconds)) + 1
    logo = max(first_bar("thema") or 1, earliest)
    wanted = [logo, logo + PHRASE_BARS, first_bar("refrein"), first_bar("breakdown"), first_bar("finale")]
    in_order = all(bar is not None for bar in wanted) and all(
        earlier < later for earlier, later in zip(wanted, wanted[1:])) and wanted[-1] <= bar_count
    if not in_order:
        logo = min(logo, max(1, bar_count - 5))
        wanted = [min(bar_count, logo + int(round(index * (bar_count - logo) / 5.0))) for index in range(5)]
    moments = dict(zip(("logo", "verhaal", "hoogtepunt", "duel", "crash"), wanted))
    moments["rust"] = (bar_count, 1.0)
    return moments


def fm_hz(f_number: int, block: int, clock: float) -> float:
    """The frequency an FM channel plays at F-number and block (the chip's own formula)."""
    return f_number * (clock / 144.0) / 2 ** (21 - block)


def letters(index: int) -> str:
    """0 -> A, 25 -> Z, 26 -> AA: the names of the rows of a composition file."""
    return (letters(index // 26 - 1) if index >= 26 else "") + chr(ord("A") + index % 26)
