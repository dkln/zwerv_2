"""Extras, part 5: themed shop ground floors, open tunnel troughs, tram lanes with regular road
markings, separate tram track, medians, plain bus lane, luxury apartments (roof terrace, roof
pool, penthouse), extra bicycle-tunnel variants, classic streetlights, café tables and
parasols, statues and green (sedum) roofs.

Tiles register through @tile(path) / register(path, fn) (common.py) and are written by
generate.py. Coordinates: x = left->right, y = front->back (front = y=0), z = up;
1 voxel = 12.5 cm. Ground tiles are T x T (32x32), one ground layer = FLOOR voxels; buildings
use buildings.Bld / make_block (48x48 canvas, 32x32 block offset by O, HGT voxels per storey).
Facade function names (lx_*, and "f_winkel_<kind>" for the shop facades) feed the building
RNG seed; do not rename them.
"""
import math

from common import T, WALK, FLOOR, register, tile
from palette import P
from vox import V, mix, pick, h, blocky
from ground import (column, new, lane, sidewalk, paint, bike_path_straight, paver_fn,
                    GRASS, CONCRETE, CONCRETE_DARK, PAVING, CURB, tram_rails_straight, BUS)
from ground2 import tunnel, access_ramp
from buildings import Bld, STYLES, S, O, HGT, make_block, flat_roof, planks, pitched, brick, x_roof_terrace_flat
from buildings2 import reg_style, flat_roofs
from buildings3 import SHAPES
from details import att, wd

# ------------------------------------------------------------------ more shops

# kind -> (sign text, goods colours, ceiling light, awning colours or None, sign board colour);
# kinds are part of the tile names and of the facade seed name.
SHOP_KINDS = {
    "bakker": ("BAKKER", ["hout2", "hout3", "zand1", "terracotta1"], "licht_warm", ["luifel_geel", "luifel_wit"], "deur_rood"),
    "slager": ("SLAGER", ["bord_rood", "bloem_roze", "stuc1", "bord_rood2"], "licht_wit", ["luifel_rood", "luifel_wit"], "bord_rood2"),
    "bloemist": ("BLOEMEN", ["bloem_rood", "bloem_geel", "bloem_paars", "bloem_roze", "blad2", "bloem_wit"], "licht_warm", ["luifel_groen", "luifel_wit"], "deur_groen"),
    "boekhandel": ("BOEKEN", ["stof1", "stof2", "paneel_geel", "paneel_groen", "deur_blauw", "stof3"], "licht_warm", None, "deur_blauw"),
    "fietsenwinkel": ("FIETSEN", ["fiets_zwart", "fiets_rood", "fiets_blauw", "rubber"], "licht_wit", None, "bord_zwart"),
    "supermarkt": ("SUPER", ["bloem_oranje", "paneel_blauw", "bloem_geel", "bord_rood", "paneel_groen", "stuc1"], "licht_wit", None, "bord_blauw"),
    "drogist": ("DROGIST", ["bloem_roze", "stuc1", "paneel_blauw", "luifel_wit"], "licht_wit", None, "bord_groen"),
    "kapper": ("KAPPER", ["glas_helder", "bord_zwart", "rvs", "stuc1"], "licht_wit", None, "bord_zwart"),
    "ijssalon": ("IJS", ["bloem_roze", "bloesem2", "zand1", "luifel_geel", "bloem_wit"], "licht_warm", ["bloem_roze", "luifel_wit"], "bloem_roze"),
    "snackbar": ("SNACKS", ["bord_geel", "bloem_oranje", "rvs", "bord_rood"], "licht_wit", None, "bord_geel"),
    "juwelier": ("JUWELEN", ["goud", "messing", "bord_zwart", "rvs"], "licht_warm", None, "bord_zwart"),
    "dierenwinkel": ("DIEREN", ["hout2", "blad2", "paneel_groen", "zand1"], "licht_warm", ["luifel_groen", "luifel_geel"], "deur_groen"),
}

