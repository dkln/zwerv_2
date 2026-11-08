"""Instruments: each function renders one note/hit and returns a mono numpy array.

Pitched instruments take a note ("E5", MIDI number) or a frequency curve and a gate time in
seconds (how long the note is held, before its release). Drums take only their own settings.
Add a new sound by writing a function here and calling it from a song.
"""
import functools

import numpy as np

from synth import (adsr, bandpass, lowpass_sweep, bitcrush, chip_noise, constant, convolve, exponential_decay,
                   gate_window, glide, highpass, lowpass, pulse, saw, seconds_to_samples, sine,
                   soft_clip, stepped, time_axis, triangle, vibrato, white_noise)
from theory import frequency

RNG = np.random.default_rng(135)


def frequency_curve_for(note_or_curve, sample_count):
    if isinstance(note_or_curve, np.ndarray):
        curve = note_or_curve[:sample_count]
        if len(curve) < sample_count:
            curve = np.concatenate([curve, constant(curve[-1], sample_count - len(curve))])
        return curve
    return constant(frequency(note_or_curve), sample_count)


def slide_in(curve, semitones=-2.0, seconds=0.04):
    """Start a note `semitones` away and slide to its pitch (pitch bend into the note)."""
    slide_samples = min(len(curve), seconds_to_samples(seconds))
    bend = np.ones(len(curve))
    bend[:slide_samples] = 2 ** (np.linspace(semitones, 0, slide_samples) / 12)
    return curve * bend


# ---------------------------------------------------------------------------------------------
# Chiptune
# ---------------------------------------------------------------------------------------------

def chip_lead(note, gate, duty=0.5, release=0.05, with_vibrato=True, bend_semitones=0.0):
    """Square-wave lead with stepped (8-bit) volume envelope."""
    sample_count = seconds_to_samples(gate + release)
    curve = frequency_curve_for(note, sample_count)
    if bend_semitones:
        curve = slide_in(curve, bend_semitones)
    if with_vibrato:
        curve = vibrato(curve, rate=6.0, depth_semitones=0.3, delay=0.22)
    envelope = stepped(adsr(sample_count, 0.003, 0.12, 0.7, release, gate))
    return pulse(curve, duty) * envelope


def soften_chip(buffer):
    """Track processor: takes the fizz off bright square waves (fast runs, high octaves)."""
    return lowpass(buffer, 3800, 2)


def chip_arp(note, gate, duty=0.25, bend_semitones=0.0):
    """Short 25% pulse blip for fast arpeggios."""
    sample_count = seconds_to_samples(gate + 0.02)
    curve = frequency_curve_for(note, sample_count)
    if bend_semitones:
        curve = slide_in(curve, bend_semitones, 0.03)
    envelope = stepped(adsr(sample_count, 0.002, gate * 0.8, 0.35, 0.02, gate), 7)
    return pulse(curve, duty) * envelope


def triangle_bass(note, gate):
    """NES-style triangle bass with a soft pluck."""
    sample_count = seconds_to_samples(gate + 0.03)
    curve = frequency_curve_for(note, sample_count)
    return triangle(curve) * adsr(sample_count, 0.004, 0.2, 0.6, 0.03, gate)


def bell(note, gate, brightness=2.0):
    """Small FM bell (shop counter, coins, sparkles)."""
    sample_count = seconds_to_samples(gate + 0.6)
    times = time_axis(sample_count)
    carrier = frequency(note)
    modulator = np.sin(2 * np.pi * carrier * 3.5 * times) * brightness * np.exp(-times / 0.25)
    return np.sin(2 * np.pi * carrier * times + modulator) * np.exp(-times / 0.45) * 0.6


def chip_pitch_drop(start_note, end_note, seconds=0.2):
    sample_count = seconds_to_samples(seconds)
    curve = glide(frequency(start_note), frequency(end_note), sample_count)
    return pulse(curve, 0.5) * stepped(np.linspace(1, 0.2, sample_count), 7)


