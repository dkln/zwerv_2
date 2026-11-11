"""The sounds the parts of a composition are played with, all on the Mega Drive chip of
tools/megadrive/megadrive.py: YM2612 FM voices, SN76489 PSG squares and noise, PCM drums
through the 8-bit DAC. A composition names them in KLANKEN ({part: sound}); a composer's
instrument without a sound here gets a new one (docs/MUZIEK.md: "Een nieuwe klank").

Every sound renders one Note (one pitch, or several struck together) to a mono buffer, and
says where it sits in the mix: `pan`, `gain`, `width` (two copies detuned by that many cents,
panned apart: the broad synthwave pads) and `echo` (a delay in beats, e.g. 0.75 the dotted
eighth, with its level and repeats, on the other side of the stereo picture).
"""
import os
import sys
from dataclasses import dataclass
from functools import lru_cache

import numpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "megadrive"))
import megadrive  # noqa: E402
from megadrive import FmPatch, Operator  # noqa: E402

SAMPLE_RATE = megadrive.SAMPLE_RATE


@dataclass(frozen=True)
class Sound:
    name: str
    kind: str                     # "fm", "psg", "gitaar"
    patch: FmPatch = None
    pan: float = 0.0
    gain: float = 1.0
    width: float = 0.0            # cents between the two copies (0: one copy at `pan`)
    echo: float = 0.0             # beats (0: no echo)
    echo_level: float = 0.3
    echo_repeats: int = 2
    psg_decay: float = 0.1
    psg_sustain: float = 0.4
    psg_release: float = 0.04
    psg_vibrato: float = 0.0
    drive: float = 6.0            # gitaar: how hard it is driven
    octave: int = 0               # played that many octaves up (+) or down (-)

    def render(self, pitches: tuple, seconds: float, velocity: float, detune_cents: float = 0.0) -> numpy.ndarray:
        seconds = round(seconds, 4)
        velocity = round(velocity, 3)
        shifted = tuple(float(pitch) + 12 * self.octave + detune_cents / 100.0 for pitch in pitches)
        if self.kind == "fm":
            return megadrive.fm_chord(self.patch, shifted, seconds, velocity)
        if self.kind == "psg":
            voices = [megadrive.psg_square(pitch, seconds, velocity, self.psg_decay, self.psg_sustain,
                                           self.psg_release, self.psg_vibrato) for pitch in shifted]
            return _sum(voices)
        if self.kind == "gitaar":
            return _guitar(self.patch, shifted, seconds, velocity, self.drive)
        raise ValueError(self.kind)


def _sum(voices: list) -> numpy.ndarray:
    longest = max(len(voice) for voice in voices)
    result = numpy.zeros(longest)
    for voice in voices:
        result[:len(voice)] += voice
    return result


def _one_pole_low_pass(signal: numpy.ndarray, cutoff_hz: float) -> numpy.ndarray:
    coefficient = numpy.exp(-2.0 * numpy.pi * cutoff_hz / SAMPLE_RATE)
    # y[n] = (1 - c) x[n] + c y[n-1], as a filter over the spectrum of the zero-padded note
    padded = numpy.concatenate([signal, numpy.zeros(2048)])
    frequencies = numpy.fft.rfftfreq(len(padded), 1.0 / SAMPLE_RATE)
    inverse_z = numpy.exp(-2j * numpy.pi * frequencies / SAMPLE_RATE)
    response = (1.0 - coefficient) / (1.0 - coefficient * inverse_z)
    return numpy.fft.irfft(numpy.fft.rfft(padded) * response, n=len(padded))[:len(signal)]


@lru_cache(maxsize=None)
def _guitar(patch: FmPatch, pitches: tuple, seconds: float, velocity: float, drive: float) -> numpy.ndarray:
    """The overdriven guitar the Mega Drive composers made: bright FM notes (a powerchord: all
    strings together) driven into the output stage, so the strings distort into each other,
    then the darker "cabinet"."""
    clean = _sum([megadrive.fm_note(patch, pitch, seconds, 1.0) for pitch in pitches]) / max(1, len(pitches)) ** 0.5
    driven = numpy.tanh(drive * clean) / numpy.tanh(drive)
    cabinet = _one_pole_low_pass(_one_pole_low_pass(driven, 4200.0), 5200.0)
    result = numpy.round(cabinet * velocity * 256.0) / 256.0
    result.setflags(write=False)
    return result


# ----------------------------------------------------------------------------- FM patches

