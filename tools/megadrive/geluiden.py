"""Sound effects of the traffic in Mega Drive style: engines, pass-bys, crashes, bells and horns.

Made from the same three sources as the music (megadrive.py, style.py, docs/MUZIEK.md):
YM2612-style FM (engine tones: a carrier bent by a modulator at half the firing rate, driven
hard; metal clangs, bells, the horn), SN76489-style PSG squares (2-stroke buzz, inverter whine of
trams and trains, glass tinkles, brake squeal) and noise, and everything at the end through the
"DAC": sample-and-hold at 22 kHz and 8 bits, for the grainy 16-bit edge.

Every file is mono (so a Godot AudioStreamPlayer3D can place it in the world), Ogg Vorbis,
44.1 kHz, in assets/audio/geluiden/:

    <vehicle>_voorbij.ogg      one-shot: the vehicle passing the listener, with the Doppler
                               drop in pitch, swelling up and dying away (for traffic heard
                               going by; play it as it passes)
    <vehicle>_motor_loop.ogg   seamless loop of its engine at cruising speed (for an
                               AudioStreamPlayer3D on the vehicle: turn loop on, Godot does the
                               distance, panning and Doppler; pitch_scale can follow the speed)
    auto_botsing_hard.ogg, auto_botsing_licht.ogg   crashes: a heavy one and a bump
    tram_bel.ogg, trein_hoorn.ogg, bus_remmen.ogg  signals and stops (the train horn: the two
                               tyfoons of an NS Koploper, 660 and 370 Hz)

Vehicles: auto (car), brommer (moped), bus, tram (also RandstadRail), trein (NS train).

Emergency services (Dutch two-tone sirens, each service with its own pitch, rhythm and timbre,
so you can tell them apart):
    politie_sirene_loop.ogg, ambulance_sirene_loop.ogg, brandweer_sirene_loop.ogg   the siren
                               alone, a seamless loop (put it on the vehicle next to its motor loop)
    sirene_yelp_loop.ogg       the fast yelp for junctions (any service)
    politie_voorbij.ogg, ambulance_voorbij.ogg, brandweer_voorbij.ogg   racing past, siren and
                               engine, with the Doppler drop
    brandweer_hoorn.ogg        the fire engine's air horn
    helikopter_loop.ogg        the police helicopter hovering (rotor chop, turbine, tail rotor)
    helikopter_voorbij.ogg     the helicopter flying over
    plons.ogg                  someone falling into the water: thump, splash, bubbles
Loops are a whole number of engine cycles long (every frequency fits the loop exactly) and are
filtered circularly, so they repeat without a click. One-shots peak at -1 dB, loops sit at
about -16 dB RMS; set the in-game level with volume_db.

Render: tools/megadrive/render.sh geluiden  (or one: render.sh geluiden tram_bel bus_voorbij)
"""
import os
import sys

import numpy

import megadrive
import style
from megadrive import FmPatch, Operator

SAMPLE_RATE = megadrive.SAMPLE_RATE
OUTPUT_FOLDER = os.path.join(style.PROJECT, "assets", "audio", "geluiden")
SPEED_OF_SOUND = 343.0
DOPPLER_BOOST = 2.5
TWO_PI = 2.0 * numpy.pi

METAL = FmPatch("metal", algorithm=4, feedback=0.5, operators=(
    Operator(ratio=1.41, level=3.2, attack=0.001, decay=0.15, sustain=0.0, release=0.1),
    Operator(ratio=1.0, level=0.6, attack=0.001, decay=0.45, sustain=0.0, release=0.2),
    Operator(ratio=3.73, level=2.2, attack=0.001, decay=0.08, sustain=0.0, release=0.05),
    Operator(ratio=0.5, level=0.45, attack=0.001, decay=0.3, sustain=0.0, release=0.1),
))

HORN = FmPatch("horn", algorithm=4, feedback=0.9, vibrato_depth=0.0, operators=(
    Operator(ratio=1.0, level=2.4, attack=0.03, decay=0.5, sustain=0.85, release=0.12),
    Operator(ratio=1.0, level=0.6, attack=0.02, decay=0.8, sustain=0.9, release=0.15),
    Operator(ratio=2.0, detune_cents=7, level=1.1, attack=0.03, decay=0.5, sustain=0.7, release=0.12),
    Operator(ratio=1.0, detune_cents=-6, level=0.45, attack=0.02, decay=0.8, sustain=0.9, release=0.15),
))


