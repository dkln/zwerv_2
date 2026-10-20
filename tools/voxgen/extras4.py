"""Extras, part 4: business-unit building style, industrial fencing, bridge-keeper houses,
steel stairs, revolving door, gravel/sand paths and hill pieces, road verge and ditches,
median streetlight, bollards, traffic bollards, elevated footbridges and a 1.80 m scale figure.

Tiles register through @tile(path) / register(path, fn) (common.py) and are written by
generate.py. Coordinates: x = left->right, y = front->back (front = y=0), z = up;
1 voxel = 12.5 cm. Ground tiles are T x T (32x32) with road top ROAD and sidewalk/grass top
WALK; buildings use the Bld/make_block machinery of buildings.py (48x48 canvas, 32x32 block).
The biz_* facade functions' names feed the building RNG seed (LEGACY_SEED_NAMES); do not
rename them.
"""
import math

from common import T, ROAD, WALK, FLOOR, register, tile, smooth
from palette import P
from vox import V, mix, h
from ground import (column, flat, new, grass_tile, padded, line_y, ASPHALT, GRASS, EARTH, SAND, GRAVEL,
                    CONCRETE_DARK, WATER, brick_fn)
from buildings import STYLES, S, pitched
from buildings2 import reg_style, flat_roofs
from details import att, wd

# ------------------------------------------------------------------ business unit (bedrijfspand)


def corrugated(x, y, z):
    """Wall colour function: corrugated sheet with a dark groove every third voxel."""
    return P["golfplaat1"] if (x + y) % 3 else P["golfplaat2"]


STYLES["bedrijfspand"] = dict(family="bedrijf", wall=corrugated, frame="antraciet1", doors=["metaal1"], plinth="beton2",
                              trim="antraciet1", roof=("golfplaat1", "golfplaat2"), roof_deck=("golfplaat1", "golfplaat2"),
                              glass="glas2", shop="antraciet1", cap="antraciet1")


# Facade functions f(b, face): b is a buildings.Bld, face one of v/r/a/l (front/right/back/left);
# u runs along the facade (0..S-1), z up, d = depth (positive into the wall, negative outwards).

def biz_blank(b, face):
    """Closed facade: only a concrete plinth (3 voxels high)."""
    b.rect(face, 0, S, 0, 3, 0, 1, "beton2")


def biz_roller_door(b, face):
    """Ground floor with a large ribbed roller door and yellow/black guard posts."""
    biz_blank(b, face)
    b.rect(face, 4, 28, 0, 20, 0, 2, 0)
    for z in range(0, 20):
        for u in range(4, 28):
            b.put(face, u, z, 1, "antraciet1" if (u in (4, 27) or z == 19) else ("metaal1" if z % 2 else "metaal2"))
    for u in (2, 29):
        for z in range(0, 6):
            b.put(face, u, z, -1, "bord_geel" if z % 2 else "bord_zwart")


def biz_office(b, face):
    """Ground floor office: ribbon window, recessed glass entrance and a canopy above it."""
    biz_blank(b, face)
    b.window(face, 2, 6, 28, 10, sill=False, lintel=False)
    b.rect(face, 12, 20, 0, 17, 0, 3, 0)
    b.rect(face, 12, 20, 0, 17, 1, 2, "glas_helder")
    b.rect(face, 10, 22, 17, 18, -5, 0, "antraciet1")


def biz_rooflight(b, face):
    """Upper floor with a full-width ribbon window high in the wall."""
    biz_blank(b, face)
    b.window(face, 0, 16, 32, 4, sill=False, lintel=False)


def biz_logo(b, face):
    """Closed upper floor with a blue company sign."""
    biz_blank(b, face)
    b.sign(face, 2, 30, 14, 21, "bord_blauw", "ZWERVR", "bord_wit")


reg_style("bedrijfspand", {"bg_roldeur": biz_roller_door, "bg_kantoor": biz_office, "bg_dicht": biz_blank,
                           "verd_lichtstraat": biz_rooflight, "verd_dicht": biz_blank, "verd_logo": biz_logo},
          [("bg_roldeur_hoek", "bg_roldeur", "bg_dicht"), ("bg_kantoor_hoek", "bg_kantoor", "bg_dicht"),
           ("verd_lichtstraat_hoek", "verd_lichtstraat", "verd_lichtstraat")],
          # shed roof: sawtooth with a 16-voxel period along y
          dict(flat_roofs("bedrijfspand"), dak_sheddak=pitched("bedrijfspand", "shed", lambda px, py: (py % 16) * 1.0)))