def chip_noise_sweep(seconds, start_rate=800, end_rate=22000, start_level=0.05, end_level=1.0):
    """Rising 8-bit noise riser: the noise clock speeds up while it gets louder."""
    sample_count = seconds_to_samples(seconds)
    rates = glide(start_rate, end_rate, sample_count)
    levels = glide(start_level, end_level, sample_count)
    return chip_noise(rates, RNG) * levels


# ---------------------------------------------------------------------------------------------
# Synths
# ---------------------------------------------------------------------------------------------

def analog_pad(notes, gate, attack=0.8, release=1.0, detune_semitones=0.1):
    """Detuned saw stack; filter it on track level (lowpass / lowpass_sweep)."""
    sample_count = seconds_to_samples(gate + release)
    stack = np.zeros(sample_count)
    for note in notes:
        for detune in (-detune_semitones, 0.0, detune_semitones):
            curve = constant(frequency(note) * 2 ** (detune / 12), sample_count)
            stack += saw(curve, RNG.random())
    envelope = adsr(sample_count, attack, 0.6, 0.85, release, gate)
    return stack * envelope / (3 * len(notes)) ** 0.5


def sub_bass(note, gate, attack=0.01, release=0.3):
    sample_count = seconds_to_samples(gate + release)
    curve = frequency_curve_for(note, sample_count)
    return (0.75 * sine(curve) + 0.25 * triangle(curve)) * adsr(sample_count, attack, 0.1, 1.0, release, gate)


def retro_bass(note, gate, cutoff=1100):
    """Staccato sawtooth layered with a triangle sub (pump it with Track.sidechain)."""
    sample_count = seconds_to_samples(gate + 0.03)
    curve = frequency_curve_for(note, sample_count)
    saw_layer = lowpass(saw(curve, RNG.random()) + 0.6 * saw(curve * 1.004, RNG.random()), cutoff)
    pluck = adsr(sample_count, 0.003, 0.12, 0.55, 0.03, gate)
    return soft_clip((0.85 * saw_layer + 0.45 * triangle(curve)) * pluck, 1.8)


def synth_lead(note, gate, release=0.15, cutoff=7500):
    """Bright detuned saw lead with vibrato."""
    sample_count = seconds_to_samples(gate + release)
    curve = vibrato(slide_in(frequency_curve_for(note, sample_count), -0.6, 0.03),
                    rate=5.8, depth_semitones=0.2, delay=0.25)
    voices = (saw(curve * 2 ** (-0.1 / 12), RNG.random()) + saw(curve * 2 ** (0.1 / 12), RNG.random())
              + 0.5 * pulse(curve * 0.5, 0.5))
    return lowpass(voices, cutoff) * adsr(sample_count, 0.008, 0.25, 0.8, release, gate) * 0.45


@functools.lru_cache(maxsize=4096)
def synth_pluck(note, gate, brightness=2600, decay=0.16):
    """Retrowave pluck: detuned saws whose low-pass closes quickly after each attack (no pitch slide)."""
    sample_count = seconds_to_samples(gate + decay)
    curve = frequency_curve_for(note, sample_count)
    voices = saw(curve * 2 ** (-0.08 / 12), RNG.random()) + saw(curve * 2 ** (0.08 / 12), RNG.random())
    cutoff = 300 + brightness * exponential_decay(sample_count, decay * 0.5, attack=0.002)
    filtered = lowpass_sweep(voices, cutoff, resonance=1.1, block_size=64)
    return filtered * exponential_decay(sample_count, decay, attack=0.003) * 0.5


def supersaw_pad(notes, gate, attack=0.4, release=0.9, spread_semitones=0.22, voices=5):
    """Wide supersaw stack (put chorus on the track for the classic synthwave pad)."""
    sample_count = seconds_to_samples(gate + release)
    stack = np.zeros(sample_count)
    for note in notes:
        for voice in range(voices):
            detune = spread_semitones * (2 * voice / (voices - 1) - 1)
            stack += saw(constant(frequency(note) * 2 ** (detune / 12), sample_count), RNG.random())
    envelope = adsr(sample_count, attack, 0.6, 0.85, release, gate)
    return stack * envelope / (voices * len(notes)) ** 0.5


