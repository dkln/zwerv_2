"""Voxel model with drawing helpers, a minimal MagicaVoxel (.vox) writer and the
.tile.json metadata writer.

Pipeline position: palette.py defines the global colours -> tile modules build a
``V`` model with the helpers below -> generate.py calls ``write_vox`` and
``write_metadata`` for every registered tile.

Coordinates follow MagicaVoxel: x = left->right, y = front->back, z = up; sizes are
in voxels of 12.5 cm. The front of a tile is the y=0 side (Godot +Z). Voxel values
in a V are *global* colour ids from palette.P (0 = empty); write_vox maps them to
the 255 palette slots of the file.
"""
import json
import os
import struct
from array import array

from palette import PALETTE, MATERIALS, P, ORDER, WATER_START, FLAG_START


def h(x, y=0, z=0, seed=0):
    """Deterministic integer hash of (x, y, z, seed) -> float in [0, 1). Pure function."""
    n = (x * 374761393 + y * 668265263 + z * 2147483647 + seed * 974634281) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFFFF) / float(0x1000000)


def pick(names, x, y=0, z=0, seed=0, weights=None):
    """Deterministically pick a colour id from a list of colour names.

    The choice is driven by h(x, y, z, seed); with ``weights`` (same length as
    ``names``) the names are chosen proportionally, otherwise uniformly.
    """
    r = h(x, y, z, seed)
    if weights is None:
        return P[names[int(r * len(names)) % len(names)]]
    tot = sum(weights)
    acc = 0.0
    for name, w in zip(names, weights):
        acc += w / tot
        if r < acc:
            return P[name]
    return P[names[-1]]


def mix(*names, seed=0, weights=None):
    """Colour function ``f(x, y, z)`` that picks one of ``names`` per voxel."""
    def f(x, y, z):
        return pick(names, x, y, z, seed, weights)
    return f


