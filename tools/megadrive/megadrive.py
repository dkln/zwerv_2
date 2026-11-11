"""A small Sega Mega Drive / Genesis style synthesizer (numpy), for the game's sound effects and voices.

It imitates the three sound sources of the console:

* YM2612 FM: 4-operator voices (`FmPatch`, four `Operator`s) wired by one of the chip's 8
  algorithms, operator 1 with self-feedback (the chip averages its last two outputs). Each
  operator has a frequency ratio ("multiple"), a detune in cents and an attack/decay/sustain/
  release envelope; a modulator's level is its modulation index in radians, a carrier's level
  its output amplitude. Feedback is a recursion, which numpy solves by fixed-point iteration
  over the whole note (it converges because the feedback gain stays below ~1.6). Optional
  delayed vibrato and pitch slides as a sound driver would do them. The output is rounded to
  the chip's 9-bit DAC steps.
* SN76489 PSG: square waves whose pitch is quantized to the chip's 10-bit divider and whose
  volume moves in 2 dB steps, updated once per 60 Hz frame like a driver's software envelope;
  and the 16-bit LFSR white noise (used here for hi-hats and the crash).
* PCM drums through the DAC: kick (fat or tight), snare (plain or the 80s gated one), clap and
  toms are synthesized, then resampled with sample-and-hold to ~13-17.5 kHz and quantized to
  8 bits, so they have that grainy sampled edge. FM patches may be driven into overdrive
  (`drive`: the "guitar"), PSG notes may carry a driver vibrato, and `tape_stop` slows a
  stretch of the mix to a standstill.

Everything is added to `Track`s (a mono buffer plus a pan) with wrap-around: what rings past
the end of the buffer lands at the start, so a song renders as a seamless loop. `master()`
mixes the tracks, filters the circular mix in the frequency domain (DC block plus a soft
"Model 1" low-pass; FFT filtering is circular too, so the seam stays clean), soft-limits and
normalizes, and `write_ogg()` writes Ogg Vorbis, 44.1 kHz stereo.

This file is the sound chip; the sound effects (geluiden.py) and the voices (stemmen.py) are made
with it (docs/GELUIDEN.md). Render: tools/megadrive/render.sh geluiden | stemmen
"""
from dataclasses import dataclass, field
from functools import lru_cache

import numpy

SAMPLE_RATE = 44100
PSG_CLOCK = 3579545.0
FRAME_RATE = 60.0


def midi_to_frequency(midi_note: float) -> float:
    return 440.0 * 2.0 ** ((midi_note - 69.0) / 12.0)


# --------------------------------------------------------------------------- tracks


@dataclass
class Track:
    """One mixer channel: a mono buffer with a fixed pan (-1 hard left, 0 centre, 1 hard right)."""
    name: str
    sample_count: int
    pan: float = 0.0
    gain: float = 1.0
    wrap: bool = True           # loops wrap their tails to the start; one-shots drop them
    buffer: numpy.ndarray = field(init=False)

    def __post_init__(self) -> None:
        self.buffer = numpy.zeros(self.sample_count)

    def add(self, start_seconds: float, samples: numpy.ndarray, gain: float = 1.0) -> None:
        """Adds samples at a time; the part past the end wraps to the start (seamless loop),
        or, for a one-shot (wrap False), is dropped."""
        start_index = int(round(start_seconds * SAMPLE_RATE))
        if not self.wrap:
            if start_index >= self.sample_count:
                return
            if start_index < 0:
                samples = samples[-start_index:]
                start_index = 0
            piece = samples[:self.sample_count - start_index] * gain
            self.buffer[start_index:start_index + len(piece)] += piece
            return
        start_index %= self.sample_count
        remaining = samples * gain
        while len(remaining):
            room = self.sample_count - start_index
            piece = remaining[:room]
            self.buffer[start_index:start_index + len(piece)] += piece
            remaining = remaining[room:]
            start_index = 0


# --------------------------------------------------------------------------- YM2612 FM


@dataclass(frozen=True)
class Operator:
    ratio: float = 1.0          # frequency multiple of the note
    detune_cents: float = 0.0
    level: float = 1.0          # modulator: index in radians; carrier: amplitude
    attack: float = 0.002       # seconds to full level
    decay: float = 0.3          # time constant of the fall towards sustain
    sustain: float = 1.0        # level (fraction) it decays to while held
    release: float = 0.06       # time constant after note-off
    velocity_to_level: float = 0.5   # how much a soft note lowers this operator


