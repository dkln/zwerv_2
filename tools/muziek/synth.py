"""The synth a composition in JSON describes (docs/MUZIEK_JSON.md, json_bron.py), built on the
rules of the Web Audio API, which the composer's tracker pages play with: oscillators (sine,
triangle, sawtooth, square) whose frequency is modulated (true FM: modulators with a ratio to
the note and an index that moves in time, modulating the carrier or each other), a vibrato, a
biquad filter whose frequency moves, an envelope, equal-power panning, drums made of tones and
filtered sample-and-hold noise, a master volume and a compressor.

Every value that moves is a "verloop" (an AudioParam's automation): points with a time, a
value and how the value gets there ("sprong" setValueAtTime, "lineair"
linearRampToValueAtTime, "exponentieel" exponentialRampToValueAtTime), as the Web Audio API
defines them. Times are seconds from the start of the note, or an expression with "noot" (the
time the note sounds): "noot*0.65", "max(0.01, noot-0.03)".

voice() one note of a channel, drum() one hit, render() the whole composition as its page
would play it (stereo, through the master volume and the compressor).
"""
import ast
import json
import math
from functools import lru_cache

import numpy

SAMPLE_RATE = 44100
## Oscillators are made at this many times the sample rate and brought down (their edges and
## the FM do not fold back), as the browser's band-limited oscillators avoid it.
OVERSAMPLING = 4
WAVES = {"sinus": "sine", "driehoek": "triangle", "zaagtand": "sawtooth", "blok": "square"}
WAYS = {"sprong": "set", "lineair": "lin", "exponentieel": "exp"}
FILTERS = {"laagdoorlaat": "lowpass", "hoogdoorlaat": "highpass"}
## The oscillators of a note run on this long after it (the page stops them a moment later).
DEFAULT_RUN_OUT = 0.02


# ----------------------------------------------------------------------------- WebAudio: the rules

def automation(events: list, count: int, rate: float) -> numpy.ndarray:
    """An AudioParam over `count` samples: `events` in the order they were called, ("set" /
    "lin" / "exp", value, seconds): setValueAtTime, linearRampToValueAtTime and
    exponentialRampToValueAtTime as the Web Audio API defines them (a ramp runs from the event
    before it; after the last event the value stays)."""
    out = numpy.empty(count)
    out[:] = events[0][1]
    previous_value = events[0][1]
    previous_time = events[0][2]
    for kind, value, time in events:
        start = min(count, max(0, int(math.ceil(previous_time * rate - 1e-9))))
        end = min(count, max(0, int(math.ceil(time * rate - 1e-9))))
        if kind != "set" and end > start and time > previous_time:
            progress = (numpy.arange(start, end) / rate - previous_time) / (time - previous_time)
            if kind == "lin":
                out[start:end] = previous_value + (value - previous_value) * progress
            else:
                out[start:end] = previous_value * (value / previous_value) ** progress
        out[end:] = value
        previous_value = value
        previous_time = time
    return out


def oscillator(kind: str, frequency: numpy.ndarray, rate: float) -> numpy.ndarray:
    """An OscillatorNode whose frequency (Hz, per sample: its own value plus what is connected
    to it) is given: the phase is the sum of it, so modulating the frequency is true FM. The
    shapes start as the standard says (at zero, rising; the square high first)."""
    phase = (numpy.cumsum(frequency) - frequency) / rate
    within = phase - numpy.floor(phase)
    if kind == "sine":
        return numpy.sin(2.0 * numpy.pi * within)
    if kind == "square":
        return numpy.where(within < 0.5, 1.0, -1.0)
    if kind == "sawtooth":
        shifted = within + 0.5
        return 2.0 * (shifted - numpy.floor(shifted)) - 1.0
    if kind == "triangle":
        shifted = within - 0.25
        return 4.0 * numpy.abs(shifted - numpy.floor(shifted) - 0.5) - 1.0
    raise ValueError(kind)


