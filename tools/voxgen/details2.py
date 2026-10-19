"""More facade and roof details (``details/...`` tiles), extending details.py.

Registers roof installations (cooling units, air handlers, vents), solar panels and a
solar water heater, a loose dormer, sun shading (awnings, roller shutters, screens),
facade lettering (``facade_text``, also used by extras6), flags on wall poles for every
flag in props2.FLAGS, entrance steps for classic houses and garage door variants.

Facade parts are drawn on details.att() canvases with y = wd(m, d) (d = 0 against the
wall, front = y=0 side); roof parts use a plain V canvas. Sizes are in voxels of 12.5 cm,
z is up.
"""
import math

from common import register, tile, text_pixels
from vox import V
from details import att, att_box, wd, pole_flag, stripe, striped_cloth
from props2 import FLAGS


# ------------------------------------------------------------------ roof: installations and solar panels

@tile("details/dak/koelinstallatie")
def cooling_unit():
    """Rooftop cooling unit with six fans on top and a grille on the front."""
    m = V(24, 16, 10)
    m.box(0, 0, 0, 24, 16, 1, "metaal2")
    m.box(1, 1, 1, 23, 15, 7, "metaal1")
    for cx in (6, 12, 18):
        for cy in (5, 11):
            m.cyl(cx, cy, 2.6, 7, 8, "metaal_donker")
            m.set(cx, cy, 8, "metaal3")
            m.set(cx - 1, cy, 7, "rooster")
    for x in range(2, 23, 2):
        m.box(x, 0, 2, x + 1, 1, 6, "rooster")
    return m


@tile("details/dak/luchtbehandeling")
def air_handler():
    """Air-handling unit box with a vertical exhaust duct on the right side."""
    m = V(32, 12, 12)
    m.box(0, 2, 0, 28, 12, 9, "metaal1")
    m.box(0, 2, 9, 28, 12, 10, "metaal2")
    m.box(29, 7, 2, 30, 8, 7, "metaal3")
    m.cyl(30, 7, 2, 0, 11, "metaal3")
    for x in range(2, 26, 6):
        m.box(x, 1, 2, x + 4, 2, 7, "rooster")
    return m


@tile("details/dak/airco_buitenunit")
def ac_outdoor_unit():
    """Air-conditioning outdoor unit with a round fan grille on the front."""
    m = V(8, 6, 7)
    m.box(0, 1, 0, 8, 5, 6, "stuc1")
    for x in range(1, 7):
        for z in range(1, 5):
            if math.hypot(x + 0.5 - 4, z + 0.5 - 3) < 2.4:
                m.set(x, 0, z, "rooster" if (x + z) % 2 else "metaal2")
    return m


@tile("details/dak/ventilatiekap")
def vent_cap():
    """Round zinc ventilation pipe with a mushroom cap."""
    m = V(6, 6, 8)
    m.cyl(3, 3, 1.4, 0, 6, "zink1")
    m.cyl(3, 3, 2.6, 6, 7, "zink2")
    m.cyl(3, 3, 1.6, 7, 8, "zink2")
    return m


@tile("details/dak/zonnepanelen_schuin_rij")
def solar_panels_pitched():
    """Row of solar panels tilted towards the front on three A-frame supports."""
    m = V(32, 12, 8)
    for y in range(10):
        z = 1 + y // 2
        for x in range(32):
            m.set(x, y + 1, z, "metaal3" if x % 8 == 0 else "zonnepaneel")
    for x in (1, 15, 30):
        m.box(x, 1, 0, x + 1, 11, 1, "metaal2")
        m.box(x, 10, 0, x + 1, 11, 6, "metaal2")
    return m


@tile("details/dak/zonnepanelen_groot")
def solar_panels_large():
    """Flat 32x32 solar panel field for a full flat roof."""
    m = V(32, 32, 3)
    for y in range(32):
        for x in range(32):
            m.set(x, y, 1, "metaal3" if (x % 8 == 0 or y % 12 == 0) else "zonnepaneel")
        m.set(0, y, 0, "metaal2")
        m.set(31, y, 0, "metaal2")
    return m


@tile("details/dak/zonnepanelen_klein")
def solar_panels_small():
    """Small flat solar panel field (two panels)."""
    m = V(16, 12, 3)
    for y in range(12):
        for x in range(16):
            m.set(x, y, 1, "metaal3" if (x % 8 == 0 or y == 0) else "zonnepaneel")
    return m


