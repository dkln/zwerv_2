"""Voices in Mega Drive style: the short cries of pain when the player is hit.

On the Mega Drive the voices of beat-'em-ups were recorded samples played through the YM2612's
DAC: low sample rates (8 to 13 kHz), 8 bits, recorded hot and clipped, so they sound gritty,
loud and a bit nasal. These are not recordings but made the same way a voice is: a glottal pulse
(the vocal folds) at a falling pitch, through formant resonators (the vowel: "ugh", "ah"), with
breath noise, a growl (period doubling) for the strain, driven into saturation, and at the end
through the "DAC": band-limited below half the VOICE_RATE (as the sampler recorded it), sample-and-
hold at VOICE_RATE and 8 bits, which gives the crunchy edge, and a steep reconstruction filter,
so the mirrors of the steps do not whistle (megadrive_voice).
All voices are levelled on how loud they sound (as the ear hears it, loudness.py, like every sound), so
a deep shout and a bright one sit at one level.

Every file is mono, Ogg Vorbis, 44.1 kHz, peak -1 dB, in assets/audio/geluiden/:

    pijn_<stem>_1.ogg, pijn_<stem>_2.ogg, pijn_<stem>_3.ogg   short cries ("ugh!", "hngh!", "uah!")
    pijn_<stem>_hard.ogg                                    a long one for a heavy hit ("aaargh")
    lichaam_klap.ogg                                        the thud of a body being hit

and the shouts of the characters (heard when you look at one on the character creation
screen), in assets/audio/kreten/kreet_<character>.ogg: Jos "5 euro?" (begging, like a question),
Martin "Al zijn ze paars!" (the old athlete), the Ufo Piloot "Derde Dal Universum" (dreamy, wavering like a theremin), Willem a hoarse
cackle, Sjaan "Ff poetsen" (the old toilet attendant), Gerrit a deep, teasing "Scholluhkop!". They are
made like the cries (`say`: segments of vowels, pitch, voice and breath, through the formants
and the DAC); each character has a speaker of their own (SPEAKERS).

and the babble of the people in the street and in conversations (no words, only sounds whose
tune tells the mood, as the voices of old adventure games), in assets/audio/geluiden/:

    brabbel_<stem>_<emotie>_<n>.ogg   a few syllables (n 1..BABBLE_VARIANTS), emotie one of
                                      BABBLE_MOODS: neutraal, blij, opgewonden, boos, verdrietig,
                                      vraag (the last syllable going up: a question)

Voices (stem): man, oude_man (lower, rougher, more breath), vrouw.
The game picks the voice of the character ("voice" in scripts/player/player_character.gd).

Render: tools/megadrive/render.sh stemmen  (or some: render.sh stemmen pijn_vrouw_hard)
"""
import os
import sys
import zlib

import numpy

import geluiden
from geluiden import PROJECT, SAMPLE_RATE, TWO_PI, band_noise, dac, fade_edges, low_pass, time_axis

VOICE_RATE = 11025.0
## The analog low-pass after the DAC: keeps the grit of the steps, takes the hard edge off.
OUTPUT_FILTER_HZ = 6000.0
## The low-pass before the DAC (as the sampler had when the voice was recorded): the hiss of an
## "s" above half the VOICE_RATE would fold back as a whistling rasp; the grit of the steps stays.
ANTI_ALIAS_HZ = 4800.0
## The reconstruction after the DAC, steep: the steps of the sample-and-hold mirror the voice
## above half the VOICE_RATE (a metallic whistle on every "s" and burst); those mirrors go, the
## 8-bit grit within the voice stays.
RECONSTRUCTION_HZ = 5000.0
## How loud the breath (the hiss of the consonants) is against the voice.
BREATH_GAIN = 1.6


def brick_wall(signal: numpy.ndarray, cutoff_hz: float) -> numpy.ndarray:
    """Nothing above `cutoff_hz` (a steep fall over the last 10 %, so it does not ring)."""
    spectrum = numpy.fft.rfft(signal)
    frequencies = numpy.fft.rfftfreq(len(signal), 1.0 / SAMPLE_RATE)
    spectrum *= numpy.clip((cutoff_hz - frequencies) / (0.1 * cutoff_hz), 0.0, 1.0)
    return numpy.fft.irfft(spectrum, n=len(signal))