# ----------------------------------------------------------------------------- building blocks


def time_axis(seconds: float) -> numpy.ndarray:
    return numpy.arange(int(round(seconds * SAMPLE_RATE))) / SAMPLE_RATE


def phase_of(frequency) -> numpy.ndarray:
    """Running phase in cycles of a frequency curve (Hz per sample)."""
    return numpy.cumsum(frequency) / SAMPLE_RATE


def square(phase: numpy.ndarray, duty: float = 0.5) -> numpy.ndarray:
    return numpy.where(phase % 1.0 < duty, 1.0, -1.0)


def band_noise(sample_count: int, low_hz: float, high_hz: float, seed: int) -> numpy.ndarray:
    """White noise kept between two frequencies; circular, so it also loops cleanly."""
    random = numpy.random.default_rng(seed)
    spectrum = numpy.fft.rfft(random.uniform(-1.0, 1.0, sample_count))
    frequencies = numpy.fft.rfftfreq(sample_count, 1.0 / SAMPLE_RATE)
    spectrum[(frequencies < low_hz) | (frequencies > high_hz)] = 0.0
    noise = numpy.fft.irfft(spectrum, n=sample_count)
    return noise / (numpy.abs(noise).max() + 1e-9)


def low_pass(signal: numpy.ndarray, cutoff_hz: float) -> numpy.ndarray:
    spectrum = numpy.fft.rfft(signal)
    frequencies = numpy.fft.rfftfreq(len(signal), 1.0 / SAMPLE_RATE)
    return numpy.fft.irfft(spectrum / numpy.sqrt(1.0 + (frequencies / cutoff_hz) ** 4), n=len(signal))


def dac(signal: numpy.ndarray, rate: float = 22050.0, bits: int = 8) -> numpy.ndarray:
    """Sample-and-hold and quantize, like a sound driver streaming through the DAC."""
    times = numpy.arange(len(signal)) / SAMPLE_RATE
    held_indices = numpy.minimum((numpy.floor(times * rate) / rate * SAMPLE_RATE).astype(int), len(signal) - 1)
    steps = 2 ** (bits - 1) - 1
    peak = numpy.abs(signal).max() + 1e-9
    return numpy.round(signal[held_indices] / peak * steps) / steps * peak


def place(buffer: numpy.ndarray, start_seconds: float, samples: numpy.ndarray, gain: float = 1.0) -> None:
    start_index = int(round(start_seconds * SAMPLE_RATE))
    if start_index >= len(buffer):
        return
    piece = samples[:len(buffer) - start_index] * gain
    buffer[start_index:start_index + len(piece)] += piece


def fade_edges(signal: numpy.ndarray, fade_in: float = 0.005, fade_out: float = 0.05) -> numpy.ndarray:
    result = signal.copy()
    in_samples = max(1, int(fade_in * SAMPLE_RATE))
    out_samples = max(1, int(fade_out * SAMPLE_RATE))
    result[:in_samples] *= numpy.linspace(0.0, 1.0, in_samples)
    result[-out_samples:] *= numpy.linspace(1.0, 0.0, out_samples) ** 2
    return result


# ----------------------------------------------------------------------------- engines


