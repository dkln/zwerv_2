"""A tracker page (the HTML file a composer such as Gemini delivers: a score in JavaScript and
a WebAudio synth that plays it) as the source of a composition (docs/MUZIEK.md, "Een
tracker-HTML als compositie").

    tools/muziek/render.sh --tracker <bestand.html> [naam]              write composities/<naam>.py
    tools/muziek/render.sh --tracker <bestand.html> [naam] --toon       only show what the page holds
    tools/muziek/render.sh --tracker <bestand.html> [naam] --vergelijk  compare composities/<naam>.py with it
    tools/muziek/render.sh --tracker <bestand.html> [naam] --meet [wav] measure the rebuilt synth (and against a WAV)
    ... --overschrijf       replace an existing composities/<naam>.py

The score is not parsed but run: the page's own JavaScript (its patterns, build32BarScore,
getChordNotesForStep, countHoldSteps) is executed by node and read back as JSON (read), so
every bar is what the page itself plays. The synth is rebuilt here by hand, function by
function, from the page's play* functions (the section "the synth" below): the same
oscillators, FM ratios and index envelopes, filters, panning, levels, noise, master gain and
compressor, with the WebAudio rules for AudioParam automation, BiquadFilterNode,
StereoPannerNode and DynamicsCompressorNode. SYNTH_FINGERPRINT is the fingerprint of the
functions this was rebuilt from: a page whose synth differs is reported (its sounds must then
be rebuilt too).

The intro of the game is the page's 32 bars played once by this synth (render); the derived
pieces use the same voices as sounds (voice, drum: instruments.py "tracker_*", drum kit
"tracker").
"""
import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from functools import lru_cache

import numpy

HERE = os.path.dirname(os.path.abspath(__file__))
COMPOSITIONS_FOLDER = os.path.join(HERE, "composities")
SAMPLE_RATE = 44100
## Oscillators are made at this many times the sample rate and brought down (their edges and
## the FM do not fold back), as the browser's band-limited oscillators avoid it.
OVERSAMPLING = 4
## The page's functions the synth below was rebuilt from (sha1 of their text, white space
## collapsed): initAudioEngine up to getStepDuration, and scheduleStep.
SYNTH_FINGERPRINT = ""
## The channels of the page (CHANNELS: its index and its volume there), as the voices are named here.
CHANNEL_OF = {"bas": 0, "brass": 1, "lead": 2, "harmonie": 3, "arp": 4, "drums": 5}
DEFAULT_VOLUMES = (0.90, 0.78, 0.88, 0.72, 0.65, 0.92)
DEFAULT_MASTER_VOLUME = 0.85
## The page's drums and the drum names of notation.py.
DRUM_NAMES = {"KCK": "kick", "SNR": "snare", "CHH": "hihat", "OHH": "open", "TOM1": "tom_hoog", "TOM2": "tom_mid",
              "TOM3": "tom_laag", "TOM4": "tom_vloer"}
## scheduleStep: a note sounds this part of its steps (the brass a fixed 2.4 steps, the arp 0.9 of one).
GATES = {"bas": 0.95, "lead": 0.96, "harmonie": 0.96, "arp": 0.9, "brass": 1.0}
BRASS_STEPS = 2.4
SECTION_KINDS = (("INTRO", "intro"), ("VERSE", "thema"), ("THEME", "thema"), ("PRE", "opbouw"), ("BUILD", "opbouw"),
                 ("BRIDGE", "opbouw"), ("CHORUS", "refrein"), ("BREAK", "breakdown"), ("FINAL", "finale"),
                 ("OUTRO", "finale"), ("CLIMAX", "finale"))


# ----------------------------------------------------------------------------- reading the page

@dataclass
class Tracker:
    path: str
    title: str
    mode: str                     # the key as the page states it ("E MIXOLYDIAN"), or ""
    bpm: float
    master_volume: float
    volumes: tuple                # the six channel volumes
    bars: list                    # as the page's SCORE, with "chords" (per step) and "holds"
    patterns: dict                # {"bass": {name: row}, "arp": ..., "drums": ...}
    fingerprint: str
    warnings: list = field(default_factory=list)

    @property
    def step_seconds(self) -> float:
        return 60.0 / self.bpm / 4.0

    @property
    def seconds(self) -> float:
        return len(self.bars) * 16 * self.step_seconds


READ_BACK = """
const __holds = (row) => row.map((note, step) => (note && note !== '---' && note !== '===') ? countHoldSteps(row, step) : 0);
console.log(JSON.stringify({
    channels: CHANNELS.map(channel => ({code: channel.code, name: channel.name, vol: channel.vol})),
    patterns: {bass: BASS_PATTERNS, arp: ARP_PATTERNS, drums: DRUM_PATTERNS},
    bars: SCORE.map(bar => ({
        barNum: bar.barNum, section: bar.section, chordName: bar.chordName, stabTrig: bar.stabTrig,
        bass: bar.bass, lead: bar.lead, harm: bar.harm, arp: bar.arp, drums: bar.drums,
        chords: bar.bass.map((_note, step) => getChordNotesForStep(bar, step)),
        holds: {bass: __holds(bar.bass), lead: __holds(bar.lead), harm: __holds(bar.harm)},
    })),
}));
"""


def _between(text: str, start: str, end: str, path: str) -> str:
    first = text.find(start)
    last = text.find(end, first + 1) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"{path}: het script van de tracker heeft geen '{start}' ... '{end}' (een andere tracker: "
                         "pas tools/muziek/tracker.py aan op zijn namen)")
    return text[first:last]


def synth_fingerprint(html: str) -> str:
    start = html.find("function initAudioEngine")
    end = html.find("function getStepDuration")
    schedule = html.find("function scheduleStep")
    schedule_end = html.find("function advanceStep")
    if min(start, end, schedule, schedule_end) < 0:
        return ""
    text = html[start:end] + html[schedule:schedule_end]
    return hashlib.sha1(re.sub(r"\s+", " ", text).encode()).hexdigest()[:16]


