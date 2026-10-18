"""Minimale MagicaVoxel (.vox) schrijver + voxel-model met tekenhulpjes.

Coordinaten volgen MagicaVoxel: x = links->rechts, y = voor->achter, z = omhoog.
De voorkant van een tile is de y=0 kant (in Godot wordt dat +Z).
"""
import math
import struct
from array import array

from palette import PALETTE, MATERIALS, P, ORDER, WATER_START, FLAG_START


def h(x, y=0, z=0, seed=0):
    """Deterministische hash -> float in [0, 1)."""
    n = (x * 374761393 + y * 668265263 + z * 2147483647 + seed * 974634281) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFFFF) / float(0x1000000)


def pick(names, x, y=0, z=0, seed=0, weights=None):
    """Kies deterministisch een kleur uit een lijst namen (voor variatie)."""
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
    """Kleurfunctie die per voxel varieert."""
    def f(x, y, z):
        return pick(names, x, y, z, seed, weights)
    return f


def blocky(names, size=2, seed=0, weights=None):
    """Variatie per blok van size x size x size (bv. tegels, stenen)."""
    def f(x, y, z):
        return pick(names, x // size, y // size, z // size, seed, weights)
    return f


def col(c):
    """Normaliseer een kleur (naam, index of functie) naar een functie."""
    if callable(c):
        return c
    if isinstance(c, str):
        idx = P[c]
    else:
        idx = c
    return lambda x, y, z: idx


class V:
    def __init__(self, sx, sy, sz):
        assert 0 < sx <= 256 and 0 < sy <= 256 and 0 < sz <= 256, (sx, sy, sz)
        self.sx, self.sy, self.sz = sx, sy, sz
        self.d = array("H", bytes(2 * sx * sy * sz))

    def _i(self, x, y, z):
        return x + self.sx * (y + self.sy * z)

    def inside(self, x, y, z):
        return 0 <= x < self.sx and 0 <= y < self.sy and 0 <= z < self.sz

    def get(self, x, y, z):
        if not self.inside(x, y, z):
            return 0
        return self.d[self._i(x, y, z)]

    def set(self, x, y, z, c):
        x, y, z = int(x), int(y), int(z)
        if not self.inside(x, y, z):
            return
        if callable(c):
            c = c(x, y, z)
        elif isinstance(c, str):
            c = P[c]
        self.d[self._i(x, y, z)] = c

    def box(self, x0, y0, z0, x1, y1, z1, c):
        """Vul [x0,x1) x [y0,y1) x [z0,z1)."""
        f = col(c) if c else (lambda x, y, z: 0)
        for z in range(max(0, z0), min(self.sz, z1)):
            for y in range(max(0, y0), min(self.sy, y1)):
                base = self.sx * (y + self.sy * z)
                for x in range(max(0, x0), min(self.sx, x1)):
                    self.d[base + x] = f(x, y, z)

    def clear(self, x0, y0, z0, x1, y1, z1):
        self.box(x0, y0, z0, x1, y1, z1, 0)

    def replace(self, x0, y0, z0, x1, y1, z1, c):
        """Vul alleen waar al een voxel staat."""
        f = col(c)
        for z in range(max(0, z0), min(self.sz, z1)):
            for y in range(max(0, y0), min(self.sy, y1)):
                for x in range(max(0, x0), min(self.sx, x1)):
                    i = self._i(x, y, z)
                    if self.d[i]:
                        self.d[i] = f(x, y, z)

    def cyl(self, cx, cy, r, z0, z1, c):
        """Verticale cilinder; cx, cy mogen halve waarden zijn."""
        f = col(c)
        for z in range(max(0, z0), min(self.sz, z1)):
            for y in range(int(cy - r - 1), int(cy + r + 2)):
                for x in range(int(cx - r - 1), int(cx + r + 2)):
                    if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r and self.inside(x, y, z):
                        self.d[self._i(x, y, z)] = f(x, y, z)

    def ellipsoid(self, cx, cy, cz, rx, ry, rz, c, keep=None):
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
        """Lijn van p0 naar p1 (float coords), optioneel met dikte r."""
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
        for z in range(other.sz):
            for y in range(other.sy):
                for x in range(other.sx):
                    c = other.d[other._i(x, y, z)]
                    if c:
                        self.set(ox + x, oy + y, oz + z, c)

    def top(self, x, y):
        """Hoogste gevulde z + 1 (0 als leeg)."""
        for z in range(self.sz - 1, -1, -1):
            if self.d[self._i(x, y, z)]:
                return z + 1
        return 0

    def rot90(self, k=1):
        """Draai k keer 90 graden tegen de klok in rond z (van boven gezien)."""
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
        n = V(self.sx, self.sy, self.sz)
        for z in range(self.sz):
            for y in range(self.sy):
                for x in range(self.sx):
                    n.d[n._i(self.sx - 1 - x, y, z)] = self.d[self._i(x, y, z)]
        return n

    def count(self):
        return sum(1 for v in self.d if v)


# ---------------------------------------------------------------- schrijven

def _chunk(cid, content, children=b""):
    return cid + struct.pack("<ii", len(content), len(children)) + content + children


def _dict(d):
    out = struct.pack("<i", len(d))
    for k, v in d.items():
        kb, vb = k.encode(), str(v).encode()
        out += struct.pack("<i", len(kb)) + kb + struct.pack("<i", len(vb)) + vb
    return out


def _matl(mat):
    if mat == "glass":
        return {"_type": "_glass", "_trans": "0.5", "_rough": "0.05", "_ior": "0.5", "_d": "0.05"}
    if mat == "water":
        return {"_type": "_glass", "_trans": "0.6", "_rough": "0.1", "_ior": "0.33", "_d": "0.2"}
    if mat == "emit":
        return {"_type": "_emit", "_emit": "1", "_flux": "2", "_ldr": "0.5"}
    if mat == "metal":
        return {"_type": "_metal", "_metal": "0.7", "_rough": "0.3", "_sp": "0.5"}
    if mat == "paneel":   # glanzend metaal (zonnepanelen); importer: _rough < 0.15
        return {"_type": "_metal", "_metal": "0.8", "_rough": "0.1", "_sp": "0.8"}
    return {"_type": "_diffuse"}


def write_vox(path, m):
    used = sorted(set(m.d) - {0})
    special = ("water", "flag")
    normal = [c for c in used if MATERIALS.get(c) not in special]
    water = [c for c in used if MATERIALS.get(c) == "water"]
    flag = [c for c in used if MATERIALS.get(c) == "flag"]
    assert len(normal) <= WATER_START - 1, f"{path}: te veel kleuren ({len(normal)})"
    assert len(water) <= 8, f"{path}: te veel waterkleuren"
    assert len(flag) <= 16, f"{path}: te veel vlagkleuren"
    # palet van dit bestand: gebruikte kleuren eerst, dan de rest van het globale palet
    slots = {}
    nxt = 1
    for c in normal + [c for c in ORDER if MATERIALS.get(c) not in special and c not in normal]:
        if nxt >= WATER_START:
            break
        slots[c] = nxt
        nxt += 1
    for kind, lst, start, end in (("water", water, WATER_START, FLAG_START - 1), ("flag", flag, FLAG_START, FLAG_START + 15)):
        n2 = start
        for c in lst + [c for c in ORDER if MATERIALS.get(c) == kind and c not in lst]:
            if n2 > end:
                break
            slots[c] = n2
            n2 += 1
    file_pal = {v: k for k, v in slots.items()}

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