@dataclass(frozen=True)
class FmPatch:
    name: str
    algorithm: int
    feedback: float
    operators: tuple            # four Operators, operator 1 first
    vibrato_depth: float = 0.0  # semitones
    vibrato_rate: float = 5.5
    vibrato_delay: float = 0.25
    # overdrive after the operators (0 = none): the "electric guitar" of the house style, as
    # Mega Drive composers got it, an FM voice with high feedback driven into the clipping
    # of the output stage; the 9-bit rounding comes after it
    drive: float = 0.0


def _envelope(operator: Operator, times: numpy.ndarray, note_length: float) -> numpy.ndarray:
    attack = max(operator.attack, 0.001)
    held = numpy.where(
        times < attack,
        times / attack,
        operator.sustain + (1.0 - operator.sustain) * numpy.exp(-(times - attack) / max(operator.decay, 1e-4)),
    )
    if note_length < attack:
        level_at_off = note_length / attack
    else:
        level_at_off = operator.sustain + (1.0 - operator.sustain) * numpy.exp(
            -(note_length - attack) / max(operator.decay, 1e-4))
    released = level_at_off * numpy.exp(-(times - note_length) / max(operator.release, 1e-4))
    return numpy.where(times < note_length, held, released)


def _carriers(algorithm: int) -> tuple:
    return {0: (3,), 1: (3,), 2: (3,), 3: (3,), 4: (1, 3), 5: (1, 2, 3), 6: (1, 2, 3), 7: (0, 1, 2, 3)}[algorithm]


@lru_cache(maxsize=None)
def fm_note(patch: FmPatch, midi_note: float, length: float, velocity: float = 1.0,
            slide_from: float = None, slide_time: float = 0.05) -> numpy.ndarray:
    """Renders one FM note (cached: grooves repeat the same notes a lot)."""
    longest_release = max(operator.release for operator in patch.operators)
    total_seconds = length + longest_release * 5.0 + 0.005
    times = numpy.arange(int(total_seconds * SAMPLE_RATE)) / SAMPLE_RATE

    pitch = numpy.full_like(times, float(midi_note))
    if slide_from is not None:
        pitch += (slide_from - midi_note) * numpy.clip(1.0 - times / slide_time, 0.0, 1.0)
    if patch.vibrato_depth:
        fade_in = numpy.clip((times - patch.vibrato_delay) / 0.2, 0.0, 1.0)
        pitch += patch.vibrato_depth * fade_in * numpy.sin(2 * numpy.pi * patch.vibrato_rate * times)
    base_frequency = 440.0 * 2.0 ** ((pitch - 69.0) / 12.0)
    base_phase = 2 * numpy.pi * numpy.cumsum(base_frequency) / SAMPLE_RATE

    carriers = _carriers(patch.algorithm)
    phases = []
    envelopes = []
    for operator_index, operator in enumerate(patch.operators):
        multiple = operator.ratio * 2.0 ** (operator.detune_cents / 1200.0)
        phases.append(base_phase * multiple)
        softness = 1.0 - operator.velocity_to_level * (1.0 - velocity)
        envelopes.append(_envelope(operator, times, length) * operator.level * softness)

    def operator_output(operator_index: int, modulation) -> numpy.ndarray:
        return envelopes[operator_index] * numpy.sin(phases[operator_index] + modulation)

    # operator 1 with feedback: y[n] = env * sin(phase + fb * (y[n-1] + y[n-2]) / 2)
    first = operator_output(0, 0.0)
    if patch.feedback:
        for _ in range(8):
            previous = numpy.concatenate(([0.0], first[:-1]))
            before_previous = numpy.concatenate(([0.0, 0.0], first[:-2]))
            normalized = (previous + before_previous) * 0.5 / max(patch.operators[0].level, 1e-6)
            first = operator_output(0, patch.feedback * normalized)

    algorithm = patch.algorithm
    if algorithm == 0:
        output = operator_output(3, operator_output(2, operator_output(1, first)))
    elif algorithm == 1:
        output = operator_output(3, operator_output(2, first + operator_output(1, 0.0)))
    elif algorithm == 2:
        output = operator_output(3, first + operator_output(2, operator_output(1, 0.0)))
    elif algorithm == 3:
        output = operator_output(3, operator_output(1, first) + operator_output(2, 0.0))
    elif algorithm == 4:
        output = operator_output(1, first) + operator_output(3, operator_output(2, 0.0))
    elif algorithm == 5:
        output = operator_output(1, first) + operator_output(2, first) + operator_output(3, first)
    elif algorithm == 6:
        output = operator_output(1, first) + operator_output(2, 0.0) + operator_output(3, 0.0)
    else:
        output = first + operator_output(1, 0.0) + operator_output(2, 0.0) + operator_output(3, 0.0)

    if patch.drive:
        output = numpy.tanh(patch.drive * output) / numpy.tanh(patch.drive)
    output *= velocity
    fade_samples = min(len(output), int(0.004 * SAMPLE_RATE))
    output[-fade_samples:] *= numpy.linspace(1.0, 0.0, fade_samples)
    output = numpy.round(output * 256.0) / 256.0        # 9-bit DAC steps
    output.setflags(write=False)
    return output