def engine(kind: str, firing_hz: numpy.ndarray, seed: int = 1, phase_offset: float = 0.0) -> numpy.ndarray:
    """The engine of a vehicle at a (possibly changing) firing frequency, unfiltered.
    `phase_offset` (in cycles of the slowest component) moves the waveform's edges; loops use it
    so their seam does not fall on an edge."""
    phase = phase_of(firing_hz) + phase_offset
    sample_count = len(firing_hz)
    if kind == "auto":
        # four-stroke: an FM tone with a sub-harmonic modulator, driven into saturation
        tone = numpy.sin(TWO_PI * phase + 2.2 * numpy.sin(TWO_PI * phase * 0.5))
        rumble = 0.35 * square(phase * 0.5, 0.3)
        hiss = 0.12 * band_noise(sample_count, 300.0, 2500.0, seed)
        return numpy.tanh(1.8 * (tone + rumble)) + hiss
    if kind == "brommer":
        # two-stroke: a raspy PSG square at 25 % with an FM buzz on top, nasal
        buzz = numpy.sin(TWO_PI * phase * 2.0 + 3.0 * numpy.sin(TWO_PI * phase))
        rasp = square(phase, 0.25)
        crackle = 0.2 * band_noise(sample_count, 1500.0, 6000.0, seed)
        return numpy.tanh(1.5 * (0.6 * rasp + 0.5 * buzz)) + crackle
    if kind == "bus":
        # big diesel: slow and heavy, hard-driven FM, a faint turbo whine
        tone = numpy.sin(TWO_PI * phase + 3.0 * numpy.sin(TWO_PI * phase * 0.5) + 1.2 * numpy.sin(TWO_PI * phase * 1.5))
        clatter = 0.4 * square(phase * 3.0, 0.15)
        turbo = 0.05 * numpy.sin(TWO_PI * phase * 80.0)
        rumble = 0.25 * band_noise(sample_count, 40.0, 500.0, seed)
        return numpy.tanh(2.2 * (tone + clatter)) * 0.8 + turbo + rumble
    if kind in ("tram", "trein"):
        # electric: the inverter's whine on two PSG squares a fifth apart, a low hum, rail roar
        whine = 0.35 * square(phase, 0.5) + 0.2 * square(phase * 1.5, 0.5)
        hum = 0.5 * numpy.sin(TWO_PI * phase / 4.0)
        roar = (0.6 if kind == "trein" else 0.4) * band_noise(sample_count, 60.0, 900.0, seed)
        return whine + hum + roar
    raise ValueError(kind)


ENGINES = {
    # kind: (firing / whine frequency in Hz at cruise, wobble depth, speed m/s, closest distance m)
    "auto": (48.0, 0.02, 14.0, 3.5),
    "brommer": (95.0, 0.03, 11.0, 2.5),
    "bus": (28.0, 0.01, 9.0, 4.0),
    "tram": (420.0, 0.0, 8.0, 4.0),
    "trein": (330.0, 0.0, 22.0, 8.0),
}


def rail_clacks(sample_count: int, speed: float, carriages: int, carriage_length: float, start: float,
                weight: float) -> numpy.ndarray:
    """Every axle over a rail joint: clack-clack pairs per bogie, two bogies per carriage."""
    buffer = numpy.zeros(sample_count)
    clack_times = numpy.arange(int(0.12 * SAMPLE_RATE)) / SAMPLE_RATE
    clack = numpy.sin(TWO_PI * 85.0 * clack_times) * numpy.exp(-clack_times / 0.03)
    clack += band_noise(len(clack_times), 800.0, 5000.0, 5) * numpy.exp(-clack_times / 0.008) * 0.6
    for carriage in range(carriages):
        for bogie_position in (2.5, carriage_length - 2.5):
            for axle_offset in (-1.25, 1.25):
                position = carriage * carriage_length + bogie_position + axle_offset
                place(buffer, start + position / speed, clack, weight)
    return buffer


def motor_loop(kind: str) -> numpy.ndarray:
    """A seamless engine loop: frequencies and the wobble complete whole cycles in it."""
    firing, wobble_depth, speed, _ = ENGINES[kind]
    loop_seconds = 2.5 if kind == "trein" else 2.0
    times = time_axis(loop_seconds)
    wobble = 1.0 + wobble_depth * numpy.sin(TWO_PI * times / loop_seconds) \
        + 0.5 * wobble_depth * numpy.sin(TWO_PI * 3 * times / loop_seconds)
    # keep the total phase a whole number of sub-harmonic cycles: scale to an exact count
    cycles = round(firing * loop_seconds / 4.0) * 4.0
    firing_curve = wobble * cycles / loop_seconds
    firing_curve *= cycles / (firing_curve.sum() / SAMPLE_RATE)
    slowest_ratio = 0.25 if kind in ("tram", "trein") else 0.5
    signal = engine(kind, firing_curve, phase_offset=0.37 / slowest_ratio)
    if kind in ("tram", "trein"):
        carriage_length = 25.0 if kind == "trein" else 15.0
        carriages = max(1, round(speed * loop_seconds / carriage_length))
        clacks = rail_clacks(len(times) * 2, speed, carriages, carriage_length, 0.0, 0.9)
        signal += clacks[:len(times)] + clacks[len(times):]       # what rings past the end wraps
    signal = low_pass(signal, 7000.0)
    return dac(signal)


