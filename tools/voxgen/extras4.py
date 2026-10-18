"""Uitbreiding 4: bedrijfspand, industrieel hekwerk, brugwachtershuisjes, stalen trappen, draaideur,
grind/zand en heuvels, berm en sloot, middenberm-lantaarns, afzetbollen, verkeerszuilen, loopbruggen."""
import math

from common import T, ROAD, WALK, FLOOR, register, tile
from palette import P
from vox import V, mix, pick, h
from ground import (column, flat, new, gras_tile, shear, paint, line_y, ASFALT, GRAS, AARDE, ZAND, GRIND, BETON,
                    BETON_D, WATER, MARK, CORNER_IN, CORNER_OUT, STRAIGHT, baksteen_fn)
from buildings import Bld, STYLES, S, O, W, HGT, make_block, flat_roof, pitched, brick
from buildings2 import reg_style, flat_roofs
from details import att, wd
from props import pole

# ------------------------------------------------------------------ bedrijfspand

def golf(x, y, z):
    u = x + y
    return P["golfplaat1"] if u % 3 else P["golfplaat2"]


STYLES["bedrijfspand"] = dict(fam="bedrijf", wall=golf, kozijn="antraciet1", deuren=["metaal1"], plint="beton2",
                              sier="antraciet1", dak=("golfplaat1", "golfplaat2"), dakvloer=("golfplaat1", "golfplaat2"),
                              glas="glas2", winkel="antraciet1", cap="antraciet1")


def bp_roldeur(b, face):
    b.rect(face, 0, S, 0, 3, 0, 1, "beton2")
    b.rect(face, 4, 28, 0, 20, 0, 2, 0)
    for z in range(0, 20):
        for u in range(4, 28):
            b.put(face, u, z, 1, "antraciet1" if (u in (4, 27) or z == 19) else ("metaal1" if z % 2 else "metaal2"))
    for u in (2, 29):
        for z in range(0, 6):
            b.put(face, u, z, -1, "bord_geel" if z % 2 else "bord_zwart")


def bp_kantoor(b, face):
    b.rect(face, 0, S, 0, 3, 0, 1, "beton2")
    b.window(face, 2, 6, 28, 10, sill=False, lintel=False)
    b.door(face, 13, 6, 0, 17, transom=False, glass_panel=True) if False else None
    b.rect(face, 12, 20, 0, 17, 0, 3, 0)
    b.rect(face, 12, 20, 0, 17, 1, 2, "glas_helder")
    b.rect(face, 10, 22, 17, 18, -5, 0, "antraciet1")


def bp_dicht(b, face):
    b.rect(face, 0, S, 0, 3, 0, 1, "beton2")


def bp_lichtstraat(b, face):
    b.rect(face, 0, S, 0, 3, 0, 1, "beton2")
    b.window(face, 0, 16, 32, 4, sill=False, lintel=False)


def bp_logo(b, face):
    bp_dicht(b, face)
    b.sign(face, 2, 30, 14, 21, "bord_blauw", "ZWERVR", "bord_wit")


reg_style("bedrijfspand", {"bg_roldeur": bp_roldeur, "bg_kantoor": bp_kantoor, "bg_dicht": bp_dicht,
                           "verd_lichtstraat": bp_lichtstraat, "verd_dicht": bp_dicht, "verd_logo": bp_logo},
          [("bg_roldeur_hoek", "bg_roldeur", "bg_dicht"), ("bg_kantoor_hoek", "bg_kantoor", "bg_dicht"),
           ("verd_lichtstraat_hoek", "verd_lichtstraat", "verd_lichtstraat")],
          dict(flat_roofs("bedrijfspand"), dak_sheddak=pitched("bedrijfspand", "shed", lambda px, py: (py % 16) * 1.0)))


# ------------------------------------------------------------------ industrieel hekwerk