SLAP_BASS = FmPatch("fm_slapbas", algorithm=4, feedback=0.7, operators=(
    Operator(ratio=1.0, level=2.4, attack=0.001, decay=0.07, sustain=0.15, release=0.03),
    Operator(ratio=1.0, level=0.9, attack=0.001, decay=0.3, sustain=0.65, release=0.04),
    Operator(ratio=7.0, level=1.4, attack=0.001, decay=0.025, sustain=0.0, release=0.02),
    Operator(ratio=2.0, level=0.35, attack=0.001, decay=0.12, sustain=0.2, release=0.03),
))
SUB_BASS = FmPatch("fm_subbas", algorithm=4, feedback=0.0, operators=(
    Operator(ratio=1.0, level=0.6, attack=0.003, decay=0.4, sustain=0.3, release=0.08),
    Operator(ratio=1.0, level=1.0, attack=0.003, decay=1.5, sustain=0.85, release=0.1),
    Operator(ratio=2.0, level=0.2, attack=0.003, decay=0.1, sustain=0.0, release=0.05),
    Operator(ratio=1.0, level=0.0),
))
SAW_PAD = FmPatch("synthwave_pad", algorithm=7, feedback=1.25, operators=(
    Operator(ratio=1.0, level=0.55, attack=0.18, decay=1.2, sustain=0.85, release=0.45),
    Operator(ratio=2.0, level=0.12, attack=0.25, decay=1.0, sustain=0.8, release=0.45),
    Operator(ratio=1.0, level=0.0),
    Operator(ratio=1.0, level=0.0),
))
SYNTH_BRASS = FmPatch("synth_brass", algorithm=4, feedback=0.9, operators=(
    Operator(ratio=1.0, level=1.7, attack=0.03, decay=0.25, sustain=0.55, release=0.1),
    Operator(ratio=1.0, level=0.8, attack=0.015, decay=0.4, sustain=0.75, release=0.12),
    Operator(ratio=1.0, detune_cents=6, level=1.3, attack=0.04, decay=0.3, sustain=0.5, release=0.1),
    Operator(ratio=1.0, detune_cents=-6, level=0.6, attack=0.015, decay=0.4, sustain=0.75, release=0.12),
))
BRIGHT_LEAD = FmPatch("fm_lead_helder", algorithm=4, feedback=0.95, vibrato_depth=0.16, vibrato_rate=6.0,
                      vibrato_delay=0.22, operators=(
    Operator(ratio=1.0, level=1.35, attack=0.004, decay=0.35, sustain=0.75, release=0.08),
    Operator(ratio=1.0, level=0.75, attack=0.004, decay=0.6, sustain=0.85, release=0.1),
    Operator(ratio=2.0, level=0.95, attack=0.004, decay=0.2, sustain=0.6, release=0.08),
    Operator(ratio=1.0, detune_cents=5, level=0.4, attack=0.004, decay=0.6, sustain=0.85, release=0.1),
))
# a buzzing, nasal FM lead in the spirit of the early-90s Mega Drive arcade leads (Yuzo Koshiro's
# street-beat-'em-up melodies): one pair with heavy feedback (saw-like buzz), one with its
# modulator at 3x (the nasal edge), a hard attack, vibrato that sets in after the attack
SNARL_LEAD = FmPatch("fm_lead_snerpend", algorithm=4, feedback=1.35, vibrato_depth=0.22, vibrato_rate=5.8,
                     vibrato_delay=0.18, operators=(
    Operator(ratio=1.0, level=1.25, attack=0.002, decay=0.5, sustain=0.8, release=0.07),
    Operator(ratio=1.0, level=0.9, attack=0.002, decay=0.7, sustain=0.85, release=0.09),
    Operator(ratio=3.0, level=1.05, attack=0.002, decay=0.15, sustain=0.5, release=0.06),
    Operator(ratio=1.0, detune_cents=7, level=0.55, attack=0.002, decay=0.7, sustain=0.85, release=0.09),
))
# a gritty house/techno bass (the early-90s club bass on the YM2612): a feedback pair whose
# modulator falls away fast (the growl on every note), and a second pair an octave below (the sub)
HOUSE_BASS = FmPatch("fm_housebas", algorithm=4, feedback=1.5, operators=(
    Operator(ratio=1.0, level=1.8, attack=0.001, decay=0.12, sustain=0.3, release=0.03),
    Operator(ratio=1.0, level=1.0, attack=0.001, decay=0.35, sustain=0.7, release=0.04),
    Operator(ratio=2.0, level=1.6, attack=0.001, decay=0.06, sustain=0.15, release=0.03),
    Operator(ratio=0.5, level=0.6, attack=0.001, decay=0.4, sustain=0.75, release=0.04),
))
# metallic, percussive stabs: modulators on inharmonic ratios (3.5x, 7x), short decays
METAL_STAB = FmPatch("fm_stoot_metaal", algorithm=4, feedback=0.6, operators=(
    Operator(ratio=3.5, level=1.6, attack=0.001, decay=0.08, sustain=0.0, release=0.05),
    Operator(ratio=1.0, level=1.0, attack=0.001, decay=0.18, sustain=0.1, release=0.06),
    Operator(ratio=7.0, level=1.0, attack=0.001, decay=0.04, sustain=0.0, release=0.04),
    Operator(ratio=1.0, detune_cents=5, level=0.6, attack=0.001, decay=0.15, sustain=0.05, release=0.06),
))
# a raw, "chemical" acid-like FM lead (early-90s techno): feedback near its top (a raw buzz), a
# strong modulator that falls away fast on every note (the squelch, like a filter closing), a
# second carrier detuned against the first (they grind), hardly any vibrato
ACID_LEAD = FmPatch("fm_lead_zuur", algorithm=4, feedback=1.9, vibrato_depth=0.05, vibrato_rate=6.0,
                    vibrato_delay=0.3, operators=(
    Operator(ratio=1.0, level=2.3, attack=0.001, decay=0.16, sustain=0.45, release=0.05),
    Operator(ratio=1.0, level=0.95, attack=0.001, decay=0.6, sustain=0.85, release=0.07),
    Operator(ratio=2.0, level=2.0, attack=0.001, decay=0.09, sustain=0.25, release=0.04),
    Operator(ratio=1.0, detune_cents=14, level=0.6, attack=0.001, decay=0.6, sustain=0.8, release=0.07),
))
GUITAR_STRING = FmPatch("gitaar_snaar", algorithm=4, feedback=1.4, operators=(
    Operator(ratio=1.0, level=1.6, attack=0.001, decay=0.4, sustain=0.7, release=0.06),
    Operator(ratio=1.0, level=1.0, attack=0.001, decay=0.8, sustain=0.85, release=0.06),
    Operator(ratio=3.0, level=0.7, attack=0.001, decay=0.05, sustain=0.2, release=0.05),
    Operator(ratio=1.0, detune_cents=8, level=0.5, attack=0.001, decay=0.8, sustain=0.85, release=0.06),
))
# a clean guitar string: no drive, a short plectrum click (the high operator, gone in 30 ms) on
# a warm body; the cabinet's low-pass in _guitar acts as its body filter
CLEAN_GUITAR_STRING = FmPatch("gitaar_snaar_clean", algorithm=4, feedback=0.6, operators=(
    Operator(ratio=1.0, level=1.1, attack=0.001, decay=0.3, sustain=0.55, release=0.07),
    Operator(ratio=1.0, level=1.0, attack=0.001, decay=0.9, sustain=0.7, release=0.08),
    Operator(ratio=5.0, level=0.9, attack=0.001, decay=0.03, sustain=0.0, release=0.02),
    Operator(ratio=2.0, detune_cents=6, level=0.35, attack=0.001, decay=0.6, sustain=0.5, release=0.07),
))
BELL = FmPatch("fm_klok", algorithm=4, feedback=0.2, operators=(
    Operator(ratio=3.5, level=1.3, attack=0.001, decay=0.5, sustain=0.0, release=0.4),
    Operator(ratio=1.0, level=0.7, attack=0.001, decay=1.1, sustain=0.0, release=0.6),
    Operator(ratio=1.0, level=0.5, attack=0.001, decay=0.3, sustain=0.0, release=0.3),
    Operator(ratio=2.0, level=0.3, attack=0.001, decay=0.8, sustain=0.0, release=0.5),
))
ELECTRIC_PIANO = FmPatch("fm_piano", algorithm=4, feedback=0.3, operators=(
    Operator(ratio=1.0, level=1.1, attack=0.001, decay=0.35, sustain=0.2, release=0.15),
    Operator(ratio=1.0, level=0.75, attack=0.001, decay=0.9, sustain=0.15, release=0.2),
    Operator(ratio=14.0, level=0.6, attack=0.001, decay=0.015, sustain=0.0, release=0.02),
    Operator(ratio=1.0, level=0.45, attack=0.001, decay=0.6, sustain=0.1, release=0.15),
))