def read(path: str) -> Tracker:
    """The page's score, by running its own JavaScript in node."""
    with open(path, encoding="utf-8") as html_file:
        html = html_file.read()
    program = (_between(html, "const NOTE_OFFSETS", "let audioCtx", path)
               + _between(html, "function countHoldSteps", "function scheduleStep", path) + READ_BACK)
    node = shutil.which("node")
    if not node:
        raise RuntimeError("node is nodig om de partituur van de tracker uit te voeren (niet gevonden)")
    with tempfile.TemporaryDirectory() as folder:
        script = os.path.join(folder, "partituur.js")
        with open(script, "w", encoding="utf-8") as script_file:
            script_file.write(program)
        done = subprocess.run([node, script], capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=30)
    if done.returncode != 0:
        raise RuntimeError(f"{path}: het script van de tracker liep niet in node:\n{done.stderr[-800:]}")
    data = json.loads(done.stdout)
    title = re.search(r"<title>(.*?)</title>", html, re.S)
    title_text = re.split(r"\s+[—–-]\s+", title.group(1).strip())[0] if title else ""
    mode = re.search(r"\b([A-G][#b]?) (MIXOLYDIAN|MAJOR|MINOR|DORIAN|AEOLIAN|IONIAN|PHRYGIAN|LYDIAN)\b", html, re.I)
    bpm = re.search(r"let bpm\s*=\s*([\d.]+)", html)
    master = re.search(r"let masterVolume\s*=\s*([\d.]+)", html)
    tracker = Tracker(path, title_text, mode.group(0).upper() if mode else "", float(bpm.group(1)) if bpm else 120.0,
                      float(master.group(1)) if master else DEFAULT_MASTER_VOLUME,
                      tuple(channel["vol"] for channel in data["channels"]), data["bars"], data["patterns"],
                      synth_fingerprint(html))
    if SYNTH_FINGERPRINT and tracker.fingerprint != SYNTH_FINGERPRINT:
        tracker.warnings.append(
            f"de synth van deze pagina ({tracker.fingerprint or 'niet gevonden'}) is een andere dan die waar "
            f"tools/muziek/tracker.py van nagebouwd is ({SYNTH_FINGERPRINT}): de klanken moeten opnieuw nagebouwd worden")
    if len(tracker.volumes) != 6:
        tracker.warnings.append(f"{len(tracker.volumes)} kanalen in plaats van 6")
    return tracker


@lru_cache(maxsize=None)
def tracker_in_compositions(file_name: str) -> Tracker:
    """The source next to the compositions: a tracker page (.html) or a composition in JSON
    (.json: json_bron.py), as a Tracker."""
    path = os.path.join(COMPOSITIONS_FOLDER, file_name)
    if file_name.endswith(".json"):
        import json_bron
        return json_bron.read(path)
    return read(path)


def note_hz(note: str) -> float:
    """The page's noteToFreq: "C#4" -> Hz, 0 for a rest."""
    match = re.match(r"^([A-G]#?)(-?\d)$", note or "")
    if not match:
        return 0.0
    semitone = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}[match.group(1)]
    midi = (int(match.group(2)) + 1) * 12 + semitone
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def plays(note: str) -> bool:
    return bool(note) and note not in ("---", "===")


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


# ----------------------------------------------------------------------------- the synth

def _times(seconds: float, rate: float) -> int:
    return max(1, int(round(seconds * rate)))


@lru_cache(maxsize=None)
def bass_voice(hz: float, seconds: float, volume: float) -> numpy.ndarray:
    """playFM1SlapBass: a sine carrier, FM'd by a triangle (1:1) that is FM'd by a sawtooth
    (2:1), both indexes falling fast (the twang). Mono, before the panner (pan 0)."""
    rate = float(SAMPLE_RATE * OVERSAMPLING)
    count = _times(seconds + 0.02, rate)
    second_index = automation([("set", hz * 2.2, 0.0), ("exp", 1.0, 0.045)], count, rate)
    second = oscillator("sawtooth", numpy.full(count, hz * 2.0), rate) * second_index
    first_index = automation([("set", hz * 3.8, 0.0), ("exp", hz * 0.4, 0.09)], count, rate)
    first = oscillator("triangle", hz + second, rate) * first_index
    carrier = oscillator("sine", hz + first, rate)
    level = automation([("set", 0.001, 0.0), ("lin", 0.36 * volume, 0.004), ("exp", 0.14 * volume, seconds * 0.65),
                        ("exp", 0.0001, seconds)], count, rate)
    return _read_only(to_sample_rate(carrier * level))


@lru_cache(maxsize=None)
def brass_voice(hz: float, index: int, seconds: float, volume: float) -> numpy.ndarray:
    """One note of playFM2BrassChord (`index`: its place in the chord: the even ones are tuned
    up and panned left, the odd ones down and right): a sawtooth FM'd by a sine (1:1), through
    a low-pass that opens and closes. Mono, before the panner (pan -0.45 / +0.45)."""
    rate = float(SAMPLE_RATE * OVERSAMPLING)
    count = _times(seconds + 0.02, rate)
    detune = 1.0025 if index % 2 == 0 else 0.9975
    modulation_index = automation([("set", hz * 0.5, 0.0), ("lin", hz * 2.6, 0.025), ("exp", hz * 0.6, seconds)], count, rate)
    modulator = oscillator("sine", numpy.full(count, hz), rate) * modulation_index
    carrier = to_sample_rate(oscillator("sawtooth", hz * detune + modulator, rate))
    cutoff = automation([("set", 900.0, 0.0), ("exp", 3800.0, 0.03), ("exp", 1400.0, seconds)], len(carrier), float(SAMPLE_RATE))
    level = automation([("set", 0.001, 0.0), ("lin", 0.11 * volume, 0.012), ("exp", 0.0008, seconds)], len(carrier),
                       float(SAMPLE_RATE))
    return _read_only(biquad(carrier, "lowpass", cutoff) * level)


