"""Facade details: loose parts placed against a facade or on a roof (``details/...`` tiles).

Registers awnings, windows, doors, balconies, roof parts (chimneys, solar panels, dishes)
and small facade items (lamps, signs, flags, ivy, gutters, ...). generate.py writes each
registered function's model to ``<OUT>/details/<group>/<name>.vox``.

Pivot = centre of the model. For facade parts the wall lies exactly on that centre: the
part sticks out to the front (y=0 side) and the rear half of the canvas stays empty, so
in the Details GridMap (0.5 m grid) a part can be put straight against a facade and
rotated around the wall plane. Draw such parts on ``att(width, depth, height)`` with
``y = wd(m, d)``, where d = 0 is the layer against the wall and d grows towards the
front. Sizes are in voxels of 12.5 cm; z is up.

Shared helpers used by other modules: ``att``, ``wd`` (details2, extras4, extras5) and
``pole_flag`` / ``striped_cloth`` (details2).
"""
from common import register, tile
from vox import V, pick, h


def att(width, depth, height):
    """Empty canvas for a facade part ``depth`` voxels deep; draw with y = wd(m, d)."""
    return V(width, depth * 2, height)


def wd(m, d):
    """Canvas y for depth layer ``d`` of an att() canvas (d = 0 touches the wall)."""
    return m.sy // 2 - 1 - d


def att_box(m, x0, x1, d0, d1, z0, z1, c):
    """Fill x in [x0, x1), depth layers d in [d0, d1), z in [z0, z1) of an att() canvas."""
    m.box(x0, wd(m, d1 - 1), z0, x1, wd(m, d0) + 1, z1, c)


