"""Ground tiles, extension 3: bridges (drawbridge, wooden footbridges, modern
footbridge, multi-tile steel arch bridge, cable-stayed bridge), cobblestone
variants, and rounded curves for complete street profiles.

Builds on ground.py / ground2.py helpers; curve_polar and the curve profiles are also used by
ground4.py (curves with height). Tiles are 32x32 (T) voxel models
(1 voxel = 12.5 cm; x = left->right, y = front->back, z = up; front = y=0),
registered via @tile / register from common.py and written out by generate.py.
Bridges run along y; multi-tile bridges are registered as numbered pieces.
"""
import math
from functools import partial

from common import T, ROAD, WALK, tile, register
from palette import P
from vox import V, mix, pick
from ground import (column, line_y, cobble_tile, grass_tile, lane, sidewalk, bike_path_straight, street_pavers,
                    road_plain, paver_fn, tram_rails_straight, ASPHALT, DASH, GRASS)
from ground2 import water_bed

# plank deck: 4-voxel planks of mixed wood with a dark joint every third row
WOOD = lambda x, y, z: pick(["hout1", "hout2", "hout3"], x // 4, y, 0, 600) if y % 3 else P["hout_donker1"]
WHITE = "kozijn_wit"


def handrail(m, x, base_fn, color=WHITE, every=4, hgt=7, mid=True):
    """Railing along y at column x.

    base_fn(y) gives the deck height at row y. Draws a top rail at base+hgt, a mid
    rail at base+hgt//2 (if `mid`) and a post from base to base+hgt every `every` rows.
    """
    for y in range(T):
        b = base_fn(y)
        m.set(x, y, b + hgt, color)
        if mid:
            m.set(x, y, b + hgt // 2, color)
        if y % every == 0:
            for z in range(b, b + hgt):
                m.set(x, y, z, color)


# ------------------------------------------------------------------ drawbridge (classic)

def bascule_deck():
    """Wooden drawbridge deck (z=0..1) with white railings on both edges."""
    m = V(T, T, 12)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, "hout_donker2")
            m.set(x, y, 1, WOOD)
    for x in (0, 31):
        handrail(m, x, lambda y: 2)
    return m


@tile("grond/brug/ophaalbrug_dek")
def drawbridge_deck():
    """Plain drawbridge deck piece."""
    return bascule_deck()


@tile("grond/brug/ophaalbrug_portaal")
def drawbridge_portal():
    """Deck with the portal frame and the balance beam (Dutch 'wipbrug' style);
    place at one end of the span."""
    m = V(T, T, 64)
    m.paste(bascule_deck(), 0, 0, 0)
    # two portal posts (x=1 and 30, y=14..17) and the cross beam at z=48..49
    for x in (1, 30):
        for y in (14, 15, 16, 17):
            for z in range(2, 50):
                m.set(x, y, z, WHITE)
    for x in range(1, 31):
        for z in (48, 49):
            m.set(x, 15, z, WHITE)
            m.set(x, 16, z, WHITE)

    def beam_z(y):
        return 52 - int(y * 0.35)

    # balance beams sloping down over the deck towards the back
    for y in range(0, T):
        z = beam_z(y)
        for x in (2, 29):
            m.set(x, y, z, WHITE)
            m.set(x, y, z + 1, WHITE)
    for x in range(2, 30):
        m.set(x, 0, 52, WHITE)
    # dark lattice under the rear part of the beams
    for y in range(0, T, 6):
        z = beam_z(y)
        for x in (2, 29):
            for zz in range(2, z):
                if y > 16 and zz > 6 and (zz + y) % 3 == 0:
                    m.set(x, y, zz, "metaal_donker")
    for x in range(1, 31):
        m.set(x, 15, 50, "lamp_warm" if x in (8, 23) else WHITE)
    return m


# ------------------------------------------------------------------ wooden footbridge (small)

@tile("grond/brug/voetbrug_hout_boog")
def footbridge_wood_arch():
    """Small wooden arched footbridge over a ditch (the water is part of the tile)."""
    m = V(T, T, 18)
    for y in range(T):
        for x in range(T):
            water_bed(m, x, y)
    base = lambda y: WALK - 1 + int(6 * math.sin(math.pi * (y + 0.5) / T))
    for y in range(T):
        b = base(y)
        for x in range(8, 24):
            m.set(x, y, b, WOOD)
            m.set(x, y, b - 1, "hout_donker2")
    for x in (8, 23):
        handrail(m, x, base, "hout_donker1", every=4, hgt=6, mid=False)
    # abutment posts at both ends
    for x in (9, 22):
        for y in (2, 29):
            for z in range(0, WALK + 1):
                m.set(x, y, z, "hout_donker2")
    return m


@tile("grond/brug/voetbrug_hout_vlak")
def footbridge_wood_flat():
    """Flat wooden footbridge at sidewalk height over water, posts down to the bed."""
    m = V(T, T, 12)
    for y in range(T):
        for x in range(T):
            water_bed(m, x, y)
        for x in range(8, 24):
            m.set(x, y, WALK - 1, WOOD)
    for x in (8, 23):
        handrail(m, x, lambda y: 0, "hout_donker1", every=8, hgt=WALK + 6, mid=False)
    return m


# ------------------------------------------------------------------ modern footbridge (small)

@tile("grond/brug/voetbrug_modern")
def footbridge_modern():
    """Concrete footbridge deck (x=6..25) with glass balustrades, steel handrail and deck lights."""
    m = V(T, T, 12)
    for y in range(T):
        for x in range(6, 26):
            m.set(x, y, 0, "metaal3")
            m.set(x, y, 1, mix("beton1", "beton3", seed=601))
        for x in (6, 25):
            for z in range(2, 9):
                m.set(x, y, z, "glas_helder")
            m.set(x, y, 9, "rvs")
        for x in (8, 23):
            m.set(x, y, 2, "lamp_wit" if y % 8 == 0 else "metaal3")
    return m


# ------------------------------------------------------------------ steel arch bridge (large, 5 tiles)

SPAN = 5      # number of tiles along y
ARCH_H = 56   # arch apex height above the deck (voxels)


def _arch(i, y):
    """Global position g (voxels along the span) and arch height za for row y of piece i."""
    g = i * T + y + 0.5
    t = g / (SPAN * T)
    return g, int(4 * ARCH_H * t * (1 - t)) + 2


def steel_arch(i, sides):
    """Piece i (0..SPAN-1) of the steel arch bridge.

    sides: x positions of the arch ribs; (0, 31) = full-width piece with centre line
    and cross bracing between the ribs, (0,) = edge piece with a single rib.
    """
    m = V(T, T, ARCH_H + 12)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, "metaal2")
            m.set(x, y, 1, ASPHALT)
    full = sides == (0, 31)
    if full:
        line_y(m, 16, dash=DASH)
    for y in range(T):
        g, za = _arch(i, y)
        for x in sides:
            # 2-voxel-wide rib, 4 voxels deep, pointing inwards
            for dz in range(0, 4):
                m.set(x, y, za + dz, "stuc1")
                m.set(x + (1 if x == 0 else -1), y, za + dz, "stuc1")
            for z in range(2, 6):
                m.set(x, y, z, "stuc1")
            # vertical hangers every 8 voxels along the whole span
            if int(g) % 8 == 0:
                for z in range(6, za):
                    m.set(x, y, z, "metaal3")
    if full:
        for y in range(T):
            _, za = _arch(i, y)
            if za > 30 and y % 8 == 4:
                for x in range(0, 32):
                    m.set(x, y, za + 1, "stuc1")
    return m


