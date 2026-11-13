"""The MagicaVoxel (.vox) tile writer, the tile format of Zwervr.

A .vox holds one model of at most 256 voxels a side and a palette of 255 colours; every
voxel is a palette index. The Godot importer reads it (addons/vox_tiles/importer/
vox_parser.gd) into the same voxel model as a Goxel .gox (gox_parser.gd, still readable),
and works out the material of every colour the same way (voxel_model.gd): the tile metadata
"materials" (a "#rrggbb" colour, or for a .vox a palette index), then the colour table of
the project (assets/tiles/materialen.json), else opaque.

Coordinates are those of the model: x = left->right, y = front->back, z = up (MagicaVoxel's
own axes); the front of a tile is the y = 0 side.

Used by vox.write_tile (the generator) and convert_gox.py (the .gox tiles of before).
"""
import struct

MAX_SIDE = 256
MAX_COLOURS = 255
VERSION = 150


def _chunk(kind, content, children=b""):
    return kind + struct.pack("<ii", len(content), len(children)) + content + children


def palette_slots(keys):
    """Palette slots (1..255) for ``keys`` (anything hashable with an rgb as its first part,
    e.g. (rgb, forced material)), in the order given. More than 255: the rest take the
    nearest slot whose key has the same second part (or any slot). Returns (slot per key,
    the keys of the slots 1..n, how many keys share a slot)."""
    slot_of, slots, shared = {}, [], 0
    for key in keys:
        if key in slot_of:
            continue
        if len(slots) < MAX_COLOURS:
            slots.append(key)
            slot_of[key] = len(slots)
            continue
        shared += 1
        rgb = key[0]
        best, best_d = 1, None
        for index, other in enumerate(slots, 1):
            if len(key) > 1 and len(other) > 1 and other[1] != key[1]:
                continue
            d = sum((a - b) ** 2 for a, b in zip(rgb, other[0]))
            if best_d is None or d < best_d:
                best, best_d = index, d
        slot_of[key] = best
    return slot_of, slots, shared


def write_vox(path, size, voxels, palette, extra_colours=()):
    """Write a .vox of model size ``size`` (sx, sy, sz, each 1..256) with ``voxels``: a list
    of (x, y, z, slot), and ``palette``: the rgb of slots 1..n. The rest of the 255 slots get
    ``extra_colours`` (rgb, those not in the palette yet: the colours to draw with in
    MagicaVoxel), then a neutral grey. Returns the number of voxels written."""
    sx, sy, sz = size
    if not (0 < sx <= MAX_SIDE and 0 < sy <= MAX_SIDE and 0 < sz <= MAX_SIDE):
        raise ValueError(f"{path}: model of {size} voxels does not fit a .vox (at most {MAX_SIDE} a side)")
    colours = [tuple(c) for c in palette][:MAX_COLOURS]
    have = set(colours)
    for rgb in extra_colours:
        if len(colours) >= MAX_COLOURS:
            break
        rgb = tuple(rgb)
        if rgb not in have:
            colours.append(rgb)
            have.add(rgb)
    while len(colours) < MAX_COLOURS:
        colours.append((128, 128, 128))
    body = bytearray()
    for x, y, z, slot in voxels:
        body += bytes((x, y, z, slot))
    rgba = b"".join(bytes((r, g, b, 255)) for r, g, b in colours) + bytes((0, 0, 0, 0))
    children = (_chunk(b"SIZE", struct.pack("<iii", sx, sy, sz))
                + _chunk(b"XYZI", struct.pack("<i", len(voxels)) + bytes(body))
                + _chunk(b"RGBA", rgba))
    with open(path, "wb") as fh:
        fh.write(b"VOX " + struct.pack("<i", VERSION) + _chunk(b"MAIN", b"", children))
    return len(voxels)


def write_colours(path, size, voxels, extra_colours=()):
    """Write a .vox from ``voxels``: model (x, y, z) -> (r, g, b), the palette made from the
    colours in the order they first appear (z, y, x, as the importer counts them). Returns
    the number of voxels written."""
    order = sorted(voxels, key=lambda p: (p[2], p[1], p[0]))
    slot_of, slots, _ = palette_slots([(voxels[p],) for p in order])
    rows = [(x, y, z, slot_of[(voxels[(x, y, z)],)]) for x, y, z in order]
    return write_vox(path, size, rows, [key[0] for key in slots], extra_colours)


def read_vox(path):
    """(size, [(x, y, z, slot)], {slot: (r, g, b)}) of the first model of a .vox."""
    data = open(path, "rb").read()
    if data[:4] != b"VOX ":
        raise ValueError(f"{path}: not a MagicaVoxel file")
    size, voxels, palette = None, None, {}
    pos = 8
    while pos + 12 <= len(data):
        kind = data[pos:pos + 4]
        content, children = struct.unpack("<ii", data[pos + 4:pos + 12])
        body = data[pos + 12:pos + 12 + content]
        if kind == b"MAIN":
            pos += 12
            continue
        if kind == b"SIZE" and size is None:
            size = struct.unpack("<iii", body[:12])
        elif kind == b"XYZI" and voxels is None:
            (count,) = struct.unpack("<i", body[:4])
            voxels = [tuple(body[4 + k * 4:8 + k * 4]) for k in range(count)]
        elif kind == b"RGBA":
            for slot in range(1, 256):
                palette[slot] = tuple(body[(slot - 1) * 4:(slot - 1) * 4 + 3])
        pos += 12 + content + children
    if size is None:
        raise ValueError(f"{path}: no model")
    return size, voxels or [], palette
