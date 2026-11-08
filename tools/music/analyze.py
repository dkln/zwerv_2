#!/usr/bin/env python3
"""Analyse audio files numerically (tempo, key, chords, sound balance, drum grid, dynamics, stereo).

Meant to compare a reference track with our own renders, since nobody can 'listen' in a script:
  tools/music/analyze.sh voorbeeld.mp3
  tools/music/analyze.sh voorbeeld.mp3 assets/audio/muziek/nachtstad_menu_loop.ogg

Decoding uses ffmpeg (any format ffmpeg reads).
"""
import subprocess
import sys

import numpy as np

SAMPLE_RATE = 22050
PITCH_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
MAJOR_PROFILE = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MINOR_PROFILE = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
BANDS = [("sub <60", 20, 60), ("bas 60-250", 60, 250), ("laag-mid 250-1k", 250, 1000),
         ("mid 1k-4k", 1000, 4000), ("hoog 4k-10k", 4000, 10000), ("lucht >10k", 10000, 11025)]


def decode(path):
    raw = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "2",
                          "-ar", str(SAMPLE_RATE), "-"], stdout=subprocess.PIPE, stdin=subprocess.DEVNULL,
                         check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def spectrogram(mono, frame_size, hop):
    frame_count = 1 + (len(mono) - frame_size) // hop
    window = np.hanning(frame_size)
    frames = np.lib.stride_tricks.as_strided(mono, shape=(frame_count, frame_size),
                                             strides=(mono.strides[0] * hop, mono.strides[0]))
    return np.abs(np.fft.rfft(frames * window, axis=1)), np.fft.rfftfreq(frame_size, 1 / SAMPLE_RATE)


def band_flux(magnitudes, frequencies, low, high):
    band = magnitudes[:, (frequencies >= low) & (frequencies < high)]
    flux = np.maximum(np.diff(np.log1p(band * 10), axis=0), 0).sum(axis=1)
    return np.concatenate([[0], flux])


def estimate_tempo(onset_envelope, hop):
    envelope = onset_envelope - onset_envelope.mean()
    correlation = np.correlate(envelope, envelope, mode="full")[len(envelope) - 1:]
    frames_per_second = SAMPLE_RATE / hop
    best_bpm, best_score = 0, -np.inf
    for bpm in np.arange(70, 190, 0.25):
        lag = frames_per_second * 60 / bpm
        score = sum(np.interp(lag * multiple, np.arange(len(correlation)), correlation) / multiple
                    for multiple in (1, 2, 4))
        score *= np.exp(-0.5 * (np.log2(bpm / 125)) ** 2)  # mild preference for dance tempos
        if score > best_score:
            best_bpm, best_score = bpm, score
    return best_bpm


def chroma(magnitudes, frequencies):
    usable = (frequencies > 55) & (frequencies < 2000)
    pitch_classes = (np.round(12 * np.log2(frequencies[usable] / 440)) + 9) % 12
    result = np.zeros((magnitudes.shape[0], 12))
    for pitch_class in range(12):
        result[:, pitch_class] = magnitudes[:, usable][:, pitch_classes == pitch_class].sum(axis=1)
    return result / np.maximum(result.sum(axis=1, keepdims=True), 1e-9)


def estimate_key(chroma_total):
    best = None
    for tonic in range(12):
        for mode, profile in (("majeur", MAJOR_PROFILE), ("mineur", MINOR_PROFILE)):
            score = np.corrcoef(np.roll(profile, tonic), chroma_total)[0, 1]
            if best is None or score > best[0]:
                best = (score, f"{PITCH_NAMES[tonic]} {mode}")
    return best[1], best[0]


def chord_name(chroma_vector):
    best_name, best_score = "?", -1
    for root in range(12):
        for suffix, intervals in (("", (0, 4, 7)), ("m", (0, 3, 7)), ("7", (0, 4, 7, 10)), ("m7", (0, 3, 7, 10)),
                                  ("sus4", (0, 5, 7)), ("5", (0, 7))):
            template = np.zeros(12)
            template[[(root + interval) % 12 for interval in intervals]] = 1
            score = np.dot(template / np.linalg.norm(template), chroma_vector / max(np.linalg.norm(chroma_vector), 1e-9))
            if suffix == "5":
                score -= 0.03
            if score > best_score:
                best_name, best_score = PITCH_NAMES[root] + suffix, score
    return best_name