def to_sample_rate(signal: numpy.ndarray) -> numpy.ndarray:
    """From the oversampled rate down to the sample rate (band-limited: through the spectrum)."""
    out_count = len(signal) // OVERSAMPLING
    signal = signal[:out_count * OVERSAMPLING]
    if out_count < 2:
        return numpy.zeros(out_count)
    spectrum = numpy.fft.rfft(signal)
    return numpy.fft.irfft(spectrum[:out_count // 2 + 1], out_count) / OVERSAMPLING


def biquad(signal: numpy.ndarray, kind: str, frequency, quality_db: float = 1.0) -> numpy.ndarray:
    """A BiquadFilterNode ("lowpass" or "highpass") with the coefficients of the Web Audio API
    (for these two the Q is in dB; its default is 1); `frequency` a number or an array (a
    frequency that moves: new coefficients every sample)."""
    count = len(signal)
    cutoff = numpy.clip(numpy.broadcast_to(numpy.asarray(frequency, dtype=float), (count,)), 1.0, SAMPLE_RATE / 2.0 - 1.0)
    omega = 2.0 * numpy.pi * cutoff / SAMPLE_RATE
    alpha = numpy.sin(omega) / (2.0 * 10.0 ** (quality_db / 20.0))
    cosine = numpy.cos(omega)
    if kind == "lowpass":
        b0, b1 = (1.0 - cosine) / 2.0, 1.0 - cosine
    elif kind == "highpass":
        b0, b1 = (1.0 + cosine) / 2.0, -(1.0 + cosine)
    else:
        raise ValueError(kind)
    a0 = 1.0 + alpha
    b0, b1, a1, a2 = (b0 / a0).tolist(), (b1 / a0).tolist(), (-2.0 * cosine / a0).tolist(), ((1.0 - alpha) / a0).tolist()
    samples = signal.tolist()
    out = [0.0] * count
    x1 = x2 = y1 = y2 = 0.0
    for index in range(count):
        x0 = samples[index]
        y0 = b0[index] * (x0 + x2) + b1[index] * x1 - a1[index] * y1 - a2[index] * y2
        out[index] = y0
        x2, x1, y2, y1 = x1, x0, y1, y0
    return numpy.array(out)


def pan_gains(pan: float) -> tuple:
    """A StereoPannerNode on a mono signal: equal power, (left, right)."""
    angle = (pan + 1.0) / 2.0 * numpy.pi / 2.0
    return math.cos(angle), math.sin(angle)


class Compressor:
    """The DynamicsCompressorNode, after the algorithm the Chromium browsers use (the Web Audio
    API leaves it to the browser): a soft knee curve, the gain followed with the attack and an
    adaptive release in blocks of 32 samples, 6 ms of look-ahead, and the make-up gain
    ((1 / the curve at full scale) ^ 0.6). An approximation: written from the description of
    that algorithm, not checked against a browser."""

    def __init__(self, threshold: float = -24.0, knee: float = 30.0, ratio: float = 12.0, attack: float = 0.003,
                 release: float = 0.25) -> None:
        self.threshold_db = threshold
        self.knee_db = knee
        self.ratio = ratio
        self.attack = max(0.001, attack)
        self.release = release
        self.linear_threshold = 10.0 ** (threshold / 20.0)
        self.knee_threshold_db = threshold + knee
        self.knee_threshold = 10.0 ** (self.knee_threshold_db / 20.0)
        self.slope = 1.0 / ratio
        self.curve_k = self._k_at_slope(self.slope)
        self.knee_end_db = 20.0 * math.log10(self._knee_curve(self.knee_threshold, self.curve_k))
        self.makeup = (1.0 / self.saturate(1.0)) ** 0.6

    def _knee_curve(self, level: float, curve_k: float) -> float:
        if level < self.linear_threshold:
            return level
        return self.linear_threshold + (1.0 - math.exp(-curve_k * (level - self.linear_threshold))) / curve_k

    def _k_at_slope(self, wanted: float) -> float:
        low, high, curve_k = 0.1, 10000.0, 5.0
        level = self.knee_threshold
        for _attempt in range(15):
            level_db = 20.0 * math.log10(level)
            beyond_db = 20.0 * math.log10(level * 1.001)
            out_db = 20.0 * math.log10(self._knee_curve(level, curve_k))
            beyond_out_db = 20.0 * math.log10(self._knee_curve(level * 1.001, curve_k))
            slope = (beyond_out_db - out_db) / (beyond_db - level_db)
            if slope < wanted:
                high = curve_k
            else:
                low = curve_k
            curve_k = math.sqrt(low * high)
        return curve_k

    def saturate(self, level: float) -> float:
        if level < self.knee_threshold:
            return self._knee_curve(level, self.curve_k)
        level_db = 20.0 * math.log10(level)
        return 10.0 ** ((self.knee_end_db + self.slope * (level_db - self.knee_threshold_db)) / 20.0)

    def process(self, stereo: numpy.ndarray) -> numpy.ndarray:
        """The compressed signal, the look-ahead taken out again (it starts where it started)."""
        rate = float(SAMPLE_RATE)
        release_frames = rate * self.release
        y1, y2, y3, y4 = (release_frames * zone for zone in (0.09, 0.16, 0.42, 0.98))
        k_a = 0.9999999999999998 * y1 + 1.8432219684323923e-16 * y2 - 1.9373394351676423e-16 * y3 + 8.824516011816245e-18 * y4
        k_b = -1.5788320352845888 * y1 + 2.3305837032074286 * y2 - 0.9141194204840429 * y3 + 0.1623677525612032 * y4
        k_c = 0.5334142869106424 * y1 - 1.272736789213631 * y2 + 0.9258856042207512 * y3 - 0.18656310191776226 * y4
        k_d = 0.08783463138207234 * y1 - 0.1694162967925622 * y2 + 0.08588057951595272 * y3 - 0.00429891410546283 * y4
        k_e = -0.042416883008123074 * y1 + 0.1115693827987602 * y2 - 0.09764676325265872 * y3 + 0.028494263462021576 * y4
        attack_frames = self.attack * rate
        saturation_release_frames = 0.0025 * rate
        loudest = numpy.abs(stereo).max(axis=1).tolist()
        count = len(loudest)
        gains = [1.0] * count
        detector = 0.0
        gain = 1.0
        worst_attack_db = 2.0
        saturate = self.saturate
        half_pi = math.pi / 2.0
        for block in range(0, count, 32):
            wanted = math.asin(min(1.0, max(0.0, detector))) / half_pi
            releasing = wanted > gain
            if releasing:
                difference_db = max(-12.0, min(0.0, 20.0 * math.log10(max(gain, 1e-9) / max(wanted, 1e-9))))
                zone = 0.25 * (difference_db + 12.0)
                frames = k_a + zone * (k_b + zone * (k_c + zone * (k_d + zone * k_e)))
                step = 10.0 ** (5.0 / frames / 20.0)
            else:
                difference_db = 20.0 * math.log10(max(wanted, 1e-9) / max(gain, 1e-9))
                if worst_attack_db == -1 or worst_attack_db < -difference_db:
                    worst_attack_db = -difference_db
                step = 1.0 - (0.25 / max(0.5, worst_attack_db)) ** (1.0 / attack_frames)
            if releasing:
                worst_attack_db = -1
            for index in range(block, min(count, block + 32)):
                level = loudest[index]
                attenuation = 1.0 if level < 0.0001 else saturate(level) / level
                attenuation_db = max(2.0, -20.0 * math.log10(attenuation))
                if attenuation > detector:
                    detector += (attenuation - detector) * (10.0 ** (attenuation_db / saturation_release_frames / 20.0) - 1.0)
                else:
                    detector = attenuation
                detector = min(1.0, detector)
                if releasing:
                    gain = min(1.0, gain * step)
                else:
                    gain += (wanted - gain) * step
                gains[index] = math.sin(half_pi * gain) * self.makeup
        delay = int(0.006 * rate)
        applied = numpy.array(gains)
        out = numpy.zeros_like(stereo)
        # the gain at a moment works on the signal of 6 ms earlier; with that delay taken out
        # again: the signal at n gets the gain of n + delay
        out[:count - delay] = stereo[:count - delay] * applied[delay:, None]
        out[count - delay:] = stereo[count - delay:] * applied[-1]
        return out



# ----------------------------------------------------------------------------- times and verlopen

def seconds_of(moment, note_seconds: float) -> float:
    """A time of a verloop: a number of seconds, or an expression with "noot" (+ - * /, min, max)."""
    if isinstance(moment, (int, float)):
        return float(moment)

    def value(node) -> float:
        if isinstance(node, ast.Expression):
            return value(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return float(node.value)
        if isinstance(node, ast.Name) and node.id == "noot":
            return note_seconds
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return -value(node.operand)
        if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div)):
            left, right = value(node.left), value(node.right)
            if isinstance(node.op, ast.Add):
                return left + right
            if isinstance(node.op, ast.Sub):
                return left - right
            if isinstance(node.op, ast.Mult):
                return left * right
            return left / right
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in ("min", "max") and node.args:
            found = [value(argument) for argument in node.args]
            return min(found) if node.func.id == "min" else max(found)
        raise ValueError(f"tijd {moment!r}: alleen getallen, 'noot', + - * /, min() en max()")

    try:
        return value(ast.parse(str(moment), mode="eval"))
    except SyntaxError:
        raise ValueError(f"tijd {moment!r}: geen getal of uitdrukking met 'noot'") from None


def verloop_events(points: list, key: str, note_seconds: float, scale: float = 1.0, other: dict = None) -> list:
    """The points of a verloop as automation events. `key` names the value in a point; `other`
    {key: scale} are other ways to give it (a modulator index as "index" times the note, or
    "hz" as it is)."""
    events = []
    for point in points:
        if key in point:
            found = point[key] * scale
        else:
            name = next(name for name in (other or {}) if name in point)
            found = point[name] * other[name]
        events.append((WAYS[point.get("naar", "sprong")], found, seconds_of(point.get("op", 0), note_seconds)))
    return events


def _alternating(value, index: int, default: float) -> float:
    """A setting that is one number, or a list that takes turns (per chord note, per step)."""
    if value is None:
        return default
    if isinstance(value, (list, tuple)):
        return float(value[index % len(value)])
    return float(value)


def envelope_points(envelope: dict) -> list:
    """The verloop of an envelope: its own "verloop", or the short form (docs/MUZIEK_JSON.md):
    from nearly nothing in `attack` seconds to `niveau`; with `sustain_op` falling to
    `sustain` at that part of the note and then away to its end; else held, set to `sustain`
    `release` seconds before the end, and away."""
    if "verloop" in envelope:
        return envelope["verloop"]
    level = envelope.get("niveau", 0.2)
    points = [{"op": 0, "niveau": 0.001}, {"op": envelope.get("attack", 0.005), "niveau": level, "naar": "lineair"}]
    sustain = envelope.get("sustain", level)
    if "sustain_op" in envelope:
        points.append({"op": f"noot*{envelope['sustain_op']}", "niveau": sustain, "naar": "exponentieel"})
        points.append({"op": "noot", "niveau": 0.0001, "naar": "exponentieel"})
    else:
        points.append({"op": f"max(0.01, noot-{envelope.get('release', 0.03)})", "niveau": sustain})
        points.append({"op": "noot", "niveau": 0.0005, "naar": "exponentieel"})
    return points


def index_points(modulator: dict) -> list:
    """The verloop of a modulator's index: its own "index_verloop", or the short form: `index`
    [begin, end] (times the note's frequency) over `tijd` seconds (or "noot"), exponentially
    (an end of 0: down to 1 Hz)."""
    if "index_verloop" in modulator:
        return modulator["index_verloop"]
    index = modulator.get("index", [1.0, 1.0])
    if isinstance(index, (int, float)):
        index = [index, index]
    last = {"op": modulator.get("tijd", "noot"), "naar": "exponentieel"}
    last.update({"index": index[1]} if index[1] > 0 else {"hz": 1.0})
    return [{"op": 0, "index": index[0]}, last]


def _modulation_order(modulators: list) -> list:
    """The modulators in an order in which each comes after the ones that modulate it."""
    order = []
    visiting = set()

    def visit(index: int) -> None:
        if index in order:
            return
        if index in visiting:
            raise ValueError("de modulatoren moduleren elkaar in een kring")
        visiting.add(index)
        for other, modulator in enumerate(modulators):
            if modulator.get("moduleert", "drager") == index:
                visit(other)
        order.append(index)

    for index in range(len(modulators)):
        visit(index)
    return order


def _decimated(signal: numpy.ndarray) -> numpy.ndarray:
    """Down to the sample rate; silence added behind first, so a sound that ends abruptly does
    not ring around to its start."""
    padded = numpy.concatenate([signal, numpy.zeros(64 * OVERSAMPLING)])
    return to_sample_rate(padded)[:len(signal) // OVERSAMPLING]


def _read_only(samples: numpy.ndarray) -> numpy.ndarray:
    samples.setflags(write=False)
    return samples


@lru_cache(maxsize=None)
def _voice(sound_text: str, hz: float, note_seconds: float, volume: float, index: int) -> numpy.ndarray:
    sound = json.loads(sound_text)
    rate = float(SAMPLE_RATE * OVERSAMPLING)
    count = max(1, int(round((note_seconds + sound.get("uitloop", DEFAULT_RUN_OUT)) * rate)))
    modulators = sound.get("modulatoren", [])
    signals = {}
    for number in _modulation_order(modulators):
        modulator = modulators[number]
        frequency = numpy.full(count, hz * modulator.get("verhouding", 1.0)) if "hz" not in modulator else numpy.full(count, float(modulator["hz"]))
        for other, source in enumerate(modulators):
            if source.get("moduleert", "drager") == number:
                frequency = frequency + signals[other]
        depth = automation(verloop_events(index_points(modulator), "index", note_seconds, hz, {"hz": 1.0}), count, rate)
        signals[number] = oscillator(WAVES[modulator.get("golfvorm", "sinus")], frequency, rate) * depth
    carrier_hz = hz * _alternating(sound.get("drager_ontstemming"), index, 1.0)
    if "hz_verloop" in sound:
        # a drum's tone: its own pitch that moves, whatever the note
        moving = automation(verloop_events(sound["hz_verloop"], "hz", note_seconds), count, rate)
    else:
        moving = None
    modulation = sum((signals[number] for number, modulator in enumerate(modulators)
                      if modulator.get("moduleert", "drager") == "drager"), numpy.zeros(count))
    vibrato = sound.get("vibrato")
    if vibrato:
        depth = automation([("set", 0.0, 0.0), ("lin", float(vibrato["diepte_hz"]),
                                                min(vibrato.get("vertraging", 0.0), note_seconds * 0.5) or 1e-6)], count, rate)
        modulation = modulation + oscillator("sine", numpy.full(count, float(vibrato["hz"])), rate) * depth
    carriers = numpy.zeros(count)
    for voice_number in range(int(sound.get("stemmen", 1))):
        base = (moving if moving is not None else carrier_hz) * sound.get("ontstemming", 1.0) ** voice_number
        carriers += oscillator(WAVES[sound.get("drager", "sinus")], base + modulation, rate)
    out = _decimated(carriers)
    own_rate = float(SAMPLE_RATE)
    filtering = sound.get("filter")
    if filtering:
        points = filtering.get("hz_verloop")
        if points is None:
            span = filtering["hz"] if isinstance(filtering["hz"], (list, tuple)) else [filtering["hz"], filtering["hz"]]
            points = [{"op": 0, "hz": span[0]}, {"op": filtering.get("tijd", "noot"), "hz": span[1], "naar": "exponentieel"}]
        cutoff = automation(verloop_events(points, "hz", note_seconds), len(out), own_rate)
        out = biquad(out, FILTERS[filtering.get("soort", "laagdoorlaat")], cutoff, filtering.get("q_db", 1.0))
    level = automation(verloop_events(envelope_points(sound.get("omhullende", {})), "niveau", note_seconds, volume), len(out), own_rate)
    return _read_only(out * level)


def voice(sound: dict, hz: float, note_seconds: float, volume: float = 1.0, index: int = 0) -> numpy.ndarray:
    """One note of a "klank" (docs/MUZIEK_JSON.md): mono at 44100 Hz, before the panner. `index`:
    which of the turns of an alternating setting (the place in a chord). Cached; read-only."""
    alternates = isinstance(sound.get("drager_ontstemming"), (list, tuple))
    return _voice(json.dumps(sound, sort_keys=True), round(float(hz), 4), round(float(note_seconds), 5), round(float(volume), 5),
                  index % len(sound["drager_ontstemming"]) if alternates else 0)


@lru_cache(maxsize=None)
def noise_buffer(noise_text: str) -> numpy.ndarray:
    """The noise the drums play: `seconden` of +`niveau` or -`niveau` at random, held
    `vasthouden_samples` samples at a time (a page draws it anew every time; here the draw of `zaad`)."""
    noise = json.loads(noise_text)
    random = numpy.random.default_rng(int(noise.get("zaad", 1992)))
    hold = max(1, int(noise.get("vasthouden_samples", 3)))
    count = int(SAMPLE_RATE * float(noise.get("seconden", 1.5)))
    level = float(noise.get("niveau", 0.9))
    return _read_only(numpy.repeat(numpy.where(random.random(count // hold + 1) > 0.5, level, -level), hold)[:count])


@lru_cache(maxsize=None)
def _filtered_noise(noise_text: str, seconds: float, kind: str, cutoff: float, quality_db: float) -> numpy.ndarray:
    """The start of the noise buffer (every hit plays it from its beginning) through a filter."""
    samples = noise_buffer(noise_text)[:max(1, int(round(seconds * SAMPLE_RATE)))]
    return _read_only(biquad(samples, kind, cutoff, quality_db) if kind else samples.copy())


def drum_layers(drum: dict) -> list:
    """The layers of a drum: its own "lagen", or the short form by its soort (docs/MUZIEK_JSON.md)."""
    if "lagen" in drum:
        return drum["lagen"]
    kind = drum.get("soort", "")
    length = float(drum.get("duur", 0.15))
    level = float(drum.get("niveau", 0.3))
    fall = [{"op": 0, "niveau": level}, {"op": length, "niveau": 0.001, "naar": "exponentieel"}]
    if kind == "kick":
        return [{"toon": "sinus", "duur": length + 0.01, "niveau_verloop": fall,
                 "hz_verloop": [{"op": 0, "hz": drum.get("van_hz", 160)}, {"op": length, "hz": drum.get("naar_hz", 40), "naar": "exponentieel"}]}]
    if kind == "tom":
        start = float(drum.get("van_hz", 160))
        return [{"toon": "sinus", "duur": length + 0.01, "niveau_verloop": fall,
                 "hz_verloop": [{"op": 0, "hz": start}, {"op": length, "hz": drum.get("naar_hz", start * 0.48), "naar": "exponentieel"}]}]
    noise = {"ruis": True, "duur": length + 0.01,
             "niveau_verloop": [{"op": 0, "niveau": level * (0.95 if kind == "snare" else 1.0)},
                                {"op": length, "niveau": 0.001, "naar": "exponentieel"}]}
    if "ruis_hoogdoorlaat_hz" in drum:
        noise["filter"] = {"soort": "hoogdoorlaat", "hz": drum["ruis_hoogdoorlaat_hz"]}
    layers = [noise]
    if "toon_hz" in drum:
        tone = drum["toon_hz"] if isinstance(drum["toon_hz"], (list, tuple)) else [drum["toon_hz"], drum["toon_hz"]]
        layers.insert(0, {"toon": "driehoek", "duur": length * 0.63,
                          "hz_verloop": [{"op": 0, "hz": tone[0]}, {"op": length * 0.42, "hz": tone[1], "naar": "exponentieel"}],
                          "niveau_verloop": [{"op": 0, "niveau": level}, {"op": length * 0.58, "niveau": 0.001, "naar": "exponentieel"}]})
    return layers


@lru_cache(maxsize=None)
def _drum(drum_text: str, noise_text: str, volume: float, stretch: float) -> numpy.ndarray:
    drum = json.loads(drum_text)
    layers = []
    for layer in drum_layers(drum):
        seconds = float(layer.get("duur", 0.15)) * stretch
        points = [dict(point, op=seconds_of(point.get("op", 0), seconds) * stretch) for point in layer["niveau_verloop"]]
        if layer.get("ruis"):
            filtering = layer.get("filter") or {}
            samples = _filtered_noise(noise_text, seconds, FILTERS[filtering["soort"]] if filtering else "",
                                      float(filtering.get("hz", 0.0)), float(filtering.get("q_db", 1.0)))
            layers.append(samples * automation(verloop_events(points, "niveau", seconds, volume), len(samples), float(SAMPLE_RATE)))
        else:
            sound = {"drager": layer.get("toon", "sinus"), "hz_verloop": layer["hz_verloop"], "uitloop": 0.0,
                     "modulatoren": layer.get("modulatoren", []), "omhullende": {"verloop": points}}
            layers.append(_voice(json.dumps(sound, sort_keys=True), 0.0, round(seconds, 5), round(volume, 5), 0))
    out = numpy.zeros(max(len(layer) for layer in layers))
    for layer in layers:
        out[:len(layer)] += layer
    return _read_only(out)


def drum(drum_sound: dict, noise: dict, volume: float = 1.0, stretch: float = 1.0) -> numpy.ndarray:
    """One hit of a drum (docs/MUZIEK_JSON.md, "drums"): mono at 44100 Hz. `stretch` makes it
    that many times as long (a crash made of an open hi-hat)."""
    return _drum(json.dumps(drum_sound, sort_keys=True), json.dumps(noise or {}, sort_keys=True), round(float(volume), 5), float(stretch))


# ----------------------------------------------------------------------------- the whole composition

def note_hz(note: str) -> float:
    """"C#4" -> Hz (A4 = 440)."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semitone = names[note[0].upper()]
    rest = note[1:]
    while rest and rest[0] in "#b":
        semitone += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 440.0 * 2 ** (((int(rest) + 1) * 12 + semitone - 69) / 12.0)


def plays(cell) -> bool:
    return isinstance(cell, str) and cell not in ("---", "===", "")


def hold_steps(track: list, step: int) -> int:
    """How many steps the note on `step` sounds: itself and the "---" after it."""
    steps = 1
    for later in range(step + 1, len(track)):
        if track[later] != "---":
            break
        steps += 1
    return steps


def chord_at(bar: dict, step: int) -> list:
    """The notes of the chord that holds on a step of a bar."""
    current = []
    for chord in sorted(bar.get("akkoorden", []), key=lambda chord: chord.get("stap", 0)):
        if chord.get("stap", 0) <= step:
            current = chord.get("noten", [])
    return current


def step_seconds(source: dict) -> float:
    beats = source.get("maatsoort", [4, 4])[0] * 4.0 / source.get("maatsoort", [4, 4])[1]
    return 60.0 / source["tempo"] * beats / source.get("stappen_per_maat", 16)


def piece_seconds(source: dict) -> float:
    return len(source["maten"]) * source.get("stappen_per_maat", 16) * step_seconds(source)


def channel_notes(source: dict, name: str) -> list:
    """Every note of a channel as (seconds from the start, [note names], seconds it sounds,
    its step in the bar): what render() plays and the composition file must hold."""
    channel = source["kanalen"][name]
    step = step_seconds(source)
    steps_per_bar = source.get("stappen_per_maat", 16)
    found = []
    for bar_index, bar in enumerate(source["maten"]):
        track = bar.get("sporen", {}).get(name)
        if not track:
            continue
        for index, cell in enumerate(track):
            time = (bar_index * steps_per_bar + index) * step
            if channel.get("rol") == "akkoorden":
                if cell == 1:
                    found.append((time, list(chord_at(bar, index)), step * channel.get("akkoordduur_stappen", 2.0), index))
            elif plays(cell):
                held = hold_steps(track, index) if channel.get("aanhouden", True) else 1
                found.append((time, [cell], step * held, index))
    return found


def render(source: dict, tail_seconds: float = 0.0, only: tuple = None, mastered: bool = True) -> numpy.ndarray:
    """The composition played once: stereo (n, 2) at 44100 Hz. Every channel with a `pan`
    goes through an equal-power panner (a list of pans takes turns: per note of a chord, else
    per step), one without goes to both sides as it is; then (`mastered`) the master volume and
    the compressor. `only`: just these channels."""
    count = int(round((piece_seconds(source) + tail_seconds) * SAMPLE_RATE))
    out = numpy.zeros((count, 2))

    def add(samples: numpy.ndarray, time: float, pan) -> None:
        start = int(round(time * SAMPLE_RATE))
        samples = samples[:max(0, count - start)]
        left, right = (1.0, 1.0) if pan is None else pan_gains(pan)
        out[start:start + len(samples), 0] += samples * left
        out[start:start + len(samples), 1] += samples * right

    step = step_seconds(source)
    steps_per_bar = source.get("stappen_per_maat", 16)
    for name, channel in source["kanalen"].items():
        if only is not None and name not in only:
            continue
        volume = float(channel.get("volume", 1.0))
        pan = channel.get("pan")
        if channel.get("rol") == "drums":
            for bar_index, bar in enumerate(source["maten"]):
                for index, cell in enumerate(bar.get("sporen", {}).get(name, [])):
                    if plays(cell):
                        add(drum(source["drums"][cell], source.get("ruis", {}), volume), (bar_index * steps_per_bar + index) * step,
                            None if pan is None else _alternating(pan, index, 0.0))
            continue
        gate = float(channel.get("nootduur", 1.0))
        for time, notes, seconds, index in channel_notes(source, name):
            for place, note in enumerate(notes):
                turn = place if channel.get("rol") == "akkoorden" else index
                add(voice(channel["klank"], note_hz(note), seconds * gate, volume, place), time,
                    None if pan is None else _alternating(pan, turn, 0.0))
    if not mastered:
        return out
    master = source.get("master", {})
    out = out * float(master.get("volume", 1.0))
    settings = master.get("compressor")
    if settings:
        out = Compressor(settings.get("drempel_db", -24.0), settings.get("knie_db", 30.0), settings.get("verhouding", 12.0),
                         settings.get("attack", 0.003), settings.get("release", 0.25)).process(out)
    return out
