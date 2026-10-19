"""Ground tiles: roads, sidewalks, squares, nature, water, rail, tram, bridges and ramps.

Part of the voxgen pipeline: every function decorated with @tile(path) or passed to
register(path, fn) (from common.py) returns a V model; generate.py writes it as
<OUT>/<path>.vox plus <path>.tile.json. This module also exports the shared ground
building blocks (surface colour functions, column/flat/paint helpers, rail and ramp
helpers) used by ground2, ground3, extras4 and extras5.

All ground tiles are 32x32 voxels (T, 4 m at 12.5 cm per voxel). Coordinates: x = left->right,
y = front->back (front = y=0), z = up. The road surface top is z=2 (ROAD), sidewalk/grass top
is z=3 (WALK). One ground storey in Godot is 1 m (8 voxels, FLOOR) high, so ramps rise exactly
one storey and tiles can be stacked (bridges, dikes, canals).
"""
import math
from functools import partial

from common import T, ROAD, WALK, FLOOR, tile, register, slopes, smooth, PICTO, text_pixels
from palette import P
from vox import V, mix, blocky, pick, h, col

# Surface colour functions (callables (x, y, z) -> palette index).
ASPHALT = mix("asfalt1", "asfalt2", "asfalt3", "asfalt4", weights=[4, 4, 2, 1], seed=1)
ASPHALT_OLD = mix("asfalt1", "asfalt2", "asfalt3", "asfalt4", "asfalt_reparatie", weights=[3, 3, 2, 2, 1], seed=2)
BIKE_ASPHALT = mix("fietsasfalt1", "fietsasfalt2", "fietsasfalt3", weights=[4, 3, 2], seed=3)
BUS = mix("busbaan1", "busbaan2", seed=4)
MARK = mix("markering", "markering", "markering2", seed=5)
PAVING = blocky(["tegel1", "tegel2", "tegel3", "tegel4"], size=3, seed=6)
CURB = mix("band1", "band2", seed=7)
GUTTER = mix("goot1", "goot2", seed=8)
GRASS = mix("gras1", "gras2", "gras3", "gras4", "gras5", weights=[4, 4, 3, 2, 2], seed=9)
EARTH = mix("aarde1", "aarde2", "aarde3", "aarde_donker", weights=[3, 3, 2, 1], seed=10)
SAND = mix("zand1", "zand2", seed=11)
GRAVEL = mix("grind1", "grind2", "grind3", "grind_roest", weights=[4, 3, 3, 1], seed=12)
CONCRETE = mix("beton1", "beton2", "beton3", weights=[3, 2, 1], seed=13)
CONCRETE_DARK = mix("beton2", "beton_donker", seed=14)
NATURAL_STONE = blocky(["natuursteen1", "natuursteen2", "natuursteen3"], size=4, seed=15)