for _i in range(SPAN):
    register(f"grond/brug/staalboog_{_i + 1}", partial(steel_arch, _i, (0, 31)))
    register(f"grond/brug/staalboog_rand_{_i + 1}", partial(steel_arch, _i, (0,)))


# ------------------------------------------------------------------ cable-stayed bridge (large)

PYLON = 120   # pylon height (voxels)


def tui(i):
    """Cable-stayed bridge piece. i=0: the pylon tile (cables on both sides);
    i=1..3: following tiles carrying the cables down to the deck."""
    m = V(T, T, PYLON + 4 if i == 0 else 100)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, "beton_donker")
            m.set(x, y, 1, ASPHALT)
        for x in (0, 1):
            for z in range(2, 6):
                m.set(x, y, z, "beton1")
    if i == 0:
        for z in range(0, PYLON):
            w = 3 if z < 80 else 2
            for y in range(16 - w, 16 + w):
                for x in range(0, 4):
                    m.set(x, y, z, "stuc1")
        m.set(1, 16, PYLON, "signaal_rood")
    # cables: cable k connects pylon height zk to the deck at distance dk (voxels) from the pylon
    for k in range(6):
        zk = PYLON - 8 - k * 9
        dk = (k + 1) * 18
        for y in range(T):
            g = i * T + y - 16   # signed distance from the pylon centre (y=16 of tile 0)
            # forward cables on every piece; backward cables only on the pylon tile
            if 0 <= g <= dk or (i == 0 and -dk <= g < 0):
                z = int(zk - (zk - 4) * abs(g) / dk)
                m.set(1, y, z, "metaal3")
    return m


