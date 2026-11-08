"""Core synthesis building blocks: timing, oscillators, envelopes, filters, tracks, effects, export.

Everything works on mono numpy float arrays at SAMPLE_RATE. A Song owns its tempo and a set of
Tracks; instruments (instruments.py) return short note arrays that are added to a Track at a time.
"""
import functools
import wave

import numpy as np
from scipy import signal as sps

SAMPLE_RATE = 44100


# ---------------------------------------------------------------------------------------------
# Song, timing and tracks
# ---------------------------------------------------------------------------------------------

class Track:
    """A mono buffer with mix settings. `reverb_send` is the amount fed into the shared reverb;
    tracks with `music_filter` go through the song's music filter (see Song.filter_keyframes)."""

    def __init__(self, song, name, volume=1.0, pan=0.0, reverb_send=0.0, sidechain=0.0, music_filter=False,
                 drum_bus=False):
        self.song = song
        self.name = name
        self.music_filter = music_filter
        self.drum_bus = drum_bus
        self.volume = volume
        self.pan = pan
        self.reverb_send = reverb_send
        self.sidechain = sidechain
        self.buffer = np.zeros(song.sample_count)
        self.post_processors = []

    def add(self, audio, start_time, gain=1.0):
        start = int(round(start_time * SAMPLE_RATE))
        if start >= len(self.buffer) or len(audio) == 0:
            return
        if start < 0:
            audio = audio[-start:]
            start = 0
        end = min(start + len(audio), len(self.buffer))
        self.buffer[start:end] += audio[:end - start] * gain

    def process(self, function):
        """Register a function(buffer) -> buffer that runs on the whole track before mixing.

        Registering the same function (by qualified name) twice is ignored, so a section that
        sets up its tracks may run several times in one song.
        """
        if all(existing.__qualname__ != function.__qualname__ for existing in self.post_processors):
            self.post_processors.append(function)
        return self