def brick_fn(x, y, z, seed=20, names=("baksteen1", "baksteen2", "baksteen3", "baksteen4", "baksteen5")):
    """Brick colour function: 2-voxel bricks, rows offset by one voxel on alternating z."""
    u = x + y + (z % 2)
    return pick(list(names), u // 2, z, 0, seed, weights=[4, 4, 3, 2, 1])


def _brick(seed):
    """brick_fn bound to a specific seed, usable as a colour function."""
    return lambda a, b, c: brick_fn(a, b, c, seed)


def paver_fn(x, y, z):
    """Clinker colour function: stretcher bond, 2x1-voxel bricks across the driving direction."""
    bid = ((x + (y % 2)) // 2, y)
    return pick(["klinker1", "klinker2", "klinker3", "klinker4", "klinker5"], bid[0], bid[1], 0, 21, [4, 4, 3, 2, 1])


def dist(x, y, cx, cy):
    """Distance from the centre of voxel (x, y) to point (cx, cy)."""
    return math.hypot(x + 0.5 - cx, y + 0.5 - cy)


# ------------------------------------------------------------- basics

def new(sz=12):
    """Empty T x T ground model, sz voxels high."""
    return V(T, T, sz)


def column(m, x, y, top, c, sub="aarde2"):
    """Fill column (x, y) from z=0 to top-1: colour c on the top voxel, sub below it."""
    fc = col(c)
    fs = col(sub)
    for z in range(top):
        m.set(x, y, z, fc(x, y, z) if z == top - 1 else fs(x, y, z))


def fill_columns(m, top, c, sub="aarde2", size=T):
    """column() for every (x, y) in a size x size square starting at the origin."""
    for y in range(size):
        for x in range(size):
            column(m, x, y, top, c, sub)


def flat(c=ASPHALT, top=ROAD, sub="aarde2", sz=12):
    """Flat tile with surface c at height top (default: road level)."""
    m = new(sz)
    fill_columns(m, top, c, sub)
    return m


def paint(m, x, y, c):
    """Recolour the topmost voxel of column (x, y); ignores out-of-range and empty columns."""
    if not (0 <= x < m.sx and 0 <= y < m.sy):
        return
    t = m.top(x, y)
    if t:
        m.set(x, y, t - 1, c)


def line_y(m, x, y0=0, y1=T, c=MARK, dash=None):
    """Paint a line along y at column x. dash = (on, period, phase) in voxels."""
    for y in range(y0, y1):
        if dash is None or (y + dash[2]) % dash[1] < dash[0]:
            paint(m, x, y, c)


def line_x(m, y, x0=0, x1=T, c=MARK, dash=None):
    """Paint a line along x at row y. dash = (on, period, phase) in voxels."""
    for x in range(x0, x1):
        if dash is None or (x + dash[2]) % dash[1] < dash[0]:
            paint(m, x, y, c)


def _lines_y(m, xs, dash=None):
    """line_y() for each column in xs."""
    for x in xs:
        line_y(m, x, dash=dash)


def paint_bitmap(m, rows, x0, y0, c=MARK, scale=1, rot=0):
    """Paint a bitmap ('#' = set) on the surface with its lower-left at (x0, y0).

    Row 0 is the farthest away (highest y). rot=0 reads along +x; rot=1 rotates 90 degrees
    so the text reads along y. Other rot values paint nothing.
    """
    hgt = len(rows)
    wid = len(rows[0])
    for r, line in enumerate(rows):
        for cc, v in enumerate(line):
            if v != "#":
                continue
            for sy in range(scale):
                for sx in range(scale):
                    lx = cc * scale + sx
                    ly = (hgt - 1 - r) * scale + sy
                    if rot == 0:
                        paint(m, x0 + lx, y0 + ly, c)
                    elif rot == 1:
                        paint(m, x0 + ly, y0 + (wid * scale - 1 - lx), c)


DASH = (10, 16, 0)           # standard dashed line
DASH_HIGHWAY = (12, 32, 0)   # highway lane divider
BLOCK_DASH = (8, 16, 4)      # block marking (exit / weaving lanes)

# ------------------------------------------------------------- roads

def lane(left="geen", right="geen", surface=ASPHALT):
    """Single traffic lane running along y, with markings on the left (x=0) and right (x=30/31).

    left:  "geen" (none), "onderbroken" (dashed), "streep" (solid), "dubbel" (double),
           "blok" (block marking).
    right: "geen", "kant" (edge line at x=30), "streep" (solid at x=31),
           "onderbroken" (dashed at x=31), "kant_onderbroken" (short dashes at x=30).
    """
    m = flat(surface)
    if left == "onderbroken":
        line_y(m, 0, dash=DASH)
    elif left == "streep":
        line_y(m, 0)
    elif left == "dubbel":
        line_y(m, 0)
        line_y(m, 2)
    elif left == "blok":
        line_y(m, 0, dash=BLOCK_DASH)
        line_y(m, 1, dash=BLOCK_DASH)
    if right == "kant":
        line_y(m, 30)
    elif right == "streep":
        line_y(m, 31)
    elif right == "onderbroken":
        line_y(m, 31, dash=DASH)
    elif right == "kant_onderbroken":
        line_y(m, 30, dash=(4, 8, 0))
    return m


LANES = [
    ("geen", "geen"), ("geen", "kant"), ("geen", "kant_onderbroken"),
    ("onderbroken", "kant"), ("onderbroken", "geen"), ("onderbroken", "onderbroken"),
    ("streep", "kant"), ("streep", "geen"), ("dubbel", "kant"), ("dubbel", "geen"),
    ("blok", "kant"), ("blok", "geen"),
]
for _l, _r in LANES:
    register(f"grond/weg/rijstrook_{_l}_{_r}", partial(lane, _l, _r))


@tile("grond/weg/weg_vlak")
def road_plain():
    """Plain asphalt road tile without markings."""
    return flat()


@tile("grond/weg/weg_vlak_oud")
def road_plain_old():
    """Worn asphalt with a few random cracks and an old repair patch."""
    m = flat(ASPHALT_OLD)
    # cracks: random walks of 10 steps
    for i in range(3):
        x, y = int(h(i, 1, 0, 30) * 28) + 2, int(h(i, 2, 0, 30) * 28) + 2
        for s in range(10):
            paint(m, x, y, P["asfalt_reparatie"])
            x += 1 if h(i, s, 1, 31) > 0.5 else 0
            y += 1 if h(i, s, 2, 31) > 0.3 else -1
    # old repair patch
    for y in range(18, 26):
        for x in range(4, 13):
            paint(m, x, y, P["asfalt_reparatie"] if h(x, y, 0, 32) > 0.1 else P["asfalt4"])
    return m


@tile("grond/weg/weg_putdeksel")
def road_manhole():
    """Road with a round manhole cover in the centre."""
    m = flat()
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16, 16)
            if d < 4.2:
                paint(m, x, y, P["rooster"] if (d < 3.4 and (x + y) % 2 == 0) or d >= 3.4 else P["metaal_donker"])
    return m


@tile("grond/weg/weg_kolk")
def road_drain():
    """Road with a gully grate along the right edge."""
    m = lane("geen", "geen")
    for y in range(12, 20):
        for x in range(28, 32):
            paint(m, x, y, P["rooster"] if (y % 2 == 0 or x in (28, 31)) else P["asfalt4"])
    return m


def arrow(m, kind, cx=16, y0=4):
    """Paint a lane arrow pointing towards +y, shaft at column cx starting at y0.

    kind: "rechtdoor" (straight), "links" (left), "rechts" (right),
          "rechtdoor_links", "rechtdoor_rechts" (straight + turn).
    """
    if kind in ("rechtdoor", "rechtdoor_links", "rechtdoor_rechts"):
        for y in range(y0, y0 + 20):
            paint(m, cx, y, MARK)
        for r in range(4):
            for x in range(cx - 3 + r, cx + 4 - r):
                paint(m, x, y0 + 20 + r, MARK)
    if kind in ("links", "rechtdoor_links", "rechts", "rechtdoor_rechts"):
        side = -1 if "links" in kind else 1
        top = y0 + 12 if kind.startswith("rechtdoor") else y0 + 14
        for y in range(y0, top + 1):
            paint(m, cx, y, MARK)
        for i in range(1, 8):
            paint(m, cx + side * i, top, MARK)
        tip = cx + side * 11
        for r in range(4):
            for y in range(top - 3 + r, top + 4 - r):
                paint(m, tip - side * (3 - r), y, MARK)


def _arrow_lane(kind):
    m = lane("streep", "kant")
    arrow(m, kind)
    return m


for _k in ("rechtdoor", "links", "rechts", "rechtdoor_links", "rechtdoor_rechts"):
    register(f"grond/weg/rijstrook_pijl_{_k}", partial(_arrow_lane, _k))


@tile("grond/weg/rijstrook_stopstreep")
def stop_line():
    """Lane with a 3-voxel stop line across the far end."""
    m = lane("streep", "kant")
    for y in range(27, 30):
        line_x(m, y, 0, 31)
    return m


@tile("grond/weg/rijstrook_haaientanden")
def shark_teeth():
    """Lane with give-way triangles ("shark teeth") at the far end, pointing towards the front."""
    m = lane("streep", "kant")
    for i in range(5):
        x0 = 2 + i * 6
        for r in range(5):
            for x in range(x0 + r // 2, x0 + 4 - r // 2):
                paint(m, x, 29 - r, MARK)
    return m


@tile("grond/weg/zebrapad")
def zebra_crossing():
    """Zebra crossing; stripes 4 voxels wide, running along y."""
    m = flat()
    for y in range(3, 29):
        for x in range(T):
            if (x // 4) % 2 == 0:
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/fietsoversteek")
def bike_crossing():
    """Bicycle crossing: red bike asphalt band with block markings along both edges."""
    m = flat()
    for y in range(4, 28):
        for x in range(T):
            paint(m, x, y, BIKE_ASPHALT)
    for x in range(T):
        if (x // 3) % 2 == 0:
            for y in (4, 5, 26, 27):
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/verkeersdrempel")
def speed_bump():
    """Clinker speed bump across the road: one voxel high for y=10..21, with striped ramps."""
    m = flat(sz=12)
    for y in range(8, 24):
        lift = 1 if 10 <= y < 22 else 0
        for x in range(T):
            column(m, x, y, ROAD + lift, paver_fn)
    for x in range(T):
        if (x // 4) % 2 == 0:
            for y in (8, 9, 22, 23):
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/rijstrook_bus")
def lane_bus():
    """Bus lane with "BUS" painted at double scale."""
    m = lane("streep", "kant", BUS)
    px, _size = text_pixels("BUS")
    for (c, r) in px:
        for sy in range(2):
            for sx in range(2):
                paint(m, 5 + c * 2 + sx, 12 + (4 - r) * 2 + sy, MARK)
    return m


@tile("grond/weg/rijstrook_fietsstrook")
def lane_bike_lane():
    """Lane with an advisory bike lane on the right (x=20..31) and a bicycle pictogram."""
    m = lane("onderbroken", "geen")
    for y in range(T):
        for x in range(20, T):
            paint(m, x, y, BIKE_ASPHALT)
        if y % 8 < 4:
            paint(m, 19, y, MARK)
    paint_bitmap(m, PICTO["fiets"], 21, 12, MARK)
    return m


@tile("grond/weg/parkeerstrook")
def parking_lane():
    """Parking lane: dashed line at x=0 and a bay line along the front edge."""
    m = flat()
    line_y(m, 0, dash=(4, 8, 0))
    for x in range(1, T):
        paint(m, x, 0, MARK)
    return m


@tile("grond/weg/parkeervak_gehandicapt")
def parking_bay_disabled():
    """Parking bay with a blue square and a white "P" (disabled parking)."""
    m = parking_lane()
    for y in range(6, 26):
        for x in range(6, 26):
            paint(m, x, y, P["bord_blauw"])
    paint_bitmap(m, ["#####", "#...#", "#####", "#....", "#...."], 11, 11, MARK, scale=2)
    return m


@tile("grond/weg/straat_klinkers")
def street_pavers():
    """Clinker-paved street at road level."""
    return flat(paver_fn)


@tile("grond/weg/straat_klinkers_middengoot")
def street_pavers_gutter():
    """Clinker street with a central gutter (x=14..17); the inner two columns dip one voxel."""
    m = flat(paver_fn)
    for y in range(T):
        for x in range(14, 18):
            top = ROAD - 1 if x in (15, 16) else ROAD
            m.clear(x, y, top, x + 1, y + 1, ROAD)
            column(m, x, y, top, GUTTER)
    return m


def cobble_tile(top=ROAD):
    """Cobblestone surface with recessed joints; 3x3-voxel stones, rows offset by 2 voxels."""
    m = new()
    for y in range(T):
        for x in range(T):
            row = y // 3
            xx = x + (row % 2) * 2
            joint = (y % 3 == 2) or (xx % 3 == 2)
            if joint:
                column(m, x, y, top - 1, "kei_voeg")
                if top - 1 <= 0:
                    m.set(x, y, 0, "kei_voeg")
            else:
                c = pick(["kei1", "kei2", "kei3", "kei4"], xx // 3, row, 0, 22)
                column(m, x, y, top, c)
    return m


@tile("grond/weg/straat_keien")
def street_cobbles():
    """Cobblestone street at road level."""
    return cobble_tile()


# ------------------------------------------------------------- highway

@tile("grond/snelweg/snelweg_rijstrook")
def highway_lane():
    """Highway lane with a wide dashed divider on the left."""
    m = flat()
    _lines_y(m, (0, 1), dash=DASH_HIGHWAY)
    return m


@tile("grond/snelweg/snelweg_rijstrook_links")
def highway_lane_left():
    """Leftmost highway lane: solid edge line left, dashed divider right."""
    m = flat()
    _lines_y(m, (0, 1))
    _lines_y(m, (30, 31), dash=DASH_HIGHWAY)
    return m


@tile("grond/snelweg/snelweg_vluchtstrook")
def highway_hard_shoulder():
    """Hard shoulder: solid line on the left plus a rumble strip at x=3."""
    m = flat()
    _lines_y(m, (0, 1))
    for y in range(T):  # rumble strip
        if y % 2 == 0:
            paint(m, 3, y, P["asfalt4"])
    return m


@tile("grond/snelweg/snelweg_blokmarkering")
def highway_block():
    """Highway lane with a wide block marking on the left."""
    m = flat()
    _lines_y(m, (0, 1, 2), dash=BLOCK_DASH)
    return m


@tile("grond/snelweg/snelweg_puntstuk")
def highway_gore():
    """Gore area between diverging lanes: solid lines both sides, diagonal hatching between."""
    m = flat()
    _lines_y(m, (0, 1))
    _lines_y(m, (30, 31))
    for y in range(T):
        for x in range(2, 30):
            if (x + y) % 8 < 2:
                paint(m, x, y, MARK)
    return m


def guardrail(m, x, base, y0=0, y1=T):
    """Crash barrier along y: posts at column x every 16 voxels, rail beside it at z=base+3..4.

    The rail sits one column towards the centre (x-1, or x+1 when x=0).
    """
    rail_x = x - 1 if x > 0 else x + 1
    for y in range(y0, y1):
        if y % 16 == 4:
            for z in range(base, base + 5):
                m.set(x, y, z, "metaal2")
        m.set(rail_x, y, base + 3, "gegalvaniseerd")
        m.set(rail_x, y, base + 4, "gegalvaniseerd")


@tile("grond/snelweg/snelweg_berm_vangrail")
def highway_verge():
    """Highway verge: asphalt strip (x<6), grass with a guardrail and hectometre posts."""
    m = new(12)
    for y in range(T):
        for x in range(T):
            if x < 6:
                column(m, x, y, ROAD, ASPHALT)
            else:
                column(m, x, y, WALK, GRASS)
    guardrail(m, 7, WALK)
    for y in range(T):
        if y % 16 == 10:
            for z in range(WALK, WALK + 7):
                m.set(14, y, z, "bord_wit")
            m.set(14, y, WALK + 5, "bord_rood")
    return m


@tile("grond/snelweg/snelweg_middenberm")
def highway_median():
    """Grass central reservation with guardrails facing both carriageways."""
    m = new(12)
    for y in range(T):
        for x in range(T):
            if x < 4 or x >= 28:
                column(m, x, y, ROAD, ASPHALT)
            else:
                column(m, x, y, WALK, GRASS)
    guardrail(m, 6, WALK)
    guardrail(m, 25, WALK)
    return m


@tile("grond/snelweg/snelweg_middenberm_beton")
def highway_median_concrete():
    """Asphalt with a 6-voxel concrete median barrier (x=13..18) with chamfered edges."""
    m = new(14)
    fill_columns(m, ROAD, ASPHALT)
    for y in range(T):
        for x in range(13, 19):
            for z in range(ROAD, ROAD + 7 - (1 if x in (13, 18) else 0)):
                m.set(x, y, z, CONCRETE)
    return m


# ------------------------------------------------------------- sidewalks

def edge_dist(px, py, edges, R=6.0):
    """Distance from point (px, py) to the nearest road edge, with rounded outer corners.

    edges: string of face letters v/r/a/l (front/right/back/left) that border the road.
    R is the outer corner radius in voxels. Returns 99 when there are no edges.
    """
    ds = []
    if "v" in edges:
        ds.append(py)
    if "a" in edges:
        ds.append(T - py)
    if "l" in edges:
        ds.append(px)
    if "r" in edges:
        ds.append(T - px)
    e = min(ds) if ds else 99.0
    corners = []
    if "v" in edges and "r" in edges:
        corners.append((T - R, R, px > T - R and py < R))
    if "v" in edges and "l" in edges:
        corners.append((R, R, px < R and py < R))
    if "a" in edges and "r" in edges:
        corners.append((T - R, T - R, px > T - R and py > T - R))
    if "a" in edges and "l" in edges:
        corners.append((R, T - R, px < R and py > T - R))
    for cx, cy, inside in corners:
        if inside:
            e = min(e, R - math.hypot(px - cx, py - cy))
    return e


def sidewalk(edges="", points=(), gutter=False, surface=PAVING, quay=False, sz=12):
    """Sidewalk tile at WALK height with a curb towards the road.

    edges:   face letters (v/r/a/l) bordering road; see edge_dist.
    points:  extra (x, y) points (in voxels) around which the road cuts in with a quarter
             circle; used for inner corners.
    gutter:  put a 3-voxel gutter at road level in front of the curb.
    surface: colour function of the walking surface.
    quay:    natural-stone quay edge (with brick underneath) instead of a curb.
    """
    m = new(sz)
    for y in range(T):
        for x in range(T):
            px, py = x + 0.5, y + 0.5
            e = edge_dist(px, py, edges)
            for (cx, cy) in points:
                e = min(e, math.hypot(px - cx, py - cy))
            if quay:
                if e < 0:
                    column(m, x, y, ROAD, ASPHALT)
                elif e < 3:
                    column(m, x, y, WALK, NATURAL_STONE, brick_fn if e < 1 else "aarde2")
                else:
                    column(m, x, y, WALK, surface)
                continue
            curb0 = 3 if gutter else 0
            if e < 0:
                column(m, x, y, ROAD, ASPHALT)
            elif e < curb0:
                column(m, x, y, ROAD, GUTTER)
            elif e < curb0 + 1:
                column(m, x, y, WALK, CURB, CURB)
            else:
                column(m, x, y, WALK, surface)
    return m


# shape name -> (edges, points) for sidewalk()
SIDEWALK_SHAPES = {
    "vol": ("", ()),
    "rand": ("v", ()),
    "hoek_buiten": ("vr", ()),
    "hoek_binnen": ("", ((T, 0),)),
    "rand_hoek_binnen": ("v", ((T, T),)),
    "dubbel_hoek_binnen": ("", ((T, 0), (0, 0))),
    "eiland": ("va", ()),
    "eiland_eind": ("var", ()),
    "eiland_rond": ("varl", ()),
    "smal_eind": ("vrl", ()),
}

for _name, (_e, _p) in SIDEWALK_SHAPES.items():
    register(f"grond/stoep/stoep_{_name}", partial(sidewalk, _e, _p))
    if _name != "vol":
        register(f"grond/stoep/stoep_goot_{_name}", partial(sidewalk, _e, _p, gutter=True))
for _name in ("vol", "rand", "hoek_buiten", "hoek_binnen"):
    _e, _p = SIDEWALK_SHAPES[_name]
    register(f"grond/stoep/stoep_klinker_{_name}", partial(sidewalk, _e, _p, surface=paver_fn))


@tile("grond/stoep/stoep_goot_kolk")
def sidewalk_gutter_drain():
    """Sidewalk with gutter and a drain grate in the gutter."""
    m = sidewalk("v", gutter=True)
    for y in range(0, 3):
        for x in range(12, 20):
            paint(m, x, y, P["rooster"] if (x % 2 == 0 or y == 0) else P["goot2"])
    return m


@tile("grond/stoep/stoep_oprit")
def sidewalk_driveway():
    """Sidewalk with a lowered curb (driveway) for x=4..27."""
    m = sidewalk("v")
    for x in range(4, 28):
        m.clear(x, 0, ROAD, x + 1, 1, WALK)
        column(m, x, 0, ROAD, CURB, CURB)
        paint(m, x, 1, CURB)
    return m


@tile("grond/stoep/stoep_goot_oprit")
def sidewalk_gutter_driveway():
    """Sidewalk with gutter and a lowered curb (driveway) for x=4..27."""
    m = sidewalk("v", gutter=True)
    for x in range(4, 28):
        m.clear(x, 3, ROAD, x + 1, 4, WALK)
        column(m, x, 3, ROAD, CURB, CURB)
    return m


@tile("grond/stoep/stoep_ribbel")
def sidewalk_tactile():
    """Sidewalk with a tactile paving strip near the curb."""
    m = sidewalk("v")
    for y in range(1, 8):
        for x in range(8, 24):
            paint(m, x, y, P["ribbel"] if x % 2 == 0 else P["tegel3"])
    return m


@tile("grond/stoep/stoep_boomrooster")
def sidewalk_tree_grate():
    """Sidewalk with a 12x12 tree grate; open earth pit in the middle."""
    m = sidewalk("")
    for y in range(10, 22):
        for x in range(10, 22):
            edge = x in (10, 21) or y in (10, 21)
            if edge:
                paint(m, x, y, P["metaal_donker"])
            elif dist(x, y, 16, 16) < 3:
                m.clear(x, y, WALK - 1, x + 1, y + 1, WALK)
                column(m, x, y, WALK - 1, EARTH)
            else:
                paint(m, x, y, P["rooster"] if (x + y) % 2 == 0 else P["metaal_donker"])
    return m


@tile("grond/stoep/stoep_kade")
def sidewalk_quay():
    """Quay sidewalk with natural-stone edge at the front."""
    return sidewalk("v", quay=True)


@tile("grond/stoep/stoep_kade_hoek_buiten")
def sidewalk_quay_corner():
    """Quay sidewalk, outer corner (front and right)."""
    return sidewalk("vr", quay=True)


@tile("grond/stoep/stoep_kade_hoek_binnen")
def sidewalk_quay_corner_inner():
    """Quay sidewalk, inner corner (front-right)."""
    return sidewalk("", ((T, 0),), quay=True)


@tile("grond/stoep/stoep_kade_klinker")
def sidewalk_quay_pavers():
    """Quay sidewalk with clinker surface."""
    return sidewalk("v", quay=True, surface=paver_fn)


# ------------------------------------------------------------- squares

@tile("grond/plein/plein_tegels")
def square_tiles():
    """Square paved with 4x4 tiles at WALK height."""
    return flat(blocky(["plein1", "plein2", "plein3"], size=4, seed=40), top=WALK)


@tile("grond/plein/plein_natuursteen")
def square_natural_stone():
    """Square paved with 8x4 natural-stone slabs in stretcher bond."""
    def f(x, y, z):
        row = y // 4
        bx = (x + (row % 2) * 4) // 8
        return pick(["natuursteen1", "natuursteen2", "natuursteen3", "plein3"], bx, row, 0, 41)
    return flat(f, top=WALK)


@tile("grond/plein/plein_klinkers")
def square_pavers():
    """Square paved with clinkers in a basket-weave pattern."""
    def f(x, y, z):
        if ((x // 2 + y // 2) % 2) == 0:
            bid = (x // 2, y)
        else:
            bid = (x, y // 2 + 100)
        return pick(["klinker1", "klinker2", "klinker3", "klinker4", "klinker5"], bid[0], bid[1], 0, 42, [4, 4, 3, 2, 1])
    return flat(f, top=WALK)


@tile("grond/plein/plein_dambord")
def square_checkerboard():
    """Square with an 8x8 checkerboard of light and dark slabs."""
    def f(x, y, z):
        return P["plein3"] if ((x // 8) + (y // 8)) % 2 == 0 else P["plein_donker"]
    return flat(f, top=WALK)


@tile("grond/plein/plein_patroon")
def square_pattern():
    """Square with concentric square rings and a red centre disc."""
    rings = [P["plein1"], P["plein_donker"], P["plein3"], P["plein_rood"], P["plein2"], P["plein_donker"]]

    def f(x, y, z):
        d = max(abs(x + 0.5 - 16), abs(y + 0.5 - 16))
        ring = int(d) // 3
        if dist(x, y, 16, 16) < 4:
            return P["plein_rood"]
        return rings[ring % 6]
    return flat(f, top=WALK)


@tile("grond/plein/plein_grind")
def square_gravel():
    """Gravel square at WALK height."""
    return flat(GRAVEL, top=WALK)


@tile("grond/plein/plein_vlonder")
def square_decking():
    """Wooden decking: 4-voxel boards along y with dark gaps."""
    def f(x, y, z):
        if x % 4 == 3:
            return P["hout_donker2"]
        return pick(["hout1", "hout2", "hout3"], x // 4, y // 12 + (x // 4) * 3, 0, 43)
    return flat(f, top=WALK, sub="hout_donker1")


# ------------------------------------------------------------- nature

def grass_tile(flowers=0.0, tufts=0.06, tall=False, base=GRASS, seed=50):
    """Grass tile (8 voxels high, top at WALK); variation and flowers are only surface colour.

    flowers / tufts are per-voxel probabilities; tall doubles the tuft probability.
    """
    m = flat(base, top=WALK, sz=8)
    for y in range(T):
        for x in range(T):
            r = h(x, y, 0, seed)
            if r < flowers:
                m.set(x, y, WALK - 1, pick(["bloem_wit", "bloem_geel", "bloem_paars", "bloem_rood", "bloem_roze"], x, y, 1, seed))
            elif r < flowers + tufts * (2 if tall else 1):
                m.set(x, y, WALK - 1, pick(["gras2", "gras4", "gras_droog"], x, y, 2, seed))
    return m


@tile("grond/natuur/gras")
def grass():
    """Default grass tile."""
    return grass_tile()


@tile("grond/natuur/gras_bloemen")
def grass_flowers():
    """Grass with flowers."""
    return grass_tile(flowers=0.06)


@tile("grond/natuur/gras_hoog")
def grass_tall():
    """Long grass (more tufts)."""
    return grass_tile(tufts=0.3, tall=True)


@tile("grond/natuur/gras_kort")
def grass_short():
    """Short mown grass without tufts."""
    return grass_tile(tufts=0.0, base=mix("gras2", "gras4", "gras1", seed=51))


@tile("grond/natuur/zand")
def sand():
    """Sand with scattered pebbles on top."""
    m = flat(SAND, top=WALK, sz=8)
    for y in range(T):
        for x in range(T):
            if h(x, y, 0, 52) < 0.03:
                m.set(x, y, WALK, "grind3")
    return m


@tile("grond/natuur/aarde")
def earth():
    """Bare earth."""
    return flat(EARTH, top=WALK, sz=8)


@tile("grond/natuur/moestuin")
def vegetable_garden():
    """Vegetable garden: raised rows along x every 6 voxels with plants every 3 voxels."""
    m = flat(EARTH, top=WALK, sz=8)
    for y in range(T):
        for x in range(T):
            if y % 6 in (1, 2):
                column(m, x, y, WALK + 1, "aarde_donker")
                if x % 3 == 0:
                    m.set(x, y, WALK + 1, pick(["blad2", "blad4", "blad_licht"], x, y, 0, 53))
                    if h(x, y, 1, 53) < 0.5:
                        m.set(x, y, WALK + 2, "blad4")
    return m


@tile("grond/natuur/bloemperk_tulpen")
def tulips():
    """Tulip bed: a plant every 2 voxels, colour changes every 5 rows."""
    m = flat(EARTH, top=WALK, sz=8)
    colors = ["bloem_rood", "bloem_geel", "bloem_roze", "bloem_paars", "bloem_wit", "bloem_oranje"]
    for y in range(T):
        for x in range(T):
            if x % 2 == 0 and y % 2 == 0:
                m.set(x, y, WALK, "blad2")
                m.set(x, y, WALK + 1, "blad4")
                m.set(x, y, WALK + 2, colors[(y // 5) % len(colors)])
    return m


def _path_column(m, x, y, c):
    """Replace column (x, y) of a grass tile with path surface c at WALK height."""
    m.clear(x, y, WALK, x + 1, y + 1, 8)
    column(m, x, y, WALK, c)


@tile("grond/natuur/pad_zand")
def path_sand():
    """Sand path along y through grass, with slightly irregular edges."""
    m = grass_tile(tufts=0.05)
    surface = mix("zand1", "zand2", "grind3", seed=55)
    for y in range(T):
        w0 = 11 + int(h(0, y // 3, 0, 54) * 2)
        w1 = 21 - int(h(1, y // 3, 0, 54) * 2)
        for x in range(w0, w1):
            _path_column(m, x, y, surface)
    return m


@tile("grond/natuur/pad_grind_bocht")
def path_curve():
    """Gravel path curving from the front edge to the right edge (centre at front-right)."""
    m = grass_tile(tufts=0.05)
    for y in range(T):
        for x in range(T):
            if abs(dist(x, y, 32, 0) - 16) < 4.5:
                _path_column(m, x, y, GRAVEL)
    return m


@tile("grond/natuur/pad_grind")
def path_gravel():
    """Straight gravel path along y (x=11..20) through grass."""
    m = grass_tile(tufts=0.05)
    for y in range(T):
        for x in range(11, 21):
            _path_column(m, x, y, GRAVEL)
    return m


# ------------------------------------------------------------- water

WATER = mix("water1", "water2", "water3", seed=60)


def water_tile(water=WATER):
    """Water tile: bed at z=0, water surface at z=1 (8 voxels high model)."""
    m = new(8)
    bed = mix("waterbodem", "waterbodem2", "modder", seed=61)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, bed)
            m.set(x, y, 1, water)
    return m


@tile("grond/water/water")
def water():
    """Open water."""
    return water_tile()


@tile("grond/water/water_gracht")
def water_canal():
    """Canal water (darker green tint)."""
    return water_tile(mix("water_gracht", "water2", seed=62, weights=[3, 1]))


def shore(dfun):
    """Natural shoreline tile. dfun(px, py) -> distance inland from the waterline (<0 = water)."""
    m = new(8)
    mud = mix("modder", "zand2", seed=63)
    bank = mix("aarde1", "gras5", "gras3", seed=64)
    for y in range(T):
        for x in range(T):
            d = dfun(x + 0.5, y + 0.5)
            if d < 0:
                m.set(x, y, 0, "waterbodem")
                m.set(x, y, 1, WATER)
            elif d < 2:
                column(m, x, y, ROAD, mud)
            elif d < 4:
                column(m, x, y, WALK, bank, EARTH)
            else:
                column(m, x, y, WALK, GRASS)
                if h(x, y, 0, 65) < 0.05:
                    m.set(x, y, WALK, "gras4")
    return m


@tile("grond/water/water_oever")
def water_shore():
    """Straight shore: water at the front, land at the back."""
    return shore(lambda px, py: py - 14)


def _bank_outer(px, py):
    d = min(py - 14, 18 - px)
    if px > 12 and py < 20:
        d = min(d, 6 - math.hypot(px - 12, py - 20))
    return d


@tile("grond/water/water_oever_hoek_buiten")
def water_shore_corner_outer():
    """Shore outer corner: land in the back-left corner, water at the front and right."""
    return shore(_bank_outer)


@tile("grond/water/water_oever_hoek_binnen")
def water_shore_corner_inner():
    """Shore inner corner: water only in the front-right corner."""
    return shore(lambda px, py: math.hypot(px - 32, py) - 14)


@tile("grond/water/water_riet")
def water_reeds():
    """Water with reeds, denser towards the back (y > 20)."""
    m = water_tile()
    for y in range(T):
        for x in range(T):
            if h(x, y, 0, 66) < 0.12 and (y > 20 or h(x, y, 1, 66) < 0.3):
                hh = 6 + int(h(x, y, 2, 66) * 8)
                for z in range(2, 2 + hh):
                    m.set(x, y, z, "riet1" if z < hh - 1 else "riet2")
                if h(x, y, 3, 66) < 0.4:
                    m.set(x, y, 2 + hh, "riet_pluim")
    return m


@tile("grond/water/water_lelies")
def water_lilies():
    """Water with 7 water-lily pads, every other one with a white flower."""
    m = water_tile()
    for i in range(7):
        cx, cy = 3 + h(i, 0, 0, 67) * 26, 3 + h(i, 1, 0, 67) * 26
        r = 1.5 + h(i, 2, 0, 67) * 1.5
        for y in range(T):
            for x in range(T):
                if dist(x, y, cx, cy) < r:
                    m.set(x, y, 2, "blad3")
        if i % 2 == 0:
            m.set(int(cx), int(cy), 3, "bloem_wit")
    return m


def quay_wall(algae=False):
    """Solid brick block, one ground storey high; algae=True adds algae at the bottom 3 layers."""
    m = V(T, T, FLOOR)
    alg = mix("alg1", "alg2", seed=69)
    brick = _brick(70)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                if algae and z < 3 and h(x, y, z, 68) < 0.7 - z * 0.2:
                    m.set(x, y, z, alg)
                else:
                    m.set(x, y, z, brick)
    return m


@tile("grond/water/kademuur")
def quay_wall_block():
    """Brick quay wall block."""
    return quay_wall()


@tile("grond/water/kademuur_alg")
def quay_wall_algae():
    """Brick quay wall block with algae near the waterline."""
    return quay_wall(True)


@tile("grond/water/kademuur_water")
def quay_wall_water():
    """Water with a quay wall at the back (useful when you don't want to stack a block)."""
    m = water_tile()
    brick = _brick(71)
    for z in range(0, FLOOR):
        for y in range(28, T):
            for x in range(T):
                m.set(x, y, z, brick)
    return m


# ------------------------------------------------------------- terrain

@tile("grond/terrein/grond_blok")
def ground_block():
    """Solid earth block, one ground storey high, grass on top."""
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                if z == FLOOR - 1:
                    m.set(x, y, z, GRASS)
                elif z == FLOOR - 2 and h(x, y, z, 72) < 0.4:
                    m.set(x, y, z, "gras5")
                elif h(x, y, z, 73) < 0.04:
                    m.set(x, y, z, "grind2")
                else:
                    m.set(x, y, z, EARTH)
    return m


@tile("grond/terrein/grond_blok_beton")
def ground_block_concrete():
    """Solid concrete block, one ground storey high, with diagonal seams."""
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                seam = (x + y) % 16 == 0 or z == 0
                m.set(x, y, z, "beton_donker" if seam else CONCRETE)
    return m


@tile("grond/terrein/grond_blok_baksteen")
def ground_block_brick():
    """Solid brick block, one ground storey high, natural-stone top layer."""
    m = V(T, T, FLOOR)
    brick = _brick(74)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                m.set(x, y, z, NATURAL_STONE if z == FLOOR - 1 else brick)
    return m


# ------------------------------------------------------------- bike paths

def bike_path_surface(m, region):
    """Bike asphalt where region(px, py) is true (voxel centres), grass elsewhere."""
    for y in range(T):
        for x in range(T):
            if region(x + 0.5, y + 0.5):
                column(m, x, y, ROAD, BIKE_ASPHALT)
            else:
                column(m, x, y, WALK, GRASS)


@tile("grond/fietspad/fietspad_recht")
def bike_path_straight():
    """Full-width bike path (red asphalt)."""
    return flat(BIKE_ASPHALT)


@tile("grond/fietspad/fietspad_eenrichting")
def bike_path_one_way():
    """One-way bike path with an arrow pointing to the back."""
    m = flat(BIKE_ASPHALT)
    paint_bitmap(m, PICTO["pijl_op"], 14, 20, MARK)
    return m


@tile("grond/fietspad/fietspad_symbool")
def bike_path_symbol():
    """Bike path with two bicycle pictograms."""
    m = flat(BIKE_ASPHALT)
    paint_bitmap(m, PICTO["fiets"], 3, 10, MARK)
    paint_bitmap(m, PICTO["fiets"], 18, 10, MARK)
    return m


@tile("grond/fietspad/fietspad_bocht")
def bike_path_curve():
    """Bike path quarter-disc around the front-right corner, grass outside."""
    m = new()
    bike_path_surface(m, lambda px, py: math.hypot(px - 32, py) <= 32)
    return m


@tile("grond/fietspad/fietspad_t")
def bike_path_t():
    """Bike path T-junction."""
    m = flat(BIKE_ASPHALT)
    # shark teeth on the side branch (traffic coming from the right gives way)
    for k in range(5):
        y0 = 3 + k * 6
        for r in range(4):
            for y in range(y0 + r // 2, y0 + 4 - r // 2):
                paint(m, 27 - r, y, MARK)
    return m


@tile("grond/fietspad/fietspad_kruising")
def bike_path_crossing():
    """Bike path crossing (plain full-width bike asphalt)."""
    return bike_path_straight()


@tile("grond/fietspad/fietspad_eind")
def bike_path_end():
    """Bike path ending in a semicircle; open towards the front."""
    m = new()
    bike_path_surface(m, lambda px, py: py < 16 or math.hypot(px - 16, py - 16) < 16)
    return m


@tile("grond/fietspad/fietspad_naast_weg")
def bike_path_beside_road():
    """Separate bike path (3 m) with a curb and grass strip on the right."""
    m = new()
    bike_path_surface(m, lambda px, py: px < 24)
    for y in range(T):
        column(m, 24, y, WALK, CURB, CURB)
    return m


# ------------------------------------------------------------- railway (train)

RAIL_X = (10, 21)  # x of the two rails on a straight track (gauge 11 voxels)


def _ballast(m, x, y, base, full):
    """Ballast column: 4 voxels (earth + gravel) on the bed, 3 gravel voxels on the shoulder."""
    if full:
        for z in range(base, base + 4):
            m.set(x, y, z, GRAVEL if z >= base + 1 else "aarde2")
    else:
        for z in range(base, base + 3):
            m.set(x, y, z, GRAVEL)


def _rail(m, x, y, base):
    """Rail voxel pair: rail body at base+3, shiny head at base+4."""
    m.set(x, y, base + 4, "rail_glim")
    m.set(x, y, base + 3, "rail")


def track_straight(m, base=0, along="y"):
    """Ballast bed + concrete sleepers + rails along y on a flat tile. base = z offset.

    along is accepted for compatibility but ignored (track always runs along y).
    """
    for y in range(T):
        for x in range(T):
            if 4 <= x <= 27:
                _ballast(m, x, y, base, True)
                if 5 <= x <= 26 and y % 4 in (0, 1):
                    m.set(x, y, base + 3, "biels_beton")
            elif x in (3, 28):
                _ballast(m, x, y, base, False)
        for x in RAIL_X:
            _rail(m, x, y, base)


def track_arc(m, cx, cy, rc, size, base=0, ballast_r=12):
    """Curved track: centreline radius rc around (cx, cy) on a size x size model.

    ballast_r is the half-width of the ballast bed; sleepers every 4 voxels of arc length.
    """
    for y in range(size):
        for x in range(size):
            d = dist(x, y, cx, cy)
            dd = abs(d - rc)
            ang = math.atan2(y + 0.5 - cy, cx - x - 0.5)
            s = rc * abs(ang)
            if dd <= ballast_r:
                _ballast(m, x, y, base, True)
                if dd <= 10.5 and (s % 4) < 2:
                    m.set(x, y, base + 3, "biels_beton")
            elif dd <= ballast_r + 1:
                _ballast(m, x, y, base, False)
            if abs(dd - 5.5) < 0.55:
                _rail(m, x, y, base)


def grass_floor(m, size, top=WALK):
    """Fill a size x size area of m with grass columns up to top."""
    fill_columns(m, top, GRASS, size=size)


@tile("grond/spoor/trein_recht")
def train_straight():
    """Straight railway track along y on grass."""
    m = new()
    grass_floor(m, T)
    track_straight(m)
    return m


@tile("grond/spoor/trein_bocht")
def train_curve():
    """Railway curve (radius 16) around the front-right corner."""
    m = new()
    grass_floor(m, T)
    track_arc(m, 32, 0, 16, T)
    return m


@tile("grond/spoor/trein_bocht_groot_3x3")
def train_curve_large():
    """Large railway curve spanning 3x3 tiles (radius 80)."""
    S = T * 3
    m = V(S, S, 12)
    grass_floor(m, S)
    track_arc(m, S, 0, 80, S)
    return m


@tile("grond/spoor/trein_overweg")
def train_level_crossing():
    """Level crossing: the track runs along x (left-right), the road from front to back."""
    m = new()
    for y in range(T):
        for x in range(T):
            e = min(y, 31 - y)
            top = ROAD + min(3, e // 2)
            if 4 <= y <= 27:
                top = 5
            column(m, x, y, top, ASPHALT)
    for x in range(T):
        for y in RAIL_X:
            m.set(x, y, 4, "rail_glim")
            m.set(x, y + (1 if y == 10 else -1), 4, "railgroef")
        for y in range(12, 20):
            m.set(x, y, 4, "rubber")
    for y in range(4, 28):
        m.set(0, y, 4, "markering")
        m.set(31, y, 4, "markering")
    return m


@tile("grond/spoor/trein_stootblok")
def train_buffer_stop():
    """Straight track ending in a buffer stop at the back."""
    m = train_straight()
    for x in range(6, 26):
        for z in range(5, 10):
            m.set(x, 22, z, "bord_rood" if (x // 3) % 2 == 0 else "bord_wit")
    for x in (8, 23):
        for z in range(4, 10):
            for y in range(22, 30):
                if z - 4 <= (30 - y) * 0.75:
                    m.set(x, y, z, "metaal_donker")
    for z in range(10, 13):
        m.set(16, 22, z, "metaal_donker")
    m.set(16, 21, 12, "stoplicht_rood")
    return m


PLATFORM_TOP = 11  # platform surface height in voxels


def _platform_base():
    """Paved platform slab up to PLATFORM_TOP (14 voxels high model)."""
    m = V(T, T, 14)
    fill_columns(m, PLATFORM_TOP, PAVING, CONCRETE_DARK)
    return m


def platform():
    """Platform edge tile: track side at the front, with yellow line and tactile strip."""
    m = _platform_base()
    for x in range(T):
        for y in range(0, 2):
            paint(m, x, y, CONCRETE)
        paint(m, x, 3, P["markering_geel"])
        for y in range(5, 7):
            paint(m, x, y, P["ribbel"] if x % 2 == 0 else P["tegel3"])
    return m


@tile("grond/spoor/perron")
def platform_tile():
    """Railway platform edge."""
    return platform()


@tile("grond/spoor/perron_midden")
def platform_middle():
    """Railway platform middle section (plain paving)."""
    return _platform_base()


@tile("grond/spoor/perron_trap")
def platform_stairs():
    """Platform with a staircase going down towards the back (x=10..21)."""
    m = platform_middle()
    for y in range(6, 28):
        step = (y - 6) // 2
        top = PLATFORM_TOP - step if step < PLATFORM_TOP else 0
        for x in range(10, 22):
            m.clear(x, y, max(top, 0), x + 1, y + 1, PLATFORM_TOP)
            if top > 0:
                m.set(x, y, top - 1, CONCRETE)
    return m


# ------------------------------------------------------------- tram

def tram_rails_straight(m, top=ROAD, along_x=False):
    """Paint grooved tram rails (rail head + groove) on the surface, along y or along x.

    top is accepted for compatibility but ignored (paint() follows the surface).
    """
    for i in range(T):
        for r in RAIL_X:
            g = r + 1 if r == RAIL_X[0] else r - 1  # groove on the inner side
            if along_x:
                paint(m, i, r, P["rail_glim"])
                paint(m, i, g, P["railgroef"])
            else:
                paint(m, r, i, P["rail_glim"])
                paint(m, g, i, P["railgroef"])


def tram_rails_arc(m, cx, cy, rc, size):
    """Paint curved grooved tram rails, centreline radius rc around (cx, cy)."""
    for y in range(size):
        for x in range(size):
            d = dist(x, y, cx, cy)
            if abs(d - (rc - 5.5)) < 0.55 or abs(d - (rc + 5.5)) < 0.55:
                paint(m, x, y, P["rail_glim"])
            elif (rc - 5.5 + 0.5) <= d < (rc - 5.5 + 1.4) or (rc + 5.5 - 1.4) < d <= (rc + 5.5 - 0.5):
                paint(m, x, y, P["railgroef"])


@tile("grond/tram/tram_recht")
def tram_straight():
    """Straight tram track in asphalt."""
    m = flat()
    tram_rails_straight(m)
    return m


@tile("grond/tram/tram_bocht")
def tram_curve():
    """Tram curve (radius 16) around the front-right corner."""
    m = flat()
    tram_rails_arc(m, 32, 0, 16, T)
    return m


@tile("grond/tram/tram_t")
def tram_t():
    """Tram junction: straight track plus a branch curving to the right."""
    m = flat()
    tram_rails_straight(m)
    tram_rails_arc(m, 32, 0, 16, T)
    return m


@tile("grond/tram/tram_kruising")
def tram_crossing():
    """Tram crossing (straight tracks along x and y)."""
    m = flat()
    tram_rails_straight(m)
    tram_rails_straight(m, along_x=True)
    return m


@tile("grond/tram/tram_bocht_groot_3x3")
def tram_curve_large():
    """Large tram curve spanning 3x3 tiles (radius 80)."""
    S = T * 3
    m = V(S, S, 8)
    fill_columns(m, ROAD, ASPHALT, size=S)
    tram_rails_arc(m, S, 0, 80, S)
    return m


@tile("grond/tram/tram_klinker_recht")
def tram_pavers_straight():
    """Straight tram track in a clinker street."""
    m = flat(paver_fn)
    tram_rails_straight(m)
    return m


@tile("grond/tram/tram_gras_recht")
def tram_grass_straight():
    """Straight tram track on a grass bed."""
    m = grass_tile(tufts=0.02)
    for y in range(T):
        for r in RAIL_X:
            m.set(r, y, WALK, "rail_glim")
            m.set(r, y, WALK - 1, "rail")
    return m


@tile("grond/tram/tram_gras_bocht")
def tram_grass_curve():
    """Tram curve on a grass bed."""
    m = grass_tile(tufts=0.02)
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 32, 0)
            if abs(d - 10.5) < 0.55 or abs(d - 21.5) < 0.55:
                m.set(x, y, WALK, "rail_glim")
    return m


@tile("grond/tram/tram_halte_perron")
def tram_stop():
    """Raised tram stop platform (top z=5) with curb at the front, line and tactile strip."""
    m = V(T, T, 10)
    fill_columns(m, 5, PAVING, CONCRETE_DARK)
    for x in range(T):
        column(m, x, 0, 5, CURB, CURB)
        paint(m, x, 2, P["markering"])
        for y in range(4, 7):
            paint(m, x, y, P["ribbel"] if x % 2 == 0 else P["tegel3"])
    return m


# ------------------------------------------------------------- stairs (1 m)

@tile("grond/terrein/trap_1m")
def stairs_1m():
    """Stairs rising one ground storey (8 voxels) from front to back, with side walls and railing."""
    m = V(T, T, FLOOR + 8)
    for y in range(T):
        if y < 8:
            top = WALK
        elif y < 24:
            top = WALK + 1 + (y - 8) // 2
        else:
            top = WALK + FLOOR
        for x in range(T):
            column(m, x, y, top, CONCRETE if 8 <= y < 24 else PAVING, CONCRETE_DARK)
            if 8 <= y < 24 and (y - 8) % 2 == 0:
                paint(m, x, y, P["beton3"])  # step nosing
    # side walls with railing posts every 8 voxels
    for y in range(T):
        for x in (0, 31):
            t = m.top(x, y)
            for z in range(t, t + 3):
                m.set(x, y, z, CONCRETE_DARK)
            if y % 8 == 4:
                for z in range(t + 3, t + 7):
                    m.set(x, y, z, "rvs")
    # handrail
    for y in range(T):
        for x in (0, 31):
            zt = (WALK + 3 + 6) if y < 8 else (WALK + FLOOR + 3 + 6 if y >= 24 else WALK + 4 + (y - 8) // 2 + 6)
            m.set(x, y, min(zt, m.sz - 1), "rvs")
    return m


# ------------------------------------------------------------- bridges

def _parapet(m, x, y, base, wall_xs):
    """Bridge parapet slice at row y: concrete wall in columns wall_xs from base up to
    base+WALK+4, then a metal railing at column x (post every 8 voxels, top rail)."""
    for wx in wall_xs:
        for z in range(base, base + WALK + 4):
            m.set(wx, y, z, CONCRETE)
    if y % 8 == 2:
        for z in range(base + WALK + 4, base + WALK + 8):
            m.set(x, y, z, "metaal2")
    m.set(x, y, base + WALK + 8, "metaal3")


def deck_from(flat_tile, rails="links"):
    """Turn a flat tile into a bridge deck: concrete underside, parapets on the edges.

    rails: "links" (parapet on the left, x=0..1), "beide" (both sides) or "geen" (none).
    """
    m = V(T, T, 12)
    for y in range(T):
        for x in range(T):
            for z in range(flat_tile.sz):
                c = flat_tile.get(x, y, z)
                if c:
                    m.set(x, y, z, c)
            m.set(x, y, 0, CONCRETE_DARK)
    sides = {"links": (0,), "beide": (0, 31), "geen": ()}[rails]
    for x0 in sides:
        xs = (0, 1) if x0 == 0 else (30, 31)
        for y in range(T):
            _parapet(m, x0, y, 0, xs)
    return m


def _deck_lane():
    """Lane with an extra line at x=3 (edge line next to the parapet)."""
    m = lane("geen", "geen")
    line_y(m, 3)
    return m


def _train_deck_base():
    """Concrete slab at road level with railway track on top, for train bridge decks."""
    base = new()
    fill_columns(base, ROAD, CONCRETE)
    track_straight(base, base=1)
    return base


def _deck(src, rails="links"):
    return deck_from(src(), rails)


# tile name suffix -> (source tile function, parapet sides)
BRIDGE_DECKS = {
    "weg_rand": (partial(lane, "geen", "geen"), "links"),
    "weg_beide": (partial(lane, "geen", "geen"), "beide"),
    "weg_midden": (partial(lane, "geen", "geen"), "geen"),
    "rijstrook_kant_rand": (_deck_lane, "links"),
    "rijstrook_onderbroken": (partial(lane, "onderbroken", "geen"), "geen"),
    "fietspad_rand": (bike_path_straight, "links"),
    "fietspad_beide": (bike_path_straight, "beide"),
    "stoep_rand": (partial(sidewalk, ""), "links"),
    "tram_rand": (tram_straight, "links"),
    "klinker_beide": (street_pavers, "beide"),
    "trein_rand": (_train_deck_base, "links"),
    "trein_beide": (_train_deck_base, "beide"),
}
for _n, (_src, _rails) in BRIDGE_DECKS.items():
    register(f"grond/brug/brug_dek_{_n}", partial(_deck, _src, _rails))


@tile("grond/brug/brug_ligger")
def bridge_girder():
    """Bridge girder storey: two concrete beams (x=3..9, 22..28) with a thin slab on top."""
    m = V(T, T, FLOOR)
    for y in range(T):
        for x in range(T):
            if 3 <= x <= 9 or 22 <= x <= 28:
                for z in range(3, FLOOR):
                    m.set(x, y, z, CONCRETE)
            else:
                m.set(x, y, FLOOR - 1, CONCRETE_DARK)
    return m


def pier(m, z0, z1):
    """Round concrete pier (radius ~5) in the tile centre from z0 to z1."""
    for z in range(z0, z1):
        for y in range(T):
            for x in range(T):
                if dist(x, y, 16, 16) < 5.2:
                    m.set(x, y, z, CONCRETE if (x + z) % 7 else "beton_donker")


@tile("grond/brug/brug_pijler")
def bridge_pier():
    """Bridge pier, one ground storey."""
    m = V(T, T, FLOOR)
    pier(m, 0, FLOOR)
    return m


@tile("grond/brug/brug_pijler_kop")
def bridge_pier_head():
    """Bridge pier with a widening pier cap along x."""
    m = V(T, T, FLOOR)
    pier(m, 0, FLOOR)
    for z in range(3, FLOOR):
        for y in range(10, 22):
            w = 2 + (z - 3) * 2
            for x in range(max(0, 10 - w), min(T, 22 + w)):
                m.set(x, y, z, CONCRETE)
    return m


@tile("grond/brug/brug_pijler_gras")
def bridge_pier_grass():
    """Bridge pier standing on grass."""
    m = grass_tile()
    pier(m, WALK, FLOOR)
    return m


@tile("grond/brug/brug_pijler_stoep")
def bridge_pier_sidewalk():
    """Bridge pier standing on a sidewalk."""
    m = V(T, T, FLOOR)
    m.paste(sidewalk(""), 0, 0, 0)
    pier(m, WALK, FLOOR)
    return m


@tile("grond/brug/brug_pijler_water")
def bridge_pier_water():
    """Bridge pier standing in water, with algae around its foot."""
    m = water_tile()
    pier(m, 0, FLOOR)
    for y in range(T):
        for x in range(T):
            if dist(x, y, 16, 16) < 6.5:
                m.set(x, y, 1, "alg2")
                m.set(x, y, 2, "alg1")
    return m


def arch_bridge(rails):
    """Brick arch bridge over a canal; the arch spans along y.

    Place it at water level (2 ground storeys below the street); the deck then ends up at
    street level. rails: "rand" (parapet left), "beide" (both sides) or "midden" (none).
    """
    H = FLOOR * 2 + ROAD
    m = V(T, T, H + 8)
    brick = _brick(75)
    for z in range(H):
        for y in range(T):
            for x in range(T):
                # elliptical arch: semi-axes 13 (y) and 12 (z), centre at y=16, z=1
                ez = (y + 0.5 - 16) ** 2 / (13.0 ** 2) + (z + 0.5 - 1) ** 2 / (12.0 ** 2)
                inside = ez < 1.0 and z >= 1
                ring = 1.0 <= ez < 1.25 and z >= 1
                if z >= H - 2:
                    m.set(x, y, z, paver_fn)
                elif inside:
                    if z == 1:
                        m.set(x, y, z, WATER)
                    continue
                elif z == 0:
                    m.set(x, y, z, "waterbodem")
                elif ring:
                    m.set(x, y, z, NATURAL_STONE if (x in (0, 31)) else "donkersteen2")
                else:
                    m.set(x, y, z, brick)
    # water under the arch wherever z=1 is still empty
    for y in range(T):
        for x in range(T):
            if m.get(x, y, 1) == 0:
                m.set(x, y, 1, WATER)
    sides = {"rand": (0,), "beide": (0, 31), "midden": ()}[rails]
    wall = _brick(76)
    for xs in sides:
        cols = (0, 1) if xs == 0 else (30, 31)
        for y in range(T):
            for x in cols:
                for z in range(H - 2, H + 6):
                    m.set(x, y, z, wall)
                m.set(x, y, H + 6, NATURAL_STONE)
    return m


for _rails in ("beide", "rand", "midden"):
    register(f"grond/brug/brug_boog_gracht_{_rails}", partial(arch_bridge, _rails))


@tile("grond/brug/brug_landhoofd")
def bridge_abutment():
    """Bridge abutment: solid concrete storey with seams on the front face."""
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                m.set(x, y, z, CONCRETE if not (y == 0 and z % 4 == 0) else "beton_donker")
    return m


# ------------------------------------------------------------- ramps

def padded(flat_tile, lift=2, fill=EARTH):
    """A flat tile raised by `lift` voxels on a `fill` block: the importer moves it onto a
    smooth slope (common.smooth, addons/vox_tiles/slopes.gd) instead of 1-voxel steps.
    The plain ramps of existing flat tiles are made by the importer from the flat tile
    itself (``slopes`` below)."""
    out = V(flat_tile.sx, flat_tile.sy, flat_tile.sz + lift)
    for y in range(flat_tile.sy):
        for x in range(flat_tile.sx):
            for z in range(flat_tile.sz):
                c = flat_tile.get(x, y, z)
                if c:
                    out.set(x, y, z + lift, c)
            for z in range(lift):
                out.set(x, y, z, fill)
    return out


# steep ramps (1 m per tile) grond/helling/helling_<name>, made by the importer
for _p in ("weg/weg_vlak", "weg/rijstrook_onderbroken_kant", "weg/rijstrook_geen_kant", "weg/rijstrook_streep_kant",
           "weg/rijstrook_onderbroken_geen", "snelweg/snelweg_rijstrook", "snelweg/snelweg_vluchtstrook",
           "fietspad/fietspad_recht", "stoep/stoep_vol", "stoep/stoep_rand", "stoep/stoep_goot_rand",
           "weg/straat_klinkers", "plein/plein_tegels", "natuur/gras", "spoor/trein_recht", "tram/tram_recht"):
    slopes("grond/" + _p, "steil")

# bridge ramps grond/helling/helling_brug_<name> (thin deck) and helling_brug_<name>_rand
# (parapet on the left), made by the importer (addons/vox_tiles/slopes.gd)
for _p in ("weg/weg_vlak", "weg/rijstrook_onderbroken_kant", "weg/rijstrook_geen_kant", "fietspad/fietspad_recht",
           "stoep/stoep_vol", "spoor/trein_recht", "tram/tram_recht"):
    slopes("grond/" + _p, "brug", "brug_rand")
# both edges of the ramps of the curved bridges, and klinker streets on bridges
slopes("grond/stoep/stoep_vol", "brug_rand_rechts")
slopes("grond/weg/straat_klinkers", "brug")

slopes("grond/natuur/gras", "hoek_buiten", "hoek_binnen")
register("grond/helling/helling_dijk_beton", lambda: padded(flat(CONCRETE, top=WALK), fill=CONCRETE_DARK))
smooth("grond/helling/helling_dijk_beton", "steil")