def moving_source(seconds: float, speed: float, closest: float):
    """A source going past in a straight line, nearest halfway: (times, the distance along the
    road from the nearest point, Doppler factor, nearness = closest / distance)."""
    times = time_axis(seconds)
    along = speed * (times - seconds * 0.5)
    distance = numpy.sqrt(along ** 2 + closest ** 2)
    # the Doppler drop is exaggerated (DOPPLER_BOOST) so it reads clearly in the game, arcade style
    radial_speed = DOPPLER_BOOST * speed * along / distance
    doppler = SPEED_OF_SOUND / (SPEED_OF_SOUND + radial_speed)
    return times, along, doppler, closest / distance


def by_distance(signal: numpy.ndarray, nearness: numpy.ndarray) -> numpy.ndarray:
    """Louder and brighter near, softer and duller far, through the DAC, faded at both ends."""
    bright = low_pass(signal, 8000.0)
    dull = low_pass(signal, 1200.0)
    shaped = (bright * nearness + dull * (1.0 - nearness)) * nearness ** 1.1
    return fade_edges(dac(shaped), 0.3, 0.4)


def pass_by(kind: str, seconds: float) -> numpy.ndarray:
    """The vehicle driving past: Doppler on the pitch, 1/distance loudness, duller when far."""
    firing, wobble_depth, speed, closest = ENGINES[kind]
    times, along, doppler, nearness = moving_source(seconds, speed, closest)
    middle = seconds * 0.5
    wobble = 1.0 + wobble_depth * numpy.sin(TWO_PI * 1.3 * times)
    signal = engine(kind, firing * doppler * wobble, seed=3)
    if kind in ("tram", "trein"):
        carriages, carriage_length = (4, 25.0) if kind == "trein" else (2, 15.0)
        train_length = carriages * carriage_length
        front_at = middle - train_length / speed * 0.5
        signal += rail_clacks(len(times), speed, carriages, carriage_length, front_at, 1.2)
        # a long vehicle: loud for as long as it is passing, not just at one point
        span = numpy.clip(along, -train_length * 0.5, train_length * 0.5)
        nearness = closest / numpy.sqrt((along - span) ** 2 + closest ** 2)
    if kind == "tram":   # a flange squeal as it takes the bend in front of you
        squeal_phase = phase_of(numpy.full(len(times), 2350.0) * (1.0 + 0.004 * numpy.sin(TWO_PI * 7.0 * times)))
        squeal_envelope = numpy.clip(1.0 - numpy.abs(times - middle - 0.3) / 0.6, 0.0, 1.0) ** 2
        signal += 0.18 * square(squeal_phase) * squeal_envelope
    tyres = band_noise(len(times), 400.0, 4000.0, 9) * (0.0 if kind in ("tram", "trein") else 0.5)
    return by_distance(signal + tyres * nearness, nearness)


# ----------------------------------------------------------------------------- emergency services

SIRENS = {
    # service: (high Hz, low Hz, seconds per tone); Dutch two-tone, each service its own
    "politie": (600.0, 450.0, 0.55),
    "ambulance": (660.0, 495.0, 0.75),
    "brandweer": (392.0, 294.0, 0.8),
}


def whole_cycles(frequency: numpy.ndarray) -> numpy.ndarray:
    """Nudges a frequency curve (a hair) so it completes a whole number of cycles: loopable."""
    cycles = frequency.sum() / SAMPLE_RATE
    return frequency * (round(cycles) / cycles)


def two_tone_curve(service: str, times: numpy.ndarray) -> numpy.ndarray:
    high, low, tone_seconds = SIRENS[service]
    position = (times / tone_seconds) % 2.0
    glide = 0.03 / tone_seconds          # a quick glide between the tones, as a real horn does
    blend = numpy.clip(position / glide, 0.0, 1.0) * numpy.clip((1.0 - position) / glide + 1.0, 0.0, 1.0)
    in_high = numpy.where(position < 1.0, numpy.minimum(blend, 1.0), 0.0)
    in_high = numpy.where((position >= 1.0) & (position < 1.0 + glide), 1.0 - (position - 1.0) / glide, in_high)
    return low + (high - low) * in_high


def yelp_curve(times: numpy.ndarray) -> numpy.ndarray:
    """The fast 'yelp' for junctions: a quick rising sweep, four times a second."""
    sweep = (times * 4.0) % 1.0
    return 520.0 + 780.0 * numpy.sqrt(sweep)


