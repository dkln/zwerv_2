"""The two sound chips of the Mega Drive imitated from their registers, so a patch (fm.FmVoice:
the FM patches a composition gives itself, tijdlijn.py) sounds as the console plays it.

YM2612 (FM, six channels): four operators per channel in the eight algorithms, the feedback
of operator 1, per operator the multiple, the detune, the total level and the envelope
(attack, decay to the sustain level, sustain rate, release; rates with key scaling), key-on
and key-off per operator, the frequency exactly as F-number and block give it, channel 3's
special mode (a frequency per operator), the panning, and the DAC on channel 6. Each channel
is clipped and stepped as the chip's 9-bit output does.
SN76489 (PSG): three square waves (period -> frequency), the noise (white or periodic, its
shift register, at one of the three fixed rates or the rate of tone 3), sixteen volumes of 2 dB.

Not cycle-exact: the envelopes are worked out as curves (the same times and levels as the
chip's counters give, without their steps), the sine and the level are not in the chip's 10-bit
tables, and the LFO (vibrato and tremolo), SSG-EG and the CSM mode are not imitated (unsupported()
says when a tune uses them). The level of the PSG against the FM is the usual emulator setting
(PSG_LEVEL), not measured from a console.

Everything is made at the chip's own rate (the clock / 144, 53267 Hz) and then brought to
44100 Hz.
"""
import math
from functools import lru_cache

import numpy

OUTPUT_RATE = 44100
TWO_PI = 2.0 * math.pi
## One PSG channel at full volume against one FM channel at full level (as Genesis Plus GX
## sets them: PSG 2800 at 150 %, an FM channel 8191).
PSG_LEVEL = 0.5
## The envelope counts in steps of 0.09375 dB, 0 (loud) to 1023 (silent).
ENVELOPE_SILENT = 1023.0
ENVELOPE_DB = 0.09375
## The detune of an operator: added to its phase step, by key code (rows: detune 0-3).
DETUNE_STEPS = (
    (0,) * 32,
    (0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 8, 8),
    (1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14, 16, 16, 16, 16),
    (2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 22, 22, 22),
)
## The operators that sound (the carriers) in each algorithm (operators 0-3).
CARRIERS = ((3,), (3,), (3,), (3,), (1, 3), (1, 2, 3), (1, 2, 3), (0, 1, 2, 3))
## Which operators modulate operator 2, 3 and 4 in each algorithm (operator 1 only itself).
MODULATORS = (
    ((0,), (1,), (2,)), ((), (0, 1), (2,)), ((), (1,), (0, 2)), ((0,), (), (1, 2)),
    ((0,), (), (2,)), ((0,), (0,), (0,)), ((0,), (), ()), ((), (), ()),
)
ATTACK, DECAY, SUSTAIN, RELEASE = range(4)
## Register groups 0x30-0x80 by their operator setting.
OPERATOR_SETTINGS = {0x30: "mul_dt", 0x40: "tl", 0x50: "ar_rs", 0x60: "dr", 0x70: "sr", 0x80: "rr_sl"}


def native_rate(fm_clock: float) -> float:
    return fm_clock / 144.0


def key_code(f_number: int, block: int) -> int:
    """The 5-bit key code (block and the top of the F-number): what detune and key scaling go by."""
    bit11 = (f_number >> 10) & 1
    bit10 = (f_number >> 9) & 1
    bit9 = (f_number >> 8) & 1
    bit8 = (f_number >> 7) & 1
    note = (bit11 & (bit10 | bit9 | bit8)) | ((1 - bit11) & bit10 & bit9 & bit8)
    return (block << 2) | (bit11 << 1) | note


def envelope_slope(rate: int, scaling: int) -> float:
    """Envelope steps per chip sample at this rate (0-31 doubled, or the release's) with the
    key scaling added: the chip's counter adds (4 + rate % 4) / 8 every 2^(11 - rate / 4)
    envelope ticks (a tick is three samples)."""
    if rate <= 0:
        return 0.0
    rate = min(63, rate + scaling)
    if rate < 2:
        return 0.0
    if rate >= 60:
        return 8.0 / 3.0
    return (4 + (rate & 3)) / 8.0 * 2.0 ** ((rate >> 2) - 11) / 3.0


