"""Sound effects of the traffic in Mega Drive style: engines, pass-bys, crashes, bells and horns.

Made with the sound chip of megadrive.py (the rules of the sounds: docs/GELUIDEN.md):
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
    auto_toeter.ogg, bus_toeter.ogg, brommer_toeter.ogg, fiets_bel.ogg   warning people on
                               foot: a car's two-note "toet-toet", the deep horn of a bus or a
                               lorry, a moped's thin beep, a bicycle's thumb bell ("tring-tring");
                               scootmobiel_toeter.ogg: a mobility scooter's electronic beep

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
    springen.ogg               the player jumping: a short rising PSG blip, as in a platform game
    brand_loop.ogg             a vehicle on fire (loop): a low roar of the flames, crackles and pops
    explosie.ogg               a burning wreck blowing up: a deep boom, a rush of debris, a rumble dying away
    deur_binnen.ogg            going into a shop or the station: the electronic door chime, "pling-plong"
    deur_buiten.ogg            going out again: the same chime
The station (Den Haag Centraal, scripts/world/station/station.gd):
    omroep_gong.ogg            the chime before an announcement in the hall (three soft notes: middle, low, high)
    conducteur_fluit.ogg       the conductor's pea whistle before a train leaves
    trein_deuren_dicht.ogg     a Sprinter's doors about to close: a row of beeps, then the hiss
    trein_deuren_open.ogg      the doors of a train opening: the air letting go, the leaves sliding
    ov_inchecken.ogg, ov_uitchecken.ogg   an OV-chipkaart at a reader: one middle beep in, two out
    ov_geweigerd.ogg           a reader saying no: high, middle, high
    kassa_piep.ogg             the scanner of a supermarket checkout: one short high beep
    winkel_alarm.ogg           the security gates of a supermarket: a fast high-low alarm
    lift_ding.ogg              the lift of the city hall arriving: "ding-dong", two soft bells
    lift_rijden_loop.ogg       the lift moving: the low hum of its motor, the hiss of air in the
                               shaft, a soft rattle of the cables; a seamless loop
    poortje_open.ogg           the glass paddles of a gate swinging open: a swoosh gliding up
    poortje_dicht.ogg          and swinging shut again: the swoosh gliding down
Loops are a whole number of engine cycles long (every frequency fits the loop exactly) and are
filtered circularly, so they repeat without a click. Every file is at one loudness
(loudness.py: a one-shot's loudest 400 ms and a loop's average at -16 LUFS, peaks under -1 dB);
set the in-game level with volume_db.

Render: tools/megadrive/render.sh geluiden  (or one: render.sh geluiden tram_bel bus_voorbij)
"""
import os
import sys

import numpy

import loudness
import megadrive
from megadrive import FmPatch, Operator

SAMPLE_RATE = megadrive.SAMPLE_RATE
## The project folder (three up from this file).
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
## The drums under a crash: a fat kick and a low tom.
FAT_KICK = megadrive.make_kick()
LOW_TOM = megadrive.make_tom(125.0)
OUTPUT_FOLDER = os.path.join(PROJECT, "assets", "audio", "geluiden")
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
    if kind == "tram":
        # electric, but soft: the HTM tram's whine is a round hum far under the rail roar
        # (squares at 420 Hz were shrill and grating)
        whine = 0.12 * numpy.sin(TWO_PI * phase) + 0.05 * numpy.sin(TWO_PI * phase * 1.5)
        hum = 0.5 * numpy.sin(TWO_PI * phase / 4.0)
        roar = 0.5 * band_noise(sample_count, 50.0, 700.0, seed)
        return whine + hum + roar
    if kind == "trein":
        # electric, deep and droning: the inverter's whine only a soft round tone (two sines a
        # fifth apart, no squares: those were shrill), under it a heavy hum an octave and two
        # down, saturated a little so it growls, and the low rumble of the rails
        whine = 0.08 * numpy.sin(TWO_PI * phase) + 0.04 * numpy.sin(TWO_PI * phase * 1.5)
        hum = numpy.tanh(1.6 * (0.55 * numpy.sin(TWO_PI * phase / 4.0) + 0.3 * numpy.sin(TWO_PI * phase / 8.0)))
        roar = 0.6 * band_noise(sample_count, 35.0, 450.0, seed)
        return whine + 0.8 * hum + roar
    raise ValueError(kind)