def siren_voice(service: str, frequency: numpy.ndarray) -> numpy.ndarray:
    """The siren's timbre: police bright PSG squares, ambulance a rounder FM horn, fire brigade
    deep and growling FM."""
    phase = phase_of(frequency) + 0.37
    if service in ("politie", "yelp"):
        return 0.55 * square(phase, 0.5) + 0.3 * square(phase * 2.0, 0.25)
    if service == "ambulance":
        return numpy.tanh(1.4 * numpy.sin(TWO_PI * phase + 1.6 * numpy.sin(TWO_PI * phase)))
    return numpy.tanh(1.8 * (numpy.sin(TWO_PI * phase + 2.4 * numpy.sin(TWO_PI * phase)) + 0.3 * square(phase, 0.4)))


def siren_loop(service: str) -> numpy.ndarray:
    if service == "yelp":
        times = time_axis(1.0)
        frequency = whole_cycles(yelp_curve(times))
    else:
        tone_seconds = SIRENS[service][2]
        times = time_axis(4.0 * tone_seconds)      # two high-low cycles
        frequency = whole_cycles(two_tone_curve(service, times))
    return dac(low_pass(siren_voice(service, frequency), 7000.0))


def emergency_pass_by(service: str) -> numpy.ndarray:
    """An emergency vehicle racing past with its siren on, engine roaring under it."""
    speed = {"politie": 20.0, "ambulance": 18.0, "brandweer": 15.0}[service]
    times, along, doppler, nearness = moving_source(5.0, speed, 4.0)
    siren = siren_voice(service, two_tone_curve(service, times) * doppler)
    engine_kind = "bus" if service == "brandweer" else "auto"
    firing = ENGINES[engine_kind][0] * 1.3
    motor = engine(engine_kind, firing * doppler, seed=4) * 0.5
    tyres = band_noise(len(times), 400.0, 4000.0, 10) * 0.4 * nearness
    return by_distance(siren + motor + tyres, nearness)


def helicopter_loop() -> numpy.ndarray:
    """The police helicopter hovering: the rotor's chop (PCM thumps, 13 a second), the turbine's
    whine (PSG and FM) and the tail rotor's buzz. 2 s, every part a whole number of times."""
    loop_seconds = 2.0
    times = time_axis(loop_seconds)
    sample_count = len(times)
    chop = numpy.zeros(sample_count)
    thump_times = time_axis(0.07)
    thump = band_noise(len(thump_times), 40.0, 700.0, 41) * numpy.exp(-thump_times / 0.022)
    thump += numpy.sin(TWO_PI * 70.0 * thump_times) * numpy.exp(-thump_times / 0.03) * 0.8
    thump *= numpy.clip(thump_times / 0.002, 0.0, 1.0)      # a 2 ms attack: no click on each chop
    for blade_pass in range(26):
        start = int(blade_pass * sample_count / 26)
        accent = 1.0 if blade_pass % 2 == 0 else 0.75
        piece = thump * accent
        end = min(sample_count, start + len(piece))
        chop[start:end] += piece[:end - start]
        overflow = start + len(piece) - sample_count
        if overflow > 0:
            chop[:overflow] += piece[-overflow:]
    whine = 0.12 * square(phase_of(numpy.full(sample_count, 1100.0)) + 0.37, 0.5) \
        + 0.06 * numpy.sin(TWO_PI * phase_of(numpy.full(sample_count, 6300.0)))
    tail = 0.18 * square(phase_of(numpy.full(sample_count, 92.0)) + 0.37, 0.3)
    wash = 0.25 * band_noise(sample_count, 100.0, 3000.0, 42)
    return dac(low_pass(chop * 1.4 + whine + tail + wash, 8000.0))


def helicopter_pass_by() -> numpy.ndarray:
    """The helicopter flying over: 8 s, its chop and whine with the Doppler drop."""
    loop = helicopter_loop()
    seconds = 8.0
    times, along, doppler, nearness = moving_source(seconds, 35.0, 25.0)
    # read the hover loop faster or slower by the Doppler factor (pitch and chop rate together)
    read_position = numpy.cumsum(doppler) % len(loop)
    resampled = numpy.interp(read_position, numpy.arange(len(loop)), loop)
    return by_distance(resampled, nearness ** 0.7)