def blocky(names, size=2, seed=0, weights=None):
    """Colour function that picks one of ``names`` per size x size x size block (tiles, stones)."""
    def f(x, y, z):
        return pick(names, x // size, y // size, z // size, seed, weights)
    return f


def col(c):
    """Normalise a colour (name, global id or function) to a function ``f(x, y, z) -> id``."""
    if callable(c):
        return c
    if isinstance(c, str):
        idx = P[c]
    else:
        idx = c
    return lambda x, y, z: idx


class V:
    """Dense voxel model of sx x sy x sz (each 1..256) holding global colour ids.

    Colour arguments ``c`` of the drawing methods may be a colour name, a global id
    or a function ``f(x, y, z) -> id`` evaluated per voxel (see mix/blocky/col).
    Writes outside the model are silently clipped; later writes overwrite earlier ones.
    """

    def __init__(self, sx, sy, sz):
        assert 0 < sx <= 256 and 0 < sy <= 256 and 0 < sz <= 256, (sx, sy, sz)
        self.sx, self.sy, self.sz = sx, sy, sz
        self.d = array("H", bytes(2 * sx * sy * sz))

    def _i(self, x, y, z):
        return x + self.sx * (y + self.sy * z)

    def inside(self, x, y, z):
        """True if (x, y, z) lies within the model bounds."""
        return 0 <= x < self.sx and 0 <= y < self.sy and 0 <= z < self.sz

    def get(self, x, y, z):
        """Colour id at (x, y, z); 0 for empty or out-of-bounds."""
        if not self.inside(x, y, z):
            return 0
        return self.d[self._i(x, y, z)]

    def set(self, x, y, z, c):
        """Set one voxel (coordinates are truncated with int()); ignored when outside."""
        x, y, z = int(x), int(y), int(z)
        if not self.inside(x, y, z):
            return
        if callable(c):
            c = c(x, y, z)
        elif isinstance(c, str):
            c = P[c]
        self.d[self._i(x, y, z)] = c

    def box(self, x0, y0, z0, x1, y1, z1, c):
        """Fill the half-open box [x0,x1) x [y0,y1) x [z0,z1); a falsy ``c`` clears it."""
        f = col(c) if c else (lambda x, y, z: 0)
        for z in range(max(0, z0), min(self.sz, z1)):
            for y in range(max(0, y0), min(self.sy, y1)):
                base = self.sx * (y + self.sy * z)
                for x in range(max(0, x0), min(self.sx, x1)):
                    self.d[base + x] = f(x, y, z)

    def clear(self, x0, y0, z0, x1, y1, z1):
        """Empty the half-open box [x0,x1) x [y0,y1) x [z0,z1)."""
        self.box(x0, y0, z0, x1, y1, z1, 0)

    def replace(self, x0, y0, z0, x1, y1, z1, c):
        """Recolour the box [x0,x1) x [y0,y1) x [z0,z1), only where a voxel already exists."""
        f = col(c)
        for z in range(max(0, z0), min(self.sz, z1)):
            for y in range(max(0, y0), min(self.sy, y1)):
                for x in range(max(0, x0), min(self.sx, x1)):
                    i = self._i(x, y, z)
                    if self.d[i]:
                        self.d[i] = f(x, y, z)

    def cyl(self, cx, cy, r, z0, z1, c):
        """Vertical cylinder of radius r around (cx, cy) for z in [z0, z1); cx, cy may be half values.

        A voxel is filled when its centre (x + 0.5, y + 0.5) lies within r.
        """
        f = col(c)
        for z in range(max(0, z0), min(self.sz, z1)):
            for y in range(int(cy - r - 1), int(cy + r + 2)):
                for x in range(int(cx - r - 1), int(cx + r + 2)):
                    if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r and self.inside(x, y, z):
                        self.d[self._i(x, y, z)] = f(x, y, z)

    def ellipsoid(self, cx, cy, cz, rx, ry, rz, c, keep=None):
        """Filled ellipsoid with centre (cx, cy, cz) and radii (rx, ry, rz), tested at voxel centres.

        ``keep(x, y, z, d)`` (optional) gets the normalised squared distance d (<= 1)
        and decides per voxel whether it is drawn (e.g. for hollow or ragged crowns).
        """
        f = col(c)
        for z in range(int(cz - rz - 1), int(cz + rz + 2)):
            for y in range(int(cy - ry - 1), int(cy + ry + 2)):
                for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                    if not self.inside(x, y, z):
                        continue
                    dx = (x + 0.5 - cx) / rx
                    dy = (y + 0.5 - cy) / ry
                    dz = (z + 0.5 - cz) / rz
                    d = dx * dx + dy * dy + dz * dz
                    if d <= 1.0 and (keep is None or keep(x, y, z, d)):
                        self.d[self._i(x, y, z)] = f(x, y, z)

    def line(self, p0, p1, c, r=0.0):
        """Line from p0 to p1 (float (x, y, z) tuples), optionally thickened to radius r.

        Samples at twice the longest axis extent; for r <= 0.5 one voxel per sample,
        otherwise a sphere of radius r (integer offsets) around each sample.
        """
        f = col(c)
        (x0, y0, z0), (x1, y1, z1) = p0, p1
        n = int(max(abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x, y, z = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t
            if r <= 0.5:
                if self.inside(int(x), int(y), int(z)):
                    self.d[self._i(int(x), int(y), int(z))] = f(int(x), int(y), int(z))
            else:
                ri = int(r) + 1
                for dz in range(-ri, ri + 1):
                    for dy in range(-ri, ri + 1):
                        for dx in range(-ri, ri + 1):
                            if dx * dx + dy * dy + dz * dz <= r * r:
                                xx, yy, zz = int(x + dx), int(y + dy), int(z + dz)
                                if self.inside(xx, yy, zz):
                                    self.d[self._i(xx, yy, zz)] = f(xx, yy, zz)

    def paste(self, other, ox, oy, oz):
        """Copy the non-empty voxels of ``other`` into this model at offset (ox, oy, oz)."""
        for z in range(other.sz):
            for y in range(other.sy):
                for x in range(other.sx):
                    c = other.d[other._i(x, y, z)]
                    if c:
                        self.set(ox + x, oy + y, oz + z, c)

    def top(self, x, y):
        """Highest filled z + 1 in column (x, y); 0 if the column is empty."""
        for z in range(self.sz - 1, -1, -1):
            if self.d[self._i(x, y, z)]:
                return z + 1
        return 0

    def rot90(self, k=1):
        """Return a copy rotated k times 90 degrees counter-clockwise around z (seen from above).

        Each step maps (x, y) -> (sy - 1 - y, x) and swaps sx and sy.
        """
        m = self
        for _ in range(k % 4):
            n = V(m.sy, m.sx, m.sz)
            for z in range(m.sz):
                for y in range(m.sy):
                    for x in range(m.sx):
                        c = m.d[m._i(x, y, z)]
                        if c:
                            n.d[n._i(m.sy - 1 - y, x, z)] = c
            m = n
        return m

    def mirror_x(self):
        """Return a copy mirrored along x (x -> sx - 1 - x)."""
        n = V(self.sx, self.sy, self.sz)
        for z in range(self.sz):
            for y in range(self.sy):
                for x in range(self.sx):
                    n.d[n._i(self.sx - 1 - x, y, z)] = self.d[self._i(x, y, z)]
        return n

    def count(self):
        """Number of non-empty voxels."""
        return sum(1 for v in self.d if v)


# ---------------------------------------------------------------- .vox writing

def _chunk(cid, content, children=b""):
    """Encode a RIFF-style .vox chunk: id, content size, children size, content, children."""
    return cid + struct.pack("<ii", len(content), len(children)) + content + children


def _dict(d):
    """Encode a .vox DICT: entry count, then (len, key, len, value) with values as strings."""
    out = struct.pack("<i", len(d))
    for k, v in d.items():
        kb, vb = k.encode(), str(v).encode()
        out += struct.pack("<i", len(kb)) + kb + struct.pack("<i", len(vb)) + vb
    return out


def _matl(mat):
    """MagicaVoxel MATL properties for a palette material tag (diffuse for anything else)."""
    if mat == "glass":
        return {"_type": "_glass", "_trans": "0.5", "_rough": "0.05", "_ior": "0.5", "_d": "0.05"}
    if mat == "water":
        return {"_type": "_glass", "_trans": "0.6", "_rough": "0.1", "_ior": "0.33", "_d": "0.2"}
    if mat == "emit":
        return {"_type": "_emit", "_emit": "1", "_flux": "2", "_ldr": "0.5"}
    if mat == "metal":
        return {"_type": "_metal", "_metal": "0.7", "_rough": "0.3", "_sp": "0.5"}
    if mat == "paneel":   # glossy metal (solar panels); the importer checks _rough < 0.15
        return {"_type": "_metal", "_metal": "0.8", "_rough": "0.1", "_sp": "0.8"}
    return {"_type": "_diffuse"}


_SPECIAL = ("water", "flag")   # materials with their own fixed slot range in every file


def _fill_slots(slots, used, pool, start, end):
    """Assign file slots start..end (inclusive): first the ``used`` ids, then the rest of
    ``pool`` (in palette order) until the range is full. Writes into ``slots``."""
    n = start
    for c in used + [c for c in pool if c not in used]:
        if n > end:
            break
        slots[c] = n
        n += 1


def write_vox(path, m):
    """Write model ``m`` to ``path`` as a MagicaVoxel .vox (version 150); returns the voxel count.

    A .vox palette has only 255 slots, so every file gets its own palette built
    from the global colour ids:
      * slots 1..WATER_START-1 (1..224): the normal colours used by this tile first
        (sorted by global id), then the remaining normal colours in palette ORDER
        until the range is full, so they are available for editing in MagicaVoxel;
      * slots WATER_START..FLAG_START-1 (225..232): water colours, used ones first,
        then the other water colours;
      * slots FLAG_START..FLAG_START+15 (233..248): flag colours, same scheme.
    Fixed ranges let the Godot importer recognise water/flag by index as well as by
    colour. Slots left over are black. One MATL chunk per slot 1..255 stores the
    material of that slot (see _matl). Asserts when a tile uses too many colours.
    """
    used = sorted(set(m.d) - {0})
    normal = [c for c in used if MATERIALS.get(c) not in _SPECIAL]
    water = [c for c in used if MATERIALS.get(c) == "water"]
    flag = [c for c in used if MATERIALS.get(c) == "flag"]
    assert len(normal) <= WATER_START - 1, f"{path}: too many colours ({len(normal)})"
    assert len(water) <= 8, f"{path}: too many water colours"
    assert len(flag) <= 16, f"{path}: too many flag colours"
    slots = {}   # global id -> file palette slot
    _fill_slots(slots, normal, [c for c in ORDER if MATERIALS.get(c) not in _SPECIAL], 1, WATER_START - 1)
    _fill_slots(slots, water, [c for c in ORDER if MATERIALS.get(c) == "water"], WATER_START, FLAG_START - 1)
    _fill_slots(slots, flag, [c for c in ORDER if MATERIALS.get(c) == "flag"], FLAG_START, FLAG_START + 15)
    file_pal = {v: k for k, v in slots.items()}   # file slot -> global id

    # XYZI: one (x, y, z, slot) byte quad per voxel, in z/y/x order
    voxels = bytearray()
    n = 0
    for z in range(m.sz):
        for y in range(m.sy):
            for x in range(m.sx):
                c = m.d[m._i(x, y, z)]
                if c:
                    voxels += bytes((x, y, z, slots[c]))
                    n += 1
    size = _chunk(b"SIZE", struct.pack("<iii", m.sx, m.sy, m.sz))
    xyzi = _chunk(b"XYZI", struct.pack("<i", n) + bytes(voxels))
    # RGBA: 256 entries; entry k holds the colour of palette slot k + 1
    rgba = bytearray()
    for i in range(1, 257):
        gid = file_pal.get(i)
        r, g, b = PALETTE[gid] if gid else (0, 0, 0)
        rgba += bytes((r, g, b, 255))
    rgba_chunk = _chunk(b"RGBA", bytes(rgba))
    matl = b""
    for i in range(1, 256):
        gid = file_pal.get(i)
        matl += _chunk(b"MATL", struct.pack("<i", i) + _dict(_matl(MATERIALS.get(gid) if gid else None)))
    children = size + xyzi + rgba_chunk + matl
    data = b"VOX " + struct.pack("<i", 150) + _chunk(b"MAIN", b"", children)
    with open(path, "wb") as fh:
        fh.write(data)
    return n


# ---------------------------------------------------------------- tile metadata
# <tile>.tile.json next to each .vox, read by addons/vox_tiles/tile_metadata.gd.

# tile base names that bob on the water (animation "float")
_FLOAT_PREFIXES = ("sloep", "roeiboot", "reddingsboei", "woonboot", "water_lelies")


def tile_animation(name):
    """Animation for a tile path such as 'props/water/sloep' (same rules the importer used to guess).

    "float" for boats/buoys/water lilies (by base name prefix), "wind" for trees,
    plants, hedges, planters and reed (except reed roofs under /daken/), else None.
    """
    base = os.path.basename(name)
    if base.startswith(_FLOAT_PREFIXES):
        return "float"
    path = "/" + name
    if ("/bomen/" in path or "/planten/" in path or "/haag" in path or "bloembak" in path
            or "riet" in path and "/daken/" not in path):
        return "wind"
    return None


def _read_vox_palette(path):
    """The used palette slots of a .vox file: slot -> ((r, g, b), MATL dict).
    MATL is MagicaVoxel's material per slot ({"_type": "_metal", "_rough": ...});
    empty when the file has none for that slot."""
    with open(path, "rb") as fh:
        data = fh.read()
    used, rgba, matl = set(), {}, {}
    pos = 8
    while pos + 12 <= len(data):
        cid = data[pos:pos + 4]
        content, children = struct.unpack("<ii", data[pos + 4:pos + 12])
        body = data[pos + 12:pos + 12 + content]
        if cid == b"MAIN":   # descend into MAIN's children
            pos += 12
            continue
        if cid == b"XYZI" and not used:   # first model only; byte 3 of each voxel = slot
            n = struct.unpack("<i", body[:4])[0]
            used = {body[4 + k * 4 + 3] for k in range(n)}
        elif cid == b"RGBA":   # entry i - 1 is slot i
            for i in range(1, 256):
                rgba[i] = tuple(body[(i - 1) * 4:(i - 1) * 4 + 3])
        elif cid == b"MATL":
            matl[struct.unpack("<i", body[:4])[0]] = _read_dict(body, 4)
        pos += 12 + content + children
    return {i: (rgba[i], matl.get(i, {})) for i in sorted(used) if i in rgba}


def _read_dict(body, pos):
    """Parse a MagicaVoxel DICT (count, then length-prefixed key/value strings)."""
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


# Surface materials MagicaVoxel doesn't know (asphalt, stone) can only be found by
# colour. rgb -> material, only where unambiguous: different palette entries can
# share an rgb (e.g. 'antraciet2' and 'metaal_donker').
_COLOR_MATERIALS = {}
for _gid, _rgb in PALETTE.items():
    _COLOR_MATERIALS.setdefault(_rgb, set()).add(MATERIALS.get(_gid))
_SURFACE_COLOR = {rgb: next(iter(m)) for rgb, m in _COLOR_MATERIALS.items()
                  if len(m) == 1 and next(iter(m)) in ("asphalt", "stone")}


def _material_at(slot, rgb, matl):
    """Metadata material of a palette slot, or None for plain opaque. Water and
    flag follow from the reserved slot ranges (write_vox puts them there), metal,
    panel, glass and emit from the slot's MATL, asphalt and stone from the colour.
    The same rules as the Godot importer's parser (vox_parser.gd)."""
    kind = matl.get("_type", "_diffuse")
    if FLAG_START <= slot < FLAG_START + 16:
        return "flag"
    if kind in ("_glass", "_blend"):
        return "water" if WATER_START <= slot < FLAG_START else "glass"
    if kind == "_emit":
        return "emit"
    if kind == "_metal":
        return "panel" if float(matl.get("_rough", "1")) < 0.15 else "metal"
    return _SURFACE_COLOR.get(rgb)


def registry_id(name):
    """MeshLibrary item id of tile path ``name`` (e.g. 'grond/weg/x') from the id
    registry assets/libraries/<category>_ids.json that Godot's library builder
    keeps, or None if the tile has no id yet (not imported)."""
    cat, _, key = name.partition("/")
    if cat not in _registries:
        path = os.path.join(_LIBRARIES, cat + "_ids.json")
        _registries[cat] = json.load(open(path)) if os.path.exists(path) else {}
    return _registries[cat].get(key)


def write_metadata(vox_path, name):
    """Write <tile>.tile.json next to ``vox_path`` for tile path ``name``.

    Contents:
    - ``"id"``: the MeshLibrary item id. An id already in the file is kept (it may
      have been chosen by hand); otherwise the id from the registry (registry_id).
    - ``"animation"`` (from tile_animation).
    - ``"materials"``: palette index (as string) -> material for every *used*
      index whose colour has a special material (water, flag, glass, metal,
      panel, emit, asphalt, stone). The palette is read back from the .vox
      itself, so the metadata stays correct after edits in MagicaVoxel.
    The file is removed when there is nothing to record and left untouched when
    its content would not change. Returns the metadata dict, or None.
    """
    meta_path = os.path.splitext(vox_path)[0] + ".tile.json"
    old = open(meta_path).read() if os.path.exists(meta_path) else None
    meta = {}
    try:
        tile_id = json.loads(old).get("id") if old else None
    except (ValueError, AttributeError):
        tile_id = None
    if tile_id is None:
        tile_id = registry_id(name)
    if tile_id is not None:
        meta["id"] = tile_id
    anim = tile_animation(name)
    if anim:
        meta["animation"] = anim
    mats = {}
    for i, (rgb, matl) in _read_vox_palette(vox_path).items():
        mat = _material_at(i, rgb, matl)
        if mat:
            mats[str(i)] = mat
    if mats:
        meta["materials"] = mats
    if not meta:
        if old is not None:
            os.remove(meta_path)
        return None
    text = json.dumps(meta, indent="\t") + "\n"
    if old != text:   # leave unchanged files alone so Godot doesn't reimport them
        with open(meta_path, "w") as fh:
            fh.write(text)
    return meta