for _i in range(4):
    register(f"grond/brug/tuibrug_{_i}", partial(tui, _i))


# ------------------------------------------------------------------ cobblestones

def _overlay(m, src, x0, x1, z1):
    """Copy the non-empty voxels of `src` (z < z1) onto `m` for columns x0 <= x < x1, all y."""
    for y in range(T):
        for x in range(x0, x1):
            for z in range(z1):
                c = src.get(x, y, z)
                if c:
                    m.set(x, y, z, c)


@tile("grond/weg/straat_keien_middengoot")
def street_cobbles_gutter():
    """Cobbled street with a shallow central gutter (x=14..17, deepest at x=15..16)."""
    m = cobble_tile()
    for y in range(T):
        for x in range(14, 18):
            m.clear(x, y, 0, x + 1, y + 1, 12)
            column(m, x, y, ROAD - (1 if x in (15, 16) else 0), mix("goot1", "goot2", seed=610))
    return m


@tile("grond/natuur/keienpad")
def cobble_path():
    """Cobbled path (x=10..21) through grass."""
    m = grass_tile(tufts=0.05)
    k = cobble_tile(top=3)
    for y in range(T):
        for x in range(10, 22):
            m.clear(x, y, 0, x + 1, y + 1, 8)
    _overlay(m, k, 10, 22, k.sz)
    return m


@tile("grond/plein/plein_keien")
def square_cobbles():
    """Cobbled square at sidewalk height."""
    return cobble_tile(top=3)


@tile("grond/stoep/stoep_keien_rand")
def sidewalk_cobble_edge():
    """Sidewalk with a front curb (y=0) and cobblestones behind it."""
    m = sidewalk("v")
    k = cobble_tile(top=3)
    for y in range(1, T):
        for x in range(T):
            for z in range(3):
                m.set(x, y, z, k.get(x, y, z))
    return m


# ------------------------------------------------------------------ rounded curves for complete street profiles

def _tram(left, right):
    """Lane with tram rails."""
    m = lane(left, right)
    tram_rails_straight(m)
    return m