# styles that get a ground-floor variant of every shop kind
SHOP_STYLES = ("klassiek_rood", "klassiek_donker", "klassiek_geel", "modern_wit", "modern_donker", "modern_hout",
               "jaren30", "herenhuis_1900")


def shop(kind):
    """Return a facade function f(b, face) for a shop of SHOP_KINDS[kind]: the style's
    shopfront, shelves with goods behind the glass (depth 3), a lit ceiling and a name board."""
    text, goods, lit, awning, board = SHOP_KINDS[kind]

    def f(b, face):
        b.shopfront(face, text, awning)
        for u in range(3, 21):
            if u == 11:
                continue   # window mullion
            for z in range(3, 16):
                if z == 15:
                    c = lit
                elif z % 4 == 2:
                    c = "hout_donker1"   # shelf
                elif z < 14 and h(u, z, b.seed, 800) < 0.75:
                    c = pick(goods, u, z, b.seed, 801)
                else:
                    c = "interieur2"
                b.put(face, u, z, 3, c)
        b.sign(face, 1, 31, 17, 23, board, text, "goud" if kind in ("juwelier", "bakker") else "bord_wit")
    f.__name__ = "f_winkel_" + kind   # seed name; must stay
    return f


for _st in SHOP_STYLES:
    for _k in SHOP_KINDS:
        register(f"gebouwen/{_st}/{_st}_bg_{_k}", make_block(_st, [("v", shop(_k))]))


# ------------------------------------------------------------------ tunnel trough (open, sunken)

def trough(d, kind, wall):
    """Open tunnel trough d ground layers deep: a lane ('rijstrook'), bike path ('fietspad')
    or sidewalk tile at the bottom; `wall` adds a concrete retaining wall on the left (x=0..1)
    with a railing on top."""
    if kind == "rijstrook":
        base = lane("geen", "onderbroken")
    elif kind == "fietspad":
        base = bike_path_straight()
    else:
        base = sidewalk("")
    out = V(T, T, d * FLOOR + 10)
    out.paste(base, 0, 0, 0)
    if wall:
        top = d * FLOOR + WALK
        for y in range(T):
            for z in range(0, top):
                out.set(0, y, z, CONCRETE_DARK if z % 12 == 0 else CONCRETE)
                out.set(1, y, z, CONCRETE)
            out.set(0, y, top + 5, "metaal_donker")
            if y % 8 == 0:
                for z in range(top, top + 5):
                    out.set(0, y, z, "metaal_donker")
    return out


def _trough_fn(d, kind, wall, mirror=False):
    """Tile function for trough(d, kind, wall), optionally mirrored (wall on the right)."""
    if mirror:
        return lambda: trough(d, kind, wall).mirror_x()
    return lambda: trough(d, kind, wall)


for _d in range(1, 7):
    for _k in ("rijstrook", "fietspad", "stoep"):
        register(f"grond/tunnel/tunnelbak_{_k}_d{_d}", _trough_fn(_d, _k, False))
        register(f"grond/tunnel/tunnelbak_{_k}_wand_d{_d}", _trough_fn(_d, _k, True))
        register(f"grond/tunnel/tunnelbak_{_k}_wand_rechts_d{_d}", _trough_fn(_d, _k, True, mirror=True))


def tunnel_bike_beside(wall):
    """Tunnel tile (6 layers) with a bike path; to be placed next to car-tunnel tiles."""
    return tunnel(wall, bicycle=True)


register("grond/tunnel/tunnel_fietspad", lambda: tunnel_bike_beside(False))


# ------------------------------------------------------------------ tram with regular lane markings

def _tram_lane(left, right):
    """Tile function: lane(left, right) with tram rails laid in it."""
    def fn():
        m = lane(left, right)
        tram_rails_straight(m)
        return m
    return fn


for _l, _r in (("onderbroken", "kant"), ("geen", "kant"), ("streep", "kant"), ("onderbroken", "geen"), ("geen", "geen"), ("dubbel", "kant")):
    register(f"grond/tram/tram_rijstrook_{_l}_{_r}", _tram_lane(_l, _r))


