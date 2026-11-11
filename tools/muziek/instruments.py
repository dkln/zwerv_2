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
GUITAR_STRING = FmPatch("gitaar_snaar", algorithm=4, feedback=1.4, operators=(
    Operator(ratio=1.0, level=1.6, attack=0.001, decay=0.4, sustain=0.7, release=0.06),
    Operator(ratio=1.0, level=1.0, attack=0.001, decay=0.8, sustain=0.85, release=0.06),
    Operator(ratio=3.0, level=0.7, attack=0.001, decay=0.05, sustain=0.2, release=0.05),
    Operator(ratio=1.0, detune_cents=8, level=0.5, attack=0.001, decay=0.8, sustain=0.85, release=0.06),
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
    Sound("fm_slapbas", "fm", SLAP_BASS, pan=0.0, gain=0.52),
    Sound("fm_subbas", "fm", SUB_BASS, pan=0.0, gain=0.42),
    Sound("synthwave_pad", "fm", SAW_PAD, pan=0.0, gain=0.21, width=14.0),
    Sound("synth_brass", "fm", SYNTH_BRASS, pan=0.0, gain=0.18, width=9.0),
    Sound("fm_lead_helder", "fm", BRIGHT_LEAD, pan=-0.12, gain=0.75, echo=0.75, echo_level=0.32, echo_repeats=2),
    Sound("psg_arp", "psg", pan=0.3, gain=0.22, psg_decay=0.06, psg_sustain=0.3, psg_release=0.03),
    Sound("psg_lead", "psg", pan=-0.2, gain=0.24, psg_decay=0.3, psg_sustain=0.7, psg_release=0.06, psg_vibrato=0.18,
          echo=0.75, echo_level=0.28),
    Sound("overdrive_gitaar", "gitaar", GUITAR_STRING, pan=0.35, gain=0.37, drive=7.0),
    Sound("overdrive_gitaar_solo", "gitaar", GUITAR_STRING, pan=0.4, gain=0.34, drive=9.0, echo=0.75, echo_level=0.2,
          echo_repeats=1),
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


DRUMS = _drum_kit()