ENGINES = {
    # kind: (firing / whine frequency in Hz at cruise, wobble depth, speed m/s, closest distance m)
    "auto": (48.0, 0.02, 14.0, 3.5),
    "brommer": (95.0, 0.03, 11.0, 2.5),
    "bus": (28.0, 0.01, 9.0, 4.0),
    "tram": (180.0, 0.0, 8.0, 4.0),
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
    place(buffer, 0.0, FAT_KICK, 1.0 if hard else 0.7)
    place(buffer, 0.0, LOW_TOM, 0.8)
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


## The two horns of a car (an electric disc horn pair, a major third apart), and of a bus or
## a lorry (lower and longer).
CAR_HORN_HZ = (410.0, 512.0)
BUS_HORN_HZ = (277.0, 349.0)


def horn_blast(frequencies, seconds: float, seed: int) -> numpy.ndarray:
    """One blast of a pair of electric horns: two buzzing diaphragms (the tyfoon's membrane,
    quicker on and off) sounding together."""
    blast = sum(tyfoon(frequency, seconds, seed + index) for index, frequency in enumerate(frequencies))
    return blast / len(frequencies)


def car_horn() -> numpy.ndarray:
    """A car warning someone on foot: two short blasts, "toet-toet"."""
    buffer = numpy.zeros(int(0.75 * SAMPLE_RATE))
    place(buffer, 0.0, horn_blast(CAR_HORN_HZ, 0.16, 61))
    place(buffer, 0.27, horn_blast(CAR_HORN_HZ, 0.3, 63))
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 5000.0), 0.002, 0.08)


def car_horn_long() -> numpy.ndarray:
    """A car that has waited long enough: one short blast and then holding it, "toet-toeeeeet"."""
    buffer = numpy.zeros(int(2.0 * SAMPLE_RATE))
    place(buffer, 0.0, horn_blast(CAR_HORN_HZ, 0.16, 61))
    place(buffer, 0.27, horn_blast(CAR_HORN_HZ, 1.5, 67))
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 5000.0), 0.002, 0.1)


def bus_horn_long() -> numpy.ndarray:
    """A bus or a lorry leaning on its horn: a long, deep blast."""
    buffer = numpy.zeros(int(2.2 * SAMPLE_RATE))
    place(buffer, 0.0, horn_blast(BUS_HORN_HZ, 1.9, 69))
    return fade_edges(low_pass(dac(low_pass(buffer, 6000.0)), 4500.0), 0.002, 0.15)


def moped_horn_long() -> numpy.ndarray:
    """A moped's horn held down: one long thin beep."""
    seconds = 1.4
    buffer = numpy.zeros(int(1.6 * SAMPLE_RATE))
    times = time_axis(seconds)
    pitch = 790.0 * (1.0 - 0.03 * numpy.exp(-times / 0.02))
    envelope = numpy.clip(times / 0.006, 0.0, 1.0) * numpy.clip((seconds - times) / 0.03, 0.0, 1.0)
    place(buffer, 0.0, square(phase_of(pitch), 0.35) * envelope * 0.8)
    return fade_edges(low_pass(dac(low_pass(buffer, 5000.0)), 4000.0), 0.002, 0.05)


def bus_horn() -> numpy.ndarray:
    """A bus or a lorry: one long, deep blast."""
    buffer = numpy.zeros(int(1.0 * SAMPLE_RATE))
    place(buffer, 0.0, horn_blast(BUS_HORN_HZ, 0.75, 65))
    return fade_edges(low_pass(dac(low_pass(buffer, 6000.0)), 4500.0), 0.002, 0.12)