class Song:
    """Tempo grid plus tracks. Bars are 1-indexed, beats inside a bar 0-indexed (floats allowed)."""

    def __init__(self, bpm, bars, beats_per_bar=4, tail_seconds=0.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.beats_per_bar = beats_per_bar
        self.bar = self.beat * beats_per_bar
        self.bars = bars
        self.length = bars * self.bar + tail_seconds
        self.sample_count = int(self.length * SAMPLE_RATE) + SAMPLE_RATE
        self.tracks = {}
        self.kick_times = []
        self.silence_windows = []
        self.master_effects = []
        self.filter_keyframes = []  # (time, cutoff Hz) for the music filter; empty = always open

    def at(self, bar, beat=0.0):
        return (bar - 1) * self.bar + beat * self.beat

    def beats(self, count):
        return count * self.beat

    def track(self, name, **settings):
        if name not in self.tracks:
            self.tracks[name] = Track(self, name, **settings)
        return self.tracks[name]

    def filter_move(self, keyframes):
        """Add (time, cutoff) points to the music filter (drums are never filtered)."""
        self.filter_keyframes.extend(keyframes)

    def master_effect(self, effect):
        """Add an effect(left, right) -> (left, right) that runs on the whole mix (tape stop, stutter...)."""
        self.master_effects.append(effect)

    def silence(self, start_time, end_time, except_tracks=()):
        """Hard-mute the whole mix (reverb included) between two times, except the named tracks."""
        self.silence_windows.append((start_time, end_time, set(except_tracks)))


# ---------------------------------------------------------------------------------------------
# Oscillators (band-limited with PolyBLEP)
# ---------------------------------------------------------------------------------------------

def time_axis(sample_count):
    return np.arange(sample_count) / SAMPLE_RATE


def seconds_to_samples(seconds):
    return max(1, int(seconds * SAMPLE_RATE))


def phase_from_frequency(frequency_curve, start_phase=0.0):
    step = np.asarray(frequency_curve, dtype=float) / SAMPLE_RATE
    phase = (np.cumsum(step) - step[0] + start_phase) % 1.0
    return phase, np.maximum(step, 1e-9)


def poly_blep(phase, step):
    correction = np.zeros_like(phase)
    rising = phase < step
    fraction = phase[rising] / step[rising]
    correction[rising] = 2 * fraction - fraction * fraction - 1
    falling = phase > 1 - step
    fraction = (phase[falling] - 1) / step[falling]
    correction[falling] = fraction * fraction + 2 * fraction + 1
    return correction


def saw(frequency_curve, start_phase=0.0):
    phase, step = phase_from_frequency(frequency_curve, start_phase)
    return 2 * phase - 1 - poly_blep(phase, step)


def pulse(frequency_curve, duty=0.5, start_phase=0.0):
    phase, step = phase_from_frequency(frequency_curve, start_phase)
    wave_shape = np.where(phase < duty, 1.0, -1.0)
    wave_shape += poly_blep(phase, step)
    wave_shape -= poly_blep((phase - duty) % 1.0, step)
    return wave_shape - (2 * duty - 1)


def triangle(frequency_curve, start_phase=0.0):
    phase, _ = phase_from_frequency(frequency_curve, start_phase)
    return 4 * np.abs(phase - 0.5) - 1


def sine(frequency_curve, start_phase=0.0):
    phase, _ = phase_from_frequency(frequency_curve, start_phase)
    return np.sin(2 * np.pi * phase)


def white_noise(sample_count, rng):
    return rng.uniform(-1, 1, sample_count)


def chip_noise(hold_rate_curve, rng):
    """8-bit style noise: random +-1 values held at a (possibly changing) clock rate in Hz."""
    clock = np.floor(np.cumsum(np.asarray(hold_rate_curve, dtype=float)) / SAMPLE_RATE).astype(int)
    table = rng.choice([-1.0, 1.0], size=clock[-1] + 2)
    return table[clock]


def constant(value, sample_count):
    return np.full(sample_count, float(value))


def glide(start_value, end_value, sample_count, exponential=True):
    if exponential:
        return start_value * (end_value / start_value) ** np.linspace(0, 1, sample_count)
    return np.linspace(start_value, end_value, sample_count)


def vibrato(frequency_curve, rate=5.5, depth_semitones=0.25, delay=0.2, fade=0.3):
    times = time_axis(len(frequency_curve))
    depth = depth_semitones * np.clip((times - delay) / fade, 0, 1)
    return frequency_curve * 2 ** (depth * np.sin(2 * np.pi * rate * times) / 12)


# ---------------------------------------------------------------------------------------------
# Envelopes
# ---------------------------------------------------------------------------------------------

def adsr(sample_count, attack, decay, sustain, release, gate):
    """Linear ADSR; the note is held for `gate` seconds and then released."""
    times = time_axis(sample_count)
    attack = max(attack, 1e-4)
    points = [0.0, attack, attack + max(decay, 1e-4)]
    levels = [0.0, 1.0, sustain]
    envelope = np.interp(times, points, levels)
    gate_level = np.interp(gate, points, levels)
    released = times >= gate
    envelope[released] = gate_level * np.clip(1 - (times[released] - gate) / max(release, 1e-4), 0, 1)
    return envelope


def exponential_decay(sample_count, time_constant, attack=0.001):
    times = time_axis(sample_count)
    return np.exp(-times / time_constant) * np.clip(times / attack, 0, 1)


def stepped(envelope, steps=15):
    """Quantize an envelope into volume steps, like old sound chips."""
    return np.round(envelope * steps) / steps


# ---------------------------------------------------------------------------------------------
# Filters
# ---------------------------------------------------------------------------------------------

@functools.lru_cache(maxsize=256)
def butter_sos(kind, cutoff, order=2):
    return sps.butter(order, cutoff, btype=kind, fs=SAMPLE_RATE, output="sos")


def lowpass(audio, cutoff, order=2):
    return sps.sosfilt(butter_sos("lowpass", float(cutoff), order), audio)


def highpass(audio, cutoff, order=2):
    return sps.sosfilt(butter_sos("highpass", float(cutoff), order), audio)


def bandpass(audio, low, high, order=2):
    return sps.sosfilt(butter_sos("bandpass", (float(low), float(high)), order), audio)


def resonant_lowpass_coefficients(cutoff, resonance):
    omega = 2 * np.pi * min(cutoff, SAMPLE_RATE * 0.45) / SAMPLE_RATE
    alpha = np.sin(omega) / (2 * resonance)
    cosine = np.cos(omega)
    numerator = np.array([(1 - cosine) / 2, 1 - cosine, (1 - cosine) / 2])
    denominator = np.array([1 + alpha, -2 * cosine, 1 - alpha])
    return numerator / denominator[0], denominator / denominator[0]


def lowpass_sweep(audio, cutoff_curve, resonance=0.9, block_size=256):
    """Resonant low-pass whose cutoff follows a per-sample curve (updated every block)."""
    output = np.zeros_like(audio)
    state = np.zeros(2)
    for start in range(0, len(audio), block_size):
        segment = slice(start, start + block_size)
        numerator, denominator = resonant_lowpass_coefficients(cutoff_curve[start], resonance)
        output[segment], state = sps.lfilter(numerator, denominator, audio[segment], zi=state)
    return output


def curve_over_time(song, keyframes, default):
    """Per-sample curve from [(time_seconds, value), ...]; exponential between keyframes."""
    times = time_axis(song.sample_count)
    if not keyframes:
        return constant(default, song.sample_count)
    keyframe_times = [time for time, _ in keyframes]
    log_values = [np.log(max(value, 1e-6)) for _, value in keyframes]
    return np.exp(np.interp(times, keyframe_times, log_values))


# ---------------------------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------------------------

def soft_clip(audio, drive=1.0):
    return np.tanh(audio * drive)


def bitcrush(audio, bits=4, hold_rate=11025):
    """Reduce amplitude resolution and sample rate."""
    levels = 2 ** (bits - 1)
    crushed = np.round(audio * levels) / levels
    hold = max(1, int(SAMPLE_RATE / hold_rate))
    held = crushed[::hold].repeat(hold)[:len(audio)]
    return held


def gate_window(sample_count, open_seconds, close_seconds=0.015):
    times = time_axis(sample_count)
    return np.clip(1 - (times - open_seconds) / close_seconds, 0, 1)


def chorus(buffer, base_milliseconds=14.0, depth_milliseconds=3.5, rate=0.7, amount=0.5):
    """Juno-style chorus: two slowly modulated delayed copies mixed with the dry signal."""
    sample_count = len(buffer)
    positions = np.arange(sample_count, dtype=float)
    times = positions / SAMPLE_RATE
    output = buffer * (1 - amount * 0.5)
    for phase in (0.0, np.pi):
        delay = (base_milliseconds + depth_milliseconds * np.sin(2 * np.pi * rate * times + phase)) * SAMPLE_RATE / 1000
        output += amount * 0.5 * np.interp(positions - delay, positions, buffer, left=0.0)
    return output


def tape_stop(start_time, seconds):
    """Master effect: the whole mix slows down to a halt like a stopping tape deck."""
    def effect(left, right):
        start = int(start_time * SAMPLE_RATE)
        length = min(int(seconds * SAMPLE_RATE), len(left) - start)
        speed = (1 - np.linspace(0, 1, length)) ** 1.5
        positions = start + np.cumsum(speed)
        fade = np.linspace(1, 0.2, length)
        for channel in (left, right):
            source = channel.copy()
            channel[start:start + length] = np.interp(positions, np.arange(len(source)), source) * fade
        return left, right
    return effect


def stutter(start_time, slice_seconds, repeats):
    """Master effect: repeat a short slice of the mix (beat-repeat / glitch)."""
    def effect(left, right):
        start = int(start_time * SAMPLE_RATE)
        slice_length = int(slice_seconds * SAMPLE_RATE)
        for channel in (left, right):
            piece = channel[start:start + slice_length].copy()
            piece *= np.clip(np.linspace(0, 1, slice_length) * 40, 0, 1) * np.clip(np.linspace(1, 0, slice_length) * 40, 0, 1)
            for repeat in range(1, repeats):
                target = start + repeat * slice_length
                if target + slice_length > len(channel):
                    break
                channel[target:target + slice_length] = piece * (1 - 0.08 * repeat)
        return left, right
    return effect


def master_filter_sweep(start_time, end_time, start_cutoff, end_cutoff, resonance=2.5):
    """Master effect: a resonant low-pass over the whole mix that sweeps between two cutoffs."""
    def effect(left, right):
        start = int(start_time * SAMPLE_RATE)
        end = min(int(end_time * SAMPLE_RATE), len(left))
        cutoff = start_cutoff * (end_cutoff / start_cutoff) ** np.linspace(0, 1, end - start)
        for channel in (left, right):
            channel[start:end] = lowpass_sweep(channel[start:end], cutoff, resonance=resonance, block_size=128)
        return left, right
    return effect


def stereo_ping_pong(audio, delay_seconds, feedback=0.4, repeats=6, damping=3500):
    """Returns (left, right) echoes only (no dry signal), alternating sides."""
    delay = int(delay_seconds * SAMPLE_RATE)
    left = np.zeros(len(audio))
    right = np.zeros(len(audio))
    echo = lowpass(audio, damping)
    for repeat in range(1, repeats + 1):
        offset = delay * repeat
        if offset >= len(audio):
            break
        gain = feedback ** repeat
        target = left if repeat % 2 else right
        target[offset:] += echo[:len(audio) - offset] * gain
    return left, right


def reverb_impulse(seconds, rng, brightness=6000, pre_delay=0.012):
    sample_count = seconds_to_samples(seconds)
    times = time_axis(sample_count)
    decay = np.exp(-6.9 * times / seconds)
    impulses = []
    for _ in range(2):
        noise = lowpass(rng.normal(0, 1, sample_count), brightness) * decay
        noise = np.concatenate([np.zeros(seconds_to_samples(pre_delay)), noise])
        impulses.append(noise / np.sqrt(np.sum(noise ** 2)))
    return impulses


def convolve(audio, impulse):
    return sps.fftconvolve(audio, impulse)[:len(audio)]


def sidechain_curve(song, kick_times, depth=0.6, release=0.16):
    """Gain curve that ducks after each kick ('pumping')."""
    curve = np.ones(song.sample_count)
    duck_length = seconds_to_samples(release * 3)
    duck_times = time_axis(duck_length)
    duck = 1 - depth * np.exp(-duck_times / release) * np.clip(duck_times / 0.004, 0, 1)
    for kick_time in kick_times:
        start = int(kick_time * SAMPLE_RATE)
        end = min(start + duck_length, song.sample_count)
        if start >= end:
            continue
        curve[start:end] = np.minimum(curve[start:end], duck[:end - start])
    return curve


# ---------------------------------------------------------------------------------------------
# Mixing and export
# ---------------------------------------------------------------------------------------------

MUSIC_FILTER_OPEN = 18000.0
MUSIC_FILTER_RESONANCE = 2.3
DRUM_BUS_DRIVE = 2.0
DRUM_BUS_PARALLEL = 0.35


def mix(song, rng, reverb_seconds=2.2, start_time=0.0, end_time=None, verbose=True, presence=0.6, width=1.45):
    """Mix all tracks to a normalized stereo array of shape (samples, 2)."""
    end_time = song.bars * song.bar if end_time is None else end_time
    pump = sidechain_curve(song, song.kick_times)
    left = np.zeros(song.sample_count)
    right = np.zeros(song.sample_count)
    reverb_bus = np.zeros(song.sample_count)
    filtered_left = np.zeros(song.sample_count)
    filtered_right = np.zeros(song.sample_count)
    filtered_reverb_bus = np.zeros(song.sample_count)
    drums_left = np.zeros(song.sample_count)
    drums_right = np.zeros(song.sample_count)
    excepted_left = np.zeros(song.sample_count)
    excepted_right = np.zeros(song.sample_count)
    excepted_names = set().union(*[names for _, _, names in song.silence_windows]) if song.silence_windows else set()

    for track in song.tracks.values():
        buffer = track.buffer
        for processor in track.post_processors:
            buffer = processor(buffer)
        if track.sidechain:
            buffer = buffer * (1 - track.sidechain * (1 - pump))
        buffer = buffer * track.volume
        if verbose:
            peak = np.max(np.abs(buffer)) if len(buffer) else 0
            print(f"  {track.name:<22} peak {peak:6.3f}  rms {np.sqrt(np.mean(buffer ** 2)):.4f}")
        angle = (track.pan + 1) * np.pi / 4
        filtered = track.music_filter and song.filter_keyframes
        if track.name in excepted_names:
            target_left, target_right = excepted_left, excepted_right
        elif filtered:
            target_left, target_right = filtered_left, filtered_right
        elif track.drum_bus:
            target_left, target_right = drums_left, drums_right
        else:
            target_left, target_right = left, right
        target_left += buffer * np.cos(angle) * np.sqrt(2)
        target_right += buffer * np.sin(angle) * np.sqrt(2)
        (filtered_reverb_bus if filtered else reverb_bus)[:] += buffer * track.reverb_send

    # Drum bus: parallel saturation ("New York" style) makes the kit fat and aggressive.
    for drums_channel, channel in ((drums_left, left), (drums_right, right)):
        crunch = lowpass(highpass(drums_channel, 150, 2), 6000)  # a little glue in the mids, not the sub or the top
        channel += drums_channel + DRUM_BUS_PARALLEL * np.tanh(crunch * DRUM_BUS_DRIVE) / DRUM_BUS_DRIVE

    impulse_left, impulse_right = reverb_impulse(reverb_seconds, rng)
    left += convolve(reverb_bus, impulse_left)
    right += convolve(reverb_bus, impulse_right)
    if song.filter_keyframes:
        filtered_left += convolve(filtered_reverb_bus, impulse_left)
        filtered_right += convolve(filtered_reverb_bus, impulse_right)
        cutoff = curve_over_time(song, sorted(song.filter_keyframes), MUSIC_FILTER_OPEN)
        left += lowpass_sweep(filtered_left, cutoff, resonance=MUSIC_FILTER_RESONANCE)
        right += lowpass_sweep(filtered_right, cutoff, resonance=MUSIC_FILTER_RESONANCE)

    for effect in song.master_effects:
        left, right = effect(left, right)

    times = time_axis(song.sample_count)
    for window_start, window_end, _ in song.silence_windows:
        mute = (times >= window_start) & (times < window_end)
        left[mute] = 0
        right[mute] = 0
    left += excepted_left
    right += excepted_right

    # Master: clean up the sub, add presence (like the reference: brighter, wider).
    left, right = highpass(left, 35), highpass(right, 35)
    left = left + presence * highpass(left, 3500) + 0.5 * bandpass(left, 1000, 4000) - 0.3 * bandpass(left, 250, 800)
    right = right + presence * highpass(right, 3500) + 0.5 * bandpass(right, 1000, 4000) - 0.3 * bandpass(right, 250, 800)
    middle, side = (left + right) / 2, (left - right) / 2 * width
    stereo = np.stack([middle + side, middle - side], axis=1)
    stereo = stereo[int(start_time * SAMPLE_RATE):int(end_time * SAMPLE_RATE)]
    stereo /= max(np.max(np.abs(stereo)), 1e-9)
    stereo = np.tanh(stereo * 1.15) / np.tanh(1.15)  # light glue only: keep the drum transients
    return stereo * 0.94


def write_wav(path, stereo):
    pcm = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(2)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(pcm.tobytes())


def write_ogg(path, stereo, quality=0.6):
    """Ogg Vorbis (what Godot imports as AudioStreamOggVorbis); quality 0..1."""
    import soundfile
    clipped = np.ascontiguousarray(np.clip(stereo, -1, 1), dtype=np.float32)
    with soundfile.SoundFile(str(path), "w", SAMPLE_RATE, 2, format="OGG", subtype="VORBIS",
                             compression_level=1.0 - quality) as ogg_file:
        for start in range(0, len(clipped), 8192):  # libsndfile's Vorbis encoder crashes on huge writes
            ogg_file.write(clipped[start:start + 8192])