def fm_chord(patch: FmPatch, midi_notes, length: float, velocity: float = 1.0) -> numpy.ndarray:
    """Several FM notes at once (one FM channel each on the real chip)."""
    voices = [fm_note(patch, float(note), length, velocity) for note in midi_notes]
    longest = max(len(voice) for voice in voices)
    result = numpy.zeros(longest)
    for voice in voices:
        result[:len(voice)] += voice
    return result


# --------------------------------------------------------------------------- SN76489 PSG


def _psg_frame_envelope(times: numpy.ndarray, length: float, decay: float, sustain: float,
                        release: float) -> numpy.ndarray:
    """A driver-style software envelope: updated once per frame, 2 dB attenuation steps."""
    frame_times = numpy.floor(times * FRAME_RATE) / FRAME_RATE
    held = sustain + (1.0 - sustain) * numpy.exp(-frame_times / max(decay, 1e-4))
    level_at_off = sustain + (1.0 - sustain) * numpy.exp(-length / max(decay, 1e-4))
    released = level_at_off * numpy.exp(-(frame_times - length) / max(release, 1e-4))
    level = numpy.where(frame_times < length, held, released)
    attenuation_steps = numpy.clip(numpy.round(-20.0 * numpy.log10(numpy.maximum(level, 1e-6)) / 2.0), 0, 15)
    return numpy.where(attenuation_steps >= 15, 0.0, 10.0 ** (-attenuation_steps * 2.0 / 20.0))


@lru_cache(maxsize=None)
def psg_square(midi_note: float, length: float, volume: float = 1.0, decay: float = 0.15,
               sustain: float = 0.5, release: float = 0.05, vibrato_depth: float = 0.0,
               vibrato_rate: float = 7.0, vibrato_delay: float = 0.08) -> numpy.ndarray:
    """A PSG square note; pitch rounded to the chip's divider (slightly out of tune, as it was).
    The SN76489 has only a 50% square: the thin "chiptune lead" comes from a fast vibrato that
    the sound driver writes into the divider once per frame (`vibrato_depth` in semitones)."""
    total_seconds = length + release * 4.0 + 1.0 / FRAME_RATE
    times = numpy.arange(int(total_seconds * SAMPLE_RATE)) / SAMPLE_RATE
    if vibrato_depth:
        frame_times = numpy.floor(times * FRAME_RATE) / FRAME_RATE
        fade_in = numpy.clip((frame_times - vibrato_delay) / 0.1, 0.0, 1.0)
        pitch = midi_note + vibrato_depth * fade_in * numpy.sin(2 * numpy.pi * vibrato_rate * frame_times)
        dividers = numpy.clip(numpy.round(PSG_CLOCK / (32.0 * 440.0 * 2.0 ** ((pitch - 69.0) / 12.0))), 1, 1023)
        phase = numpy.cumsum(PSG_CLOCK / (32.0 * dividers)) / SAMPLE_RATE
        square = numpy.where(phase % 1.0 < 0.5, 1.0, -1.0)
    else:
        divider = max(1, min(1023, round(PSG_CLOCK / (32.0 * midi_to_frequency(midi_note)))))
        frequency = PSG_CLOCK / (32.0 * divider)
        square = numpy.where((times * frequency) % 1.0 < 0.5, 1.0, -1.0)
    output = square * _psg_frame_envelope(times, length, decay, sustain, release) * volume
    output.setflags(write=False)
    return output