def megadrive_voice(signal: numpy.ndarray) -> numpy.ndarray:
    """Through the sampler and the DAC: band-limited, 8 bits at VOICE_RATE, the mirrors filtered off."""
    held = dac(brick_wall(signal, ANTI_ALIAS_HZ), VOICE_RATE, 8)
    return low_pass(brick_wall(held, RECONSTRUCTION_HZ), OUTPUT_FILTER_HZ)

## Per voice: pitch at the start and the end of a cry (Hz), formant scale (shorter vocal tract
## is higher), how much breath, how much growl (period doubling), how much pitch jitter.
VOICES = {
    "man": {"pitch": (210.0, 120.0), "formants": 1.0, "breath": 0.10, "growl": 0.35, "jitter": 0.02},
    "oude_man": {"pitch": (165.0, 95.0), "formants": 0.95, "breath": 0.22, "growl": 0.55, "jitter": 0.05},
    "vrouw": {"pitch": (430.0, 260.0), "formants": 1.17, "breath": 0.14, "growl": 0.2, "jitter": 0.02},
    # Blikken Bertus (data/gesprekken/personages.json "stem"): a smoker's rasp, low and gravelly,
    # air through every syllable ("rasp": breath on top of the mood's) and a crackle in the throat
    "rasperig": {"pitch": (125.0, 78.0), "formants": 0.9, "breath": 0.4, "growl": 0.85, "jitter": 0.1,
                 "rasp": 0.35, "crackle": 0.5},
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
    "eu": ((450.0, 1600.0, 2400.0, 3400.0), (70.0, 100.0, 150.0, 220.0)),
    "uu": ((280.0, 1800.0, 2300.0, 3300.0), (60.0, 100.0, 140.0, 200.0)),
    # the "l": voiced, the tongue up, a low second formant
    "l": ((380.0, 1000.0, 2600.0, 3400.0), (90.0, 150.0, 200.0, 250.0)),
    # nasal: the mouth closed, a low murmur
    "m": ((250.0, 1000.0, 2200.0, 3200.0), (120.0, 250.0, 300.0, 350.0)),
    # the bursts of the stops (breath only, coloured where the tongue or lips let go)
    "k": ((900.0, 2400.0, 3300.0, 4200.0), (300.0, 400.0, 500.0, 600.0)),
    "p": ((500.0, 1100.0, 2400.0, 3400.0), (300.0, 400.0, 500.0, 600.0)),
    "d": ((700.0, 1800.0, 2800.0, 3800.0), (300.0, 400.0, 500.0, 600.0)),
    # the hiss of the "s" (and the "f" with "p"): high, sharp
    "s": ((2600.0, 3800.0, 4800.0, 5600.0), (500.0, 600.0, 700.0, 800.0)),
}