@lru_cache(maxsize=None)
def lead_voice(hz: float, seconds: float, volume: float, harmony: bool) -> numpy.ndarray:
    """playFMLeadVoice: a sawtooth (the harmony: a triangle) FM'd by a sine an octave up, with
    a vibrato of 6.2 Hz that comes in. Mono, before the panner (pan -0.15, the harmony +0.38)."""
    rate = float(SAMPLE_RATE * OVERSAMPLING)
    count = _times(seconds + 0.02, rate)
    vibrato_depth = automation([("set", 0.0, 0.0), ("lin", 3.5 if harmony else 5.5, min(0.18, seconds * 0.5))], count, rate)
    vibrato = oscillator("sine", numpy.full(count, 6.2), rate) * vibrato_depth
    depth = 1.8 if harmony else 3.4
    modulation_index = automation([("set", hz * depth, 0.0), ("exp", hz * depth * 0.45, seconds)], count, rate)
    modulator = oscillator("sine", numpy.full(count, hz * 2.0), rate) * modulation_index
    carrier = oscillator("triangle" if harmony else "sawtooth", hz + vibrato + modulator, rate)
    top = (0.16 if harmony else 0.23) * volume
    level = automation([("set", 0.001, 0.0), ("lin", top, 0.008), ("set", top * 0.85, max(0.01, seconds - 0.03)),
                        ("exp", 0.0005, seconds)], count, rate)
    return _read_only(to_sample_rate(carrier * level))


@lru_cache(maxsize=None)
def arp_voice(hz: float, seconds: float, volume: float) -> numpy.ndarray:
    """playPSGSquareArp: two square waves, the second 0.4 % higher. Mono, before the panner
    (pan -0.5 on the even steps, +0.5 on the odd ones)."""
    rate = float(SAMPLE_RATE * OVERSAMPLING)
    count = _times(seconds, rate)
    squares = oscillator("square", numpy.full(count, hz), rate) + oscillator("square", numpy.full(count, hz * 1.004), rate)
    level = automation([("set", 0.001, 0.0), ("lin", 0.09 * volume, 0.003), ("exp", 0.0008, seconds * 0.92)], count, rate)
    return _read_only(to_sample_rate(squares * level))