@tile("props/hekken/hek_industrie")
def hek_industrie():
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
def schuifpoort():
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
def slagboom():
    m = V(72, 6, 10)
    m.box(32, 1, 0, 36, 5, 8, "bord_wit")
    for x in range(36, 70):
        m.set(x, 3, 6, "bord_rood" if (x // 4) % 2 else "bord_wit")
    m.set(34, 0, 7, "stoplicht_rood")
    return m


# ------------------------------------------------------------------ brugwachtershuisjes

@tile("props/water/brugwachtershuisje_klassiek")
def brugwachter_klassiek():
    m = V(16, 16, 26)
    for z in range(0, 14):
        for y in range(2, 14):
            for x in range(2, 14):
                if x in (2, 13) or y in (2, 13):
                    m.set(x, y, z, baksteen_fn(x, y, z, 700))
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
def brugwachter_modern():
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


# ------------------------------------------------------------------ stalen trappen en draaideur

@tile("props/trappen/trap_staal_spiraal")
def trap_spiraal():
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
def brandtrap():
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
def draaideur():
    m = att(20, 6, 20)
    c = (10, wd(m, 3))
    for z in range(0, 20):
        for y in range(m.sy):
            for x in range(20):
                d = math.hypot(x + 0.5 - 10, y + 0.5 - c[1])
                if 8.4 < d < 9.4 and y <= c[1]:
                    m.set(x, y, z, "glas_helder" if z < 18 else "metaal3")
        for k in range(4):
            a = k * math.pi / 2 + 0.4
            for r in range(0, 8):
                m.set(10 + math.cos(a) * r, c[1] + math.sin(a) * r, z, "glas_helder" if z < 18 else "metaal3")
    m.cyl(10, c[1], 9, 18, 20, "metaal3")
    return m


# ------------------------------------------------------------------ grind/zand en heuvels

register("grond/natuur/grind", lambda: flat(GRIND, top=WALK, sz=8))
register("grond/natuur/grindpad", lambda: _pad(GRIND))
register("grond/natuur/zandpad", lambda: _pad(ZAND))


def _pad(mat):
    m = gras_tile(tufts=0.05)
    for y in range(T):
        for x in range(10, 22):
            m.clear(x, y, WALK, x + 1, y + 1, 8)
            column(m, x, y, WALK, mat)
    return m


def blok(mat, top):
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        for y in range(T):
            for x in range(T):
                m.set(x, y, z, top if z == FLOOR - 1 else mat)
    return m


for _n, _top, _fill in (("gras", GRAS, AARDE), ("zand", ZAND, ZAND), ("grind", GRIND, GRIND)):
    _flat = (lambda t: lambda: flat(t, top=WALK, sz=8))(_top)
    register(f"grond/heuvel/heuvel_{_n}_blok", (lambda f, t: lambda: blok(f, t))(_fill, _top))
    register(f"grond/heuvel/heuvel_{_n}_helling", (lambda fl, f: lambda: shear(fl(), STRAIGHT, fill=f))(_flat, _fill))
    register(f"grond/heuvel/heuvel_{_n}_hoek_buiten", (lambda fl, f: lambda: shear(fl(), CORNER_OUT, fill=f))(_flat, _fill))
    register(f"grond/heuvel/heuvel_{_n}_hoek_binnen", (lambda fl, f: lambda: shear(fl(), CORNER_IN, fill=f))(_flat, _fill))
    register(f"grond/heuvel/heuvel_{_n}_top", (lambda fl, f: lambda: shear(fl(), lambda x, y: min(4, int(4 - math.hypot(x - 15.5, y - 15.5) / 4)), fill=f))(_flat, _fill))


# ------------------------------------------------------------------ berm en sloot

@tile("grond/weg/berm")
def berm():
    m = new()
    for y in range(T):
        for x in range(T):
            if x < 10:
                column(m, x, y, ROAD, ASFALT)
            elif x < 13:
                column(m, x, y, ROAD, GRIND)
            else:
                column(m, x, y, WALK, GRAS)
                if h(x, y, 0, 701) < 0.1:
                    m.set(x, y, WALK, "gras_droog")
    line_y(m, 8, dash=(4, 8, 0))
    for y in range(T):
        if y % 16 == 6:
            for z in range(WALK, WALK + 7):
                m.set(16, y, z, "bord_wit")
            m.set(16, y, WALK + 5, "bord_rood")
    return m


@tile("grond/water/sloot")
def sloot():
    m = new(8)
    for y in range(T):
        for x in range(T):
            d = abs(x + 0.5 - 16)
            if d < 6:
                m.set(x, y, 0, "modder")
                m.set(x, y, 1, WATER)
            elif d < 9:
                column(m, x, y, ROAD, mix("gras5", "aarde1", seed=702))
            else:
                column(m, x, y, WALK, GRAS)
    for y in range(T):
        for x in (10, 21):
            if h(x, y, 0, 703) < 0.4:
                for z in range(ROAD, ROAD + 4 + int(h(x, y, 1, 703) * 4)):
                    m.set(x, y, z, "riet1")
    return m


@tile("grond/water/sloot_bocht")
def sloot_bocht():
    m = new(8)
    for y in range(T):
        for x in range(T):
            d = abs(math.hypot(x + 0.5 - 32, y + 0.5) - 16)
            if d < 6:
                m.set(x, y, 0, "modder")
                m.set(x, y, 1, WATER)
            elif d < 9:
                column(m, x, y, ROAD, mix("gras5", "aarde1", seed=704))
            else:
                column(m, x, y, WALK, GRAS)
    return m


@tile("grond/water/duiker")
def duiker():
    """Sloot onder een weg door (dam met duiker)."""
    m = new(8)
    for y in range(T):
        for x in range(T):
            column(m, x, y, ROAD, ASFALT, "aarde2")
    for y in (0, 31):
        for x in range(10, 22):
            for z in range(0, 2):
                m.set(x, y, z, BETON_D)
    return m


# ------------------------------------------------------------------ middenberm-lantaarns, bollen, verkeerszuil

@tile("props/verlichting/lantaarn_middenberm")
def lantaarn_middenberm():
    m = V(80, 4, 84)
    for z in range(0, 80):
        for x in (39, 40):
            m.set(x, 1, z, "gegalvaniseerd")
            m.set(x, 2, z, "gegalvaniseerd")
    for side in (-1, 1):
        for i in range(0, 34):
            x = 40 + side * i if side > 0 else 39 - i
            z = 80 + min(2, i // 6)
            m.set(x, 1, z, "gegalvaniseerd")
            m.set(x, 2, z, "gegalvaniseerd")
        for i in range(27, 35):
            x = 40 + side * i if side > 0 else 39 - i
            m.set(x, 1, 81, "lamp_wit")
            m.set(x, 2, 81, "lamp_wit")
    return m


@tile("props/verkeer/afzetbol_beton")
def afzetbol():
    m = V(6, 6, 6)
    m.ellipsoid(3, 3, 2.8, 2.8, 2.8, 2.8, mix("beton1", "beton3", seed=705))
    return m


@tile("props/verkeer/afzetbol_rood_wit")
def afzetbol_rw():
    m = V(6, 6, 6)
    m.ellipsoid(3, 3, 2.8, 2.8, 2.8, 2.8, lambda x, y, z: P["bord_rood"] if z in (2, 3) else P["bord_wit"])
    return m


@tile("props/verkeer/verkeerszuil")
def verkeerszuil():
    m = V(6, 6, 12)
    for z in range(12):
        m.cyl(3, 3, 2.4 - z * 0.05, z, z + 1, "lamp_wit" if 2 < z < 10 else "bord_wit")
    for (c, r) in [(2, 8), (3, 7), (1, 7), (2, 6), (2, 5), (2, 4)]:
        m.set(c + 0, 0, r, "bord_blauw")
    return m


@tile("props/verkeer/verkeerszuil_geel")
def verkeerszuil_geel():
    m = verkeerszuil()
    for z in range(3, 10):
        for y in range(6):
            for x in range(6):
                if m.get(x, y, z) == P["lamp_wit"]:
                    m.set(x, y, z, "stoplicht_oranje")
    return m


# ------------------------------------------------------------------ loopbruggen (op hoogte, over wegen)

def loopbrug(dicht):
    m = V(T, T, 32)
    for y in range(T):
        for x in range(6, 26):
            m.set(x, y, 0, "metaal2")
            m.set(x, y, 1, mix("tegel1", "tegel3", seed=706))
        for x in (6, 25):
            if dicht:
                for z in range(2, 22):
                    m.set(x, y, z, "glas_helder" if y % 8 else "metaal3")
            else:
                for z in range(2, 9):
                    m.set(x, y, z, "glas_helder")
                m.set(x, y, 9, "rvs")
        if dicht:
            for x in range(6, 26):
                m.set(x, y, 22, "metaal3" if (y % 8 == 0 or x in (6, 25)) else "glas_helder")
            if y % 8 == 4:
                m.set(16, y, 21, "lamp_wit")
    return m


register("grond/brug/loopbrug_overdekt", lambda: loopbrug(True))
register("grond/brug/loopbrug_open", lambda: loopbrug(False))


@tile("grond/brug/loopbrug_trap")
def loopbrug_trap():
    """Trap die 1 grond-laag stijgt (stapelbaar naar een loopbrug)."""
    m = V(T, T, FLOOR + 10)
    for y in range(T):
        top = 2 + y // 4
        for x in range(8, 24):
            m.set(x, y, top - 1, "metaal1")
            m.set(x, y, top - 2, "metaal2") if top > 2 else None
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
def loopbrug_pijler():
    m = V(T, T, FLOOR)
    for z in range(FLOOR):
        m.box(14, 14, z, 18, 18, z + 1, "metaal2")
    return m


@tile("props/overig/persoon_1m80")
def persoon():
    """Schaalmodel: persoon van 1,80 m (14-15 voxels) om maten te controleren."""
    m = V(6, 4, 15)
    for z in range(0, 7):
        for x in (1, 4):
            m.set(x, 2, z, "stof1")
            m.set(x + (1 if x == 1 else -1) * 0, 1, z, "stof1") if False else None
    for z in range(0, 1):
        for x in (1, 4):
            m.set(x, 1, z, "bord_zwart")
    for z in range(7, 12):
        for x in range(1, 5):
            m.set(x, 2, z, "stof2")
        m.set(0, 2, z, "gordijn1" if z < 9 else "stof2")
        m.set(5, 2, z, "gordijn1" if z < 9 else "stof2")
    for z in range(12, 15):
        for x in range(2, 4):
            m.set(x, 2, z, "gordijn1" if z < 14 else "hout_donker2")
    return m
