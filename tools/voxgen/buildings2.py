"""Building extension set: 1930s upper-floor houses, 1960s houses and gallery flats, modern
apartments, townhouses (1600 / 1900), shops and hospitality, offices (80s / 2000s / modern),
museums, churches, schools, government buildings, barns, hollow halls / canopies and pillars.

This module builds on buildings.py: it adds its styles to the shared STYLES dict, defines facade
pieces with the signature ``f(b, face)`` (b = buildings.Bld, face = "v"/"r"/"a"/"l" for
front/right/back/left), roof / top tiles as zero-argument factories returning a V model, and
registers everything under ``gebouwen/<style>/<style>_<name>`` at import time (generate.py imports
this module so the tiles end up in common.TILES).

Facade coordinates (see buildings.fp): u runs 0..31 along the face, z is up (one storey = 24
voxels of 12.5 cm), d is depth into the building (d < 0 sticks out in front of the facade).

NOTE: the ``__name__`` of every facade function (and lambda) feeds the building RNG seed via
buildings.seed_name / LEGACY_SEED_NAMES, so facade functions must not be renamed.
"""
import math

from common import register, text_pixels
from palette import P
from vox import V, mix, pick, blocky
from buildings import (Bld, STYLES, S, O, W, HGT, brick, planks, panels, make_block, pitched, flat_roof,
                       gable_top, H_SLOPE, H_CORNER_OUT, H_CORNER_IN, H_GABLE, H_GABLE_HIP, H_GABLE_CORNER,
                       x_dormer, x_chimney, x_hvac, x_solar_panels, x_roof_terrace_flat,
                       f_office_curtain_wall, f_office_band, f_office_gf_entrance, f_office_gf_glass, f_gf_shop,
                       f_gf_shop_awning, roof_colors)

STONE_BLOCKS = blocky(["natuursteen1", "natuursteen2", "natuursteen3"], size=3, seed=200)
GREY_STONE = blocky(["beton1", "beton3", "natuursteen3", "beton2"], size=3, seed=201)