def fm_epiano(notes, gate, release=0.35):
    """DX7-style electric piano: FM body with a short metallic tine."""
    sample_count = seconds_to_samples(gate + release)
    times = time_axis(sample_count)
    output = np.zeros(sample_count)
    for note in notes:
        pitch = frequency(note)
        modulator = np.sin(2 * np.pi * pitch * times) * 1.6 * np.exp(-times / 0.45)
        body = np.sin(2 * np.pi * pitch * times + modulator)
        tine = np.sin(2 * np.pi * pitch * 14 * times) * 0.12 * np.exp(-times / 0.025)
        output += (body + tine) * np.exp(-times / 1.4)
    return output * adsr(sample_count, 0.002, 0.0, 1.0, release, gate) / len(notes) ** 0.5 * 0.5


def poly_brass(notes, gate, release=0.25):
    """Polysynth brass: detuned saws whose filter swells open with the note."""
    sample_count = seconds_to_samples(gate + release)
    stack = np.zeros(sample_count)
    for note in notes:
        for detune in (-0.07, 0.07):
            stack += saw(constant(frequency(note) * 2 ** (detune / 12), sample_count), RNG.random())
    swell = adsr(sample_count, 0.06, 0.35, 0.55, release, gate)
    filtered = lowpass_sweep(stack, 350 + 3200 * swell, resonance=0.9, block_size=64)
    return filtered * adsr(sample_count, 0.03, 0.3, 0.8, release, gate) / (2 * len(notes)) ** 0.5 * 0.6


# ---------------------------------------------------------------------------------------------
# Distorted guitar (apply guitar_cabinet on the track)
# ---------------------------------------------------------------------------------------------

def guitar_cabinet(buffer):
    return lowpass(highpass(buffer, 90, 2), 6200, 4)


def guitar_chord(notes, gate, palm_mute=True, drive=16.0, detune_cents=6.0):
    """Power chord through a hard-clipping amp. Palm mute = dark, short and chugging."""
    release = 0.03 if palm_mute else 0.25
    sample_count = seconds_to_samples(gate + release)
    strings = np.zeros(sample_count)
    for note in notes:
        for detune in (-detune_cents, detune_cents):
            curve = constant(frequency(note) * 2 ** ((detune + RNG.normal(0, 2)) / 1200), sample_count)
            strings += saw(curve, RNG.random())
    pick_noise = highpass(white_noise(sample_count, RNG), 2000) * exponential_decay(sample_count, 0.004)
    strings = highpass(strings / len(notes) + 0.3 * pick_noise, 110)
    if palm_mute:
        strings = lowpass(strings, 850) * exponential_decay(sample_count, 0.11)
    else:
        strings = lowpass(strings, 2400) * exponential_decay(sample_count, 1.6)
    amp = soft_clip(strings * drive)
    return amp * adsr(sample_count, 0.001, 0.05, 1.0, release, gate) * 0.5


def guitar_lead(note, gate, release=0.12, drive=22.0, vibrato_depth=0.3, pinch=False):
    """Singing lead guitar; with pinch=True it squeals two octaves-and-a-fifth up."""
    sample_count = seconds_to_samples(gate + release)
    curve = frequency_curve_for(note, sample_count)
    if pinch:
        curve = vibrato(curve * 3.0, rate=7.5, depth_semitones=0.6, delay=0.05, fade=0.1)
    else:
        curve = vibrato(slide_in(curve, -1.0, 0.05), rate=5.6, depth_semitones=vibrato_depth, delay=0.18)
    strings = saw(curve, RNG.random()) + 0.7 * saw(curve * 1.003, RNG.random())
    strings = lowpass(highpass(strings, 220), 3000 if not pinch else 6000)
    amp = soft_clip(strings * drive * exponential_decay(sample_count, 2.5))
    return amp * adsr(sample_count, 0.004, 0.1, 1.0, release, gate) * 0.35