class _Operator:
    def __init__(self) -> None:
        self.mul = 1
        self.detune = 0
        self.tl = 0
        self.rs = 0
        self.ar = 31
        self.dr = 0
        self.sr = 0
        self.sl = 0
        self.rr = 15
        self.keyed = False
        self.stage = RELEASE
        self.level = ENVELOPE_SILENT      # the envelope, in its steps
        self.phase = 0.0                  # cycles

    def phase_step(self, f_number: int, block: int) -> float:
        """Cycles per chip sample."""
        code = key_code(f_number, block)
        step = ((f_number << block) >> 1) + (-1 if self.detune & 4 else 1) * DETUNE_STEPS[self.detune & 3][code]
        step = max(0, step)
        return (step * self.mul if self.mul else step / 2.0) / 1048576.0

    def key(self, on: bool, code: int) -> None:
        if on and not self.keyed:
            self.phase = 0.0
            self.stage = ATTACK
            if min(63, self.ar * 2 + (code >> (3 - self.rs))) >= 62 and self.ar:
                self.level = 0.0
                self.stage = DECAY
        elif not on and self.keyed:
            self.stage = RELEASE
        self.keyed = on

    def envelope(self, count: int, code: int) -> numpy.ndarray:
        """The envelope over the next `count` samples (in its steps, the total level not yet added)."""
        out = numpy.empty(count, dtype=numpy.float32)
        scaling = code >> (3 - self.rs)
        done = 0
        while done < count:
            left = count - done
            if self.stage == ATTACK:
                slope = envelope_slope(self.ar * 2, scaling) / 16.0
                if slope <= 0.0:
                    out[done:] = self.level
                    break
                # the attack closes a sixteenth of what is left every step: an exponential
                samples_to_top = math.log(self.level + 1.0) / slope
                steps = min(left, max(1, int(math.ceil(samples_to_top))))
                curve = (self.level + 1.0) * numpy.exp(-slope * numpy.arange(1, steps + 1)) - 1.0
                out[done:done + steps] = numpy.maximum(curve, 0.0)
                done += steps
                self.level = max(0.0, float(curve[-1]))
                if samples_to_top <= steps:
                    self.level = 0.0
                    self.stage = DECAY
                continue
            if self.stage == DECAY:
                target = 992.0 if self.sl == 15 else self.sl * 32.0
                if self.level >= target:
                    self.stage = SUSTAIN
                    continue
                slope = envelope_slope(self.dr * 2, scaling)
            else:
                target = ENVELOPE_SILENT
                slope = envelope_slope(self.sr * 2 if self.stage == SUSTAIN else self.rr * 4 + 2, scaling)
            if slope <= 0.0 or self.level >= target:
                out[done:] = self.level
                break
            steps = min(left, max(1, int(math.ceil((target - self.level) / slope))))
            line = self.level + slope * numpy.arange(1, steps + 1)
            out[done:done + steps] = numpy.minimum(line, target)
            done += steps
            self.level = min(target, float(line[-1]))
            if self.level >= target and self.stage == DECAY:
                self.stage = SUSTAIN
        return out


def _feedback_operator(phase: numpy.ndarray, level: numpy.ndarray, feedback: int) -> numpy.ndarray:
    """Operator 1: it modulates itself with the mean of its last two samples (sample by sample)."""
    if not feedback:
        return level * numpy.sin(TWO_PI * phase)
    reach = TWO_PI * 2.0 ** (feedback - 7)
    angles = (TWO_PI * phase.astype(numpy.float64)).tolist()
    levels = level.tolist()
    out = [0.0] * len(angles)
    sine = math.sin
    last = 0.0
    before_last = 0.0
    for index, own_level in enumerate(levels):
        if own_level:
            value = own_level * sine(angles[index] + (last + before_last) * reach)
        else:
            value = 0.0
        out[index] = value
        before_last = last
        last = value
    return numpy.array(out)