def moped_horn() -> numpy.ndarray:
    """A moped's thin little horn: two short PSG beeps, "piep-piep", a little flat."""
    buffer = numpy.zeros(int(0.55 * SAMPLE_RATE))
    for start, seconds in ((0.0, 0.12), (0.2, 0.2)):
        times = time_axis(seconds)
        pitch = 790.0 * (1.0 - 0.03 * numpy.exp(-times / 0.02))
        envelope = numpy.clip(times / 0.006, 0.0, 1.0) * numpy.clip((seconds - times) / 0.02, 0.0, 1.0)
        place(buffer, start, square(phase_of(pitch), 0.35) * envelope * 0.8)
    return fade_edges(low_pass(dac(low_pass(buffer, 5000.0)), 4000.0), 0.002, 0.05)


def jump() -> numpy.ndarray:
    """The player jumping: a short square-wave blip sweeping up (a PSG channel, as the old
    platform games), with a soft octave under it and a tiny puff at the take-off."""
    seconds = 0.16
    times = time_axis(seconds)
    sweep = 280.0 * (3.2 ** (times / seconds))
    envelope = numpy.clip(times / 0.004, 0.0, 1.0) * (1.0 - times / seconds) ** 1.4
    tone = square(phase_of(sweep), 0.25) * 0.55 + square(phase_of(sweep * 0.5), 0.5) * 0.2
    puff = band_noise(len(times), 300.0, 2500.0, 11) * numpy.exp(-times / 0.015) * 0.25
    return fade_edges(low_pass(dac(low_pass((tone * envelope + puff), 6000.0)), 5000.0), 0.002, 0.03)


def fire_loop() -> numpy.ndarray:
    """A fire, seamless over its length: the roar of the flames (filtered noise breathing
    slowly), crackles and the odd pop, through the DAC."""
    seconds = 3.0
    count = int(seconds * SAMPLE_RATE)
    times = numpy.arange(count) / SAMPLE_RATE
    breathing = 0.75 + 0.25 * numpy.sin(TWO_PI * times / seconds) * numpy.sin(TWO_PI * 3.0 * times / seconds)
    roar = band_noise(count, 60.0, 600.0, 21) * breathing * 0.7
    random = numpy.random.default_rng(5)
    crackle = numpy.zeros(count)
    click_times = time_axis(0.012)
    for start in random.uniform(0.0, seconds - 0.02, 90):
        click = band_noise(len(click_times), 1500.0, 6000.0, int(start * 1000)) * numpy.exp(-click_times / 0.003)
        place(crackle, start, click * random.uniform(0.3, 1.0))
    pop_times = time_axis(0.08)
    for start in random.uniform(0.0, seconds - 0.1, 6):
        pop = numpy.sin(TWO_PI * 140.0 * pop_times) * numpy.exp(-pop_times / 0.02)
        place(crackle, start, pop * 0.6)
    return low_pass(dac(low_pass(roar + crackle * 0.5, 7000.0)), 6000.0)


def explosion() -> numpy.ndarray:
    """A burning wreck blowing up: a deep boom falling in pitch, a rush of debris, a long
    rumble dying away."""
    seconds = 2.4
    times = time_axis(seconds)
    boom = numpy.sin(TWO_PI * numpy.cumsum(55.0 * numpy.exp(-times / 0.4) + 25.0) / SAMPLE_RATE) * numpy.exp(-times / 0.5)
    rush = band_noise(len(times), 200.0, 5000.0, 13) * numpy.exp(-times / 0.18)
    rumble = band_noise(len(times), 30.0, 250.0, 17) * numpy.exp(-times / 0.9)
    sound = numpy.tanh(2.5 * (boom * 1.0 + rush * 0.8 + rumble * 0.7))
    return fade_edges(low_pass(dac(low_pass(sound, 6000.0)), 5000.0), 0.002, 0.4)


## The electronic chime of a shop door (the sensor over the door): two soft notes, "pling"
## high and "plong" a major third lower, each a sine with a little bell partial, ringing on.
DOOR_CHIME_HZ = (1318.5, 1046.5)


def _door_chime(frequency: float, seconds: float, seed: int) -> numpy.ndarray:
    times = time_axis(seconds)
    random = numpy.random.default_rng(seed)
    tone = numpy.zeros(len(times))
    for ratio, level, decay in ((1.0, 1.0, 0.55), (2.0, 0.22, 0.25), (3.0, 0.07, 0.12)):
        tone += level * numpy.exp(-times / decay) * numpy.sin(TWO_PI * frequency * ratio * (1.0 + random.uniform(-0.0005, 0.0005)) * times)
    return tone * numpy.clip(times / 0.004, 0.0, 1.0)