# ---------------------------------------------------------------------------------------------
# Drums (cached: every hit of a drum is the same sample; vary loudness with the gain)
# ---------------------------------------------------------------------------------------------

@functools.lru_cache(maxsize=None)
def kick(length=0.5, punch=210.0, body=50.0):
    """Hard drum-machine kick: fast pitch punch, saturated body and a beater click on top."""
    sample_count = seconds_to_samples(length)
    times = time_axis(sample_count)
    curve = body + punch * np.exp(-times / 0.022)
    body_tone = sine(curve) * np.exp(-times / 0.3)
    click = bandpass(white_noise(sample_count, RNG), 1500, 7000) * np.exp(-times / 0.004)
    beater = sine(constant(3200, sample_count)) * np.exp(-times / 0.005)
    return soft_clip(2.8 * body_tone + 1.0 * click + 0.35 * beater) * 0.92


@functools.lru_cache(maxsize=None)
def sub_boom(length=1.6):
    sample_count = seconds_to_samples(length)
    times = time_axis(sample_count)
    return sine(frequency("E1") + 60 * np.exp(-times / 0.05)) * np.exp(-times / 0.6)


@functools.lru_cache(maxsize=None)
def gated_snare(gate_seconds=0.28):
    """Big 80s snare: two-tone body, crack and rattle through a dense reverb that is cut off hard."""
    sample_count = seconds_to_samples(0.55)
    times = time_axis(sample_count)
    tone = (0.75 * sine(185 + 45 * np.exp(-times / 0.01)) * np.exp(-times / 0.07)
            + 0.4 * sine(constant(330, sample_count)) * np.exp(-times / 0.045))
    rattle = bandpass(white_noise(sample_count, RNG), 900, 9000) * np.exp(-times / 0.15)
    rattle += highpass(white_noise(sample_count, RNG), 5000) * np.exp(-times / 0.03)  # crack
    dry = tone + rattle
    room_length = seconds_to_samples(0.35)
    room_impulse = white_noise(room_length, RNG) * np.exp(-time_axis(room_length) / 0.2)
    room = convolve(dry, room_impulse) / 28
    return soft_clip((dry + room * gate_window(sample_count, gate_seconds)) * 1.9) * 0.8


def gated_room(dry, gate_seconds=0.3, wet=1.0, length=0.55):
    """The 80s gated reverb for any hit (a sample, say): a dense, bright room that swells under
    the hit and is cut off hard after `gate_seconds`. No filter: the room keeps all its top.
    `wet` scales the room level (GATED_ROOM_LEVEL) against the dry hit."""
    sample_count = max(len(dry), seconds_to_samples(length))
    padded = np.zeros(sample_count)
    padded[:len(dry)] = dry
    room_length = seconds_to_samples(0.35)
    room_impulse = white_noise(room_length, RNG) * np.exp(-time_axis(room_length) / 0.2)
    room = convolve(padded, room_impulse / np.sqrt(np.sum(room_impulse ** 2)))[:sample_count]
    room *= GATED_ROOM_LEVEL * wet
    mixed = padded + room * gate_window(sample_count, gate_seconds)
    return soft_clip(mixed / max(np.max(np.abs(mixed)), 1e-9) * 1.2)  # a little glue, no squashing


GATED_ROOM_LEVEL = 1.4  # room peak about 75% of the dry hit: big, but the crack stays in front


