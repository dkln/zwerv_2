#!/usr/bin/env python3
"""Convert MagicaVoxel tiles (.vox) to Goxel tiles (.gox), keeping how they look in Godot.

Usage:
  python3 tools/voxgen/convert_vox.py                    # every .vox below assets/tiles
  python3 tools/voxgen/convert_vox.py path/to/huis.vox   # only these files
  python3 tools/voxgen/convert_vox.py --dry-run          # only report

For every .vox the material of each colour is worked out the way the importer did
for .vox files before Goxel: the MATL chunk of the palette slot (glass, emit, metal,
metal with _rough < 0.15 = panel), the reserved slots 225..232 (water, when glass) and
233..248 (flag), then the "materials" of the .tile.json (palette index or "#rrggbb").
The .gox gets one layer "model" with every voxel whose colour already has that
material in the colour table (assets/tiles/materialen.json), and one layer per other
material (named after it, so the importer forces it) for the rest. A colour that is
one step off a palette colour with the same material (the old flag colours
vlag_wit / vlag_oranje) becomes that palette colour.

Afterwards the .vox and its .vox.import are removed, and palette index keys in the
.tile.json "materials" are dropped (they meant nothing outside the .vox palette).
"""
import argparse
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from gox import write_layers  # noqa: E402
from palette import PALETTE, godot_material  # noqa: E402
from vox import material_table, write_material_table, MATERIAL_NAMES  # noqa: E402

TILES = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "tiles"))
WATER_START, WATER_END = 225, 232
FLAG_START, FLAG_END = 233, 248


def read_vox(path):
    """(size, [(x, y, z, slot)], {slot: (r, g, b)}, {slot: MATL dict}) of the first model."""
    data = open(path, "rb").read()
    if data[:4] != b"VOX ":
        raise ValueError(f"{path}: not a MagicaVoxel file")
    size, voxels, rgba, matl = None, None, {}, {}
    pos = 8
    while pos + 12 <= len(data):
        cid = data[pos:pos + 4]
        content, children = struct.unpack("<ii", data[pos + 4:pos + 12])
        body = data[pos + 12:pos + 12 + content]
        if cid == b"MAIN":
            pos += 12
            continue
        if cid == b"SIZE" and size is None:
            size = struct.unpack("<iii", body[:12])
        elif cid == b"XYZI" and voxels is None:
            (n,) = struct.unpack("<i", body[:4])
            voxels = [tuple(body[4 + k * 4:8 + k * 4]) for k in range(n)]
        elif cid == b"RGBA":
            for i in range(1, 256):
                rgba[i] = tuple(body[(i - 1) * 4:(i - 1) * 4 + 3])
        elif cid == b"MATL":
            matl[struct.unpack("<i", body[:4])[0]] = _read_dict(body, 4)
        pos += 12 + content + children
    if size is None:
        raise ValueError(f"{path}: no model")
    for i in range(1, 256):
        rgba.setdefault(i, (153, 153, 153))   # the importer's default for a missing palette
    return size, voxels or [], rgba, matl


def _read_dict(body, pos):
    out = {}
    (n,) = struct.unpack("<i", body[pos:pos + 4])
    pos += 4
    for _ in range(n):
        parts = []
        for _ in range(2):
            (ln,) = struct.unpack("<i", body[pos:pos + 4])
            parts.append(body[pos + 4:pos + 4 + ln].decode())
            pos += 4 + ln
        out[parts[0]] = parts[1]
    return out


