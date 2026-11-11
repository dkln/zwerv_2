"""The background sound of the places (ambience): the murmur of the street, the hall of the
station and a shop, from free recordings (Wikimedia Commons), made into seamless loops.

Every recording is downloaded once (into a folder of its own outside the project), a stretch
of it is cut out and its end crossfaded into its start (CROSSFADE seconds, equal power), so it
loops without a seam; it is levelled like every sound of the game (loudness.py, -16 LUFS
integrated); the game plays it softly (scripts/audio/ambience.gd). Where the recordings come
from and their licences: assets/audio/omgeving/BRONNEN.md (written here too).

    uv run --with numpy --with soundfile python3 tools/megadrive/omgeving.py

Output: assets/audio/omgeving/straat_loop.ogg, station_loop.ogg, winkel_loop.ogg (stereo).
"""
import os
import subprocess
import sys
import tempfile
import urllib.request

import numpy
import soundfile

import loudness
import megadrive

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUTPUT_FOLDER = os.path.join(PROJECT, "assets", "audio", "omgeving")
SAMPLE_RATE = 44100
CROSSFADE = 3.0
USER_AGENT = "game-ambience-download/1.0"

## name: its layers, each (the recording on Wikimedia Commons, its page, its licence, its
## maker, the stretch used (start, seconds), its level in the mix (dB)); a loop of more layers
## is their sum, each cut to the shortest stretch.
RECORDINGS = {
    # the street: people talking all round (the crowd of a busy mall) over the sound of a city
    # street (traffic, steps), a few dB under it: a loop of several layers
    "straat_loop": [
        ("https://upload.wikimedia.org/wikipedia/commons/f/fd/1_minute_at_the_alexa_mall_in_berlin.ogg",
         "https://commons.wikimedia.org/wiki/File:1_minute_at_the_alexa_mall_in_berlin.ogg",
         "publiek domein", "thore (Wikimedia Commons)", (5.0, 50.0), 0.0),
        ("https://upload.wikimedia.org/wikipedia/commons/a/ab/Karlova_0001.ogg",
         "https://commons.wikimedia.org/wiki/File:Karlova_0001.ogg",
         "publiek domein", "Juan de Vojníkov (Wikimedia Commons)", (20.0, 50.0), -4.0),
    ],
    # a station concourse murmur without a voice standing out (the Tampere hall had an
    # announcer; measured: the least syllable-rate swell in the loudness)
    "station_loop": [("https://upload.wikimedia.org/wikipedia/commons/d/d6/Union_Station_Bay_Concourse_Ambience_%28Freesound%29.ogg",
                     "https://commons.wikimedia.org/wiki/File:Union_Station_Bay_Concourse_Ambience_(Freesound).ogg",
                     "CC BY 4.0", "PascalHD (Freesound, via Wikimedia Commons)", (3.0, 38.0), 0.0)],
    "winkel_loop": [("https://upload.wikimedia.org/wikipedia/commons/d/d5/Shopping_mall_less_crowded.ogg",
                    "https://commons.wikimedia.org/wiki/File:Shopping_mall_less_crowded.ogg",
                    "publiek domein", "natalie (Wikimedia Commons)", (1.0, 27.0), 0.0)],
}


def download(url: str, folder: str) -> str:
    path = os.path.join(folder, os.path.basename(url))
    if not os.path.exists(path):
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request) as response, open(path, "wb") as out:
            out.write(response.read())
    return path


def decoded(path: str) -> str:
    """The recording as a WAV at SAMPLE_RATE, stereo (ffmpeg: libsndfile crashes reading big Vorbis)."""
    wav = os.path.splitext(path)[0] + ".wav"
    if not os.path.exists(wav):
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-ac", "2", "-ar", str(SAMPLE_RATE), wav],
                       check=True, stdin=subprocess.DEVNULL)
    return wav


def as_stereo(signal: numpy.ndarray) -> numpy.ndarray:
    if signal.ndim == 1:
        return numpy.stack([signal, signal], axis=1)
    return signal[:, :2]


def resample(signal: numpy.ndarray, rate: int) -> numpy.ndarray:
    if rate == SAMPLE_RATE:
        return signal
    old = numpy.arange(len(signal)) / rate
    new = numpy.arange(int(len(signal) * SAMPLE_RATE / rate)) / SAMPLE_RATE
    return numpy.stack([numpy.interp(new, old, signal[:, channel]) for channel in range(signal.shape[1])], axis=1)


def seamless(signal: numpy.ndarray) -> numpy.ndarray:
    """The stretch with its last CROSSFADE seconds faded into its first (equal power): the loop
    is that much shorter and its end runs into its start."""
    fade = int(CROSSFADE * SAMPLE_RATE)
    body = signal[:-fade].copy()
    share = numpy.linspace(0.0, 1.0, fade)[:, None]
    body[:fade] = signal[-fade:] * numpy.cos(share * numpy.pi / 2) + signal[:fade] * numpy.sin(share * numpy.pi / 2)
    return body


def make(name: str, folder: str) -> None:
    stretches = []
    for url, page, licence, maker, (start, seconds), gain_db in RECORDINGS[name]:
        signal, rate = soundfile.read(decoded(download(url, folder)), always_2d=True)
        signal = resample(as_stereo(signal), rate)
        stretch = signal[int(start * SAMPLE_RATE):int((start + seconds + CROSSFADE) * SAMPLE_RATE)]
        stretch = stretch - stretch.mean(axis=0)
        # every layer at the same loudness first, then at its level in the mix
        stretch = loudness.level(stretch, one_shot=False) * 10.0 ** (gain_db / 20.0)
        stretches.append(stretch)
    shortest = min(len(stretch) for stretch in stretches)
    mixed = sum(stretch[:shortest] for stretch in stretches)
    loop = loudness.level(seamless(mixed), one_shot=False)
    path = os.path.join(OUTPUT_FOLDER, name + ".ogg")
    megadrive.write_ogg(path, loop)   # in small writes: libsndfile crashes on big ones
    print(f"geschreven: {path}  ({len(loop) / SAMPLE_RATE:.1f} s, {len(stretches)} lagen, {loudness.integrated_lufs(loop):.1f} LUFS)")


def write_sources() -> None:
    lines = ["# Bronnen van de achtergrondgeluiden", "",
             "Opnames van Wikimedia Commons, bewerkt tot naadloze lussen door `tools/megadrive/omgeving.py`.", ""]
    for name, layers in RECORDINGS.items():
        for url, page, licence, maker, (start, seconds), gain_db in layers:
            lines.append(f"- `{name}.ogg`: [{os.path.basename(page)}]({page}), {maker}, licentie {licence}"
                         f" (stuk vanaf {start:g} s, {seconds:g} s{'' if gain_db == 0.0 else f', {gain_db:+g} dB in de mix'}).")
    with open(os.path.join(OUTPUT_FOLDER, "BRONNEN.md"), "w") as sources:
        sources.write("\n".join(lines) + "\n")


def main() -> None:
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    folder = os.path.join(tempfile.gettempdir(), "zwervr_omgeving_opnames")
    os.makedirs(folder, exist_ok=True)
    for name in sys.argv[1:] or list(RECORDINGS):
        make(name, folder)
    write_sources()


if __name__ == "__main__":
    main()