@functools.lru_cache(maxsize=None)
def gated_tom(pitch=110.0):
    """80s tom with pitch drop and gated room, for fills."""
    sample_count = seconds_to_samples(0.5)
    times = time_axis(sample_count)
    body = sine(pitch * (1 + 0.6 * np.exp(-times / 0.03))) * np.exp(-times / 0.22)
    attack = bandpass(white_noise(sample_count, RNG), 600, 5000) * np.exp(-times / 0.01)
    dry = body + 0.4 * attack
    room_length = seconds_to_samples(0.3)
    room = convolve(dry, white_noise(room_length, RNG) * np.exp(-time_axis(room_length) / 0.18)) / 30
    return soft_clip((dry + room * gate_window(sample_count, 0.3)) * 1.8) * 0.8


@functools.lru_cache(maxsize=None)
def chip_clap():
    """Bitcrushed handclap: three quick noise bursts."""
    sample_count = seconds_to_samples(0.18)
    times = time_axis(sample_count)
    bursts = sum(np.exp(-np.clip(times - offset, 0, None) / 0.006) * (times >= offset) for offset in (0.0, 0.011, 0.022))
    tail = np.exp(-times / 0.05) * 0.5
    noise = bandpass(white_noise(sample_count, RNG), 900, 3200) * (bursts + tail)
    return bitcrush(noise / max(np.max(np.abs(noise)), 1e-9), bits=4, hold_rate=11025) * 0.6


@functools.lru_cache(maxsize=None)
def chip_hat(accent=False):
    sample_count = seconds_to_samples(0.06)
    noise = highpass(chip_noise(constant(20000, sample_count), RNG), 7000)
    return noise * exponential_decay(sample_count, 0.022 if accent else 0.012) * (1.0 if accent else 0.55)


@functools.lru_cache(maxsize=None)
def chip_rim():
    """Short square 'tick' for light percussion."""
    sample_count = seconds_to_samples(0.05)
    tone = pulse(glide(1400, 700, sample_count), 0.5)
    return stepped(exponential_decay(sample_count, 0.012), 7) * tone * 0.5


@functools.lru_cache(maxsize=None)
def analog_clap():
    """Drum-machine handclap (not bitcrushed)."""
    sample_count = seconds_to_samples(0.3)
    times = time_axis(sample_count)
    bursts = sum(np.exp(-np.clip(times - offset, 0, None) / 0.005) * (times >= offset)
                 for offset in (0.0, 0.009, 0.018, 0.027))
    tail = np.exp(-np.clip(times - 0.027, 0, None) / 0.09) * (times >= 0.027) * 0.6
    noise = bandpass(white_noise(sample_count, RNG), 1100, 8000) * (bursts + tail)
    return noise / max(np.max(np.abs(noise)), 1e-9) * 0.6


@functools.lru_cache(maxsize=None)
def analog_hat(open_hat=False):
    """Drum-machine hi-hat: filtered noise plus metallic square partials."""
    sample_count = seconds_to_samples(0.4 if open_hat else 0.08)
    metal = sum(pulse(constant(freq, sample_count), 0.5) for freq in (3270, 4530, 5960, 7310)) / 4
    noise = highpass(white_noise(sample_count, RNG) + 0.5 * metal, 7000, 4)
    return noise * exponential_decay(sample_count, 0.16 if open_hat else 0.025) * 0.6


# Classic kit (the default, see style.KIT), after the TR-909 / TR-808 circuits.

HAT_METAL_FREQUENCIES = (205.3, 304.4, 369.6, 522.7, 540.0, 800.0)  # the six TR-808 hi-hat oscillators


@functools.lru_cache(maxsize=None)
def classic_kick(length=0.45):
    """909-style kick: a sine that drops fast from ~250 Hz to the body, plus a short click."""
    sample_count = seconds_to_samples(length)
    times = time_axis(sample_count)
    body = sine(55 + 200 * np.exp(-times / 0.018)) * np.exp(-times / 0.3)
    click = lowpass(white_noise(sample_count, RNG), 6000) * np.exp(-times / 0.004)
    return soft_clip(1.6 * body + 0.5 * click) * 0.9


