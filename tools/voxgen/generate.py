#!/usr/bin/env python3
"""Generate all tiles as MagicaVoxel .vox files (plus .tile.json metadata) into assets/tiles/.

Usage:
  python3 tools/voxgen/generate.py             # only create missing tiles
  python3 tools/voxgen/generate.py --force     # overwrite everything (your own edits are lost!)
  python3 tools/voxgen/generate.py --only weg  # only tiles whose path contains 'weg' (tile paths are Dutch)
  python3 tools/voxgen/generate.py --list      # list all tiles
  python3 tools/voxgen/generate.py --meta      # only (re)write the .tile.json metadata of existing tiles
  python3 tools/voxgen/generate.py --dedup     # only replace identical tiles by aliases (dedupe.py)
  python3 tools/voxgen/generate.py --palettes  # Goxel palette, colour chart and handbook

By default existing tiles (.vox, or a .gox made by hand in Goxel) are NOT overwritten, so
manual changes are kept; --force replaces them by the generated .vox.
Alias tiles (dedupe.py) count as existing. After creating tiles, identical tiles are
replaced by aliases. Every run also writes the colour -> material table
(assets/tiles/materialen.json, vox.write_material_table). Importing the tiles package
(tiles/) fills common.TILES via the @tile/register calls of its modules; each tile
path maps to <OUT>/<path>.vox.
"""
import argparse
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from common import TILES  # noqa: E402
import tiles  # noqa: E402,F401  (registers every tile, see tiles/__init__.py)
from vox import write_tile, write_metadata, write_material_table  # noqa: E402
from dedupe import dedupe, is_alias, write_alias_traffic, TILE_EXTENSIONS  # noqa: E402

# Output root; read by main() at call time (tests patch it).
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "tiles"))


def main():
    """Command line entry point; see the module docstring for the options."""
    ap = argparse.ArgumentParser(description="Generate the tiles into <OUT>/<path>.vox (MagicaVoxel).")
    ap.add_argument("--force", action="store_true", help="overwrite existing tiles")
    ap.add_argument("--only", default=None, metavar="TEXT", help="only tiles whose path contains TEXT")
    ap.add_argument("--list", action="store_true", help="list the tile paths and exit")
    ap.add_argument("--meta", action="store_true", help="only write metadata for existing tiles")
    ap.add_argument("--dedup", action="store_true", help="only replace identical tiles by aliases")
    ap.add_argument("--palettes", action="store_true", help="write the Goxel palette and colour chart (tools/voxgen/paletten)")
    a = ap.parse_args()

    names = sorted(TILES)
    if a.only:
        names = [n for n in names if a.only in n]
    if a.list:
        for n in names:
            print(n)
        print(f"{len(names)} tiles")
        return

    print("  " + os.path.relpath(write_material_table()))

    if a.palettes:
        from palettes import write_palettes
        from handbook import write_handbook
        for path in write_palettes() + [write_handbook()]:
            print("  " + os.path.relpath(path))
        return

    if a.dedup:
        _dedupe()
        return

    if a.meta:
        # every tile on disk, generated or made by hand (not the coarse .lod versions)
        on_disk = {}
        for folder, _, files in os.walk(OUT):
            for f in files:
                base, ext = os.path.splitext(f)
                if ext in TILE_EXTENSIONS and not base.endswith(".lod"):
                    on_disk[os.path.relpath(os.path.join(folder, base), OUT).replace(os.sep, "/")] = os.path.join(folder, f)
        if a.only:
            on_disk = {n: p for n, p in on_disk.items() if a.only in n}
        count = sum(1 for n in sorted(on_disk) if write_metadata(on_disk[n], n))
        print(f"metadata for {count} of {len(on_disk)} tiles ({len(set(on_disk) - set(TILES))} not from the generator)")
        # aliases: only their "traffic" (the rest belongs to the tile they point to)
        alias_names = [n for n in sorted(TILES) if is_alias(OUT, n) and (not a.only or a.only in n)]
        with_traffic = sum(1 for n in alias_names if write_alias_traffic(OUT, n))
        print(f"traffic for {with_traffic} of {len(alias_names)} aliases")
        return

    made = skipped = 0
    t0 = time.time()
    for tile_number, n in enumerate(names, 1):
        path = os.path.join(OUT, n + ".vox")
        exists = any(os.path.exists(os.path.join(OUT, n + e)) for e in TILE_EXTENSIONS)
        if (exists or is_alias(OUT, n)) and not a.force:
            skipped += 1
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        m = TILES[n]()
        cnt = write_tile(path, m)
        for ext in (".gox", ".gox.import"):   # a .gox under the same name would be a second tile
            if os.path.exists(os.path.join(OUT, n + ext)):
                os.remove(os.path.join(OUT, n + ext))
        write_metadata(path, n)
        made += 1
        print(f"[ {100 * tile_number // len(names):3d}% ] {n:60s} {m.sx}x{m.sy}x{m.sz}  {cnt} voxels")
    print(f"{made} created, {skipped} skipped (already existed) in {time.time() - t0:.1f}s")
    if made:
        _dedupe()


def _dedupe():
    """Replace identical tiles by aliases and report them."""
    pairs = dedupe(OUT)
    for alias, kept in pairs:
        print(f"  {alias:60s} -> alias of {kept}")
    print(f"{len(pairs)} identical tiles replaced by aliases")


if __name__ == "__main__":
    main()
