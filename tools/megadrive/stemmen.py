"""Voices in Mega Drive style: the short cries of pain when the player is hit.

On the Mega Drive the voices of beat-'em-ups were recorded samples played through the YM2612's
DAC: low sample rates (8 to 13 kHz), 8 bits, recorded hot and clipped, so they sound gritty,
loud and a bit nasal. These are not recordings but made the same way a voice is: a glottal pulse
(the vocal folds) at a falling pitch, through formant resonators (the vowel: "ugh", "ah"), with
breath noise, a growl (period doubling) for the strain, driven into saturation, and at the end
through the "DAC": sample-and-hold at VOICE_RATE and 8 bits, without an anti-alias filter in
between, which gives the crunchy edge, and the console's output filter (OUTPUT_FILTER_HZ).

Every file is mono, Ogg Vorbis, 44.1 kHz, peak -1 dB, in assets/audio/geluiden/:

    pijn_<stem>_1.ogg, pijn_<stem>_2.ogg, pijn_<stem>_3.ogg   short cries ("ugh!", "hngh!", "uah!")
    pijn_<stem>_hard.ogg                                    a long one for a heavy hit ("aaargh")
    lichaam_klap.ogg                                        the thud of a body being hit

and the shouts of the characters (heard when you look at one on the character creation
screen), in assets/audio/kreten/kreet_<character>.ogg: Jos "jie-HAA!" (the rodeo rider),
Martin "hup-hup-HUP!" (the runner), the Ufo Piloot a wavering "oeoeoe-oeh", Willem a hoarse
cackle, Sjaan "hoi!", Gerrit a deep "a-HOI!". They are
made like the cries (`say`: segments of vowels, pitch, voice and breath, through the formants
and the DAC); each character has a speaker of their own (SPEAKERS).

Voices (stem): man, oude_man (lower, rougher, more breath), vrouw.
The game picks the voice of the character ("voice" in scripts/player/player_character.gd).

Render: tools/megadrive/render.sh stemmen  (or some: render.sh stemmen pijn_vrouw_hard)
"""
import os
import sys
import zlib

import numpy

import geluiden
import style
from geluiden import SAMPLE_RATE, TWO_PI, band_noise, dac, fade_edges, low_pass, time_axis

VOICE_RATE = 11025.0
## The analog low-pass after the DAC: keeps the grit of the steps, takes the hard edge off.
OUTPUT_FILTER_HZ = 6000.0

## Per voice: pitch at the start and the end of a cry (Hz), formant scale (shorter vocal tract
## is higher), how much breath, how much growl (period doubling), how much pitch jitter.
VOICES = {
    "man": {"pitch": (210.0, 120.0), "formants": 1.0, "breath": 0.10, "growl": 0.35, "jitter": 0.02},
    "oude_man": {"pitch": (165.0, 95.0), "formants": 0.95, "breath": 0.22, "growl": 0.55, "jitter": 0.05},
    "vrouw": {"pitch": (430.0, 260.0), "formants": 1.17, "breath": 0.14, "growl": 0.2, "jitter": 0.02},
}

## Vowels as formant frequencies and bandwidths (Hz): F1, F2, F3, F4.
VOWELS = {
    "u": ((320.0, 800.0, 2300.0, 3300.0), (60.0, 90.0, 140.0, 200.0)),
    "uh": ((620.0, 1180.0, 2400.0, 3400.0), (80.0, 100.0, 150.0, 220.0)),
    "a": ((780.0, 1250.0, 2550.0, 3500.0), (90.0, 110.0, 160.0, 220.0)),
    "e": ((550.0, 1750.0, 2500.0, 3500.0), (70.0, 100.0, 150.0, 220.0)),
    "ng": ((300.0, 1100.0, 2300.0, 3300.0), (120.0, 200.0, 250.0, 300.0)),
    "i": ((280.0, 2250.0, 2900.0, 3500.0), (60.0, 90.0, 150.0, 200.0)),
    "o": ((450.0, 800.0, 2600.0, 3400.0), (70.0, 90.0, 150.0, 220.0)),
    "oe": ((300.0, 700.0, 2300.0, 3300.0), (60.0, 80.0, 140.0, 200.0)),
}