def fm_channel(events: list, count: int) -> tuple:
    """One FM channel over `count` chip samples: (mono, left on/off, right on/off). `events`:
    (sample, name, ...) in order of time: ("set", operator, setting, value) with the settings
    of OPERATOR_SETTINGS as the register holds them; ("algorithm", algorithm, feedback);
    ("frequency", F-number, block); ("operator_frequency", operator, F-number, block) and
    ("special", on) for channel 3; ("key", mask of operators); ("pan", left, right)."""
    operators = [_Operator() for _operator in range(4)]
    phases = numpy.zeros((4, count), dtype=numpy.float32)
    levels = numpy.zeros((4, count), dtype=numpy.float32)
    left = numpy.ones(count, dtype=numpy.float32)
    right = numpy.ones(count, dtype=numpy.float32)
    frequency = (0, 0)
    operator_frequencies = [(0, 0)] * 4
    special = False
    wirings = [(0, 0, 0)]                 # (from sample, algorithm, feedback)
    position = 0

    def frequency_of(operator: int) -> tuple:
        return operator_frequencies[operator] if special and operator < 3 else frequency

    def fill(until: int) -> None:
        span = until - position
        steps = numpy.arange(span, dtype=numpy.float64)
        for index, operator in enumerate(operators):
            f_number, block = frequency_of(index)
            step = operator.phase_step(f_number, block)
            phases[index, position:until] = (operator.phase + step * steps) % 1.0
            operator.phase = (operator.phase + step * span) % 1.0
            total = operator.envelope(span, key_code(f_number, block)) + operator.tl * 8.0
            levels[index, position:until] = numpy.where(total >= ENVELOPE_SILENT, 0.0,
                                                        10.0 ** (-total * ENVELOPE_DB / 20.0))

    for event in events:
        sample = min(count, max(0, event[0]))
        if sample > position:
            fill(sample)
            position = sample
        name = event[1]
        if name == "set":
            operator = operators[event[2]]
            setting, value = event[3], event[4]
            if setting == "mul_dt":
                operator.mul = value & 0x0F
                operator.detune = (value >> 4) & 0x07
            elif setting == "tl":
                operator.tl = value & 0x7F
            elif setting == "ar_rs":
                operator.ar = value & 0x1F
                operator.rs = value >> 6
            elif setting == "dr":
                operator.dr = value & 0x1F
            elif setting == "sr":
                operator.sr = value & 0x1F
            elif setting == "rr_sl":
                operator.rr = value & 0x0F
                operator.sl = value >> 4
        elif name == "algorithm":
            wirings.append((position, event[2], event[3]))
        elif name == "frequency":
            frequency = (event[2], event[3])
        elif name == "operator_frequency":
            operator_frequencies[event[2]] = (event[3], event[4])
        elif name == "special":
            special = bool(event[2])
        elif name == "key":
            for index, operator in enumerate(operators):
                operator.key(bool(event[2] & (1 << index)), key_code(*frequency_of(index)))
        elif name == "pan":
            left[position:] = 1.0 if event[2] else 0.0
            right[position:] = 1.0 if event[3] else 0.0
    if count > position:
        fill(count)
    mono = numpy.zeros(count)
    for index, (start, algorithm, feedback) in enumerate(wirings):
        end = wirings[index + 1][0] if index + 1 < len(wirings) else count
        if end <= start:
            continue
        outputs = [_feedback_operator(phases[0, start:end], levels[0, start:end], feedback)]
        for operator in (1, 2, 3):
            modulation = sum((outputs[source] for source in MODULATORS[algorithm][operator - 1]), 0.0)
            # a modulator at full level moves the phase four cycles either way
            outputs.append(levels[operator, start:end] * numpy.sin(
                TWO_PI * (phases[operator, start:end].astype(numpy.float64) + 4.0 * modulation)))
        mono[start:end] = sum(outputs[operator] for operator in CARRIERS[algorithm])
    # the channel's output: clipped at full scale, in the 9 bits of the chip's DAC
    mono = numpy.floor(numpy.clip(mono, -1.0, 1.0) * 256.0) / 256.0
    return mono, left, right


# ----------------------------------------------------------------------------- SN76489