@functools.lru_cache(maxsize=None)
def classic_snare(room_amount=1.0):
    """909-style snare: two triangle tones and band-passed noise, with a smooth short room."""
    sample_count = seconds_to_samples(0.4)
    times = time_axis(sample_count)
    tone = (0.6 * triangle(180 + 20 * np.exp(-times / 0.01)) * np.exp(-times / 0.05)
            + 0.35 * triangle(constant(330, sample_count)) * np.exp(-times / 0.04))
    noise = bandpass(white_noise(sample_count, RNG), 1200, 9000) * np.exp(-times / 0.16)
    dry = tone + 0.9 * noise
    room_length = seconds_to_samples(0.18)
    room_impulse = lowpass(white_noise(room_length, RNG), 4000) * np.exp(-time_axis(room_length) / 0.06)
    room = convolve(dry, room_impulse / np.sqrt(np.sum(room_impulse ** 2))) * 0.25 * room_amount
    return lowpass(soft_clip((dry + room) * 1.2), 10000) * 0.8


@functools.lru_cache(maxsize=None)
def classic_clap():
    """808-style clap: four quick bursts and a tail around 1.2 kHz."""
    sample_count = seconds_to_samples(0.35)
    times = time_axis(sample_count)
    bursts = sum(np.exp(-np.clip(times - offset, 0, None) / 0.007) * (times >= offset)
                 for offset in (0.0, 0.011, 0.022, 0.033))
    tail = np.exp(-np.clip(times - 0.033, 0, None) / 0.15) * (times >= 0.033) * 0.6
    noise = bandpass(white_noise(sample_count, RNG), 1000, 2600) * (bursts + tail)
    return noise / max(np.max(np.abs(noise)), 1e-9) * 0.6


@functools.lru_cache(maxsize=None)
def classic_hat(open_hat=False):
    """808-style hi-hat: six detuned square oscillators, only their metallic top kept."""
    sample_count = seconds_to_samples(0.45 if open_hat else 0.08)
    metal = sum(pulse(constant(frequency_hz, sample_count), 0.5) for frequency_hz in HAT_METAL_FREQUENCIES)
    metal = highpass(bandpass(metal, 7000, 11000, 2), 7000, 2)
    envelope = exponential_decay(sample_count, 0.22 if open_hat else 0.035, attack=0.0005)
    return metal / max(np.max(np.abs(metal)), 1e-9) * envelope * 0.7


@functools.lru_cache(maxsize=None)
def classic_tom(pitch=110.0):
    sample_count = seconds_to_samples(0.45)
    times = time_axis(sample_count)
    body = sine(pitch * (1 + 0.3 * np.exp(-times / 0.04))) * np.exp(-times / 0.2)
    attack = lowpass(white_noise(sample_count, RNG), 3000) * np.exp(-times / 0.006)
    return soft_clip(1.3 * body + 0.3 * attack) * 0.8


# Warm kit: round and fat instead of sharp.

@functools.lru_cache(maxsize=None)
def warm_kick(length=0.55):
    """Round, deep kick: a thump instead of a click."""
    sample_count = seconds_to_samples(length)
    times = time_axis(sample_count)
    body = sine(48 + 130 * np.exp(-times / 0.03)) * np.exp(-times / 0.35)
    thump = lowpass(white_noise(sample_count, RNG), 1200) * np.exp(-times / 0.008)
    return soft_clip(2.2 * body + 0.6 * thump) * 0.92