## The cries: length (s), the vowels it moves through (vowel, from-time share), how the pitch
## falls (exponent of the curve: high is a fast drop), and how loud the start is.
CRIES = {
    1: {"length": 0.30, "vowels": [("uh", 0.0), ("uh", 0.6), ("ng", 1.0)], "drop": 1.6, "onset": "h"},
    2: {"length": 0.26, "vowels": [("ng", 0.0), ("uh", 0.35), ("ng", 1.0)], "drop": 1.0, "onset": "glottal"},
    3: {"length": 0.36, "vowels": [("u", 0.0), ("a", 0.3), ("uh", 1.0)], "drop": 2.2, "onset": "h"},
    "hard": {"length": 0.85, "vowels": [("a", 0.0), ("a", 0.55), ("uh", 0.85), ("ng", 1.0)], "drop": 0.8, "onset": "h"},
}


def curve(points, length: int) -> numpy.ndarray:
    """A value per sample from (share of the length, value) points."""
    shares = numpy.linspace(0.0, 1.0, length)
    return numpy.interp(shares, [share for share, _ in points], [value for _, value in points])


def glottal_pulses(pitch: numpy.ndarray, growl: numpy.ndarray, jitter: float, seed: int) -> numpy.ndarray:
    """The vocal folds: a pulse per period that opens smoothly and shuts hard (the shut is what
    rings the formants), the pitch wobbling a little; with `growl` every other pulse is weaker
    and later, the strained, rattling sound of a cry."""
    random = numpy.random.default_rng(seed)
    wobble = numpy.repeat(random.normal(0.0, jitter, len(pitch) // 200 + 2), 200)[:len(pitch)]
    phase = numpy.cumsum(pitch * (1.0 + low_pass(wobble, 40.0))) / SAMPLE_RATE
    within = phase % 1.0
    open_share = 0.6
    pulse = numpy.where(within < open_share, 0.5 - 0.5 * numpy.cos(numpy.pi * within / open_share), 0.0)
    flow_change = numpy.diff(pulse, prepend=0.0) * SAMPLE_RATE / (pitch + 1.0)
    every_other = (numpy.floor(phase) % 2.0) == 1.0
    return flow_change * numpy.where(every_other, 1.0 - growl, 1.0)


def resonate(source: numpy.ndarray, frequency: numpy.ndarray, bandwidth: numpy.ndarray) -> numpy.ndarray:
    """A two-pole resonator with a gliding centre frequency (one formant), unity gain at 0 Hz."""
    radius = numpy.exp(-numpy.pi * bandwidth / SAMPLE_RATE)
    feedback_1 = 2.0 * radius * numpy.cos(TWO_PI * frequency / SAMPLE_RATE)
    feedback_2 = -radius * radius
    gain = 1.0 - feedback_1 - feedback_2
    output = numpy.zeros(len(source))
    previous_1 = previous_2 = 0.0
    for index in range(len(source)):
        value = gain[index] * source[index] + feedback_1[index] * previous_1 + feedback_2[index] * previous_2
        output[index] = value
        previous_2, previous_1 = previous_1, value
    return output


def vocal_tract(source: numpy.ndarray, vowels, formant_scale: float) -> numpy.ndarray:
    """The source through four formants in a row, gliding from vowel to vowel."""
    output = source
    for formant in range(4):
        frequency = curve([(share, VOWELS[vowel][0][formant] * formant_scale) for vowel, share in vowels], len(source))
        bandwidth = curve([(share, VOWELS[vowel][1][formant]) for vowel, share in vowels], len(source))
        output = resonate(output, frequency, bandwidth)
    return output


def cry(voice_name: str, cry_key) -> numpy.ndarray:
    voice = VOICES[voice_name]
    shape = CRIES[cry_key]
    seed = zlib.crc32(f"{voice_name}/{cry_key}".encode()) % 10000
    length = shape["length"] * (1.1 if voice_name == "oude_man" else 1.0)
    times = time_axis(length)
    sample_count = len(times)
    share = times / length
    start_pitch, end_pitch = voice["pitch"]
    if cry_key == "hard":
        start_pitch *= 1.25   # a scream starts higher
    # pitch: a jump up at the start (the shock), then falling away
    pitch = end_pitch + (start_pitch - end_pitch) * (1.0 - share) ** shape["drop"]
    pitch *= 1.0 + 0.08 * numpy.exp(-times / 0.025)
    if cry_key == "hard":
        pitch *= 1.0 + 0.025 * numpy.sin(TWO_PI * 6.5 * times) * numpy.clip(share * 3.0, 0.0, 1.0)
    growl = numpy.clip(voice["growl"] * (0.6 + 0.8 * share), 0.0, 0.9)
    voiced = glottal_pulses(pitch, growl, voice["jitter"], seed)
    voiced /= numpy.sqrt(numpy.mean(voiced ** 2)) + 1e-9
    # loudness: a hard start, held, then dying away (the breath runs out)
    attack = 0.006 if shape["onset"] == "glottal" else 0.02
    envelope = numpy.clip(times / attack, 0.0, 1.0) * numpy.clip((1.0 - share) / 0.35, 0.0, 1.0) ** 1.5
    breath = band_noise(sample_count, 400.0, 6000.0, seed + 1) * voice["breath"]
    source = voiced * envelope + breath * (0.4 + envelope)
    if shape["onset"] == "h":
        # a breathy "h" before the voice comes in
        onset = numpy.exp(-times / 0.02) * band_noise(sample_count, 800.0, 7000.0, seed + 2) * 0.8
        source += onset
    else:
        # a glottal stop: a click as the folds burst open
        source += numpy.exp(-times / 0.003) * band_noise(sample_count, 200.0, 5000.0, seed + 3) * 1.5
    spoken = vocal_tract(source, shape["vowels"], voice["formants"])
    # the voice from a little above the mouth to the ear: lose some low end, then recorded hot
    spoken = spoken - low_pass(spoken, 180.0)
    spoken /= numpy.abs(spoken).max() + 1e-9
    driven = numpy.tanh(3.2 * spoken)
    # through the DAC, then the console's output filter, which rounds off the steps a bit
    return fade_edges(low_pass(dac(low_pass(driven, 7000.0), VOICE_RATE, 8), OUTPUT_FILTER_HZ), 0.002, 0.04)


def body_hit() -> numpy.ndarray:
    """The thud of a body being hit, beat-'em-up style: a low punch, a slap on top, clipped."""
    times = time_axis(0.22)
    punch_frequency = 70.0 + 140.0 * numpy.exp(-times / 0.015)
    punch = numpy.sin(TWO_PI * numpy.cumsum(punch_frequency) / SAMPLE_RATE) * numpy.exp(-times / 0.06)
    slap = band_noise(len(times), 600.0, 5000.0, 77) * numpy.exp(-times / 0.012)
    cloth = band_noise(len(times), 200.0, 1500.0, 78) * numpy.exp(-times / 0.04) * 0.4
    hit = numpy.tanh(2.8 * (punch + 0.9 * slap + cloth))
    return fade_edges(low_pass(dac(hit, 13000.0, 8), OUTPUT_FILTER_HZ), 0.0005, 0.04)


# ----------------------------------------------------------------------------- shouts


## A shout is a row of segments: (seconds, vowel at the start, vowel at the end, pitch at the
## start, pitch at the end (times the speaker's `pitch`), loudness of the voice, of the breath).
## A "-" vowel is silence (a stop: the "p" of "hup"). The values glide within a segment and
## jump between them, smoothed a little so nothing clicks.
def say(speaker: dict, segments, seed: int) -> numpy.ndarray:
    tracks = {name: [] for name in ("pitch", "voice", "breath", "f1", "f2", "f3", "f4", "b1", "b2", "b3", "b4")}
    last_vowel = "uh"
    for seconds, vowel_from, vowel_to, pitch_from, pitch_to, voice_level, breath_level in segments:
        count = int(round(seconds * SAMPLE_RATE))
        ramp = numpy.linspace(0.0, 1.0, count)
        silent = vowel_from == "-"
        start_vowel = last_vowel if silent else vowel_from
        end_vowel = last_vowel if silent else vowel_to
        for formant in range(4):
            tracks[f"f{formant + 1}"].append(VOWELS[start_vowel][0][formant] + ramp * (VOWELS[end_vowel][0][formant] - VOWELS[start_vowel][0][formant]))
            tracks[f"b{formant + 1}"].append(VOWELS[start_vowel][1][formant] + ramp * (VOWELS[end_vowel][1][formant] - VOWELS[start_vowel][1][formant]))
        tracks["pitch"].append(speaker["pitch"] * (pitch_from + ramp * (pitch_to - pitch_from)))
        tracks["voice"].append(numpy.full(count, 0.0 if silent else voice_level))
        tracks["breath"].append(numpy.full(count, 0.0 if silent else breath_level))
        last_vowel = end_vowel
    track = {name: numpy.concatenate(parts) for name, parts in tracks.items()}
    sample_count = len(track["pitch"])
    voice_level = low_pass(track["voice"], 60.0)
    breath_level = low_pass(track["breath"], 80.0)
    growl = numpy.full(sample_count, speaker.get("growl", 0.2))
    voiced = glottal_pulses(track["pitch"], growl, speaker.get("jitter", 0.02), seed)
    voiced /= numpy.sqrt(numpy.mean(voiced ** 2)) + 1e-9
    breath = band_noise(sample_count, 500.0, 7000.0, seed + 1)
    source = voiced * voice_level + breath * breath_level * 3.0
    output = source
    for formant in range(4):
        output = resonate(output, track[f"f{formant + 1}"] * speaker.get("formants", 1.0), track[f"b{formant + 1}"])
    output = output - low_pass(output, 150.0)
    output /= numpy.abs(output).max() + 1e-9
    driven = numpy.tanh(speaker.get("drive", 3.0) * output)
    return fade_edges(low_pass(dac(low_pass(driven, 7000.0), VOICE_RATE, 8), OUTPUT_FILTER_HZ), 0.003, 0.05)


## The speakers of the shouts: base pitch (Hz), formant scale, growl, jitter, drive.
SPEAKERS = {
    "jos": {"pitch": 150.0, "formants": 1.0, "growl": 0.3, "jitter": 0.03, "drive": 3.2},
    "martin": {"pitch": 185.0, "formants": 1.06, "growl": 0.15, "jitter": 0.02, "drive": 3.0},
    "ufo_piloot": {"pitch": 140.0, "formants": 0.97, "growl": 0.2, "jitter": 0.03, "drive": 2.6},
    "willem": {"pitch": 120.0, "formants": 0.95, "growl": 0.55, "jitter": 0.06, "drive": 3.4},
    "sjaan": {"pitch": 300.0, "formants": 1.15, "growl": 0.15, "jitter": 0.03, "drive": 3.0},
    "gerrit": {"pitch": 105.0, "formants": 0.92, "growl": 0.4, "jitter": 0.04, "drive": 3.2},
}

## What each character shouts when you look at them on the character creation screen.
SHOUTS = {
    # the old rodeo rider: "jie-HAA!", the "haa" swooping up and falling away
    "jos": [(0.14, "i", "i", 1.25, 1.35, 1.0, 0.05), (0.05, "i", "a", 1.35, 1.2, 0.6, 0.6),
            (0.42, "a", "a", 1.75, 1.15, 1.0, 0.08), (0.12, "a", "uh", 1.15, 0.95, 0.5, 0.15)],
    # the runner: "hup-hup-HUP!", quick, the last one higher
    "martin": [(0.03, "uh", "uh", 1.2, 1.2, 0.0, 0.8), (0.09, "uh", "uh", 1.2, 1.15, 1.0, 0.05), (0.07, "-", "-", 1, 1, 0, 0),
               (0.03, "uh", "uh", 1.25, 1.25, 0.0, 0.8), (0.09, "uh", "uh", 1.25, 1.2, 1.0, 0.05), (0.07, "-", "-", 1, 1, 0, 0),
               (0.03, "uh", "uh", 1.5, 1.5, 0.0, 0.9), (0.16, "uh", "uh", 1.6, 1.35, 1.0, 0.05), (0.05, "-", "-", 1, 1, 0, 0)],
    # the ufo pilot, far away: "oeoeoe-oeh", wavering up and down like a theremin
    "ufo_piloot": [(0.18, "oe", "oe", 1.3, 1.9, 0.9, 0.1), (0.18, "oe", "u", 1.9, 1.3, 0.9, 0.1),
                   (0.18, "u", "oe", 1.3, 2.0, 0.9, 0.1), (0.3, "oe", "uh", 2.0, 1.1, 0.8, 0.15)],
    # the old rat: a hoarse cackle, "heh-heh-heh"
    "willem": [(0.03, "e", "e", 1.6, 1.6, 0.0, 0.9), (0.08, "e", "uh", 1.6, 1.45, 1.0, 0.25), (0.05, "-", "-", 1, 1, 0, 0),
               (0.03, "e", "e", 1.5, 1.5, 0.0, 0.9), (0.08, "e", "uh", 1.5, 1.35, 1.0, 0.25), (0.05, "-", "-", 1, 1, 0, 0),
               (0.03, "e", "e", 1.4, 1.4, 0.0, 0.9), (0.12, "e", "uh", 1.4, 1.1, 1.0, 0.3)],
    # the street musician: a cheerful "hoi!", up and down
    "sjaan": [(0.04, "o", "o", 1.3, 1.3, 0.0, 0.8), (0.14, "o", "o", 1.35, 1.6, 1.0, 0.05),
              (0.16, "o", "i", 1.6, 1.15, 1.0, 0.05)],
    # the fisherman: a deep "a-HOI!" across the water
    "gerrit": [(0.16, "a", "a", 1.1, 1.05, 1.0, 0.05), (0.05, "a", "o", 1.05, 1.1, 0.3, 0.7),
               (0.3, "o", "o", 1.45, 1.35, 1.0, 0.05), (0.2, "o", "i", 1.35, 1.0, 1.0, 0.08)],
}
SHOUTS_FOLDER = os.path.join(style.PROJECT, "assets", "audio", "kreten")


def shout(character: str) -> numpy.ndarray:
    seed = zlib.crc32(character.encode()) % 10000
    return say(SPEAKERS[character], SHOUTS[character], seed)


SOUNDS = {"lichaam_klap": body_hit}
for _voice_name in VOICES:
    for _cry_key in CRIES:
        SOUNDS[f"pijn_{_voice_name}_{_cry_key}"] = (lambda voice_name=_voice_name, cry_key=_cry_key: cry(voice_name, cry_key))


for _character in SHOUTS:
    SOUNDS[f"kreet_{_character}"] = (lambda character=_character: shout(character))


def main() -> None:
    names = sys.argv[1:] or list(SOUNDS)
    for sound_number, name in enumerate(names, 1):
        print(f"[ {sound_number}/{len(names)} ] {name}", end="  ", flush=True)
        folder = SHOUTS_FOLDER if name.startswith("kreet_") else geluiden.OUTPUT_FOLDER
        geluiden.write_mono(name, SOUNDS[name](), False, folder)


if __name__ == "__main__":
    main()