def old_materials(rgba, matl, meta):
    """Material name per palette slot 1..255, as the .vox importer resolved it."""
    out = {}
    for i in range(1, 256):
        kind = matl.get(i, {}).get("_type", "_diffuse")
        m = "opaque"
        if kind in ("_glass", "_blend"):
            m = "water" if WATER_START <= i <= WATER_END else "glass"
        elif kind == "_emit":
            m = "emit"
        elif kind == "_metal":
            m = "panel" if float(matl[i].get("_rough", "1")) < 0.15 else "metal"
        if FLAG_START <= i <= FLAG_END:
            m = "flag"
        out[i] = m
    mats = meta.get("materials", {})
    if isinstance(mats, dict):
        for key, value in mats.items():
            if value not in MATERIAL_NAMES:
                continue
            key = str(key)
            if key.startswith("#"):
                for i in range(1, 256):
                    if "#%02x%02x%02x" % rgba[i] == key.lower():
                        out[i] = value
            elif key.isdigit() and 1 <= int(key) <= 255:
                out[int(key)] = value
    return out


def _snap(rgb, mat, table):
    """A palette colour at most one step per channel from rgb with material mat, or rgb."""
    if table.get("#%02x%02x%02x" % rgb, "opaque") == mat:
        return rgb
    for gid, p in PALETTE.items():
        if godot_material(gid) == mat and max(abs(p[k] - rgb[k]) for k in range(3)) <= 1:
            return p
    return rgb


def convert(vox_path, table, dry_run=False):
    """Convert one .vox; returns (voxel count, {material: count} of forced voxels)."""
    base = vox_path[:-4]
    meta_path = base + ".tile.json"
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    size, voxels, rgba, matl = read_vox(vox_path)
    mats = old_materials(rgba, matl, meta)
    model, forced = {}, {}
    for x, y, z, slot in voxels:
        if x >= size[0] or y >= size[1] or z >= size[2]:
            continue
        mat = mats[slot]
        rgb = _snap(rgba[slot], mat, table)
        if table.get("#%02x%02x%02x" % rgb, "opaque") == mat:
            model[(x, y, z)] = rgb
        else:
            forced.setdefault(mat, {})[(x, y, z)] = rgb
    if not dry_run:
        layers = [("model", None, model)] + [(m, m, v) for m, v in sorted(forced.items())]
        write_layers(base + ".gox", size, layers)
        for ext in (".vox", ".vox.import"):
            if os.path.exists(base + ext):
                os.remove(base + ext)
        _clean_meta(meta_path, meta)
    return len(model) + sum(len(v) for v in forced.values()), {m: len(v) for m, v in forced.items()}


def _clean_meta(meta_path, meta):
    """Drop palette index keys from "materials" (and "materials" itself when empty)."""
    mats = meta.get("materials")
    if not isinstance(mats, dict):
        return
    keep = {k: v for k, v in mats.items() if str(k).startswith("#")}
    if keep == mats:
        return
    if keep:
        meta["materials"] = keep
    else:
        del meta["materials"]
    with open(meta_path, "w") as fh:
        fh.write(json.dumps(meta, indent="\t") + "\n")


def main():
    ap = argparse.ArgumentParser(description="Convert .vox tiles to .gox (Goxel).")
    ap.add_argument("files", nargs="*", help=".vox files (default: every .vox below assets/tiles)")
    ap.add_argument("--dry-run", action="store_true", help="only report what would happen")
    a = ap.parse_args()
    files = a.files
    if not files:
        files = sorted(os.path.join(d, f) for d, _, fs in os.walk(TILES) for f in fs if f.endswith(".vox"))
    write_material_table()
    table = material_table()
    total_forced = {}
    for file_number, path in enumerate(files, 1):
        if file_number % 50 == 0 or file_number == len(files):
            print(f"[ {100 * file_number // len(files):3d}% ] {file_number}/{len(files)} files", flush=True)
        if os.path.exists(path[:-4] + ".gox"):
            print(f"  {os.path.relpath(path)}: a .gox with this name exists, skipped")
            continue
        n, forced = convert(path, table, a.dry_run)
        for m, c in forced.items():
            total_forced[m] = total_forced.get(m, 0) + c
        if forced:
            print(f"  {os.path.relpath(path)}: {n} voxels, material layers {forced}")
    print(f"{len(files)} files {'checked' if a.dry_run else 'converted'}; voxels on material layers: {total_forced or 'none'}")


if __name__ == "__main__":
    main()