def _pling_plong(gap: float) -> numpy.ndarray:
    seconds = 1.4
    buffer = numpy.zeros(int(seconds * SAMPLE_RATE))
    place(buffer, 0.0, _door_chime(DOOR_CHIME_HZ[0], 1.1, 111) * 0.6)
    place(buffer, gap, _door_chime(DOOR_CHIME_HZ[1], 1.1, 112) * 0.6)
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 6000.0), 0.002, 0.3)


def door_in() -> numpy.ndarray:
    """Going in (a shop, the station): the electronic door chime, "pling-plong"."""
    return _pling_plong(0.32)


def door_out() -> numpy.ndarray:
    """Going out again: the same chime, the second note a little sooner."""
    return _pling_plong(0.28)


def scooter_beep() -> numpy.ndarray:
    """A mobility scooter's horn: a little electronic buzzer, one high beep."""
    beep_seconds = 0.22
    buffer = numpy.zeros(int(0.3 * SAMPLE_RATE))
    times = time_axis(beep_seconds)
    envelope = numpy.clip(times / 0.004, 0.0, 1.0) * numpy.clip((beep_seconds - times) / 0.015, 0.0, 1.0)
    place(buffer, 0.0, square(phase_of(numpy.full(len(times), 2350.0)), 0.5) * envelope * 0.6)
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 6000.0), 0.002, 0.04)


## The thumb bell of a Dutch bicycle: two little domes a hair apart, struck fast by the
## spinning clapper (BIKE_BELL_STRIKES a second) for a while (BIKE_BELL_STRIKES_PER_BURST: a
## real trill, "trrringeling"), twice.
BIKE_BELL_HZ = (2650.0, 2790.0)
BIKE_BELL_PARTIALS = ((1.0, 1.0, 0.5), (1.51, 0.4, 0.25), (2.14, 0.25, 0.14))
BIKE_BELL_STRIKES = 30.0
BIKE_BELL_STRIKES_PER_BURST = 10
BIKE_BELL_BURSTS = (0.0, 0.48)


def bike_bell() -> numpy.ndarray:
    """A bicycle's bell: "trringel-trringel", two bursts of many quick strikes ringing on."""
    buffer = numpy.zeros(int(1.6 * SAMPLE_RATE))
    times = time_axis(0.7)
    random = numpy.random.default_rng(71)
    for burst_start in BIKE_BELL_BURSTS:
        for strike in range(BIKE_BELL_STRIKES_PER_BURST):
            ring = numpy.zeros(len(times))
            for dome in BIKE_BELL_HZ:
                for ratio, level, decay in BIKE_BELL_PARTIALS:
                    frequency = dome * ratio * (1.0 + random.uniform(-0.001, 0.001))
                    ring += level * numpy.exp(-times / decay) * numpy.sin(TWO_PI * frequency * times + random.uniform(0.0, TWO_PI))
            click = band_noise(len(times), 3000.0, 9000.0, 72 + strike) * numpy.exp(-times / 0.002) * 0.6
            # the clapper hits a little unevenly, now harder, now softer, slowing a touch at the end
            strength = (1.0 - strike * 0.035) * random.uniform(0.8, 1.0)
            at = burst_start + strike / BIKE_BELL_STRIKES * (1.0 + strike * 0.012)
            place(buffer, at, (ring / 3.0 + click) * strength)
    return fade_edges(low_pass(dac(low_pass(numpy.tanh(1.2 * buffer), 9000.0)), 7000.0), 0.001, 0.3)


# ----------------------------------------------------------------------------- output


## Every file at one loudness (loudness.py, as the ear hears it): a one-shot's loudest moment
## and a loop's average at loudness.TARGET_LUFS, the peaks softly held under ONE_SHOT_CEILING_DB,
## so a bell, a crash, a cry and an engine sit at one level and the game sets their loudness
## (scripts/audio/spatial_audio.gd) instead of the files.
ONE_SHOT_CEILING_DB = loudness.CEILING_DB


