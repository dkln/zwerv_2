"""Props, part 2: fences and gates, low walls, café terraces, playground equipment, copses,
containers, jetties, swimming-pool props, flagpoles, place-name signs, push-button posts,
public-transport signals, tram catenary masts and extra Dutch (RVV) traffic signs.

Every tile is registered with @tile(path) / register(path, fn) from common.py; generate.py
calls the function and writes the returned V model to <OUT>/<path>.vox (+ .tile.json).
Coordinates: x = left->right, y = front->back (front = y=0), z = up; 1 voxel = 12.5 cm.
Props are free-standing models whose pivot is the bottom centre (see props.py).

FLAGS is imported by details2.py (facade flags).
"""
import math

from common import register, tile, text_pixels
from palette import P
from vox import V, mix, pick, h
from props import PICTO, crown_clusters, light_head, pole, shrub, sign_panel, trunk


def BRICK(seed):
    """Return a colour function for a running-bond brick wall (4 brick tones, offset every row)."""
    return lambda x, y, z: pick(["baksteen1", "baksteen2", "baksteen3", "baksteen4"], (x + y + (z % 2) * 2) // 3, z, 0, seed)


def _stone_cap(m, x0, x1, y0, y1, z, cx, cy):
    """Natural-stone cover slab on [x0,x1) x [y0,y1) at height z plus a ball finial centred at (cx, cy)."""
    for x in range(x0, x1):
        for y in range(y0, y1):
            m.set(x, y, z, "natuursteen1")
    m.ellipsoid(cx, cy, z + 2, 2, 2, 2, "natuursteen1")


# ------------------------------------------------------------------ fences and gates

@tile("props/hekken/hek_hoog_spijlen")
def fence_tall_bars():
    """Tall railing (2.5 m): two rails, a bar every 2 voxels, every other bar sticks out on top."""
    m = V(16, 2, 20)
    for x in range(16):
        m.set(x, 0, 2, "antraciet1")
        m.set(x, 0, 17, "antraciet1")
        if x % 2 == 0:
            for z in range(0, 19):
                m.set(x, 0, z, "antraciet1")
            if x % 4 == 0:
                m.set(x, 0, 19, "antraciet1")
    # end posts, one voxel behind the railing
    for x in (0, 15):
        for z in range(20):
            m.set(x, 1, z, "antraciet1")
    return m


@tile("props/hekken/hek_gaas_hoog")
def fence_mesh_tall():
    """Tall green wire-mesh fence with galvanised frame and posts."""
    m = V(24, 2, 17)
    for x in range(24):
        for z in range(0, 16):
            if x in (0, 23) or z in (0, 15) or (x + z) % 2 == 0:
                m.set(x, 0, z, "bord_groen2" if x not in (0, 23) else "gegalvaniseerd")
    for z in range(17):
        m.set(0, 1, z, "gegalvaniseerd")
        m.set(23, 1, z, "gegalvaniseerd")
    return m


@tile("props/hekken/schoolhek")
def school_fence():
    """Low green school fence: two rails with a bar every 2 voxels."""
    m = V(16, 2, 10)
    for x in range(16):
        m.set(x, 0, 1, "paneel_groen")
        m.set(x, 0, 8, "paneel_groen")
        if x % 2 == 0:
            for z in range(0, 10):
                m.set(x, 0, z, "paneel_groen")
    return m


def gate(width=32, color="amsterdamgroen", pillar=True):
    """Arched double gate of `width` voxels between two brick piers (6x6, stone cap + ball).

    The gate leaves sit in plane y=4; the top follows a parabola rising 4 voxels in the middle.
    """
    m = V(width + 12, 8, 26)
    if pillar:
        brick = BRICK(400)
        for x0 in (0, width + 6):
            for z in range(0, 22):
                for x in range(x0, x0 + 6):
                    for y in range(1, 7):
                        m.set(x, y, z, brick)
            _stone_cap(m, x0 - 1, x0 + 7, 0, 8, 22, x0 + 3, 4)
    for x in range(6, width + 6):
        dx = x + 0.5 - (width / 2 + 6)
        top = 16 + int(4 * (1 - (dx / (width / 2)) ** 2))
        for z in range(0, top):
            if x % 2 == 0 or z in (1, 8, top - 1):
                m.set(x, 4, z, color)
    # two brass handles and the centre stile where the leaves meet
    m.set(width // 2 + 5, 3, 8, "messing")
    m.set(width // 2 + 7, 3, 8, "messing")
    for z in range(0, 18):
        m.set(width // 2 + 6, 4, z, color)
    return m


register("props/hekken/poort_groot", lambda: gate())
register("props/hekken/poort_klein", lambda: gate(12))
register("props/hekken/poort_hout", lambda: gate(20, "hout2", True))


@tile("props/hekken/poortpijler")
def gate_pier():
    """Single brick gate pier with stone cap and ball finial."""
    m = V(8, 8, 26)
    brick = BRICK(401)
    for z in range(22):
        for x in range(1, 7):
            for y in range(1, 7):
                m.set(x, y, z, brick)
    _stone_cap(m, 0, 8, 0, 8, 22, 4, 4)
    return m


# ------------------------------------------------------------------ low walls

def low_wall(mat, hgt, length=16, cap="natuursteen2", depth=3):
    """Straight low wall `length` long, `hgt` high and `depth` thick (y = 1..depth).

    mat is a colour name or colour function; cap (or None) is a cover course one voxel
    wider on the front, placed at z = hgt.
    """
    m = V(length, 4, hgt + 1)
    for z in range(hgt):
        for x in range(length):
            for y in range(1, 1 + depth):
                m.set(x, y, z, mat)
    if cap:
        for x in range(length):
            for y in range(0, min(4, 2 + depth)):
                m.set(x, y, hgt, cap)
    return m


register("props/muurtjes/muurtje_baksteen", lambda: low_wall(BRICK(402), 5))
register("props/muurtjes/muurtje_baksteen_hoog", lambda: low_wall(BRICK(403), 14))
register("props/muurtjes/muurtje_natuursteen", lambda: low_wall(lambda x, y, z: pick(["natuursteen1", "natuursteen2", "natuursteen3"], (x + (z % 2) * 2) // 4, z, 0, 404), 6, cap="natuursteen1"))
register("props/muurtjes/muurtje_beton", lambda: low_wall(mix("beton1", "beton2", "beton3", seed=405), 5, cap=None))
register("props/muurtjes/zitrand_beton", lambda: low_wall(mix("beton1", "beton3", seed=406), 3, cap="hout_bank1"))
register("props/muurtjes/muurtje_kort", lambda: low_wall(BRICK(407), 5, 8))


@tile("props/muurtjes/muurtje_hoek")
def low_wall_corner():
    """L-shaped low brick wall (back and left side of a 16x16 area) with stone cap."""
    m = V(16, 16, 6)
    f = BRICK(408)
    for z in range(5):
        for x in range(16):
            for y in range(13, 16):
                m.set(x, y, z, f)
        for y in range(16):
            for x in range(0, 3):
                m.set(x, y, z, f)
    # cap wherever the wall reaches the top course
    for x in range(16):
        for y in range(16):
            if m.get(x, y, 4):
                m.set(x, y, 5, "natuursteen2")
    return m


# ------------------------------------------------------------------ terrace

def chair(m, x, y, color="metaal_donker", facing=1):
    """Draw a 3x3 chair with its corner at (x, y): legs, wooden seat at z=3 and a backrest
    at the back (facing > 0) or front (facing <= 0) edge."""
    for z in range(0, 4):
        for dx, dy in ((0, 0), (2, 0), (0, 2), (2, 2)):
            m.set(x + dx, y + dy, z, color)
    for dx in range(3):
        for dy in range(3):
            m.set(x + dx, y + dy, 3, "hout_bank2")
    by = y + (2 if facing > 0 else 0)
    for dx in range(3):
        for z in range(4, 7):
            m.set(x + dx, by, z, color)


def terrace_set(parasol=False, color="luifel_rood"):
    """Round café table with two chairs; optionally with a striped parasol (color / white)."""
    m = V(24 if parasol else 20, 24 if parasol else 20, 22 if parasol else 8)
    c = m.sx // 2
    for z in range(0, 5):
        m.set(c, c, z, "metaal_donker")
    m.cyl(c, c, 3, 5, 6, "hout_bank1")
    chair(m, c - 1, c - 8, facing=-1)
    chair(m, c - 1, c + 5, facing=1)
    if parasol:
        for z in range(6, 19):
            m.set(c, c, z, "hout2")
        # canopy: concentric rings shrinking upwards, 8 alternating colour segments
        for z in range(15, 20):
            r = 11 - (z - 15) * 2.2
            for y in range(m.sy):
                for x in range(m.sx):
                    d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                    if r - 1.4 < d <= r:
                        ang = math.atan2(y - c, x - c)
                        m.set(x, y, z, color if int((ang + 4) * 4 / math.pi) % 2 else "luifel_wit")
    return m


register("props/terras/terras_set", lambda: terrace_set())
register("props/terras/terras_set_parasol", lambda: terrace_set(True))
register("props/terras/terras_set_parasol_groen", lambda: terrace_set(True, "luifel_groen"))


@tile("props/terras/terras_scherm")
def terrace_screen():
    """Terrace wind screen: metal frame, red lower panel, glass upper panel."""
    m = V(24, 2, 12)
    for x in range(24):
        for z in range(0, 12):
            edge = x in (0, 23) or z in (0, 11) or x % 8 == 0
            m.set(x, 0, z, "metaal3" if edge else ("glas_helder" if z > 4 else "luifel_rood"))
    return m


@tile("props/terras/stoepbord")
def a_board():
    """A-frame sidewalk board: two slanted chalkboards meeting at the top."""
    m = V(6, 6, 8)
    for z in range(8):
        for x in range(6):
            c = "hout2" if x in (0, 5) or z in (0, 7) else "bord_zwart"
            m.set(x, 1 + z // 3, z, c)
            m.set(x, 5 - z // 3, z, c)
    # chalk scribbles on the front board
    for x in (1, 3):
        m.set(x, 2, 5, "bord_wit")
        m.set(x + 1, 2, 3, "bord_wit")
    return m


@tile("props/terras/statafel")
def standing_table():
    """Standing bar table: round top at z=9 on a single leg with a round foot."""
    m = V(8, 8, 10)
    for z in range(9):
        m.set(4, 4, z, "metaal3")
    m.cyl(4, 4, 3, 9, 10, "hout_bank1")
    m.cyl(4, 4, 2, 0, 1, "metaal3")
    return m


@tile("props/terras/bloembak_terras")
def flower_box_terrace():
    """Long wooden planter with a flowering shrub."""
    m = V(16, 6, 9)
    m.box(0, 1, 0, 16, 5, 4, "hout_donker1")
    shrub(m, 8, 3, 6, 7, 2.5, 3, ["blad2", "blad1", "blad4"], 409, ["bloem_rood", "bloem_wit"])
    return m


# ------------------------------------------------------------------ playground

@tile("props/speeltuin/schommel")
def swing():
    """Double swing: A-frame legs at x=1 and x=26, top beam at z=21, two seats on chains."""
    m = V(28, 16, 22)
    for t in range(0, 21):
        for x in (1, 26):
            m.set(x, 8 - t * 6 // 21, t, "paneel_rood")
            m.set(x, 8 + t * 6 // 21, t, "paneel_rood")
    for x in range(1, 27):
        m.set(x, 8, 21, "paneel_rood")
    for xs in (8, 18):
        for z in range(6, 21):
            m.set(xs, 8, z, "metaal3")
            m.set(xs + 3, 8, z, "metaal3")
        for x in range(xs, xs + 4):
            m.set(x, 8, 5, "rubber")
    return m


@tile("props/speeltuin/glijbaan")
def slide():
    """Slide: platform at z=13 with railings, ladder at the front (y=0), chute running to the back."""
    m = V(12, 36, 20)
    # posts (up to the platform and above it as railing posts)
    for z in range(0, 19):
        for y in (2, 7):
            m.set(3, y, z, "paneel_geel")
            m.set(8, y, z, "paneel_geel")
    for y in range(2, 8):
        for x in range(3, 9):
            m.set(x, y, 13, "hout2")
    for x in range(3, 9):
        m.set(x, 2, 18, "paneel_rood")
        m.set(x, 7, 18, "paneel_rood")
    # chute: descends 1 voxel every 2 voxels of y, with raised side edges
    for y in range(8, 34):
        z = max(0, 13 - (y - 8) // 2)
        for x in range(4, 8):
            m.set(x, y, z, "rvs")
        m.set(3, y, z + 1, "rvs")
        m.set(8, y, z + 1, "rvs")
    # ladder: stiles at y=1 and rungs at y=0
    for z in range(0, 13):
        for x in (3, 8):
            m.set(x, 1, z, "paneel_geel")
        if z % 2 == 0:
            for x in range(4, 8):
                m.set(x, 0, z, "hout2")
    return m


@tile("props/speeltuin/klimrek")
def climbing_frame():
    """Climbing frame: cubic grid of bars with a 5-voxel pitch."""
    m = V(24, 24, 16)
    for z in range(0, 16, 5):
        for i in range(0, 24, 5):
            for j in range(24):
                m.set(i, j, z, "paneel_blauw")
                m.set(j, i, z, "paneel_blauw")
    for x in range(0, 24, 5):
        for y in range(0, 24, 5):
            for z in range(16):
                m.set(x, y, z, "paneel_blauw")
    return m


@tile("props/speeltuin/wipwap")
def seesaw():
    """Seesaw: slightly tilted plank on a central pivot block, with a handle at each seat."""
    m = V(28, 6, 8)
    m.box(12, 2, 0, 16, 4, 4, "paneel_rood")

    def plank_z(x):
        return 4 + (x - 14) * 3 // 26

    for x in range(1, 27):
        m.set(x, 2, plank_z(x), "hout2")
        m.set(x, 3, plank_z(x), "hout2")
    for x in (3, 24):
        z = plank_z(x)
        for zz in range(z + 1, z + 4):
            m.set(x, 2, zz, "paneel_geel")
    return m


@tile("props/speeltuin/zandbak")
def sandpit():
    """Square sandpit with a wooden rim and a few toys."""
    m = V(24, 24, 4)
    for y in range(24):
        for x in range(24):
            edge = x in (0, 23) or y in (0, 23)
            for z in range(3 if edge else 2):
                m.set(x, y, z, "hout1" if edge else "zand1")
    m.set(6, 6, 2, "paneel_rood")
    m.set(7, 6, 2, "paneel_rood")
    m.set(14, 15, 2, "paneel_geel")
    return m


@tile("props/speeltuin/draaimolen")
def roundabout_ride():
    """Playground roundabout: round deck, central post and four handle bars."""
    m = V(20, 20, 8)
    m.cyl(10, 10, 9, 1, 2, "paneel_rood")
    m.cyl(10, 10, 1, 0, 8, "metaal3")
    for a in range(4):
        ang = a * math.pi / 2
        for t in range(2, 9):
            m.set(10 + math.cos(ang) * t, 10 + math.sin(ang) * t, 6, "metaal3")
    return m


@tile("props/speeltuin/speelhuisje")
def playhouse():
    """Play tower: deck on four posts, slatted walls, stepped red roof and a front ladder."""
    m = V(16, 16, 24)
    for (x, y) in ((1, 1), (14, 1), (1, 14), (14, 14)):
        for z in range(0, 14):
            m.set(x, y, z, "hout2")
    m.box(1, 1, 8, 15, 15, 9, "hout1")
    for z in range(9, 14):
        for i in range(1, 15):
            if i % 3 == 0:
                m.set(i, 1, z, "hout1")
                m.set(1, i, z, "hout1")
    for z in range(14, 22):
        w = 22 - z
        m.box(8 - w, 0, z, 8 + w, 16, z + 1, "paneel_rood")
    for z in range(0, 8, 2):
        for x in range(5, 10):
            m.set(x, 0, z, "hout2")
    return m


@tile("props/speeltuin/voetbaldoel")
def football_goal():
    """Football goal (5 m wide) with a sloping net behind it."""
    m = V(40, 12, 18)
    for z in range(17):
        m.set(1, 1, z, "bord_wit")
        m.set(38, 1, z, "bord_wit")
    for x in range(1, 39):
        m.set(x, 1, 16, "bord_wit")
    for x in range(1, 39):
        for z in range(16):
            y = 1 + int((16 - z) * 0.6)
            if (x + z) % 3 == 0:
                m.set(x, y, z, "stuc3")
    return m


@tile("props/speeltuin/basketbalpaal")
def basketball_hoop():
    """Basketball post with backboard and an orange hoop sticking out to the front."""
    m = V(12, 12, 32)
    pole(m, 5, 9, 0, 28, "metaal3")
    for x in range(1, 11):
        for z in range(22, 30):
            m.set(x, 8, z, "bord_wit" if not (x in (4, 7) and 23 < z < 27) else "bord_rood")
    for x in range(3, 9):
        m.set(x, 6, 23, "bord_oranje")
        m.set(x, 4, 23, "bord_oranje")
    m.set(3, 5, 23, "bord_oranje")
    m.set(8, 5, 23, "bord_oranje")
    return m


@tile("props/speeltuin/pingpongtafel")
def table_tennis():
    """Concrete table-tennis table with a metal net."""
    m = V(24, 14, 8)
    m.box(0, 0, 6, 24, 14, 7, "beton2")
    for x in (3, 20):
        m.box(x, 4, 0, x + 1, 10, 6, "beton1")
    for y in range(14):
        m.set(12, y, 7, "metaal3")
    return m


# ------------------------------------------------------------------ copses

def copse(seed, size):
    """Cluster of shrubs (size // 4) and a few small trees on a size x size footprint."""
    m = V(size, size, 40)
    n = size // 4
    for i in range(n):
        x = 4 + h(i, 0, 0, seed) * (size - 8)
        y = 4 + h(i, 1, 0, seed) * (size - 8)
        r = 3 + h(i, 2, 0, seed) * 4
        shrub(m, x, y, r * 0.7, r, r, r * 0.9, ["blad1", "blad3", "blad5", "haag1", "blad2"], seed + i)
    for i in range(max(1, n // 4)):
        x = 6 + h(i, 5, 0, seed) * (size - 12)
        y = 6 + h(i, 6, 0, seed) * (size - 12)
        trunk(m, x, y, 16, 0.9, "schors2")
        crown_clusters(m, x, y, 14, 32, 7, 4, ["blad1", "blad2", "blad4"], seed + 50 + i)
    return m


register("props/planten/bosje_klein", lambda: copse(410, 24))
register("props/planten/bosje_groot", lambda: copse(411, 48))
register("props/planten/struikgewas", lambda: copse(412, 32))


@tile("props/planten/braamstruik")
def bramble():
    """Bramble bush with black and red berries."""
    m = V(16, 12, 8)
    shrub(m, 8, 6, 3, 7.5, 5.5, 4, ["blad3", "blad5", "haag2"], 413, ["bord_zwart", "bloem_rood"])
    return m


# ------------------------------------------------------------------ containers

@tile("props/straat/container_groot")
def container_large():
    """Open skip container (6 m) filled with rubble at z=12."""
    m = V(48, 20, 18)
    for z in range(0, 16):
        for y in range(1, 19):
            for x in range(0, 48):
                edge = x in (0, 47) or y in (1, 18)
                inner = not edge and z > 1
                if not inner:
                    m.set(x, y, z, "paneel_geel" if (x % 4 or z < 2) else "bord_oranje")
    # stiffening ribs on front and back
    for x in range(0, 48, 6):
        for z in range(2, 16):
            m.set(x, 0, z, "bord_oranje")
            m.set(x, 19, z, "bord_oranje")
    for y in range(2, 18):
        for x in range(1, 47):
            if h(x, y, 0, 414) < 0.7:
                m.set(x, y, 12, pick(["hout1", "stuc2", "beton2", "baksteen2"], x, y, 0, 414))
    return m


@tile("props/straat/container_klein")
def container_small():
    """Small wheeled waste container with green lid."""
    m = V(12, 10, 12)
    for z in range(1, 11):
        for y in range(1, 9):
            for x in range(0, 12):
                m.set(x, y, z, "metaal1" if z < 10 else "bord_groen")
    for x in (1, 10):
        for y in (1, 8):
            m.set(x, y, 0, "rubber")
    return m


@tile("props/straat/glasbak")
def bottle_bank():
    """Round green bottle bank with lifting hook and front slots."""
    m = V(12, 12, 14)
    for z in range(0, 12):
        m.cyl(6, 6, 5, z, z + 1, "bord_groen" if z < 11 else "metaal2")
    for z in range(12, 14):
        m.set(6, 6, z, "metaal2")
    for x in (3, 4, 7, 8):
        m.set(x, 1, 9, "interieur3")
    return m


@tile("props/straat/kledingcontainer")
def clothes_container():
    """Clothes collection container with deposit flap."""
    m = V(12, 10, 16)
    m.box(0, 1, 0, 12, 9, 15, "paneel_groen")
    m.box(0, 1, 15, 12, 9, 16, "stuc1")
    m.box(3, 0, 9, 9, 1, 12, "metaal2")
    return m


@tile("props/straat/bouwkeet")
def site_cabin():
    """Construction site cabin (6 x 2.5 m) with two windows and a door."""
    m = V(48, 20, 22)
    m.box(0, 0, 0, 48, 20, 20, "stuc1")
    m.box(0, 0, 20, 48, 20, 21, "metaal2")
    for x0 in (6, 30):
        m.box(x0, 0, 8, x0 + 10, 1, 15, "glas2")
    m.box(20, 0, 0, 26, 1, 16, "metaal1")
    return m


# ------------------------------------------------------------------ jetties

def _deck(x, y, seed, plank):
    """Colour of a jetty deck voxel: mixed planks, or a dark seam where `plank` is false."""
    return pick(["hout1", "hout2", "hout3"], x // 3, y, 0, seed) if plank else "hout_donker1"


def jetty_long(length=32, width=12, stairs=False):
    """Straight wooden jetty along y with a deck at z=1, posts every 8 voxels on both
    sides, and optionally steps down into the water at the back end."""
    m = V(width, length, 6)
    for y in range(length):
        for x in range(width):
            m.set(x, y, 1, _deck(x, y, 415, y % 3))
    for x in (0, width - 1):
        for y in range(0, length, 8):
            for z in range(0, 5):
                m.set(x, y, z, "hout_donker2")
    if stairs:
        for i in range(4):
            for x in range(3, width - 3):
                m.set(x, length - 1 - i, 1 if i < 2 else 0, "hout_donker1")
    return m


register("props/water/steiger_lang", lambda: jetty_long(64))
register("props/water/steiger_breed", lambda: jetty_long(32, 24))
register("props/water/steiger_trap", lambda: jetty_long(32, 12, True))


@tile("props/water/steiger_L")
def jetty_L():
    """L-shaped jetty: a 10-wide arm along the left side and a 10-deep arm along the back."""
    m = V(32, 32, 6)
    for y in range(32):
        for x in range(32):
            if x < 10 or y >= 22:
                m.set(x, y, 1, _deck(x, y, 416, (y + x) % 3))
    for (x, y) in ((0, 0), (9, 0), (0, 31), (31, 31), (31, 22), (9, 22)):
        for z in range(5):
            m.set(x, y, z, "hout_donker2")
    return m


# ------------------------------------------------------------------ swimming pool

@tile("props/zwembad/zwembadtrap")
def pool_ladder():
    """Stainless-steel pool ladder with handrails curving back over the edge."""
    m = V(8, 6, 12)
    for x in (1, 6):
        for z in range(0, 11):
            m.set(x, 1 if z < 9 else 1 + (z - 8), z, "rvs")
        m.set(x, 4, 10, "rvs")
    for z in range(1, 8, 2):
        for x in range(2, 6):
            m.set(x, 1, z, "rvs")
    return m


@tile("props/zwembad/duikplank")
def diving_board():
    """Diving board on a concrete base at the back, overhanging towards the front."""
    m = V(8, 32, 8)
    m.box(1, 24, 0, 7, 32, 6, "beton1")
    for y in range(4, 26):
        for x in range(2, 6):
            m.set(x, y, 6, "bord_blauw")
    return m


@tile("props/zwembad/ligstoel")
def deckchair():
    """Sun lounger with a raised backrest at the back."""
    m = V(8, 18, 8)
    for y in range(2, 16):
        z = 2 if y < 12 else 2 + (y - 11)
        for x in range(1, 7):
            m.set(x, y, z, "bord_wit" if (y % 3) else "paneel_blauw")
    for (x, y) in ((1, 2), (6, 2), (1, 11), (6, 11)):
        for z in range(0, 2):
            m.set(x, y, z, "rvs")
    return m


@tile("props/zwembad/badmeesterstoel")
def lifeguard_chair():
    """Elevated lifeguard chair with a front ladder."""
    m = V(10, 10, 24)
    for (x, y) in ((1, 1), (8, 1), (1, 8), (8, 8)):
        for z in range(0, 16):
            m.set(x, y, z, "bord_wit")
    m.box(1, 1, 16, 9, 9, 17, "bord_wit")
    m.box(2, 7, 17, 8, 9, 22, "bord_rood")
    for z in range(0, 16, 2):
        for x in range(2, 8):
            m.set(x, 1, z, "bord_wit")
    return m


@tile("props/zwembad/parasol")
def parasol():
    """Yellow/white striped beach parasol on a concrete foot."""
    m = V(24, 24, 20)
    c = 12
    for z in range(0, 16):
        m.set(c, c, z, "hout2")
    m.cyl(c, c, 2, 0, 1, "beton2")
    for z in range(13, 18):
        r = 11 - (z - 13) * 2.4
        m.cyl(c, c, r, z, z + 1, lambda x, y, zz: P["luifel_geel"] if int((math.atan2(y - c, x - c) + 4) * 4 / math.pi) % 2 else P["luifel_wit"])
    return m


# ------------------------------------------------------------------ flags and signs

# Flag stripes from top to bottom (6 rows); keys are part of the tile names.
FLAGS = {
    "nl": ["vlag_rood", "vlag_rood", "vlag_wit", "vlag_wit", "vlag_blauw", "vlag_blauw"],
    "regenboog": ["vlag_rood", "vlag_oranje", "vlag_geel", "vlag_groen", "vlag_blauw", "vlag_paars"],
    "denhaag": ["vlag_geel", "vlag_geel", "vlag_geel", "vlag_groen", "vlag_groen", "vlag_groen"],
    "amsterdam": ["vlag_rood", "vlag_rood", "vlag_zwart", "vlag_zwart", "vlag_rood", "vlag_rood"],
    "rotterdam": ["vlag_groen", "vlag_groen", "vlag_wit", "vlag_wit", "vlag_groen", "vlag_groen"],
    "utrecht": ["vlag_wit", "vlag_wit", "vlag_wit", "vlag_rood", "vlag_rood", "vlag_rood"],
    "transgender": ["vlag_lichtblauw", "vlag_roze", "vlag_wit", "vlag_wit", "vlag_roze", "vlag_lichtblauw"],
    "eu": ["vlag_donkerblauw"] * 6,
    "oranje": ["vlag_oranje"] * 6,
    "zwervr": ["vlag_zwart", "vlag_geel", "vlag_geel", "vlag_geel", "vlag_geel", "vlag_zwart"],
}

# (x offset, row) of the EU stars on the 12x6 flag
_EU_STARS = ((5, 1), (3, 2), (8, 2), (3, 4), (8, 4), (5, 5))


def flagpole(kind):
    """8 m flagpole with gold knob and a 12x6 flag (FLAGS[kind]) flying to the right."""
    m = V(28, 4, 64)
    for z in range(64):
        m.set(14, 1, z, "stuc1")
        m.set(14, 2, z, "stuc1")
    m.set(14, 1, 63, "goud")
    cols = FLAGS[kind]
    for x in range(15, 27):
        for i in range(6):
            c = cols[i]
            if kind == "eu" and (x - 15, i) in _EU_STARS:
                c = "vlag_geel"
            if kind == "amsterdam" and i in (2, 3) and x in (17, 20, 23):
                c = "vlag_wit"   # the three St. Andrew's crosses, simplified
            m.set(x, 1, 62 - i, c)
    return m


for _k in FLAGS:
    register(f"props/straat/vlaggenmast_{_k}", (lambda k: lambda: flagpole(k))(_k))


def place_name(text):
    """Blue place-name sign (white border and text) on two posts; width grows with the text
    (at least 32, always even)."""
    px, (tw, th) = text_pixels(text)
    w = max(32, tw + 6)
    w += w % 2
    m = V(w, 4, 30)
    pole(m, 2, 2, 0, 30, "metaal3")
    pole(m, w - 4, 2, 0, 30, "metaal3")
    for z in range(20, 30):
        for x in range(1, w - 1):
            edge = x in (1, w - 2) or z in (20, 29)
            m.set(x, 1, z, "bord_wit" if edge else "bord_blauw")
            m.set(x, 2, z, "metaal1")
    for (c, r) in px:
        m.set(w // 2 - tw // 2 + c, 0, 27 - r, "bord_wit")
    return m


def place_name_end():
    """End-of-built-up-area sign: the ZWERVR place-name sign with a red diagonal bar."""
    m = place_name("ZWERVR")
    for i in range(3, m.sx - 3):
        z = 21 + int((i - 3) * 7 / (m.sx - 6))
        m.set(i, 0, z, "bord_rood")
    return m


register("props/borden/bord_plaatsnaam_den_haag", lambda: place_name("DEN HAAG"))
register("props/borden/bord_plaatsnaam_einde", place_name_end)

register("props/borden/bord_eenrichting_fiets_uitgezonderd",
         lambda: sign_panel("vierkant", "bord_blauw", "bord_wit", "pijl_rechts", "bord_wit", n=11))
register("props/borden/bord_busbaan", lambda: sign_panel("vierkant", "bord_blauw", "bord_wit", "bus", "bord_wit", n=11))
register("props/borden/bord_fietsstraat",
         lambda: sign_panel("vierkant", "bord_wit", "bord_rood", "fiets_klein", "bord_rood", n=11))


# ------------------------------------------------------------------ push-button posts and speed camera

@tile("props/verkeer/drukknop_fiets")
def push_button_bike():
    """Low yellow push-button box for cyclists (reachable from the saddle)."""
    m = V(4, 4, 10)
    for z in range(0, 7):
        m.set(1, 1, z, "metaal3")
        m.set(2, 1, z, "metaal3")
    for z in range(7, 10):
        for x in range(0, 4):
            m.set(x, 1, z, "bord_geel")
            m.set(x, 2, z, "bord_geel")
    m.set(1, 0, 8, "bord_zwart")
    m.set(2, 0, 8, "stoplicht_rood")
    return m


@tile("props/verkeer/drukknop_voetganger")
def push_button_pedestrian():
    """Pedestrian push-button box on a post."""
    m = V(4, 4, 14)
    for z in range(0, 14):
        m.set(1, 1, z, "metaal3")
        m.set(2, 1, z, "metaal3")
    for z in range(9, 13):
        for x in range(0, 4):
            m.set(x, 1, z, "bord_geel")
    m.set(1, 0, 11, "bord_zwart")
    m.set(2, 0, 10, "stoplicht_rood")
    return m


@tile("props/verkeer/wegafzetting_paal_flitser")
def speed_camera():
    """Yellow speed-camera box on a round post."""
    m = V(6, 6, 28)
    for z in range(0, 18):
        m.cyl(3, 3, 1.2, z, z + 1, "metaal3")
    m.box(1, 1, 18, 5, 5, 27, "bord_geel")
    m.box(2, 0, 22, 4, 1, 25, "interieur3")
    return m


# ------------------------------------------------------------------ bus/tram signals and tram catenary

@tile("props/verkeer/verkeerslicht_bus")
def traffic_light_bus():
    """Public-transport signal: white bars/dots (stop = horizontal bar)."""
    m = V(8, 4, 32)
    pole(m, 3, 2, 0, 30, "metaal3")
    for z in range(19, 30):
        for x in range(1, 7):
            m.set(x, 1, z, "bord_zwart")
            m.set(x, 2, z, "bord_zwart")
    for x in range(2, 6):
        m.set(x, 0, 27, "lamp_wit")
    for x in (2, 5):
        m.set(x, 0, 23, "stoplicht_rood_uit")
    m.set(3, 0, 21, "lamp_wit")
    m.set(4, 0, 21, "lamp_wit")
    return m


@tile("props/verkeer/verkeerslicht_set")
def traffic_light_set():
    """Post with combined lights for cars, cyclists and pedestrians."""
    m = V(16, 4, 32)
    pole(m, 7, 2, 0, 30, "metaal3")
    light_head(m, 6, 1, 19, "rood")
    light_head(m, 1, 1, 9, "groen")
    # pedestrian head: black box with a red standing figure
    for z in range(9, 17):
        for x in range(11, 15):
            m.set(x, 1, z, "bord_zwart")
    for (c, r) in [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (0, 3), (2, 3)]:
        m.set(11 + c, 0, 16 - r, "stoplicht_rood")
    for x in range(1, 15):
        m.set(x, 2, 12, "metaal3")
    return m


def _mast(m, x0, z1, color="amsterdamgroen"):
    """2x2 catenary mast at x0..x0+1, y=1..2, from z=0 up to z1 (exclusive)."""
    for z in range(0, z1):
        for dx in (0, 1):
            m.set(x0 + dx, 1, z, color)
            m.set(x0 + dx, 2, z, color)


def _hanger(m, x, z0, z1):
    """Vertical dropper wire at x from z0 to z1 (exclusive) with a rubber insulator at z0 - 1."""
    for z in range(z0, z1):
        m.set(x, 1, z, "metaal_donker")
    m.set(x, 1, z0 - 1, "rubber")


@tile("props/ov/tram_bovenleiding_mast")
def tram_catenary_mast():
    """Single tram catenary mast with a cantilever arm carrying two contact wires."""
    m = V(72, 4, 56)
    _mast(m, 35, 54)
    for x in range(36, 70):
        m.set(x, 1, 50 - (x - 36) // 12, "metaal_donker")
    for xw in (46, 62):
        _hanger(m, xw, 44, 49)
    return m


@tile("props/ov/tram_bovenleiding_dubbel")
def tram_catenary_double():
    """Pair of tram catenary masts with a span wire carrying two contact wires."""
    m = V(88, 4, 56)
    for x0 in (2, 84):
        _mast(m, x0, 54)
    for x in range(3, 85):
        m.set(x, 1, 50, "metaal_donker")
    for xw in (26, 62):
        _hanger(m, xw, 44, 50)
    return m


# ------------------------------------------------------------------ more Dutch traffic signs (RVV)

# extra pictograms ('#' = pixel, top row first) for sign_panel
PX = {
    "vracht": ["###..", "####.", "#####", ".#..#"],
    "kind": [".#.#.", "#####", ".#.#.", "#.#.#"],
    "drempel": [".....", ".###.", "#####"],
    "rotonde": [".###.", "#...#", "#.#.#", "#...#", ".###."],
    "werk": ["..#..", ".###.", "#.#..", "..##.", ".#..#"],
    "spoor": ["#####", "#.#.#", "#####", "#...#"],
    "slip": ["##...", "..#..", "...##", "#.#.#"],
    "twee_autos": ["##.##", "##.##", "#..#."],
    "rechts": ["..#..", "...#.", "#####", "...#.", "..#.."],
    "links": ["..#..", ".#...", "#####", ".#...", "..#.."],
    "file": ["##.##", "#####", "##.##"],
    "tram": ["#####", "#.#.#", "#####", "#...#"],
}


def _plate_line(m, n, kind, color):
    """Draw a diagonal ('slash': bottom-left to top-right) or a cross ('x') over the n x n
    plate of a sign_panel model; returns m."""
    z0 = m.sz - n - 3
    for i in range(1, n - 1):
        if kind in ("slash", "x"):
            m.set(1 + i, 0, z0 + n - 1 - i, color)
        if kind == "x":
            m.set(1 + i, 0, z0 + i, color)
    return m


# shared sign_panel keyword sets
_PROHIBIT = dict(shape="rond", bg="bord_wit", rim="bord_rood")                    # red ring
_MANDATORY = dict(shape="rond", bg="bord_blauw", rim="bord_wit", pc="bord_wit")    # blue disc
_WARNING = dict(shape="driehoek", bg="bord_wit", rim="bord_rood", n=13)            # red triangle
_INFO = dict(shape="vierkant", bg="bord_blauw", rim="bord_wit", pc="bord_wit", n=11)  # blue square

# sign name -> sign_panel(**kwargs); names are part of the tile paths
SIGNS2 = {
    "max_60": dict(_PROHIBIT, text="60", n=11),
    "max_70": dict(_PROHIBIT, text="70", n=11),
    "max_120": dict(_PROHIBIT, text="120", n=13),
    "max_130": dict(_PROHIBIT, text="130", n=13),
    "vrachtauto_verboden": dict(_PROHIBIT, picto=PX["vracht"], n=11),
    "fiets_verboden": dict(_PROHIBIT, picto="fiets_klein", n=11),
    "inhaalverbod": dict(_PROHIBIT, picto=PX["twee_autos"], n=11),
    "rotonde": dict(_MANDATORY, picto=PX["rotonde"], n=11),
    "verplicht_rechtsaf": dict(_MANDATORY, picto=PX["rechts"], n=11),
    "verplicht_linksaf": dict(_MANDATORY, picto=PX["links"], n=11),
    "fiets_en_voetpad": dict(_MANDATORY, picto="voetganger", n=11),
    "busbaan_rond": dict(_MANDATORY, picto="bus", n=11),
    "trambaan": dict(_MANDATORY, picto=PX["tram"], n=11),
    "let_op_kinderen": dict(_WARNING, picto=PX["kind"]),
    "drempel": dict(_WARNING, picto=PX["drempel"]),
    "werk_in_uitvoering": dict(_WARNING, picto=PX["werk"]),
    "spoorwegovergang": dict(_WARNING, picto=PX["spoor"]),
    "slipgevaar": dict(_WARNING, picto=PX["slip"]),
    "rotonde_vooraankondiging": dict(_WARNING, picto=PX["rotonde"]),
    "file": dict(_WARNING, picto=PX["file"]),
    "fietsers_oversteken": dict(_WARNING, picto="fiets_klein"),
    "tram_kruist": dict(_WARNING, picto=PX["tram"]),
    "autosnelweg": dict(_INFO, picto=["#...#", "##.##", "#.#.#", "#...#"]),
    "autoweg": dict(_INFO, picto="auto"),
    "tunnel": dict(_INFO, picto=[".###.", "#...#", "#...#", "#...#"]),
    "ziekenhuis": dict(_INFO, text="H"),
    "informatie": dict(_INFO, text="I"),
}
for _n, _kw in SIGNS2.items():
    register(f"props/borden/bord_{_n}", (lambda kw: lambda: sign_panel(**kw))(_kw))


@tile("props/borden/bord_parkeerverbod")
def sign_no_parking():
    """No parking: blue disc, red ring, red diagonal."""
    m = sign_panel("rond", "bord_blauw", "bord_rood", n=11)
    return _plate_line(m, 11, "slash", "bord_rood")


@tile("props/borden/bord_stopverbod")
def sign_no_stopping():
    """No stopping: blue disc, red ring, red cross."""
    m = sign_panel("rond", "bord_blauw", "bord_rood", n=11)
    return _plate_line(m, 11, "x", "bord_rood")


@tile("props/borden/bord_einde_voorrangsweg")
def sign_end_priority_road():
    """End of priority road: priority diamond with a black diagonal."""
    m = sign_panel("ruit", "bord_wit", "bord_zwart", inner="bord_geel", n=11)
    return _plate_line(m, 11, "slash", "bord_zwart")


@tile("props/borden/bord_einde_maximum")
def sign_end_speed_limit():
    """End of speed limit 50: grey number in a black ring with a black diagonal."""
    m = sign_panel("rond", "bord_wit", "bord_zwart", text="50", pc="antraciet2", n=11)
    return _plate_line(m, 11, "slash", "bord_zwart")


@tile("props/borden/bord_onderbord_uitgezonderd")
def sign_sub_plate():
    """Sub-plate 'except cyclists': white plate with black border and a bicycle pictogram."""
    m = V(13, 4, 26)
    pole(m, 6, 2, 0, 26, "metaal3")
    for z in range(14, 19):
        for x in range(1, 12):
            m.set(x, 1, z, "bord_wit" if 1 < x < 11 and 14 < z < 18 else "bord_zwart")
    for r, line in enumerate(PICTO["fiets_klein"]):
        for c, v in enumerate(line):
            if v == "#":
                m.set(3 + c, 0, 17 - r, "bord_zwart")
    return m


# ------------------------------------------------------------------ garden walls (medium height) with gate

def garden_wall(hgt=11, with_gate=False, length=16):
    """Brick garden wall `hgt` high; with_gate cuts an opening at x=4..11 holding a
    wooden door (striped planks) with a brass handle."""
    m = low_wall(BRICK(420), hgt, length)
    if with_gate:
        m.clear(4, 0, 0, 12, 4, hgt + 1)
        for z in range(0, hgt - 1):
            for x in range(4, 12):
                m.set(x, 2, z, "hout2" if x % 2 else "hout_donker1")
        m.set(10, 1, 5, "messing")
    return m


register("props/muurtjes/tuinmuur_middel", lambda: garden_wall(11))
register("props/muurtjes/tuinmuur_hoog", lambda: garden_wall(15))
register("props/muurtjes/tuinmuur_poort", lambda: garden_wall(11, True))
register("props/muurtjes/tuinmuur_hoog_poort", lambda: garden_wall(15, True))
