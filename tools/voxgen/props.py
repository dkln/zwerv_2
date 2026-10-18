"""Props: straatmeubilair, borden, bomen, planten, hekken, paaltjes, trappen, spoor en water.

Draaipunt = midden-onder van het model. In de Props-GridMap (raster 0.5 m) staat
het draaipunt op een rasterpunt, dus je kunt props fijn positioneren.
"""
import math

from common import register, tile, PICTO, text_pixels
from palette import P
from vox import V, mix, pick, h, col

PAAL = "metaal2"


def pole(m, x, y, z0, z1, c=PAAL, w=2):
    for z in range(z0, z1):
        for dy in range(w):
            for dx in range(w):
                m.set(x + dx, y + dy, z, c)


# ------------------------------------------------------------------ verlichting

@tile("props/verlichting/lantaarn_klassiek")
def lantaarn_klassiek():
    m = V(12, 12, 44)
    g = "amsterdamgroen"
    for z in range(0, 4):
        for y in range(3, 9):
            for x in range(3, 9):
                if not ((x in (3, 8)) and (y in (3, 8))):
                    m.set(x, y, z, g)
    for z in range(4, 34):
        r = 1.6 if z < 8 else 1.1
        m.cyl(6, 6, r, z, z + 1, g)
    m.cyl(6, 6, 1.6, 26, 27, g)
    for x in range(1, 11):
        m.set(x, 6, 30, g)
    for z in range(34, 36):
        m.cyl(6, 6, 2.2, z, z + 1, g)
    for z in range(36, 41):
        for y in range(3, 9):
            for x in range(3, 9):
                edge = x in (3, 8) or y in (3, 8)
                corner = x in (3, 8) and y in (3, 8)
                if edge:
                    m.set(x, y, z, g if corner else "lamp_warm")
    for z in (41, 42):
        m.cyl(6, 6, 3.3 - (z - 41) * 1.6, z, z + 1, g)
    m.set(5, 5, 43, g)
    m.set(6, 6, 43, g)
    return m


@tile("props/verlichting/lantaarn_modern")
def lantaarn_modern():
    m = V(28, 4, 50)
    for z in range(0, 48):
        m.set(14, 1, z, "metaal3")
        m.set(14, 2, z, "metaal3")
        if z < 2:
            m.set(13, 1, z, "metaal3")
            m.set(15, 2, z, "metaal3")
    for x in range(14, 26):
        m.set(x, 1, 48, "metaal3")
        m.set(x, 2, 48, "metaal3")
    for x in range(22, 27):
        for y in (1, 2):
            m.set(x, y, 47, "lamp_wit")
            m.set(x, y, 48, "antraciet1")
    return m


@tile("props/verlichting/lantaarn_dubbel")
def lantaarn_dubbel():
    m = V(28, 4, 54)
    for z in range(0, 52):
        m.set(13, 1, z, "metaal3")
        m.set(14, 2, z, "metaal3")
        m.set(13, 2, z, "metaal3")
        m.set(14, 1, z, "metaal3")
    for x in range(2, 26):
        m.set(x, 1, 52, "metaal3")
        m.set(x, 2, 52, "metaal3")
    for x in list(range(2, 7)) + list(range(21, 26)):
        m.set(x, 1, 51, "lamp_wit")
        m.set(x, 2, 51, "lamp_wit")
    return m


@tile("props/verlichting/lantaarn_snelweg")
def lantaarn_snelweg():
    m = V(64, 4, 100)
    for z in range(0, 96):
        for x in (31, 32):
            for y in (1, 2):
                m.set(x, y, z, "gegalvaniseerd")
    for x in range(31, 60):
        z = 96 + (1 if x > 36 else 0)
        m.set(x, 1, z, "gegalvaniseerd")
        m.set(x, 2, z, "gegalvaniseerd")
    for x in range(53, 60):
        for y in (1, 2):
            m.set(x, y, 96, "lamp_wit")
            m.set(x, y, 97, "metaal2")
    return m


@tile("props/verlichting/lantaarn_park")
def lantaarn_park():
    m = V(6, 6, 30)
    for z in range(0, 24):
        m.cyl(3, 3, 0.9 if z > 2 else 1.6, z, z + 1, "antraciet1")
    m.ellipsoid(3, 3, 26, 2.6, 2.6, 3, "lamp_warm")
    m.cyl(3, 3, 2.5, 28, 30, "antraciet1")
    return m


# ------------------------------------------------------------------ afval

@tile("props/straat/prullenbak_paal")
def prullenbak_paal():
    m = V(6, 6, 10)
    pole(m, 2, 2, 0, 9, "amsterdamgroen")
    for z in range(3, 9):
        m.cyl(3, 3, 2.6, z, z + 1, "amsterdamgroen" if z not in (4, 7) else "deur_groen")
    m.cyl(3, 3, 1.5, 8, 9, "interieur3")
    m.cyl(3, 3, 2.8, 9, 10, "metaal_donker")
    m.set(3, 3, 9, 0)
    m.set(2, 3, 9, 0)
    return m


@tile("props/straat/prullenbak_rond")
def prullenbak_rond():
    m = V(6, 6, 8)
    for z in range(0, 8):
        for y in range(6):
            for x in range(6):
                d = math.hypot(x + 0.5 - 3, y + 0.5 - 3)
                if 2.0 < d < 3.0 and (z < 1 or z > 6 or (x + y + z) % 2 == 0):
                    m.set(x, y, z, "metaal_donker")
                elif d <= 2.0 and z == 0:
                    m.set(x, y, z, "metaal_donker")
    return m


@tile("props/straat/afvalcontainer_ondergronds")
def ondergronds():
    m = V(12, 12, 10)
    for y in range(12):
        for x in range(12):
            m.set(x, y, 0, "rvs")
    for z in range(1, 9):
        m.cyl(6, 6, 2.6, z, z + 1, "antraciet2")
    m.cyl(6, 6, 3.2, 9, 10, "antraciet1")
    for z in range(6, 8):
        for x in range(4, 9):
            m.set(x, 3, z, "interieur3")
    m.set(6, 3, 8, "bord_groen")
    return m


def rolcontainer(lid):
    m = V(6, 8, 9)
    for z in range(0, 8):
        for y in range(1, 7):
            for x in range(0, 6):
                m.set(x, y, z, "antraciet1" if z < 7 else lid)
    for x in (0, 5):
        m.set(x, 6, 0, "rubber")
        m.set(x, 7, 1, "rubber")
    for x in range(6):
        m.set(x, 7, 7, "antraciet2")
    return m


register("props/straat/rolcontainer_grijs", lambda: rolcontainer("antraciet2"))
register("props/straat/rolcontainer_groen", lambda: rolcontainer("bord_groen"))
register("props/straat/rolcontainer_blauw", lambda: rolcontainer("bord_blauw"))


# ------------------------------------------------------------------ zitten

@tile("props/straat/bank_hout")
def bank_hout():
    m = V(16, 6, 8)
    for x in (1, 14):
        for z in range(0, 7):
            m.set(x, 1, z, "metaal_donker")
            m.set(x, 4, z if z < 4 else 3, "metaal_donker")
        for y in range(1, 5):
            m.set(x, y, 3, "metaal_donker")
    for x in range(16):
        for y in (1, 2, 3, 4):
            if y != 2 or True:
                m.set(x, y, 4, "hout_bank1" if y % 2 else "hout_bank2")
        for z in (5, 6):
            m.set(x, 0, z + 1, "hout_bank3" if z == 6 else "hout_bank2")
    return m


