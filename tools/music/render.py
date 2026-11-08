#!/usr/bin/env python3
"""Render the songs in tools/music/songs/ to .ogg files.

Usage (via the wrapper, which sets up numpy/scipy in tools/music/.venv):
  tools/music/render.sh                     # render everything into assets/audio/muziek/
  tools/music/render.sh --list              # list all renders
  tools/music/render.sh --only menu         # only renders whose file name contains 'menu'
  tools/music/render.sh --only intro --bars 17-32   # quick preview of bars 17-32 (*_preview.ogg)
  tools/music/render.sh --out-dir /tmp/x    # write somewhere else

Every module in songs/ exposes RENDERS: a list of dicts with
  file     output file name
  bpm      tempo
  bars     length in bars (or `seconds` for jingles: hard length, cut + fade)
  compose  function(song, first_bar) that places all notes
  loop     True for a seamless loop: the piece is rendered twice in a row and the second pass
           is kept, so reverb and echoes at the end continue into the start.
"""
import argparse
import importlib
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
sys.path.insert(0, str(HERE))

import numpy as np  # noqa: E402

from synth import SAMPLE_RATE, Song, mix, write_ogg  # noqa: E402

DEFAULT_OUT_DIR = PROJECT / "assets" / "audio" / "muziek"
FADE_SECONDS = 0.25


def all_renders():
    renders = []
    for module_path in sorted((HERE / "songs").glob("*.py")):
        if module_path.stem.startswith("_"):
            continue
        module = importlib.import_module(f"songs.{module_path.stem}")
        renders.extend(getattr(module, "RENDERS", []))
    return renders


def render(spec, out_dir, bar_range=None):
    started = time.time()
    rng = np.random.default_rng(7)
    is_loop = spec.get("loop", False) and bar_range is None
    if "bars" in spec:
        bars = spec["bars"]
        song = Song(spec["bpm"], bars * (2 if is_loop else 1), tail_seconds=4.0)
        spec["compose"](song, 1)
        if is_loop:
            spec["compose"](song, bars + 1)
        start_time, end_time = (song.at(bars + 1), song.at(2 * bars + 1)) if is_loop else (0.0, song.at(bars + 1))
        if bar_range:
            start_time, end_time = song.at(bar_range[0]), song.at(bar_range[1] + 1)
    else:
        song = Song(spec["bpm"], int(np.ceil(spec["seconds"] / (240 / spec["bpm"]))) + 1, tail_seconds=2.0)
        spec["compose"](song, 1)
        start_time, end_time = 0.0, spec["seconds"]

    print(f"{spec['file']}: {(end_time - start_time):.2f} s{'  (loop)' if is_loop else ''}")
    stereo = mix(song, rng, start_time=start_time, end_time=end_time)
    if "seconds" in spec:
        fade = min(len(stereo), int(FADE_SECONDS * SAMPLE_RATE))
        stereo[-fade:] *= np.linspace(1, 0, fade)[:, None]

    name = spec["file"] if not bar_range else spec["file"].replace(".ogg", "_preview.ogg")
    out_path = out_dir / name
    write_ogg(out_path, stereo)
    print(f"  -> {out_path}  ({time.time() - started:.1f} s rendering)")
    if is_loop:
        print("  loop: whole file (loop_offset 0)")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--only", help="only renders whose file name contains this text")
    parser.add_argument("--bars", help="preview bar range, e.g. 17-32 (not for jingles)")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR))
    arguments = parser.parse_args()

    renders = [spec for spec in all_renders() if not arguments.only or arguments.only in spec["file"]]
    if arguments.list:
        for spec in renders:
            length = f"{spec['bars']} bars" if "bars" in spec else f"{spec['seconds']} s"
            print(f"{spec['file']:<36} {spec['bpm']:>4} bpm  {length}{'  loop' if spec.get('loop') else ''}")
        return
    if not renders:
        sys.exit(f"No render matches '{arguments.only}' (see --list)")

    bar_range = None
    if arguments.bars:
        first, last = arguments.bars.split("-")
        bar_range = (int(first), int(last))
    out_dir = pathlib.Path(arguments.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for spec in renders:
        if bar_range and "bars" not in spec:
            continue
        render(spec, out_dir, bar_range)


if __name__ == "__main__":
    main()