@tile("details/dak/zonneboiler")
def solar_water_heater():
    """Solar water heater: tilted collector with a stainless storage tank behind it."""
    m = V(16, 12, 10)
    for y in range(10):
        z = 1 + y // 2
        for x in range(1, 15):
            m.set(x, y, z, "metaal3" if x in (1, 14) else ("glas_helder" if x % 2 else "metaal_donker"))
    m.box(1, 10, 7, 15, 12, 9, "rvs")
    return m


@tile("details/dak/dakkapel_los")
def dormer_single():
    """Free-standing dormer box with a zinc roof slab and a two-pane window on the front."""
    m = V(16, 12, 12)
    m.box(0, 0, 0, 16, 12, 10, "kozijn_wit")
    m.box(-1, -1, 10, 17, 13, 11, "zink1")
    m.box(2, 0, 2, 14, 1, 9, "glas1")
    m.box(8, 0, 2, 9, 1, 9, "kozijn_wit")
    return m


# ------------------------------------------------------------------ sun shading

def sun_shading(cols, width=24, depth=8, drop_arm=False):
    """Fabric sun shade against the wall, striped with ``cols`` in 3-voxel bands.

    drop_arm=False: folding-arm awning, nearly horizontal cloth with a valance (8 high).
    drop_arm=True: drop-arm awning, cloth sloping 1:1 down to the front with side arms (14 high).
    """
    m = att(width, depth, 14 if drop_arm else 8)
    hgt = m.sz
    if drop_arm:
        for d in range(depth):
            z = hgt - 1 - d
            for x in range(width):
                m.set(x, wd(m, d), z, stripe(cols, x))
        for x in (0, width - 1):
            for d in range(depth):
                m.set(x, wd(m, d), hgt - 2 - d, "metaal3")
    else:
        striped_cloth(m, cols, width, depth, hgt, 3)
    att_box(m, 0, width, 0, 1, hgt - 1, hgt, "metaal3")  # wall rail
    return m


register("details/zonwering/knikarmscherm_streep", lambda: sun_shading(["luifel_geel", "luifel_wit"]))
register("details/zonwering/knikarmscherm_groen", lambda: sun_shading(["luifel_groen"]))
register("details/zonwering/knikarmscherm_antraciet", lambda: sun_shading(["antraciet2"]))
register("details/zonwering/uitvalscherm_oranje", lambda: sun_shading(["luifel_oranje", "luifel_oranje", "luifel_wit"], 12, 6, True))
register("details/zonwering/uitvalscherm_blauw", lambda: sun_shading(["luifel_blauw", "luifel_wit"], 12, 6, True))


@tile("details/zonwering/rolluik")
def roller_shutter():
    """Metal roller shutter (window size) with its housing on top."""
    m = att(12, 1, 18)
    for z in range(18):
        c = "antraciet1" if z == 17 else ("metaal1" if z % 2 else "metaal2")
        att_box(m, 0, 12, 0, 1, z, z + 1, c)
    return m


@tile("details/zonwering/screen")
def screen():
    """Fabric window screen with dark side rails and housing."""
    m = att(12, 1, 18)
    for z in range(18):
        for x in range(12):
            m.set(x, wd(m, 0), z, "antraciet1" if (z == 17 or x in (0, 11)) else "antraciet2")
    return m