@tile("props/straat/bank_beton")
def bank_beton():
    m = V(16, 6, 4)
    for z in range(3):
        for y in range(1, 5):
            for x in range(16):
                m.set(x, y, z, mix("beton1", "beton2", "beton3", seed=11))
    for x in range(1, 15):
        for y in range(1, 5):
            m.set(x, y, 3, "hout_bank1" if y % 2 else "hout_bank3")
    return m


@tile("props/straat/bank_modern")
def bank_modern():
    m = V(20, 6, 7)
    for x in range(20):
        for y in range(1, 5):
            m.set(x, y, 3, "rvs")
        for z in range(4, 7):
            m.set(x, 1, z, "rvs")
    for x in (1, 9, 18):
        for z in range(3):
            for y in (2, 3):
                m.set(x, y, z, "metaal_donker")
    return m


@tile("props/straat/picknicktafel")
def picknicktafel():
    m = V(16, 14, 7)
    for x in range(1, 15):
        for y in range(4, 10):
            m.set(x, y, 6, "hout_bank1" if y % 2 else "hout_bank2")
        for y in (1, 2, 11, 12):
            m.set(x, y, 3, "hout_bank2")
    for x in (2, 13):
        for z in range(0, 6):
            m.set(x, 7 - z // 2, z, "hout_bank3")
            m.set(x, 7 + z // 2, z, "hout_bank3")
        for y in range(1, 13):
            m.set(x, y, 2, "hout_bank3")
    return m


# ------------------------------------------------------------------ fietsen

def fiets(color="fiets_zwart"):
    m = V(16, 6, 10)
    y = 3
    for cx in (3.5, 12.5):
        for z in range(0, 8):
            for x in range(16):
                d = math.hypot(x + 0.5 - cx, z + 0.5 - 3.5)
                if 2.6 < d < 3.6:
                    m.set(x, y, z, "rubber")
                elif d < 0.8:
                    m.set(x, y, z, "metaal3")
    m.line((3.5, y, 3.5), (8, y, 3.5), color)
    m.line((8, y, 3.5), (5.5, y, 7.5), color)
    m.line((8, y, 3.5), (11.5, y, 7.5), color)
    m.line((5.5, y, 7.5), (11.5, y, 7.5), color)
    m.line((3.5, y, 3.5), (5.5, y, 7.5), color)
    m.line((12.5, y, 3.5), (11.5, y, 8.5), color)
    for yy in range(1, 6):
        m.set(11, yy, 9, "metaal_donker")
    m.set(5, y, 8, "rubber")
    m.set(6, y, 8, "rubber")
    m.set(4, y, 8, "rubber")
    # bagagedrager en spatbord
    for x in range(1, 6):
        m.set(x, y, 6, "metaal_donker")
    return m


register("props/fietsen/fiets_zwart", lambda: fiets())
register("props/fietsen/fiets_rood", lambda: fiets("fiets_rood"))
register("props/fietsen/fiets_blauw", lambda: fiets("fiets_blauw"))


@tile("props/fietsen/fietsnietje")
def fietsnietje():
    m = V(8, 2, 8)
    for z in range(7):
        m.set(1, 0, z, "rvs")
        m.set(6, 0, z, "rvs")
    for x in range(1, 7):
        m.set(x, 0, 7, "rvs")
    return m


@tile("props/fietsen/fietsenrek")
def fietsenrek():
    m = V(32, 4, 4)
    for x in range(32):
        m.set(x, 1, 0, "gegalvaniseerd")
        m.set(x, 2, 0, "gegalvaniseerd")
        if x % 4 == 1:
            for z in range(1, 4):
                m.set(x, 1, z, "gegalvaniseerd")
                m.set(x, 2, z, "gegalvaniseerd")
    return m


@tile("props/fietsen/fietsenrek_vol")
def fietsenrek_vol():
    m = V(32, 18, 10)
    r = fietsenrek()
    m.paste(r, 0, 7, 0)
    colors = ["fiets_zwart", "fiets_rood", "fiets_blauw", "fiets_zwart", "fiets_zwart", "fiets_blauw", "fiets_rood", "fiets_zwart"]
    for i in range(8):
        f = fiets(colors[i]).rot90(1)
        # gedraaide fiets: 6 breed, 16 diep
        m.paste(f, i * 4 - 1, 1, 0)
    return m


# ------------------------------------------------------------------ OV

@tile("props/ov/abri")
def abri():
    m = V(36, 14, 22)
    for x in (1, 34):
        for z in range(0, 20):
            for y in (2, 11):
                m.set(x, y, z, "metaal3")
    for x in range(0, 36):
        for y in range(0, 14):
            m.set(x, y, 20, "metaal3" if (x in (0, 35) or y in (0, 13)) else "glas_helder")
            m.set(x, y, 21, "metaal3" if (x in (0, 35) or y in (0, 13)) else 0)
    for x in range(2, 34):
        for z in range(1, 19):
            m.set(x, 11, z, "glas_helder")
        m.set(x, 11, 0, "metaal3")
        m.set(x, 11, 19, "metaal3")
    # reclamevitrine aan de zijkant
    for y in range(3, 12):
        for z in range(1, 19):
            edge = y in (3, 11) or z in (1, 18)
            m.set(34, y, z, "metaal3" if edge else pick(["reclame1", "reclame2", "reclame3"], y // 4, z // 6, 0, 12))
            m.set(35, y, z, "metaal3")
    # bankje
    for x in range(6, 22):
        m.set(x, 9, 4, "hout_bank1")
        m.set(x, 10, 4, "hout_bank2")
    for x in (7, 20):
        for z in range(4):
            m.set(x, 10, z, "metaal3")
    # haltebord
    for z in range(15, 20):
        for x in range(4, 14):
            m.set(x, 2, z, "bord_geel" if z > 16 else "bord_blauw")
    return m


@tile("props/ov/bushokje")
def bushokje():
    m = V(28, 12, 21)
    for x in (1, 26):
        for y in (1, 10):
            for z in range(19):
                m.set(x, y, z, "amsterdamgroen")
    for x in range(28):
        for y in range(12):
            m.set(x, y, 19, "amsterdamgroen")
            if 0 < x < 27 and 0 < y < 11:
                m.set(x, y, 20, "amsterdamgroen")
    for x in range(2, 26):
        for z in range(2, 18):
            m.set(x, 10, z, "glas_helder")
    for y in range(2, 10):
        for z in range(2, 18):
            m.set(1, y, z, "glas_helder")
    for x in range(4, 20):
        m.set(x, 9, 4, "hout_bank1")
        m.set(x, 8, 4, "hout_bank2")
    return m


def haltepaal(text, color_top="bord_geel", color_bottom="bord_blauw"):
    m = V(14, 4, 28)
    pole(m, 6, 1, 0, 28, "metaal3")
    px, (tw, th) = text_pixels(text)
    w = max(tw + 2, 8)
    x0 = 7 - w // 2
    for z in range(20, 28):
        for x in range(x0, x0 + w):
            m.set(x, 1, z, color_top if z >= 26 else color_bottom)
            m.set(x, 2, z, "metaal2")
    for (c, r) in px:
        m.set(x0 + 1 + c, 0, 25 - r, "bord_wit")
    for z in range(10, 16):
        for x in range(5, 9):
            m.set(x, 1, z, "stuc1")
            m.set(x, 0, z, "bord_wit" if z % 2 else "bord_zwart")
    return m


register("props/ov/bushalte_paal", lambda: haltepaal("BUS"))
register("props/ov/tramhalte_paal", lambda: haltepaal("TRAM", "bord_geel", "bord_rood"))


@tile("props/ov/reclamezuil")
def reclamezuil():
    m = V(12, 12, 28)
    for z in range(0, 2):
        m.cyl(6, 6, 5, z, z + 1, "amsterdamgroen")
    for z in range(2, 22):
        for y in range(12):
            for x in range(12):
                d = math.hypot(x + 0.5 - 6, y + 0.5 - 6)
                if d < 4.5:
                    ang = math.atan2(y - 6, x - 6)
                    m.set(x, y, z, pick(["reclame1", "luifel_wit", "bloem_geel", "luifel_rood", "luifel_blauw"], int((ang + 4) * 1.3), z // 5, 0, 13))
    for z in range(22, 25):
        m.cyl(6, 6, 5.2 - (z - 22) * 1.2, z, z + 1, "amsterdamgroen")
    m.cyl(6, 6, 1, 25, 28, "amsterdamgroen")
    return m


# ------------------------------------------------------------------ verkeerslichten

def light_head(m, x, y, z, lit="rood", kind="auto"):
    for zz in range(z, z + 10):
        for xx in range(x, x + 4):
            m.set(xx, y, zz, "bord_zwart")
            m.set(xx, y + 1, zz, "bord_zwart")
    for i, name in enumerate(["groen", "oranje", "rood"]):
        zz = z + 1 + i * 3
        c = f"stoplicht_{name}" if name == lit else f"stoplicht_{name}_uit"
        for dz in (0, 1):
            for dx in (1, 2):
                m.set(x + dx, y - 1, zz + dz, c)
        m.set(x + 1, y - 1, zz + 2, "bord_zwart")
        m.set(x + 2, y - 1, zz + 2, "bord_zwart")
    # witte rand (achterbord)
    for zz in range(z - 1, z + 11):
        for xx in (x - 1, x + 4):
            m.set(xx, y + 1, zz, "bord_wit" if (zz % 2) else "bord_rood")


@tile("props/verkeer/verkeerslicht")
def verkeerslicht():
    m = V(8, 4, 32)
    pole(m, 3, 2, 0, 30, "metaal3")
    light_head(m, 2, 1, 19, "rood")
    for z in range(8, 12):
        for x in range(2, 6):
            m.set(x, 1, z, "bord_geel")
    m.set(3, 0, 10, "bord_zwart")
    return m


@tile("props/verkeer/verkeerslicht_groen")
def verkeerslicht_groen():
    m = V(8, 4, 32)
    pole(m, 3, 2, 0, 30, "metaal3")
    light_head(m, 2, 1, 19, "groen")
    return m


@tile("props/verkeer/verkeerslicht_fiets")
def verkeerslicht_fiets():
    m = V(8, 4, 24)
    pole(m, 3, 2, 0, 22, "metaal3")
    light_head(m, 2, 1, 11, "rood")
    return m


@tile("props/verkeer/verkeerslicht_voetganger")
def verkeerslicht_voetganger():
    m = V(8, 4, 26)
    pole(m, 3, 2, 0, 24, "metaal3")
    for z in range(14, 24):
        for x in range(2, 6):
            m.set(x, 1, z, "bord_zwart")
            m.set(x, 2, z, "bord_zwart")
    for (c, r) in [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (0, 3), (2, 3)]:
        m.set(2 + c + 0, 0, 22 - r, "stoplicht_rood")
        m.set(2 + c + 0, 0, 18 - r, "stoplicht_groen_uit")
    for z in range(8, 12):
        for x in range(2, 6):
            m.set(x, 1, z, "bord_geel")
    return m


@tile("props/verkeer/verkeerslicht_mast")
def verkeerslicht_mast():
    m = V(80, 4, 44)
    pole(m, 39, 1, 0, 42, "metaal3", 2)
    for x in range(39, 78):
        m.set(x, 1, 41, "metaal3")
        m.set(x, 2, 41, "metaal3")
    light_head(m, 58, 1, 30, "rood")
    light_head(m, 72, 1, 30, "rood")
    return m


# ------------------------------------------------------------------ borden

def plate_shape(shape, x, z, n):
    c = (n - 1) / 2.0
    dx, dz = x - c, z - c
    if shape == "rond":
        return math.hypot(dx, dz) <= c + 0.3, math.hypot(dx, dz) > c - 0.9
    if shape == "vierkant":
        return True, abs(dx) > c - 0.6 or abs(dz) > c - 0.6
    if shape == "achthoek":
        inside = abs(dx) + abs(dz) <= c * 1.45
        return inside, abs(dx) + abs(dz) > c * 1.45 - 1.2 or abs(dx) > c - 0.6 or abs(dz) > c - 0.6
    if shape == "driehoek":  # punt boven
        t = z / (n - 1)
        half = c * (1 - t) + 0.4
        return abs(dx) <= half, abs(dx) > half - 1.2 or z == 0
    if shape == "driehoek_om":  # punt onder
        t = 1 - z / (n - 1)
        half = c * (1 - t) + 0.4
        return abs(dx) <= half, abs(dx) > half - 1.2 or z == n - 1
    if shape == "ruit":
        return abs(dx) + abs(dz) <= c + 0.3, abs(dx) + abs(dz) > c - 1.4
    return False, False


def bord(shape, bg, rand, picto=None, pc="bord_zwart", n=9, text=None, inner=None, hgt=None):
    H = hgt or (22 + n)
    m = V(n + 2, 4, H)
    pole(m, n // 2, 2, 0, H - 2, "metaal3")
    z0 = H - n - 1
    for z in range(n):
        for x in range(n):
            inside, border = plate_shape(shape, x, z, n)
            if not inside:
                continue
            c = rand if border and rand else bg
            if inner and not border and shape == "ruit" and abs(x - (n - 1) / 2) + abs(z - (n - 1) / 2) < (n - 1) / 2 - 1.5:
                c = inner
            m.set(x + 1, 1, z0 + z, c)
            m.set(x + 1, 2, z0 + z, "metaal1")
    if picto:
        rows = PICTO[picto] if isinstance(picto, str) else picto
        ph, pw = len(rows), len(rows[0])
        ox = 1 + (n - pw) // 2
        oz = z0 + (n - ph) // 2 + ph - 1
        for r, line in enumerate(rows):
            for cc, v in enumerate(line):
                if v == "#":
                    m.set(ox + cc, 1, oz - r, pc)
    if text:
        px, (tw, th) = text_pixels(text)
        ox = 1 + (n - tw) // 2
        oz = z0 + (n - 5) // 2 + 4
        for (cc, r) in px:
            m.set(ox + cc, 1, oz - r, pc)
    return m


BORDEN = {
    "max_30": dict(shape="rond", bg="bord_wit", rand="bord_rood", text="30", n=11),
    "max_50": dict(shape="rond", bg="bord_wit", rand="bord_rood", text="50", n=11),
    "max_80": dict(shape="rond", bg="bord_wit", rand="bord_rood", text="80", n=11),
    "max_100": dict(shape="rond", bg="bord_wit", rand="bord_rood", text="100", n=13),
    "stop": dict(shape="achthoek", bg="bord_rood", rand="bord_wit", picto=["#######"], pc="bord_wit", n=11),
    "voorrang_verlenen": dict(shape="driehoek_om", bg="bord_wit", rand="bord_rood", n=11),
    "voorrangsweg": dict(shape="ruit", bg="bord_wit", rand="bord_zwart", inner="bord_geel", n=11),
    "voorrangskruispunt": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=["..#..", "..#..", "#####", "..#..", "..#.."], n=11),
    "gevaar": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto="uitroep", n=11),
    "verboden_in_te_rijden": dict(shape="rond", bg="bord_rood", rand="bord_rood", picto=["#####"], pc="bord_wit"),
    "gesloten_verkeer": dict(shape="rond", bg="bord_wit", rand="bord_rood"),
    "eenrichtingsweg": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", picto="pijl_rechts", pc="bord_wit"),
    "verplicht_rechtdoor": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto="pijl_op", pc="bord_wit"),
    "fietspad": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto="fiets_klein", pc="bord_wit"),
    "voetpad": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto="voetganger", pc="bord_wit"),
    "parkeren": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", text="P", pc="bord_wit"),
    "zebrapad": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", picto=["...#...", "..###..", ".#####.", "#######"], pc="bord_wit"),
    "doodlopend": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", picto=["#####", "#####", "..#..", "..#..", "..#.."], pc="bord_wit"),
    "woonerf": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", picto="huis", pc="bord_wit"),
    "bushalte": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", picto="bus", pc="bord_wit"),
    "inrijverbod_auto": dict(shape="rond", bg="bord_wit", rand="bord_rood", picto="auto"),
}

for _n, _kw in BORDEN.items():
    register(f"props/borden/bord_{_n}", (lambda kw: lambda: bord(**kw))(_kw))


@tile("props/borden/bord_bebouwde_kom")
def bord_plaatsnaam():
    m = V(32, 4, 30)
    pole(m, 2, 2, 0, 30, "metaal3")
    pole(m, 28, 2, 0, 30, "metaal3")
    px, (tw, th) = text_pixels("ZWERVR")
    for z in range(20, 30):
        for x in range(1, 31):
            edge = x in (1, 30) or z in (20, 29)
            m.set(x, 1, z, "bord_wit" if edge else "bord_blauw")
            m.set(x, 2, z, "metaal1")
    for (c, r) in px:
        m.set(16 - tw // 2 + c, 0, 27 - r, "bord_wit")
    return m


@tile("props/borden/wegwijzer")
def wegwijzer():
    m = V(68, 4, 32)
    pole(m, 33, 2, 0, 32, "metaal3")
    for row, (txt, arrow) in enumerate([("CENTRUM", 1), ("STATION", -1)]):
        z0 = 23 - row * 8
        px, (tw, th) = text_pixels(txt)
        for z in range(z0, z0 + 7):
            for x in range(35, 67):
                edge = x in (35, 66) or z in (z0, z0 + 6)
                m.set(x, 1, z, "bord_blauw" if edge else "bord_wit")
                m.set(x, 2, z, "metaal1")
        for (c, r) in px:
            m.set(37 + c, 0, z0 + 5 - r, "bord_blauw")
        ax = 64 if arrow > 0 else 62
        for dz in range(-1, 2):
            m.set(ax, 0, z0 + 3 + dz, "bord_rood")
        m.set(ax + arrow, 0, z0 + 3, "bord_rood")
    return m


@tile("props/borden/snelweg_portaal")
def snelweg_portaal():
    m = V(100, 6, 64)
    for x0 in (2, 94):
        for z in range(0, 62):
            for dx in range(4):
                for dy in range(1, 5):
                    if dx in (0, 3) or dy in (1, 4):
                        m.set(x0 + dx, dy, z, "gegalvaniseerd")
    for x in range(2, 98):
        for z in (54, 61):
            for y in (1, 4):
                m.set(x, y, z, "gegalvaniseerd")
        if x % 4 == 0:
            for z in range(54, 62):
                m.set(x, 1, z, "gegalvaniseerd")
                m.set(x, 4, z, "gegalvaniseerd")
    # groene wegwijzers
    for (x0, x1, txt) in ((10, 46, "ZWERVR"), (52, 90, "CENTRUM")):
        px, (tw, th) = text_pixels(txt)
        for x in range(x0, x1):
            for z in range(42, 54):
                edge = x in (x0, x1 - 1) or z in (42, 53)
                m.set(x, 0, z, "bord_wit" if edge else "bord_blauw")
        for (c, r) in px:
            for sx in range(1):
                m.set((x0 + x1) // 2 - tw // 2 + c, 0, 50 - r, "bord_wit")
        for dz in range(3):
            for k in range(3 - dz):
                m.set((x0 + x1) // 2 - 1 + k + dz // 2, 0, 44 + dz, "bord_wit")
    # matrixborden
    for x0 in (14, 40, 66):
        for x in range(x0, x0 + 8):
            for z in range(32, 40):
                m.set(x, 2, z, "bord_zwart")
        for k in range(1, 7):
            m.set(x0 + k, 1, 33 + k - 1 if k < 7 else 33, "matrix")
            m.set(x0 + 7 - k, 1, 33 + k - 1, "matrix")
        for z in range(40, 54):
            m.set(x0 + 4, 2, z, "gegalvaniseerd")
    return m


@tile("props/borden/hectometerpaal")
def hectometerpaal():
    m = V(2, 2, 8)
    for z in range(8):
        m.set(0, 0, z, "bord_groen")
        m.set(1, 0, z, "bord_groen")
        m.set(0, 1, z, "bord_groen")
        m.set(1, 1, z, "bord_groen")
    m.set(0, 0, 6, "bord_wit")
    m.set(1, 0, 5, "bord_wit")
    return m


@tile("props/borden/reflectorpaal")
def reflectorpaal():
    m = V(2, 2, 8)
    for z in range(8):
        for x in (0, 1):
            for y in (0, 1):
                m.set(x, y, z, "bord_wit")
    m.set(0, 0, 6, "bord_zwart")
    m.set(1, 0, 6, "bord_rood")
    return m


@tile("props/verkeer/verkeerskegel")
def verkeerskegel():
    m = V(6, 6, 6)
    for z in range(6):
        m.cyl(3, 3, 2.8 - z * 0.45, z, z + 1, "bord_oranje" if z not in (2, 4) else "bord_wit")
    for y in range(6):
        for x in range(6):
            m.set(x, y, 0, "bord_oranje")
    return m


@tile("props/verkeer/dranghek")
def dranghek():
    m = V(20, 4, 9)
    for x in range(20):
        m.set(x, 2, 8, "gegalvaniseerd")
        m.set(x, 2, 1, "gegalvaniseerd")
        if x % 2 == 0:
            for z in range(1, 8):
                m.set(x, 2, z, "gegalvaniseerd")
    for x in (1, 18):
        for y in range(4):
            m.set(x, y, 0, "gegalvaniseerd")
    return m


@tile("props/verkeer/wegafzetting")
def wegafzetting():
    m = V(16, 4, 8)
    for x in range(16):
        for z in (5, 6):
            m.set(x, 1, z, "bord_rood" if (x // 3) % 2 else "bord_wit")
    for x in (2, 13):
        for z in range(0, 7):
            m.set(x, 2, z, "metaal2")
        for y in range(4):
            m.set(x, y, 0, "metaal2")
    m.set(2, 1, 7, "stoplicht_oranje")
    m.set(13, 1, 7, "stoplicht_oranje")
    return m


# ------------------------------------------------------------------ paaltjes

@tile("props/paaltjes/amsterdammertje")
def amsterdammertje():
    m = V(2, 2, 9)
    for z in range(9):
        for x in (0, 1):
            for y in (0, 1):
                m.set(x, y, z, "paal_bruin")
    for z in (6, 4, 2):
        m.set(0, 0, z, "bord_wit") if False else None
    # XXX (wapen van Amsterdam) als lichte accenten
    for z in (6, 4, 2):
        m.set(0, 0, z, "luifel_rood")
        m.set(1, 0, z, "luifel_rood")
    m.set(0, 0, 8, "paal_bruin")
    return m


@tile("props/paaltjes/paal_beton")
def paal_beton():
    m = V(4, 4, 6)
    for z in range(5):
        m.cyl(2, 2, 1.8, z, z + 1, mix("beton1", "beton3", seed=14))
    m.cyl(2, 2, 1.0, 5, 6, "beton3")
    return m


@tile("props/paaltjes/paal_rvs")
def paal_rvs():
    m = V(2, 2, 7)
    for z in range(7):
        for x in (0, 1):
            for y in (0, 1):
                m.set(x, y, z, "rvs")
    return m


@tile("props/paaltjes/paal_afzet")
def paal_afzet():
    m = V(2, 2, 8)
    for z in range(8):
        for x in (0, 1):
            for y in (0, 1):
                m.set(x, y, z, "bord_rood" if z in (5, 6) else "bord_wit")
    return m


@tile("props/paaltjes/fietspaal")
def fietspaal():
    m = V(2, 2, 8)
    for z in range(8):
        for x in (0, 1):
            for y in (0, 1):
                m.set(x, y, z, "bord_rood" if z % 3 == 0 else "bord_wit")
    return m


@tile("props/paaltjes/bolder")
def bolder():
    m = V(4, 4, 6)
    for z in range(6):
        r = 1.8 if z < 2 else (1.3 if z < 4 else 1.9)
        m.cyl(2, 2, r, z, z + 1, "metaal_donker")
    return m


@tile("props/paaltjes/parkeerautomaat")
def parkeerautomaat():
    m = V(4, 4, 12)
    for z in range(12):
        for x in range(4):
            for y in range(1, 4):
                m.set(x, y, z, "antraciet1" if z < 11 else "metaal3")
    for z in range(7, 10):
        m.set(1, 0, z, "lamp_wit")
        m.set(2, 0, z, "lamp_wit")
    m.set(2, 0, 5, "bord_geel")
    return m


@tile("props/paaltjes/laadpaal")
def laadpaal():
    m = V(4, 4, 11)
    for z in range(11):
        for x in range(4):
            for y in range(1, 3):
                m.set(x, y, z, "stuc1" if z < 10 else "bord_groen")
    m.set(1, 0, 8, "stoplicht_groen")
    m.set(2, 0, 6, "rubber")
    m.set(2, 0, 5, "rubber")
    return m


@tile("props/straat/elektriciteitskast")
def elektriciteitskast():
    m = V(10, 6, 10)
    for z in range(10):
        for y in range(1, 5):
            for x in range(10):
                m.set(x, y, z, "paneel1" if z < 9 else "paneel2")
    for z in range(1, 9):
        m.set(5, 0, z, "paneel2") if False else None
        m.set(5, 1, z, "paneel2")
    return m


@tile("props/straat/brievenbus")
def brievenbus():
    m = V(6, 6, 10)
    for z in range(10):
        for y in range(1, 5):
            for x in range(1, 5):
                m.set(x, y, z, "bord_rood" if z < 9 else "bord_rood2")
    for x in (2, 3):
        m.set(x, 0, 7, "rubber")
    return m


@tile("props/straat/vlaggenmast")
def vlaggenmast():
    m = V(28, 4, 64)
    for z in range(64):
        m.set(14, 1, z, "stuc1")
        m.set(14, 2, z, "stuc1")
    for x in range(15, 27):
        for i, c in enumerate(["vlag_rood", "vlag_rood", "vlag_wit", "vlag_wit", "vlag_blauw", "vlag_blauw"]):
            m.set(x, 1, 62 - i - (x // 6), c)
    return m


@tile("props/straat/fontein")
def fontein():
    m = V(24, 24, 14)
    for y in range(24):
        for x in range(24):
            d = math.hypot(x + 0.5 - 12, y + 0.5 - 12)
            if d < 12:
                m.set(x, y, 0, "natuursteen2")
                if d > 10.6:
                    for z in range(1, 4):
                        m.set(x, y, z, "natuursteen1")
                elif d < 10.6:
                    m.set(x, y, 1, "water1")
                    m.set(x, y, 2, "water3")
    for z in range(1, 8):
        m.cyl(12, 12, 1.5, z, z + 1, "natuursteen1")
    m.cyl(12, 12, 4, 8, 9, "natuursteen1")
    for z in range(9, 13):
        m.cyl(12, 12, 1.0 + (z - 9) * 0.6, z, z + 1, "water3")
    return m


@tile("props/straat/kiosk")
def kiosk():
    m = V(24, 24, 32)
    for z in range(0, 22):
        for y in range(24):
            for x in range(24):
                d = math.hypot(x + 0.5 - 12, y + 0.5 - 12)
                if d < 9:
                    m.set(x, y, z, "amsterdamgroen" if z < 4 or z > 18 else ("glas1" if (int(math.atan2(y - 12, x - 12) * 4) % 2) else "amsterdamgroen"))
    for z in range(4, 10):
        for x in range(8, 16):
            m.set(x, 3, z, "hout1")
    for z in range(22, 30):
        m.cyl(12, 12, 11 - (z - 22) * 1.4, z, z + 1, "zink1")
    m.cyl(12, 12, 1, 30, 32, "amsterdamgroen")
    return m


# ------------------------------------------------------------------ hekken

@tile("props/hekken/hek_ijzer")
def hek_ijzer():
    m = V(16, 2, 9)
    for x in range(16):
        m.set(x, 0, 1, "amsterdamgroen")
        m.set(x, 0, 7, "amsterdamgroen")
        if x % 2 == 0:
            for z in range(0, 9):
                m.set(x, 0, z, "amsterdamgroen")
    for x in (0, 15):
        for z in range(9):
            m.set(x, 0, z, "amsterdamgroen")
            m.set(x, 1, z, "amsterdamgroen")
    return m


@tile("props/hekken/hek_ijzer_poort")
def hek_ijzer_poort():
    m = hek_ijzer()
    for z in range(2, 7):
        for x in range(3, 13):
            if (x + z) % 4 == 0:
                m.set(x, 0, z, "amsterdamgroen")
    m.set(8, 1, 4, "messing")
    return m


@tile("props/hekken/schutting_hout")
def schutting_hout():
    m = V(16, 2, 15)
    for x in range(16):
        for z in range(14):
            m.set(x, 0, z, pick(["hout2", "hout1", "hout3"], x // 2, 0, 0, 15) if x % 2 == 0 else "hout_donker1")
    for x in (0, 15):
        for z in range(15):
            m.set(x, 1, z, "hout_donker2")
    for x in range(16):
        m.set(x, 1, 3, "hout_donker1")
        m.set(x, 1, 11, "hout_donker1")
    return m


@tile("props/hekken/tuinhek_wit")
def tuinhek_wit():
    m = V(16, 2, 7)
    for x in range(16):
        m.set(x, 1, 2, "kozijn_wit")
        m.set(x, 1, 5, "kozijn_wit")
        if x % 2 == 0:
            for z in range(0, 6):
                m.set(x, 0, z, "kozijn_wit")
            m.set(x, 0, 6, "kozijn_wit") if x % 4 == 0 else None
    return m


@tile("props/hekken/bouwhek")
def bouwhek():
    m = V(28, 6, 17)
    for x in range(28):
        for z in range(1, 17):
            if x in (1, 26) or z in (1, 16) or (x % 2 == 0 and z % 2 == 0):
                m.set(x, 2, z, "gegalvaniseerd")
    for x0 in (0, 25):
        for x in range(x0, x0 + 3):
            for y in range(0, 6):
                m.set(x, y, 0, "beton1")
                m.set(x, y, 1, "beton1" if 1 <= y <= 4 else 0)
    for x in range(4, 24):
        for z in range(10, 15):
            m.set(x, 3, z, "bord_oranje" if z in (10, 14) else "bord_wit")
    return m


@tile("props/hekken/hek_kade")
def hek_kade():
    m = V(16, 2, 8)
    for x in range(16):
        m.set(x, 0, 7, "metaal_donker")
        if x % 8 == 0:
            for z in range(8):
                m.set(x, 0, z, "metaal_donker")
                m.set(x, 1, z, "metaal_donker")
        else:
            m.set(x, 0, 4 + int(abs(math.sin(x * math.pi / 8)) * 2), "metaal_donker")
    return m


@tile("props/hekken/vangrail")
def vangrail():
    m = V(32, 2, 6)
    for x in range(32):
        m.set(x, 0, 3, "gegalvaniseerd")
        m.set(x, 0, 4, "gegalvaniseerd")
        if x % 16 == 8:
            for z in range(0, 5):
                m.set(x, 1, z, "metaal2")
    return m


@tile("props/hekken/haag")
def haag():
    m = V(16, 6, 10)
    for z in range(10):
        for y in range(6):
            for x in range(16):
                edge = y in (0, 5) or z == 9
                if not edge or h(x, y, z, 16) < 0.8:
                    m.set(x, y, z, pick(["haag1", "haag2", "blad5"], x, y, z, 17))
    return m


@tile("props/hekken/haag_laag")
def haag_laag():
    m = V(16, 6, 5)
    for z in range(5):
        for y in range(6):
            for x in range(16):
                edge = y in (0, 5) or z == 4
                if not edge or h(x, y, z, 18) < 0.8:
                    m.set(x, y, z, pick(["haag1", "haag2", "blad3"], x, y, z, 19))
    return m


# ------------------------------------------------------------------ trappen

def trap(width, steps, rise=1, run=2, railing=True, mat="beton1"):
    depth = steps * run
    m = V(width + 2, depth + 2, steps * rise + 8)
    for s in range(steps):
        for y in range(s * run, depth):
            for x in range(1, width + 1):
                for z in range(s * rise, (s + 1) * rise):
                    m.set(x, y + 1, z, mat if y >= (s + 1) * run - 1 or y == s * run else mix("beton2", "beton1", seed=20))
    if railing:
        for x in (0, width + 1):
            for y in range(depth + 1):
                top = min(steps, y // run + 1) * rise
                m.set(x, y + 1, top + 6, "rvs")
                if y % 4 == 0:
                    for z in range(max(0, top - rise), top + 6):
                        m.set(x, y + 1, z, "rvs")
    return m


register("props/trappen/stoeptrap", lambda: trap(12, 3, 1, 2, railing=False, mat="natuursteen1"))
register("props/trappen/trap_1m", lambda: trap(14, 8, 1, 2))
register("props/trappen/trap_1m_breed", lambda: trap(30, 8, 1, 2))
register("props/trappen/trap_3m", lambda: trap(14, 24, 1, 2))


@tile("props/trappen/trap_metaal_3m")
def trap_metaal():
    m = trap(10, 24, 1, 2, mat="metaal1")
    return m


# ------------------------------------------------------------------ plantenbakken & planten

def struik(m, cx, cy, cz, rx, ry, rz, colors, seed, flowers=None):
    def keep(x, y, z, d):
        return True   # gesloten vorm; de variatie zit in de kleur
    def cfun(x, y, z):
        if flowers and h(x // 2, y // 2, z // 2, seed + 1) < 0.18:
            return pick(flowers, x // 2, y // 2, z // 2, seed + 2)
        return pick(colors, x // 2, y // 2, z // 2, seed + 3)
    m.ellipsoid(cx, cy, cz, rx, ry, rz, cfun, keep)


@tile("props/planten/plantenbak_beton")
def plantenbak_beton():
    m = V(16, 8, 12)
    m.box(0, 0, 0, 16, 8, 5, mix("beton1", "beton3", seed=21))
    m.box(1, 1, 4, 15, 7, 5, "aarde_donker")
    struik(m, 8, 4, 7, 7, 3.5, 3.5, ["blad1", "blad2", "blad4", "blad3"], 22)
    return m


@tile("props/planten/plantenbak_hout")
def plantenbak_hout():
    m = V(16, 16, 10)
    for z in range(5):
        for y in range(16):
            for x in range(16):
                if x in (0, 15) or y in (0, 15):
                    m.set(x, y, z, "hout2" if z % 2 else "hout1")
                elif z == 4:
                    m.set(x, y, z, "aarde_donker")
    for y in range(2, 14, 2):
        for x in range(2, 14, 2):
            m.set(x, y, 5, "blad2")
            m.set(x, y, 6, pick(["bloem_rood", "bloem_geel", "bloem_paars", "bloem_wit", "bloem_roze"], x, y, 0, 23))
    struik(m, 8, 8, 7, 3, 3, 2.5, ["blad1", "blad4"], 24)
    return m


@tile("props/planten/pot_terracotta")
def pot_terracotta():
    m = V(6, 6, 10)
    for z in range(4):
        m.cyl(3, 3, 1.8 + z * 0.3, z, z + 1, "terracotta1" if z < 3 else "terracotta2")
    struik(m, 3, 3, 6, 2.6, 2.6, 2.8, ["blad2", "blad4", "blad1"], 25, ["bloem_rood", "bloem_roze"])
    return m


@tile("props/planten/boombak")
def boombak():
    m = V(20, 20, 56)
    m.box(1, 1, 0, 19, 19, 5, mix("beton1", "beton3", seed=26))
    m.box(2, 2, 4, 18, 18, 5, "aarde_donker")
    for z in range(5, 28):
        m.cyl(10, 10, 1.1, z, z + 1, "schors1")
    struik(m, 10, 10, 40, 8.5, 8.5, 12, ["blad1", "blad2", "blad4", "blad_licht"], 27)
    return m


@tile("props/planten/struik")
def struik_rond():
    m = V(12, 12, 9)
    struik(m, 6, 6, 4, 5.5, 5.5, 4.5, ["blad1", "blad3", "blad5", "blad2"], 28)
    return m


@tile("props/planten/struik_bloei")
def struik_bloei():
    m = V(12, 12, 9)
    struik(m, 6, 6, 4, 5.5, 5.5, 4.5, ["blad1", "blad3", "blad2"], 29, ["bloem_roze", "bloesem1", "bloem_wit"])
    return m


@tile("props/planten/hortensia")
def hortensia():
    m = V(10, 10, 8)
    struik(m, 5, 5, 3.5, 4.5, 4.5, 3.8, ["blad2", "blad1"], 30, ["bloem_paars", "bloem_roze", "luifel_blauw"])
    return m


@tile("props/planten/buxus_bol")
def buxus():
    m = V(8, 8, 8)
    m.box(1, 1, 0, 7, 7, 2, "terracotta2")
    m.ellipsoid(4, 4, 5, 3.2, 3.2, 3, mix("haag1", "haag2", seed=31))
    return m


@tile("props/planten/bloemen")
def bloemen():
    m = V(8, 8, 4)
    for y in range(8):
        for x in range(8):
            if h(x, y, 0, 32) < 0.5:
                m.set(x, y, 0, "blad2")
                m.set(x, y, 1, "blad4")
                if h(x, y, 1, 32) < 0.6:
                    m.set(x, y, 2, pick(["bloem_rood", "bloem_geel", "bloem_paars", "bloem_wit", "bloem_oranje"], x, y, 0, 33))
    return m


@tile("props/planten/varen")
def varen():
    m = V(10, 10, 6)
    for i in range(7):
        a = i / 7 * math.tau
        for t in range(1, 5):
            x = 5 + math.cos(a) * t
            y = 5 + math.sin(a) * t
            z = 1 + t * 0.7 - (t * t) * 0.15
            m.set(x, y, z, "blad4" if t > 2 else "blad2")
    m.set(5, 5, 0, "blad3")
    return m


@tile("props/planten/riet")
def riet():
    m = V(8, 8, 16)
    for y in range(8):
        for x in range(8):
            if h(x, y, 0, 34) < 0.35:
                hh = 8 + int(h(x, y, 1, 34) * 7)
                for z in range(hh):
                    m.set(x, y, z, "riet2" if z < hh // 2 else "riet1")
                m.set(x, y, hh, "riet_pluim")
    return m


@tile("props/planten/graspol")
def graspol():
    m = V(6, 6, 6)
    for y in range(6):
        for x in range(6):
            d = math.hypot(x + 0.5 - 3, y + 0.5 - 3)
            if d < 2.8:
                hh = int(5 - d * 1.4 + h(x, y, 0, 35) * 2)
                for z in range(max(1, hh)):
                    m.set(x, y, z, "gras_droog" if z > 2 else "gras4")
    return m


# ------------------------------------------------------------------ bomen

def trunk(m, cx, cy, height, r, bark):
    for z in range(height):
        rr = r + (0.8 if z < 2 else 0) - z * 0.012
        m.cyl(cx, cy, rr, z, z + 1, bark)


def crown_clusters(m, cx, cy, base, top, radius, n, leaves, seed, shape="rond", blossom=None, light="blad_licht"):
    pts = []
    for i in range(n):
        a = h(i, 0, 0, seed) * math.tau
        t = h(i, 1, 0, seed)
        if shape == "rond":
            r = radius * 0.65 * math.sqrt(h(i, 2, 0, seed))
            z = base + (top - base) * (0.3 + 0.55 * t)
        elif shape == "zuil":
            r = radius * 0.45 * h(i, 2, 0, seed)
            z = base + (top - base) * t
        elif shape == "breed":
            r = radius * 0.75 * math.sqrt(h(i, 2, 0, seed))
            z = base + (top - base) * (0.35 + 0.4 * t)
        else:
            r = radius * 0.6 * h(i, 2, 0, seed)
            z = base + (top - base) * t
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, z))
    for i, (px, py, pz) in enumerate(pts):
        sr = radius * (0.38 + 0.2 * h(i, 3, 0, seed))
        if shape == "zuil":
            sr *= 0.8
        m.line((cx, cy, base - 4), (px, py, pz), "schors2", 0.6)

        def cfun(x, y, z, pz=pz, sr=sr):
            bx, by, bz = x // 2, y // 2, z // 2   # kleur per blokje van 2x2x2: minder losse vlakjes
            if blossom and h(bx, by, bz, seed + 5) < 0.4:
                return pick(blossom, bx, by, bz, seed + 6)
            rel = (z - (pz - sr)) / (2 * sr)
            if rel > 0.7 and h(bx, by, bz, seed + 7) < 0.5:
                return P[light]
            if rel < 0.3:
                return P[leaves[-1]]
            return pick(leaves, bx, by, bz, seed + 8)

        def keep(x, y, z, d):
            return True   # gesloten kruin; de variatie zit in de kleur

        m.ellipsoid(px, py, pz, sr, sr, sr * (1.25 if shape == "zuil" else 0.85), cfun, keep)


def loofboom(seed, size=1.0, leaves=("blad1", "blad2", "blad4", "blad3"), bark="schors1", shape="rond",
             blossom=None, trunk_h=None, light="blad_licht"):
    R = int(18 * size)
    Wd = 2 * R + 6
    Wd += Wd % 2
    Ht = int(72 * size) + 6
    m = V(Wd, Wd, Ht)
    cx = cy = Wd / 2
    th = trunk_h or int(Ht * 0.42)
    trunk(m, cx, cy, th, 1.6 * size + 0.4, bark)
    crown_clusters(m, cx, cy, th, Ht - R * 0.55, R, 6, list(leaves), seed, shape, blossom, light)
    return m


register("props/bomen/linde", lambda: loofboom(101))
register("props/bomen/eik", lambda: loofboom(102, 1.15, ("blad3", "blad1", "blad5", "blad2"), "schors2", "breed"))
register("props/bomen/kastanje", lambda: loofboom(103, 1.1, ("blad5", "blad1", "blad3", "blad5"), "schors2", "rond", ["bloem_wit", "bloesem2"]))
register("props/bomen/plataan", lambda: loofboom(104, 1.2, ("blad2", "blad4", "blad1", "blad3"), "plataanschors", "breed"))
register("props/bomen/herfstboom", lambda: loofboom(105, 1.0, ("herfst1", "herfst2", "herfst3", "herfst2"), "schors1", light="herfst3"))
register("props/bomen/bloesemboom", lambda: loofboom(106, 0.75, ("bloesem1", "bloesem2", "bloesem1", "blad4"), "schors3", light="bloesem2"))
register("props/bomen/jonge_boom", lambda: _jonge_boom())
register("props/bomen/fruitboom", lambda: loofboom(107, 0.6, ("blad2", "blad4", "blad1"), "schors3", blossom=["bloem_rood"]))


def _jonge_boom():
    m = loofboom(108, 0.5, ("blad4", "blad2", "blad_licht"), "schors3")
    cx = m.sx // 2
    for dx in (-3, 3):
        for z in range(0, 14):
            m.set(cx + dx, cx, z, "hout1")
    for x in range(cx - 3, cx + 4):
        m.set(x, cx, 10, "hout2")
    return m


@tile("props/bomen/populier")
def populier():
    m = V(20, 20, 104)
    trunk(m, 10, 10, 30, 1.6, "schors3")
    crown_clusters(m, 10, 10, 26, 98, 12, 12, ["blad2", "blad4", "blad1", "blad3"], 109, "zuil")
    return m


@tile("props/bomen/berk")
def berk():
    m = V(32, 32, 76)
    def bark(x, y, z):
        return P["berkenschors_zwart"] if h(x, y, z // 2, 110) < 0.18 else P["berkenschors"]
    trunk(m, 16, 16, 44, 1.2, bark)
    crown_clusters(m, 16, 16, 34, 70, 12, 10, ["blad4", "blad_licht", "blad2"], 111, "zuil")
    return m


@tile("props/bomen/den")
def den():
    m = V(32, 32, 88)
    trunk(m, 16, 16, 40, 1.4, "schors2")
    for layer in range(9):
        z = 30 + layer * 6
        r = 13 - layer * 1.3
        def keep(x, y, zz, d):
            return True
        m.ellipsoid(16, 16, z, r, r, 3, mix("naald1", "naald2", "naald3", seed=113), keep)
    m.set(16, 16, 86, "naald3")
    m.set(16, 16, 85, "naald3")
    return m


@tile("props/bomen/conifeer")
def conifeer():
    m = V(14, 14, 40)
    trunk(m, 7, 7, 4, 1, "schors2")
    for z in range(3, 38):
        r = 5.5 * (1 - (z - 3) / 38) + 0.6
        m.cyl(7, 7, r, z, z + 1, mix("naald1", "naald2", "naald3", seed=114))
    return m


@tile("props/bomen/treurwilg")
def treurwilg():
    m = V(48, 48, 72)
    trunk(m, 24, 24, 30, 2.2, "schors2")
    crown_clusters(m, 24, 24, 34, 60, 18, 8, ["blad4", "blad_licht", "blad2"], 115, "breed")
    # hangende takken: minder, als blokjes van 2x2 met één kleur per tak
    for i in range(48):
        a = h(i, 0, 0, 116) * math.tau
        r = 10 + h(i, 1, 0, 116) * 10
        x = int(24 + math.cos(a) * r) // 2 * 2
        y = int(24 + math.sin(a) * r) // 2 * 2
        top = 52 - int(r * 0.4)
        length = 18 + int(h(i, 2, 0, 116) * 20)
        kleur = "blad_licht" if i % 3 else "blad4"
        m.box(x, y, max(2, top - length), x + 2, y + 2, top, kleur)
    return m


# ------------------------------------------------------------------ spoor

@tile("props/spoor/bovenleidingmast")
def bovenleidingmast():
    m = V(40, 4, 60)
    for z in range(0, 58):
        for x in (19, 20):
            m.set(x, 1, z, "gegalvaniseerd")
            m.set(x, 2, z, "gegalvaniseerd")
        if z % 6 == 0:
            m.set(19, 0, z, "gegalvaniseerd")
    for x in range(20, 38):
        m.set(x, 1, 52, "gegalvaniseerd")
        m.set(x, 1, 46, "gegalvaniseerd") if x < 34 else None
    for x in range(20, 34, 2):
        m.set(x, 1, 49, "gegalvaniseerd")
    for z in range(42, 52):
        m.set(30, 1, z, "metaal2")
    m.set(30, 1, 41, "rubber")
    return m


@tile("props/spoor/seinpaal")
def seinpaal():
    m = V(6, 4, 36)
    pole(m, 2, 1, 0, 28, "metaal2")
    for z in range(28, 36):
        for x in range(1, 5):
            m.set(x, 1, z, "bord_zwart")
            m.set(x, 2, z, "bord_zwart")
    m.set(2, 0, 33, "stoplicht_groen")
    m.set(2, 0, 30, "stoplicht_rood_uit")
    for x in range(0, 6):
        m.set(x, 0, 27, "bord_wit")
    return m


@tile("props/spoor/spoorboom")
def spoorboom():
    m = V(136, 6, 20)
    for z in range(0, 14):
        for x in range(66, 70):
            for y in range(1, 5):
                m.set(x, y, z, "metaal2" if z < 10 else "bord_wit")
    for x in range(70, 134):
        m.set(x, 2, 8, "bord_rood" if (x // 4) % 2 else "bord_wit")
        m.set(x, 2, 9, "bord_rood" if (x // 4) % 2 else "bord_wit")
    for x in range(66, 70):
        for z in range(14, 20):
            m.set(x, 2, z, "metaal2" if x in (67, 68) else 0)
    # lichten en andreaskruis
    m.set(66, 0, 12, "stoplicht_rood")
    m.set(69, 0, 12, "stoplicht_rood_uit")
    for i in range(-3, 4):
        m.set(68 + i, 1, 17 + i, "bord_rood" if abs(i) < 3 else "bord_wit")
        m.set(68 - i, 1, 17 + i, "bord_rood" if abs(i) < 3 else "bord_wit")
    return m


@tile("props/spoor/andreaskruis")
def andreaskruis():
    m = V(12, 4, 30)
    pole(m, 5, 2, 0, 28, "metaal3")
    for i in range(-5, 6):
        for c in ((6 + i, 22 + i), (6 - i, 22 + i)):
            m.set(c[0], 1, c[1], "bord_rood" if abs(i) % 3 else "bord_wit")
            m.set(c[0], 1, c[1] + 1, "bord_rood" if abs(i) % 3 else "bord_wit")
    m.set(4, 0, 14, "stoplicht_rood")
    m.set(7, 0, 14, "stoplicht_rood_uit")
    return m


# ------------------------------------------------------------------ water

@tile("props/water/steiger")
def steiger():
    m = V(16, 32, 4)
    for y in range(32):
        for x in range(16):
            m.set(x, y, 1, pick(["hout1", "hout2", "hout3"], x // 3, y, 0, 117) if y % 3 else "hout_donker1")
    for x in (0, 15):
        for y in range(0, 32, 8):
            for z in range(0, 4):
                m.set(x, y, z, "hout_donker2")
    return m


@tile("props/water/roeiboot")
def roeiboot():
    m = V(12, 28, 6)
    for y in range(28):
        t = abs(y + 0.5 - 14) / 14
        half = 5.5 * math.sqrt(max(0, 1 - t ** 3))
        for x in range(12):
            dx = abs(x + 0.5 - 6)
            if dx < half:
                for z in range(0, 4):
                    inner = dx < half - 1 and z > 0
                    if not inner or z == 0:
                        m.set(x, y, z, "boot_groen" if z < 3 else "hout1")
        if y % 9 == 4:
            for x in range(2, 10):
                m.set(x, y, 2, "hout2")
    return m


@tile("props/water/sloep")
def sloep():
    m = V(20, 48, 12)
    for y in range(48):
        t = (y + 0.5) / 48
        half = 9 * (1 - max(0, t - 0.7) ** 2 * 6) if t > 0.7 else 9 * min(1, 0.85 + t)
        half = max(1, half)
        for x in range(20):
            dx = abs(x + 0.5 - 10)
            if dx < half:
                for z in range(0, 5):
                    inner = dx < half - 1 and z > 1
                    if not inner:
                        m.set(x, y, z, "boot_wit" if z > 1 else "boot_blauw")
                if dx < half - 1:
                    m.set(x, y, 2, "hout1")
    for x in range(4, 16):
        for y in range(8, 22):
            if x in (4, 15) or y in (8, 21):
                m.set(x, y, 5, "hout2")
    for x in range(5, 15):
        m.set(x, 24, 5, "glas_helder")
        m.set(x, 24, 6, "glas_helder")
        m.set(x, 24, 4, "boot_wit")
    return m


@tile("props/water/woonboot")
def woonboot():
    m = V(36, 96, 28)
    for y in range(96):
        for x in range(36):
            for z in range(0, 6):
                edge = x in (0, 35) or y in (0, 95)
                if z < 5 or edge:
                    m.set(x, y, z, "beton_donker" if z < 2 else "beton2")
    for y in range(6, 90):
        for x in range(3, 33):
            for z in range(6, 22):
                if x in (3, 32) or y in (6, 89):
                    win = (z in range(10, 18)) and (y % 12 in range(3, 10) if x in (3, 32) else x % 10 in range(3, 8))
                    m.set(x, y, z, "glas1" if win else planks(x, y, z))
    for y in range(4, 92):
        for x in range(1, 35):
            m.set(x, y, 22, "antraciet1")
    for y in range(20, 40):
        for x in range(8, 28):
            m.set(x, y, 23, "zonnepaneel")
    for x in range(4, 32, 4):
        m.set(x, 2, 7, "bloem_rood")
        m.set(x, 2, 6, "terracotta1")
    return m


def planks(x, y, z):
    return P["hout_donker1"] if (z % 3 == 0) else pick(["hout1", "hout2", "hout3"], (x + y) // 5, z // 3, 0, 118)


@tile("props/water/meerpaal")
def meerpaal():
    m = V(4, 4, 12)
    for z in range(12):
        m.cyl(2, 2, 1.6, z, z + 1, "hout_donker2" if z < 10 else "hout_donker1")
    return m


@tile("props/water/reddingsboei")
def reddingsboei():
    m = V(8, 4, 12)
    pole(m, 3, 2, 0, 12, "hout2")
    for z in range(3, 10):
        for x in range(8):
            d = math.hypot(x + 0.5 - 4, z + 0.5 - 6.5)
            if 2 < d < 3.6:
                m.set(x, 1, z, "bord_oranje" if int(math.atan2(z - 6.5, x - 4) * 2) % 2 else "bord_wit")
    return m