def _shift_register_bits(white: bool) -> numpy.ndarray:
    """The output of the 16-bit noise shift register from its reset, one period (Sega's: white
    noise taps bits 0 and 3)."""
    bits = []
    register = 0x8000
    while True:
        bits.append(register & 1)
        fed_back = ((register ^ (register >> 3)) & 1) if white else (register & 1)
        register = (register >> 1) | (fed_back << 15)
        if register == 0x8000 or len(bits) >= 70000:
            break
    return numpy.array(bits, dtype=numpy.float64) * 2.0 - 1.0


@lru_cache(maxsize=None)
def _noise_bits(white: bool) -> numpy.ndarray:
    return _shift_register_bits(white)


def _square_area(cycles: numpy.ndarray) -> numpy.ndarray:
    """The integral of a square wave (+1 the first half of a cycle, -1 the second)."""
    within = cycles - numpy.floor(cycles)
    return numpy.where(within < 0.5, within, 1.0 - within)


def psg(writes: list, count: int, psg_clock: float, rate: float) -> numpy.ndarray:
    """The SN76489 over `count` samples at `rate`: `writes` are (sample, byte) as written to it."""
    out = numpy.zeros(count)
    periods = [0, 0, 0]
    attenuations = [15, 15, 15, 15]
    tone_phases = [0.0, 0.0, 0.0]
    noise_control = 0
    noise_position = 0.0
    latch = (0, 0)
    position = 0

    def volume(channel: int) -> float:
        return 0.0 if attenuations[channel] >= 15 else PSG_LEVEL * 10.0 ** (-2.0 * attenuations[channel] / 20.0)

    def tone_hz(channel: int) -> float:
        return psg_clock / (32.0 * max(1, periods[channel]))

    def fill(until: int) -> None:
        nonlocal noise_position
        span = until - position
        steps = numpy.arange(span, dtype=numpy.float64)
        for channel in range(3):
            step = tone_hz(channel) / rate
            if volume(channel) > 0.0:
                if periods[channel] <= 1:
                    out[position:until] += volume(channel)       # held high: the way samples are played
                else:
                    # each sample the mean of the square over its width (no aliasing of the edges)
                    start = tone_phases[channel] + step * steps
                    out[position:until] += volume(channel) * (_square_area(start + step) - _square_area(start)) / step
            tone_phases[channel] = (tone_phases[channel] + step * span) % 1.0
        shift_hz = tone_hz(2) if noise_control & 3 == 3 else psg_clock / (32.0 * (0x10 << (noise_control & 3)))
        shift_step = shift_hz / rate
        if volume(3) > 0.0:
            bits = _noise_bits(bool(noise_control & 4))
            out[position:until] += volume(3) * bits[(noise_position + shift_step * steps).astype(numpy.int64) % len(bits)]
        noise_position += shift_step * span

    for sample, value in writes:
        sample = min(count, max(0, sample))
        if sample > position:
            fill(sample)
            position = sample
        if value & 0x80:
            latch = ((value >> 5) & 3, (value >> 4) & 1)
        channel, is_volume = latch
        if is_volume:
            attenuations[channel] = value & 0x0F
        elif channel == 3:
            noise_control = value & 0x07
            noise_position = 0.0          # writing the control register resets the shift register
        elif value & 0x80:
            periods[channel] = (periods[channel] & 0x3F0) | (value & 0x0F)
        else:
            periods[channel] = (periods[channel] & 0x00F) | ((value & 0x3F) << 4)
    if count > position:
        fill(count)
    return out


# ----------------------------------------------------------------------------- resampling