def level_one_shot(signal: numpy.ndarray) -> numpy.ndarray:
    """The one-shot at the target loudness (its loudest 400 ms), peaks under the ceiling."""
    return loudness.level(signal - signal.mean(), one_shot=True)


def write_mono(name: str, signal: numpy.ndarray, loop: bool, folder: str = OUTPUT_FOLDER, levelled: bool = False) -> None:
    import soundfile
    if loop:
        signal = loudness.level(signal - signal.mean(), one_shot=False)
    elif not levelled:
        signal = level_one_shot(signal)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name + ".ogg")
    with soundfile.SoundFile(path, "w", SAMPLE_RATE, 1, format="OGG", subtype="VORBIS", compression_level=0.3) as ogg_file:
        for start in range(0, len(signal), 8192):
            ogg_file.write(signal[start:start + 8192])
    print(f"written: {path}  ({len(signal) / SAMPLE_RATE:.2f} s{', loop' if loop else ''})")



# ----------------------------------------------------------------------------- the station

def _soft_bell(frequency: float, seconds: float, seed: int) -> numpy.ndarray:
    """One note of the chime in the hall: a soft FM-like bell (a sine with a few inharmonic
    partials dying away faster), a gentle strike, no clank."""
    times = time_axis(seconds)
    random = numpy.random.default_rng(seed)
    ring = numpy.zeros(len(times))
    for ratio, level, decay in ((1.0, 1.0, 1.1), (2.0, 0.35, 0.5), (3.01, 0.18, 0.25), (4.2, 0.08, 0.12)):
        detune = 1.0 + random.uniform(-0.001, 0.001)
        ring += level * numpy.exp(-times / decay) * numpy.sin(TWO_PI * frequency * ratio * detune * times)
    attack = numpy.clip(times / 0.006, 0.0, 1.0)
    return ring * attack


def station_chime() -> numpy.ndarray:
    """The chime before an announcement in the station hall: three soft bell notes, middle,
    low, high (C, G below it, E above it), the last one ringing out."""
    buffer = numpy.zeros(int(2.6 * SAMPLE_RATE))
    for start, frequency, seed in ((0.0, 523.3, 61), (0.38, 392.0, 62), (0.76, 659.3, 63)):
        place(buffer, start, _soft_bell(frequency, 1.8, seed) * 0.6)
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 6000.0), 0.002, 0.4)


def conductor_whistle() -> numpy.ndarray:
    """The conductor's whistle on the platform before the doors close: a shrill pea whistle,
    the pea rattling the tone (a fast warble), one long blast with a little rise at the start."""
    seconds = 1.1
    times = time_axis(seconds)
    pitch = 2950.0 + 120.0 * numpy.clip(times / 0.08, 0.0, 1.0)
    rattle = 1.0 + 0.035 * numpy.sin(TWO_PI * 38.0 * times) * (0.6 + 0.4 * numpy.sin(TWO_PI * 5.0 * times))
    tone = numpy.sin(TWO_PI * numpy.cumsum(pitch * rattle) / SAMPLE_RATE)
    breath = band_noise(len(times), 2500.0, 6500.0, 71) * 0.18
    envelope = numpy.clip(times / 0.02, 0.0, 1.0) * numpy.clip((seconds - times) / 0.08, 0.0, 1.0)
    amplitude = 0.75 + 0.25 * (numpy.sin(TWO_PI * 38.0 * times) > 0.0)
    return fade_edges(low_pass(dac(low_pass((tone * amplitude + breath) * envelope * 0.7, 8000.0)), 6500.0), 0.002, 0.05)