@tile("grond/tram/trambaan_vrij")
def tram_track_separate():
    """Separate tram track: raised paved strip with curbs on both sides and grooved rails
    at x = 10/11 and 20/21."""
    m = new()
    for y in range(T):
        for x in range(T):
            if x in (0, 31):
                column(m, x, y, WALK, CURB, CURB)
            else:
                column(m, x, y, WALK, paver_fn)
    for y in range(T):
        for r in (10, 21):
            m.set(r, y, WALK - 1, "rail_glim")
            m.set(r + (1 if r == 10 else -1), y, WALK - 1, "railgroef")
    return m


@tile("grond/tram/trambaan_vrij_gras")
def tram_track_separate_grass():
    """Separate tram track with grass between and beside the rails."""
    m = tram_track_separate()
    for y in range(T):
        for x in range(1, 31):
            if x not in (10, 11, 20, 21):
                m.set(x, y, WALK - 1, pick(["gras1", "gras2", "gras4"], x, y, 0, 802))
    return m


@tile("grond/tram/tramhalte_middenperron")
def tram_stop_island():
    """Island platform between two tram tracks: curbs on both sides, edge line and tactile guide strips."""
    m = V(T, T, 10)
    for y in range(T):
        for x in range(T):
            column(m, x, y, 5, PAVING, CONCRETE_DARK)
    for y in range(T):
        for x in (0, 31):
            column(m, x, y, 5, CURB, CURB)
        for x in (2, 29):
            paint(m, x, y, P["markering"])
        for x in (4, 27):
            paint(m, x, y, P["ribbel"])
    return m


# ------------------------------------------------------------------ medians

register("grond/weg/middenberm_gras", lambda: sidewalk("lr", surface=GRASS))
register("grond/weg/middenberm_gras_kop", lambda: sidewalk("lra", surface=GRASS))
register("grond/weg/middenberm_klinkers", lambda: sidewalk("lr", surface=paver_fn))


@tile("grond/weg/rijstrook_bus_leeg")
def lane_bus_empty():
    """Bus lane surface without the BUS text."""
    return lane("streep", "kant", BUS)


# ------------------------------------------------------------------ luxury apartments with roof terrace and penthouse

STYLES["luxe_appartement"] = dict(family="luxe", wall=blocky(["natuursteen1", "stuc1", "natuursteen2"], size=4, seed=803),
                                  frame="antraciet3", doors=["antraciet3"], plinth="antraciet3", trim="goud",
                                  roof=("dakgrind1", "dakgrind2"), glass="glas2", shop="antraciet3", cap="antraciet3",
                                  accent=planks(["hout1", "hout2", "hout3"], 804))


# Facade functions f(b, face); face = v/r/a/l (front/right/back/left), u along the facade,
# d = depth (negative = in front of the wall).

def lx_lobby(b, face):
    """Ground floor lobby: full-height glass with dark frame, wood-panelled back wall,
    warm lights, a canopy and a gold 'LUXE' sign."""
    b.rect(face, 0, S, 0, 24, 0, 3, 0)
    for z in range(0, 24):
        for u in range(S):
            edge = u in (0, 31) or u % 8 == 0 or z in (0, 23)
            b.put(face, u, z, 1, "antraciet3" if edge else "glas_helder")
    b.rect(face, 1, 31, 0, 23, 3, 4, "hout1")
    for u in range(4, 28, 6):
        b.put(face, u, 18, 3, "licht_warm")
    b.rect(face, 4, 28, 18, 20, -7, 0, "antraciet3")
    b.sign(face, 10, 22, 20, 24, "antraciet3", "LUXE", "goud")