def psg_sweep(start_midi: float, end_midi: float, seconds: float, volume: float = 1.0) -> numpy.ndarray:
    """A PSG square diving (or rising) in pitch, one divider step per frame, fading out."""
    times = numpy.arange(int(seconds * SAMPLE_RATE)) / SAMPLE_RATE
    frame_progress = numpy.floor(times * FRAME_RATE) / FRAME_RATE / seconds
    pitch = start_midi + (end_midi - start_midi) * frame_progress
    dividers = numpy.clip(numpy.round(PSG_CLOCK / (32.0 * 440.0 * 2.0 ** ((pitch - 69.0) / 12.0))), 1, 1023)
    phase = numpy.cumsum(PSG_CLOCK / (32.0 * dividers)) / SAMPLE_RATE
    square = numpy.where(phase % 1.0 < 0.5, 1.0, -1.0)
    return square * _psg_frame_envelope(times, seconds * 0.6, seconds * 0.5, 0.0, seconds * 0.2) * volume


def _lfsr_white_noise() -> numpy.ndarray:
    """The Sega PSG's 16-bit white-noise LFSR (taps on bits 0 and 3), one full period."""
    register = 0x8000
    bits = []
    for _ in range(0xFFFF):
        bits.append(register & 1)
        feedback = (register & 1) ^ ((register >> 3) & 1)
        register = (register >> 1) | (feedback << 15)
    return numpy.array(bits, dtype=float) * 2.0 - 1.0


_NOISE_PERIOD = _lfsr_white_noise()


@lru_cache(maxsize=None)
def psg_noise(length: float, volume: float = 1.0, shift_rate: float = 28000.0, decay: float = 0.03,
              offset: int = 0) -> numpy.ndarray:
    """PSG noise clocked at `shift_rate` Hz (driven by tone 3, as drivers did for hats)."""
    times = numpy.arange(int((length + 0.02) * SAMPLE_RATE)) / SAMPLE_RATE
    indices = (numpy.floor(times * shift_rate).astype(int) + offset) % len(_NOISE_PERIOD)
    noise = _NOISE_PERIOD[indices]
    output = noise * _psg_frame_envelope(times, length, decay, 0.0, 0.01) * volume
    output.setflags(write=False)
    return output


# --------------------------------------------------------------------------- PCM drums

_DRUM_RANDOM = numpy.random.default_rng(1992)


def _pcm(samples: numpy.ndarray, rate: float = 17500.0) -> numpy.ndarray:
    """Through the DAC like a driver would play it: sample-and-hold at `rate`, 8 bits."""
    times = numpy.arange(len(samples)) / SAMPLE_RATE
    held_indices = numpy.minimum((numpy.floor(times * rate) / rate * SAMPLE_RATE).astype(int), len(samples) - 1)
    held = samples[held_indices]
    quantized = numpy.round(numpy.clip(held, -1.0, 1.0) * 127.0) / 127.0
    fade_samples = int(0.003 * SAMPLE_RATE)
    quantized[-fade_samples:] *= numpy.linspace(1.0, 0.0, fade_samples)
    quantized.setflags(write=False)
    return quantized


def _noise(seconds: float) -> numpy.ndarray:
    return _DRUM_RANDOM.uniform(-1.0, 1.0, int(seconds * SAMPLE_RATE))


def _smooth(samples: numpy.ndarray, width: int) -> numpy.ndarray:
    return numpy.convolve(samples, numpy.ones(width) / width, mode="same")


def make_kick() -> numpy.ndarray:
    """A fat 909-ish kick: a sine dropping from ~160 Hz to 46 Hz, a click, soft saturation."""
    times = numpy.arange(int(0.42 * SAMPLE_RATE)) / SAMPLE_RATE
    frequency = 46.0 + 115.0 * numpy.exp(-times / 0.03) + 260.0 * numpy.exp(-times / 0.004)
    body = numpy.sin(2 * numpy.pi * numpy.cumsum(frequency) / SAMPLE_RATE)
    body *= numpy.exp(-times / 0.22) * numpy.clip(times / 0.0015, 0.0, 1.0)
    click = numpy.diff(_noise(0.42), prepend=0.0) * numpy.exp(-times / 0.002) * 0.35
    return _pcm(numpy.tanh(2.2 * (body + click)) * 0.95)


