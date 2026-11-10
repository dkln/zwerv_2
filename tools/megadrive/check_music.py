"""Checks the rendered music (assets/audio/muziek/*.ogg): length, loudness, peak, how clean
the loop seam is, and the level per stretch of bars (so a section that came out empty or a
part that drowns the rest shows up without listening).

    uv run --with numpy --with soundfile python3 tools/megadrive/check_music.py [name ...]

For a loop the seam is the jump from the last sample to the first, against the large steps
between two samples in the music (the 99.9th percentile: the 8-bit sample-and-hold drums make
big steps all the time); above 1 it may be a click. The city loops
must all be equally long (the HUD crossfades them at the same playback position).
"""
import glob
import os
import sys

import numpy
import soundfile

import loudness
import style

BAR_SECONDS_FALLBACK = 2.0


def check(path: str) -> dict:
    signal, rate = soundfile.read(path)
    name = os.path.basename(path)
    seconds = len(signal) / rate
    peak_db = 20 * numpy.log10(max(numpy.abs(signal).max(), 1e-9))
    lufs = loudness.integrated_lufs(signal)
    steps = numpy.abs(numpy.diff(signal, axis=0))
    typical_step = numpy.percentile(steps, 99.9) + 1e-9
    seam = numpy.abs(signal[0] - signal[-1]).max() / typical_step
    bar_seconds = 60.0 / style.tempo("stad") * 4 if name.startswith("stad_") else BAR_SECONDS_FALLBACK
    stretch = int(bar_seconds * 8 * rate)
    levels = []
    for start in range(0, len(signal), stretch):
        part = signal[start:start + stretch]
        if len(part) > rate:
            levels.append(round(float(20 * numpy.log10(numpy.sqrt(numpy.mean(part ** 2)) + 1e-9)), 1))
    return {"name": name, "seconds": round(seconds, 3), "lufs": round(lufs, 1), "peak_db": round(peak_db, 2),
            "seam": round(float(seam), 2), "levels_per_8_bars": levels}


def main() -> None:
    folder = style.MUSIC_FOLDER
    names = sys.argv[1:]
    paths = sorted(glob.glob(os.path.join(folder, "*.ogg")))
    if names:
        paths = [path for path in paths if any(name in os.path.basename(path) for name in names)]
    city_lengths = set()
    for path in paths:
        result = check(path)
        loop = "_loop" in result["name"]
        flag = ""
        if loop and result["seam"] > 1.0:
            flag += "  NAAD?"
        if result["peak_db"] > -0.9:
            flag += "  PIEK?"
        if result["name"].startswith("stad_"):
            city_lengths.add(result["seconds"])
        print(f"{result['name']:32s} {result['seconds']:8.3f} s  {result['lufs']:6.1f} LUFS  piek {result['peak_db']:6.2f} dB"
              f"  naad {result['seam'] if loop else '-':>5}  per 8 maten {result['levels_per_8_bars']}{flag}")
    if len(city_lengths) > 1:
        print("FOUT: de stadsloops zijn niet even lang:", sorted(city_lengths))


if __name__ == "__main__":
    main()