# profile = list of parts from left (inside of the curve) to right (outside); traffic runs along y.
# Second element: what fills the inside of the curve ("stoep" = sidewalk, "gras" = grass).
CURVE_PROFILES = {
    "straat": (lambda: [sidewalk("r"), road_plain(), sidewalk("l")], "stoep"),
    "klinkerstraat": (lambda: [sidewalk("r", surface=paver_fn), street_pavers(), sidewalk("l", surface=paver_fn)], "stoep"),
    "weg": (lambda: [sidewalk("r", gutter=True), lane("geen", "kant").rot90(2), lane("onderbroken", "kant"), sidewalk("l", gutter=True)], "stoep"),
    "hoofdweg": (lambda: [sidewalk("r", gutter=True), bike_path_straight(), lane("geen", "kant").rot90(2),
                          lane("onderbroken", "kant"), bike_path_straight(), sidewalk("l", gutter=True)], "stoep"),
    "tramweg": (lambda: [sidewalk("r"), _tram("geen", "kant").rot90(2), _tram("onderbroken", "kant"), sidewalk("l")], "stoep"),
    "laan": (lambda: [sidewalk("r"), lane("onderbroken", "kant").rot90(2), lane("geen", "geen").rot90(2),
                      sidewalk("lr", surface=GRASS), lane("geen", "geen"), lane("onderbroken", "kant"), sidewalk("l")], "stoep"),
    "fietspad": (lambda: [grass_tile(tufts=0.03), bike_path_straight(), grass_tile(tufts=0.03)], "gras"),
}
CURVE_RADIUS = 1   # inner radius in tiles


def _profile(parts):
    """Paste the profile parts side by side along x into one wide model."""
    height = max(d.sz for d in parts)
    p = V(T * len(parts), T, height)
    for i, d in enumerate(parts):
        p.paste(d, i * T, 0, 0)
    return p


_curve_cache = {}


def _curve_source(name):
    """(profile model, number of parts, inner fill tile, outer fill tile) for a profile; cached."""
    if name not in _curve_cache:
        make, fill = CURVE_PROFILES[name]
        parts = make()
        inner_src = sidewalk("") if fill == "stoep" else grass_tile(tufts=0.03)
        outer_src = grass_tile(tufts=0.05)
        _curve_cache[name] = (_profile(parts), len(parts), inner_src, outer_src)
    return _curve_cache[name]


def curve_polar(i, j, x, y, w):
    """Polar coordinates of voxel column (x, y) of cell (i, j) of a curve of a w-part profile.

    The curve's centre is the front-left corner (x=0, y=0) of cell (0, 0). Returns
    (r, u, angle, s): r = radius of the column centre (voxels); u = column across the
    profile (0 = inner edge .. w*T-1 = outer edge), or None when r lies inside the inner
    radius or outside the outer radius; angle = atan2 in radians (0 at the front edge of
    row j=0, pi/2 at the left edge of column i=0); s = arc length at the mid radius.
    """
    rin = CURVE_RADIUS * T
    rout = rin + w * T
    rmid = (rin + rout) / 2.0
    X = i * T + x + 0.5
    Y = j * T + y + 0.5
    r = math.hypot(X, Y)
    a = math.atan2(Y, X)
    u = min(int(r - rin), w * T - 1) if rin <= r < rout else None
    return r, u, a, a * rmid


def curve_tile(name, i, j):
    """Tile (i, j) of a 90-degree curve of profile `name`, centred on the curve's origin.

    Each voxel is mapped to polar coordinates (curve_polar): the radius selects the
    position across the profile, the arc length (at the mid radius) selects the row
    along it. Inside the inner radius / outside the outer radius the fill tiles are used.
    """
    p, w, inner_src, outer_src = _curve_source(name)
    m = V(T, T, p.sz)
    for y in range(T):
        for x in range(T):
            r, u, _, s = curve_polar(i, j, x, y, w)
            if u is not None:
                src, bx, by = p, u, int(s) % T
            elif r < CURVE_RADIUS * T:
                src, bx, by = inner_src, x, y
            else:
                src, bx, by = outer_src, x, y
            for z in range(min(src.sz, m.sz)):
                c = src.get(bx, by, z)
                if c:
                    m.set(x, y, z, c)
    return m


# a curve of a w-part profile covers (CURVE_RADIUS + w)^2 tiles
for _pname in CURVE_PROFILES:
    _n = CURVE_RADIUS + len(CURVE_PROFILES[_pname][0]())
    for _i in range(_n):
        for _j in range(_n):
            register(f"grond/bocht/{_pname}_{_i}_{_j}", partial(curve_tile, _pname, _i, _j))