def make_snare() -> numpy.ndarray:
    """Two-tone body (190/340 Hz) under a bright noise burst."""
    times = numpy.arange(int(0.3 * SAMPLE_RATE)) / SAMPLE_RATE
    tone = (numpy.sin(2 * numpy.pi * 190.0 * times) * 0.7 + numpy.sin(2 * numpy.pi * 340.0 * times) * 0.35)
    tone *= numpy.exp(-times / 0.045)
    noise = numpy.diff(_noise(0.3), prepend=0.0) * 0.6 + _smooth(_noise(0.3), 3) * 0.6
    noise *= numpy.exp(-times / 0.085)
    return _pcm(numpy.tanh(1.6 * (tone + noise)) * 0.85)


def make_clap() -> numpy.ndarray:
    """Three quick noise slaps, then a short tail, band-limited around 1-2 kHz."""
    times = numpy.arange(int(0.35 * SAMPLE_RATE)) / SAMPLE_RATE
    band = _smooth(numpy.diff(_noise(0.35), prepend=0.0), 6)
    envelope = numpy.zeros_like(times)
    for burst_start in (0.0, 0.009, 0.019):
        envelope += numpy.where(times >= burst_start, numpy.exp(-(times - burst_start) / 0.006), 0.0)
    envelope += numpy.where(times >= 0.028, numpy.exp(-(times - 0.028) / 0.11), 0.0) * 0.8
    return _pcm(numpy.tanh(3.0 * band * envelope) * 0.8)


def make_tight_kick() -> numpy.ndarray:
    """A dry, tight electronic kick (the 80s drum machine): short, a higher punch, a click."""
    times = numpy.arange(int(0.24 * SAMPLE_RATE)) / SAMPLE_RATE
    frequency = 55.0 + 140.0 * numpy.exp(-times / 0.018) + 400.0 * numpy.exp(-times / 0.003)
    body = numpy.sin(2 * numpy.pi * numpy.cumsum(frequency) / SAMPLE_RATE)
    body *= numpy.exp(-times / 0.09) * numpy.clip(times / 0.001, 0.0, 1.0)
    click = numpy.diff(_noise(0.24), prepend=0.0) * numpy.exp(-times / 0.0015) * 0.5
    return _pcm(numpy.tanh(2.6 * (body + click)) * 0.95)


def make_gated_snare(gate_seconds: float = 0.17) -> numpy.ndarray:
    """The 80s gated-reverb snare: a snappy hit, then a dense, bright room tail that holds
    up for `gate_seconds` and is cut off hard by the gate, sampled into the DAC."""
    seconds = gate_seconds + 0.05
    times = numpy.arange(int(seconds * SAMPLE_RATE)) / SAMPLE_RATE
    tone = (numpy.sin(2 * numpy.pi * 200.0 * times) * 0.7 + numpy.sin(2 * numpy.pi * 330.0 * times) * 0.3)
    tone *= numpy.exp(-times / 0.04)
    snap = numpy.diff(_noise(seconds), prepend=0.0) * numpy.exp(-times / 0.03) * 0.7
    room = _smooth(_noise(seconds), 2) * (0.55 + 0.1 * numpy.exp(-times / 0.05))
    gate = numpy.clip((gate_seconds - times) / 0.008, 0.0, 1.0)
    return _pcm(numpy.tanh(1.7 * (tone + snap + room * gate)) * 0.85, rate=13000.0)


def make_tom(start_frequency: float) -> numpy.ndarray:
    """An electronic tom: a sine sweeping down a fifth, a pinch of noise."""
    times = numpy.arange(int(0.36 * SAMPLE_RATE)) / SAMPLE_RATE
    frequency = start_frequency * (0.66 + 0.34 * numpy.exp(-times / 0.06))
    body = numpy.sin(2 * numpy.pi * numpy.cumsum(frequency) / SAMPLE_RATE) * numpy.exp(-times / 0.16)
    body += _smooth(_noise(0.36), 2) * numpy.exp(-times / 0.01) * 0.3
    return _pcm(numpy.tanh(1.8 * body) * 0.85)


