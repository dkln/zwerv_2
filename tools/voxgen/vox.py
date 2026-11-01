"""Voxel model with drawing helpers, the Goxel (.gox) tile writer, the colour ->
material table and the .tile.json metadata writer.

Pipeline position: palette.py defines the global colours -> tile modules build a
``V`` model with the helpers below -> generate.py calls ``write_tile`` and
``write_metadata`` for every registered tile and ``write_material_table`` once.

Coordinates follow Goxel: x = left->right, y = front->back, z = up; sizes are in
voxels of 12.5 cm. The front of a tile is the y=0 side (Godot +Z). Voxel values in a
V are *global* colour ids from palette.P (0 = empty); write_tile stores their colours.
"""
import json
import os
import struct
from array import array

from palette import PALETTE, P, godot_material
from gox import write_layers
from common import SLOPES, CURVES, SMOOTH


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


# ---------------------------------------------------------------- .gox writing

def write_tile(path, m):
    """Write model ``m`` (global colour ids) to ``path`` as a Goxel .gox with one layer
    "model"; returns the voxel count. The colour of a voxel is all a tile stores: the
    importer looks its material up in the colour table (write_material_table)."""
    voxels = {}
    for z in range(m.sz):
        for y in range(m.sy):
            base = m.sx * (y + m.sy * z)
            for x in range(m.sx):
                c = m.d[base + x]
                if c:
                    voxels[(x, y, z)] = PALETTE[c]
    return write_layers(path, (m.sx, m.sy, m.sz), [("model", None, voxels)])


# Material names of the Godot importer (addons/vox_tiles/importer/voxel_model.gd
# MATERIAL_NAMES); a Goxel layer with one of these names forces that material.
MATERIAL_NAMES = ("opaque", "metal", "glass", "emit", "water", "flag", "panel", "asphalt", "stone", "brick",
                  "gravel", "painted", "paving", "cobble", "plaster")


# Colour -> material table of the whole project, read by the Godot importer
# (addons/vox_tiles/importer/voxel_model.gd).
MATERIAL_TABLE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "tiles", "materialen.json"))


def material_table():
    """"#rrggbb" -> Godot material name for every palette colour that is not plain
    opaque. Asserts that no colour is used with two different materials."""
    out = {}
    for gid, rgb in PALETTE.items():
        mat = godot_material(gid)
        key = "#%02x%02x%02x" % rgb
        assert out.get(key, mat) == mat, f"colour {key} has two materials: {out[key]} and {mat}"
        if mat != "opaque" or key in out:
            out[key] = mat
    return dict(sorted(out.items(), key=lambda kv: (kv[1], kv[0])))


def write_material_table(path=MATERIAL_TABLE):
    """Write the colour table (material_table) as JSON, only when it changed (a change
    makes Godot reimport every tile). Returns the path."""
    text = json.dumps(material_table(), indent="\t") + "\n"
    old = open(path).read() if os.path.exists(path) else None
    if old != text:
        with open(path, "w") as fh:
            fh.write(text)
    return path


# ---------------------------------------------------------------- tile metadata
# <tile>.tile.json next to each tile file, read by addons/vox_tiles/importer/tile_metadata.gd.

# tile base names that bob on the water (animation "float")
_FLOAT_PREFIXES = ("sloep", "roeiboot", "reddingsboei", "woonboot", "water_lelies")


def tile_animation(name):
    """Animation for a tile path such as 'props/water/sloep' (same rules the importer used to guess).

    "float" for boats/buoys/water lilies (by base name prefix), "flowers" for flower beds
    in the ground (sway just above the ground), "wind" for trees,
    plants, hedges, planters and reed (except reed roofs under /daken/), else None.
    """
    base = os.path.basename(name)
    if base.startswith(_FLOAT_PREFIXES):
        return "float"
    path = "/" + name
    if "bloemperk" in base:
        return "flowers"
    if ("/bomen/" in path or "/planten/" in path or "/haag" in path or "bloembak" in path
            or "riet" in path and "/daken/" not in path):
        return "wind"
    return None


_LIBRARIES = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "libraries"))
_registries = {}   # category -> {tile key: id}, loaded on first use


def registry_id(name):
    """MeshLibrary item id of tile path ``name`` (e.g. 'grond/weg/x') from the id
    registry assets/libraries/<category>_ids.json that Godot's library builder
    keeps, or None if the tile has no id yet (not imported)."""
    cat, _, key = name.partition("/")
    if cat not in _registries:
        path = os.path.join(_LIBRARIES, cat + "_ids.json")
        _registries[cat] = json.load(open(path)) if os.path.exists(path) else {}
    return _registries[cat].get(key)


def write_metadata(tile_path, name):
    """Write <tile>.tile.json next to ``tile_path`` (the .gox) for tile path ``name``.

    Contents:
    - ``"id"``: the MeshLibrary item id. An id already in the file is kept (it may
      have been chosen by hand); otherwise the id from the registry (registry_id).
    - ``"animation"`` (from tile_animation).
    - ``"materials"``: only "#rrggbb" overrides already in the file (made by hand) are
      kept; the materials of the palette colours come from the colour table
      (write_material_table), not from the tile metadata.
    - ``"slopes"``: slope shapes the importer makes of the tile, and ``"curve"``:
      [i, j, parts] of a curve cell for the curve shapes (common.slopes).
    - ``"smooth"``: the tile is a padded block the importer smooths (common.smooth).
    The file is removed when there is nothing to record and left untouched when
    its content would not change. Returns the metadata dict, or None.
    """
    meta_path = os.path.splitext(tile_path)[0] + ".tile.json"
    old = open(meta_path).read() if os.path.exists(meta_path) else None
    meta = {}
    try:
        old_meta = json.loads(old) if old else {}
        if not isinstance(old_meta, dict):
            old_meta = {}
    except ValueError:
        old_meta = {}
    tile_id = old_meta.get("id")
    if tile_id is None:
        tile_id = registry_id(name)
    if tile_id is not None:
        meta["id"] = tile_id
    anim = tile_animation(name)
    if anim:
        meta["animation"] = anim
    old_mats = old_meta.get("materials")
    mats = {k: v for k, v in old_mats.items() if k.startswith("#")} if isinstance(old_mats, dict) else {}
    if mats:
        meta["materials"] = mats
    if name in SLOPES:
        meta["slopes"] = SLOPES[name]
    if name in CURVES:
        meta["curve"] = CURVES[name]
    if name in SMOOTH:
        meta["smooth"] = SMOOTH[name]
    if not meta:
        if old is not None:
            os.remove(meta_path)
        return None
    text = json.dumps(meta, indent="\t") + "\n"
    if old != text:   # leave unchanged files alone so Godot doesn't reimport them
        with open(meta_path, "w") as fh:
            fh.write(text)
    return meta