def train_door_beeps() -> numpy.ndarray:
    """The doors of a Sprinter about to close: a fast row of high beeps (a PSG square), then
    the hiss of the air as they slide shut."""
    seconds = 2.6
    buffer = numpy.zeros(int(seconds * SAMPLE_RATE))
    beep_seconds = 0.09
    beep_times = time_axis(beep_seconds)
    envelope = numpy.clip(beep_times / 0.003, 0.0, 1.0) * numpy.clip((beep_seconds - beep_times) / 0.01, 0.0, 1.0)
    beep = square(phase_of(numpy.full(len(beep_times), 1760.0)), 0.5) * envelope * 0.5
    for index in range(10):
        place(buffer, index * 0.16, beep)
    hiss_times = time_axis(0.9)
    hiss = band_noise(len(hiss_times), 1200.0, 7000.0, 81) * numpy.exp(-hiss_times / 0.35) * 0.35
    thump = numpy.sin(TWO_PI * 90.0 * hiss_times) * numpy.exp(-numpy.maximum(hiss_times - 0.55, 0.0) / 0.05) * (hiss_times > 0.55) * 0.5
    place(buffer, 1.6, hiss + thump)
    return fade_edges(low_pass(dac(low_pass(buffer, 7500.0)), 6000.0), 0.002, 0.1)


def train_doors_open() -> numpy.ndarray:
    """The doors of a train opening: the air letting go (a hiss) and the leaves sliding, one
    low bump as they stop."""
    seconds = 1.2
    times = time_axis(seconds)
    hiss = band_noise(len(times), 900.0, 6000.0, 91) * numpy.exp(-times / 0.3) * 0.45
    slide = band_noise(len(times), 150.0, 900.0, 92) * numpy.clip(times / 0.1, 0.0, 1.0) * numpy.exp(-times / 0.5) * 0.3
    bump = numpy.sin(TWO_PI * 80.0 * times) * numpy.exp(-numpy.maximum(times - 0.7, 0.0) / 0.05) * (times > 0.7) * 0.5
    return fade_edges(low_pass(dac(low_pass(hiss + slide + bump, 7000.0)), 6000.0), 0.002, 0.15)


def _reader_beep(frequency: float, seconds: float) -> numpy.ndarray:
    times = time_axis(seconds)
    envelope = numpy.clip(times / 0.003, 0.0, 1.0) * numpy.clip((seconds - times) / 0.012, 0.0, 1.0)
    return (square(phase_of(numpy.full(len(times), frequency)), 0.5) * 0.4
            + numpy.sin(TWO_PI * frequency * times) * 0.4) * envelope


## The pitches of the OV-chipkaart reader: a middle beep and a high one above it.
READER_MIDDLE_HZ = 1568.0
READER_HIGH_HZ = 2093.0


def ov_check_in() -> numpy.ndarray:
    """Checking in with an OV-chipkaart at a reader: one middle beep."""
    buffer = numpy.zeros(int(0.35 * SAMPLE_RATE))
    place(buffer, 0.0, _reader_beep(READER_MIDDLE_HZ, 0.15))
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 6000.0), 0.001, 0.03)


def ov_check_out() -> numpy.ndarray:
    """Checking out: two middle beeps, quickly after each other."""
    buffer = numpy.zeros(int(0.45 * SAMPLE_RATE))
    place(buffer, 0.0, _reader_beep(READER_MIDDLE_HZ, 0.1))
    place(buffer, 0.15, _reader_beep(READER_MIDDLE_HZ, 0.1))
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 6000.0), 0.001, 0.03)


def ov_refused() -> numpy.ndarray:
    """A reader that says no (no card, or the gate the wrong way): high, middle, high."""
    buffer = numpy.zeros(int(0.65 * SAMPLE_RATE))
    for start, frequency in ((0.0, READER_HIGH_HZ), (0.15, READER_MIDDLE_HZ), (0.3, READER_HIGH_HZ)):
        place(buffer, start, _reader_beep(frequency, 0.12))
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 6000.0), 0.001, 0.04)


def checkout_beep() -> numpy.ndarray:
    """The scanner of a supermarket checkout: one short beep, higher and drier than the OV
    reader's."""
    buffer = numpy.zeros(int(0.22 * SAMPLE_RATE))
    place(buffer, 0.0, _reader_beep(2637.0, 0.07))
    return fade_edges(low_pass(dac(low_pass(buffer, 7500.0)), 6500.0), 0.001, 0.02)


def shop_alarm() -> numpy.ndarray:
    """The security gates of a supermarket: high and low beeps fast after each other, six
    pairs, the alarm everyone in the shop turns round for."""
    buffer = numpy.zeros(int(2.0 * SAMPLE_RATE))
    for pair in range(6):
        place(buffer, pair * 0.3, _reader_beep(3136.0, 0.13))
        place(buffer, pair * 0.3 + 0.15, _reader_beep(2349.0, 0.13))
    return fade_edges(low_pass(dac(low_pass(buffer, 7500.0)), 6500.0), 0.001, 0.05)