# --------------------------------------------------------------------------- mixing and output


def _circular_filter(signal: numpy.ndarray, low_pass_hz: float, high_pass_hz: float) -> numpy.ndarray:
    """Zero-phase filtering of a looping buffer through its spectrum (no seam, no clicks)."""
    spectrum = numpy.fft.rfft(signal)
    frequencies = numpy.fft.rfftfreq(len(signal), 1.0 / SAMPLE_RATE)
    low_pass = 1.0 / numpy.sqrt(1.0 + (frequencies / low_pass_hz) ** 4)          # 2nd-order Butterworth
    high_pass = (frequencies / high_pass_hz) ** 2 / numpy.sqrt(1.0 + (frequencies / high_pass_hz) ** 4)
    return numpy.fft.irfft(spectrum * low_pass * high_pass, n=len(signal))


def _soft_limit(signal: numpy.ndarray, threshold: float, ceiling: float) -> numpy.ndarray:
    magnitude = numpy.abs(signal)
    over = magnitude > threshold
    limited = magnitude.copy()
    limited[over] = threshold + (ceiling - threshold) * numpy.tanh((magnitude[over] - threshold) / (ceiling - threshold))
    return numpy.sign(signal) * limited


def master(tracks, target_rms_db: float = -14.0, peak_db: float = -1.5,
           low_pass_hz: float = 11000.0) -> numpy.ndarray:
    """Pans and sums the tracks, filters, sets the loudness and limits the peaks. Returns (n, 2).
    One-shots should end in silence (their own fade), since the filtering is circular."""
    sample_count = tracks[0].sample_count
    left = numpy.zeros(sample_count)
    right = numpy.zeros(sample_count)
    for track in tracks:
        angle = (track.pan + 1.0) * numpy.pi / 4.0       # constant-power pan
        left += track.buffer * track.gain * numpy.cos(angle) * numpy.sqrt(2.0)
        right += track.buffer * track.gain * numpy.sin(angle) * numpy.sqrt(2.0)
    left = _circular_filter(left, low_pass_hz, 25.0)
    right = _circular_filter(right, low_pass_hz, 25.0)
    stereo = numpy.stack([left, right], axis=1)
    ceiling = 10.0 ** (peak_db / 20.0)
    # loudness first, then the limiter takes the drum peaks; a few passes because limiting lowers the RMS
    for _ in range(4):
        rms = numpy.sqrt(numpy.mean(stereo ** 2))
        stereo *= 10.0 ** (target_rms_db / 20.0) / rms
        limited = _soft_limit(stereo, ceiling * 0.72, ceiling)
        if abs(20 * numpy.log10(numpy.sqrt(numpy.mean(limited ** 2))) - target_rms_db) < 0.1:
            break
    return limited


def tape_stop(stereo: numpy.ndarray, at_seconds: float, seconds: float) -> numpy.ndarray:
    """A tape stop: from `at_seconds` the music slows down to a standstill over `seconds`
    (the pitch dropping with it), then silence until the end of that stretch; what follows
    plays on as it was."""
    start = int(at_seconds * SAMPLE_RATE)
    length = int(seconds * SAMPLE_RATE)
    end = min(start + length, len(stereo))
    if start >= end:
        return stereo
    progress = numpy.arange(end - start) / length
    speed = (1.0 - progress) ** 2
    read_at = start + numpy.cumsum(speed)
    result = stereo.copy()
    for channel in range(stereo.shape[1]):
        result[start:end, channel] = numpy.interp(read_at, numpy.arange(len(stereo)), stereo[:, channel])
    fade = numpy.clip((1.0 - progress) / 0.15, 0.0, 1.0)
    result[start:end] *= fade[:, None]
    return result


def write_ogg(path: str, stereo: numpy.ndarray, quality: float = 0.7) -> None:
    """Ogg Vorbis, what Godot imports as AudioStreamOggVorbis (needs soundfile: use render.sh)."""
    import soundfile
    with soundfile.SoundFile(path, "w", SAMPLE_RATE, 2, format="OGG", subtype="VORBIS",
                             compression_level=1.0 - quality) as ogg_file:
        chunk = 8192   # libsndfile's Vorbis encoder crashes on huge writes
        for start in range(0, len(stereo), chunk):
            ogg_file.write(stereo[start:start + chunk])
