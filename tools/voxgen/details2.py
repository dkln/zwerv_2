"""Uitbreiding details: koelinstallaties, zonnepanelen, zonwering, gevelteksten, vlaggen."""
import math

from common import register, tile, text_pixels
from palette import P
from vox import V, mix, pick, h
from details import att, wd


# ------------------------------------------------------------------ dak: installaties en zonnepanelen

@tile("details/dak/koelinstallatie")
def koelinstallatie():
    m = V(24, 16, 10)
    m.box(0, 0, 0, 24, 16, 1, "metaal2")
    m.box(1, 1, 1, 23, 15, 7, "metaal1")
    for cx in (6, 12, 18):
        for cy in (5, 11):
            m.cyl(cx, cy, 2.6, 7, 8, "metaal_donker")
            m.set(cx, cy, 8, "metaal3")
            m.set(cx - 1, cy, 7, "rooster")
    for x in range(1, 23):
        if x % 2 == 0:
            for z in range(2, 6):
                m.set(x, 0, z, "rooster")
    return m


@tile("details/dak/luchtbehandeling")
def luchtbehandeling():
    m = V(32, 12, 12)
    m.box(0, 2, 0, 28, 12, 9, "metaal1")
    m.box(0, 2, 9, 28, 12, 10, "metaal2")
    for z in range(2, 7):
        m.set(29, 7, z, "metaal3")
    m.cyl(30, 7, 2, 0, 11, "metaal3")
    for x in range(2, 26, 6):
        m.box(x, 1, 2, x + 4, 2, 7, "rooster")
    return m


@tile("details/dak/airco_buitenunit")
def airco_buitenunit():
    m = V(8, 6, 7)
    m.box(0, 1, 0, 8, 5, 6, "stuc1")
    m.cyl(4, 1, 2.2, 1, 5, "metaal_donker") if False else None
    for x in range(1, 7):
        for z in range(1, 5):
            if math.hypot(x + 0.5 - 4, z + 0.5 - 3) < 2.4:
                m.set(x, 0, z, "rooster" if (x + z) % 2 else "metaal2")
    return m


@tile("details/dak/ventilatiekap")
def ventilatiekap():
    m = V(6, 6, 8)
    m.cyl(3, 3, 1.4, 0, 6, "zink1")
    m.cyl(3, 3, 2.6, 6, 7, "zink2")
    m.cyl(3, 3, 1.6, 7, 8, "zink2")
    return m


@tile("details/dak/zonnepanelen_schuin_rij")
def zonnepanelen_schuin():
    m = V(32, 12, 8)
    for y in range(10):
        z = 1 + y // 2
        for x in range(32):
            m.set(x, y + 1, z, "metaal3" if x % 8 == 0 else "zonnepaneel")
    for x in (1, 15, 30):
        for y in range(1, 11):
            m.set(x, y, 0, "metaal2")
        for z in range(0, 6):
            m.set(x, 10, z, "metaal2")
    return m


@tile("details/dak/zonnepanelen_groot")
def zonnepanelen_groot():
    m = V(32, 32, 3)
    for y in range(32):
        for x in range(32):
            m.set(x, y, 1, "metaal3" if (x % 8 == 0 or y % 12 == 0) else "zonnepaneel")
        m.set(0, y, 0, "metaal2")
        m.set(31, y, 0, "metaal2")
    return m


@tile("details/dak/zonnepanelen_klein")
def zonnepanelen_klein():
    m = V(16, 12, 3)
    for y in range(12):
        for x in range(16):
            m.set(x, y, 1, "metaal3" if (x % 8 == 0 or y == 0) else "zonnepaneel")
    return m


@tile("details/dak/zonneboiler")
def zonneboiler():
    m = V(16, 12, 10)
    for y in range(10):
        z = 1 + y // 2
        for x in range(1, 15):
            m.set(x, y, z, "metaal3" if x in (1, 14) else ("glas_helder" if x % 2 else "metaal_donker"))
    for x in range(1, 15):
        m.cyl(x, 10, 1.4, 6, 9, "rvs") if False else None
        for z in (7, 8):
            m.set(x, 10, z, "rvs")
            m.set(x, 11, z, "rvs")
    return m


