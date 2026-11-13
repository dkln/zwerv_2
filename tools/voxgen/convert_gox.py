#!/usr/bin/env python3
"""Convert Goxel tiles (.gox) to MagicaVoxel tiles (.vox), keeping how they look in Godot.

Usage:
  python3 tools/voxgen/convert_gox.py                    # every .gox below assets/tiles
  python3 tools/voxgen/convert_gox.py path/to/huis.gox   # only these files
  python3 tools/voxgen/convert_gox.py --keep             # keep the .gox (to compare first)
  python3 tools/voxgen/convert_gox.py --remove-gox       # only remove the .gox whose .vox exists
  python3 tools/voxgen/convert_gox.py --dry-run          # only report

The .gox is read the way the Godot importer reads it (gox.read_gox, the same rules as
addons/vox_tiles/importer/gox_parser.gd): the visible layers merged, clone layers, the
image box as the model size. Every colour gets a palette slot, in the order the importer
counts them (z, y, x); a colour drawn on a material layer of Goxel (a layer named "glass",
"emit", ...) gets a slot of its own, and its material goes into the "materials" of the
.tile.json: as its "#rrggbb" when that colour is only used on that layer, else as the
palette index of its slot (a .vox may use those). The rest of the 255 slots get the colours
of the Zwervr palette, to draw with in MagicaVoxel.

The .vox gets the import settings of the .gox (voxel size, cell block, ...) and its uid,
so everything that refers to the tile keeps working; then the .gox and its .gox.import
are removed (not with --keep). Check the result first with tools/check/gox_vox.gd (keep the
.gox until it passes, then --remove-gox).
"""
import argparse
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from gox import read_gox  # noqa: E402
from palette import PALETTE  # noqa: E402
from vox import MATERIAL_NAMES, material_table  # noqa: E402
from voxfile import MAX_SIDE, palette_slots, write_vox  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
TILES = os.path.join(ROOT, "assets", "tiles")


def _res_path(path):
    return "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")


def convert(gox_path, table, extra, keep=False, dry_run=False):
    """Convert one .gox; returns a line of what happened (or raises ValueError)."""
    base = gox_path[:-4]
    vox_path = base + ".vox"
    model = read_gox(gox_path, MATERIAL_NAMES)
    sx, sy, sz = model.size
    if not model.voxels:
        raise ValueError("no voxels")
    if max(model.size) > MAX_SIDE:
        raise ValueError(f"model of {model.size} voxels is too big for a .vox")
    order = sorted(model.voxels, key=lambda p: (p[2], p[1], p[0]))
    slot_of, slots, shared = palette_slots([model.voxels[p] for p in order])
    rows = [(x, y, z, slot_of[model.voxels[(x, y, z)]]) for x, y, z in order]

    # the materials of the material layers into the metadata
    meta_path = base + ".tile.json"
    meta = json.load(open(meta_path, encoding="utf-8")) if os.path.exists(meta_path) else {}
    materials = meta.get("materials", {}) if isinstance(meta.get("materials"), dict) else {}
    forced_by_colour = {}
    for rgb, forced in slots:
        forced_by_colour.setdefault(rgb, set()).add(forced)
    added = {}
    for index, (rgb, forced) in enumerate(slots, 1):
        if forced is None:
            continue
        key = "#%02x%02x%02x" % rgb
        if key in materials:
            continue   # the metadata decided this colour already (it comes first)
        if forced == table.get(key, "opaque"):
            continue   # the colour table gives it that material anyway
        if forced_by_colour[rgb] == {forced}:
            added[key] = forced
        else:
            added[str(index)] = forced
    notes = []
    if added:
        notes.append(f"{len(added)} materialen in de metadata")
    if shared:
        notes.append(f"{shared} kleuren samengevoegd (meer dan 255)")
    for warning in model.warnings:
        notes.append(warning)
    if dry_run:
        return f"{os.path.relpath(gox_path, ROOT)}: {len(rows)} voxels" + (" (" + ", ".join(notes) + ")" if notes else "")

    write_vox(vox_path, (sx, sy, sz), rows, [key[0] for key in slots], extra)
    if added:
        merged = dict(materials)
        merged.update(added)
        meta["materials"] = merged
        with open(meta_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(json.dumps(meta, indent="\t") + "\n")

    # the import settings and the uid of the .gox
    gox_import = gox_path + ".import"
    if os.path.exists(gox_import):
        text = open(gox_import, encoding="utf-8").read()
        old_res, new_res = _res_path(gox_path), _res_path(vox_path)
        old_dest = "res://.godot/imported/%s-%s.mesh" % (os.path.basename(gox_path), hashlib.md5(old_res.encode()).hexdigest())
        new_dest = "res://.godot/imported/%s-%s.mesh" % (os.path.basename(vox_path), hashlib.md5(new_res.encode()).hexdigest())
        text = text.replace(old_dest, new_dest).replace(old_res, new_res)
        with open(vox_path + ".import", "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        if not keep:
            os.remove(gox_import)
    if not keep:
        os.remove(gox_path)
    return f"{os.path.relpath(gox_path, ROOT)} -> .vox: {len(rows)} voxels" + (" (" + ", ".join(notes) + ")" if notes else "")


def main():
    ap = argparse.ArgumentParser(description="Convert Goxel tiles (.gox) to MagicaVoxel (.vox).")
    ap.add_argument("files", nargs="*", help="only these .gox files")
    ap.add_argument("--keep", action="store_true", help="keep the .gox and its .import")
    ap.add_argument("--remove-gox", action="store_true", help="only remove every .gox (and .import) that has a .vox")
    ap.add_argument("--dry-run", action="store_true", help="only report")
    a = ap.parse_args()
    files = [os.path.abspath(f) for f in a.files]
    if not files:
        for folder, _, names in os.walk(TILES):
            files += [os.path.join(folder, n) for n in sorted(names) if n.endswith(".gox")]
    if a.remove_gox:
        removed = 0
        for path in files:
            if os.path.exists(path[:-4] + ".vox"):
                for p in (path, path + ".import"):
                    if os.path.exists(p):
                        os.remove(p)
                removed += 1
        print(f"{removed} .gox verwijderd")
        return
    table = material_table()
    extra = [PALETTE[gid] for gid in sorted(PALETTE)]
    done, failed = 0, []
    for number, path in enumerate(files, 1):
        try:
            line = convert(path, table, extra, keep=a.keep, dry_run=a.dry_run)
            done += 1
            if "(" in line or number % 250 == 0:
                print(f"[ {100 * number // len(files):3d}% ] {line}")
        except (ValueError, OSError) as error:
            failed.append(f"{os.path.relpath(path, ROOT)}: {error}")
    print(f"{done} omgezet, {len(failed)} niet")
    for line in failed:
        print("  NIET: " + line)


if __name__ == "__main__":
    main()
