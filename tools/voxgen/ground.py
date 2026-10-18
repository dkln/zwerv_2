"""Grond-tiles: wegen, stoepen, pleinen, natuur, water, spoor, tram, bruggen, hellingen.

Alle grond-tiles zijn 32x32 voxels (4x4 m). Het wegdek ligt op z=2, stoep/gras op z=3.
Een grond-verdieping in Godot is 1 m (8 voxels) hoog, zodat hellingen precies
1 verdieping stijgen en je tiles kunt stapelen (bruggen, dijken, grachten).
"""
import math

from common import T, ROAD, WALK, FLOOR, tile, register, PICTO, text_pixels
from palette import P
from vox import V, mix, blocky, pick, h, col

ASFALT = mix("asfalt1", "asfalt2", "asfalt3", "asfalt4", weights=[4, 4, 2, 1], seed=1)
ASFALT_OUD = mix("asfalt1", "asfalt2", "asfalt3", "asfalt4", "asfalt_reparatie", weights=[3, 3, 2, 2, 1], seed=2)
FIETS = mix("fietsasfalt1", "fietsasfalt2", "fietsasfalt3", weights=[4, 3, 2], seed=3)
BUS = mix("busbaan1", "busbaan2", seed=4)
MARK = mix("markering", "markering", "markering2", seed=5)
TEGEL = blocky(["tegel1", "tegel2", "tegel3", "tegel4"], size=3, seed=6)
BAND = mix("band1", "band2", seed=7)
GOOT = mix("goot1", "goot2", seed=8)
GRAS = mix("gras1", "gras2", "gras3", "gras4", "gras5", weights=[4, 4, 3, 2, 2], seed=9)
AARDE = mix("aarde1", "aarde2", "aarde3", "aarde_donker", weights=[3, 3, 2, 1], seed=10)
ZAND = mix("zand1", "zand2", seed=11)
GRIND = mix("grind1", "grind2", "grind3", "grind_roest", weights=[4, 3, 3, 1], seed=12)
BETON = mix("beton1", "beton2", "beton3", weights=[3, 2, 1], seed=13)
BETON_D = mix("beton2", "beton_donker", seed=14)
BAKSTEEN = None  # zie gebouwen; hier een eenvoudige variant
NATUURSTEEN = blocky(["natuursteen1", "natuursteen2", "natuursteen3"], size=4, seed=15)