@tile("details/zonwering/markies")
def roll_awning():
    """Dutch 'markies': quarter-round striped awning, deepest at the top."""
    m = att(12, 4, 10)
    for d in range(4):
        r = 4 - d
        for z in range(10 - r * 2, 10):
            for x in range(12):
                m.set(x, wd(m, d), z, "luifel_rood" if (x // 2) % 2 else "luifel_wit")
    return m


# ------------------------------------------------------------------ facade lettering

WORDS = ["HOTEL", "THEATER", "BIOSCOOP", "STATION", "BAKKERIJ", "APOTHEEK", "ZWERVR", "MUSEUM", "SCHOOL",
         "RAADHUIS", "BIBLIOTHEEK", "ZWEMBAD", "SPORTHAL", "POLITIE", "MARKT", "CAFE", "HAVEN", "KERK"]


def facade_text(word, scale=2, letter="goud", plate=None, lit=False):
    """Facade lettering for ``word`` in the common 3x5 pixel font.

    scale: voxels per font pixel. letter: letter colour (``lamp_warm`` when lit=True).
    plate: optional backing plate colour on the wall layer; letters sit one layer in front
    of it. The canvas has a 2-voxel margin and an even width (so it centres on the grid).
    """
    px, (tw, th) = text_pixels(word)
    w = tw * scale + 4
    w += w % 2
    hgt = 5 * scale + 4
    m = att(w, 2, hgt)
    if plate:
        att_box(m, 0, w, 0, 1, 0, hgt, plate)
    c = "lamp_warm" if lit else letter
    for (col, row) in px:
        # font row 0 is the top line
        att_box(m, 2 + col * scale, 2 + (col + 1) * scale, 1, 2, 2 + (4 - row) * scale, 2 + (5 - row) * scale, c)
    return m


for _w in WORDS:
    register(f"details/tekst/tekst_{_w.lower()}", lambda w=_w: facade_text(w))
for _w in ("HOTEL", "THEATER", "BIOSCOOP", "CAFE", "ZWERVR"):
    register(f"details/tekst/lichtreclame_{_w.lower()}", lambda w=_w: facade_text(w, 2, plate="bord_zwart", lit=True))
for _w in ("BAKKER", "SLAGER", "KAAS", "BLOEMEN", "FIETSEN", "KAPPER"):
    register(f"details/tekst/bord_{_w.lower()}", lambda w=_w: facade_text(w, 1, "bord_wit", "deur_groen"))


# ------------------------------------------------------------------ flags on the facade

def facade_flag(colors):
    """Flag on a slanted wall pole; ``colors`` are the stripes from top to bottom."""
    return pole_flag(colors)


for _k, _c in FLAGS.items():
    register(f"details/gevel/vlag_{_k}", lambda c=_c: facade_flag(c))


@tile("details/gevel/vlag_regenboog_hangend")
def flag_rainbow_hanging():
    """Rainbow banner hanging flat against the wall from a rod, stripes vertical."""
    m = att(12, 2, 20)
    cols = ["vlag_rood", "vlag_oranje", "vlag_geel", "vlag_groen", "vlag_blauw", "vlag_paars"]
    for x in range(12):
        m.set(x, wd(m, 1), 19, "metaal3")
        for z in range(0, 19):
            m.set(x, wd(m, 1), z, cols[x // 2])
    return m


# ------------------------------------------------------------------ entrance steps for classic houses

def entry_steps(steps, width=12, handrail=False, landing=False):
    """Stone entrance steps: ``steps`` treads 2 voxels deep, each 1 voxel high.

    landing=True adds a 4-deep landing against the wall and widens the canvas by 4.
    handrail=True adds railings on both sides, 6 voxels above the treads.
    """
    lead = 4 if landing else 0
    depth = steps * 2 + lead
    m = att(width + lead, depth, steps + 8)
    w = m.sx

    def height(d):
        return steps if d < lead else steps - (d - lead) // 2

    for d in range(depth):
        hd = height(d)
        for x in range(w):
            for z in range(hd):
                m.set(x, wd(m, d), z, "natuursteen1" if z == hd - 1 else "natuursteen2")
    if handrail:
        for x in (0, w - 1):
            for d in range(depth):
                hd = height(d)
                m.set(x, wd(m, d), hd + 6, "metaal_donker")
                if d % 3 == 0:
                    for z in range(hd, hd + 6):
                        m.set(x, wd(m, d), z, "metaal_donker")
    return m


register("details/deuren/opstap_2_treden", lambda: entry_steps(2))
register("details/deuren/opstap_3_treden", lambda: entry_steps(3))
register("details/deuren/opstap_4_treden_leuning", lambda: entry_steps(4, handrail=True))
register("details/deuren/bordes_klassiek", lambda: entry_steps(4, 12, True, True))


# ------------------------------------------------------------------ garage doors

def garage_door(kind, width=24):
    """Garage door of ``kind``: kanteldeur (wooden up-and-over), sectionaal (sectional with
    windows), roldeur (roller door) or anything else = classic green double door."""
    m = att(width, 1, 17)
    for z in range(17):
        for x in range(width):
            edge = x in (0, width - 1) or z == 16
            if edge:
                c = "antraciet1"
            elif kind == "kanteldeur":
                c = "hout2" if (x // 2) % 2 else "hout1"
            elif kind == "sectionaal":
                c = "stuc1" if (z // 4) % 2 else "stuc2"
            elif kind == "roldeur":
                c = "metaal1" if z % 2 else "metaal2"
            else:
                c = "kozijn_groen" if not ((x == width // 2) or z in (5, 11)) else "kozijn_wit"
            m.set(x, wd(m, 0), z, c)
    if kind == "sectionaal":
        for x in range(3, width - 3, 3):
            m.set(x, wd(m, 0), 13, "glas2")
    return m


for _k in ("kanteldeur", "sectionaal", "roldeur", "dubbel_klassiek"):
    register(f"details/deuren/garagedeur_{_k}", lambda k=_k: garage_door(k))