# ------------------------------------------------------------------ industrial fencing

@tile("props/hekken/hek_industrie")
def fence_industrial():
    """Galvanised mesh fence with a sparse barbed-wire top."""
    m = V(24, 2, 22)
    for x in range(24):
        for z in range(0, 18):
            if x in (0, 23) or z in (0, 17) or (x + z) % 2 == 0:
                m.set(x, 0, z, "gegalvaniseerd")
        for z in (18, 19, 20):
            if (x + z) % 3 == 0:
                m.set(x, 1, z, "metaal2")
    for x in (0, 23):
        for z in range(22):
            m.set(x, 0, z, "gegalvaniseerd")
            m.set(x, 1, z, "gegalvaniseerd")
    return m


@tile("props/hekken/schuifpoort_industrie")
def sliding_gate():
    """6 m sliding gate with diagonal bracing, hazard-striped bottom rail and a warning light."""
    m = V(48, 6, 22)
    for x in range(1, 47):
        for z in range(2, 18):
            if x in (1, 46) or z in (2, 17) or (x - z) % 6 == 0 or (x + z) % 6 == 0:
                m.set(x, 2, z, "gegalvaniseerd")
        m.set(x, 2, 1, "bord_geel" if (x // 3) % 2 else "bord_zwart")
    for (x, y) in ((4, 3), (43, 3)):
        m.set(x, y, 0, "rubber")
    for z in range(0, 22):
        m.set(0, 2, z, "metaal2")
        m.set(47, 2, z, "metaal2")
    m.set(47, 1, 20, "stoplicht_oranje")
    return m


@tile("props/hekken/slagboom")
def barrier_arm():
    """Boom barrier: white post with a red/white striped arm reaching to the right."""
    m = V(72, 6, 10)
    m.box(32, 1, 0, 36, 5, 8, "bord_wit")
    for x in range(36, 70):
        m.set(x, 3, 6, "bord_rood" if (x // 4) % 2 else "bord_wit")
    m.set(34, 0, 7, "stoplicht_rood")
    return m


# ------------------------------------------------------------------ bridge-keeper houses

@tile("props/water/brugwachtershuisje_klassiek")
def bridge_house_classic():
    """Classic brick bridge-keeper house with a window at the front, door on the right
    and a slate pyramid roof with a gold finial."""
    m = V(16, 16, 26)
    for z in range(0, 14):
        for y in range(2, 14):
            for x in range(2, 14):
                if x in (2, 13) or y in (2, 13):
                    m.set(x, y, z, brick_fn(x, y, z, 700))
    for x in range(4, 12):
        for z in range(6, 11):
            m.set(x, 2, z, "glas1" if x not in (4, 11, 8) and z not in (6, 10) else "kozijn_wit")
    for z in range(0, 10):
        for y in range(6, 10):
            m.set(13, y, z, "deur_groen")
    for z in range(14, 25):
        r = 8 - (z - 14) * 0.75
        for y in range(16):
            for x in range(16):
                if max(abs(x + 0.5 - 8), abs(y + 0.5 - 8)) <= r:
                    m.set(x, y, z, "leisteen1" if z % 2 else "leisteen2")
    m.set(8, 8, 25, "goud")
    return m


@tile("props/water/brugwachtershuisje_modern")
def bridge_house_modern():
    """Modern bridge-keeper house: dark base, all-round glass control room and a flat roof."""
    m = V(16, 16, 22)
    m.box(1, 1, 0, 15, 15, 8, "antraciet1")
    for z in range(8, 18):
        for y in range(1, 15):
            for x in range(1, 15):
                if x in (1, 14) or y in (1, 14):
                    m.set(x, y, z, "glas_helder" if not (x in (1, 14) and y in (1, 14)) else "antraciet1")
    m.box(0, 0, 18, 16, 16, 20, "antraciet1")
    for x in range(3, 13):
        m.set(x, 3, 12, "scherm")
    return m


# ------------------------------------------------------------------ steel stairs and revolving door

@tile("props/trappen/trap_staal_spiraal")
def stairs_spiral():
    """Steel spiral staircase: one step per voxel of height, a full turn every 12 steps,
    with a handrail 6 voxels above the outer edge."""
    m = V(16, 16, 26)
    m.cyl(8, 8, 1, 0, 26, "metaal2")
    for z in range(0, 24):
        a = z * math.tau / 12
        for r in range(1, 7):
            m.set(8 + math.cos(a) * r, 8 + math.sin(a) * r, z, "metaal1")
            m.set(8 + math.cos(a + 0.2) * r, 8 + math.sin(a + 0.2) * r, z, "metaal1")
        m.set(8 + math.cos(a) * 7, 8 + math.sin(a) * 7, z + 6, "metaal_donker")
    return m


@tile("props/trappen/brandtrap")
def fire_escape():
    """Straight steel fire-escape stair rising towards the back, with side rails and a top landing."""
    m = V(16, 32, 26)
    for i in range(12):
        z, y = i * 2, 2 + i * 2
        for x in range(2, 14):
            m.set(x, y, z, "metaal1")
            m.set(x, y + 1, z, "metaal1")
    for x in (1, 14):
        for i in range(26):
            y = min(30, 2 + i)
            m.set(x, y, min(25, i + 6), "metaal_donker")
        for y in range(2, 30, 6):
            for z in range(0, min(25, y + 4)):
                m.set(x, y, z, "metaal_donker")
    m.box(1, 26, 23, 15, 32, 24, "metaal1")
    return m


@tile("details/deuren/draaideur")
def revolving_door():
    """Revolving door facade attachment (details.att canvas): half-round glass drum
    sticking out of the wall, four glass wings and a metal top."""
    m = att(20, 6, 20)
    cy = wd(m, 3)
    for z in range(0, 20):
        c = "glas_helder" if z < 18 else "metaal3"
        for y in range(m.sy):
            for x in range(20):
                d = math.hypot(x + 0.5 - 10, y + 0.5 - cy)
                if 8.4 < d < 9.4 and y <= cy:
                    m.set(x, y, z, c)
        for k in range(4):
            a = k * math.pi / 2 + 0.4
            for r in range(0, 8):
                m.set(10 + math.cos(a) * r, cy + math.sin(a) * r, z, c)
    m.cyl(10, cy, 9, 18, 20, "metaal3")
    return m


# ------------------------------------------------------------------ gravel/sand and hills

def _path(mat):
    """Grass tile with a 12-voxel wide path of `mat` running front to back (x = 10..21)."""
    m = grass_tile()
    for y in range(T):
        for x in range(10, 22):
            m.clear(x, y, WALK, x + 1, y + 1, 8)   # remove grass tufts above the path
            column(m, x, y, WALK, mat)
    return m


register("grond/natuur/grind", lambda: flat(GRAVEL, top=WALK, sz=8))
register("grond/natuur/grindpad", lambda: _path(GRAVEL))
register("grond/natuur/zandpad", lambda: _path(SAND))


def block(mat, top):
    """Solid T x T x FLOOR ground block of `mat` with a `top` surface layer (stackable hill core)."""
    m = V(T, T, FLOOR)
    m.box(0, 0, 0, T, T, FLOOR - 1, mat)
    m.box(0, 0, FLOOR - 1, T, T, FLOOR, top)
    return m


def _hill(top, fill):
    """Tile function: a flat `top` surface at WALK on a `fill` block; the importer smooths it
    into the hill shape (a straight slope, a corner, or heuvel_top: a rounded top of up to
    4 voxels in the centre, falling off outwards)."""
    return lambda: padded(flat(top, top=WALK, sz=8), fill=fill)


for _n, _top, _fill in (("gras", GRASS, EARTH), ("zand", SAND, SAND), ("grind", GRAVEL, GRAVEL)):
    register(f"grond/heuvel/heuvel_{_n}_blok", (lambda f, t: lambda: block(f, t))(_fill, _top))
    for _suffix, _shape in (("helling", "steil"), ("hoek_buiten", "hoek_buiten"), ("hoek_binnen", "hoek_binnen"), ("top", "heuvel_top")):
        register(f"grond/heuvel/heuvel_{_n}_{_suffix}", _hill(_top, _fill))
        smooth(f"grond/heuvel/heuvel_{_n}_{_suffix}", _shape)


# ------------------------------------------------------------------ verge and ditch

@tile("grond/weg/berm")
def verge():
    """Rural road edge: asphalt (x < 10) with dashed edge line, gravel strip and a grass verge
    with white/red reflector posts every 16 voxels."""
    m = new()
    for y in range(T):
        for x in range(T):
            if x < 10:
                column(m, x, y, ROAD, ASPHALT)
            elif x < 13:
                column(m, x, y, ROAD, GRAVEL)
            else:
                column(m, x, y, WALK, GRASS)
    line_y(m, 8, dash=(4, 8, 0))
    for y in range(T):
        if y % 16 == 6:
            for z in range(WALK, WALK + 7):
                m.set(16, y, z, "bord_wit")
            m.set(16, y, WALK + 5, "bord_rood")
    return m


def _ditch(dist, seed):
    """Ditch tile: water (z=1, mud below) where dist(x, y) < 6, muddy banks at ROAD height
    up to 9, grass beyond."""
    m = new(8)
    for y in range(T):
        for x in range(T):
            d = dist(x, y)
            if d < 6:
                m.set(x, y, 0, "modder")
                m.set(x, y, 1, WATER)
            elif d < 9:
                column(m, x, y, ROAD, mix("gras5", "aarde1", seed=seed))
            else:
                column(m, x, y, WALK, GRASS)
    return m


@tile("grond/water/sloot")
def ditch():
    """Straight ditch running front to back through the middle, with reeds along the banks."""
    m = _ditch(lambda x, y: abs(x + 0.5 - 16), 702)
    for y in range(T):
        for x in (10, 21):
            if h(x, y, 0, 703) < 0.4:
                for z in range(ROAD, ROAD + 4 + int(h(x, y, 1, 703) * 4)):
                    m.set(x, y, z, "riet1")
    return m


@tile("grond/water/sloot_bocht")
def ditch_curve():
    """Quarter-circle ditch (radius 16 around the front-right corner), connecting front and right."""
    return _ditch(lambda x, y: abs(math.hypot(x + 0.5 - 32, y + 0.5) - 16), 704)


@tile("grond/water/duiker")
def culvert():
    """Ditch passing under a road (dam with culvert): asphalt dam with concrete pipe ends at front and back."""
    m = new(8)
    for y in range(T):
        for x in range(T):
            column(m, x, y, ROAD, ASPHALT, "aarde2")
    for y in (0, 31):
        for x in range(10, 22):
            for z in range(0, 2):
                m.set(x, y, z, CONCRETE_DARK)
    return m


# ------------------------------------------------------------------ median streetlight, bollards, traffic bollard

@tile("props/verlichting/lantaarn_middenberm")
def streetlight_median():
    """10 m median streetlight: central 2x2 mast with two arms of 34 voxels, lamps at the ends."""
    m = V(80, 4, 84)
    for z in range(0, 80):
        for x in (39, 40):
            m.set(x, 1, z, "gegalvaniseerd")
            m.set(x, 2, z, "gegalvaniseerd")
    for side in (-1, 1):
        for i in range(0, 34):
            x = 40 + i if side > 0 else 39 - i
            z = 80 + min(2, i // 6)
            m.set(x, 1, z, "gegalvaniseerd")
            m.set(x, 2, z, "gegalvaniseerd")
        for i in range(27, 35):
            x = 40 + i if side > 0 else 39 - i
            m.set(x, 1, 81, "lamp_wit")
            m.set(x, 2, 81, "lamp_wit")
    return m


@tile("props/verkeer/afzetbol_beton")
def bollard_ball():
    """Concrete barrier ball."""
    m = V(6, 6, 6)
    m.ellipsoid(3, 3, 2.8, 2.8, 2.8, 2.8, mix("beton1", "beton3", seed=705))
    return m


@tile("props/verkeer/afzetbol_rood_wit")
def bollard_ball_rw():
    """Barrier ball, white with a red band."""
    m = V(6, 6, 6)
    m.ellipsoid(3, 3, 2.8, 2.8, 2.8, 2.8, lambda x, y, z: P["bord_rood"] if z in (2, 3) else P["bord_wit"])
    return m


@tile("props/verkeer/verkeerszuil")
def traffic_bollard():
    """Illuminated traffic bollard (keep-left island marker) with a blue arrow on the front."""
    m = V(6, 6, 12)
    for z in range(12):
        m.cyl(3, 3, 2.4 - z * 0.05, z, z + 1, "lamp_wit" if 2 < z < 10 else "bord_wit")
    for (x, z) in [(2, 8), (3, 7), (1, 7), (2, 6), (2, 5), (2, 4)]:
        m.set(x, 0, z, "bord_blauw")
    return m


@tile("props/verkeer/verkeerszuil_geel")
def traffic_bollard_yellow():
    """Traffic bollard variant with amber light instead of white."""
    m = traffic_bollard()
    for z in range(3, 10):
        for y in range(6):
            for x in range(6):
                if m.get(x, y, z) == P["lamp_wit"]:
                    m.set(x, y, z, "stoplicht_oranje")
    return m


# ------------------------------------------------------------------ footbridges (elevated, over roads)

def walkway(closed):
    """Footbridge deck tile (20 wide, x = 6..25, running front to back): tiled deck on a steel
    plate with glass balustrades; `closed` adds a full-height glass tube with roof and lights."""
    m = V(T, T, 32)
    for y in range(T):
        for x in range(6, 26):
            m.set(x, y, 0, "metaal2")
            m.set(x, y, 1, mix("tegel1", "tegel3", seed=706))
        for x in (6, 25):
            if closed:
                for z in range(2, 22):
                    m.set(x, y, z, "glas_helder" if y % 8 else "metaal3")
            else:
                for z in range(2, 9):
                    m.set(x, y, z, "glas_helder")
                m.set(x, y, 9, "rvs")
        if closed:
            for x in range(6, 26):
                m.set(x, y, 22, "metaal3" if (y % 8 == 0 or x in (6, 25)) else "glas_helder")
            if y % 8 == 4:
                m.set(16, y, 21, "lamp_wit")
    return m


register("grond/brug/loopbrug_overdekt", lambda: walkway(True))
register("grond/brug/loopbrug_open", lambda: walkway(False))


@tile("grond/brug/loopbrug_trap")
def walkway_stairs():
    """Stair rising one ground layer (FLOOR) from front to back; stackable up to a footbridge."""
    m = V(T, T, FLOOR + 10)
    for y in range(T):
        top = 2 + y // 4
        for x in range(8, 24):
            m.set(x, y, top - 1, "metaal1")
            if top > 2:
                m.set(x, y, top - 2, "metaal2")
        # handrails with a post every 6 voxels
        for x in (8, 23):
            m.set(x, y, top + 7, "rvs")
            if y % 6 == 0:
                for z in range(top, top + 7):
                    m.set(x, y, z, "rvs")
    for (x, y) in ((8, 0), (23, 0), (8, 31), (23, 31)):
        for z in range(0, 2 + y // 4):
            m.set(x, y, z, "metaal2")
    return m


@tile("grond/brug/loopbrug_pijler")
def walkway_pier():
    """Footbridge pier: 4x4 steel column one ground layer high, stackable."""
    m = V(T, T, FLOOR)
    m.box(14, 14, 0, 18, 18, FLOOR, "metaal2")
    return m


@tile("props/overig/persoon_1m80")
def person():
    """Scale model: a 1.80 m person (15 voxels) for checking dimensions."""
    m = V(6, 4, 15)
    # legs and shoes
    for z in range(0, 7):
        for x in (1, 4):
            m.set(x, 2, z, "stof1")
    for x in (1, 4):
        m.set(x, 1, 0, "bord_zwart")
    # torso with arms
    for z in range(7, 12):
        for x in range(1, 5):
            m.set(x, 2, z, "stof2")
        m.set(0, 2, z, "gordijn1" if z < 9 else "stof2")
        m.set(5, 2, z, "gordijn1" if z < 9 else "stof2")
    # head and hair
    for z in range(12, 15):
        for x in range(2, 4):
            m.set(x, 2, z, "gordijn1" if z < 14 else "hout_donker2")
    return m