def fire_horn() -> numpy.ndarray:
    """The fire engine's air horn: a deep, blaring two-note blast."""
    buffer = numpy.zeros(int(1.6 * SAMPLE_RATE))
    place(buffer, 0.0, megadrive.fm_chord(HORN, [45.0, 52.0, 57.0], 0.5, 1.0))
    place(buffer, 0.62, megadrive.fm_chord(HORN, [45.0, 52.0, 57.0], 0.7, 1.0))
    return fade_edges(dac(low_pass(buffer, 6000.0)), 0.002, 0.2)


# ----------------------------------------------------------------------------- one-shots


def crash(hard: bool) -> numpy.ndarray:
    seconds = 1.8 if hard else 0.9
    buffer = numpy.zeros(int(seconds * SAMPLE_RATE))
    random = numpy.random.default_rng(12 if hard else 13)
    times = time_axis(seconds)
    # the impact: a PCM thump and a burst of crunching noise
    place(buffer, 0.0, style.KICK, 1.0 if hard else 0.7)
    place(buffer, 0.0, style.TOMS[2], 0.8)
    crunch = band_noise(len(times), 200.0, 7000.0, 21) * numpy.exp(-times / (0.25 if hard else 0.09))
    buffer += crunch * (0.9 if hard else 0.6)
    # bent metal: FM clangs at a few odd pitches
    for index, pitch in enumerate((40, 47, 52) if hard else (45,)):
        clang = megadrive.fm_note(METAL, float(pitch + random.integers(-2, 3)), 0.3 if hard else 0.15, 1.0)
        place(buffer, 0.004 * index, numpy.asarray(clang), 0.6)
    # glass: PSG tinkles falling after the hit (only a hard crash breaks a window)
    if hard:
        for _ in range(16):
            start = 0.05 + random.uniform(0.0, 0.7) ** 1.5
            pitch = float(random.integers(88, 104))
            tinkle = megadrive.psg_square(pitch, 0.04, random.uniform(0.15, 0.4), decay=0.03, sustain=0.0, release=0.02)
            place(buffer, start, numpy.asarray(tinkle))
        # debris rattling down
        for _ in range(7):
            start = 0.2 + random.uniform(0.0, 0.9)
            rattle = band_noise(int(0.06 * SAMPLE_RATE), 1000.0, 6000.0, int(random.integers(100)))
            place(buffer, start, rattle * numpy.exp(-time_axis(0.06) / 0.015), random.uniform(0.15, 0.35))
    return fade_edges(dac(low_pass(buffer, 9000.0)), 0.001, 0.15)


## The tram's gong: its fundamental (Hz) and the partials of a struck dome (ratio, level,
## decay in s); not harmonic, which makes it a bell rather than a tone.
TRAM_GONG_HZ = 760.0
TRAM_GONG_PARTIALS = ((1.0, 1.0, 1.1), (2.32, 0.55, 0.7), (2.98, 0.25, 0.45), (4.25, 0.3, 0.35),
                      (5.4, 0.12, 0.2), (6.63, 0.15, 0.15))


def gong_strike(seed: int, strength: float) -> numpy.ndarray:
    """One strike of the hammer on the dome: the partials ringing out (each pair a hair apart,
    so it shimmers) and the clank of the hammer."""
    times = time_axis(1.4)
    random = numpy.random.default_rng(seed)
    ring = numpy.zeros(len(times))
    for ratio, level, decay in TRAM_GONG_PARTIALS:
        frequency = TRAM_GONG_HZ * ratio * (1.0 + random.uniform(-0.002, 0.002))
        shimmer = 1.0 + 0.0025 * ratio
        ring += level * numpy.exp(-times / decay) * (numpy.sin(TWO_PI * frequency * times)
                                                   + 0.6 * numpy.sin(TWO_PI * frequency * shimmer * times))
    clank = band_noise(len(times), 2000.0, 9000.0, seed + 1) * numpy.exp(-times / 0.004) * 0.8
    return numpy.tanh(1.3 * strength * (ring / 1.6 + clank))


def tram_bell() -> numpy.ndarray:
    """The tram's bell, like the trams of the GVB in Amsterdam: the dome gong under the cab,
    struck twice quickly ("ding-ding"), ringing on."""
    buffer = numpy.zeros(int(1.7 * SAMPLE_RATE))
    place(buffer, 0.0, gong_strike(51, 1.0))
    place(buffer, 0.2, gong_strike(52, 0.9))
    return fade_edges(low_pass(dac(low_pass(buffer, 8000.0)), 6000.0), 0.001, 0.25)