def lx_terrace(b, face):
    """Upper floor with an 8-voxel deep balcony terrace (glass balustrade, planters)
    in front of a large window."""
    b.rect(face, 0, S, 0, 2, -8, 0, "stuc1")
    for u in range(S):
        for z in range(2, 9):
            b.put(face, u, z, -8, "glas_helder")
        b.put(face, u, 9, -8, "rvs")
    for u0 in (2, 26):
        b.rect(face, u0, u0 + 4, 2, 5, -7, -3, "antraciet2")
        b.rect(face, u0, u0 + 4, 5, 8, -7, -3, "blad2")
    b.window(face, 1, 2, 30, 20, sill=False, lintel=False)
    for z in range(2, 22):
        for u in (11, 21):
            b.put(face, u, z, 1, "antraciet3")


def lx_glass(b, face):
    """Glass facade with dark mullions every 8 voxels and a slim floor ledge."""
    b.window(face, 1, 1, 30, 22, sill=False, lintel=False)
    b.rect(face, 0, S, 0, 1, -2, 1, "stuc1")
    for z in range(1, 23):
        for u in (8, 16, 24):
            b.put(face, u, z, 1, "antraciet3")


def penthouse(edges):
    """Tile function for a penthouse storey: a glass volume set back 8 voxels from each
    facade in `edges` (letters v/r/a/l), wooden terrace deck, overhanging roof and glass
    balustrades along those edges."""
    def fn():
        b = Bld("luxe_appartement", "penthouse" + edges, HGT)
        m = b.m
        inset = {f: (8 if f in edges else 0) for f in "vral"}
        x0, x1 = O + inset["l"], O + S - inset["r"]
        y0, y1 = O + inset["v"], O + S - inset["a"]
        for ly in range(S):
            for lx in range(S):
                m.set(O + lx, O + ly, 0, pick(["hout1", "hout2", "hout3"], lx // 4, ly, 0, 805))
        m.box(x0, y0, 1, x1, y1, 21, "glas2")
        m.box(x0 + 1, y0 + 1, 1, x1 - 1, y1 - 1, 21, "interieur2")
        for z in range(1, 21):
            for x in range(x0, x1, 8):
                m.set(x, y0, z, "antraciet3")
                m.set(x, y1 - 1, z, "antraciet3")
        # roof slab, overhanging 2 voxels past the facade on the terrace sides
        m.box(O - 2 if "l" in edges else x0, O - 2 if "v" in edges else y0, 21,
              O + S + 2 if "r" in edges else x1, O + S + 2 if "a" in edges else y1, 23, "antraciet3")
        for f in edges:
            for u in range(S):
                for z in range(1, 8):
                    b.put(f, u, z, 0, "glas_helder")
                b.put(f, u, 8, 0, "rvs")
        # planter with a shrub in the front-left corner
        m.box(O + 2, O + 2, 1, O + 6, O + 6, 4, "antraciet2")
        m.ellipsoid(O + 4, O + 4, 6, 2.5, 2.5, 2.5, mix("blad1", "blad2", "blad4", seed=806))
        return m
    return fn


def x_roof_pool(b):
    """Roof extra for flat_roof: wooden deck with a sunken pool and three sun loungers."""
    m = b.m
    for ly in range(2, 30):
        for lx in range(2, 30):
            m.set(O + lx, O + ly, 1, pick(["hout1", "hout2", "hout3"], lx // 4, ly, 0, 807))
    for ly in range(6, 26):
        for lx in range(6, 22):
            edge = lx in (6, 21) or ly in (6, 25)
            # 25 cm tiled rim around the sunken water
            m.set(O + lx, O + ly, 1, "tegel_wit" if edge else "water_zwembad")
            m.set(O + lx, O + ly, 2, "tegel_wit" if edge else 0)
            m.set(O + lx, O + ly, 3, "tegel_wit" if edge else 0)
    for ly in (8, 14, 20):
        for lx in range(24, 28):
            m.set(O + lx, O + ly, 2, "bord_wit")
            m.set(O + lx, O + ly + 1, 2, "bord_wit")


reg_style("luxe_appartement",
          {"bg_lobby": lx_lobby, "bg_glas": lx_glass, "verd_terras": lx_terrace, "verd_glas": lx_glass},
          [("bg_glas_hoek", "bg_glas", "bg_glas"), ("verd_terras_hoek", "verd_terras", "verd_terras"),
           ("verd_glas_hoek", "verd_glas", "verd_glas"), ("bg_lobby_hoek", "bg_lobby", "bg_glas")],
          dict(flat_roofs("luxe_appartement"),
               dak_terras=flat_roof("luxe_appartement", "v", x_roof_terrace_flat),
               dak_zwembad=flat_roof("luxe_appartement", "v", x_roof_pool),
               penthouse_rand=penthouse("v"), penthouse_hoek=penthouse("vr"), penthouse_tegenover=penthouse("va"),
               penthouse_midden=penthouse("")))


# ------------------------------------------------------------------ extra tunnel variants (bike trough next to car trough)

register("grond/tunnel/tunnel_fiets_wand_rechts", lambda: tunnel(True, bicycle=True).mirror_x())
register("grond/tunnel/tunnel_fiets_wand_rechts_portaal", lambda: tunnel(True, bicycle=True, portal=True).mirror_x())
for _d in range(1, 7):
    register(f"grond/tunnel/fietstunnel_toerit_wand_rechts_d{_d}", (lambda d: lambda: access_ramp(d, True, True).mirror_x())(_d))


# ------------------------------------------------------------------ classic streetlights

def _lantern_head(m, cx, cy, z, green="amsterdamgroen"):
    """Classic lantern: 5x5x5 lamp box (corner posts in `green`, warm glass between) at
    (cx, cy) from height z, topped by a two-step cap."""
    for zz in range(z, z + 5):
        for y in range(int(cy) - 2, int(cy) + 3):
            for x in range(int(cx) - 2, int(cx) + 3):
                edge = abs(x - cx) >= 1.5 or abs(y - cy) >= 1.5
                corner = abs(x - cx) >= 1.5 and abs(y - cy) >= 1.5
                if edge:
                    m.set(x, y, zz, green if corner else "lamp_warm")
    for zz in (z + 5, z + 6):
        m.cyl(cx + 0.5, cy + 0.5, 3 - (zz - z - 5) * 1.5, zz, zz + 1, green)


@tile("props/verlichting/lantaarn_klassiek_dubbel")
def streetlight_classic_double():
    """Amsterdam-green classic streetlight with a cross arm and two hanging lanterns."""
    m = V(24, 8, 44)
    g = "amsterdamgroen"
    m.box(9, 2, 0, 15, 6, 3, g)
    for z in range(3, 34):
        m.cyl(12, 4, 1.2, z, z + 1, g)
    for x in range(3, 21):
        m.set(x, 4, 34, g)
        m.set(x, 3, 34, g)
    for cx in (4, 19):
        for z in range(31, 34):
            m.set(cx, 4, z, g)
        _lantern_head(m, cx, 4, 26)
    return m


@tile("props/verlichting/lantaarn_gietijzer")
def streetlight_cast_iron():
    """Black cast-iron streetlight with a curved arm and a hanging lantern."""
    m = V(24, 6, 40)
    c = "bord_zwart"
    m.box(10, 1, 0, 14, 5, 3, c)
    for z in range(3, 34):
        m.cyl(12, 3, 1.0 if z > 6 else 1.5, z, z + 1, c)
    # half-arch arm from the mast to x = 24
    for t in range(0, 20):
        a = t / 19 * math.pi
        x = 12 + 6 * (1 - math.cos(a))
        z = 33 + 3 * math.sin(a)
        m.set(x, 3, z, c)
    for z in range(30, 34):
        m.set(22, 3, z, c)
    _lantern_head(m, 22, 3, 24, c)
    return m


@tile("props/verlichting/lantaarn_bol")
def streetlight_globe():
    """Low park light with a glowing globe."""
    m = V(8, 8, 36)
    for z in range(0, 28):
        m.cyl(4, 4, 1.0 if z > 3 else 2.0, z, z + 1, "antraciet1")
    m.ellipsoid(4, 4, 31, 3.4, 3.4, 3.6, "lamp_warm")
    m.cyl(4, 4, 1.5, 34, 35, "antraciet1")
    return m


@tile("props/verlichting/lantaarn_wand_klassiek")
def streetlight_wall_classic():
    """Classic wall lantern (details.att canvas): bracket and a black-framed lamp box."""
    m = att(6, 6, 12)
    for d in range(0, 5):
        m.set(3, wd(m, d), 9, "bord_zwart")
    for z in range(2, 8):
        for d in range(3, 6):
            for x in range(2, 5):
                edge = x in (2, 4) and d in (3, 5)
                m.set(x, wd(m, d), z, "bord_zwart" if edge or z in (2, 7) else "lamp_warm")
    return m


# ------------------------------------------------------------------ terrace: tables and parasols

_LEGS4 = ((0, 0), (2, 0), (0, 2), (2, 2))


def table(shape, chairs):
    """Café table, round ('rond', wood) or square ('vierkant', white), optionally with four
    chairs whose backrests face away from the table."""
    m = V(16, 16, 8)
    c = 8
    for z in range(0, 5):
        m.set(c, c, z, "metaal_donker")
    if shape == "rond":
        m.cyl(c, c, 3.2, 5, 6, "hout_bank1")
    else:
        m.box(c - 3, c - 3, 5, c + 3, c + 3, 6, "stuc1")
    if chairs:
        for (dx, dy) in ((0, -6), (0, 5), (-6, 0), (5, 0)):
            x, y = c + dx - 1, c + dy - 1
            for z in range(0, 3):
                for (a, b_) in _LEGS4:
                    m.set(x + a, y + b_, z, "metaal_donker")
            m.box(x, y, 3, x + 3, y + 3, 4, "hout_bank2")
            # backrest on the side away from the table
            bx = (x, x + 3) if dx == 0 else ((x, x + 1) if dx < 0 else (x + 2, x + 3))
            by = ((y, y + 1) if dy < 0 else (y + 2, y + 3)) if dx == 0 else (y, y + 3)
            m.box(bx[0], by[0], 4, bx[1], by[1], 7, "metaal_donker")
    return m


for _v in ("rond", "vierkant"):
    register(f"props/terras/tafel_{_v}", (lambda v: lambda: table(v, False))(_v))
    register(f"props/terras/tafel_{_v}_stoelen", (lambda v: lambda: table(v, True))(_v))


@tile("props/terras/bistrostoel")
def bistro_chair():
    """Single bistro chair (4x4) with a backrest at the back."""
    m = V(4, 4, 7)
    for z in range(0, 3):
        for (a, b_) in ((0, 0), (3, 0), (0, 3), (3, 3)):
            m.set(a, b_, z, "metaal_donker")
    m.box(0, 0, 3, 4, 4, 4, "hout_bank2")
    m.box(0, 3, 4, 4, 4, 7, "metaal_donker")
    return m


def parasol(colors, square=False, r=11):
    """Café parasol of radius r on a concrete foot; the canopy cycles through `colors` in
    8 segments. Square canopies use the Chebyshev distance; round ones get a scalloped valance."""
    size = int(r * 2 + 2)
    size += size % 2
    m = V(size, size, 22)
    c = size / 2
    for z in range(0, 18):
        m.set(c, c, z, "hout2")
    m.box(int(c) - 2, int(c) - 2, 0, int(c) + 2, int(c) + 2, 1, "beton2")
    for z in range(14, 19):
        rr = r - (z - 14) * (r / 4.5)
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                d = max(abs(dx), abs(dy)) if square else math.hypot(dx, dy)
                if rr - 1.6 < d <= rr:
                    a = math.atan2(dy, dx)
                    m.set(x, y, z, colors[int((a + 4) * 4 / math.pi) % len(colors)])
    if not square:
        for x in range(size):
            for y in range(size):
                d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                if r - 1 < d <= r and (x + y) % 2 == 0:
                    m.set(x, y, 13, colors[0])
    return m


register("props/terras/parasol_rood", lambda: parasol(["luifel_rood", "luifel_wit"]))
register("props/terras/parasol_groen", lambda: parasol(["luifel_groen"]))
register("props/terras/parasol_blauw", lambda: parasol(["luifel_blauw", "luifel_wit"]))
register("props/terras/parasol_naturel", lambda: parasol(["luifel_wit"]))
register("props/terras/parasol_vierkant", lambda: parasol(["antraciet2"], True))
register("props/terras/parasol_groot", lambda: parasol(["luifel_wit", "stuc2"], True, 15))


# ------------------------------------------------------------------ statues

def socle(m, cx, cy, w, hgt, mat="natuursteen2"):
    """Square pedestal of half-width w and height hgt centred on (cx, cy); the bottom and
    top courses are one voxel wider and made of natuursteen1."""
    for z in range(hgt):
        ww = w + (1 if z in (0, hgt - 1) else 0)
        m.box(int(cx - ww), int(cy - ww), z, int(cx + ww), int(cy + ww), z + 1, mat if z not in (0, hgt - 1) else "natuursteen1")


def figure(m, cx, cy, z0, scale=1.0, mat="brons_patina"):
    """Standing human figure (~17 voxels at scale 1) built from ellipsoids, feet at z0."""
    s = scale

    def e(x, y, z, rx, ry, rz):
        m.ellipsoid(cx + x * s, cy + y * s, z0 + z * s, rx * s, ry * s, rz * s, mat)
    e(-1.2, 0, 4, 1.1, 1.1, 4.2)    # legs
    e(1.2, 0, 4, 1.1, 1.1, 4.2)
    e(0, 0, 10.5, 2.6, 1.8, 3.6)    # torso
    e(-3.0, 0, 11, 0.9, 0.9, 3.0)   # arms (right one raised slightly forward)
    e(3.2, -1.2, 13, 0.9, 0.9, 3.0)
    e(0, 0, 15.5, 1.5, 1.5, 1.7)    # head


@tile("props/standbeelden/standbeeld_persoon")
def statue_person():
    """Bronze statue of a person on a stone pedestal."""
    m = V(14, 14, 34)
    socle(m, 7, 7, 4, 12)
    figure(m, 7, 7, 12, 1.2)
    return m


@tile("props/standbeelden/ruiterstandbeeld")
def equestrian_statue():
    """Equestrian statue: horse (facing +x) with rider on a stone pedestal."""
    m = V(28, 16, 44)
    socle(m, 14, 8, 6, 12)
    b = "brons_patina"
    m.ellipsoid(14, 8, 21, 8, 3, 3.5, b)                      # horse body
    for (x, y) in ((8.5, 6.5), (8.5, 9.5), (19.5, 6.5), (19.5, 9.5)):
        m.line((x, y, 12), (x + (1 if x < 14 else -1), y, 19), b, 0.9)
    m.line((21, 8, 22), (24, 8, 28), b, 1.4)                   # neck
    m.ellipsoid(24.5, 8, 29, 2.2, 1.4, 1.6, b)                # head
    m.line((6, 8, 22), (4, 8, 16), b, 0.8)                     # tail
    figure(m, 14, 8, 21, 0.8)
    return m


@tile("props/standbeelden/buste")
def bust():
    """Bronze bust on a marble pedestal."""
    m = V(8, 8, 18)
    socle(m, 4, 4, 2, 10, "marmer")
    m.ellipsoid(4, 4, 12, 3, 2, 2, "brons")
    m.ellipsoid(4, 4, 15.5, 1.6, 1.6, 2, "brons")
    return m


def _square_layer(m, c, hw, z, mat):
    """One horizontal square layer of half-width hw centred on (c, c) at height z."""
    m.box(int(c - hw), int(c - hw), z, int(c + hw + 0.5), int(c + hw + 0.5), z + 1, mat)


@tile("props/standbeelden/obelisk")
def obelisk():
    """7.5 m stone obelisk, slightly tapering, with a gold pyramidion."""
    m = V(12, 12, 60)
    socle(m, 6, 6, 4, 6)
    for z in range(6, 56):
        _square_layer(m, 6, 2.6 - (z - 6) * 0.025, z, "natuursteen1")
    for z in range(56, 60):
        _square_layer(m, 6, (60 - z) * 0.5, z, "goud")
    return m


@tile("props/standbeelden/kunstwerk_modern")
def artwork_modern():
    """Modern art: a stainless-steel helix (1.5 turns) on a concrete base."""
    m = V(20, 20, 40)
    m.box(4, 4, 0, 16, 16, 2, "beton1")
    for t in range(0, 120):
        a = t / 120 * math.tau * 1.5
        x = 10 + math.cos(a) * 5
        y = 10 + math.sin(a) * 5
        z = 2 + t * 0.3
        m.line((x, y, z), (x, y, z + 1), "rvs", 1.2)
    return m


@tile("props/standbeelden/fontein_beeld")
def fountain_statue():
    """Round fountain basin (4 m) with a bronze statue on a pedestal in the middle."""
    m = V(32, 32, 30)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - 16, y + 0.5 - 16)
            if d < 16:
                m.set(x, y, 0, "natuursteen2")
                if d > 14.5:
                    for z in range(1, 4):
                        m.set(x, y, z, "natuursteen1")
                else:
                    m.set(x, y, 1, "water1")
                    m.set(x, y, 2, "water3")
    socle(m, 16, 16, 3, 9)
    figure(m, 16, 16, 9, 1.0, "brons")
    return m


# ------------------------------------------------------------------ green roofs (sedum)

SEDUM = ("sedum1", "sedum3", "sedum2", "sedum1", "sedum4")

# styles that get green flat-roof variants (midden/rand/hoek)
GREEN_ROOF_STYLES = ("modern_wit", "modern_donker", "modern_hout", "kantoor_glas", "kantoor_beton", "jaren60", "galerijflat",
                     "appartement_modern", "kantoor_80", "kantoor_2000", "kantoor_modern", "school", "jaren30", "luxe_appartement",
                     "bedrijfspand", "museum_modern")


def x_sedum(b):
    """Roof extra: scattered sedum, grass and flower tufts on the roof deck."""
    m = b.m
    for ly in range(2, 30):
        for lx in range(2, 30):
            if h(lx, ly, 0, 810) < 0.12:
                m.set(O + lx, O + ly, 1, pick(["sedum1", "gras4", "bloem_geel", "bloem_paars"], lx, ly, 1, 811))


def green_roof(st, edges, extra=True):
    """Tile function: style st's flat roof with a sedum deck (and tufts when `extra`).

    STYLES[st]["roof_deck"] is temporarily replaced by SEDUM while the roof is built and
    restored afterwards.
    """
    def fn():
        orig = STYLES[st].get("roof_deck")
        STYLES[st]["roof_deck"] = SEDUM
        try:
            return flat_roof(st, edges, x_sedum if extra else None)()
        finally:
            if orig is None:
                STYLES[st].pop("roof_deck", None)
            else:
                STYLES[st]["roof_deck"] = orig
    return fn


for _st in GREEN_ROOF_STYLES:
    for _e, _n in (("", "midden"), ("v", "rand"), ("vr", "hoek")):
        register(f"gebouwen/{_st}/{_st}_dak_groen_{_n}", green_roof(_st, _e))

# separate pitched sedum roofs (all roof shapes from buildings3.SHAPES listed below)
STYLES["dak_sedum"] = dict(family="dak", wall=brick(["baksteen1", "baksteen2", "baksteen3"], 812), frame="kozijn_wit",
                           doors=["deur_groen"], plinth="natuursteen2", trim="natuursteen1", roof=SEDUM, glass="glas1",
                           shop="kozijn_wit", cap="zink1")
for _shape in ("schuin", "schuin_hoek_buiten", "schuin_hoek_binnen", "zadel", "zadel_schild", "zadel_hoek", "lessenaar", "schuin_afgeplat"):
    register(f"gebouwen/daken/sedum/sedum_{_shape}", pitched("dak_sedum", "sedum" + _shape, SHAPES[_shape]))