@tile("details/dak/dakkapel_los")
def dakkapel_los():
    m = V(16, 12, 12)
    m.box(0, 0, 0, 16, 12, 10, "kozijn_wit")
    m.box(-1, -1, 10, 17, 13, 11, "zink1")
    m.box(2, 0, 2, 14, 1, 9, "glas1")
    for z in range(2, 9):
        m.set(8, 0, z, "kozijn_wit")
    return m


# ------------------------------------------------------------------ zonwering

def zonwering(cols, width=24, depth=8, uitval=False):
    m = att(width, depth, 14 if uitval else 8)
    hgt = m.sz
    if uitval:
        # uitvalscherm: doek schuin naar beneden-voren, armen vanaf de zijkant
        for d in range(depth):
            z = hgt - 1 - d
            for x in range(width):
                m.set(x, wd(m, d), z, cols[(x // 3) % len(cols)])
        for x in (0, width - 1):
            for d in range(depth):
                m.set(x, wd(m, d), hgt - 2 - d, "metaal3")
    else:
        # knikarmscherm: vrijwel horizontaal doek met valletje
        for d in range(depth):
            z = hgt - 1 - d // 3
            for x in range(width):
                m.set(x, wd(m, d), z, cols[(x // 3) % len(cols)])
        zl = hgt - 1 - (depth - 1) // 3
        for x in range(width):
            m.set(x, wd(m, depth - 1), zl - 1, cols[(x // 3) % len(cols)])
            if x % 2 == 0:
                m.set(x, wd(m, depth - 1), zl - 2, cols[(x // 3) % len(cols)])
    for x in range(width):
        m.set(x, wd(m, 0), hgt - 1, "metaal3")
    return m


register("details/zonwering/knikarmscherm_streep", lambda: zonwering(["luifel_geel", "luifel_wit"]))
register("details/zonwering/knikarmscherm_groen", lambda: zonwering(["luifel_groen"]))
register("details/zonwering/knikarmscherm_antraciet", lambda: zonwering(["antraciet2"]))
register("details/zonwering/uitvalscherm_oranje", lambda: zonwering(["luifel_oranje", "luifel_oranje", "luifel_wit"], 12, 6, True))
register("details/zonwering/uitvalscherm_blauw", lambda: zonwering(["luifel_blauw", "luifel_wit"], 12, 6, True))


@tile("details/zonwering/rolluik")
def rolluik():
    m = att(12, 1, 18)
    for z in range(18):
        for x in range(12):
            m.set(x, wd(m, 0), z, "metaal1" if z % 2 else "metaal2")
    for x in range(12):
        m.set(x, wd(m, 0), 17, "antraciet1")
    return m


@tile("details/zonwering/screen")
def screen():
    m = att(12, 1, 18)
    for z in range(18):
        for x in range(12):
            m.set(x, wd(m, 0), z, "antraciet1" if (z == 17 or x in (0, 11)) else "antraciet2")
    return m


@tile("details/zonwering/markies")
def markies():
    m = att(12, 4, 10)
    for d in range(4):
        r = 4 - d
        for z in range(10 - r * 2, 10):
            for x in range(12):
                m.set(x, wd(m, d), z, "luifel_rood" if (x // 2) % 2 else "luifel_wit")
    return m


# ------------------------------------------------------------------ gevel met tekst

WOORDEN = ["HOTEL", "THEATER", "BIOSCOOP", "STATION", "BAKKERIJ", "APOTHEEK", "ZWERVR", "MUSEUM", "SCHOOL",
           "RAADHUIS", "BIBLIOTHEEK", "ZWEMBAD", "SPORTHAL", "POLITIE", "MARKT", "CAFE", "HAVEN", "KERK"]


def gevel_tekst(word, scale=2, letter="goud", plate=None, licht=False):
    px, (tw, th) = text_pixels(word)
    w = tw * scale + 4
    w += w % 2
    hgt = 5 * scale + 4
    m = att(w, 2, hgt)
    if plate:
        for z in range(hgt):
            for x in range(w):
                m.set(x, wd(m, 0), z, plate)
    for (c, r) in px:
        for sx in range(scale):
            for sz in range(scale):
                m.set(2 + c * scale + sx, wd(m, 1), 2 + (4 - r) * scale + sz, "lamp_warm" if licht else letter)
    return m


for _w in WOORDEN:
    register(f"details/tekst/tekst_{_w.lower()}", (lambda w: lambda: gevel_tekst(w))(_w))
for _w in ("HOTEL", "THEATER", "BIOSCOOP", "CAFE", "ZWERVR"):
    register(f"details/tekst/lichtreclame_{_w.lower()}", (lambda w: lambda: gevel_tekst(w, 2, plate="bord_zwart", licht=True))(_w))
for _w in ("BAKKER", "SLAGER", "KAAS", "BLOEMEN", "FIETSEN", "KAPPER"):
    register(f"details/tekst/bord_{_w.lower()}", (lambda w: lambda: gevel_tekst(w, 1, "bord_wit", "deur_groen"))(_w))


# ------------------------------------------------------------------ vlaggen aan de gevel

def gevelvlag(kleuren):
    m = att(2, 16, 24)
    for d in range(16):
        z = d // 2 + 4
        m.set(0, wd(m, d), z, "metaal3")
    for d in range(5, 16):
        top = (d // 2 + 4) - 1
        for i, c in enumerate(kleuren):
            m.set(1, wd(m, d), top - i, c)
    return m


from props2 import FLAGS
for _k, _c in FLAGS.items():
    register(f"details/gevel/vlag_{_k}", (lambda c: lambda: gevelvlag(c))(_c))


@tile("details/gevel/vlag_regenboog_hangend")
def vlag_regenboog_hangend():
    m = att(12, 2, 20)
    cols = ["vlag_rood", "vlag_oranje", "vlag_geel", "vlag_groen", "vlag_blauw", "vlag_paars"]
    for x in range(12):
        m.set(x, wd(m, 1), 19, "metaal3")
        for z in range(0, 19):
            m.set(x, wd(m, 1), z, cols[x // 2])
    return m


# ------------------------------------------------------------------ opstap-trappetjes voor klassieke huizen

def opstap(treden, breedte=12, leuning=False, bordes=False):
    diepte = treden * 2 + (4 if bordes else 0)
    m = att(breedte + (4 if bordes else 0), diepte, treden + 8)
    w = m.sx
    for d in range(diepte):
        hoogte = treden if d < (4 if bordes else 0) else treden - (d - (4 if bordes else 0)) // 2
        for x in range(w):
            for z in range(hoogte):
                m.set(x, wd(m, d), z, "natuursteen1" if z == hoogte - 1 else "natuursteen2")
    if leuning:
        for x in (0, w - 1):
            for d in range(diepte):
                hoogte = treden if d < (4 if bordes else 0) else treden - (d - (4 if bordes else 0)) // 2
                m.set(x, wd(m, d), hoogte + 6, "metaal_donker")
                if d % 3 == 0:
                    for z in range(hoogte, hoogte + 6):
                        m.set(x, wd(m, d), z, "metaal_donker")
    return m


register("details/deuren/opstap_2_treden", lambda: opstap(2))
register("details/deuren/opstap_3_treden", lambda: opstap(3))
register("details/deuren/opstap_4_treden_leuning", lambda: opstap(4, leuning=True))
register("details/deuren/bordes_klassiek", lambda: opstap(4, 12, True, True))


# ------------------------------------------------------------------ garagedeuren

def garagedeur(kind, width=24):
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
    register(f"details/deuren/garagedeur_{_k}", (lambda k: lambda: garagedeur(k))(_k))