## The two tones of a European train horn (TSI): the high and the low tyfoon.
TRAIN_HORN_HIGH_HZ = 660.0
TRAIN_HORN_LOW_HZ = 370.0


def tyfoon(frequency: float, seconds: float, seed: int) -> numpy.ndarray:
    """One blast of a pneumatic tyfoon (the air horn on the cab of a Koploper): a steel membrane
    slapping against its seat, so a narrow, buzzy pulse rich in harmonics, through the flared
    trumpet (a high-pass at the fundamental and a nasal bump around 1.5 kHz). As the valve opens
    the pitch scoops up while the pressure builds, with a rush of air; it wavers a little while
    it blows, and sags and dies quickly as the valve shuts."""
    times = time_axis(seconds + 0.12)
    held = numpy.clip((seconds - times) / 0.06, 0.0, 1.0)            # valve shutting
    pressure = numpy.clip(times / 0.05, 0.0, 1.0) ** 0.7 * held
    random = numpy.random.default_rng(seed)
    waver = low_pass(random.normal(0.0, 1.0, len(times)), 6.0)
    waver *= 0.004 / (numpy.abs(waver).max() + 1e-9)
    pitch = frequency * (1.0 - 0.07 * numpy.exp(-times / 0.035) - 0.03 * (1.0 - held) + waver)
    phase = phase_of(pitch) % 1.0
    membrane = numpy.where(phase < 0.22, 1.0, -0.28) + 0.25 * numpy.sin(TWO_PI * phase)
    spectrum = numpy.fft.rfft(membrane)
    frequencies = numpy.fft.rfftfreq(len(membrane), 1.0 / SAMPLE_RATE)
    trumpet = (frequencies / frequency) ** 4 / (1.0 + (frequencies / frequency) ** 4)
    trumpet *= 1.0 + 1.4 * numpy.exp(-((frequencies - 1500.0) / 500.0) ** 2)
    trumpet /= 1.0 + (frequencies / 3500.0) ** 2
    tone = numpy.fft.irfft(spectrum * trumpet, n=len(membrane))
    tone = numpy.tanh(1.6 * tone / (numpy.abs(tone).max() + 1e-9))
    rush = band_noise(len(times), 1500.0, 7000.0, seed + 1) * (0.35 * numpy.exp(-times / 0.04) + 0.04) * held
    return (tone * pressure + rush)


def train_horn() -> numpy.ndarray:
    """The horn of an NS Koploper (ICM): its two tyfoons, a short high blast and then a long low
    one ("tuu-tuuuu"), as a driver gives it before a level crossing or the platform's end."""
    buffer = numpy.zeros(int(1.75 * SAMPLE_RATE))
    place(buffer, 0.0, tyfoon(TRAIN_HORN_HIGH_HZ, 0.32, 41), 0.85)
    place(buffer, 0.42, tyfoon(TRAIN_HORN_LOW_HZ, 1.05, 42), 1.0)
    # through the DAC, then the console's output filter takes the edge off the steps
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 5000.0), 0.002, 0.15)


def bus_brakes() -> numpy.ndarray:
    """Coming to a stop: a short brake squeal, then the air brake's hiss."""
    times = time_axis(1.6)
    squeal_phase = phase_of(1900.0 * (1.0 - 0.06 * times) * (1.0 + 0.006 * numpy.sin(TWO_PI * 9.0 * times)))
    squeal = square(squeal_phase) * numpy.clip(times / 0.05, 0.0, 1.0) * numpy.clip(1.0 - times / 0.55, 0.0, 1.0) * 0.35
    hiss_envelope = numpy.where(times > 0.6, numpy.exp(-(times - 0.6) / 0.35) * numpy.clip((times - 0.6) / 0.02, 0.0, 1.0), 0.0)
    hiss = band_noise(len(times), 2500.0, 11000.0, 31) * hiss_envelope
    rumble = band_noise(len(times), 40.0, 300.0, 32) * numpy.clip(1.0 - times / 0.7, 0.0, 1.0) * 0.5
    return fade_edges(dac(squeal + hiss + rumble), 0.005, 0.1)


