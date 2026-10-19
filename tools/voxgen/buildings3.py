"""Building extension 3: roof covering types (incl. truncated roofs), battlements,
a stackable radio tower, a multi-storey car park and a 1960s house with a
ground-floor bay window.

Builds on the toolkit in buildings.py (Bld, pitched, make_block, ...) and
registers its tiles under gebouwen/... via common.register; generate.py writes
them out. SHAPES (roof height functions by name) is reused by extras5.
Canvas conventions as in buildings.py: 48 x 48 canvas, 32 x 32 block at
offset O, 24 voxels per storey, front = y = O side, z up.
"""
from common import register, tile, text_pixels
from vox import V, mix, pick
from buildings import (Bld, STYLES, S, O, W, HGT, brick, make_block, pitched, H_SLOPE, H_CORNER_OUT,
                       H_CORNER_IN, H_GABLE, H_GABLE_HIP, H_GABLE_CORNER, H_GABLE_T, x_dormer, x_chimney)
import buildings2  # noqa: F401  (defines the jaren30 / jaren60 styles used below)

# ------------------------------------------------------------------ roof covering types

# covering name (tile folder) -> roof colours (see STYLES "roof")
ROOF_TYPES = {
    "pannen_rood": ("pan_rood1", "pan_rood2", "pan_rood3"),
    "pannen_oranje": ("pan_oranje1", "pan_oranje2", "pan_rood3"),
    "pannen_zwart_geglazuurd": ("pan_zwart1", "pan_zwart2", "pan_zwart3"),
    "pannen_antraciet": ("pan_antraciet1", "pan_antraciet2", "pan_zwart1"),
    "leisteen": ("leisteen1", "leisteen2", "leisteen1"),
    "riet": ("riet_dak1", "riet_dak2", "riet_dak1"),
    "golfplaat": ("golfplaat1", "golfplaat2", "golfplaat1"),
    "zink": ("zink1", "zink2", "zink1"),
    "koper": ("koper", "koper", "zink1"),
}

TRUNCATE_AT = 22  # height (in tile units, see pitched()) at which a roof is truncated


def cap(fn, top=TRUNCATE_AT):
    """Truncate roof height function fn at `top` (flat top instead of a ridge)."""
    return lambda px, py: min(fn(px, py), top)


# roof shape name (tile name suffix) -> height function for pitched()
SHAPES = {
    "schuin": H_SLOPE, "schuin_hoek_buiten": H_CORNER_OUT, "schuin_hoek_binnen": H_CORNER_IN,
    "zadel": H_GABLE, "zadel_schild": H_GABLE_HIP, "zadel_hoek": H_GABLE_CORNER, "zadel_t": H_GABLE_T,
    "schuin_afgeplat": cap(H_SLOPE), "schuin_afgeplat_hoek_buiten": cap(H_CORNER_OUT),
    "schuin_afgeplat_hoek_binnen": cap(H_CORNER_IN), "zadel_afgeplat": cap(H_GABLE),
    "piramide": lambda px, py: 2 * min(px, 32 - px, py, 32 - py),
    "lessenaar": lambda px, py: py * 0.5,   # shallow lean-to
}

# One "dak_<covering>" style per covering; every shape plus a dormer and a chimney variant.
for _kind, _colors in ROOF_TYPES.items():
    _st = "dak_" + _kind
    STYLES[_st] = dict(family="dak", wall=brick(["baksteen1", "baksteen2", "baksteen3"], 500), frame="kozijn_wit",
                       doors=["deur_groen"], plinth="natuursteen2", trim="natuursteen1", roof=_colors, glass="glas1",
                       shop="kozijn_wit", cap="zink1")
    _base = f"gebouwen/daken/{_kind}/{_kind}_"
    for _shape, _hf in SHAPES.items():
        register(_base + _shape, pitched(_st, _st + _shape, _hf))
    register(_base + "schuin_dakkapel", pitched(_st, _st + "dk", H_SLOPE, x_dormer))
    register(_base + "schuin_schoorsteen", pitched(_st, _st + "sc", H_SLOPE, x_chimney))