@functools.lru_cache(maxsize=None)
def warm_snare(gate_seconds=0.3, dark=True):
    """Fat, dark 80s snare: a thick 'thwack' with body and a warm gated room, no sharp crack.
    dark=False leaves out the low-pass filters (noise, room and output): the same snare, open."""
    sample_count = seconds_to_samples(0.55)
    times = time_axis(sample_count)
    body = (0.9 * sine(175 + 60 * np.exp(-times / 0.012)) * np.exp(-times / 0.09)
            + 0.45 * sine(260 + 30 * np.exp(-times / 0.01)) * np.exp(-times / 0.06))
    noise = bandpass(white_noise(sample_count, RNG), 300, 4000 if dark else 9000)
    if dark:
        noise = lowpass(noise, 3500)
    noise = noise * np.exp(-times / 0.17)
    snap = bandpass(white_noise(sample_count, RNG), 1800, 5000) * np.exp(-times / 0.02)  # pit without fizz
    dry = body + 0.8 * noise + 0.55 * snap
    room_length = seconds_to_samples(0.35)
    room_noise = white_noise(room_length, RNG)
    room_impulse = (lowpass(room_noise, 3000) if dark else room_noise) * np.exp(-time_axis(room_length) / 0.22)
    room = convolve(dry, room_impulse) / (18 if dark else 26)
    snare = soft_clip((dry + room * gate_window(sample_count, gate_seconds)) * 1.4)
    return (lowpass(snare, 7500) if dark else snare) * 0.85


def open_warm_snare(gate_seconds=0.3):
    """The warm snare without its low-pass filters (see warm_snare)."""
    return warm_snare(gate_seconds, dark=False)


@functools.lru_cache(maxsize=None)
def warm_clap():
    sample_count = seconds_to_samples(0.3)
    times = time_axis(sample_count)
    bursts = sum(np.exp(-np.clip(times - offset, 0, None) / 0.006) * (times >= offset)
                 for offset in (0.0, 0.01, 0.02))
    tail = np.exp(-np.clip(times - 0.02, 0, None) / 0.1) * (times >= 0.02) * 0.5
    noise = bandpass(white_noise(sample_count, RNG), 700, 3000) * (bursts + tail)
    return noise / max(np.max(np.abs(noise)), 1e-9) * 0.5


@functools.lru_cache(maxsize=None)
def warm_hat(open_hat=False):
    sample_count = seconds_to_samples(0.3 if open_hat else 0.06)
    noise = lowpass(highpass(white_noise(sample_count, RNG), 6000, 4), 12000)
    return noise * exponential_decay(sample_count, 0.11 if open_hat else 0.02) * 0.8


@functools.lru_cache(maxsize=None)
def warm_tom(pitch=110.0):
    return lowpass(gated_tom(pitch), 4000)


@functools.lru_cache(maxsize=None)
def reverse_crash(seconds=1.6):
    """A crash played backwards: swells up into the next downbeat."""
    swell = crash(seconds + 0.4)[::-1][-seconds_to_samples(seconds):]
    return swell * np.linspace(0.2, 1.0, len(swell))


@functools.lru_cache(maxsize=None)
def impact(seconds=2.5):
    """Cinematic hit for drops: sub drop, noise burst and a low tom-like body."""
    sample_count = seconds_to_samples(seconds)
    times = time_axis(sample_count)
    boom = sine(frequency("E1") * (1 + 2.5 * np.exp(-times / 0.08))) * np.exp(-times / 0.9)
    burst = lowpass(white_noise(sample_count, RNG), 2500) * np.exp(-times / 0.12)
    return soft_clip(1.6 * boom + 0.5 * burst) * 0.8


def downlifter(seconds=1.5):
    """Falling filtered noise after a hit."""
    sample_count = seconds_to_samples(seconds)
    noise = white_noise(sample_count, RNG)
    cutoff = glide(9000, 300, sample_count)
    return lowpass_sweep(noise, cutoff, resonance=2.0, block_size=128) * np.linspace(1, 0, sample_count) * 0.5


@functools.lru_cache(maxsize=None)
def crash(length=2.2):
    sample_count = seconds_to_samples(length)
    times = time_axis(sample_count)
    noise = highpass(white_noise(sample_count, RNG), 4000)
    shimmer = highpass(sum(pulse(constant(freq, sample_count), 0.5) for freq in (3150, 4270, 5410)), 3000)
    return (noise + 0.15 * shimmer) * np.exp(-times / 0.7) * 0.5