def resample(signal: numpy.ndarray, from_rate: float, to_rate: float = OUTPUT_RATE) -> numpy.ndarray:
    """The signal at another sample rate (band-limited: through its spectrum)."""
    if len(signal) < 2:
        return numpy.zeros(int(round(len(signal) * to_rate / from_rate)))
    out_count = int(round(len(signal) * to_rate / from_rate))
    spectrum = numpy.fft.rfft(signal)
    kept = numpy.zeros(out_count // 2 + 1, dtype=complex)
    bins = min(len(kept), len(spectrum))
    kept[:bins] = spectrum[:bins]
    return numpy.fft.irfft(kept, out_count) * (out_count / len(signal))


def f_number_for(hz: float, clock: float) -> tuple:
    """(F-number, block) nearest to a frequency: the lowest block the F-number fits in, as
    sound drivers choose them."""
    for block in range(8):
        f_number = int(round(hz * 144.0 * 2 ** (21 - block) / clock))
        if f_number < 1290 or block == 7:
            return min(2047, max(1, f_number)), block
    return 2047, 7


def voice_events(voice) -> list:
    """The events that set a channel to a patch (fm.FmVoice: operators 1-4 in order)."""
    events = [(0, "algorithm", voice.algorithm, voice.feedback)]
    for operator in range(4):
        events += [
            (0, "set", operator, "mul_dt", (voice.detunes[operator] << 4) | voice.multiples[operator]),
            (0, "set", operator, "tl", voice.total_levels[operator]),
            (0, "set", operator, "ar_rs", (voice.rate_scalings[operator] << 6) | voice.attack_rates[operator]),
            (0, "set", operator, "dr", voice.decay_rates[operator]),
            (0, "set", operator, "sr", voice.sustain_rates[operator]),
            (0, "set", operator, "rr_sl", (voice.sustain_levels[operator] << 4) | voice.release_rates[operator]),
        ]
    return events


## A note of a voice rings at most this long after its key-off.
LONGEST_RELEASE = 1.5


def _trimmed(signal: numpy.ndarray, keep: int) -> numpy.ndarray:
    """Without the silence at its end (at least `keep` samples stay)."""
    loud = numpy.nonzero(numpy.abs(signal) > 1e-4)[0]
    last = int(loud[-1]) + 1 if len(loud) else 0
    return signal[:max(keep, min(len(signal), last + 64))]


@lru_cache(maxsize=None)
def voice_note(voice, clock: float, hz: float, seconds: float) -> numpy.ndarray:
    """One note of a patch on one FM channel: key-on, key-off after `seconds`, its release.
    Mono at 44100 Hz (read-only: it is cached)."""
    rate = native_rate(clock)
    key_off = max(1, int(round(seconds * rate)))
    count = key_off + int(LONGEST_RELEASE * rate)
    f_number, block = f_number_for(hz, clock)
    events = voice_events(voice) + [(0, "frequency", f_number, block), (0, "key", 0x0F), (key_off, "key", 0)]
    mono, _left, _right = fm_channel(events, count)
    result = _trimmed(resample(mono, rate), int(seconds * OUTPUT_RATE))
    result[-32:] *= numpy.linspace(1.0, 0.0, 32)
    result.setflags(write=False)
    return result


def voice_sweep(voice, clock: float, from_hz: float, to_hz: float, seconds: float, fall: float = 0.35) -> numpy.ndarray:
    """A note of a patch whose pitch falls from one frequency to another (quickly at first:
    `fall` of the time to get halfway) and is then released: a drum made of a voice."""
    rate = native_rate(clock)
    key_off = max(1, int(round(seconds * rate)))
    events = voice_events(voice) + [(0, "frequency", *f_number_for(from_hz, clock)), (0, "key", 0x0F)]
    moves = max(2, int(seconds / 0.002))
    for move in range(1, moves):
        progress = move / moves
        hz = to_hz + (from_hz - to_hz) * 0.5 ** (progress / fall)
        events.append((int(progress * key_off), "frequency", *f_number_for(hz, clock)))
    events.append((key_off, "key", 0))
    mono, _left, _right = fm_channel(events, key_off + int(0.4 * rate))
    return _trimmed(resample(mono, rate), int(seconds * OUTPUT_RATE))


def noise_hit(steps: list, psg_clock: float, white: bool = True, divider: int = 0) -> numpy.ndarray:
    """A hit on the PSG noise channel: `steps` are (seconds, attenuation 0-15) one after the
    other (one step: a gated burst; falling volumes: a decay in the chip's 2 dB steps)."""
    rate = 53267.0
    writes = [(0, 0xE0 | (4 if white else 0) | divider)]
    time = 0.0
    for seconds, attenuation in steps:
        writes.append((int(time * rate), 0xF0 | attenuation))
        time += seconds
    writes.append((int(time * rate), 0xFF))
    return resample(psg(writes, int(time * rate) + 64, psg_clock, rate), rate)
