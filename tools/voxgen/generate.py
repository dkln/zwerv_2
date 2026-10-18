#!/usr/bin/env python3
"""Genereer alle .vox tiles naar assets/tiles/.

Gebruik:
  python3 tools/voxgen/generate.py            # alleen ontbrekende tiles maken
  python3 tools/voxgen/generate.py --force    # alles overschrijven (let op: eigen edits weg!)
  python3 tools/voxgen/generate.py --only weg # alleen tiles waarvan het pad 'weg' bevat
  python3 tools/voxgen/generate.py --list     # toon alle tiles

Bestaande .vox bestanden worden standaard NIET overschreven, zodat je eigen
aanpassingen in MagicaVoxel bewaard blijven.
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
from vox import write_vox  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "tiles"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only", default=None)
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()

    names = sorted(TILES)
    if a.only:
        names = [n for n in names if a.only in n]
    if a.list:
        for n in names:
            print(n)
        print(f"{len(names)} tiles")
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
        made += 1
        print(f"  {n:60s} {m.sx}x{m.sy}x{m.sz}  {cnt} voxels")
    print(f"{made} gemaakt, {skipped} overgeslagen (bestonden al) in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