def splash() -> numpy.ndarray:
    """Someone falling into the water: a low thump and the white rush of the splash, then
    bubbles gurgling up (short sine chirps rising, like the blips of a sinking diver)."""
    times = time_axis(1.4)
    random = numpy.random.default_rng(61)
    thump = numpy.sin(TWO_PI * numpy.cumsum(70.0 + 90.0 * numpy.exp(-times / 0.03)) / SAMPLE_RATE) * numpy.exp(-times / 0.09)
    rush = band_noise(len(times), 400.0, 7000.0, 62) * numpy.exp(-times / 0.18) * numpy.clip(times / 0.004, 0.0, 1.0)
    buffer = 0.9 * thump + 0.8 * rush
    for bubble_index in range(9):
        start = random.uniform(0.25, 1.15)
        bubble_times = time_axis(random.uniform(0.03, 0.06))
        low = random.uniform(350.0, 700.0)
        pitch = low * (1.0 + 1.6 * bubble_times / bubble_times[-1])
        blip = numpy.sin(TWO_PI * numpy.cumsum(pitch) / SAMPLE_RATE) * numpy.sin(numpy.pi * bubble_times / bubble_times[-1])
        place(buffer, start, blip, random.uniform(0.2, 0.45) * (1.3 - start))
    return fade_edges(low_pass(dac(numpy.tanh(1.5 * buffer), 16000.0, 8), 7000.0), 0.001, 0.15)


# ----------------------------------------------------------------------------- output


def write_mono(name: str, signal: numpy.ndarray, loop: bool, folder: str = OUTPUT_FOLDER) -> None:
    import soundfile
    if loop:
        signal = signal - signal.mean()
        signal *= 10.0 ** (-16.0 / 20.0) / numpy.sqrt(numpy.mean(signal ** 2))
        peak = numpy.abs(signal).max()
        ceiling = 10.0 ** (-1.5 / 20.0)
        if peak > ceiling:
            signal *= ceiling / peak
    else:
        signal = signal * 10.0 ** (-1.2 / 20.0) / (numpy.abs(signal).max() + 1e-9)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name + ".ogg")
    with soundfile.SoundFile(path, "w", SAMPLE_RATE, 1, format="OGG", subtype="VORBIS", compression_level=0.3) as ogg_file:
        for start in range(0, len(signal), 8192):
            ogg_file.write(signal[start:start + 8192])
    print(f"written: {path}  ({len(signal) / SAMPLE_RATE:.2f} s{', loop' if loop else ''})")


SOUNDS = {
    "auto_voorbij": (lambda: pass_by("auto", 3.0), False),
    "auto_motor_loop": (lambda: motor_loop("auto"), True),
    "brommer_voorbij": (lambda: pass_by("brommer", 3.0), False),
    "brommer_motor_loop": (lambda: motor_loop("brommer"), True),
    "bus_voorbij": (lambda: pass_by("bus", 4.5), False),
    "bus_motor_loop": (lambda: motor_loop("bus"), True),
    "bus_remmen": (bus_brakes, False),
    "tram_voorbij": (lambda: pass_by("tram", 6.0), False),
    "tram_motor_loop": (lambda: motor_loop("tram"), True),
    "tram_bel": (tram_bell, False),
    "trein_voorbij": (lambda: pass_by("trein", 7.0), False),
    "trein_motor_loop": (lambda: motor_loop("trein"), True),
    "trein_hoorn": (train_horn, False),
    "auto_botsing_hard": (lambda: crash(True), False),
    "auto_botsing_licht": (lambda: crash(False), False),
    "politie_sirene_loop": (lambda: siren_loop("politie"), True),
    "ambulance_sirene_loop": (lambda: siren_loop("ambulance"), True),
    "brandweer_sirene_loop": (lambda: siren_loop("brandweer"), True),
    "sirene_yelp_loop": (lambda: siren_loop("yelp"), True),
    "politie_voorbij": (lambda: emergency_pass_by("politie"), False),
    "ambulance_voorbij": (lambda: emergency_pass_by("ambulance"), False),
    "brandweer_voorbij": (lambda: emergency_pass_by("brandweer"), False),
    "brandweer_hoorn": (fire_horn, False),
    "helikopter_loop": (helicopter_loop, True),
    "helikopter_voorbij": (helicopter_pass_by, False),
    "plons": (splash, False),
}


def main() -> None:
    names = sys.argv[1:] or list(SOUNDS)
    for sound_number, name in enumerate(names, 1):
        print(f"[ {sound_number}/{len(names)} ] {name}", end="  ", flush=True)
        make, loop = SOUNDS[name]
        write_mono(name, make(), loop)


if __name__ == "__main__":
    main()