def lift_ding() -> numpy.ndarray:
    """The lift arriving: "ding-dong", two soft bell tones (a major third down), ringing out."""
    seconds = 1.6
    buffer = numpy.zeros(int(seconds * SAMPLE_RATE))
    for start, frequency in ((0.0, 1318.5), (0.42, 1046.5)):
        times = time_axis(seconds - start)
        tone = (numpy.sin(TWO_PI * frequency * times) + 0.3 * numpy.sin(TWO_PI * frequency * 2.0 * times)
                + 0.12 * numpy.sin(TWO_PI * frequency * 3.01 * times))
        place(buffer, start, tone * numpy.exp(-times / 0.45) * numpy.clip(times / 0.004, 0.0, 1.0) * 0.45)
    return fade_edges(low_pass(dac(low_pass(buffer, 7000.0)), 6000.0), 0.001, 0.2)


def lift_moving_loop() -> numpy.ndarray:
    """The lift moving, a seamless loop of 2 s: the motor's low hum (a fundamental and its
    second harmonic in whole cycles), air rushing past in the shaft (band noise, the loop's
    ends crossfaded) and a soft periodic rattle of the cables."""
    seconds = 2.0
    times = time_axis(seconds)
    hum = numpy.sin(TWO_PI * 55.0 * times) * 0.35 + numpy.sin(TWO_PI * 110.0 * times) * 0.18 \
        + numpy.sin(TWO_PI * 165.0 * times) * 0.06
    air = band_noise(len(times), 200.0, 1400.0, 171) * 0.12
    # crossfade the noise into its own start, so the loop has no seam
    fade = int(0.25 * SAMPLE_RATE)
    ramp = numpy.linspace(0.0, 1.0, fade)
    air[:fade] = air[:fade] * ramp + air[-fade:] * (1.0 - ramp)
    rattle = band_noise(len(times), 1500.0, 4000.0, 172) * (0.5 + 0.5 * numpy.sin(TWO_PI * 4.0 * times)) ** 8 * 0.05
    return low_pass(dac(low_pass(hum + air + rattle, 5000.0)), 4500.0)


## How long the paddles of a gate take to swing (as SWING_TIME in station_gates.gd).
GATE_SWING_SECONDS = 0.45


## The bands of noise a swoosh glides through (Hz): low to high.
SWOOSH_BANDS = ((350.0, 700.0), (700.0, 1400.0), (1400.0, 2800.0), (2800.0, 5600.0))


def _gate_swing(closing: bool) -> numpy.ndarray:
    """The glass paddles of a gate swinging: a swoosh, air pushed aside by the panes: noise
    swelling up and dying away with the speed of the paddles, its pitch gliding up as they
    open (down as they close), and at the end only a very soft tick of the stops."""
    swing = GATE_SWING_SECONDS
    seconds = swing + 0.2
    times = time_axis(seconds)
    progress = numpy.clip(times / swing, 0.0, 1.0)
    # how fast the paddles go: nothing at both ends, fastest just before halfway
    speed = numpy.sin(numpy.pi * progress ** 0.8) * (times < swing)
    # where in the bands the swoosh is: up while opening, down while closing
    glide = (1.0 - progress) if closing else progress
    position = 0.6 + glide * (len(SWOOSH_BANDS) - 1.6)
    swoosh = numpy.zeros(len(times))
    for band_index, (low, high) in enumerate(SWOOSH_BANDS):
        weight = numpy.clip(1.0 - numpy.abs(position - band_index), 0.0, 1.0)
        swoosh += band_noise(len(times), low, high, 121 + band_index + (10 if closing else 0)) * weight
    swoosh *= speed ** 1.5 * 0.55
    after_stop = numpy.maximum(times - swing, 0.0) * (times >= swing)
    tick = band_noise(len(times), 1500.0, 4000.0, 131) * numpy.exp(-after_stop / 0.006) * (times >= swing) * 0.08
    return fade_edges(low_pass(dac(low_pass(swoosh + tick, 7000.0)), 6000.0), 0.004, 0.06)