## The cries: length (s), the vowels it moves through (vowel, from-time share), how the pitch
## falls (exponent of the curve: high is a fast drop), and how loud the start is.
CRIES = {
    1: {"length": 0.30, "vowels": [("uh", 0.0), ("uh", 0.6), ("ng", 1.0)], "drop": 1.6, "onset": "h"},
    2: {"length": 0.26, "vowels": [("ng", 0.0), ("uh", 0.35), ("ng", 1.0)], "drop": 1.0, "onset": "glottal"},
    3: {"length": 0.36, "vowels": [("u", 0.0), ("a", 0.3), ("uh", 1.0)], "drop": 2.2, "onset": "h"},
    "hard": {"length": 0.85, "vowels": [("a", 0.0), ("a", 0.55), ("uh", 0.85), ("ng", 1.0)], "drop": 0.8, "onset": "h"},
    # the death cry, as the fighting games had it when someone went down (KO): long, from high up,
    # "aaaa" sinking through "oh" and "uh", a wide vibrato, and a big echo after it (DEATH_ECHOES)
    "dood": {"length": 1.6, "vowels": [("a", 0.0), ("a", 0.4), ("o", 0.7), ("uh", 0.9), ("ng", 1.0)], "drop": 0.6,
             "onset": "h"},
    # a groan: low and drawn out, the breath pressed out of you (thrown out of a building)
    "kreun": {"length": 0.9, "vowels": [("uh", 0.0), ("u", 0.45), ("ng", 1.0)], "drop": 0.5, "onset": "glottal"},
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


## The echo of the death cry: (delay in seconds, level) of each repeat, as the big hall of a
## fighting game's KO.
DEATH_ECHOES = ((0.16, 0.5), (0.32, 0.3), (0.48, 0.18), (0.64, 0.1))


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
    if cry_key == "dood":
        start_pitch *= 1.35   # a scream from high up, falling a long way
        end_pitch *= 0.8
    if cry_key == "kreun":
        start_pitch *= 0.8    # a groan stays low
        end_pitch *= 0.75
    # pitch: a jump up at the start (the shock), then falling away
    pitch = end_pitch + (start_pitch - end_pitch) * (1.0 - share) ** shape["drop"]
    pitch *= 1.0 + 0.08 * numpy.exp(-times / 0.025)
    if cry_key == "hard":
        pitch *= 1.0 + 0.025 * numpy.sin(TWO_PI * 6.5 * times) * numpy.clip(share * 3.0, 0.0, 1.0)
    if cry_key == "dood":
        # the dramatic shake of the voice as it goes
        pitch *= 1.0 + 0.045 * numpy.sin(TWO_PI * 5.5 * times) * numpy.clip(share * 2.5, 0.0, 1.0)
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
    if cry_key == "dood":
        # the echo of the hall, before the DAC (the console played it as one sample)
        samples_per_second = len(times) / length
        echoed = numpy.concatenate([driven, numpy.zeros(int(DEATH_ECHOES[-1][0] * samples_per_second) + 1)])
        for delay, level in DEATH_ECHOES:
            start = int(delay * samples_per_second)
            echoed[start:start + len(driven)] += driven * level
        driven = echoed / (numpy.abs(echoed).max() + 1e-9)
    # through the DAC, then the console's output filter, which rounds off the steps a bit
    return fade_edges(megadrive_voice(driven), 0.002, 0.04)


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
## A "-" vowel is silence (the closure before a stop: the "p" of "op"). The values glide within a segment and
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
    if "vibrato" in speaker:
        rate, depth = speaker["vibrato"]
        track["pitch"] = track["pitch"] * (1.0 + depth * numpy.sin(TWO_PI * rate * numpy.arange(len(track["pitch"])) / SAMPLE_RATE))
    sample_count = len(track["pitch"])
    voice_level = low_pass(track["voice"], 60.0)
    breath_level = low_pass(track["breath"], 80.0)
    growl = numpy.full(sample_count, speaker.get("growl", 0.2))
    voiced = glottal_pulses(track["pitch"], growl, speaker.get("jitter", 0.02), seed)
    voiced /= numpy.sqrt(numpy.mean(voiced ** 2)) + 1e-9
    breath = band_noise(sample_count, 500.0, 7000.0, seed + 1)
    # the hiss of the "s", "k" and "p" softer than the voice, so a burst is not the loudest of the shout
    source = voiced * voice_level + breath * breath_level * BREATH_GAIN
    if speaker.get("crackle", 0.0) > 0.0:
        # a crackle in the throat: sparse clicks while the voice sounds (a smoker's rasp)
        clicks = numpy.random.default_rng(seed + 2).random(sample_count) < 0.0025 * speaker["crackle"]
        source = source + clicks * voice_level * numpy.random.default_rng(seed + 3).uniform(-6.0, 6.0, sample_count)
    output = source
    for formant in range(4):
        output = resonate(output, track[f"f{formant + 1}"] * speaker.get("formants", 1.0), track[f"b{formant + 1}"])
    output = output - low_pass(output, 150.0)
    output /= numpy.abs(output).max() + 1e-9
    driven = numpy.tanh(speaker.get("drive", 3.0) * output)
    return fade_edges(megadrive_voice(driven), 0.003, 0.05)


## The speakers of the shouts: base pitch (Hz), formant scale, growl, jitter, drive, and an
## optional vibrato (rate in Hz, depth as a share of the pitch).
SPEAKERS = {
    "jos": {"pitch": 150.0, "formants": 1.0, "growl": 0.3, "jitter": 0.03, "drive": 3.2},
    "martin": {"pitch": 185.0, "formants": 1.06, "growl": 0.15, "jitter": 0.02, "drive": 3.0},
    "ufo_piloot": {"pitch": 140.0, "formants": 0.97, "growl": 0.2, "jitter": 0.03, "drive": 2.6,
                   "vibrato": (6.0, 0.06)},
    "willem": {"pitch": 120.0, "formants": 0.95, "growl": 0.55, "jitter": 0.06, "drive": 3.4},
    "sjaan": {"pitch": 300.0, "formants": 1.15, "growl": 0.15, "jitter": 0.03, "drive": 3.0},
    "gerrit": {"pitch": 105.0, "formants": 0.92, "growl": 0.4, "jitter": 0.04, "drive": 3.2},
}

## What each character shouts when you look at them on the character creation screen.
SHOUTS = {
    # begging, hopeful: "5 euro?" ("vijf euro?"), going up at the end like a question
    "jos": [(0.05, "u", "u", 1.1, 1.1, 0.35, 0.6), (0.16, "e", "i", 1.15, 1.05, 1.0, 0.05),
            (0.07, "p", "p", 1.0, 1.0, 0.0, 0.9), (0.14, "eu", "eu", 1.0, 1.05, 1.0, 0.05),
            (0.03, "uh", "uh", 1.05, 1.05, 0.4, 0.2), (0.26, "o", "o", 1.1, 1.6, 1.0, 0.05)],
    # the old athlete, wired: "Al zijn ze paars!", quick, going up to "PAARS"
    "martin": [(0.09, "a", "a", 1.3, 1.35, 1.0, 0.05), (0.06, "l", "l", 1.35, 1.3, 0.7, 0.0),
               (0.05, "s", "s", 1.0, 1.0, 0.0, 0.12), (0.13, "e", "i", 1.35, 1.3, 1.0, 0.05),
               (0.05, "ng", "ng", 1.3, 1.3, 0.6, 0.0), (0.04, "s", "s", 1.0, 1.0, 0.0, 0.12),
               (0.07, "uh", "uh", 1.35, 1.4, 0.9, 0.05), (0.05, "-", "-", 1, 1, 0, 0),
               (0.025, "p", "p", 1.0, 1.0, 0.0, 1.0), (0.22, "a", "a", 1.9, 1.6, 1.0, 0.06),
               (0.04, "uh", "uh", 1.6, 1.5, 0.4, 0.25), (0.12, "s", "s", 1.0, 1.0, 0.0, 0.2)],
    # the ufo pilot, of the planet Erra, naming where he comes from: "Derde Dal Universum", dreamy, the stress
    # high on "VER", the whole line wavering like a theremin (his speaker's vibrato)
    "ufo_piloot": [(0.03, "-", "-", 1, 1, 0, 0), (0.02, "d", "d", 1.0, 1.0, 0.3, 0.8),
                   (0.12, "e", "e", 1.5, 1.6, 1.0, 0.05), (0.03, "uh", "uh", 1.6, 1.6, 0.4, 0.2),
                   (0.02, "d", "d", 1.0, 1.0, 0.3, 0.8), (0.1, "uh", "uh", 1.5, 1.3, 0.9, 0.05),
                   (0.05, "-", "-", 1, 1, 0, 0), (0.02, "d", "d", 1.0, 1.0, 0.3, 0.8),
                   (0.16, "a", "a", 1.6, 1.8, 1.0, 0.05), (0.08, "l", "l", 1.8, 1.7, 0.7, 0.0),
                   (0.06, "-", "-", 1, 1, 0, 0), (0.09, "uu", "uu", 1.4, 1.5, 1.0, 0.05),
                   (0.05, "ng", "ng", 1.5, 1.5, 0.6, 0.0), (0.08, "i", "i", 1.5, 1.6, 1.0, 0.05),
                   (0.05, "u", "u", 1.6, 1.6, 0.35, 0.6), (0.12, "e", "uh", 1.9, 2.0, 1.0, 0.05),
                   (0.03, "uh", "uh", 2.0, 1.9, 0.4, 0.2), (0.08, "s", "s", 1.0, 1.0, 0.0, 1.0),
                   (0.1, "uh", "uh", 1.6, 1.3, 0.9, 0.05), (0.12, "m", "m", 1.3, 1.0, 0.55, 0.0)],
    # the old rat: a hoarse cackle, "heh-heh-heh"
    "willem": [(0.03, "e", "e", 1.6, 1.6, 0.0, 0.9), (0.08, "e", "uh", 1.6, 1.45, 1.0, 0.25), (0.05, "-", "-", 1, 1, 0, 0),
               (0.03, "e", "e", 1.5, 1.5, 0.0, 0.9), (0.08, "e", "uh", 1.5, 1.35, 1.0, 0.25), (0.05, "-", "-", 1, 1, 0, 0),
               (0.03, "e", "e", 1.4, 1.4, 0.0, 0.9), (0.12, "e", "uh", 1.4, 1.1, 1.0, 0.3)],
    # the old toilet attendant, cheerful: "Ff poetsen" ("effe poetsen"), the stress on "POE"
    "sjaan": [(0.09, "e", "e", 1.3, 1.35, 1.0, 0.05), (0.07, "p", "p", 1.0, 1.0, 0.0, 0.8),
              (0.03, "-", "-", 1, 1, 0, 0), (0.025, "p", "p", 1.0, 1.0, 0.0, 0.9),
              (0.14, "oe", "oe", 1.5, 1.6, 1.0, 0.05), (0.03, "-", "-", 1, 1, 0, 0),
              (0.02, "d", "d", 1.0, 1.0, 0.0, 0.9), (0.07, "s", "s", 1.0, 1.0, 0.0, 1.0),
              (0.12, "uh", "uh", 1.35, 1.15, 0.9, 0.05)],
    # the fisherman from Scheveningen, deep and teasing: "Scholluhkop!" (plaice-head), the
    # stress on "SCHOL", the "ch" a long scrape at the back of the throat
    "gerrit": [(0.07, "s", "s", 1.0, 1.0, 0.0, 1.0), (0.08, "k", "k", 1.0, 1.0, 0.0, 0.9),
               (0.13, "o", "o", 1.4, 1.45, 1.0, 0.05), (0.07, "l", "l", 1.45, 1.35, 0.7, 0.0),
               (0.09, "uh", "uh", 1.3, 1.2, 0.9, 0.05), (0.04, "-", "-", 1, 1, 0, 0),
               (0.03, "k", "k", 1.0, 1.0, 0.0, 1.1), (0.18, "o", "o", 1.35, 1.1, 1.0, 0.05),
               (0.05, "-", "-", 1, 1, 0, 0), (0.03, "p", "p", 1.0, 1.0, 0.0, 0.9)],
}
SHOUTS_FOLDER = os.path.join(PROJECT, "assets", "audio", "kreten")


def shout(character: str) -> numpy.ndarray:
    seed = zlib.crc32(character.encode()) % 10000
    return say(SPEAKERS[character], SHOUTS[character], seed)


## The babble (see the top): per mood how high the voice is (share of its pitch) at the start
## and the end of the line, how long a syllable is (s), the pitch swing within a syllable,
## how hard the voice is driven, extra growl, breath and an optional vibrato.
BABBLE_MOODS = {
    "neutraal": {"pitch": (1.0, 0.92), "syllable": 0.085, "swing": 0.06, "drive": 3.0, "growl": 0.0, "breath": 0.05},
    "blij": {"pitch": (1.3, 1.5), "syllable": 0.07, "swing": 0.16, "drive": 3.0, "growl": 0.0, "breath": 0.05},
    "opgewonden": {"pitch": (1.55, 1.9), "syllable": 0.055, "swing": 0.22, "drive": 3.2, "growl": 0.0, "breath": 0.06},
    "boos": {"pitch": (0.95, 0.8), "syllable": 0.065, "swing": -0.12, "drive": 5.0, "growl": 0.45, "breath": 0.15},
    "verdrietig": {"pitch": (0.85, 0.62), "syllable": 0.14, "swing": -0.08, "drive": 2.2, "growl": 0.0, "breath": 0.3,
                   "vibrato": (5.5, 0.05)},
    # a question: level, then the last syllable longer and going up far ("rise")
    "vraag": {"pitch": (1.0, 1.02), "syllable": 0.08, "swing": 0.03, "drive": 3.0, "growl": 0.0, "breath": 0.05,
              "rise": 0.65},
}
BABBLE_VARIANTS = 32
## The syllables babble is made of: a consonant (or none), a vowel or a gliding one (two
## vowels: "ei", "au", "ui"), and now and then a consonant closing it ("dam", "kos", "pil").
## "t" is a short sharp "d", "b" a soft voiced "p", "n" the nasal "ng" open, "h" breath only.
BABBLE_CONSONANTS = ["d", "k", "p", "m", "l", "s", "n", "t", "b", "h", "-", "-"]
BABBLE_VOWELS = [("a", "a"), ("e", "e"), ("o", "o"), ("i", "i"), ("uh", "uh"), ("oe", "oe"), ("eu", "eu"),
                 ("uu", "uu"), ("u", "u"), ("e", "i"), ("a", "oe"), ("eu", "i")]
BABBLE_CODAS = ["m", "l", "s", "k", "n", "t"]
## The share of syllables closed by a consonant.
BABBLE_CODA_SHARE = 0.3


def babble(voice_name: str, mood: str, variant: int) -> numpy.ndarray:
    """A few syllables of babble in the voice, the tune of the mood."""
    voice = VOICES[voice_name]
    settings = BABBLE_MOODS[mood]
    seed = zlib.crc32(f"{voice_name}{mood}{variant}".encode()) % 10000
    random = numpy.random.default_rng(seed)
    speaker = {"pitch": (voice["pitch"][0] + voice["pitch"][1]) * 0.5, "formants": voice["formants"],
               "growl": voice["growl"] * 0.5 + settings["growl"], "jitter": voice["jitter"], "drive": settings["drive"],
               "crackle": voice.get("crackle", 0.0)}
    rasp = voice.get("rasp", 0.0)
    if "vibrato" in settings:
        speaker["vibrato"] = settings["vibrato"]
    # 1 to 5 syllables (the sad ones 2 to 3, a question at least 2), so the variants differ in length too
    if mood == "verdrietig":
        syllables = 2 + variant % 2
    else:
        syllables = [1, 2, 3, 2, 4, 3, 5, 2][variant % 8]
        if mood == "vraag":
            syllables = max(syllables, 2)
    start, end = settings["pitch"]
    segments = []
    for syllable in range(syllables):
        share = syllable / max(syllables - 1, 1)
        pitch = start + (end - start) * share + random.uniform(-0.07, 0.07)
        consonant = BABBLE_CONSONANTS[random.integers(len(BABBLE_CONSONANTS))]
        first_vowel, last_vowel = BABBLE_VOWELS[random.integers(len(BABBLE_VOWELS))]
        _babble_consonant(segments, consonant, pitch)
        length = settings["syllable"] * random.uniform(0.7, 1.4)
        if first_vowel != last_vowel:
            length *= 1.3   # a gliding vowel takes a little longer
        swing = settings["swing"]
        if syllable == syllables - 1 and "rise" in settings:
            length *= 2.0
            swing = settings["rise"]
        segments.append((length, first_vowel, last_vowel, pitch, pitch * (1.0 + swing), 1.0, settings["breath"] + rasp))
        if random.uniform() < BABBLE_CODA_SHARE and not (syllable == syllables - 1 and "rise" in settings):
            _babble_consonant(segments, BABBLE_CODAS[random.integers(len(BABBLE_CODAS))], pitch * (1.0 + swing))
        # a little gap between syllables (longer for the sad and the calm), now and then none
        if random.uniform() < 0.8:
            segments.append((settings["syllable"] * random.uniform(0.2, 0.5), "-", "-", 1, 1, 0, 0))
    return say(speaker, segments, seed)


def _babble_consonant(segments: list, consonant: str, pitch: float) -> None:
    """The segment of one consonant of babble (see BABBLE_CONSONANTS); nothing for "-"."""
    if consonant in ("d", "k", "p"):
        segments.append((0.025, consonant, consonant, 1.0, 1.0, 0.0, 0.8))
    elif consonant == "t":
        segments.append((0.018, "d", "d", 1.0, 1.0, 0.0, 1.0))
    elif consonant == "b":
        segments.append((0.03, "p", "p", pitch, pitch, 0.35, 0.4))
    elif consonant in ("m", "l"):
        segments.append((0.04, consonant, consonant, pitch, pitch, 0.6, 0.0))
    elif consonant == "n":
        segments.append((0.04, "ng", "ng", pitch, pitch, 0.6, 0.0))
    elif consonant == "s":
        segments.append((0.05, "s", "s", 1.0, 1.0, 0.0, 0.9))
    elif consonant == "h":
        segments.append((0.035, "uh", "uh", 1.0, 1.0, 0.0, 0.7))


## Someone throwing up in the street at night (a drunk, scripts/world/people/pedestrian.gd
## throw_up): two retches (a strained "hrk", the voice of a rough young man), then the gush (a
## gurgling low noise) and its splash on the stones.
RETCHER = {"pitch": 120.0, "formants": 1.0, "growl": 0.7, "jitter": 0.05, "drive": 5.0, "crackle": 0.4}


def throw_up() -> numpy.ndarray:
    """"Hrrk... hrrk... bleuargh" and the splash on the street."""
    retch = say(RETCHER, [(0.06, "-", "-", 1.0, 1.0, 0.0, 0.0), (0.16, "uh", "uh", 0.9, 1.3, 1.0, 0.5),
                          (0.18, "-", "-", 1.0, 1.0, 0.0, 0.0), (0.14, "uh", "e", 1.0, 1.4, 1.0, 0.6),
                          (0.1, "-", "-", 1.0, 1.0, 0.0, 0.0), (0.42, "e", "uh", 1.3, 0.7, 1.0, 0.9)], 4431)
    gush_length = int(0.9 * SAMPLE_RATE)
    times = numpy.arange(gush_length) / SAMPLE_RATE
    gurgle = 1.0 + 0.6 * numpy.sin(TWO_PI * 11.0 * times) * numpy.sin(TWO_PI * 3.0 * times)
    gush = band_noise(gush_length, 180.0, 1400.0, 4432) * gurgle * numpy.minimum(times / 0.05, 1.0) * numpy.exp(-times / 0.5)
    splash_length = int(0.5 * SAMPLE_RATE)
    splash_times = numpy.arange(splash_length) / SAMPLE_RATE
    splash = band_noise(splash_length, 900.0, 6000.0, 4433) * numpy.exp(-splash_times / 0.08) * 0.8
    total = numpy.zeros(len(retch) + int(0.25 * SAMPLE_RATE) + splash_length)
    total[:len(retch)] += retch * 0.9
    start = len(retch) - int(0.35 * SAMPLE_RATE)
    total[start:start + gush_length] += gush[:len(total) - start] * 0.8
    splash_at = start + int(0.3 * SAMPLE_RATE)
    total[splash_at:splash_at + splash_length] += splash[:len(total) - splash_at]
    return fade_edges(numpy.tanh(1.6 * total), 0.002, 0.08)


SOUNDS = {"lichaam_klap": body_hit, "overgeven": throw_up}
for _voice_name in VOICES:
    for _mood in BABBLE_MOODS:
        for _variant in range(1, BABBLE_VARIANTS + 1):
            SOUNDS[f"brabbel_{_voice_name}_{_mood}_{_variant}"] = (
                lambda voice_name=_voice_name, mood=_mood, variant=_variant: babble(voice_name, mood, variant))
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
        sound = SOUNDS[name]()
        voice = name != "lichaam_klap"
        if voice:
            # levelled by ear; what the limiter added above the voice taken off again, and the
            # peaks kept under the ceiling without limiting once more
            for attempt in range(4):
                sound = brick_wall(geluiden.level_one_shot(sound), RECONSTRUCTION_HZ + 300.0)
            sound *= min(1.0, 10.0 ** (geluiden.ONE_SHOT_CEILING_DB / 20.0) / (numpy.abs(sound).max() + 1e-9))
        geluiden.write_mono(name, sound, False, folder, levelled=voice)


if __name__ == "__main__":
    main()