def drum_grid(flux, hop, bpm, bar_count_limit=64):
    """Fold onsets onto a 16-step bar; returns strength per step (0..9) using the best phase."""
    frames_per_step = SAMPLE_RATE / hop * 60 / bpm / 4
    step_count = int(len(flux) / frames_per_step)
    steps = np.array([flux[int(step * frames_per_step):int((step + 1) * frames_per_step)].max(initial=0)
                      for step in range(step_count)])
    usable = steps[:min(len(steps), bar_count_limit * 16) // 16 * 16].reshape(-1, 16)
    return usable.mean(axis=0)


def bar_text(values):
    scaled = np.round(9 * values / max(values.max(), 1e-9)).astype(int)
    text = "".join(str(value) if value >= 3 else "." for value in scaled)
    return " ".join(text[index:index + 4] for index in range(0, 16, 4))


def analyse(path):
    stereo = decode(path)
    mono = stereo.mean(axis=1)
    duration = len(mono) / SAMPLE_RATE
    print(f"\n=== {path}  ({duration // 60:.0f}:{duration % 60:04.1f}) ===")

    rms = np.sqrt(np.mean(mono ** 2))
    peak = np.max(np.abs(mono))
    print(f"Luidheid: RMS {20 * np.log10(rms):.1f} dBFS, piek {20 * np.log10(peak):.1f} dBFS, "
          f"crest {20 * np.log10(peak / rms):.1f} dB (lager = meer gecomprimeerd)")
    mid = stereo.mean(axis=1)
    side = (stereo[:, 0] - stereo[:, 1]) / 2
    print(f"Stereobreedte (side/mid): {np.sqrt(np.mean(side ** 2)) / np.sqrt(np.mean(mid ** 2)):.2f}")

    hop = 512
    magnitudes, frequencies = spectrogram(mono, 2048, hop)
    power = magnitudes ** 2
    total = power.sum()
    print("Klankbalans:", ", ".join(
        f"{name} {100 * power[:, (frequencies >= low) & (frequencies < high)].sum() / total:.0f}%"
        for name, low, high in BANDS))
    centroid = (power * frequencies).sum(axis=1) / np.maximum(power.sum(axis=1), 1e-9)
    print(f"Helderheid (spectral centroid): gemiddeld {np.mean(centroid):.0f} Hz")

    onset = band_flux(magnitudes, frequencies, 30, 11025)
    bpm = estimate_tempo(onset, hop)
    print(f"Tempo: ~{bpm:.1f} BPM")

    chroma_magnitudes, chroma_frequencies = spectrogram(mono, 8192, 2048)
    chroma_frames = chroma(chroma_magnitudes, chroma_frequencies)
    key, confidence = estimate_key(chroma_frames.sum(axis=0))
    print(f"Toonsoort: {key} (zekerheid {confidence:.2f})")
    print("Toonklassen:", " ".join(f"{PITCH_NAMES[index]} {100 * value:.0f}%"
                                   for index, value in sorted(enumerate(chroma_frames.mean(axis=0)),
                                                              key=lambda item: -item[1])[:7]))
    frames_per_bar = SAMPLE_RATE / 2048 * 60 / bpm * 4
    bar_count = int(len(chroma_frames) / frames_per_bar)
    chords = [chord_name(chroma_frames[int(bar * frames_per_bar):int((bar + 1) * frames_per_bar)].mean(axis=0))
              for bar in range(bar_count)]
    print("Akkoord per maat:")
    for start in range(0, len(chords), 16):
        print(f"  maat {start + 1:>3}: " + " ".join(f"{chord:<5}" for chord in chords[start:start + 16]))

    print("Drumgrid (gemiddelde aanslag per 16e in een maat, 9 = sterkst):")
    for name, low, high in (("kick 40-120", 40, 120), ("snare 150-300+2-5k", 150, 300), ("hats 7k+", 7000, 11025)):
        grid = drum_grid(band_flux(magnitudes, frequencies, low, high), hop, bpm)
        print(f"  {name:<20} {bar_text(grid)}")

    section_seconds = 60 / bpm * 4 * 8
    print("Energie per 8 maten (RMS dB | % bas | % hoog):")
    for start in np.arange(0, duration, section_seconds):
        segment = mono[int(start * SAMPLE_RATE):int((start + section_seconds) * SAMPLE_RATE)]
        if len(segment) < SAMPLE_RATE:
            continue
        segment_magnitudes, segment_frequencies = spectrogram(segment, 2048, 1024)
        segment_power = segment_magnitudes ** 2
        segment_total = max(segment_power.sum(), 1e-12)
        bass_share = segment_power[:, segment_frequencies < 250].sum() / segment_total
        high_share = segment_power[:, segment_frequencies >= 4000].sum() / segment_total
        level = 20 * np.log10(np.sqrt(np.mean(segment ** 2)) + 1e-12)
        print(f"  {int(start // 60)}:{start % 60:04.1f}  {level:6.1f} dB | {100 * bass_share:3.0f}% | "
              f"{100 * high_share:3.0f}%  " + "#" * max(0, int((level + 40) / 1.5)))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for audio_path in sys.argv[1:]:
        analyse(audio_path)