# truncated roofs for the classic and 1930s/1960s styles as well
for _st in ("klassiek_rood", "klassiek_donker", "klassiek_geel", "jaren30", "jaren60"):
    for _shape in ("schuin_afgeplat", "schuin_afgeplat_hoek_buiten", "schuin_afgeplat_hoek_binnen", "zadel_afgeplat"):
        register(f"gebouwen/{_st}/{_st}_dak_{_shape}", pitched(_st, _st + _shape, SHAPES[_shape]))


# ------------------------------------------------------------------ battlements

def battlements(style, edges):
    """Return a tile function for a flat roof with crenellated parapets on the
    faces in `edges` (merlons 4 voxels wide, every other 4)."""
    def fn():
        b = Bld(style, "kantelen" + edges, 16)
        m = b.m
        for ly in range(S):
            for lx in range(S):
                m.set(O + lx, O + ly, 0, pick(["zink1", "natuursteen3"], lx, ly, 0, 501))
        for face in edges:
            for u in range(S):
                merlon = (u // 4) % 2 == 0
                for d in range(0, 3):
                    for z in range(0, 10 if merlon else 5):
                        b.put(face, u, z, d, b.st["wall"])
                b.put(face, u, 4, -1, b.st["trim"])
        return m
    return fn


for _st in ("klassiek_rood", "klassiek_donker", "kerk_baksteen", "kerk_steen", "overheid", "herenhuis_1600", "museum_klassiek"):
    for _e, _n in (("v", "rand"), ("vr", "hoek"), ("varl", "toren")):
        register(f"gebouwen/{_st}/{_st}_dak_kantelen_{_n}", battlements(_st, _e))


# ------------------------------------------------------------------ radio tower (stackable, 3 m per piece)

def radio_tower(part):
    """Return a tile function for a lattice radio mast piece.

    part: "voet" (tapering base), "segment" (stackable middle) or "top"
    (48 high: antenna, dishes and aviation lights). Red/white legs, a ring
    every 6 voxels and diagonal bracing in between.
    """
    def fn():
        hgt = 48 if part == "top" else HGT
        m = V(W, W, hgt)
        c = W / 2
        half = {"voet": 10, "segment": 6, "top": 6}[part]
        for z in range(0, HGT):
            hs = half if part != "voet" else 10 - z * 4 / 24.0
            for (sx, sy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                m.set(c + sx * hs, c + sy * hs, z, "bord_rood" if (z // 6) % 2 else "bord_wit")
            if z % 6 == 0:
                for i in range(int(-hs), int(hs) + 1):
                    for (a, b_) in ((i, -hs), (i, hs), (-hs, i), (hs, i)):
                        m.set(c + a, c + b_, z, "metaal3")
            k = z % 6
            for i in range(int(hs * 2)):
                t = -hs + i
                if abs(t - (-hs + k * 2 * hs / 6)) < 1:
                    for (a, b_) in ((t, -hs), (t, hs), (-hs, t), (hs, t)):
                        m.set(c + a, c + b_, z, "metaal3")
        if part == "top":
            for z in range(HGT, 46):
                m.set(c, c, z, "metaal3")
                m.set(c - 1, c, z, "metaal3")
            for z in (28, 36):
                for (dx, dy) in ((-4, 0), (4, 0), (0, -4), (0, 4)):
                    m.cyl(c + dx, c + dy, 1.5, z, z + 3, "stuc1")
            m.set(c, c, 46, "signaal_rood")
            m.set(c - 1, c, 46, "signaal_rood")
            m.set(c + 6, c + 6, 23, "signaal_rood")
            m.set(c - 6, c - 6, 23, "signaal_rood")
        return m
    return fn


for _p in ("voet", "segment", "top"):
    register(f"gebouwen/overig/radiotoren_{_p}", radio_tower(_p))


# ------------------------------------------------------------------ car park (hollow, open decks)

GARAGE_CONCRETE = mix("beton1", "beton2", "beton3", seed=502)


def garage(kind, edges=""):
    """Return a tile function for one storey of a multi-storey car park.

    kind: "dek" (deck with lights), "dak" (top deck with a lamp post),
    "inrit" (deck with an entrance and a P sign at the front) or "helling"
    (ramp rising from front to back). edges: faces that get a parapet with a
    rail.
    """
    def fn():
        b = Bld("kantoor_beton", "garage" + kind + edges, HGT)
        m = b.m
        if kind != "helling":
            # deck: concrete slab with asphalt, marking lines at lx = 0 and ly = 10
            for ly in range(S):
                for lx in range(S):
                    m.set(O + lx, O + ly, 0, GARAGE_CONCRETE)
                    m.set(O + lx, O + ly, 1, "markering" if lx == 0 and ly > 8 else "asfalt2")
            for lx in range(S):
                m.set(O + lx, O + 10, 1, "markering")
        else:
            for ly in range(S):
                zt = int(ly * 24 / 32)
                for lx in range(S):
                    for z in range(max(0, zt - 1), zt + 2):
                        m.set(O + lx, O + ly, z, GARAGE_CONCRETE if z < zt + 1 else "asfalt2")
        # corner columns
        for (cx, cy) in ((0, 0), (30, 0), (0, 30), (30, 30)):
            m.box(O + cx, O + cy, 0, O + cx + 2, O + cy + 2, HGT, GARAGE_CONCRETE)
        for face in edges:
            for u in range(S):
                for z in range(2, 9):
                    b.put(face, u, z, 0, GARAGE_CONCRETE if z < 8 else "beton_donker")
                if u % 2 == 0:
                    for z in (14, 15):
                        b.put(face, u, z, 0, "metaal2")
        if kind == "inrit":
            # opening in the front, barrier, blue band with a "P" sign
            for u in range(4, 28):
                for z in range(2, 9):
                    b.put("v", u, z, 0, 0)
            for z in range(0, 7):
                b.put("v", 4, z, 1, "bord_geel")
            for u in range(4, 24):
                b.put("v", u, 6, 1, "bord_rood" if (u // 3) % 2 else "bord_wit")
            for u in range(4, 28):
                b.put("v", u, 22, -1, "bord_blauw")
                b.put("v", u, 23, -1, "bord_blauw")
            px, _ = text_pixels("P")
            b.rect("v", 12, 20, 16, 23, -1, 0, "bord_blauw")
            for (c, r) in px:
                b.put("v", 15 + c, 21 - r, -2, "bord_wit")
        if kind == "dak":
            # lamp post in the middle of the top deck
            for z in range(2, 20):
                m.set(O + 16, O + 16, z, "metaal3")
            m.set(O + 16, O + 16, 20, "lamp_wit")
        if kind in ("dek", "inrit"):
            # ceiling lights
            for lx in range(4, S, 8):
                m.set(O + lx, O + 16, 23, "lamp_wit")
                m.set(O + lx, O + 16, 22, "metaal3")
        return m
    return fn


for _k in ("dek", "dak"):
    for _e, _n in (("", "midden"), ("v", "rand"), ("vr", "hoek")):
        register(f"gebouwen/parkeergarage/parkeergarage_{_k}_{_n}", garage(_k, _e))
register("gebouwen/parkeergarage/parkeergarage_inrit", garage("inrit", ""))
register("gebouwen/parkeergarage/parkeergarage_helling", garage("helling", ""))
register("gebouwen/parkeergarage/parkeergarage_helling_rand", garage("helling", "l"))


@tile("gebouwen/parkeergarage/parkeergarage_trappenhuis")
def garage_stairwell():
    """Concrete stairwell block with a tall window on every side."""
    b = Bld("kantoor_beton", "garagetrap", HGT)
    b.body()
    for face in "vral":
        b.window(face, 10, 0, 12, 23, sill=False, lintel=False)
    return b.m


# ------------------------------------------------------------------ 1960s house with a ground-floor bay window

def y60_gf_bay(b, face):
    """Ground floor with a 5-voxel deep bay window across most of the facade."""
    b.plinth(face, 1)
    b.rect(face, 3, 29, 0, 16, -5, 0, b.st["wall"])
    b.rect(face, 2, 30, 16, 17, -6, 0, "kozijn_wit")
    b.window(face, 5, 3, 22, 12, sill=False, lintel=False, d0=-5)


register("gebouwen/jaren60/jaren60_bg_erker", make_block("jaren60", [("v", y60_gf_bay)]))
register("gebouwen/jaren30/jaren30_bg_erker", make_block("jaren30", [("v", y60_gf_bay)]))
