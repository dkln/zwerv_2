#!/usr/bin/env python3
"""Generate all .vox tiles (plus .tile.json metadata) into assets/tiles/.

Usage:
  python3 tools/voxgen/generate.py             # only create missing tiles
  python3 tools/voxgen/generate.py --force     # overwrite everything (your own edits are lost!)
  python3 tools/voxgen/generate.py --only weg  # only tiles whose path contains 'weg' (tile paths are Dutch)
  python3 tools/voxgen/generate.py --list      # list all tiles
  python3 tools/voxgen/generate.py --meta      # only (re)write the .tile.json metadata of existing tiles

By default existing .vox files are NOT overwritten, so manual changes made in
MagicaVoxel are kept. Importing the tile modules below fills common.TILES via
their @tile/register calls; each tile path maps to <OUT>/<path>.vox.
"""
import argparse
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from common import TILES  # noqa: E402
import ground  # noqa: E402,F401
import ground2  # noqa: E402,F401
import ground3  # noqa: E402,F401
import ground4  # noqa: E402,F401
import buildings  # noqa: E402,F401
import buildings2  # noqa: E402,F401
import buildings3  # noqa: E402,F401
import details  # noqa: E402,F401
import details2  # noqa: E402,F401
import props  # noqa: E402,F401
import props2  # noqa: E402,F401
import extras4  # noqa: E402,F401
import extras5  # noqa: E402,F401
import extras6  # noqa: E402,F401
import extras7  # noqa: E402,F401
from vox import write_vox, write_metadata  # noqa: E402

# Output root; read by main() at call time (tests patch it).

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "tiles"))


def main():
    """Command line entry point; see the module docstring for the options."""
    ap = argparse.ArgumentParser(description="Generate the MagicaVoxel tiles into <OUT>/<path>.vox.")
    ap.add_argument("--force", action="store_true", help="overwrite existing .vox files")
    ap.add_argument("--only", default=None, metavar="TEXT", help="only tiles whose path contains TEXT")
    ap.add_argument("--list", action="store_true", help="list the tile paths and exit")
    ap.add_argument("--meta", action="store_true", help="only write metadata for existing tiles")
    a = ap.parse_args()

    names = sorted(TILES)
    if a.only:
        names = [n for n in names if a.only in n]
    if a.list:
        for n in names:
            print(n)
        print(f"{len(names)} tiles")
        return

    if a.meta:
        count = 0
        for n in names:
            path = os.path.join(OUT, n + ".vox")
            if os.path.exists(path) and write_metadata(path, n):
                count += 1
        print(f"metadata for {count} of {len(names)} tiles")
        return

    made = skipped = 0
    t0 = time.time()
    for n in names:
        path = os.path.join(OUT, n + ".vox")
        if os.path.exists(path) and not a.force:
            skipped += 1
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        m = TILES[n]()
        cnt = write_vox(path, m)
        write_metadata(path, n)
        made += 1
        print(f"  {n:60s} {m.sx}x{m.sy}x{m.sz}  {cnt} voxels")
    print(f"{made} created, {skipped} skipped (already existed) in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