SOUNDS = {sound.name: sound for sound in (
    Sound("fm_slapbas", "fm", SLAP_BASS, pan=0.0, gain=0.75),
    Sound("fm_housebas", "fm", HOUSE_BASS, pan=0.0, gain=0.85),
    # the house bass's FM voice as a melody: its growl on every note, its sub an octave below
    # giving the line a thick bottom, with echo
    Sound("fm_housebas_lead", "fm", HOUSE_BASS, pan=-0.1, gain=0.85, echo=0.75, echo_level=0.3, echo_repeats=3),
    Sound("fm_stoot_metaal", "fm", METAL_STAB, pan=0.0, gain=0.3, width=8.0),
    Sound("fm_subbas", "fm", SUB_BASS, pan=0.0, gain=0.42),
    Sound("synthwave_pad", "fm", SAW_PAD, pan=0.0, gain=0.21, width=14.0),
    Sound("synth_brass", "fm", SYNTH_BRASS, pan=0.0, gain=0.27, width=9.0),
    Sound("fm_lead_helder", "fm", BRIGHT_LEAD, pan=-0.12, gain=0.75, echo=0.75, echo_level=0.32, echo_repeats=2),
    Sound("fm_lead_snerpend", "fm", SNARL_LEAD, pan=-0.1, gain=0.7, echo=0.75, echo_level=0.34, echo_repeats=3),
    # the arpeggio's square (psg_arp: a quick attack, falling right away to a low level) as a
    # melody: loud enough to lead, with echo, no vibrato
    Sound("psg_lead_arp", "psg", pan=-0.1, gain=1.1, psg_decay=0.06, psg_sustain=0.35, psg_release=0.03,
          echo=0.75, echo_level=0.32, echo_repeats=3),
    Sound("fm_lead_zuur", "fm", ACID_LEAD, pan=-0.1, gain=0.6, echo=0.75, echo_level=0.3, echo_repeats=3),
    Sound("psg_arp", "psg", pan=0.3, gain=0.31, psg_decay=0.06, psg_sustain=0.3, psg_release=0.03),
    # the melody as chiptune: a bright SN76489 square, hardly any decay, a quick vibrato, echo
    Sound("psg_lead_fel", "psg", pan=-0.12, gain=0.56, psg_decay=0.12, psg_sustain=0.85, psg_release=0.04,
          psg_vibrato=0.12, echo=0.75, echo_level=0.28, echo_repeats=2),
    Sound("psg_lead", "psg", pan=-0.2, gain=0.24, psg_decay=0.3, psg_sustain=0.7, psg_release=0.06, psg_vibrato=0.18,
          echo=0.75, echo_level=0.28),
    Sound("overdrive_gitaar", "gitaar", GUITAR_STRING, pan=0.35, gain=0.37, drive=7.0),
    Sound("overdrive_gitaar_solo", "gitaar", GUITAR_STRING, pan=0.4, gain=0.34, drive=9.0, echo=0.75, echo_level=0.2,
          echo_repeats=1),
    Sound("clean_gitaar", "gitaar", CLEAN_GUITAR_STRING, pan=0.35, gain=0.63, drive=0.8),
    Sound("clean_gitaar_solo", "gitaar", CLEAN_GUITAR_STRING, pan=0.4, gain=0.6, drive=1.0, echo=0.75,
          echo_level=0.2, echo_repeats=1),
    Sound("fm_klok", "fm", BELL, pan=0.15, gain=0.32, echo=0.75, echo_level=0.35, echo_repeats=3),
    Sound("fm_piano", "fm", ELECTRIC_PIANO, pan=-0.1, gain=0.38, echo=0.75, echo_level=0.2, echo_repeats=1),
)}


