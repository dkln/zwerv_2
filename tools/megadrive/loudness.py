"""One loudness standard for every audio file of the game (music, stingers, sound effects, cries).

Measured as the ear hears it (ITU-R BS.1770 / EBU R128: K-weighting, LUFS), so a deep engine
and a bright bell of the same number sound equally loud:

* things that last (music, stingers, loops): the integrated loudness (gated, as ffmpeg's
  `ebur128` and every loudness meter measure it) at TARGET_LUFS;
* one-shots (effects, cries, shouts): their loudest moment, the momentary loudness (400 ms
  window), at TARGET_LUFS, so a short knock is as loud at its peak as a loop is on average.

Sample peaks stay under CEILING_DB (a soft knee, only on the peaks that would cross it).
With every source at one level, the game sets how loud something is (volume_db) and nothing else.

Check the files: ffmpeg -i file.ogg -af ebur128 -f null -   (I: for loops, max M: for one-shots)
"""
import numpy

SAMPLE_RATE = 44100
TARGET_LUFS = -16.0
CEILING_DB = -1.0
MOMENTARY_WINDOW = 0.4
GATE_HOP = 0.1
ABSOLUTE_GATE_LUFS = -70.0
RELATIVE_GATE_LU = -10.0


def ear_weighting(signal: numpy.ndarray) -> numpy.ndarray:
    """One channel as loud as the ear hears it (the K-weighting of BS.1770: the lows count less,
    everything above 2 kHz 4 dB more), for measuring only. Zero-padded, so nothing wraps around."""
    padded_length = len(signal) + SAMPLE_RATE // 2
    frequencies = numpy.fft.rfftfreq(padded_length, 1.0 / SAMPLE_RATE)
    inverse_z = numpy.exp(-2j * numpy.pi * frequencies / SAMPLE_RATE)

    def biquad(numerator, denominator):
        return numpy.polyval(numerator[::-1], inverse_z) / numpy.polyval(denominator[::-1], inverse_z)

    shelf_k = numpy.tan(numpy.pi * 1681.97 / SAMPLE_RATE)
    shelf_q = 0.7071752
    gain_high = 10.0 ** (3.99984 / 20.0)
    gain_band = gain_high ** 0.4996667741545416
    scale = 1.0 + shelf_k / shelf_q + shelf_k ** 2
    shelf = biquad([(gain_high + gain_band * shelf_k / shelf_q + shelf_k ** 2) / scale, 2.0 * (shelf_k ** 2 - gain_high) / scale,
                    (gain_high - gain_band * shelf_k / shelf_q + shelf_k ** 2) / scale],
                   [1.0, 2.0 * (shelf_k ** 2 - 1.0) / scale, (1.0 - shelf_k / shelf_q + shelf_k ** 2) / scale])
    pass_k = numpy.tan(numpy.pi * 38.13547 / SAMPLE_RATE)
    pass_q = 0.5003270
    scale = 1.0 + pass_k / pass_q + pass_k ** 2
    high_pass = biquad([1.0, -2.0, 1.0], [1.0, 2.0 * (pass_k ** 2 - 1.0) / scale, (1.0 - pass_k / pass_q + pass_k ** 2) / scale])
    spectrum = numpy.fft.rfft(signal, n=padded_length) * numpy.abs(shelf * high_pass)
    return numpy.fft.irfft(spectrum, n=padded_length)[:len(signal)]


def _channels(signal: numpy.ndarray) -> list:
    return [signal] if signal.ndim == 1 else [signal[:, channel] for channel in range(signal.shape[1])]


def _window_powers(signal: numpy.ndarray, hop_seconds: float) -> numpy.ndarray:
    """Weighted mean square of every 400 ms window (summed over the channels), one per hop.
    A sound shorter than a window counts as one window with silence after it, as a meter does."""
    window = int(MOMENTARY_WINDOW * SAMPLE_RATE)
    hop = max(1, int(hop_seconds * SAMPLE_RATE))
    total = None
    for channel in _channels(signal):
        weighted = ear_weighting(channel)
        if len(weighted) < window:
            weighted = numpy.pad(weighted, (0, window - len(weighted)))
        running = numpy.concatenate([[0.0], numpy.cumsum(weighted ** 2)])
        starts = numpy.arange(0, len(weighted) - window + 1, hop)
        powers = (running[starts + window] - running[starts]) / window
        total = powers if total is None else total + powers
    return total


def _to_lufs(power) -> float:
    return -0.691 + 10.0 * numpy.log10(power + 1e-12)


def integrated_lufs(signal: numpy.ndarray) -> float:
    """Integrated loudness (BS.1770-4: 400 ms blocks, 75 % overlap, absolute and relative gate)."""
    powers = _window_powers(signal, GATE_HOP)
    powers = powers[_to_lufs(powers) > ABSOLUTE_GATE_LUFS]
    if len(powers) == 0:
        return ABSOLUTE_GATE_LUFS
    relative_gate = _to_lufs(powers.mean()) + RELATIVE_GATE_LU
    return float(_to_lufs(powers[_to_lufs(powers) > relative_gate].mean()))


def loudest_momentary_lufs(signal: numpy.ndarray) -> float:
    """The loudest 400 ms of the sound (momentary loudness), in 10 ms steps."""
    return float(_to_lufs(_window_powers(signal, 0.01).max()))


def soft_limit(signal: numpy.ndarray, ceiling_db: float = CEILING_DB) -> numpy.ndarray:
    """Peaks bent softly under the ceiling; everything under 72 % of it stays untouched."""
    ceiling = 10.0 ** (ceiling_db / 20.0)
    threshold = ceiling * 0.72
    magnitude = numpy.abs(signal)
    over = magnitude > threshold
    limited = magnitude.copy()
    limited[over] = threshold + (ceiling - threshold) * numpy.tanh((magnitude[over] - threshold) / (ceiling - threshold))
    return numpy.sign(signal) * limited


def level(signal: numpy.ndarray, one_shot: bool, target_lufs: float = TARGET_LUFS,
          ceiling_db: float = CEILING_DB) -> numpy.ndarray:
    """The signal at the target loudness (loudest moment for a one-shot, integrated otherwise),
    peaks under the ceiling. A few passes, since limiting takes a little loudness off."""
    measure = loudest_momentary_lufs if one_shot else integrated_lufs
    ceiling = 10.0 ** (ceiling_db / 20.0)
    for attempt in range(4):
        signal = signal * 10.0 ** ((target_lufs - measure(signal)) / 20.0)
        if numpy.abs(signal).max() <= ceiling:
            break
        signal = soft_limit(signal, ceiling_db)
        if abs(measure(signal) - target_lufs) < 0.1:
            break
    return signal