def baksteen_fn(x, y, z, seed=20, names=("baksteen1", "baksteen2", "baksteen3", "baksteen4", "baksteen5")):
    u = x + y + (z % 2)
    return pick(list(names), u // 2, z, 0, seed, weights=[4, 4, 3, 2, 1])


def klinker_fn(x, y, z):
    # halfsteensverband, stenen van 2x1 voxels dwars op de rijrichting
    bid = ((x + (y % 2)) // 2, y)
    return pick(["klinker1", "klinker2", "klinker3", "klinker4", "klinker5"], bid[0], bid[1], 0, 21, [4, 4, 3, 2, 1])


def dist(x, y, cx, cy):
    return math.hypot(x + 0.5 - cx, y + 0.5 - cy)


# ------------------------------------------------------------- basis

def new(sz=12):
    return V(T, T, sz)


def column(m, x, y, top, c, sub="aarde2"):
    fc = col(c)
    fs = col(sub)
    for z in range(top):
        m.set(x, y, z, fc(x, y, z) if z == top - 1 else fs(x, y, z))


def flat(c=ASFALT, top=ROAD, sub="aarde2", sz=12):
    m = new(sz)
    for y in range(T):
        for x in range(T):
            column(m, x, y, top, c, sub)
    return m


def paint(m, x, y, c):
    if not (0 <= x < m.sx and 0 <= y < m.sy):
        return
    t = m.top(x, y)
    if t:
        m.set(x, y, t - 1, c)


def line_y(m, x, y0=0, y1=T, c=MARK, dash=None):
    for y in range(y0, y1):
        if dash is None or (y + dash[2]) % dash[1] < dash[0]:
            paint(m, x, y, c)


def line_x(m, y, x0=0, x1=T, c=MARK, dash=None):
    for x in range(x0, x1):
        if dash is None or (x + dash[2]) % dash[1] < dash[0]:
            paint(m, x, y, c)


def paint_bitmap(m, rows, x0, y0, c=MARK, scale=1, rot=0):
    """Schilder een bitmap op het wegdek. rij 0 = verst weg (hoogste y)."""
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
                    elif rot == 1:  # 90 graden: leesrichting langs y
                        paint(m, x0 + ly, y0 + (wid * scale - 1 - lx), c)


DASH = (10, 16, 0)
DASH_SNEL = (12, 32, 0)
BLOK = (8, 16, 4)

# ------------------------------------------------------------- wegen

def rijstrook(left="geen", right="geen", surface=ASFALT):
    m = flat(surface)
    if left == "onderbroken":
        line_y(m, 0, dash=DASH)
    elif left == "streep":
        line_y(m, 0)
    elif left == "dubbel":
        line_y(m, 0)
        line_y(m, 2)
    elif left == "blok":
        line_y(m, 0, dash=BLOK)
        line_y(m, 1, dash=BLOK)
    if right == "kant":
        line_y(m, 30)
    elif right == "streep":
        line_y(m, 31)
    elif right == "onderbroken":
        line_y(m, 31, dash=DASH)
    elif right == "kant_onderbroken":
        line_y(m, 30, dash=(4, 8, 0))
    return m


RIJSTROKEN = [
    ("geen", "geen"), ("geen", "kant"), ("geen", "kant_onderbroken"),
    ("onderbroken", "kant"), ("onderbroken", "geen"), ("onderbroken", "onderbroken"),
    ("streep", "kant"), ("streep", "geen"), ("dubbel", "kant"), ("dubbel", "geen"),
    ("blok", "kant"), ("blok", "geen"),
]
for _l, _r in RIJSTROKEN:
    register(f"grond/weg/rijstrook_{_l}_{_r}", (lambda l, r: lambda: rijstrook(l, r))(_l, _r))


@tile("grond/weg/weg_vlak")
def weg_vlak():
    return flat()


@tile("grond/weg/weg_vlak_oud")
def weg_vlak_oud():
    m = flat(ASFALT_OUD)
    # scheuren
    for i in range(3):
        x, y = int(h(i, 1, 0, 30) * 28) + 2, int(h(i, 2, 0, 30) * 28) + 2
        for s in range(10):
            paint(m, x, y, P["asfalt_reparatie"])
            x += 1 if h(i, s, 1, 31) > 0.5 else 0
            y += 1 if h(i, s, 2, 31) > 0.3 else -1
    # oude reparatie-plek
    for y in range(18, 26):
        for x in range(4, 13):
            paint(m, x, y, P["asfalt_reparatie"] if h(x, y, 0, 32) > 0.1 else P["asfalt4"])
    return m


@tile("grond/weg/weg_putdeksel")
def weg_putdeksel():
    m = flat()
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16, 16)
            if d < 4.2:
                paint(m, x, y, P["rooster"] if (d < 3.4 and (x + y) % 2 == 0) or d >= 3.4 else P["metaal_donker"])
    return m


@tile("grond/weg/weg_kolk")
def weg_kolk():
    m = rijstrook("geen", "geen")
    for y in range(12, 20):
        for x in range(28, 32):
            paint(m, x, y, P["rooster"] if (y % 2 == 0 or x in (28, 31)) else P["asfalt4"])
    return m


def arrow(m, kind, cx=16, y0=4):
    shaft_top = y0 + 16
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


for _k in ("rechtdoor", "links", "rechts", "rechtdoor_links", "rechtdoor_rechts"):
    def _f(k=_k):
        m = rijstrook("streep", "kant")
        arrow(m, k)
        return m
    register(f"grond/weg/rijstrook_pijl_{_k}", _f)


@tile("grond/weg/rijstrook_stopstreep")
def stopstreep():
    m = rijstrook("streep", "kant")
    for y in range(27, 30):
        line_x(m, y, 0, 31)
    return m


@tile("grond/weg/rijstrook_haaientanden")
def haaientanden():
    m = rijstrook("streep", "kant")
    for i in range(5):
        x0 = 2 + i * 6
        for r in range(5):
            for x in range(x0 + r // 2, x0 + 4 - r // 2):
                paint(m, x, 29 - r, MARK)
    return m


@tile("grond/weg/zebrapad")
def zebrapad():
    m = flat()
    for y in range(3, 29):
        for x in range(T):
            if (x // 4) % 2 == 0:
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/fietsoversteek")
def fietsoversteek():
    m = flat()
    for y in range(4, 28):
        for x in range(T):
            paint(m, x, y, FIETS)
    for x in range(T):
        if (x // 3) % 2 == 0:
            for y in (4, 5, 26, 27):
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/verkeersdrempel")
def drempel():
    m = flat(sz=12)
    for y in range(8, 24):
        lift = 1 if 10 <= y < 22 else 0
        for x in range(T):
            t = ROAD + lift
            column(m, x, y, t, klinker_fn)
    for x in range(T):
        if (x // 4) % 2 == 0:
            for y in (8, 9, 22, 23):
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/rijstrook_bus")
def rijstrook_bus():
    m = rijstrook("streep", "kant", BUS)
    px, (w, hh) = text_pixels("BUS")
    for (c, r) in px:
        for sy in range(2):
            for sx in range(2):
                paint(m, 5 + c * 2 + sx, 12 + (4 - r) * 2 + sy, MARK)
    return m


@tile("grond/weg/rijstrook_fietsstrook")
def rijstrook_fietsstrook():
    m = rijstrook("onderbroken", "geen")
    for y in range(T):
        for x in range(20, T):
            paint(m, x, y, FIETS)
        if y % 8 < 4:
            paint(m, 19, y, MARK)
    paint_bitmap(m, PICTO["fiets"], 21, 12, MARK)
    return m


@tile("grond/weg/parkeerstrook")
def parkeerstrook():
    m = flat()
    line_y(m, 0, dash=(4, 8, 0))
    for x in range(1, T):
        paint(m, x, 0, MARK)
    return m


@tile("grond/weg/parkeervak_gehandicapt")
def parkeervak_blauw():
    m = parkeerstrook()
    for y in range(6, 26):
        for x in range(6, 26):
            paint(m, x, y, P["bord_blauw"])
    paint_bitmap(m, ["#####", "#...#", "#####", "#....", "#...."], 11, 11, MARK, scale=2)
    return m


@tile("grond/weg/straat_klinkers")
def straat_klinkers():
    return flat(klinker_fn)


@tile("grond/weg/straat_klinkers_middengoot")
def straat_klinkers_goot():
    m = flat(klinker_fn)
    for y in range(T):
        for x in range(14, 18):
            column(m, x, y, ROAD, GOOT)
        m.clear(14, y, ROAD - 1, 18, y + 1, ROAD)
        for x in range(14, 18):
            column(m, x, y, ROAD - (1 if x in (15, 16) else 0), GOOT)
    return m


def keien_tile(top=ROAD):
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
def straat_keien():
    return keien_tile()


# ------------------------------------------------------------- snelweg

@tile("grond/snelweg/snelweg_rijstrook")
def snelweg_rijstrook():
    m = flat()
    for x in (0, 1):
        line_y(m, x, dash=DASH_SNEL)
    return m


@tile("grond/snelweg/snelweg_rijstrook_links")
def snelweg_rijstrook_links():
    m = flat()
    for x in (0, 1):
        line_y(m, x)
    for x in (30, 31):
        line_y(m, x, dash=DASH_SNEL)
    return m


@tile("grond/snelweg/snelweg_vluchtstrook")
def snelweg_vluchtstrook():
    m = flat()
    for x in (0, 1):
        line_y(m, x)
    for y in range(T):  # ribbels
        if y % 2 == 0:
            paint(m, 3, y, P["asfalt4"])
    return m


@tile("grond/snelweg/snelweg_blokmarkering")
def snelweg_blok():
    m = flat()
    for x in (0, 1, 2):
        line_y(m, x, dash=BLOK)
    return m


@tile("grond/snelweg/snelweg_puntstuk")
def snelweg_puntstuk():
    m = flat()
    for x in (0, 1):
        line_y(m, x)
    for x in (30, 31):
        line_y(m, x)
    for y in range(T):
        for x in range(2, 30):
            if (x + y) % 8 < 2:
                paint(m, x, y, MARK)
    return m


def vangrail(m, x, base, y0=0, y1=T):
    for y in range(y0, y1):
        if y % 16 == 4:
            for z in range(base, base + 5):
                m.set(x, y, z, "metaal2")
        m.set(x - 1 if x > 0 else x + 1, y, base + 3, "gegalvaniseerd")
        m.set(x - 1 if x > 0 else x + 1, y, base + 4, "gegalvaniseerd")


@tile("grond/snelweg/snelweg_berm_vangrail")
def snelweg_berm():
    m = new(12)
    for y in range(T):
        for x in range(T):
            if x < 6:
                column(m, x, y, ROAD, ASFALT)
            else:
                column(m, x, y, WALK, GRAS)
    vangrail(m, 7, WALK)
    for y in range(T):
        if y % 16 == 10:
            for z in range(WALK, WALK + 7):
                m.set(14, y, z, "bord_wit")
            m.set(14, y, WALK + 5, "bord_rood")
    return m


@tile("grond/snelweg/snelweg_middenberm")
def snelweg_middenberm():
    m = new(12)
    for y in range(T):
        for x in range(T):
            if x < 4 or x >= 28:
                column(m, x, y, ROAD, ASFALT)
            else:
                column(m, x, y, WALK, GRAS)
    vangrail(m, 6, WALK)
    vangrail(m, 25, WALK)
    m2 = m
    for y in range(T):
        m2.set(24, y, WALK + 3, "gegalvaniseerd")
        m2.set(24, y, WALK + 4, "gegalvaniseerd")
        m2.clear(26, y, WALK + 3, 27, y + 1, WALK + 5)
    return m


@tile("grond/snelweg/snelweg_middenberm_beton")
def snelweg_middenberm_beton():
    m = new(14)
    for y in range(T):
        for x in range(T):
            column(m, x, y, ROAD, ASFALT)
        for x in range(13, 19):
            for z in range(ROAD, ROAD + 7 - (1 if x in (13, 18) else 0)):
                m.set(x, y, z, BETON)
    return m


# ------------------------------------------------------------- stoepen

def edge_dist(px, py, edges, R=6.0):
    """Afstand tot de dichtstbijzijnde wegrand, met afgeronde buitenhoeken."""
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


def stoep(edges="", points=(), goot=False, surface=TEGEL, kade=False, sz=12):
    m = new(sz)
    for y in range(T):
        for x in range(T):
            px, py = x + 0.5, y + 0.5
            e = edge_dist(px, py, edges)
            for (cx, cy) in points:
                e = min(e, math.hypot(px - cx, py - cy))
            if kade:
                if e < 0:
                    column(m, x, y, ROAD, ASFALT)
                elif e < 3:
                    column(m, x, y, WALK, NATUURSTEEN, baksteen_fn if e < 1 else "aarde2")
                else:
                    column(m, x, y, WALK, surface)
                continue
            curb0 = 3 if goot else 0
            if e < 0:
                column(m, x, y, ROAD, ASFALT)
            elif e < curb0:
                column(m, x, y, ROAD, GOOT)
            elif e < curb0 + 1:
                column(m, x, y, WALK, BAND, BAND)
            else:
                column(m, x, y, WALK, surface)
    return m


STOEP_VORMEN = {
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

for _name, (_e, _p) in STOEP_VORMEN.items():
    register(f"grond/stoep/stoep_{_name}", (lambda e, p: lambda: stoep(e, p))(_e, _p))
    if _name != "vol":
        register(f"grond/stoep/stoep_goot_{_name}", (lambda e, p: lambda: stoep(e, p, goot=True))(_e, _p))
for _name in ("vol", "rand", "hoek_buiten", "hoek_binnen"):
    _e, _p = STOEP_VORMEN[_name]
    register(f"grond/stoep/stoep_klinker_{_name}", (lambda e, p: lambda: stoep(e, p, surface=klinker_fn))(_e, _p))


@tile("grond/stoep/stoep_goot_kolk")
def stoep_goot_kolk():
    m = stoep("v", goot=True)
    for y in range(0, 3):
        for x in range(12, 20):
            paint(m, x, y, P["rooster"] if (x % 2 == 0 or y == 0) else P["goot2"])
    return m


@tile("grond/stoep/stoep_oprit")
def stoep_oprit():
    m = stoep("v")
    for x in range(4, 28):
        m.clear(x, 0, ROAD, x + 1, 1, WALK)
        column(m, x, 0, ROAD, BAND, BAND)
        paint(m, x, 1, BAND)
    return m


@tile("grond/stoep/stoep_goot_oprit")
def stoep_goot_oprit():
    m = stoep("v", goot=True)
    for x in range(4, 28):
        m.clear(x, 3, ROAD, x + 1, 4, WALK)
        column(m, x, 3, ROAD, BAND, BAND)
    return m


@tile("grond/stoep/stoep_ribbel")
def stoep_ribbel():
    m = stoep("v")
    for y in range(1, 8):
        for x in range(8, 24):
            paint(m, x, y, P["ribbel"] if x % 2 == 0 else P["tegel3"])
    return m


@tile("grond/stoep/stoep_boomrooster")
def stoep_boomrooster():
    m = stoep("")
    for y in range(10, 22):
        for x in range(10, 22):
            edge = x in (10, 21) or y in (10, 21)
            if edge:
                paint(m, x, y, P["metaal_donker"])
            elif dist(x, y, 16, 16) < 3:
                m.clear(x, y, WALK - 1, x + 1, y + 1, WALK)
                column(m, x, y, WALK - 1, AARDE)
            else:
                paint(m, x, y, P["rooster"] if (x + y) % 2 == 0 else P["metaal_donker"])
    return m


@tile("grond/stoep/stoep_kade")
def stoep_kade():
    return stoep("v", kade=True)


@tile("grond/stoep/stoep_kade_hoek_buiten")
def stoep_kade_hoek():
    return stoep("vr", kade=True)


@tile("grond/stoep/stoep_kade_hoek_binnen")
def stoep_kade_hoek_binnen():
    return stoep("", ((T, 0),), kade=True)


@tile("grond/stoep/stoep_kade_klinker")
def stoep_kade_klinker():
    return stoep("v", kade=True, surface=klinker_fn)


# ------------------------------------------------------------- pleinen

@tile("grond/plein/plein_tegels")
def plein_tegels():
    return flat(blocky(["plein1", "plein2", "plein3"], size=4, seed=40), top=WALK)


@tile("grond/plein/plein_natuursteen")
def plein_natuursteen():
    def f(x, y, z):
        row = y // 4
        bx = (x + (row % 2) * 4) // 8
        return pick(["natuursteen1", "natuursteen2", "natuursteen3", "plein3"], bx, row, 0, 41)
    return flat(f, top=WALK)


@tile("grond/plein/plein_klinkers")
def plein_klinkers():
    def f(x, y, z):
        if ((x // 2 + y // 2) % 2) == 0:
            bid = (x // 2, y)
        else:
            bid = (x, y // 2 + 100)
        return pick(["klinker1", "klinker2", "klinker3", "klinker4", "klinker5"], bid[0], bid[1], 0, 42, [4, 4, 3, 2, 1])
    return flat(f, top=WALK)


@tile("grond/plein/plein_dambord")
def plein_dambord():
    def f(x, y, z):
        return P["plein3"] if ((x // 8) + (y // 8)) % 2 == 0 else P["plein_donker"]
    return flat(f, top=WALK)


@tile("grond/plein/plein_patroon")
def plein_patroon():
    def f(x, y, z):
        d = max(abs(x + 0.5 - 16), abs(y + 0.5 - 16))
        ring = int(d) // 3
        if dist(x, y, 16, 16) < 4:
            return P["plein_rood"]
        return [P["plein1"], P["plein_donker"], P["plein3"], P["plein_rood"], P["plein2"], P["plein_donker"]][ring % 6]
    return flat(f, top=WALK)


@tile("grond/plein/plein_grind")
def plein_grind():
    return flat(GRIND, top=WALK)


@tile("grond/plein/plein_vlonder")
def plein_vlonder():
    def f(x, y, z):
        if x % 4 == 3:
            return P["hout_donker2"]
        return pick(["hout1", "hout2", "hout3"], x // 4, y // 12 + (x // 4) * 3, 0, 43)
    return flat(f, top=WALK, sub="hout_donker1")


# ------------------------------------------------------------- natuur

def gras_tile(flowers=0.0, tufts=0.06, tall=False, base=GRAS, seed=50):
    m = flat(base, top=WALK, sz=8)
    for y in range(T):
        for x in range(T):
            r = h(x, y, 0, seed)
            if r < flowers:
                m.set(x, y, WALK, "gras3")
                m.set(x, y, WALK + 1, pick(["bloem_wit", "bloem_geel", "bloem_paars", "bloem_rood", "bloem_roze"], x, y, 1, seed))
            elif r < flowers + tufts:
                m.set(x, y, WALK, pick(["gras2", "gras4", "gras_droog"], x, y, 2, seed))
                if tall and h(x, y, 3, seed) < 0.5:
                    m.set(x, y, WALK + 1, pick(["gras4", "gras_droog"], x, y, 4, seed))
    return m


@tile("grond/natuur/gras")
def gras():
    return gras_tile()


@tile("grond/natuur/gras_bloemen")
def gras_bloemen():
    return gras_tile(flowers=0.06)


@tile("grond/natuur/gras_hoog")
def gras_hoog():
    return gras_tile(tufts=0.3, tall=True)


@tile("grond/natuur/gras_kort")
def gras_kort():
    return gras_tile(tufts=0.0, base=mix("gras2", "gras4", "gras1", seed=51))


@tile("grond/natuur/zand")
def zand():
    m = flat(ZAND, top=WALK, sz=8)
    for y in range(T):
        for x in range(T):
            if h(x, y, 0, 52) < 0.03:
                m.set(x, y, WALK, "grind3")
    return m


@tile("grond/natuur/aarde")
def aarde():
    return flat(AARDE, top=WALK, sz=8)


@tile("grond/natuur/moestuin")
def moestuin():
    m = flat(AARDE, top=WALK, sz=8)
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
def tulpen():
    m = flat(AARDE, top=WALK, sz=8)
    kleuren = ["bloem_rood", "bloem_geel", "bloem_roze", "bloem_paars", "bloem_wit", "bloem_oranje"]
    for y in range(T):
        for x in range(T):
            if x % 2 == 0 and y % 2 == 0:
                m.set(x, y, WALK, "blad2")
                m.set(x, y, WALK + 1, "blad4")
                m.set(x, y, WALK + 2, kleuren[(y // 5) % len(kleuren)])
    return m


@tile("grond/natuur/pad_zand")
def pad_zand():
    m = gras_tile(tufts=0.05)
    for y in range(T):
        w0 = 11 + int(h(0, y // 3, 0, 54) * 2)
        w1 = 21 - int(h(1, y // 3, 0, 54) * 2)
        for x in range(w0, w1):
            m.clear(x, y, WALK, x + 1, y + 1, 8)
            column(m, x, y, WALK, mix("zand1", "zand2", "grind3", seed=55))
    return m


@tile("grond/natuur/pad_grind_bocht")
def pad_bocht():
    m = gras_tile(tufts=0.05)
    for y in range(T):
        for x in range(T):
            if abs(dist(x, y, 32, 0) - 16) < 4.5:
                m.clear(x, y, WALK, x + 1, y + 1, 8)
                column(m, x, y, WALK, GRIND)
    return m


@tile("grond/natuur/pad_grind")
def pad_grind():
    m = gras_tile(tufts=0.05)
    for y in range(T):
        for x in range(11, 21):
            m.clear(x, y, WALK, x + 1, y + 1, 8)
            column(m, x, y, WALK, GRIND)
    return m


# ------------------------------------------------------------- water

WATER = mix("water1", "water2", "water3", seed=60)


def water_tile(water=WATER):
    m = new(8)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, mix("waterbodem", "waterbodem2", "modder", seed=61))
            m.set(x, y, 1, water)
    return m


@tile("grond/water/water")
def water():
    return water_tile()


@tile("grond/water/water_gracht")
def water_gracht():
    return water_tile(mix("water_gracht", "water2", seed=62, weights=[3, 1]))


def oever(dfun):
    """dfun(px, py) -> afstand landinwaarts vanaf de waterlijn (<0 = water)."""
    m = new(8)
    for y in range(T):
        for x in range(T):
            d = dfun(x + 0.5, y + 0.5)
            if d < 0:
                m.set(x, y, 0, "waterbodem")
                m.set(x, y, 1, WATER)
            elif d < 2:
                column(m, x, y, ROAD, mix("modder", "zand2", seed=63))
            elif d < 4:
                column(m, x, y, WALK, mix("aarde1", "gras5", "gras3", seed=64), AARDE)
            else:
                column(m, x, y, WALK, GRAS)
                if h(x, y, 0, 65) < 0.05:
                    m.set(x, y, WALK, "gras4")
    return m


@tile("grond/water/water_oever")
def water_oever():
    return oever(lambda px, py: py - 14)


def _oever_buiten(px, py):
    d = min(py - 14, 18 - px)
    if px > 12 and py < 20:
        d = min(d, 6 - math.hypot(px - 12, py - 20))
    return d


@tile("grond/water/water_oever_hoek_buiten")
def water_oever_hoek_buiten():
    # land in de hoek achter-links; water voor en rechts
    return oever(_oever_buiten)


@tile("grond/water/water_oever_hoek_binnen")
def water_oever_hoek_binnen():
    # water alleen in de hoek voor-rechts
    return oever(lambda px, py: math.hypot(px - 32, py) - 14)


@tile("grond/water/water_riet")
def water_riet():
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
def water_lelies():
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


def kademuur(alg=False):
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                if alg and z < 3 and h(x, y, z, 68) < 0.7 - z * 0.2:
                    m.set(x, y, z, mix("alg1", "alg2", seed=69))
                else:
                    m.set(x, y, z, lambda a, b, c: baksteen_fn(a, b, c, 70))
    return m


@tile("grond/water/kademuur")
def kademuur_blok():
    return kademuur()


@tile("grond/water/kademuur_alg")
def kademuur_alg():
    return kademuur(True)


@tile("grond/water/kademuur_water")
def kademuur_water():
    """Water met een kademuur aan de achterkant (handig als je geen blok wilt stapelen)."""
    m = water_tile()
    for z in range(0, FLOOR):
        for y in range(28, T):
            for x in range(T):
                m.set(x, y, z, lambda a, b, c: baksteen_fn(a, b, c, 71))
    return m


# ------------------------------------------------------------- terrein

@tile("grond/terrein/grond_blok")
def grond_blok():
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                if z == FLOOR - 1:
                    m.set(x, y, z, GRAS)
                elif z == FLOOR - 2 and h(x, y, z, 72) < 0.4:
                    m.set(x, y, z, "gras5")
                elif h(x, y, z, 73) < 0.04:
                    m.set(x, y, z, "grind2")
                else:
                    m.set(x, y, z, AARDE)
    return m


@tile("grond/terrein/grond_blok_beton")
def grond_blok_beton():
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                seam = (x + y) % 16 == 0 or z == 0
                m.set(x, y, z, "beton_donker" if seam else BETON)
    return m


@tile("grond/terrein/grond_blok_baksteen")
def grond_blok_baksteen():
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                m.set(x, y, z, NATUURSTEEN if z == FLOOR - 1 else (lambda a, b, c: baksteen_fn(a, b, c, 74)))
    return m


# ------------------------------------------------------------- fietspaden

def fietspad_surface(m, region):
    for y in range(T):
        for x in range(T):
            if region(x + 0.5, y + 0.5):
                column(m, x, y, ROAD, FIETS)
            else:
                column(m, x, y, WALK, GRAS)


@tile("grond/fietspad/fietspad_recht")
def fietspad_recht():
    return flat(FIETS)


@tile("grond/fietspad/fietspad_eenrichting")
def fietspad_eenrichting():
    m = flat(FIETS)
    paint_bitmap(m, PICTO["pijl_op"], 14, 20, MARK)
    return m


@tile("grond/fietspad/fietspad_symbool")
def fietspad_symbool():
    m = flat(FIETS)
    paint_bitmap(m, PICTO["fiets"], 3, 10, MARK)
    paint_bitmap(m, PICTO["fiets"], 18, 10, MARK)
    return m


@tile("grond/fietspad/fietspad_bocht")
def fietspad_bocht():
    m = new()
    fietspad_surface(m, lambda px, py: math.hypot(px - 32, py) <= 32)
    return m


@tile("grond/fietspad/fietspad_t")
def fietspad_t():
    m = flat(FIETS)
    # haaientanden op de zijtak (wie van rechts komt, verleent voorrang)
    for k in range(5):
        y0 = 3 + k * 6
        for r in range(4):
            for y in range(y0 + r // 2, y0 + 4 - r // 2):
                paint(m, 27 - r, y, MARK)
    return m


@tile("grond/fietspad/fietspad_kruising")
def fietspad_kruising():
    return flat(FIETS)


@tile("grond/fietspad/fietspad_eind")
def fietspad_eind():
    m = new()
    fietspad_surface(m, lambda px, py: py < 16 or math.hypot(px - 16, py - 16) < 16)
    return m


@tile("grond/fietspad/fietspad_naast_weg")
def fietspad_naast_weg():
    """Vrijliggend fietspad (3 m) met grasstrook aan de rechterkant."""
    m = new()
    fietspad_surface(m, lambda px, py: px < 24)
    for y in range(T):
        column(m, 24, y, WALK, BAND, BAND)
    return m


# ------------------------------------------------------------- spoor (trein)

RAIL_X = (10, 21)


def track_straight(m, base=0, along="y"):
    """Ballastbed + bielzen + rails op een vlakke tile. base = z offset."""
    for y in range(T):
        for x in range(T):
            if 4 <= x <= 27:
                for z in range(base, base + 4):
                    m.set(x, y, z, GRIND if z >= base + 1 else "aarde2")
                if 5 <= x <= 26 and y % 4 in (0, 1):
                    m.set(x, y, base + 3, "biels_beton")
            elif x in (3, 28):
                for z in range(base, base + 3):
                    m.set(x, y, z, GRIND)
        for x in RAIL_X:
            m.set(x, y, base + 4, "rail_glim")
            m.set(x, y, base + 3, "rail")


def track_arc(m, cx, cy, rc, size, base=0, ballast_r=12):
    for y in range(size):
        for x in range(size):
            d = dist(x, y, cx, cy)
            dd = abs(d - rc)
            ang = math.atan2(y + 0.5 - cy, cx - x - 0.5)
            s = rc * abs(ang)
            if dd <= ballast_r:
                for z in range(base, base + 4):
                    m.set(x, y, z, GRIND if z >= base + 1 else "aarde2")
                if dd <= 10.5 and (s % 4) < 2:
                    m.set(x, y, base + 3, "biels_beton")
            elif dd <= ballast_r + 1:
                for z in range(base, base + 3):
                    m.set(x, y, z, GRIND)
            if abs(dd - 5.5) < 0.55:
                m.set(x, y, base + 4, "rail_glim")
                m.set(x, y, base + 3, "rail")


def grass_floor(m, size, top=WALK):
    for y in range(size):
        for x in range(size):
            column(m, x, y, top, GRAS)


@tile("grond/spoor/trein_recht")
def trein_recht():
    m = new()
    grass_floor(m, T)
    track_straight(m)
    return m


@tile("grond/spoor/trein_bocht")
def trein_bocht():
    m = new()
    grass_floor(m, T)
    track_arc(m, 32, 0, 16, T)
    return m


@tile("grond/spoor/trein_bocht_groot_3x3")
def trein_bocht_groot():
    S = T * 3
    m = V(S, S, 12)
    grass_floor(m, S)
    track_arc(m, S, 0, 80, S)
    return m


@tile("grond/spoor/trein_overweg")
def trein_overweg():
    """Spoor loopt langs x (links-rechts), weg loopt van voor naar achter."""
    m = new()
    for y in range(T):
        for x in range(T):
            e = min(y, 31 - y)
            top = ROAD + min(3, e // 2)
            if 4 <= y <= 27:
                top = 5
            column(m, x, y, top, ASFALT)
    for x in range(T):
        for y in RAIL_X:
            m.set(x, y, 4, "rail_glim")
            m.set(x, y + (1 if y == 10 else -1), 4, "railgroef")
        for y in range(11, 21):
            if 11 < y < 20:
                m.set(x, y, 4, "rubber")
    for y in range(T):
        if 4 <= y <= 27:
            m.set(0, y, 4, "markering")
            m.set(31, y, 4, "markering")
    return m


@tile("grond/spoor/trein_stootblok")
def trein_stootblok():
    m = trein_recht()
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


def perron(edge="v"):
    m = V(T, T, 14)
    top = 11
    for y in range(T):
        for x in range(T):
            column(m, x, y, top, TEGEL, BETON_D)
    for x in range(T):
        for y in range(0, 2):
            paint(m, x, y, BETON)
        paint(m, x, 3, P["markering_geel"])
        for y in range(5, 7):
            paint(m, x, y, P["ribbel"] if x % 2 == 0 else P["tegel3"])
    return m


@tile("grond/spoor/perron")
def perron_tile():
    return perron()


@tile("grond/spoor/perron_midden")
def perron_midden():
    m = V(T, T, 14)
    for y in range(T):
        for x in range(T):
            column(m, x, y, 11, TEGEL, BETON_D)
    return m


@tile("grond/spoor/perron_trap")
def perron_trap():
    m = perron_midden()
    for y in range(6, 28):
        step = (y - 6) // 2
        top = 11 - step if step < 11 else 0
        for x in range(10, 22):
            m.clear(x, y, max(top, 0), x + 1, y + 1, 11)
            if top > 0:
                m.set(x, y, top - 1, BETON)
    return m


# ------------------------------------------------------------- tram

def tram_rails_straight(m, top=ROAD, along_x=False):
    for i in range(T):
        for r in RAIL_X:
            g = r + 1 if r == RAIL_X[0] else r - 1
            if along_x:
                paint(m, i, r, P["rail_glim"])
                paint(m, i, g, P["railgroef"])
            else:
                paint(m, r, i, P["rail_glim"])
                paint(m, g, i, P["railgroef"])


def tram_rails_arc(m, cx, cy, rc, size):
    for y in range(size):
        for x in range(size):
            d = dist(x, y, cx, cy)
            if abs(d - (rc - 5.5)) < 0.55 or abs(d - (rc + 5.5)) < 0.55:
                paint(m, x, y, P["rail_glim"])
            elif (rc - 5.5 + 0.5) <= d < (rc - 5.5 + 1.4) or (rc + 5.5 - 1.4) < d <= (rc + 5.5 - 0.5):
                paint(m, x, y, P["railgroef"])


@tile("grond/tram/tram_recht")
def tram_recht():
    m = flat()
    tram_rails_straight(m)
    return m


@tile("grond/tram/tram_bocht")
def tram_bocht():
    m = flat()
    tram_rails_arc(m, 32, 0, 16, T)
    return m


@tile("grond/tram/tram_t")
def tram_t():
    m = flat()
    tram_rails_straight(m)
    tram_rails_arc(m, 32, 0, 16, T)
    return m


@tile("grond/tram/tram_kruising")
def tram_kruising():
    m = flat()
    tram_rails_straight(m)
    tram_rails_straight(m, along_x=True)
    return m


@tile("grond/tram/tram_bocht_groot_3x3")
def tram_bocht_groot():
    S = T * 3
    m = V(S, S, 8)
    for y in range(S):
        for x in range(S):
            column(m, x, y, ROAD, ASFALT)
    tram_rails_arc(m, S, 0, 80, S)
    return m


@tile("grond/tram/tram_klinker_recht")
def tram_klinker_recht():
    m = flat(klinker_fn)
    tram_rails_straight(m)
    return m


@tile("grond/tram/tram_gras_recht")
def tram_gras_recht():
    m = gras_tile(tufts=0.02)
    for y in range(T):
        for r in RAIL_X:
            m.set(r, y, WALK, "rail_glim")
            m.set(r, y, WALK - 1, "rail")
    return m


@tile("grond/tram/tram_gras_bocht")
def tram_gras_bocht():
    m = gras_tile(tufts=0.02)
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 32, 0)
            if abs(d - 10.5) < 0.55 or abs(d - 21.5) < 0.55:
                m.set(x, y, WALK, "rail_glim")
    return m


@tile("grond/tram/tram_halte_perron")
def tram_halte():
    m = V(T, T, 10)
    for y in range(T):
        for x in range(T):
            column(m, x, y, 5, TEGEL, BETON_D)
    for x in range(T):
        column(m, x, 0, 5, BAND, BAND)
        paint(m, x, 2, P["markering"])
        for y in range(4, 7):
            paint(m, x, y, P["ribbel"] if x % 2 == 0 else P["tegel3"])
    return m


# ------------------------------------------------------------- trappen (1 m)

@tile("grond/terrein/trap_1m")
def trap_1m():
    m = V(T, T, FLOOR + 8)
    for y in range(T):
        if y < 8:
            top = WALK
        elif y < 24:
            top = WALK + 1 + (y - 8) // 2
        else:
            top = WALK + FLOOR
        for x in range(T):
            column(m, x, y, top, BETON if 8 <= y < 24 else TEGEL, BETON_D)
            if 8 <= y < 24 and (y - 8) % 2 == 0:
                paint(m, x, y, P["beton3"])
    for y in range(T):
        for x in (0, 31):
            t = m.top(x, y)
            for z in range(t, t + 3):
                m.set(x, y, z, BETON_D)
            if y % 8 == 4:
                for z in range(t + 3, t + 7):
                    m.set(x, y, z, "rvs")
    # leuning
    for y in range(T):
        for x in (0, 31):
            zt = (WALK + 3 + 6) if y < 8 else (WALK + FLOOR + 3 + 6 if y >= 24 else WALK + 4 + (y - 8) // 2 + 6)
            m.set(x, y, min(zt, m.sz - 1), "rvs")
    return m


# ------------------------------------------------------------- bruggen

def deck_from(flat_tile, rails="links"):
    """Maak een brugdek: onderkant beton, randen met borstwering."""
    m = V(T, T, 12)
    for y in range(T):
        for x in range(T):
            t = flat_tile.top(x, y)
            for z in range(flat_tile.sz):
                c = flat_tile.get(x, y, z)
                if c:
                    m.set(x, y, z, c)
            m.set(x, y, 0, BETON_D)
    sides = {"links": (0,), "beide": (0, 31), "geen": ()}[rails]
    for x0 in sides:
        xs = (0, 1) if x0 == 0 else (30, 31)
        for y in range(T):
            for x in xs:
                for z in range(0, WALK + 4):
                    m.set(x, y, z, BETON)
            if y % 8 == 2:
                for z in range(WALK + 4, WALK + 8):
                    m.set(xs[0] if x0 == 0 else xs[1], y, z, "metaal2")
            m.set(xs[0] if x0 == 0 else xs[1], y, WALK + 8, "metaal3")
    return m


register("grond/brug/brug_dek_weg_rand", lambda: deck_from(rijstrook("geen", "geen")))
register("grond/brug/brug_dek_weg_beide", lambda: deck_from(rijstrook("geen", "geen"), "beide"))
register("grond/brug/brug_dek_weg_midden", lambda: deck_from(rijstrook("geen", "geen"), "geen"))
register("grond/brug/brug_dek_rijstrook_kant_rand", lambda: deck_from(_deck_lane()))
register("grond/brug/brug_dek_rijstrook_onderbroken", lambda: deck_from(rijstrook("onderbroken", "geen"), "geen"))
register("grond/brug/brug_dek_fietspad_rand", lambda: deck_from(fietspad_recht()))
register("grond/brug/brug_dek_fietspad_beide", lambda: deck_from(fietspad_recht(), "beide"))
register("grond/brug/brug_dek_stoep_rand", lambda: deck_from(stoep("")))
register("grond/brug/brug_dek_tram_rand", lambda: deck_from(tram_recht()))
register("grond/brug/brug_dek_klinker_beide", lambda: deck_from(straat_klinkers(), "beide"))


def _deck_lane():
    m = rijstrook("geen", "geen")
    line_y(m, 3)
    return m


@tile("grond/brug/brug_dek_trein_rand")
def brug_dek_trein():
    base = new()
    for y in range(T):
        for x in range(T):
            column(base, x, y, ROAD, BETON)
    track_straight(base, base=1)
    return deck_from(base, "links")


@tile("grond/brug/brug_dek_trein_beide")
def brug_dek_trein_beide():
    base = new()
    for y in range(T):
        for x in range(T):
            column(base, x, y, ROAD, BETON)
    track_straight(base, base=1)
    return deck_from(base, "beide")


@tile("grond/brug/brug_ligger")
def brug_ligger():
    m = V(T, T, FLOOR)
    for y in range(T):
        for x in range(T):
            if 3 <= x <= 9 or 22 <= x <= 28:
                for z in range(3, FLOOR):
                    m.set(x, y, z, BETON)
            else:
                m.set(x, y, FLOOR - 1, BETON_D)
    return m


def pijler(m, z0, z1):
    for z in range(z0, z1):
        for y in range(T):
            for x in range(T):
                if dist(x, y, 16, 16) < 5.2:
                    m.set(x, y, z, BETON if (x + z) % 7 else "beton_donker")


@tile("grond/brug/brug_pijler")
def brug_pijler():
    m = V(T, T, FLOOR)
    pijler(m, 0, FLOOR)
    return m


@tile("grond/brug/brug_pijler_kop")
def brug_pijler_kop():
    m = V(T, T, FLOOR)
    pijler(m, 0, FLOOR)
    for z in range(3, FLOOR):
        for y in range(10, 22):
            w = 2 + (z - 3) * 2
            for x in range(max(0, 10 - w), min(T, 22 + w)):
                m.set(x, y, z, BETON)
    return m


@tile("grond/brug/brug_pijler_gras")
def brug_pijler_gras():
    m = gras_tile()
    pijler(m, WALK, FLOOR)
    return m


@tile("grond/brug/brug_pijler_stoep")
def brug_pijler_stoep():
    m = stoep("")
    m2 = V(T, T, FLOOR)
    m2.paste(m, 0, 0, 0)
    pijler(m2, WALK, FLOOR)
    return m2


@tile("grond/brug/brug_pijler_water")
def brug_pijler_water():
    m = water_tile()
    pijler(m, 0, FLOOR)
    for y in range(T):
        for x in range(T):
            if dist(x, y, 16, 16) < 6.5:
                m.set(x, y, 1, "alg2")
                m.set(x, y, 2, "alg1")
    return m


def boogbrug(rails):
    """Bakstenen boogbrug over een gracht. Plaats op het niveau van het water
    (2 grond-verdiepingen onder de straat); het wegdek komt dan op straatniveau."""
    H = FLOOR * 2 + ROAD
    m = V(T, T, H + 8)
    for z in range(H):
        for y in range(T):
            for x in range(T):
                ez = (y + 0.5 - 16) ** 2 / (13.0 ** 2) + (z + 0.5 - 1) ** 2 / (12.0 ** 2)
                inside = ez < 1.0 and z >= 1
                ring = 1.0 <= ez < 1.25 and z >= 1
                if z >= H - 2:
                    m.set(x, y, z, klinker_fn)
                elif inside:
                    if z == 1:
                        m.set(x, y, z, WATER)
                    continue
                elif z == 0:
                    m.set(x, y, z, "waterbodem")
                elif ring:
                    m.set(x, y, z, NATUURSTEEN if (x in (0, 31)) else "donkersteen2")
                else:
                    m.set(x, y, z, lambda a, b, c: baksteen_fn(a, b, c, 75))
            # water onder de boog
        for y in range(T):
            pass
    for y in range(T):
        for x in range(T):
            if m.get(x, y, 1) == 0:
                m.set(x, y, 1, WATER)
    sides = {"rand": (0,), "beide": (0, 31), "midden": ()}[rails]
    for xs in sides:
        cols = (0, 1) if xs == 0 else (30, 31)
        for y in range(T):
            for x in cols:
                for z in range(H - 2, H + 6):
                    m.set(x, y, z, lambda a, b, c: baksteen_fn(a, b, c, 76))
                m.set(x, y, H + 6, NATUURSTEEN)
    return m


register("grond/brug/brug_boog_gracht_beide", lambda: boogbrug("beide"))
register("grond/brug/brug_boog_gracht_rand", lambda: boogbrug("rand"))
register("grond/brug/brug_boog_gracht_midden", lambda: boogbrug("midden"))


@tile("grond/brug/brug_landhoofd")
def brug_landhoofd():
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                m.set(x, y, z, BETON if not (y == 0 and z % 4 == 0) else "beton_donker")
    return m


# ------------------------------------------------------------- hellingen

def shear(flat_tile, offset_fn, fill=AARDE, thin=False, rails=None):
    out = V(flat_tile.sx, flat_tile.sy, flat_tile.sz + FLOOR + 1)
    for y in range(flat_tile.sy):
        for x in range(flat_tile.sx):
            o = offset_fn(x, y)
            col_top = flat_tile.top(x, y)
            for z in range(flat_tile.sz):
                c = flat_tile.get(x, y, z)
                if not c:
                    continue
                if thin and z < ROAD - 2:
                    continue
                out.set(x, y, z + o, c)
            if thin:
                out.set(x, y, o, BETON_D)
                if o > 0:
                    out.set(x, y, o - 1, BETON_D)
            elif fill:
                for z in range(o):
                    out.set(x, y, z, fill)
    if rails:
        for xs in rails:
            for y in range(T):
                o = offset_fn(xs, y)
                for z in range(o, o + WALK + 4):
                    out.set(xs, y, z, BETON)
                if y % 8 == 2:
                    for z in range(o + WALK + 4, o + WALK + 8):
                        out.set(xs, y, z, "metaal2")
                out.set(xs, y, o + WALK + 8, "metaal3")
    return out


STRAIGHT = lambda x, y: y // 4
CORNER_OUT = lambda x, y: min(x, y) // 4
CORNER_IN = lambda x, y: max(x, y) // 4

HELLING_BRON = {
    "weg_vlak": weg_vlak,
    "rijstrook_onderbroken_kant": lambda: rijstrook("onderbroken", "kant"),
    "rijstrook_geen_kant": lambda: rijstrook("geen", "kant"),
    "rijstrook_streep_kant": lambda: rijstrook("streep", "kant"),
    "rijstrook_onderbroken_geen": lambda: rijstrook("onderbroken", "geen"),
    "snelweg_rijstrook": snelweg_rijstrook,
    "snelweg_vluchtstrook": snelweg_vluchtstrook,
    "fietspad_recht": fietspad_recht,
    "stoep_vol": lambda: stoep(""),
    "stoep_rand": lambda: stoep("v"),
    "stoep_goot_rand": lambda: stoep("v", goot=True),
    "straat_klinkers": straat_klinkers,
    "plein_tegels": plein_tegels,
    "gras": gras,
    "trein_recht": trein_recht,
    "tram_recht": tram_recht,
}

for _n, _f in HELLING_BRON.items():
    register(f"grond/helling/helling_{_n}", (lambda f: lambda: shear(f(), STRAIGHT))(_f))

for _n in ("weg_vlak", "rijstrook_onderbroken_kant", "rijstrook_geen_kant", "fietspad_recht", "stoep_vol", "trein_recht", "tram_recht"):
    _f = HELLING_BRON[_n]
    register(f"grond/helling/helling_brug_{_n}_rand", (lambda f: lambda: shear(f(), STRAIGHT, thin=True, rails=(0,)))(_f))
    register(f"grond/helling/helling_brug_{_n}", (lambda f: lambda: shear(f(), STRAIGHT, thin=True))(_f))

register("grond/helling/helling_gras_hoek_buiten", lambda: shear(gras(), CORNER_OUT))
register("grond/helling/helling_gras_hoek_binnen", lambda: shear(gras(), CORNER_IN))
register("grond/helling/helling_dijk_beton", lambda: shear(flat(BETON, top=WALK), STRAIGHT, fill=BETON_D))