@lru_cache(maxsize=None)
def noise_buffer() -> numpy.ndarray:
    """The page's noise: 1.5 s of +0.9 or -0.9 at random, held three samples at a time. The
    page draws it anew every time it is opened; here always the same draw."""
    random = numpy.random.default_rng(1992)
    count = int(SAMPLE_RATE * 1.5)
    held = numpy.where(random.random(count // 3 + 1) > 0.5, 0.9, -0.9)
    return numpy.repeat(held, 3)[:count]


@lru_cache(maxsize=None)
def _filtered_noise(seconds: float, cutoff: float) -> numpy.ndarray:
    """The start of the noise buffer (every hit plays it from its beginning) through a high-pass."""
    return _read_only(biquad(noise_buffer()[:_times(seconds, float(SAMPLE_RATE))], "highpass", cutoff))


@lru_cache(maxsize=None)
def drum(name: str, volume: float) -> numpy.ndarray:
    """playMegaDrum: one hit of KCK, SNR, CHH, OHH or TOM1-TOM4. Mono (straight to the master:
    the same left and right)."""
    rate = float(SAMPLE_RATE * OVERSAMPLING)
    if name == "KCK":
        count = _times(0.16, rate)
        thump = oscillator("sine", automation([("set", 165.0, 0.0), ("exp", 44.0, 0.065), ("exp", 32.0, 0.14)], count, rate), rate)
        click_count = _times(0.025, rate)
        click = numpy.zeros(count)
        click[:click_count] = oscillator("triangle", automation([("set", 520.0, 0.0), ("exp", 60.0, 0.02)], click_count, rate), rate)
        level = automation([("set", 0.55 * volume, 0.0), ("exp", 0.001, 0.15)], count, rate)
        return _read_only(to_sample_rate((thump + click) * level))
    if name == "SNR":
        count = _times(0.12, rate)
        body = oscillator("triangle", automation([("set", 210.0, 0.0), ("exp", 115.0, 0.08)], count, rate), rate)
        body = to_sample_rate(body * automation([("set", 0.38 * volume, 0.0), ("exp", 0.001, 0.11)], count, rate))
        noise = _filtered_noise(0.2, 650.0)
        noise = noise * automation([("set", 0.36 * volume, 0.0), ("set", 0.24 * volume, 0.09), ("exp", 0.001, 0.19)],
                                   len(noise), float(SAMPLE_RATE))
        out = noise.copy()
        out[:len(body)] += body
        return _read_only(out)
    if name in ("CHH", "OHH"):
        seconds = 0.16 if name == "OHH" else 0.045
        noise = _filtered_noise(seconds + 0.01, 5200.0)
        return _read_only(noise * automation([("set", (0.14 if name == "OHH" else 0.10) * volume, 0.0), ("exp", 0.0008, seconds)],
                                             len(noise), float(SAMPLE_RATE)))
    if name.startswith("TOM"):
        start = {"TOM1": 220.0, "TOM2": 175.0, "TOM3": 140.0, "TOM4": 105.0}.get(name, 160.0)
        count = _times(0.15, rate)
        modulator = oscillator("sine", numpy.full(count, start * 1.5), rate) * automation(
            [("set", start * 1.2, 0.0), ("exp", 1.0, 0.07)], count, rate)
        tone = oscillator("sine", automation([("set", start, 0.0), ("exp", start * 0.48, 0.13)], count, rate) + modulator, rate)
        return _read_only(to_sample_rate(tone * automation([("set", 0.42 * volume, 0.0), ("exp", 0.001, 0.14)], count, rate)))
    raise ValueError(name)


def _read_only(samples: numpy.ndarray) -> numpy.ndarray:
    samples.setflags(write=False)
    return samples


def voice(name: str, hz: float, seconds: float, index: int = 0, volume: float = None) -> numpy.ndarray:
    """One note of a voice of the page by its name here (bas, brass, lead, harmonie, arp), at
    the page's channel volume: for the sounds of instruments.py ("tracker_*")."""
    volume = DEFAULT_VOLUMES[CHANNEL_OF[name]] if volume is None else volume
    hz = round(hz, 4)
    seconds = round(seconds, 5)
    if name == "bas":
        return bass_voice(hz, seconds, volume)
    if name == "brass":
        return brass_voice(hz, index, seconds, volume)
    if name in ("lead", "harmonie"):
        return lead_voice(hz, seconds, volume, name == "harmonie")
    if name == "arp":
        return arp_voice(hz, seconds, volume)
    raise ValueError(name)


# ----------------------------------------------------------------------------- the whole score

def render(tracker: Tracker, tail_seconds: float = 0.0, only: tuple = None, mastered: bool = True) -> numpy.ndarray:
    """The page's score played once, as its scheduleStep plays it: stereo (n, 2) at 44100 Hz,
    through the master gain and the compressor (`mastered`). `only`: just these channels
    (bas, brass, lead, harmonie, arp, drums)."""
    step = tracker.step_seconds
    count = int(round((tracker.seconds + tail_seconds) * SAMPLE_RATE))
    out = numpy.zeros((count, 2))
    volumes = tracker.volumes

    def wanted(name: str) -> bool:
        return only is None or name in only

    def add(samples: numpy.ndarray, time: float, pan=None) -> None:
        start = int(round(time * SAMPLE_RATE))
        samples = samples[:max(0, count - start)]
        left, right = (1.0, 1.0) if pan is None else pan_gains(pan)
        out[start:start + len(samples), 0] += samples * left
        out[start:start + len(samples), 1] += samples * right

    for bar_index, bar in enumerate(tracker.bars):
        for step_index in range(16):
            time = (bar_index * 16 + step_index) * step
            if wanted("bas") and plays(bar["bass"][step_index]):
                seconds = round(step * bar["holds"]["bass"][step_index] * GATES["bas"], 5)
                add(bass_voice(round(note_hz(bar["bass"][step_index]), 4), seconds, volumes[0]), time, 0.0)
            if wanted("brass") and bar["stabTrig"][step_index] == 1:
                for index, note in enumerate(bar["chords"][step_index]):
                    if note_hz(note) > 0:
                        add(brass_voice(round(note_hz(note), 4), index % 2, round(step * BRASS_STEPS, 5), volumes[1]), time,
                            -0.45 if index % 2 == 0 else 0.45)
            for name, row, channel, pan in (("lead", "lead", 2, -0.15), ("harmonie", "harm", 3, 0.38)):
                if wanted(name) and plays(bar[row][step_index]):
                    seconds = round(step * bar["holds"][row][step_index] * GATES[name], 5)
                    add(lead_voice(round(note_hz(bar[row][step_index]), 4), seconds, volumes[channel], name == "harmonie"),
                        time, pan)
            if wanted("arp") and plays(bar["arp"][step_index]):
                add(arp_voice(round(note_hz(bar["arp"][step_index]), 4), round(step * GATES["arp"], 5), volumes[4]), time,
                    -0.5 if step_index % 2 == 0 else 0.5)
            hit = bar["drums"][step_index]
            if wanted("drums") and hit and hit != "---":
                add(drum(hit, volumes[5]), time)
    if not mastered:
        return out
    compressor = Compressor(threshold=-10.0, knee=12.0, ratio=4.0, attack=0.003, release=0.15)
    return compressor.process(out * tracker.master_volume)


# ----------------------------------------------------------------------------- the composition file

def section_kind(name: str) -> str:
    upper = name.upper()
    for word, kind in SECTION_KINDS:
        if word in upper:
            return kind
    return "opbouw"


def sections(tracker: Tracker) -> list:
    """The page's sections (a bar's "section"), each with the soort its name says."""
    found = []
    for bar in tracker.bars:
        if found and found[-1]["bron"] == bar["section"]:
            found[-1]["maten"] = (found[-1]["maten"][0], bar["barNum"])
        else:
            name = re.sub(r"^\d+:\s*", "", bar["section"]).strip()
            found.append({"bron": bar["section"], "naam": name, "soort": section_kind(bar["section"]),
                          "maten": (bar["barNum"], bar["barNum"])})
    return found


CHORD_SHAPES = {"": (0, 4, 7), "m": (0, 3, 7), "5": (0, 7), "6": (0, 4, 7, 9), "m6": (0, 3, 7, 9), "7": (0, 4, 7, 10),
                "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11), "add9": (0, 2, 4, 7), "sus2": (0, 2, 7), "sus4": (0, 5, 7),
                "7sus4": (0, 5, 7, 10), "dim": (0, 3, 6), "m7b5": (0, 3, 6, 10), "aug": (0, 4, 8)}
NOTE_CLASS_NAMES = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")


def _note_class(note: str) -> int:
    return NOTE_CLASS_NAMES.index(re.match(r"[A-G]#?", note).group(0))


def chord_from_notes(notes: list) -> str:
    """The name of a chord by its notes (the lowest the root), for a bar whose name on the page
    is not a chord name ("E Mixo Blues Riff")."""
    root = _note_class(notes[0])
    classes = {(_note_class(note) - root) % 12 for note in notes}
    for quality, shape in CHORD_SHAPES.items():
        if set(shape) == classes:
            return NOTE_CLASS_NAMES[root] + quality
    # no shape of its own: the one that shares most with it
    best = max(CHORD_SHAPES, key=lambda quality: (len(set(CHORD_SHAPES[quality]) & classes) - len(set(CHORD_SHAPES[quality]) - classes)))
    return NOTE_CLASS_NAMES[root] + best


def _readable_chord(text: str):
    """A chord name of the page in the notation's spelling, or None when it is not one."""
    text = re.sub(r"\(.*?\)", "", text).strip()
    if " / " in text:
        text = text.split(" / ")[-1].strip()      # "E5 / E7sus4": two names for one chord, the fuller one
    match = re.match(r"^([A-G][#b]?)([A-Za-z0-9#]*)(?:/([A-G][#b]?))?$", text)
    if not match or match.group(2) not in CHORD_SHAPES:
        return None
    return text


def bar_chords(bar: dict) -> str:
    """The bar's chords for "akkoord": the page's own names when it names as many chords as the
    bar has (the notes change at those places), else named by the notes the page plays."""
    spans = []
    for step_notes in bar["chords"]:
        if not spans or spans[-1] != step_notes:
            spans.append(step_notes)
    names = [_readable_chord(part) for part in bar["chordName"].split("->")]
    if len(names) == len(spans) and all(names):
        return " ".join(names)
    return " ".join(chord_from_notes(span) for span in spans)


def _row(notes: list) -> str:
    return " ".join(notes)


def composition_source(tracker: Tracker, name: str, title: str) -> str:
    """The text of composities/<naam>.py: the page's rows as they stand."""
    import vgm
    bars = tracker.bars
    found_sections = sections(tracker)
    constants = {}                # (part, row text) -> constant name
    order = []
    counters = {}
    pattern_names = {}
    for kind, part in (("bass", "BAS"), ("arp", "ARP"), ("drums", "DRUMS")):
        for pattern, row in tracker.patterns.get(kind, {}).items():
            pattern_names[(part, _row(row))] = f"{part}_{pattern}"

    def constant(part: str, row: list) -> str:
        key = (part, _row(row))
        if key not in constants:
            if key in pattern_names:
                constants[key] = pattern_names[key]
            else:
                counters[part] = counters.get(part, 0) + 1
                constants[key] = f"{part}_{vgm._letters(counters[part] - 1)}"
            order.append(key)
        return constants[key]

    entries = []
    for bar in bars:
        bar_entries = [f'"akkoord": "{bar_chords(bar)}"']
        bar_entries.append(f'"bas": {constant("BAS", bar["bass"])}')
        spans = []
        for step_notes in bar["chords"]:
            if not spans or spans[-1] != step_notes:
                spans.append(step_notes)
        if any(bar["stabTrig"]):
            chords = ", ".join(f'"{"+".join(span)}"' for span in spans)
            bar_entries.append(f'"brass": stabs("{" ".join(str(trigger) for trigger in bar["stabTrig"])}", {chords})')
        for part, row in (("lead", "lead"), ("harmonie", "harm")):
            if any(plays(note) for note in bar[row]):
                bar_entries.append(f'"{part}": {constant(part.upper(), bar[row])}')
        if any(plays(note) for note in bar["arp"]):
            bar_entries.append(f'"arp": {constant("ARP", bar["arp"])}')
        bar_entries.append(f'"drums": {constant("DRUMS", bar["drums"])}')
        entries.append((bar, bar_entries))
    key_tonic, key_mode = key_of(tracker)
    moments = vgm.moments_from_sections(found_sections, len(bars), 60.0 / tracker.bpm * 4)
    out = []
    from_json = tracker.path.endswith(".json")
    out += [f'"""{title}: de partituur van {os.path.basename(tracker.path)} (' + (
                "de compositie in JSON van de componist," if from_json else "de tracker-pagina van de componist: een partituur in JavaScript en een WebAudio-synth,"),
            ("letterlijk: elke maat en elk spoor zoals het JSON ze geeft (tools/muziek/json_bron.py)." if from_json else
             "letterlijk: het script van de pagina is door node uitgevoerd en maat voor maat uitgelezen (tools/muziek/tracker.py).")
            + " Elke rij hieronder is een rij",
            "van de bron: zestien stappen (zestienden), '---' houdt de noot aan of is een rust, '===' stopt hem.",
            "",
            "De intro van het spel is deze partituur, één keer gespeeld door de nagebouwde synth van de pagina (TRACKER",
            "hieronder); de andere stukken worden uit deze maten afgeleid en klinken met dezelfde stemmen",
            "(AFGELEIDE_KLANKEN).",
            "",
            f"Uit de pagina: de titel, het tempo ({tracker.bpm:g} BPM), de toonsoort ({tracker.mode or 'niet genoemd'}), de zes",
            "kanalen, de secties (de soort bij de naam: intro, verse = thema, chorus = refrein, breakdown, final = finale),",
            "de akkoordnamen (waar de pagina een maat geen akkoordnaam geeft, staat het akkoord dat zij daar speelt, met",
            "haar naam als commentaar) en alle noten. Niet uit de pagina: de MOMENTEN van de intro-beelden.",
            '"""',
            "from notation import drum_steps, stabs, steps",
            "",
            f"TITEL = {json.dumps(title, ensure_ascii=False)}",
            f"TEMPO = {tracker.bpm:g}",
            "TELLEN_PER_MAAT = 4",
            f'TOONSOORT = ("{key_tonic}", "{key_mode}")' + (f"   # de pagina: {tracker.mode}" if tracker.mode else ""),
            "",
            "# de pagina waar de intro uit gespeeld wordt (in deze map)",
            f'TRACKER = "{os.path.basename(tracker.path)}"',
            "",
            "# de zes kanalen van de pagina, elk in zijn eigen nagebouwde klank",
            "KLANKEN = {"]
    channel_names = {"bas": 0, "brass": 1, "lead": 2, "harmonie": 3, "arp": 4}
    for part, channel in channel_names.items():
        out.append(f'    "{part}": "tracker_{part}",'.ljust(36) + f"# kanaal {channel + 1}")
    out += ['    "drumstel": "tracker",'.ljust(36) + "# kanaal 6", "}", "",
            "# de afgeleide stukken in de stemmen van de pagina: elke klank die ze gebruiken wordt een stem van de",
            "# tracker, op de plek en het niveau van die klank; het drumstel dat van de tracker",
            "AFGELEIDE_KLANKEN = {"]
    voices = {"bas": "tracker_bas", "lead": "tracker_lead", "zacht": "tracker_harmonie", "vlak": "tracker_harmonie",
              "akkoord": "tracker_brass"}
    for kind, sounds in vgm.SOUND_KINDS.items():
        for sound in sounds:
            if sound.startswith("tracker_"):
                continue
            own = "tracker_arp" if sound == "psg_arp" else voices[kind]
            out.append(f'    "{sound}": "{own}={sound}",')
    for kit in vgm.DRUM_KIT_NAMES:
        if kit != "tracker":
            out.append(f'    "{kit}": "tracker",')
    out += ["}", "",
            "# waar de intro-beelden wisselen (scripts/ui/intro.gd): het logo op het thema, het verhaal een frase",
            "# later, dan het refrein, de breakdown en de finale; de rust op de laatste maat",
            "MOMENTEN = {" + ", ".join(f'"{moment}": {value!r}' for moment, value in moments.items()) + "}", ""]
    for part, row in order:
        helper = "drum_steps" if part == "DRUMS" else "steps"
        out.append(f'{constants[(part, row)]} = {helper}("{row}")')
    out += ["", "SECTIES = ["]
    for section in found_sections:
        out.append(f'    {{"naam": {json.dumps(section["naam"], ensure_ascii=False)}, "soort": "{section["soort"]}", '
                   f'"maten": {section["maten"]!r}}},')
    out += ["]", "", "MATEN = {"]
    for section in found_sections:
        out.append(f"    # {'-' * 66} {section['bron']}")
        for bar, bar_entries in entries:
            if section["maten"][0] <= bar["barNum"] <= section["maten"][1]:
                opening = f'    {bar["barNum"]}: {{'
                lines = (",\n" + " " * len(opening)).join(bar_entries)
                out.append(f"    # {bar['chordName']}")
                out.append(opening + lines + "},")
    out.append("}")
    return "\n".join(out) + "\n"


def key_of(tracker: Tracker) -> tuple:
    """TOONSOORT from what the page states ("E MIXOLYDIAN"); without it: the root of the first chord, major."""
    modes = {"MIXOLYDIAN": "mixolydisch", "MAJOR": "majeur", "IONIAN": "majeur", "LYDIAN": "majeur", "MINOR": "mineur",
             "AEOLIAN": "mineur", "DORIAN": "mineur", "PHRYGIAN": "mineur"}
    if tracker.mode:
        tonic, mode = tracker.mode.split()
        return tonic[0].upper() + tonic[1:], modes[mode]
    return re.match(r"[A-G]#?", tracker.bars[0]["chords"][0][0]).group(0), "majeur"


def default_title(tracker: Tracker) -> str:
    words = tracker.title.split()
    return " ".join(word.capitalize() if word.isupper() else word for word in words) or "Tracker"


def default_name(path: str) -> str:
    base = os.path.splitext(os.path.basename(path))[0].lower()
    return re.sub(r"[^a-z0-9]+", "_", base).strip("_") or "tracker"


# ----------------------------------------------------------------------------- report, comparison, measuring

def expected_bars(tracker: Tracker) -> list:
    """Per bar {part: [(position in beats, pitches, length in beats)], "drums": [(position, drum)]}:
    what the composition file must hold."""
    import notation
    result = []
    for bar in tracker.bars:
        parts = {}
        for part, row in (("bas", "bass"), ("lead", "lead"), ("harmonie", "harm")):
            found = [(1.0 + step * 0.25, (notation.pitch(note),), bar["holds"][row][step] * 0.25)
                     for step, note in enumerate(bar[row]) if plays(note)]
            if found:
                parts[part] = found
        arp = [(1.0 + step * 0.25, (notation.pitch(note),), 0.25) for step, note in enumerate(bar["arp"]) if plays(note)]
        if arp:
            parts["arp"] = arp
        brass = [(1.0 + step * 0.25, tuple(notation.pitch(note) for note in bar["chords"][step]), BRASS_STEPS * 0.25)
                 for step in range(16) if bar["stabTrig"][step] == 1]
        if brass:
            parts["brass"] = brass
        parts["drums"] = [(1.0 + step * 0.25, DRUM_NAMES[hit]) for step, hit in enumerate(bar["drums"]) if hit in DRUM_NAMES]
        result.append(parts)
    return result


def compare(tracker: Tracker, name: str) -> list:
    """composities/<naam>.py (as score.py reads it) against the page: every part of every bar
    the same notes, the same drums, tempo and length. Returns the problems; prints a line per part."""
    import score as score_module
    score = score_module.load(name)
    problems = []
    if abs(score.tempo - tracker.bpm) > 1e-6 or len(score.bars) != len(tracker.bars):
        problems.append(f"tempo/lengte: {score.tempo:g} BPM en {len(score.bars)} maten; de pagina {tracker.bpm:g} BPM en "
                        f"{len(tracker.bars)} maten")
    expected = expected_bars(tracker)
    names = sorted({part for bar in expected for part in bar})
    for part in names:
        wanted = []
        written = []
        for bar_number, bar in enumerate(expected, start=1):
            if part == "drums":
                wanted += sorted((bar_number, position, drum_name) for position, drum_name in bar["drums"])
            else:
                wanted += sorted((bar_number, position, pitches, round(length, 4)) for position, pitches, length in bar.get(part, []))
        for bar in score.bars[:len(expected)]:
            if part == "drums":
                written += sorted((bar.number, hit.position, hit.drum) for hit in bar.hits)
            else:
                written += sorted((bar.number, note.position, note.pitches, round(note.length, 4)) for note in bar.parts.get(part, []))
        same = wanted == written
        print(f"{part:9s} de pagina {len(wanted):5d} {'slagen' if part == 'drums' else 'noten'}; de compositie {len(written):5d}"
              + (": gelijk" if same else ": ANDERS"))
        if not same:
            problems.append(f"{part}: {len(set(wanted) ^ set(written))} anders, bv. {sorted(set(wanted) ^ set(written))[:4]}")
    extra = sorted({part for bar in score.bars for part in bar.parts} - set(names))
    if extra:
        problems.append(f"partijen die de pagina niet heeft: {extra}")
    return problems


def report(tracker: Tracker) -> str:
    counts = {part: 0 for part in ("bas", "brass", "lead", "harmonie", "arp", "drums")}
    for bar in expected_bars(tracker):
        for part, found in bar.items():
            counts[part] += len(found)
    lines = [f"tracker {os.path.basename(tracker.path)}: {tracker.title}",
             f"tempo {tracker.bpm:g} BPM, {len(tracker.bars)} maten van 16 stappen = {tracker.seconds:.2f} s; toonsoort volgens "
             f"de pagina: {tracker.mode or 'niet genoemd'}; master {tracker.master_volume:g}",
             "kanalen: " + ", ".join(f"{part} (vol {tracker.volumes[channel]:g}, {counts[part]} "
                                     f"{'slagen' if part == 'drums' else 'noten'})" for part, channel in CHANNEL_OF.items()),
             "secties: " + ", ".join(f"{section['naam']} ({section['soort']}) maat {section['maten'][0]}-{section['maten'][1]}"
                                     for section in sections(tracker)),
             "akkoorden: " + " | ".join(bar_chords(bar) for bar in tracker.bars),
             f"synth van de pagina: {tracker.fingerprint}" + (" (waar de nabouw van gemaakt is)"
                                                              if tracker.fingerprint == SYNTH_FINGERPRINT else "")]
    lines += [f"let op: {warning}" for warning in tracker.warnings]
    return "\n".join(lines)


def _band_levels(signal: numpy.ndarray) -> list:
    """The level (dB) in six bands: under 120, to 400, to 1200, to 3600, to 9000, above."""
    spectrum = numpy.abs(numpy.fft.rfft(signal)) ** 2
    frequencies = numpy.fft.rfftfreq(len(signal), 1.0 / SAMPLE_RATE)
    edges = (0.0, 120.0, 400.0, 1200.0, 3600.0, 9000.0, SAMPLE_RATE / 2.0 + 1.0)
    total = spectrum.sum() + 1e-20
    return [10.0 * math.log10(spectrum[(frequencies >= low) & (frequencies < high)].sum() / total + 1e-12)
            for low, high in zip(edges, edges[1:])]


def _period_hz(piece: numpy.ndarray, wanted: float) -> float:
    """The frequency near `wanted` at which the piece repeats best."""
    lags = range(max(2, int(SAMPLE_RATE / wanted * 0.94)), int(SAMPLE_RATE / wanted * 1.06) + 2)
    alike = [float(numpy.dot(piece[:-lag], piece[lag:])) / (len(piece) - lag) for lag in lags]
    best = int(numpy.argmax(alike))
    shift = 0.0
    if 0 < best < len(alike) - 1:
        bend = alike[best - 1] - 2.0 * alike[best] + alike[best + 1]
        shift = 0.5 * (alike[best - 1] - alike[best + 1]) / bend if bend else 0.0
    return SAMPLE_RATE / (lags[best] + shift)


def measure(tracker: Tracker, wav_path: str = None, intro_path: str = None) -> list:
    """Measures the rebuilt synth against the score (every voice alone: the pitch of its notes,
    its level and its place left-right against what the page sets), the intro file against the
    bare render, and (with `wav_path`) the render against a recording of the piece: length, the
    level through the piece, the spectrum in bands, left against right, and the pitch of the
    bass and the melody at their notes. Returns the problems (Dutch); prints the measurements."""
    problems = []
    step = tracker.step_seconds
    alone = {part: render(tracker, 0.0, (part,), mastered=False) for part in CHANNEL_OF}
    for part, row in (("bas", "bass"), ("lead", "lead"), ("harmonie", "harm")):
        cents = []
        for bar_index, bar in enumerate(tracker.bars):
            for step_index, note in enumerate(bar[row]):
                if not plays(note) or bar["holds"][row][step_index] < 2:
                    continue
                start = int(((bar_index * 16 + step_index) * step + 0.02) * SAMPLE_RATE)
                end = int(((bar_index * 16 + step_index + bar["holds"][row][step_index]) * step - 0.02) * SAMPLE_RATE)
                cents.append(abs(1200.0 * math.log2(_period_hz(alone[part][start:end].mean(axis=1), note_hz(note)) / note_hz(note))))
        if cents:
            print(f"{part}: {len(cents)} aangehouden noten gemeten: gemiddeld {sorted(cents)[len(cents) // 2]:.1f} cent van de noot "
                  f"van de pagina, hooguit {max(cents):.1f} cent")
            if sorted(cents)[len(cents) // 2] > 15.0:
                problems.append(f"{part}: de toonhoogte ligt {sorted(cents)[len(cents) // 2]:.0f} cent naast de pagina")
    pans = {"bas": 0.0, "lead": -0.15, "harmonie": 0.38, "drums": None}
    for part, pan in pans.items():
        left = float(numpy.sqrt(numpy.mean(alone[part][:, 0] ** 2)))
        right = float(numpy.sqrt(numpy.mean(alone[part][:, 1] ** 2)))
        wanted_db = 0.0 if pan is None else 20.0 * math.log10(pan_gains(pan)[1] / pan_gains(pan)[0])
        found_db = 20.0 * math.log10(right / left)
        print(f"{part}: rechts {found_db:+.2f} dB tegen links (de pagina: {wanted_db:+.2f} dB)")
        if abs(found_db - wanted_db) > 0.2:
            problems.append(f"{part}: het stereobeeld wijkt {abs(found_db - wanted_db):.1f} dB af")
    levels = {part: 10.0 * math.log10(float(numpy.mean(alone[part] ** 2)) + 1e-20) for part in alone}
    loudest = max(levels.values())
    print("niveau van de kanalen (dB onder het luidste, elk alleen, voor de compressor): "
          + ", ".join(f"{part} {level - loudest:.1f}" for part, level in sorted(levels.items(), key=lambda item: -item[1])))
    ours = render(tracker, 0.0)
    peak = float(numpy.abs(ours).max())
    bare = sum(alone.values()) * tracker.master_volume
    reduction = 20.0 * math.log10(float(numpy.sqrt(numpy.mean(ours ** 2))) / float(numpy.sqrt(numpy.mean(bare ** 2))))
    print(f"na master ({tracker.master_volume:g}) en compressor: piek {20 * math.log10(peak):.1f} dB, het niveau "
          f"{reduction:+.1f} dB tegen ervoor (de compressor met zijn make-up)")
    if intro_path and os.path.exists(intro_path):
        import soundfile
        written, rate = soundfile.read(intro_path)
        both = min(len(written), len(ours))
        alike = [float(numpy.corrcoef(written[:both, side], ours[:both, side])[0, 1]) for side in (0, 1)]
        print(f"intro-bestand: {len(written) / rate:.2f} s (de partituur {tracker.seconds:.2f} s, de rest is uitklinken); "
              f"correlatie met de kale weergave links {alike[0]:.3f}, rechts {alike[1]:.3f}")
        if min(alike) < 0.9:
            problems.append(f"de intro lijkt te weinig op de weergave (correlatie {min(alike):.2f})")
    if wav_path:
        import soundfile
        theirs, rate = soundfile.read(wav_path)
        if rate != SAMPLE_RATE or theirs.ndim != 2:
            print(f"{wav_path}: {rate} Hz, niet vergeleken")
            return problems
        print(f"tegen {os.path.basename(wav_path)}: {len(theirs) / rate:.2f} s; onze weergave {len(ours) / SAMPLE_RATE:.2f} s")
        both = min(len(theirs), len(ours))
        ours_bands = _band_levels(ours[:both].mean(axis=1))
        their_bands = _band_levels(theirs[:both].mean(axis=1))
        print("  spectrum per band (dB van het geheel; <120, -400, -1200, -3600, -9000, >9000 Hz):")
        print("    wij:  " + ", ".join(f"{level:6.1f}" for level in ours_bands))
        print("    WAV:  " + ", ".join(f"{level:6.1f}" for level in their_bands))
        eighth = both // 8
        ours_levels = [10 * math.log10(float(numpy.mean(ours[part * eighth:(part + 1) * eighth] ** 2))) for part in range(8)]
        their_levels = [10 * math.log10(float(numpy.mean(theirs[part * eighth:(part + 1) * eighth] ** 2))) for part in range(8)]
        print("  niveau per achtste deel (dB): wij " + ", ".join(f"{level:.1f}" for level in ours_levels))
        print("                                WAV " + ", ".join(f"{level:.1f}" for level in their_levels))
        print(f"  links tegen rechts (correlatie): wij {float(numpy.corrcoef(ours[:both, 0], ours[:both, 1])[0, 1]):.3f}, "
              f"WAV {float(numpy.corrcoef(theirs[:both, 0], theirs[:both, 1])[0, 1]):.3f}")
        # the envelope: the level per sixteenth, ours against theirs (how alike the rhythm of loud and soft is)
        step_samples = both // (len(tracker.bars) * 16)
        ours_steps = numpy.array([numpy.mean(ours[index * step_samples:(index + 1) * step_samples] ** 2)
                                  for index in range(len(tracker.bars) * 16)])
        their_steps = numpy.array([numpy.mean(theirs[index * step_samples:(index + 1) * step_samples] ** 2)
                                   for index in range(len(tracker.bars) * 16)])
        print(f"  omhullende per zestiende (correlatie van het niveau in dB): "
              f"{float(numpy.corrcoef(numpy.log10(ours_steps + 1e-12), numpy.log10(their_steps + 1e-12))[0, 1]):.3f}")
        # the pitch of the melody: at each held note of the lead, the strongest partial near it in both
        hits = {"wij": 0, "WAV": 0}
        total = 0
        for bar_index, bar in enumerate(tracker.bars):
            for step_index, note in enumerate(bar["lead"]):
                if not plays(note) or bar["holds"]["lead"][step_index] < 2:
                    continue
                start = int((bar_index * 16 + step_index) * step * SAMPLE_RATE)
                end = start + int(bar["holds"]["lead"][step_index] * step * SAMPLE_RATE)
                total += 1
                for label, signal in (("wij", ours), ("WAV", theirs)):
                    piece = signal[start:end].mean(axis=1) * numpy.hanning(end - start)
                    spectrum = numpy.abs(numpy.fft.rfft(piece, 1 << 16))
                    hz = note_hz(note)
                    at = lambda frequency: spectrum[int(frequency * 0.985 * 65536 / SAMPLE_RATE):int(frequency * 1.015 * 65536 / SAMPLE_RATE) + 1].max()
                    between = lambda frequency: numpy.median(spectrum[int(frequency * 1.03 * 65536 / SAMPLE_RATE):int(frequency * 1.9 * 65536 / SAMPLE_RATE)])
                    if at(hz) > 4.0 * between(hz):
                        hits[label] += 1
        print(f"  de melodie: bij {total} aangehouden noten steekt de grondtoon van de pagina boven zijn omgeving uit: "
              f"wij {hits['wij']}, WAV {hits['WAV']}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("html", help="the tracker page")
    parser.add_argument("naam", nargs="?", help="the name of the composition (default: the file name)")
    parser.add_argument("--toon", action="store_true")
    parser.add_argument("--vergelijk", action="store_true")
    parser.add_argument("--meet", nargs="?", const="", default=None, metavar="WAV",
                        help="measure the rebuilt synth; with a WAV of the piece also against that")
    parser.add_argument("--overschrijf", action="store_true")
    parser.add_argument("--titel")
    arguments = parser.parse_args()
    tracker = read(arguments.html)
    name = arguments.naam or default_name(arguments.html)
    print(report(tracker))
    if arguments.toon:
        return 0
    sys.path.insert(0, HERE)
    if arguments.vergelijk or arguments.meet is not None:
        if arguments.vergelijk:
            problems = compare(tracker, name)
        else:
            intro_path = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "audio", "muziek", "zwervr_intro.ogg")
            problems = measure(tracker, arguments.meet or None, intro_path)
        if problems:
            print("VERSCHILLEN:\n  " + "\n  ".join(problems))
            return 1
        print("de compositie komt overeen met de pagina" if arguments.vergelijk else "de nabouw komt overeen met de pagina")
        return 0
    target = os.path.join(COMPOSITIONS_FOLDER, name + ".py")
    if os.path.exists(target) and not arguments.overschrijf:
        print(f"{target} bestaat al (handwerk erin gaat verloren): geef --overschrijf om het te vervangen")
        return 1
    kept = os.path.join(COMPOSITIONS_FOLDER, name + ".html")
    if os.path.abspath(kept) != os.path.abspath(arguments.html):
        shutil.copyfile(arguments.html, kept)
        print(f"bron bewaard: {kept}")
        tracker.path = kept
    with open(target, "w", encoding="utf-8") as composition_file:
        composition_file.write(composition_source(tracker, name, arguments.titel or default_title(tracker)))
    print(f"geschreven: {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