# ----------------------------------------------------------------------------- the drum kit

@dataclass(frozen=True)
class Drum:
    samples: numpy.ndarray
    pan: float
    gain: float


def _drum_kit() -> dict:
    return {
        "kick": Drum(megadrive.make_kick(), 0.0, 0.95),
        "snare": Drum(megadrive.make_gated_snare(0.17), 0.05, 0.6),
        "clap": Drum(megadrive.make_clap(), -0.05, 0.45),
        "hihat": Drum(megadrive.psg_noise(0.03, 1.0, 28000.0, 0.018), 0.25, 0.17),
        "open": Drum(megadrive.psg_noise(0.22, 1.0, 28000.0, 0.11), 0.25, 0.14),
        "crash": Drum(megadrive.psg_noise(1.6, 1.0, 36000.0, 0.55), -0.3, 0.2),
        "tom_hoog": Drum(megadrive.make_tom(210.0), 0.35, 0.55),
        "tom_mid": Drum(megadrive.make_tom(165.0), 0.0, 0.55),
        "tom_laag": Drum(megadrive.make_tom(125.0), -0.35, 0.6),
    }


def _dmx_kit() -> dict:
    """The early-90s drum machine kit (DMX-like) as the Mega Drive played it: the raw kick and a
    dry snare through the DAC at a low rate; hats, clap, crash and toms as the standard kit."""
    kit = dict(_drum_kit())
    kit["kick"] = Drum(megadrive.make_raw_kick(), 0.0, 0.95)
    kit["snare"] = Drum(megadrive.make_dry_snare(), 0.05, 0.62)
    return kit


## The drum kits a composition can choose (BIJSTELLING "drumstel"; the mixer reads it from the
## piece's sounds under "drumstel").
DRUM_KITS = {"standaard": _drum_kit(), "dmx": _dmx_kit()}
DRUMS = DRUM_KITS["standaard"]