def stripe(cols, x):
    """Colour of column ``x`` for cloth striped in bands of 3 voxels."""
    return cols[(x // 3) % len(cols)]


def striped_cloth(m, cols, width, depth, hgt, drop):
    """Striped cloth sloping down by 1 voxel per ``drop`` depth layers, plus a valance.

    The cloth starts at z = hgt - 1 against the wall; the valance hangs 2 voxels below the
    front edge (the lowest voxel only on even x, giving a scalloped edge).
    """
    for d in range(depth):
        z = hgt - 1 - d // drop
        for x in range(width):
            m.set(x, wd(m, d), z, stripe(cols, x))
    zl = hgt - 1 - (depth - 1) // drop
    for x in range(width):
        m.set(x, wd(m, depth - 1), zl - 1, stripe(cols, x))
        if x % 2 == 0:
            m.set(x, wd(m, depth - 1), zl - 2, stripe(cols, x))


def pole_flag(colors):
    """Flag on a slanted pole sticking out of the wall; ``colors`` are the stripes top to bottom."""
    m = att(2, 16, 24)
    for d in range(16):
        m.set(0, wd(m, d), d // 2 + 4, "metaal3")
    for d in range(5, 16):
        top = (d // 2 + 4) - 1
        for i, c in enumerate(colors):
            m.set(1, wd(m, d), top - i, c)
    return m


# ------------------------------------------------------------------ awnings

def awning(cols, width=32, depth=8, hgt=8):
    """Shop awning: striped cloth (see striped_cloth) with dark side arms and a wall rail."""
    m = att(width, depth, hgt)
    striped_cloth(m, cols, width, depth, hgt, 2)
    for x in (0, width - 1):
        for d in range(depth):
            m.set(x, wd(m, d), hgt - 2 - d // 2, "metaal_donker")
    att_box(m, 0, width, 0, 1, hgt - 1, hgt, "metaal_donker")
    return m


for _n, _c in {"rood": ["luifel_rood", "luifel_wit"], "groen": ["luifel_groen", "luifel_wit"],
               "blauw": ["luifel_blauw", "luifel_wit"], "geel": ["luifel_geel", "luifel_oranje"],
               "effen_rood": ["luifel_rood"], "effen_groen": ["luifel_groen"]}.items():
    register(f"details/luifels/luifel_{_n}", lambda c=_c: awning(c))
    register(f"details/luifels/luifel_{_n}_smal", lambda c=_c: awning(c, 16, 6, 6))


@tile("details/luifels/luifel_glas")
def canopy_glass():
    """Flat glass canopy in a metal frame with two diagonal braces."""
    m = att(32, 8, 4)
    for d in range(8):
        for x in range(32):
            m.set(x, wd(m, d), 3, "glas_helder" if 0 < x < 31 and d < 7 else "metaal3")
    for x in (2, 29):
        for d in range(8):
            m.set(x, wd(m, d), 3 - (7 - d) // 3, "metaal3")
    return m


@tile("details/luifels/luifel_kantoor")
def canopy_office():
    """Solid metal office canopy with downlights underneath."""
    m = att(32, 8, 4)
    att_box(m, 0, 32, 0, 8, 2, 4, "metaal3")
    for x in range(4, 30, 6):
        m.set(x, wd(m, 4), 1, "lamp_wit")
    return m


# ------------------------------------------------------------------ windows

def window(width, hgt, frame, muntins=True, sill="natuursteen1", glass="glas1"):
    """Framed window of ``width`` x ``hgt`` (frame included) with optional cross muntins and sill.

    The canvas adds a 1-voxel border; the sill (z = 0) spans the full width, 3 layers deep.
    """
    m = att(width + 2, 3, hgt + 2)
    for z in range(1, hgt + 1):
        for x in range(1, width + 1):
            edge = x in (1, width) or z in (1, hgt)
            muntin = muntins and (x == (width + 1) // 2 or z == hgt // 2 + 1)
            m.set(x, wd(m, 0), z, frame if (edge or muntin) else glass)
            if edge:
                m.set(x, wd(m, 1), z, frame)
    if sill:
        att_box(m, 0, width + 2, 0, 3, 0, 1, sill)
    return m


register("details/ramen/raam_klassiek", lambda: window(10, 16, "kozijn_wit"))
register("details/ramen/raam_klassiek_groen", lambda: window(10, 16, "kozijn_groen"))
register("details/ramen/raam_klassiek_klein", lambda: window(6, 8, "kozijn_wit"))
register("details/ramen/raam_modern", lambda: window(14, 16, "antraciet1", muntins=False, sill="zink1", glass="glas2"))
register("details/ramen/raam_modern_breed", lambda: window(26, 14, "antraciet1", muntins=False, sill="zink1", glass="glas2"))
register("details/ramen/raam_modern_staand", lambda: window(6, 20, "antraciet1", muntins=False, sill=None, glass="glas2"))


@tile("details/ramen/raam_rond")
def window_round():
    """Round window (oculus) with a cross and a stone surround."""
    m = att(10, 2, 10)
    for z in range(10):
        for x in range(10):
            d = ((x + 0.5 - 5) ** 2 + (z + 0.5 - 5) ** 2) ** 0.5
            if d < 3.4:
                m.set(x, wd(m, 0), z, "glas1" if not (x == 5 or z == 5) else "kozijn_wit")
            elif d < 5:
                m.set(x, wd(m, 0), z, "natuursteen1")
                m.set(x, wd(m, 1), z, "natuursteen1")
    return m


@tile("details/ramen/vensterbank")
def window_sill():
    """Stone window sill with a darker drip edge underneath."""
    m = att(12, 3, 2)
    att_box(m, 0, 12, 0, 3, 1, 2, "natuursteen1")
    att_box(m, 0, 12, 0, 1, 0, 1, "natuursteen2")
    return m


@tile("details/ramen/vensterbank_modern")
def window_sill_modern():
    """Thin zinc window sill."""
    m = att(16, 2, 1)
    att_box(m, 0, 16, 0, 2, 0, 1, "zink1")
    return m


@tile("details/ramen/luiken")
def shutters():
    """Pair of green shutters (4 voxels wide each) on either side of a 10-voxel gap."""
    m = att(18, 1, 16)
    for x in list(range(0, 4)) + list(range(14, 18)):
        for z in range(16):
            edge = x in (0, 3, 14, 17) or z in (0, 15)
            diag = (z % 8) == (x % 4) * 2
            m.set(x, wd(m, 0), z, "kozijn_groen" if (edge or not diag) else "kozijn_wit")
    return m


@tile("details/ramen/bloembak")
def flower_box():
    """Terracotta window box with leaves and randomly scattered flowers."""
    m = att(12, 3, 5)
    for x in range(12):
        for d in range(3):
            m.set(x, wd(m, d), 0, "terracotta2")
            m.set(x, wd(m, d), 1, "terracotta1")
            m.set(x, wd(m, d), 2, pick(["blad2", "blad4", "blad1"], x, d, 0, 1))
            if h(x, d, 0, 2) < 0.6:
                m.set(x, wd(m, d), 3, pick(["bloem_rood", "bloem_roze", "bloem_wit", "blad4"], x, d, 1, 3))
            if h(x, d, 1, 2) < 0.2:
                m.set(x, wd(m, d), 4, pick(["bloem_rood", "bloem_geel"], x, d, 2, 4))
    return m


# ------------------------------------------------------------------ doors

def door_detail(color, width=8, hgt=19, glass=False, frame="kozijn_wit", transom=True):
    """Front door of ``width`` x ``hgt`` in a frame, optional glass pane and transom window.

    Brass handle and letter slot are placed on the front layer (d = 1).
    """
    m = att(width + 2, 2, hgt + 1)
    for z in range(hgt + 1):
        for x in range(width + 2):
            edge = x in (0, width + 1) or z == hgt
            if edge:
                m.set(x, wd(m, 0), z, frame)
                m.set(x, wd(m, 1), z, frame)
            elif transom and z >= hgt - 4:
                m.set(x, wd(m, 0), z, frame if z == hgt - 4 else "glas1")
            else:
                pane = glass and 3 <= x <= width - 2 and hgt // 2 <= z < hgt - 6
                m.set(x, wd(m, 0), z, "glas1" if pane else color)
    m.set(width - 1, wd(m, 1), hgt // 2 - 1, "messing")
    m.set(width // 2 + 1, wd(m, 1), hgt // 2 - 2, "messing")
    return m


register("details/deuren/deur_klassiek_groen", lambda: door_detail("deur_groen"))
register("details/deuren/deur_klassiek_rood", lambda: door_detail("deur_rood"))
register("details/deuren/deur_klassiek_zwart", lambda: door_detail("deur_zwart"))
register("details/deuren/deur_klassiek_blauw", lambda: door_detail("deur_blauw"))
register("details/deuren/deur_modern_hout", lambda: door_detail("hout1", 8, 18, True, "antraciet1", False))
register("details/deuren/deur_modern_antraciet", lambda: door_detail("antraciet2", 8, 18, True, "antraciet1", False))
register("details/deuren/deur_dubbel", lambda: door_detail("deur_groen", 14, 20, True))


@tile("details/deuren/schuifdeur_glas")
def sliding_door():
    """Two-leaf glass sliding door in a metal frame."""
    m = att(18, 2, 18)
    for z in range(18):
        for x in range(18):
            edge = x in (0, 17) or z == 17 or x in (8, 9)
            m.set(x, wd(m, 0), z, "metaal3" if edge else "glas_helder")
            if edge:
                m.set(x, wd(m, 1), z, "metaal3")
    return m


@tile("details/deuren/garagedeur")
def garage_door():
    """Ribbed metal garage door."""
    m = att(24, 1, 16)
    for z in range(16):
        for x in range(24):
            edge = x in (0, 23) or z == 15
            m.set(x, wd(m, 0), z, "antraciet1" if edge else ("metaal1" if (z // 2) % 2 else "metaal2"))
    return m


@tile("details/deuren/stoeptrap")
def stoop_stairs():
    """Two-step stone stoop, 4 layers deep (top step against the wall)."""
    m = att(12, 4, 3)
    for d in range(4):
        for x in range(12):
            for z in range(3 - d // 2):
                m.set(x, wd(m, d), z, "natuursteen1" if z == 2 - d // 2 else "natuursteen2")
    return m


# ------------------------------------------------------------------ balconies

@tile("details/balkons/balkon_klassiek")
def balcony_classic():
    """Stone balcony slab with a wrought-iron railing on the front and sides."""
    m = att(24, 4, 10)
    for d in range(4):
        for x in range(24):
            m.set(x, wd(m, d), 0, "natuursteen1")
            m.set(x, wd(m, d), 1, "natuursteen2" if d == 3 or x in (0, 23) else 0)
    for x in range(24):
        m.set(x, wd(m, 3), 9, "metaal_donker")
        if x % 2 == 0:
            for z in range(1, 9):
                m.set(x, wd(m, 3), z, "metaal_donker")
        if x % 4 == 2:
            m.set(x, wd(m, 3), 5, "metaal_donker")
    for x in (0, 23):
        for d in range(4):
            m.set(x, wd(m, d), 9, "metaal_donker")
            if d % 2 == 0:
                for z in range(1, 9):
                    m.set(x, wd(m, d), z, "metaal_donker")
    return m


@tile("details/balkons/balkon_frans")
def balcony_french():
    """French balcony: flat railing directly against the window."""
    m = att(12, 1, 8)
    for x in range(12):
        m.set(x, wd(m, 0), 7, "metaal_donker")
        m.set(x, wd(m, 0), 0, "metaal_donker")
        if x % 2 == 0:
            for z in range(8):
                m.set(x, wd(m, 0), z, "metaal_donker")
    return m


@tile("details/balkons/balkon_modern")
def balcony_modern_detail():
    """Concrete balcony slab with a glass balustrade (front and sides) and metal handrail."""
    m = att(28, 8, 10)
    att_box(m, 0, 28, 0, 8, 0, 1, "beton1")
    att_box(m, 0, 28, 0, 8, 1, 2, "beton2")
    # front pane, then side panes (they share the corner voxels, same colours)
    att_box(m, 0, 28, 7, 8, 2, 9, "glas_helder")
    att_box(m, 0, 28, 7, 8, 9, 10, "metaal3")
    for x in (0, 27):
        att_box(m, x, x + 1, 0, 8, 2, 9, "glas_helder")
        att_box(m, x, x + 1, 0, 8, 9, 10, "metaal3")
    return m


@tile("details/balkons/balkon_hout")
def balcony_wood():
    """Wooden balcony: plank floor, front railing with balusters every 3 voxels, side rails."""
    m = att(24, 6, 9)
    for d in range(6):
        for x in range(24):
            m.set(x, wd(m, d), 0, "hout2" if x % 3 else "hout_donker1")
    for x in range(24):
        m.set(x, wd(m, 5), 8, "hout1")
        if x % 3 == 0:
            for z in range(1, 8):
                m.set(x, wd(m, 5), z, "hout1")
    for x in (0, 23):
        for d in range(6):
            m.set(x, wd(m, d), 8, "hout1")
    return m


# ------------------------------------------------------------------ roof parts (free-standing, no att canvas)

def _chimney_stack(m, z_cap, seed):
    """Brick shaft (1-voxel margin on all sides) up to ``z_cap`` with a full-width stone cap on top."""
    for z in range(z_cap):
        for y in range(1, m.sy - 1):
            for x in range(1, m.sx - 1):
                m.set(x, y, z, pick(["baksteen2", "baksteen4", "donkersteen1"], (x + y) // 2, z, 0, seed))
    m.box(0, 0, z_cap, m.sx, m.sy, z_cap + 1, "natuursteen2")


@tile("details/dak/schoorsteen")
def chimney():
    """Single brick chimney with a stone cap and a metal flue."""
    m = V(6, 6, 16)
    _chimney_stack(m, 14, 5)
    m.box(2, 2, 15, 4, 4, 16, "metaal_donker")
    return m


@tile("details/dak/schoorsteen_dubbel")
def chimney_double():
    """Wide brick chimney with two terracotta chimney pots."""
    m = V(10, 6, 18)
    _chimney_stack(m, 16, 6)
    for x in (3, 6):
        m.box(x, 2, 17, x + 1, 4, 18, "terracotta1")
    return m


@tile("details/dak/zonnepanelen")
def solar_panels():
    """Tilted solar panel array (rises towards the back) on two rows of legs."""
    m = V(32, 16, 6)
    for y in range(16):
        z = 1 + y // 4
        for x in range(32):
            m.set(x, y, z, "metaal3" if (x % 8 == 0 or y in (0, 15)) else "zonnepaneel")
        for x in (2, 29):
            for zz in range(z):
                m.set(x, y, zz, "metaal2")
    return m


@tile("details/dak/dakraam")
def skylight():
    """Flat roof window: dark frame with glass."""
    m = V(10, 12, 2)
    for y in range(12):
        for x in range(10):
            edge = x in (0, 9) or y in (0, 11)
            m.set(x, y, 0, "antraciet1")
            m.set(x, y, 1, "antraciet1" if edge else "glas1")
    return m


@tile("details/dak/schotel")
def satellite_dish():
    """Satellite dish on a wall arm (att canvas); the dish faces the front."""
    m = att(8, 6, 8)
    for z in range(8):
        for x in range(8):
            d = ((x + 0.5 - 4) ** 2 + (z + 0.5 - 4) ** 2) ** 0.5
            if d < 3.8:
                m.set(x, wd(m, 3 if d > 2.5 else 4), z, "stuc1")
    m.set(4, wd(m, 5), 4, "metaal2")
    for d in range(0, 3):
        m.set(4, wd(m, d), 3, "metaal2")
    return m


@tile("details/dak/antenne")
def antenna():
    """Old-fashioned TV antenna: mast with three cross bars."""
    m = V(8, 8, 20)
    m.box(4, 4, 0, 5, 5, 20, "metaal2")
    for z in (12, 15, 18):
        m.box(1, 4, z, 8, 5, z + 1, "metaal2")
    return m


# ------------------------------------------------------------------ small facade items

@tile("details/gevel/airco")
def air_con():
    """Wall-mounted air-conditioning unit with a round fan grille on the front."""
    m = att(8, 4, 6)
    att_box(m, 0, 8, 0, 4, 0, 6, "stuc1")
    for x in range(1, 7):
        for z in range(1, 5):
            dd = ((x + 0.5 - 4) ** 2 + (z + 0.5 - 3) ** 2) ** 0.5
            if dd < 2.2:
                m.set(x, wd(m, 3), z, "metaal_donker" if (x + z) % 2 else "metaal2")
    return m


@tile("details/gevel/regenpijp")
def downpipe():
    """One-storey zinc downpipe with brackets every 8 voxels."""
    m = att(2, 2, 24)
    for z in range(24):
        m.set(0, wd(m, 1), z, "zink2")
        m.set(1, wd(m, 1), z, "zink2")
        if z % 8 == 4:
            m.set(0, wd(m, 0), z, "metaal_donker")
    m.set(0, wd(m, 0), 0, "zink1")
    return m


@tile("details/gevel/buitenlamp")
def outdoor_lamp():
    """Classic lantern on a short wall bracket."""
    m = att(4, 3, 6)
    m.set(1, wd(m, 0), 3, "metaal_donker")
    m.set(2, wd(m, 0), 3, "metaal_donker")
    for z in range(1, 5):
        c = "lamp_warm" if 1 < z < 4 else "metaal_donker"
        for x in (1, 2):
            m.set(x, wd(m, 1), z, c)
            m.set(x, wd(m, 2), z, c)
    return m


@tile("details/gevel/buitenlamp_modern")
def outdoor_lamp_modern():
    """Flat modern wall light shining downwards."""
    m = att(4, 2, 4)
    for x in range(4):
        for z in range(4):
            m.set(x, wd(m, 0), z, "antraciet1")
        m.set(x, wd(m, 1), 0, "lamp_wit")
        m.set(x, wd(m, 1), 3, "antraciet1")
    return m


@tile("details/gevel/uithangbord")
def hanging_sign():
    """Shop sign hanging from an arm perpendicular to the wall."""
    m = att(2, 10, 12)
    att_box(m, 0, 2, 0, 10, 11, 12, "metaal_donker")
    for d in range(2, 10):
        for z in range(2, 10):
            edge = d in (2, 9) or z in (2, 9)
            c = "messing" if edge else ("bord_rood" if (d + z) % 5 else "bord_wit")
            m.set(0, wd(m, d), z, c)
            m.set(1, wd(m, d), z, c)
    # chains between arm and sign
    m.set(0, wd(m, 3), 10, "metaal_donker")
    m.set(0, wd(m, 8), 10, "metaal_donker")
    return m


@tile("details/gevel/vlag")
def flag():
    """Dutch flag on a slanted wall pole."""
    return pole_flag(["vlag_rood", "vlag_rood", "vlag_wit", "vlag_wit", "vlag_blauw", "vlag_blauw"])


@tile("details/gevel/klimop")
def ivy():
    """Ivy patch, densest at the bottom centre and thinning out upwards and sideways."""
    m = att(16, 2, 24)
    for z in range(24):
        for x in range(16):
            r = h(x, z, 0, 7)
            dens = 0.85 - z * 0.025 - abs(x - 8) * 0.03
            if r < dens:
                m.set(x, wd(m, 0), z, pick(["blad1", "blad3", "blad5", "haag1"], x, z, 0, 8))
                if r < dens * 0.4:
                    m.set(x, wd(m, 1), z, pick(["blad2", "blad1"], x, z, 1, 9))
    return m


@tile("details/gevel/muuranker")
def wall_anchor():
    """Cross-shaped iron wall anchor."""
    m = att(4, 1, 6)
    att_box(m, 2, 3, 0, 1, 0, 6, "metaal_donker")
    att_box(m, 0, 4, 0, 1, 3, 4, "metaal_donker")
    return m


@tile("details/gevel/hijsbalk")
def hoist_beam():
    """Canal-house hoist beam with a hook at the front end."""
    m = att(2, 8, 6)
    att_box(m, 0, 2, 0, 8, 4, 6, "hout_donker2")
    att_box(m, 0, 1, 7, 8, 1, 4, "metaal_donker")
    return m


@tile("details/gevel/brievenbus_muur")
def mailbox_wall():
    """Red wall-mounted letter box with a black slot."""
    m = att(4, 2, 6)
    for z in range(6):
        for x in range(4):
            m.set(x, wd(m, 0), z, "bord_rood")
            m.set(x, wd(m, 1), z, "bord_rood" if z < 5 else "bord_rood2")
    m.set(1, wd(m, 1), 4, "rubber")
    m.set(2, wd(m, 1), 4, "rubber")
    return m


@tile("details/gevel/huisnummer")
def house_number():
    """Blue enamel house-number plate with a white border."""
    m = att(6, 1, 4)
    for z in range(4):
        for x in range(6):
            m.set(x, wd(m, 0), z, "bord_blauw" if 0 < x < 5 and 0 < z < 3 else "bord_wit")
    m.set(2, wd(m, 0), 1, "bord_wit")
    m.set(3, wd(m, 0), 2, "bord_wit")
    return m


@tile("details/gevel/reclamebord")
def billboard():
    """Wide flat advertising board in a dark frame, four 7-voxel colour panels."""
    m = att(28, 1, 6)
    for z in range(6):
        for x in range(28):
            edge = x in (0, 27) or z in (0, 5)
            m.set(x, wd(m, 0), z, "metaal_donker" if edge else pick(["reclame1", "reclame2", "reclame3"], x // 7, 0, 0, 10))
    return m


@tile("details/gevel/dakgoot")
def roof_gutter():
    """Zinc roof gutter along a full tile width."""
    m = att(32, 2, 2)
    att_box(m, 0, 32, 1, 2, 0, 2, "zink1")
    att_box(m, 0, 32, 0, 1, 0, 1, "zink1")
    return m


@tile("details/gevel/kroonlijst")
def cornice():
    """White wooden cornice along a full tile width, with dentils underneath."""
    m = att(32, 3, 4)
    for x in range(32):
        for d in range(3):
            m.set(x, wd(m, d), 3, "kozijn_wit")
        m.set(x, wd(m, 0), 2, "kozijn_wit")
        m.set(x, wd(m, 1), 2, "kozijn_wit")
        if x % 2 == 0:
            m.set(x, wd(m, 0), 1, "kozijn_wit")
            m.set(x, wd(m, 0), 0, "kozijn_wit")
    return m