def _bond(names, x, y, z, salt, weights=None):
    """Running-bond brick colour: 3-voxel bricks, rows offset by 2 voxels on odd z."""
    return pick(names, (x + y + (z % 2) * 2) // 3, z, 0, salt, weights)


# Wall colour functions (x, y, z) -> palette index, used as the style's "wall".

def wall_flat60(x, y, z):
    """1960s yellow brick with concrete bands at the floor and every 16 voxels."""
    if (x + y) % 16 == 0 or z in (0, 1):
        return P["beton60"]
    return _bond(["geelsteen60_1", "geelsteen60_2"], x, y, z, 202)


def wall_1900(x, y, z):
    """Red brick with stucco bands (plinth, mid-storey and top)."""
    if z in (0, 1, 13, 22, 23):
        return pick(["stuc1", "stuc2"], x + y, z, 0, 203)
    return _bond(["baksteen1", "baksteen3", "baksteen5"], x, y, z, 204)


def wall_gov(x, y, z):
    """Dark brick with natural-stone bands (government buildings)."""
    if z in (0, 1, 2, 12, 23):
        return pick(["natuursteen1", "natuursteen2"], (x + y) // 4, z, 0, 205)
    return _bond(["donkersteen1", "baksteen4", "donkersteen3"], x, y, z, 206)


def wall_school(x, y, z):
    """Mixed red/yellow brick on a concrete plinth (schools)."""
    if z in (0, 1):
        return P["beton60"]
    return _bond(["baksteen5", "geelsteen1", "baksteen3"], x, y, z, 207, [3, 2, 2])


def wall_museum_m(x, y, z):
    """Large stucco panels with darker seams (modern museum)."""
    u = x + y
    if u % 16 == 0 or z == 0:
        return P["stuc3"]
    return pick(["stuc1", "stuc2"], u // 16, z // 12, 0, 208)


NEW_STYLES = {
    "jaren30": dict(family="jaren30", wall=brick(["baksteen30_1", "baksteen30_2", "baksteen30_3"], 210, (3, 3, 2)),
                    frame="kozijn_creme", doors=["deur_groen", "deur_rood", "hout_donker1"], plinth="donkersteen2",
                    trim="natuursteen2", roof=("pan_zwart1", "pan_zwart2", "pan_zwart3"), roof_deck=("bitumen1", "bitumen2"),
                    glass="glas1", shop="hout_donker1", shutter="kozijn_groen", cap="zink1"),
    "jaren60": dict(family="jaren60", wall=brick(["geelsteen60_1", "geelsteen60_2"], 211, (3, 2)),
                    frame="kozijn_wit", doors=["paneel_blauw", "paneel_geel", "paneel_rood", "paneel_groen"],
                    plinth="beton60", trim="beton60", roof=("pan_zwart1", "pan_zwart2", "pan_zwart3"),
                    roof_deck=("dakgrind1", "dakgrind2"), glass="glas2", shop="kozijn_wit", cap="kozijn_wit",
                    fascia="kozijn_wit", panels=["paneel_blauw", "paneel_geel", "paneel_rood", "paneel_groen"]),
    "galerijflat": dict(family="flat", wall=wall_flat60, frame="kozijn_wit", doors=["paneel_blauw", "paneel_geel", "paneel_rood"],
                        plinth="beton60", trim="beton60", roof=("dakgrind1", "dakgrind2"), glass="glas2", shop="kozijn_wit",
                        cap="beton60", panels=["paneel_blauw", "paneel_geel", "paneel_rood", "paneel_groen"]),
    "appartement_modern": dict(family="appmodern", wall=mix("stuc1", "paneel3", "stuc2", seed=212, weights=[4, 1, 2]),
                               frame="antraciet1", doors=["antraciet2"], plinth="antraciet2", trim="antraciet1",
                               roof=("dakgrind1", "dakgrind2"), glass="glas2", shop="antraciet1", cap="alu", accent=planks(["hout1", "hout2", "hout3"], 213)),
    "herenhuis_1600": dict(family="heren1600", wall=STONE_BLOCKS, frame="kozijn_wit", doors=["deur_groen", "deur_zwart"],
                           plinth="natuursteen3", trim="natuursteen1", roof=("leisteen1", "leisteen2", "leisteen1"),
                           roof_deck=("zink1", "zink2"), glass="glas1", shop="kozijn_groen", shutter="kozijn_groen", cap="natuursteen1"),
    "herenhuis_1900": dict(family="heren1900", wall=wall_1900, frame="kozijn_wit", doors=["deur_rood", "deur_groen", "hout_donker1"],
                           plinth="natuursteen3", trim="stuc1", roof=("pan_zwart1", "pan_zwart2", "leisteen1"),
                           roof_deck=("zink1", "zink2"), glass="glas1", shop="kozijn_groen", shutter="kozijn_groen", cap="zink1"),
    "kantoor_80": dict(family="kantoor", wall=panels(["bruin80_1", "bruin80_2"], 214, "antraciet3", 8), frame="antraciet3", doors=["antraciet3"],
                       plinth="bruin80_1", trim="antraciet3", roof=("bitumen1", "bitumen2"), glass="glas_brons", shop="antraciet3", cap="antraciet1"),
    "kantoor_2000": dict(family="kantoor", wall=panels(["paneel3", "paneel1"], 215, "alu", 16), frame="alu", doors=["alu"],
                         plinth="antraciet1", trim="alu", roof=("bitumen1", "bitumen2"), glass="glas_blauw", shop="alu", cap="alu"),
    "kantoor_modern": dict(family="kantoor", wall=mix("stuc1", "paneel3", seed=216, weights=[5, 1]), frame="stuc1", doors=["antraciet1"],
                           plinth="antraciet1", trim="stuc1", roof=("dakgrind1", "dakgrind2"), glass="glas_groen", shop="stuc1", cap="stuc1",
                           accent=planks(["hout1", "hout2", "hout3"], 217)),
    "museum_klassiek": dict(family="museum_k", wall=STONE_BLOCKS, frame="kozijn_creme", doors=["hout_donker1"], plinth="natuursteen3",
                            trim="natuursteen1", roof=("koper", "koper", "leisteen1"), roof_deck=("zink1", "zink2"), glass="glas1",
                            shop="hout_donker1", cap="natuursteen1"),
    "museum_modern": dict(family="museum_m", wall=wall_museum_m, frame="antraciet1", doors=["antraciet1"], plinth="antraciet2",
                          trim="antraciet1", roof=("dakgrind1", "dakgrind2"), glass="glas2", shop="antraciet1", cap="stuc1"),
    "kerk_baksteen": dict(family="kerk", wall=brick(["baksteen2", "baksteen4", "donkersteen1", "baksteen1"], 218, (3, 3, 1, 2)),
                          frame="natuursteen2", doors=["hout_donker2"], plinth="natuursteen3", trim="natuursteen2",
                          roof=("leisteen1", "leisteen2", "leisteen1"), roof_deck=("zink1",), glass="glas_lood_blauw", shop="hout_donker2", cap="natuursteen2"),
    "kerk_steen": dict(family="kerk", wall=GREY_STONE, frame="natuursteen1", doors=["hout_donker2"], plinth="natuursteen3",
                       trim="natuursteen1", roof=("leisteen2", "leisteen1", "koper"), roof_deck=("zink1",), glass="glas_lood_rood",
                       shop="hout_donker2", cap="natuursteen1"),
    "kerk_modern": dict(family="kerk_modern", wall=brick(["geelsteen60_1", "geelsteen60_2", "geelsteen2"], 219, (3, 2, 1)),
                        frame="antraciet1", doors=["hout2"], plinth="beton60", trim="beton60", roof=("zink1", "zink2"),
                        roof_deck=("dakgrind1", "dakgrind2"), glass="glas_lood_geel", shop="antraciet1", cap="beton60"),
    "school": dict(family="school", wall=wall_school, frame="kozijn_zwart", doors=["paneel_groen"], plinth="beton60",
                   trim="beton60", roof=("dakgrind1", "dakgrind2"), glass="glas1", shop="kozijn_zwart", cap="zink1"),
    "overheid": dict(family="overheid", wall=wall_gov, frame="kozijn_wit", doors=["hout_donker1"], plinth="natuursteen3",
                     trim="natuursteen1", roof=("leisteen1", "leisteen2", "leisteen1"), roof_deck=("zink1", "zink2"), glass="glas1",
                     shop="kozijn_wit", cap="natuursteen1"),
    "schuur_zwart": dict(family="schuur", wall=planks(["schuur_zwart", "schuur_zwart", "antraciet3"], 220), frame="kozijn_wit",
                         doors=["schuur_zwart"], plinth="baksteen4", trim="kozijn_wit", roof=("riet_dak1", "riet_dak2", "riet_dak1"),
                         glass="glas2", shop="kozijn_wit", cap="zink1"),
    "schuur_rood": dict(family="schuur", wall=planks(["schuur_rood", "baksteen4", "schuur_rood"], 221), frame="kozijn_wit",
                        doors=["kozijn_groen"], plinth="baksteen4", trim="kozijn_wit", roof=("pan_rood1", "pan_rood2", "pan_rood3"),
                        glass="glas2", shop="kozijn_wit", cap="zink1"),
}
STYLES.update(NEW_STYLES)


# ------------------------------------------------------------------ helpers

def _mullions(b, face, us, z0, z1, d=1, c=None):
    """Vertical frame bars at each u in `us` from z0 to z1 (exclusive), at depth d."""
    c = c or b.st["frame"]
    for u in us:
        for z in range(z0, z1):
            b.put(face, u, z, d, c)


def _transom(b, face, u0, u1, z, d=1, c=None):
    """Horizontal frame bar from u0 to u1 (exclusive) at height z, depth d."""
    c = c or b.st["frame"]
    for u in range(u0, u1):
        b.put(face, u, z, d, c)


def _leaded(b, face, u0, w, zt, d=2, salt=234):
    """Two rows (zt, zt+1) of coloured leaded glass above a window of width w starting at u0."""
    for u in range(u0 + 1, u0 + w - 1):
        for z in (zt, zt + 1):
            b.put(face, u, z, d, pick(["glas_lood_geel", "glas_lood_rood", "glas_lood_blauw"], u, z, b.seed, salt))


def _balustrade(b, face, u0, u1, rail, baluster):
    """Small stone balcony 4 voxels deep: slab (z 0-1), balusters on even u, top rail at z=7."""
    b.rect(face, u0, u1, 0, 2, -4, 0, rail)
    for u in range(u0, u1):
        b.put(face, u, 7, -4, rail)
        if u % 2 == 0:
            for z in range(2, 7):
                b.put(face, u, z, -4, baluster)


def _storage_door(b, face, u0, w, c):
    """Storage/garage door: 2-voxel recess, 16 high, panel colour c, handle at u0+w-2."""
    b.rect(face, u0, u0 + w, 0, 16, 0, 2, 0)
    b.rect(face, u0, u0 + w, 0, 16, 1, 2, c)
    b.put(face, u0 + w - 2, 8, 0, "rvs")


def _glass_wall(b, face, z0, z1, c0, c1):
    """Fill the face for z0..z1 with c0(u, z) at d=0 and c1(u, z) at d=1."""
    for z in range(z0, z1):
        for u in range(S):
            b.put(face, u, z, 0, c0(u, z))
            b.put(face, u, z, 1, c1(u, z))


def lancet(b, face, u0, w, z0, z_spring, z_top, d0=0, glass=None, frame=None, kind="spits"):
    """Pointed (kind="spits") or round (kind="rond") arched window.

    u0/w: left edge and width along the face; straight jambs from z0 up to z_spring, arch above
    it up to z_top. The opening is cut 2 deep from d0, glazed at d0+2 (lead bars every 3rd column
    and 4th row; random stained glass unless `glass` is given) with a lit interior at d0+3.
    A 1-voxel ring in `frame` (default: style trim) surrounds it.
    """
    fr = frame or b.st["trim"]
    cu = u0 + w / 2.0
    for z in range(z0, z_top + 1):
        for u in range(u0 - 1, u0 + w + 1):
            uc = u + 0.5
            if z < z_spring:
                inside = u0 <= u < u0 + w
                ring = u in (u0 - 1, u0 + w)
            else:
                zz = z + 0.5 - z_spring
                if kind == "spits":
                    # Gothic arch: intersection of two circles of radius w centred on the jambs.
                    r = w
                    d1 = math.hypot(uc - u0, zz)
                    d2 = math.hypot(uc - (u0 + w), zz)
                    inside = d1 <= r and d2 <= r and u0 <= u < u0 + w
                    ring = (d1 <= r + 1 and d2 <= r + 1) and not inside and u0 - 1 <= u <= u0 + w
                else:
                    r = w / 2.0
                    d = math.hypot(uc - cu, zz)
                    inside = d <= r
                    ring = r < d <= r + 1.2
            if inside:
                b.put(face, u, z, d0, 0)
                b.put(face, u, z, d0 + 1, 0)
                gc = glass or pick(["glas_lood_blauw", "glas_lood_rood", "glas_lood_geel", "glas_lood_blauw"], u, z, b.seed, 230)
                if (u - u0) % 3 == 2 or z % 4 == 0:
                    gc = "metaal_donker"
                b.put(face, u, z, d0 + 2, gc)
                b.put(face, u, z, d0 + 3, "interieur1" if (u + z) % 3 else "licht_warm")
            elif ring:
                b.put(face, u, z, d0, fr)


def _round_arch(b, face, u0, w, z0, z_spring, z_top):
    """Round-arched window with clear glass and a trim-coloured ring."""
    lancet(b, face, u0, w, z0, z_spring, z_top, kind="rond", glass="glas1", frame=b.st["trim"])


def clock(b, face, cu, cz, r=6.0, d=-1):
    """Clock face of radius r centred at (cu, cz) at depth d, gold rim, hands and hour marks at d-1."""
    for z in range(int(cz - r - 1), int(cz + r + 2)):
        for u in range(int(cu - r - 1), int(cu + r + 2)):
            dd = math.hypot(u + 0.5 - cu, z + 0.5 - cz)
            if dd <= r:
                b.put(face, u, z, d, "bord_wit" if dd < r - 1 else "goud")
    for t in range(int(r) - 1):
        b.put(face, int(cu), int(cz) + t, d - 1, "bord_zwart")
    for t in range(int(r * 0.6)):
        b.put(face, int(cu) + t, int(cz), d - 1, "bord_zwart")
    for k in range(12):
        a = k / 12 * math.tau
        b.put(face, int(cu + math.sin(a) * (r - 1.6)), int(cz + math.cos(a) * (r - 1.6)), d - 1, "bord_zwart")


def colored_panel(b, face, u0, u1, z0, z1, d=0, key=0):
    """1-deep coloured panel rect, colour picked from the style's "panels" by seed + key."""
    pal = b.st.get("panels", ["paneel_blauw"])
    b.rect(face, u0, u1, z0, z1, d, d + 1, pal[(b.seed + key) % len(pal)])


def gallery(b, face, depth=8):
    """Gallery (cantilevered access walkway) `depth` voxels deep with coloured parapet panels."""
    b.rect(face, 0, S, 0, 2, -depth, 0, b.st["trim"])
    b.rect(face, 0, S, 2, 9, -depth, -depth + 1, b.st["trim"])
    for u in range(0, S, 4):
        b.rect(face, u, u + 3, 3, 8, -depth - 1, -depth, b.st.get("panels", ["paneel_blauw"])[(u // 4 + b.seed) % 4])
    b.rect(face, 0, S, 9, 10, -depth, -depth + 1, "metaal3")


# ------------------------------------------------------------------ shops and hospitality

def _shop_colour(kind, b, u, z):
    """Colour of the shop interior back wall (d=3) at (u, z) for a shop `kind`, or None."""
    if kind == "kleding":
        if u % 5 == 1 and z < 13:
            return "stuc1" if z > 10 else pick(["stof1", "stof2", "stof3", "luifel_geel"], u, 0, b.seed, 231)
        if z == 12 and u % 5 in (3, 4):
            return "rvs"
        if z < 12 and u % 5 in (3, 4) and z > 6:
            return pick(["stof1", "stof2", "stof3", "bloem_roze", "luifel_blauw"], u, z, b.seed, 232)
        return "stof3" if z < 3 else ("licht_wit" if z == 15 else "stuc2")
    if kind == "restaurant":
        if z in (6, 7) and u % 6 in (1, 2, 3, 4):
            return "tafelkleed"
        if z < 6 and u % 6 in (2, 3):
            return "hout_donker1"
        if z == 14 and u % 6 == 3:
            return "licht_warm"
        return "deur_rood" if z < 9 else "interieur2"
    if kind == "cafe":
        if z < 8 and u > 14:
            return "hout2"
        if z == 8 and u > 14:
            return "hout_donker1"
        if z > 10 and u > 14 and u % 2 == 0:
            return pick(["glas_lood_geel", "glas_lood_rood", "blad3"], u, z, b.seed, 233)
        if z == 14:
            return "licht_warm"
        return "hout_donker1" if z < 5 else "interieur2"
    if kind == "bar":
        if z == 13 or (u == 4 and z > 4):
            return "neon_blauw"
        if z < 7 and u > 13:
            return "hout_donker2"
        return "interieur3"
    if kind == "telefoon":
        if z in (6, 7) and u % 4 in (1, 2):
            return "scherm"
        if z == 5:
            return "stuc1"
        if z == 15:
            return "licht_wit"
        return "stuc1" if z < 5 else "stuc2"
    return None


def shop_interior(b, face, kind):
    """Paint the visible shop interior (u 3..20, z 3..15, d=3), skipping the door column u=11."""
    for u in range(3, 21):
        for z in range(3, 16):
            if u == 11:
                continue
            c = _shop_colour(kind, b, u, z)
            if c:
                b.put(face, u, z, 3, c)


# kind -> (sign text, awning colours or None, sign board colour, letter colour)
SHOP_TYPES = {
    "kleding": ("MODE", ["luifel_wit", "bord_zwart"], "bord_zwart", "bord_wit"),
    "restaurant": ("BISTRO", ["luifel_rood", "luifel_rood"], "deur_rood", "goud"),
    "cafe": ("CAFE", ["luifel_groen", "luifel_wit"], "deur_groen", "goud"),
    "bar": ("BAR", None, "bord_zwart", "neon_roze"),
    "telefoon": ("TELECOM", None, "bord_blauw", "bord_wit"),
}


def shop_piece(kind):
    """Ground-floor shop facade piece for a SHOP_TYPES kind (shopfront, interior, sign board)."""
    text, awning, board, letter = SHOP_TYPES[kind]

    def f(b, face):
        b.shopfront(face, text, awning)
        shop_interior(b, face, kind)
        b.sign(face, 1, 31, 17, 23, board, text, letter)
        if kind == "bar":
            # dotted neon strip under the sign
            for u in range(2, 30):
                b.put(face, u, 17, -2, "neon_roze" if u % 2 else 0)
        if kind == "telefoon":
            b.rect(face, 1, 31, 16, 17, 0, 1, "scherm")
    f.__name__ = "f_shop_" + kind   # seed name
    return f


SHOP_PIECES = {f"bg_{k}": shop_piece(k) for k in SHOP_TYPES}


# ------------------------------------------------------------------ 1930s

def y30_gf_porch(b, face):
    """1930s ground floor: recessed porch with two front doors, windows with leaded tops."""
    b.plinth(face, 2)
    b.rect(face, 10, 22, 0, 19, 0, 7, 0)
    b.rect(face, 10, 22, 0, 1, 0, 7, "natuursteen3")
    b.rect(face, 9, 23, 19, 21, -1, 1, b.st["trim"])
    for u, c in ((11, "deur_groen"), (17, "deur_rood")):
        b.rect(face, u, u + 4, 1, 17, 7, 8, c)
        b.rect(face, u, u + 4, 13, 16, 7, 8, "glas_lood_geel")
        b.put(face, u + 3, 8, 6, "messing")
    b.rect(face, 15, 17, 1, 18, 7, 8, b.st["wall"])
    b.put(face, 16, 12, 6, "lamp_warm")
    b.window(face, 2, 5, 7, 14, sill=True, lintel=False)
    b.window(face, 24, 5, 7, 14, sill=True, lintel=False)
    _leaded(b, face, 2, 7, 15)
    _leaded(b, face, 24, 7, 15)


def y30_gf_window(b, face):
    """1930s ground floor: one wide window with mullions, transom and leaded top lights."""
    b.plinth(face, 2)
    b.window(face, 3, 4, 26, 16, sill=True, lintel=False)
    _mullions(b, face, (11, 20), 4, 20)
    _transom(b, face, 3, 29, 15)
    _leaded(b, face, 3, 26, 16)


def y30_up_window(b, face):
    """1930s upper floor: two windows with a centre mullion, transom and leaded top lights."""
    for u0 in (3, 18):
        b.window(face, u0, 5, 11, 15, sill=True, lintel=False)
        _mullions(b, face, (u0 + 5,), 5, 20)
        _transom(b, face, u0, u0 + 11, 15)
        _leaded(b, face, u0, 11, 16)
    b.rect(face, 0, S, 22, 23, 0, 1, "donkersteen2")


def y30_up_bay(b, face):
    """1930s upper floor: bay window projecting 4 voxels with chamfered sides and zinc cap."""
    for z in range(0, 23):
        for d in range(1, 5):
            inset = max(0, d - 2)
            b.rect(face, 5 + inset, 27 - inset, z, z + 1, -d, -d + 1, b.st["wall"])
    b.rect(face, 4, 28, 22, 23, -5, 0, "zink1")
    b.window(face, 8, 5, 16, 15, sill=False, lintel=False, d0=-4)
    _mullions(b, face, (13, 18), 5, 20, d=-3)
    _leaded(b, face, 8, 16, 16, d=-2, salt=235)
    b.rect(face, 5, 27, 0, 3, -5, 0, b.st["trim"])


def y30_up_balcony(b, face):
    """1930s upper floor: brick-parapet balcony with balcony door and window."""
    b.rect(face, 2, 30, 0, 1, -5, 0, "beton60")
    b.rect(face, 2, 30, 1, 8, -5, -4, b.st["wall"])
    b.rect(face, 2, 3, 1, 8, -5, 0, b.st["wall"])
    b.rect(face, 29, 30, 1, 8, -5, 0, b.st["wall"])
    b.rect(face, 2, 30, 8, 9, -5, -4, b.st["trim"])
    b.window(face, 4, 2, 9, 19, sill=False, lintel=False)
    b.window(face, 18, 5, 11, 15, sill=False, lintel=False)


def y30_up_stairwell(b, face):
    """1930s upper floor: tall stairwell window with stained-glass bands every 3 voxels."""
    b.window(face, 12, 1, 8, 22, sill=False, lintel=False)
    for z in range(1, 23, 3):
        for u in range(12, 20):
            b.put(face, u, z, 2, pick(["glas_lood_geel", "glas1", "glas_lood_rood"], u, z, b.seed, 236))
    b.window(face, 3, 6, 6, 12)
    b.window(face, 23, 6, 6, 12)


# ------------------------------------------------------------------ 1960s

def y60_gf_door(b, face):
    """1960s ground floor: front door with glass side light, canopy and coloured panel."""
    b.plinth(face, 1)
    b.door(face, 3, 7, 0, 17, transom=False, glass_panel=True)
    b.rect(face, 10, 12, 0, 17, 0, 3, 0)
    b.rect(face, 10, 12, 0, 17, 2, 3, "glas2")
    b.rect(face, 1, 14, 18, 19, -6, 0, "beton60")
    b.window(face, 15, 4, 15, 14, sill=True, lintel=False, sill_c="beton60")
    colored_panel(b, face, 15, 30, 18, 23, 0, 1)
    b.put(face, 8, 14, -1, "lamp_wit")


def y60_gf_window(b, face):
    """1960s ground floor: wide window with one mullion and a coloured panel above."""
    b.plinth(face, 1)
    b.window(face, 2, 2, 28, 16, sill=False, lintel=False)
    _mullions(b, face, (16,), 2, 18)
    colored_panel(b, face, 2, 30, 19, 23, 0, 2)


def y60_gf_storage(b, face):
    """1960s ground floor: three storage doors in the style's door colours."""
    b.plinth(face, 1)
    for u0 in (2, 12, 22):
        _storage_door(b, face, u0, 8, b.st["doors"][(u0 + b.seed) % 4])


def y60_up_window(b, face):
    """1960s upper floor: coloured parapet panel with a ribbon window above."""
    colored_panel(b, face, 1, 31, 1, 6, 0, 3)
    b.window(face, 1, 6, 30, 13, sill=False, lintel=False)
    _mullions(b, face, (11, 21), 6, 19)


def y60_up_window_small(b, face):
    """1960s upper floor: three small windows with concrete sills."""
    for u0 in (3, 13, 23):
        b.window(face, u0, 9, 7, 10, sill=True, lintel=False, sill_c="beton60")


def y60_gallery_door(b, face):
    """1960s upper floor on a gallery: front door, two windows and a lamp."""
    gallery(b, face)
    b.door(face, 3, 7, 2, 19, transom=False, glass_panel=True, color=b.st["doors"][b.seed % 4])
    b.window(face, 13, 10, 8, 9, sill=False, lintel=False)
    b.window(face, 23, 10, 7, 9, sill=False, lintel=False)
    b.put(face, 11, 14, -1, "lamp_wit")


def y60_gallery_window(b, face):
    """1960s upper floor on a gallery: two windows."""
    gallery(b, face)
    b.window(face, 3, 10, 12, 9, sill=False, lintel=False)
    b.window(face, 18, 10, 12, 9, sill=False, lintel=False)


def y60_up_balcony(b, face):
    """1960s upper floor: concrete balcony 7 deep with coloured parapet and metal posts."""
    b.rect(face, 3, 29, 0, 2, -7, 0, "beton60")
    b.rect(face, 3, 29, 2, 9, -7, -6, b.st.get("panels")[b.seed % 4])
    b.rect(face, 3, 4, 2, 9, -7, 0, "metaal3")
    b.rect(face, 28, 29, 2, 9, -7, 0, "metaal3")
    b.window(face, 4, 2, 10, 19, sill=False, lintel=False)
    b.window(face, 16, 6, 13, 14, sill=False, lintel=False)


# ------------------------------------------------------------------ gallery flat

def flat_gallery(b, face):
    """Gallery flat upper floor: gallery with two front doors and two kitchen windows."""
    gallery(b, face, 8)
    for i, u0 in enumerate((1, 17)):
        b.door(face, u0, 6, 2, 19, transom=False, glass_panel=True, color=b.st["doors"][(b.seed + i) % 3])
        b.window(face, u0 + 8, 9, 6, 10, sill=False, lintel=False)
    b.put(face, 15, 15, -1, "lamp_wit")


def flat_balconies(b, face):
    """Gallery flat back side: two recessed loggia balconies (6 deep) split by a concrete wall."""
    b.rect(face, 1, 31, 0, 22, 0, 6, 0)
    b.rect(face, 1, 31, 0, 1, 0, 6, "beton60")
    b.rect(face, 1, 31, 1, 8, 0, 1, b.st["panels"][b.seed % 4])
    b.rect(face, 1, 31, 8, 9, 0, 1, "metaal3")
    b.rect(face, 15, 17, 0, 22, 0, 6, "beton60")
    for u0 in (2, 18):
        b.window(face, u0, 2, 12, 18, sill=False, lintel=False, d0=5)


def flat_stairwell(b, face):
    """Gallery flat: full-height stairwell glazing with a frame bar every 4 voxels."""
    b.window(face, 10, 0, 12, 23, sill=False, lintel=False)
    for z in range(0, 23, 4):
        _transom(b, face, 10, 22, z)


def flat_gable_end(b, face):
    """Gallery flat gable end: mostly blank with one small window."""
    b.window(face, 14, 9, 4, 6, sill=False, lintel=False)


def flat_gf_entrance(b, face):
    """Gallery flat ground floor: glazed entrance hall with glass doors and canopy."""
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plinth"])
    b.window(face, 6, 0, 20, 21, sill=False, lintel=False)
    b.rect(face, 12, 20, 0, 18, 1, 3, "glas_helder")
    _mullions(b, face, (16,), 0, 18, c="metaal3")
    b.rect(face, 4, 28, 21, 22, -6, 0, "beton60")
    _transom(b, face, 7, 11, 8, d=2, c="metaal3")   # mailbox / intercom strip


def flat_gf_storage(b, face):
    """Gallery flat ground floor: four storage doors with a high window strip."""
    b.rect(face, 0, S, 0, 1, 0, 1, b.st["plinth"])
    for u0 in (1, 9, 17, 25):
        _storage_door(b, face, u0, 6, "paneel2" if u0 % 2 else "paneel1")
    for u in range(0, S):
        b.put(face, u, 19, 0, "glas2" if u % 8 not in (0, 7) else b.st["frame"])


# ------------------------------------------------------------------ modern apartment

def apt_gf_entrance(b, face):
    """Modern apartment ground floor: full-width glass entrance with wooden canopy."""
    b.window(face, 2, 0, 28, 23, sill=False, lintel=False)
    b.rect(face, 10, 22, 0, 19, 1, 3, "glas_helder")
    b.rect(face, 0, S, 22, 24, -4, 1, b.st["accent"])


def apt_up_glass(b, face):
    """Modern apartment upper floor: storey-high glazing with glass balustrade and steel rail."""
    b.window(face, 1, 1, 30, 22, sill=False, lintel=False)
    b.rect(face, 1, 31, 2, 9, 0, 1, "glas_helder")
    b.rect(face, 1, 31, 9, 10, 0, 1, "rvs")
    _mullions(b, face, (10, 21), 1, 23)


def apt_up_loggia(b, face):
    """Modern apartment upper floor: loggia recessed 8 voxels, framed in the accent wood."""
    b.rect(face, 2, 30, 0, 22, 0, 8, 0)
    b.rect(face, 2, 30, 0, 1, 0, 8, b.st["accent"])
    b.rect(face, 2, 30, 21, 22, 0, 8, b.st["accent"])
    b.rect(face, 2, 30, 1, 9, 0, 1, "glas_helder")
    b.window(face, 3, 1, 26, 20, sill=False, lintel=False, d0=7)


def apt_up_panel(b, face):
    """Modern apartment upper floor: wooden accent panel on the left, tall window right."""
    b.rect(face, 0, 12, 0, 24, 0, 1, b.st["accent"])
    b.window(face, 14, 3, 14, 18, sill=False, lintel=False)


def apt_up_small(b, face):
    """Modern apartment upper floor: four narrow windows."""
    for u0 in (3, 11, 19, 27):
        b.window(face, u0, 8, 3, 8, sill=False, lintel=False)


def apt_up_large(b, face):
    """Storey-high two-pane glass wall (frame at the edges and u=16) with interior behind."""
    b.rect(face, 0, S, 0, 24, 0, 3, 0)
    for z in range(0, 24):
        for u in range(0, S):
            edge = u in (0, 31) or z in (0, 23) or u == 16
            b.put(face, u, z, 0, b.st["frame"] if edge else 0)
            b.put(face, u, z, 1, 0 if edge else b.st["glass"])
    b.interior(face, 1, 31, 1, 23, 2, 900)


# ------------------------------------------------------------------ townhouses

def pilasters(b, face, z0=0, z1=24):
    """Trim pilasters (2 wide, 1 proud) at both facade edges from z0 to z1, with a capital at z1-1."""
    for u in (0, 1, 30, 31):
        for z in range(z0, z1):
            b.put(face, u, z, -1, b.st["trim"])
    # Capital: u in -1..2 / 29..32 clipped to the face.
    for u in (0, 1, 2, 29, 30, 31):
        b.put(face, u, z1 - 1, -2, b.st["trim"])


def h1600_gf_door(b, face):
    """17th-century townhouse ground floor: raised front door with stone stoop and railings."""
    pilasters(b, face)
    b.plinth(face, 3)
    b.door(face, 11, 10, 4, 20, steps=0)
    for i in range(4):
        b.rect(face, 8 - i * 2, 24 + i * 2, 0, 4 - i, -1 - i, -i, "natuursteen1")
    b.rect(face, 9, 23, 3, 4, -6, -1, "natuursteen1")
    _mullions(b, face, (8, 23), 4, 9, d=-5, c="metaal_donker")
    b.window(face, 3, 6, 6, 14, muntins=True)
    b.window(face, 25, 6, 5, 14, muntins=True)


def h1600_gf_window(b, face):
    """17th-century townhouse ground floor: three tall sash windows."""
    pilasters(b, face)
    b.plinth(face, 3)
    for u0 in (4, 13, 22):
        b.window(face, u0, 6, 7, 15, muntins=True)


def h1600_up_window(b, face):
    """17th-century townhouse upper floor: three tall sash windows."""
    pilasters(b, face)
    for u0 in (4, 13, 22):
        b.window(face, u0, 4, 7, 17, muntins=True)


def h1600_up_balcony(b, face):
    """Townhouse upper floor: French window with stone balustrade balcony, flanking windows."""
    pilasters(b, face)
    b.window(face, 12, 2, 8, 19, muntins=True, sill=False)
    _balustrade(b, face, 9, 23, "natuursteen1", "natuursteen2")
    b.window(face, 3, 4, 6, 17, muntins=True)
    b.window(face, 24, 4, 6, 17, muntins=True)


def _pediment_rows(b, z_base, z_top, half_of_z, d_face):
    """Triangular pediment on face "v": rows z_base..z_top-1, half-width half_of_z(z).

    The outline (side edges and bottom row) is trim, the inside wall, at depth d_face.
    """
    st = b.st
    for z in range(z_base, z_top):
        half = half_of_z(z)
        for u in range(16 - half, 16 + half):
            edge = u in (16 - half, 16 + half - 1) or z == z_base
            b.put("v", u, z, d_face, st["trim"] if edge else st["wall"])
            if d_face == 0:
                b.put("v", u, z, 1, st["wall"])


def cornice_facade_top(style, pediment=True):
    """Top tile: straight cornice facade (white cornice, attic band), optional pediment with window."""
    def fn():
        b = Bld(style, "lijst" + str(pediment), 24)
        st = b.st
        b.m.box(O, O + 2, 0, O + S, O + S, 6, st["wall"])
        b.m.box(O, O + 2, 6, O + S, O + S, 7, "zink1")
        for u in range(S):
            # cornice: 2 rows 3 deep with dentils at z=2
            for d in range(-3, 1):
                b.put("v", u, 0, d, "kozijn_wit")
                b.put("v", u, 1, d, "kozijn_wit")
            if u % 2 == 0:
                b.put("v", u, 2, -1, "kozijn_wit")
            for z in range(3, 9):
                b.put("v", u, z, 0, st["wall"])
            if u % 3 == 0:
                for z in range(3, 8):
                    b.put("v", u, z, -1, st["trim"])
            b.put("v", u, 8, -1, st["trim"])
            b.put("v", u, 8, 0, st["trim"])
        if pediment:
            _pediment_rows(b, 9, 17, lambda z: 16 - (z - 9) * 2, 0)
            b.window("v", 13, 10, 6, 4, sill=False, lintel=False)
        return b.m
    return fn


def h1900_gf_door(b, face):
    """1900 townhouse ground floor: front door with steps and a round-arched window."""
    b.plinth(face, 2)
    b.door(face, 3, 8, 2, 19, steps=2)
    _round_arch(b, face, 15, 13, 4, 15, 21)


def h1900_gf_window_arch(b, face):
    """1900 townhouse ground floor: two round-arched windows."""
    b.plinth(face, 2)
    _round_arch(b, face, 3, 11, 4, 15, 21)
    _round_arch(b, face, 18, 11, 4, 15, 21)


def h1900_up_window_arch(b, face):
    """1900 townhouse upper floor: two round-arched windows with trim sills."""
    for u0 in (3, 18):
        _round_arch(b, face, u0, 10, 4, 15, 20)
        b.rect(face, u0 - 1, u0 + 11, 3, 4, -1, 1, b.st["trim"])


def h1900_up_bay(b, face):
    """1900 townhouse upper floor: rectangular bay window projecting 4 voxels, zinc cap."""
    b.rect(face, 6, 26, 0, 23, -4, 0, b.st["wall"])
    b.rect(face, 5, 27, 23, 24, -5, 0, "zink1")
    b.window(face, 8, 4, 16, 16, muntins=True, d0=-4, sill=False)
    b.rect(face, 6, 26, 0, 2, -5, 0, b.st["trim"])


def mansard(style, edges):
    """Mansard roof: steep lower slope with dormers along `edges` (subset of "vral"), flat on top."""
    def fn():
        b = Bld(style, "mansarde" + edges, 32)
        m = b.m
        for ly in range(S):
            for lx in range(S):
                # distance to the nearest sloped edge
                dists = []
                if "v" in edges:
                    dists.append(ly)
                if "a" in edges:
                    dists.append(S - 1 - ly)
                if "l" in edges:
                    dists.append(lx)
                if "r" in edges:
                    dists.append(S - 1 - lx)
                d = min(dists) if dists else 99
                top = 16 if d >= 6 else int(2 + d * 2.4)
                for z in range(top):
                    c = roof_colors(b, z, lx, ly) if (d < 6 and z >= top - 3) else b.st["wall"]
                    m.set(O + lx, O + ly, z, c)
                if d >= 6:
                    m.set(O + lx, O + ly, 16, "zink1")
        for face in edges:
            for u0 in (6, 20):
                b.rect(face, u0, u0 + 6, 2, 13, 0, 3, "kozijn_wit")
                b.rect(face, u0 + 1, u0 + 5, 3, 11, 0, 1, b.st["glass"])
                b.rect(face, u0 - 1, u0 + 7, 13, 14, -1, 3, "zink1")
        return m
    return fn


# ------------------------------------------------------------------ offices

def o80_mirror_band(b, face):
    """1980s office: brown spandrel bands with a bronze mirror-glass ribbon in between."""
    b.rect(face, 0, S, 0, 8, -1, 1, "bruin80_2")
    _glass_wall(b, face, 8, 22, lambda u, z: "antraciet3" if u % 8 == 0 else 0, lambda u, z: "glas_brons")
    b.interior(face, 0, S, 8, 22, 2, 1100, office=True)
    b.rect(face, 0, S, 22, 24, -1, 1, "bruin80_1")


def o2000_sun_shading(b, face):
    """2000s office: curtain wall with three horizontal aluminium sun-shading fins (4 deep)."""
    f_office_curtain_wall(b, face)
    for z in (8, 15, 21):
        b.rect(face, 0, S, z, z + 1, -4, 0, "alu")


def om_louvres(b, face):
    """Modern office: full glass with vertical louvres every 3 voxels (accent every 6th)."""
    _glass_wall(b, face, 0, 24, lambda u, z: 0, lambda u, z: b.st["glass"])
    b.interior(face, 0, S, 1, 23, 2, 1200, office=True)
    for u in range(0, S, 3):
        b.rect(face, u, u + 1, 0, 24, -4, 0, b.st["accent"] if u % 6 == 0 else "stuc1")
    b.rect(face, 0, S, 23, 24, -4, 1, "stuc1")


def office_small(b, face):
    """Office upper floor: four small windows."""
    for u0 in (2, 10, 18, 26):
        b.window(face, u0, 8, 4, 10, sill=False, lintel=False)


def office_large(b, face):
    """Office upper floor: large two-pane glass wall (same as apt_up_large, own seed name)."""
    apt_up_large(b, face)


# ------------------------------------------------------------------ museums

def column(b, face, uc, d, z0, z1, r=1.6, c=None):
    """Round column centred at (uc, d) from z0 to z1, radius r (+0.9 for base and capital)."""
    c = c or b.st["trim"]
    for z in range(z0, z1):
        rr = r + (0.9 if (z < z0 + 2 or z > z1 - 3) else 0)
        for u in range(int(uc - rr - 1), int(uc + rr + 2)):
            for dd in range(int(d - rr - 1), int(d + rr + 2)):
                if math.hypot(u + 0.5 - uc, dd + 0.5 - d) <= rr:
                    b.put(face, u, z, dd, c)


def mc_gf_columns(b, face):
    """Classical museum ground floor: portico of four columns before a recessed entrance."""
    b.rect(face, 0, S, 0, 24, -7, 0, 0)
    b.rect(face, 0, S, 0, 2, -8, 0, b.st["plinth"])
    for uc in (4, 12, 20, 28):
        column(b, face, uc, -5, 2, 22)
    b.rect(face, 0, S, 22, 24, -8, 0, b.st["trim"])
    b.door(face, 11, 10, 2, 18, transom=True)


def mc_gf_window_arch(b, face):
    """Classical museum ground floor: one large round-arched window."""
    b.plinth(face, 3)
    _round_arch(b, face, 9, 14, 5, 14, 21)


def mc_up_window_arch(b, face):
    """Classical museum upper floor: round-arched window between pilasters."""
    _round_arch(b, face, 9, 14, 3, 13, 20)
    pilasters(b, face)


def mc_up_relief(b, face):
    """Classical museum upper floor: blank wall with a framed diagonal relief panel."""
    pilasters(b, face)
    for z in range(6, 18):
        for u in range(6, 26):
            edge = z in (6, 17) or u in (6, 25)
            if edge or (u + z) % 4 == 0:
                b.put(face, u, z, -1, b.st["trim"])


def mc_pediment(style):
    """Top tile: classical triangular pediment on the front with a gable roof behind it."""
    def fn():
        b = Bld(style, "fronton", 24)
        st = b.st
        b.m.box(O, O, 0, O + S, O + S, 3, st["wall"])
        for u in range(S):
            for d in (-2, -1, 0):
                b.put("v", u, 0, d, st["trim"])
        _pediment_rows(b, 3, 16, lambda z: 16 - int((z - 3) * 1.25), -1)
        # gable roof behind the pediment
        for ly in range(1, S):
            for lx in range(S):
                hh = 2 * min(lx + 0.5, S - lx - 0.5) * 0.4 + 3
                for z in range(3, int(hh)):
                    b.m.set(O + lx, O + ly, z, roof_colors(b, z * 2, lx, ly) if z >= int(hh) - 2 else st["wall"])
        return b.m
    return fn


def _disc_layers(m, c, z0, z1, radius_fn, colour_fn):
    """For z0 <= z < z1 set every voxel within radius_fn(z) of the vertical axis at (c, c).

    colour_fn(x, y, z, d) gives the colour, d = horizontal distance to the axis.
    """
    for z in range(z0, z1):
        r = radius_fn(z)
        for y in range(m.sy):
            for x in range(m.sx):
                d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                if d <= r:
                    m.set(x, y, z, colour_fn(x, y, z, d))


def dome(style, big=False):
    """Copper dome on a drum with windows and a lantern; big=True gives a 3x3-tile (112 wide) dome."""
    def fn():
        b = Bld(style, "koepel" + str(big), 48)
        if big:
            size = 112
            m = V(size, size, 72)
            c = size / 2
            R = 40
            drum = 12
        else:
            m = b.m
            c = W / 2
            R = 13
            drum = 6

        def drum_colour(x, y, z, d):
            ang = math.atan2(y - c, x - c)
            win = d > R + 1 and 3 < z < drum - 2 and int((ang + 4) * R / 6) % 2 == 0
            return "glas1" if win else b.st["trim"]
        _disc_layers(m, c, 0, drum, lambda z: R + 2, drum_colour)

        # hemisphere squashed to 0.85 R high, zinc ribs
        Rz = R * 0.85

        def shell_colour(x, y, z, d):
            ang = math.atan2(y - c, x - c)
            rib = int((ang + 4) * 8 / math.pi) % 4 == 0
            return "zink1" if rib else "koper"

        def shell_radius(z):
            zz = (z - drum) / Rz
            return R * math.sqrt(max(0.0, 1 - zz * zz))
        _disc_layers(m, c, drum, int(drum + Rz) + 1, shell_radius, shell_colour)

        # lantern with gold finial
        top = int(drum + Rz)
        lr = max(2, R // 6)
        _disc_layers(m, c, top, top + lr * 2, lambda z: lr,
                     lambda x, y, z, d: "glas1" if (z - top) % 3 else b.st["trim"])
        for z in range(top + lr * 2, top + lr * 2 + 4):
            m.set(int(c), int(c), z, "goud")
        return m
    return fn


def mm_gf_entrance(b, face):
    """Modern museum ground floor: full glass front with frame grid and MUSEUM sign."""
    b.rect(face, 0, S, 0, 24, 0, 3, 0)
    for z in range(0, 24):
        for u in range(S):
            edge = u % 8 == 0 or z in (0, 23)
            b.put(face, u, z, 1, "antraciet1" if edge else "glas_helder")
    b.rect(face, 0, S, 0, 23, 3, 4, "stuc2")
    b.sign(face, 4, 28, 18, 23, "stuc1", "MUSEUM", "antraciet1")


def mm_up_light_strip(b, face):
    """Modern museum upper floor: one full-width horizontal light strip."""
    b.window(face, 0, 9, 32, 4, sill=False, lintel=False)


def mm_up_blank(b, face):
    """Modern museum: blank wall with diagonal relief lines."""
    for z in range(0, 24):
        for u in range(S):
            if (u + z) % 12 == 0:
                b.put(face, u, z, -1, "stuc3")


def mm_roof_overhang(style):
    """Roof tile: flat roof slab cantilevering 8 voxels over the front with downlights."""
    def fn():
        b = Bld(style, "overstek", 8)
        b.m.box(O, O - 8, 0, O + S, O + S, 3, "stuc1")
        b.m.box(O, O - 8, 0, O + S, O - 7, 3, "antraciet1")
        for x in range(O + 2, O + S, 6):
            b.m.set(x, O - 4, 0, "lamp_wit")
        return b.m
    return fn


# ------------------------------------------------------------------ churches

def church_gf_portal(b, face):
    """Church ground floor: stepped pointed-arch portal (3 orders) with a double wooden door."""
    b.plinth(face, 2)
    for k in range(3):
        lancet(b, face, 9 - k * 2, 14 + k * 4, 0, 14, 23, d0=-k, glass="hout_donker2", frame=b.st["trim"])
    b.rect(face, 10, 22, 0, 14, 0, 2, 0)
    b.rect(face, 10, 22, 0, 14, 2, 3, "hout_donker2")
    _mullions(b, face, (16,), 0, 14, d=2, c="metaal_donker")
    b.put(face, 14, 7, 1, "metaal_donker")
    b.put(face, 17, 7, 1, "metaal_donker")


def church_gf_lancet(b, face):
    """Church ground floor: tall lancet window."""
    b.plinth(face, 2)
    lancet(b, face, 10, 12, 6, 24, 24)


def church_up_lancet(b, face):
    """Church upper floor: top part of a lancet window."""
    lancet(b, face, 10, 12, 0, 6, 20)


def church_up_rose(b, face):
    """Church upper floor: rose window (radius 10.5) with spokes and stained glass."""
    cu, cz, r = 16, 12, 10.5
    for z in range(0, 24):
        for u in range(S):
            d = math.hypot(u + 0.5 - cu, z + 0.5 - cz)
            if d <= r:
                b.put(face, u, z, 0, 0)
                b.put(face, u, z, 1, 0)
                ang = math.atan2(z - cz, u - cu)
                spoke = int((ang + 4) * 12 / math.pi) % 3 == 0 or abs(d - r * 0.45) < 0.6 or d < 1.5
                c = b.st["trim"] if spoke else pick(["glas_lood_blauw", "glas_lood_rood", "glas_lood_geel"], int(d), int((ang + 4) * 4), b.seed, 237)
                b.put(face, u, z, 2, c)
                b.put(face, u, z, 3, "licht_warm")
            elif d <= r + 1.5:
                b.put(face, u, z, 0, b.st["trim"])
                b.put(face, u, z, -1, b.st["trim"])


def church_buttress(b, face):
    """Church upper floor: stepped buttress at the left edge plus a lancet window."""
    for z in range(0, 24):
        depth = 6 - z // 5
        for d in range(-depth, 0):
            for u in (0, 1, 2):
                b.put(face, u, z, d, b.st["wall"])
        if z % 5 == 4:
            b.put(face, 0, z, -depth, b.st["trim"])
    lancet(b, face, 12, 10, 4, 14, 22)


def church_tower_portal(b, face):
    """Tower base: portal on the front face, small lancet on the other faces."""
    if face == "v":
        church_gf_portal(b, face)
    else:
        lancet(b, face, 13, 6, 6, 14, 20)


def church_tower_window(b, face):
    """Tower storey: narrow lancet with a trim band."""
    lancet(b, face, 13, 6, 4, 13, 20)
    b.rect(face, 0, S, 22, 23, -1, 1, b.st["trim"])


def church_tower_clock(b, face):
    """Tower storey: clock face with a trim band."""
    clock(b, face, 16, 12, 8.0)
    b.rect(face, 0, S, 22, 23, -1, 1, b.st["trim"])


def church_tower_louvre(b, face):
    """Tower belfry: two louvred sound openings."""
    for u0 in (6, 18):
        lancet(b, face, u0, 7, 3, 12, 20, glass="metaal_donker")
        for z in range(4, 18, 2):
            b.rect(face, u0, u0 + 7, z, z + 1, 1, 2, "hout_donker2")
    b.rect(face, 0, S, 22, 24, -1, 1, b.st["trim"])


def tower_spire(style, part):
    """Octagonal spire in two 48-high tiles: part "onder" (lower, with corner turrets) or "boven" (top, cross)."""
    def fn():
        b = Bld(style, "spits" + part, 48)
        m = b.m
        c = W / 2
        z0 = 0 if part == "onder" else 24
        for z in range(0, 48):
            Z = z + z0
            hs = 16 - Z * 0.36   # half size shrinks with absolute height Z
            if hs <= 0.5:
                break
            for y in range(W):
                for x in range(W):
                    dx, dy = abs(x + 0.5 - c), abs(y + 0.5 - c)
                    if max(dx, dy) <= hs and dx + dy <= hs * 1.35:
                        m.set(x, y, z, roof_colors(b, Z, x, y) if (max(dx, dy) > hs - 1.5 or dx + dy > hs * 1.35 - 1.5) else b.st["wall"])
        if part == "onder":
            for (px, py) in ((O + 1, O + 1), (O + S - 3, O + 1), (O + 1, O + S - 3), (O + S - 3, O + S - 3)):
                for z in range(0, 10):
                    r = 1.5 - z * 0.12
                    m.cyl(px + 1, py + 1, max(0.6, r), z, z + 1, b.st["trim"])
            for face in "vral":
                b.rect(face, 0, S, 0, 2, -1, 1, b.st["trim"])
        else:
            # gold cross on the apex
            top = int(16 / 0.36) - z0
            for z in range(top - 2, top + 8):
                m.set(int(c), int(c), z, "goud")
            for x in range(int(c) - 2, int(c) + 3):
                m.set(x, int(c), top + 5, "goud")
            m.set(int(c) + 1, int(c), top + 8, "goud")
            m.set(int(c), int(c), top + 8, "goud")
        return m
    return fn


def tower_pinnacles(style):
    """Tower top: crenellated parapet with four tapering corner pinnacles with gold tips."""
    def fn():
        b = Bld(style, "pinakels", 40)
        m = b.m
        m.box(O, O, 0, O + S, O + S, 2, b.st["trim"])
        for face in "vral":
            for u in range(0, S, 4):
                for z in range(2, 6):
                    b.put(face, u, z, 0, b.st["trim"])
        for (px, py) in ((O + 2, O + 2), (O + S - 2, O + 2), (O + 2, O + S - 2), (O + S - 2, O + S - 2)):
            for z in range(0, 30):
                r = 2.4 - z * 0.075
                m.cyl(px, py, max(0.5, r), z, z + 1, b.st["trim"] if z < 26 else "goud")
        return m
    return fn


def flying_buttress(style):
    """Flying buttress: pier at the front, arch rising towards the back (against the nave)."""
    def fn():
        b = Bld(style, "luchtboog")
        m = b.m
        st = b.st
        m.box(O + 13, O, 0, O + 19, O + 6, 24, st["wall"])
        for z in range(24, 30):
            m.cyl(O + 16, O + 3, 2.2 - (z - 24) * 0.3, z, z + 1, st["trim"])
        for t in range(0, 40):
            ly = 5 + t * 26 / 40.0
            z = 14 + 8 * math.sin((ly - 5) / 26.0 * math.pi / 2)
            for lx in range(14, 18):
                for dz in range(0, 3):
                    m.set(O + lx, O + int(ly), int(z) + dz, st["trim"])
        return m
    return fn


def mch_gf_entrance(b, face):
    """Modern church ground floor: glazed entrance with wooden doors and concrete canopy."""
    b.plinth(face, 1)
    b.window(face, 6, 0, 20, 17, sill=False, lintel=False)
    b.rect(face, 12, 20, 0, 16, 1, 3, "hout2")
    b.rect(face, 2, 30, 17, 19, -7, 0, "beton60")


def mch_up_slit(b, face):
    """Modern church upper floor: four full-height slit windows."""
    for u0 in (4, 10, 21, 27):
        b.window(face, u0, 0, 2, 24, sill=False, lintel=False, frame="beton60")


def mch_up_cross(b, face):
    """Modern church upper floor: 2-voxel concrete relief cross."""
    _mullions(b, face, (15, 16), 3, 22, d=-1, c="beton60")
    for z in (15, 16):
        _transom(b, face, 10, 22, z, d=-1, c="beton60")


def mch_tower(style, has_clock):
    """Open concrete bell-tower frame (4 posts, ring beams); has_clock adds a bell and cross."""
    def fn():
        b = Bld(style, "kloktoren" + str(has_clock), 32 if has_clock else 24)
        m = b.m
        for (lx, ly) in ((10, 10), (20, 10), (10, 20), (20, 20)):
            m.box(O + lx, O + ly, 0, O + lx + 2, O + ly + 2, 24, "beton60")
        for z in (0, 12, 23):
            for lx in range(10, 22):
                for ly in (10, 21):
                    m.set(O + lx, O + ly, z, "beton60")
                    m.set(O + ly, O + lx, z, "beton60")
        if has_clock:
            for z in range(14, 21):
                r = 1.5 + (21 - z) * 0.35
                m.cyl(O + 16, O + 16, r, z, z + 1, "messing")
            for z in range(24, 32):
                m.set(O + 16, O + 16, z, "metaal_donker")
            for lx in range(13, 20):
                m.set(O + lx, O + 16, 29, "metaal_donker")
        return m
    return fn


# ------------------------------------------------------------------ school / government / barn

def school_gf_entrance(b, face):
    """School ground floor: glazed entrance with canopy and SCHOOL sign."""
    b.plinth(face, 2)
    b.window(face, 8, 0, 16, 18, sill=False, lintel=False)
    b.rect(face, 11, 21, 0, 17, 1, 3, "glas_helder")
    _mullions(b, face, (16,), 0, 17)
    b.rect(face, 4, 28, 18, 19, -6, 0, "beton60")
    b.sign(face, 6, 26, 19, 24, "paneel_groen", "SCHOOL", "bord_wit")


def school_window(b, face, z0=4, hh=16):
    """Full-width school window from z0, hh high, with a 4x4 frame grid."""
    b.window(face, 2, z0, 28, hh, sill=True, lintel=False, sill_c="beton60")
    for z in range(z0, z0 + hh):
        for u in range(2, 30):
            if (u - 2) % 4 == 0 or (z - z0) % 4 == 0:
                b.put(face, u, z, 1, b.st["frame"])


def school_gf_window(b, face):
    """School ground floor: plinth and gridded window."""
    b.plinth(face, 2)
    school_window(b, face)


def school_up_window(b, face):
    """School upper floor: taller gridded window."""
    school_window(b, face, 3, 18)


def gov_gf_entrance(b, face):
    """Government ground floor: recessed portico with steps, four columns and entrance door."""
    b.rect(face, 0, S, 0, 24, -7, 0, 0)
    for i in range(3):
        b.rect(face, 4, 28, 0, 3 - i, -7 + i * 2, 0, b.st["trim"])
    for uc in (5, 13, 19, 27):
        column(b, face, uc, -5, 3, 21, 1.4)
    b.rect(face, 0, S, 21, 24, -8, 0, b.st["trim"])
    b.door(face, 11, 10, 3, 17, transom=True)


def gov_up_window_tall(b, face):
    """Government upper floor: three tall windows with muntins."""
    for u0 in (3, 13, 23):
        b.window(face, u0, 3, 6, 19, muntins=True)


def gov_up_balcony(b, face):
    """Government upper floor: tall windows with a central stone balcony."""
    gov_up_window_tall(b, face)
    _balustrade(b, face, 10, 22, b.st["trim"], b.st["trim"])


def gov_name(style):
    """Top tile: low attic band with the gold lettering RAADHUIS on the front."""
    def fn():
        b = Bld(style, "naambord", 8)
        b.m.box(O, O, 0, O + S, O + S, 1, "zink1")
        b.rect("v", 0, S, 0, 7, 0, 1, b.st["trim"])
        px, (tw, _th) = text_pixels("RAADHUIS")
        for (c, r) in px:
            b.put("v", 16 - tw // 2 + c, 5 - r, -1, "goud")
        return b.m
    return fn


def barn_gf_door(b, face):
    """Barn ground floor: large double barn door with frame and diagonal braces."""
    b.rect(face, 6, 26, 0, 20, 0, 2, 0)
    for z in range(0, 20):
        for u in range(6, 26):
            edge = u in (6, 15, 16, 25) or z == 19
            diag = (u - 6) % 10 == z % 10 or (u - 6) % 10 == 9 - z % 10
            b.put(face, u, z, 1, b.st["trim"] if (edge or diag) else b.st["doors"][0])
    b.rect(face, 0, S, 0, 1, 0, 1, b.st["plinth"])


def barn_gf_window(b, face):
    """Barn ground floor: two small stable windows."""
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plinth"])
    b.window(face, 6, 8, 6, 6, muntins=True, sill=False, lintel=False)
    b.window(face, 20, 8, 6, 6, muntins=True, sill=False, lintel=False)


def barn_hayloft(b, face):
    """Barn upper floor: hayloft door with a hoisting beam above."""
    b.rect(face, 12, 20, 6, 18, 0, 2, 0)
    b.rect(face, 12, 20, 6, 18, 1, 2, b.st["doors"][0])
    _mullions(b, face, (12, 19), 6, 18, c=b.st["trim"])
    for d in range(-5, 0):
        b.put(face, 16, 20, d, "hout_donker2")


# ------------------------------------------------------------------ hollow halls and canopies

# Hall styles: frame/beam colours, glazed wall infill, socle and roof infill.
HALL_STYLES = {
    "hal_glas": dict(frame="metaal3", wall="glas_helder", socle="antraciet1", roof="glas_helder", beam="metaal3"),
    "hal_zwembad": dict(frame="stuc1", wall="glas1", socle="tegel_wit", roof="paneel3", beam="stuc1"),
    "hal_sport": dict(frame="baksteen2", wall="glas2", socle="baksteen4", roof="zink1", beam="metaal2"),
}


def hall(stylename, walls="v", roof=True, door=False, columns=()):
    """Hollow hall tile (no interior body): glazed framed walls on the faces in `walls`,
    optional beamed roof at z=23, optional glass double door on the front, and 2x2 columns
    at the local (u, d) positions in `columns`.
    """
    hs = HALL_STYLES[stylename]

    def fn():
        b = Bld("modern_wit", stylename + walls + str(roof) + str(door) + str(columns), HGT)
        m = b.m
        for face in walls:
            for u in range(S):
                post = u % 8 == 0 or u == S - 1
                for z in range(0, 24):
                    if z < 3:
                        c = hs["socle"]
                    elif post or z in (3, 12, 23):
                        c = hs["frame"]
                    else:
                        c = hs["wall"]
                    b.put(face, u, z, 0, c)
                    if post:
                        b.put(face, u, z, 1, hs["frame"])
            if door and face == "v":
                b.rect("v", 10, 22, 0, 18, 0, 1, "glas_helder")
                _mullions(b, "v", (10, 21, 16), 0, 18, d=0, c=hs["frame"])
                _transom(b, "v", 10, 22, 18, d=0, c=hs["frame"])
        if roof:
            for ly in range(S):
                for lx in range(S):
                    beam = lx % 8 == 0 or ly % 16 == 0
                    m.set(O + lx, O + ly, 23, hs["beam"] if beam else hs["roof"])
                    if beam and (lx % 8 == 0):
                        m.set(O + lx, O + ly, 22, hs["beam"])
            for lx in range(4, S, 8):
                m.set(O + lx, O + 16, 21, "lamp_wit")
        for (cu, cd) in columns:
            m.box(O + cu, O + cd, 0, O + cu + 2, O + cd + 2, 24, hs["frame"])
        return m
    return fn


def canopy(with_column):
    """Glass canopy on steel beams at z=22; with_column adds a 2x2 column at the front-left corner."""
    def fn():
        m = V(W, W, HGT)
        for ly in range(S):
            for lx in range(S):
                beam = lx in (0, 31) or ly in (0, 31) or ly % 8 == 0
                m.set(O + lx, O + ly, 22, "metaal3" if beam else "glas_helder")
            m.set(O + 0, O + ly, 21, "metaal3")
            m.set(O + 31, O + ly, 21, "metaal3")
        if with_column:
            m.box(O, O, 0, O + 2, O + 2, 22, "metaal3")
        return m
    return fn


# ------------------------------------------------------------------ pillars

def pillar_tile(kind):
    """Free-standing storey-high pillar in the tile centre: kind "klassiek" (fluted),
    "beton" (square concrete), "baksteen" (brick with stone cap) or "staal" (steel H-profile).
    """
    def fn():
        m = V(W, W, HGT)
        c = W / 2
        for z in range(HGT):
            if kind == "klassiek":
                base = z < 2 or z > 21
                if base:
                    m.box(int(c - 3), int(c - 3), z, int(c + 3), int(c + 3), z + 1, "natuursteen1")
                else:
                    r = 2.2 - (z - 2) * 0.012   # slight entasis
                    for y in range(W):
                        for x in range(W):
                            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                            if d <= r:
                                ang = math.atan2(y - c, x - c)
                                flute = int((ang + 4) * 8 / math.pi) % 2 == 0 and d > r - 0.8
                                m.set(x, y, z, "natuursteen2" if flute else "natuursteen1")
            elif kind == "beton":
                m.box(int(c - 2), int(c - 2), z, int(c + 2), int(c + 2), z + 1, "beton1" if z % 12 else "beton_donker")
            elif kind == "baksteen":
                m.box(int(c - 3), int(c - 3), z, int(c + 3), int(c + 3), z + 1,
                      lambda x, y, zz: _bond(["baksteen1", "baksteen2", "baksteen3"], x, y, zz, 240))
                if z == HGT - 1:
                    m.box(int(c - 4), int(c - 4), z, int(c + 4), int(c + 4), z + 1, "natuursteen2")
            elif kind == "staal":
                # H-profile: web along y, two flanges
                m.box(int(c - 1), int(c - 2), z, int(c + 1), int(c + 2), z + 1, "metaal3")
                m.box(int(c - 2), int(c - 2), z, int(c + 2), int(c - 1), z + 1, "metaal3")
                m.box(int(c - 2), int(c + 1), z, int(c + 2), int(c + 2), z + 1, "metaal3")
        return m
    return fn


def arcade(kind):
    """Arcade (colonnade) tile: slab at z 21-23 on two front columns; "klassiek" adds an arch, else concrete."""
    def fn():
        b = Bld("klassiek_rood" if kind == "klassiek" else "kantoor_beton", "zuilengang" + kind, HGT)
        m = b.m
        mat = "natuursteen1" if kind == "klassiek" else "beton1"
        m.box(O, O, 21, O + S, O + S, 24, mat)
        for (lx, ly) in ((4, 4), (28, 4)):
            if kind == "klassiek":
                for z in range(0, 21):
                    m.cyl(O + lx, O + ly, 1.8 if 1 < z < 19 else 2.6, z, z + 1, mat)
            else:
                m.box(O + lx - 2, O + ly - 2, 0, O + lx + 2, O + ly + 2, 21, mat)
        if kind == "klassiek":
            for lx in range(4, 29):
                dx = lx + 0.5 - 16
                z = int(20 - max(0, 1 - (dx / 12.0) ** 2) * 5)
                for zz in range(z, 21):
                    m.set(O + lx, O + 3, zz, mat)
                    m.set(O + lx, O + 4, zz, mat)
        return m
    return fn


# ------------------------------------------------------------------ registration

def _reg_facades(style, pieces):
    """Register one single-facade block tile per (name, facade fn) in `pieces`."""
    base = f"gebouwen/{style}/{style}_"
    for name, f in pieces.items():
        register(base + name, make_block(style, [("v", f)]))


def reg_style(style, pieces, corners, roofs):
    """Register a complete style under gebouwen/<style>/<style>_<name>.

    pieces:  {name: facade fn} -> one block per piece with that facade on the front.
    corners: [(name, front_piece, right_piece)] -> corner blocks (front + right facade).
    roofs:   {name: tile factory} registered as-is. Also registers a blank "blok_dicht" block.
    """
    base = f"gebouwen/{style}/{style}_"
    _reg_facades(style, pieces)
    for name, a, c in corners:
        register(base + name, make_block(style, [("v", pieces[a]), ("r", pieces[c])]))
    register(base + "blok_dicht", make_block(style, []))
    for name, fn in roofs.items():
        register(base + name, fn)


def flat_roofs(style, extras=True):
    """Standard flat roof set: middle, edge (front), corner (front+right), opposite and end.

    `extras` is unused (kept for call compatibility).
    """
    return {
        "dak_plat_midden": flat_roof(style, ""), "dak_plat_rand": flat_roof(style, "v"), "dak_plat_hoek": flat_roof(style, "vr"),
        "dak_plat_tegenover": flat_roof(style, "va"), "dak_plat_eind": flat_roof(style, "var"),
    }


def pitched_roofs(style):
    """Standard pitched roof set (lean-to, corners, dormer, chimney, gable, hipped, gable corner)."""
    return {
        "dak_schuin": pitched(style, style + "s", H_SLOPE),
        "dak_schuin_hoek_buiten": pitched(style, style + "hb", H_CORNER_OUT),
        "dak_schuin_hoek_binnen": pitched(style, style + "hi", H_CORNER_IN),
        "dak_schuin_dakkapel": pitched(style, style + "dk", H_SLOPE, x_dormer),
        "dak_schuin_schoorsteen": pitched(style, style + "sc", H_SLOPE, x_chimney),
        "dak_zadel": pitched(style, style + "z", H_GABLE),
        "dak_zadel_schild": pitched(style, style + "zs", H_GABLE_HIP),
        "dak_zadel_hoek": pitched(style, style + "zh", H_GABLE_CORNER),
    }


def _pitched_and_flat(style):
    """pitched_roofs followed by flat_roofs (dict order = registration order)."""
    r = pitched_roofs(style)
    r.update(flat_roofs(style))
    return r


def with_shops(pieces):
    """Copy of `pieces` with all SHOP_PIECES appended."""
    p = dict(pieces)
    p.update(SHOP_PIECES)
    return p


def _corner(*names):
    """Corner entries using the same piece on both faces: (name + "_hoek", name, name)."""
    return [(n + "_hoek", n, n) for n in names]


def _all_faces(style, f):
    """Block with facade piece f on all four faces (tower storeys)."""
    return make_block(style, [(face, f) for face in "vral"])


# Placeholder facades. They must stay lambdas: their __name__ "<lambda>" is part of the seed.
_BLANK = lambda b, f: None              # noqa: E731
_PLINTH_ONLY = lambda b, f: b.plinth(f, 1)  # noqa: E731


# 1930s
reg_style("jaren30",
          with_shops({"bg_portiek": y30_gf_porch, "bg_raam": y30_gf_window, "bg_winkel": f_gf_shop,
                      "bg_winkel_luifel": f_gf_shop_awning, "verd_raam": y30_up_window, "verd_erker": y30_up_bay,
                      "verd_balkon": y30_up_balcony, "verd_trappenhuis": y30_up_stairwell}),
          _corner("bg_raam", "verd_raam")
          + [("verd_erker_hoek", "verd_erker", "verd_raam"), ("bg_winkel_hoek", "bg_winkel", "bg_raam"),
             ("bg_cafe_hoek", "bg_cafe", "bg_raam")],
          _pitched_and_flat("jaren30"))

# 1960s: corners pair each piece with a blank side wall
_p = {"bg_deur": y60_gf_door, "bg_raam": y60_gf_window, "bg_berging": y60_gf_storage, "verd_raam": y60_up_window,
      "verd_raam_klein": y60_up_window_small, "verd_galerij_deur": y60_gallery_door, "verd_galerij_raam": y60_gallery_window,
      "verd_balkon": y60_up_balcony, "verd_dicht": _BLANK}
reg_style("jaren60", _p,
          [(n + "_hoek", n, "verd_dicht") for n in ("bg_raam", "bg_deur", "verd_raam", "verd_raam_klein",
                                                     "verd_galerij_deur", "verd_galerij_raam")],
          _pitched_and_flat("jaren60"))

# gallery flat: corners pair each piece with the gable end
_r = flat_roofs("galerijflat")
_r["dak_liftopbouw"] = flat_roof("galerijflat", "", lambda b: b.m.box(O + 8, O + 8, 1, O + 24, O + 24, 14, wall_flat60))
reg_style("galerijflat",
          {"bg_entree": flat_gf_entrance, "bg_bergingen": flat_gf_storage, "verd_galerij": flat_gallery,
           "verd_balkons": flat_balconies, "verd_trappenhuis": flat_stairwell, "verd_kopgevel": flat_gable_end},
          [(n + "_hoek", n, "verd_kopgevel") for n in ("verd_galerij", "verd_balkons", "bg_bergingen", "bg_entree")],
          _r)

# modern apartment
_r = flat_roofs("appartement_modern")
_r["dak_daktuin"] = flat_roof("appartement_modern", "v", x_roof_terrace_flat)
reg_style("appartement_modern",
          {"bg_entree": apt_gf_entrance, "bg_glas": f_office_gf_glass, "verd_glas": apt_up_glass, "verd_loggia": apt_up_loggia,
           "verd_balkon": lambda b, f: b.balcony_modern(f), "verd_paneel": apt_up_panel, "verd_raam_groot": apt_up_large,
           "verd_raam_klein": apt_up_small},
          _corner("verd_glas") + [("verd_balkon_hoek", "verd_balkon", "verd_glas")]
          + _corner("bg_glas", "verd_raam_groot", "verd_raam_klein") + [("verd_loggia_hoek", "verd_loggia", "verd_paneel")],
          _r)

# townhouses
_r = pitched_roofs("herenhuis_1600")
_r.update({"top_lijstgevel": cornice_facade_top("herenhuis_1600", False), "top_lijstgevel_fronton": cornice_facade_top("herenhuis_1600", True),
           "gevel_klok": gable_top("herenhuis_1600", "klok"), "gevel_hals": gable_top("herenhuis_1600", "hals"),
           "dak_plat_midden": flat_roof("herenhuis_1600", "")})
reg_style("herenhuis_1600",
          {"bg_deur": h1600_gf_door, "bg_raam": h1600_gf_window, "verd_raam": h1600_up_window, "verd_balkon": h1600_up_balcony},
          _corner("bg_raam", "verd_raam"), _r)

_r = pitched_roofs("herenhuis_1900")
_r.update({"dak_mansarde_rand": mansard("herenhuis_1900", "v"), "dak_mansarde_hoek": mansard("herenhuis_1900", "vr"),
           "dak_mansarde_tegenover": mansard("herenhuis_1900", "va"), "gevel_tuit": gable_top("herenhuis_1900", "tuit"),
           "dak_plat_midden": flat_roof("herenhuis_1900", "")})
reg_style("herenhuis_1900",
          with_shops({"bg_deur": h1900_gf_door, "bg_raam_boog": h1900_gf_window_arch, "verd_raam_boog": h1900_up_window_arch,
                      "verd_erker": h1900_up_bay, "verd_balkon": h1600_up_balcony}),
          _corner("bg_raam_boog", "verd_raam_boog") + [("verd_erker_hoek", "verd_erker", "verd_raam_boog")], _r)


# offices: shared piece set plus one style-specific facade
def _office_crown(b):
    """Roof-edge crown: vertical frame-coloured fins every 4 voxels on the front."""
    for u in range(0, S, 4):
        b.rect("v", u, u + 1, 0, 16, -1, 0, b.st["frame"])


for _st, _k, _f in (("kantoor_80", "verd_spiegelband", o80_mirror_band),
                    ("kantoor_2000", "verd_zonwering", o2000_sun_shading),
                    ("kantoor_modern", "verd_lamellen", om_louvres)):
    _r = flat_roofs(_st)
    _r["dak_installatie"] = flat_roof(_st, "", x_hvac)
    _r["dak_installatie_rand"] = flat_roof(_st, "v", x_hvac)
    _r["dak_kroon_rand"] = flat_roof(_st, "v", _office_crown)
    reg_style(_st,
              {"bg_entree": f_office_gf_entrance, "bg_glas": f_office_gf_glass, "verd_vliesgevel": f_office_curtain_wall,
               "verd_band": f_office_band, "verd_raam_groot": office_large, "verd_raam_klein": office_small, _k: _f},
              _corner("bg_glas") + [("bg_entree_hoek", "bg_entree", "bg_glas")]
              + _corner("verd_vliesgevel", "verd_band", _k, "verd_raam_groot", "verd_raam_klein"),
              _r)

# museums
reg_style("museum_klassiek",
          {"bg_zuilen": mc_gf_columns, "bg_raam_boog": mc_gf_window_arch, "verd_raam_boog": mc_up_window_arch, "verd_relief": mc_up_relief},
          _corner("bg_raam_boog", "verd_raam_boog", "verd_relief"),
          {"top_fronton": mc_pediment("museum_klassiek"), "dak_koepel": dome("museum_klassiek"), "dak_koepel_3x3": dome("museum_klassiek", True),
           "dak_kroonlijst_rand": flat_roof("museum_klassiek", "v", cornice=True), "dak_kroonlijst_hoek": flat_roof("museum_klassiek", "vr", cornice=True),
           "dak_plat_midden": flat_roof("museum_klassiek", "")})

_r = flat_roofs("museum_modern")
_r["dak_overstek"] = mm_roof_overhang("museum_modern")
reg_style("museum_modern",
          {"bg_entree": mm_gf_entrance, "bg_dicht": mm_up_blank, "verd_lichtstrook": mm_up_light_strip, "verd_dicht": mm_up_blank},
          _corner("verd_lichtstrook", "verd_dicht") + [("bg_entree_hoek", "bg_entree", "bg_dicht")], _r)

# churches
for _st in ("kerk_baksteen", "kerk_steen"):
    _r = pitched_roofs(_st)
    _r["dak_plat_midden"] = flat_roof(_st, "")
    _r.update({"gevel_spits": gable_top(_st, "tuit"),
               "toren_portaal": _all_faces(_st, church_tower_portal),
               "toren_raam": _all_faces(_st, church_tower_window),
               "toren_klok": _all_faces(_st, church_tower_clock),
               "toren_galmgat": _all_faces(_st, church_tower_louvre),
               "toren_spits_onder": tower_spire(_st, "onder"), "toren_spits_boven": tower_spire(_st, "boven"),
               "toren_pinakels": tower_pinnacles(_st), "luchtboog": flying_buttress(_st)})
    reg_style(_st,
              {"bg_portaal": church_gf_portal, "bg_spitsraam": church_gf_lancet, "verd_spitsraam": church_up_lancet,
               "verd_roosvenster": church_up_rose, "verd_steunbeer": church_buttress, "verd_dicht": _BLANK},
              _corner("verd_spitsraam", "bg_spitsraam"), _r)

_r = flat_roofs("kerk_modern")
_r.update({"dak_lessenaar": pitched("kerk_modern", "lessenaar", lambda px, py: py * 0.5),
           "toren_beton": mch_tower("kerk_modern", False), "toren_beton_klok": mch_tower("kerk_modern", True)})
reg_style("kerk_modern",
          {"bg_entree": mch_gf_entrance, "bg_dicht": _PLINTH_ONLY, "verd_spleet": mch_up_slit, "verd_kruis": mch_up_cross},
          _corner("verd_spleet") + [("bg_entree_hoek", "bg_entree", "bg_dicht")], _r)

# school
_r = flat_roofs("school")
_r["dak_zonnepanelen"] = flat_roof("school", "", x_solar_panels)
reg_style("school", {"bg_entree": school_gf_entrance, "bg_raam": school_gf_window, "verd_raam": school_up_window},
          _corner("bg_raam", "verd_raam") + [("bg_entree_hoek", "bg_entree", "bg_raam")], _r)

# government
_r = pitched_roofs("overheid")
_r.update({"top_fronton": mc_pediment("overheid"), "top_naambord": gov_name("overheid"),
           "toren_klok": _all_faces("overheid", church_tower_clock),
           "toren_spits_onder": tower_spire("overheid", "onder"), "toren_spits_boven": tower_spire("overheid", "boven"),
           "dak_plat_midden": flat_roof("overheid", "")})
reg_style("overheid",
          {"bg_entree": gov_gf_entrance, "bg_raam": lambda b, f: (b.plinth(f, 3), gov_up_window_tall(b, f)),
           "verd_raam_hoog": gov_up_window_tall, "verd_balkon": gov_up_balcony},
          _corner("bg_raam", "verd_raam_hoog"), _r)

# barns
for _st in ("schuur_zwart", "schuur_rood"):
    reg_style(_st, {"bg_deur_groot": barn_gf_door, "bg_raam": barn_gf_window, "verd_hooideur": barn_hayloft, "bg_dicht": _PLINTH_ONLY},
              _corner("bg_raam") + [("bg_deur_groot_hoek", "bg_deur_groot", "bg_raam")], pitched_roofs(_st))

# the original classic/modern styles also get the shop / hospitality pieces
for _st in ("klassiek_rood", "klassiek_donker", "klassiek_geel", "modern_wit", "modern_donker", "modern_hout"):
    _reg_facades(_st, SHOP_PIECES)


def _deck_variant(st, floor, edges):
    """Flat roof of style `st` built with a temporary roof_deck `floor` (restored afterwards).

    The style's original roof_deck is captured now (at registration), as before.
    """
    orig = STYLES[st].get("roof_deck")

    def fn():
        STYLES[st]["roof_deck"] = floor
        try:
            return flat_roof(st, edges)()
        finally:
            if orig is None:
                STYLES[st].pop("roof_deck", None)
            else:
                STYLES[st]["roof_deck"] = orig
    return fn


# extra roof decks (bitumen / gravel) for all flat-roofed styles
for _st in ("modern_wit", "modern_donker", "modern_hout", "kantoor_glas", "kantoor_beton", "jaren60", "galerijflat",
            "appartement_modern", "kantoor_80", "kantoor_2000", "kantoor_modern", "school", "jaren30"):
    for _kind, _floor in (("bitumen", ("bitumen1", "bitumen2")), ("grind", ("dakgrind1", "dakgrind2"))):
        for _e, _edge_name in (("", "midden"), ("v", "rand"), ("vr", "hoek")):
            register(f"gebouwen/{_st}/{_st}_dak_{_kind}_{_edge_name}", _deck_variant(_st, _floor, _e))

# large and small office windows for the original office styles too
for _st in ("kantoor_glas", "kantoor_beton"):
    _reg_facades(_st, {"verd_raam_groot": office_large, "verd_raam_klein": office_small})

# halls, canopies and pillars
for _hs in HALL_STYLES:
    _base = f"gebouwen/hallen/{_hs}_"
    register(_base + "wand", hall(_hs, "v", roof=False))
    register(_base + "wand_dak", hall(_hs, "v", roof=True))
    register(_base + "wand_deur_dak", hall(_hs, "v", roof=True, door=True))
    register(_base + "hoek", hall(_hs, "vr", roof=False))
    register(_base + "hoek_dak", hall(_hs, "vr", roof=True))
    register(_base + "dak", hall(_hs, "", roof=True))
    register(_base + "dak_kolom", hall(_hs, "", roof=True, columns=((0, 0),)))
register("gebouwen/overkapping/overkapping_glas", canopy(False))
register("gebouwen/overkapping/overkapping_glas_kolom", canopy(True))
for _k in ("klassiek", "beton", "baksteen", "staal"):
    register(f"gebouwen/pilaren/pilaar_{_k}", pillar_tile(_k))
register("gebouwen/pilaren/zuilengang_klassiek", arcade("klassiek"))
register("gebouwen/pilaren/zuilengang_beton", arcade("beton"))