def gate_paddles() -> numpy.ndarray:
    """The paddles of a gate swinging open."""
    return _gate_swing(closing=False)


def gate_paddles_close() -> numpy.ndarray:
    """The paddles of a gate swinging shut again, meeting each other in the middle."""
    return _gate_swing(closing=True)


def smack() -> numpy.ndarray:
    """The KLAP of being flung out of a door: a heavy boom (a low punch that drops) under a
    sharp crack (a slap of noise), hard and short, as in a beat-'em-up."""
    seconds = 0.6
    times = time_axis(seconds)
    pitch = 48.0 + 140.0 * numpy.exp(-times / 0.03)
    boom = numpy.sin(TWO_PI * numpy.cumsum(pitch) / SAMPLE_RATE) * numpy.exp(-times / 0.16)
    crack = band_noise(len(times), 1200.0, 7000.0, 151) * numpy.exp(-times / 0.018) * 0.9
    body = band_noise(len(times), 150.0, 900.0, 152) * numpy.exp(-times / 0.06) * 0.5
    return fade_edges(low_pass(dac(low_pass(numpy.tanh(2.6 * (boom + crack + body)), 7500.0)), 6500.0), 0.001, 0.08)


def kick() -> numpy.ndarray:
    """A boot kick (someone thrown out of the door): the swing through the air, then the heavy
    dull thump of the boot on a body, a slap of cloth on top."""
    seconds = 0.45
    times = time_axis(seconds)
    swing = band_noise(len(times), 600.0, 3500.0, 141) * numpy.clip(times / 0.06, 0.0, 1.0) * (times < 0.09) * 0.35
    at = numpy.maximum(times - 0.09, 0.0) * (times >= 0.09)
    pitch = 55.0 + 90.0 * numpy.exp(-at / 0.025)
    thump = numpy.sin(TWO_PI * numpy.cumsum(pitch) / SAMPLE_RATE) * numpy.exp(-at / 0.09) * (times >= 0.09)
    slap = band_noise(len(times), 900.0, 5000.0, 142) * numpy.exp(-at / 0.012) * (times >= 0.09) * 0.6
    return fade_edges(low_pass(dac(low_pass(numpy.tanh(2.0 * (swing + thump + slap)), 7000.0)), 6000.0), 0.002, 0.05)


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
    "auto_toeter": (car_horn, False),
    "auto_toeter_lang": (car_horn_long, False),
    "bus_toeter_lang": (bus_horn_long, False),
    "brommer_toeter_lang": (moped_horn_long, False),
    "bus_toeter": (bus_horn, False),
    "brommer_toeter": (moped_horn, False),
    "fiets_bel": (bike_bell, False),
    "scootmobiel_toeter": (scooter_beep, False),
    "springen": (jump, False),
    "brand_loop": (fire_loop, True),
    "explosie": (explosion, False),
    "deur_binnen": (door_in, False),
    "deur_buiten": (door_out, False),
    "omroep_gong": (station_chime, False),
    "conducteur_fluit": (conductor_whistle, False),
    "trein_deuren_dicht": (train_door_beeps, False),
    "trein_deuren_open": (train_doors_open, False),
    "ov_inchecken": (ov_check_in, False),
    "ov_uitchecken": (ov_check_out, False),
    "ov_geweigerd": (ov_refused, False),
    "poortje_open": (gate_paddles, False),
    "schop": (kick, False),
    "klap": (smack, False),
    "poortje_dicht": (gate_paddles_close, False),
    "kassa_piep": (checkout_beep, False),
    "winkel_alarm": (shop_alarm, False),
    "lift_ding": (lift_ding, False),
    "lift_rijden_loop": (lift_moving_loop, True),
}


def main() -> None:
    names = sys.argv[1:] or list(SOUNDS)
    for sound_number, name in enumerate(names, 1):
        print(f"[ {sound_number}/{len(names)} ] {name}", end="  ", flush=True)
        make, loop = SOUNDS[name]
        write_mono(name, make(), loop)


if __name__ == "__main__":
    main()
