"""Gevel-details: losse onderdelen die je tegen een gevel of op een dak plaatst.

Draaipunt = midden van het model; voor gevel-onderdelen ligt de muur precies op
dat midden (het onderdeel steekt naar voren uit, de achterste helft is leeg).
Zo kun je ze in de Details-GridMap (raster 0.5 m) direct tegen een gevel zetten
en rond het muurvlak draaien.
"""
from common import register, tile
from palette import P
from vox import V, mix, pick, h


def att(width, depth, height):
    """Leeg canvas voor een gevel-onderdeel; teken met y = wd(d) (d=0 tegen de muur)."""
    return V(width, depth * 2, height)


def wd(m, d):
    return m.sy // 2 - 1 - d


def luifel(cols, width=32, depth=8, hgt=8):
    m = att(width, depth, hgt)
    for d in range(depth):
        z = hgt - 1 - d // 2
        for x in range(width):
            m.set(x, wd(m, d), z, cols[(x // 3) % len(cols)])
    zl = hgt - 1 - (depth - 1) // 2
    for x in range(width):
        m.set(x, wd(m, depth - 1), zl - 1, cols[(x // 3) % len(cols)])
        if x % 2 == 0:
            m.set(x, wd(m, depth - 1), zl - 2, cols[(x // 3) % len(cols)])
    for x in (0, width - 1):
        for d in range(depth):
            m.set(x, wd(m, d), hgt - 2 - d // 2, "metaal_donker")
    for x in range(width):
        m.set(x, wd(m, 0), hgt - 1, "metaal_donker")
    return m


for _n, _c in {"rood": ["luifel_rood", "luifel_wit"], "groen": ["luifel_groen", "luifel_wit"],
               "blauw": ["luifel_blauw", "luifel_wit"], "geel": ["luifel_geel", "luifel_oranje"],
               "effen_rood": ["luifel_rood"], "effen_groen": ["luifel_groen"]}.items():
    register(f"details/luifels/luifel_{_n}", (lambda c: lambda: luifel(c))(_c))
    register(f"details/luifels/luifel_{_n}_smal", (lambda c: lambda: luifel(c, 16, 6, 6))(_c))


@tile("details/luifels/luifel_glas")
def luifel_glas():
    m = att(32, 8, 4)
    for d in range(8):
        for x in range(32):
            m.set(x, wd(m, d), 3, "glas_helder" if 0 < x < 31 and d < 7 else "metaal3")
    for x in (2, 29):
        for d in range(8):
            m.set(x, wd(m, d), 3 - (7 - d) // 3, "metaal3")
    return m


@tile("details/luifels/luifel_kantoor")
def luifel_kantoor():
    m = att(32, 8, 4)
    for d in range(8):
        for x in range(32):
            m.set(x, wd(m, d), 2, "metaal3")
            m.set(x, wd(m, d), 3, "metaal3")
    for x in range(4, 30, 6):
        m.set(x, wd(m, 4), 1, "lamp_wit")
    return m


def window(width, hgt, frame, roedes=True, sill="natuursteen1", glass="glas1"):
    m = att(width + 2, 3, hgt + 2)
    for z in range(1, hgt + 1):
        for x in range(1, width + 1):
            edge = x in (1, width) or z in (1, hgt)
            r = roedes and (x == (width + 1) // 2 + (0 if width % 2 else 0) or z == hgt // 2 + 1)
            m.set(x, wd(m, 0), z, frame if (edge or r) else glass)
            if edge:
                m.set(x, wd(m, 1), z, frame)
    if sill:
        for x in range(0, width + 2):
            m.set(x, wd(m, 0), 0, sill)
            m.set(x, wd(m, 1), 0, sill)
            m.set(x, wd(m, 2), 0, sill)
    return m


register("details/ramen/raam_klassiek", lambda: window(10, 16, "kozijn_wit"))
register("details/ramen/raam_klassiek_groen", lambda: window(10, 16, "kozijn_groen"))
register("details/ramen/raam_klassiek_klein", lambda: window(6, 8, "kozijn_wit"))
register("details/ramen/raam_modern", lambda: window(14, 16, "antraciet1", roedes=False, sill="zink1", glass="glas2"))
register("details/ramen/raam_modern_breed", lambda: window(26, 14, "antraciet1", roedes=False, sill="zink1", glass="glas2"))
register("details/ramen/raam_modern_staand", lambda: window(6, 20, "antraciet1", roedes=False, sill=None, glass="glas2"))


@tile("details/ramen/raam_rond")
def raam_rond():
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
def vensterbank():
    m = att(12, 3, 2)
    for x in range(12):
        for d in range(3):
            m.set(x, wd(m, d), 1, "natuursteen1")
        m.set(x, wd(m, 0), 0, "natuursteen2")
    return m


@tile("details/ramen/vensterbank_modern")
def vensterbank_modern():
    m = att(16, 2, 1)
    for x in range(16):
        for d in range(2):
            m.set(x, wd(m, d), 0, "zink1")
    return m


@tile("details/ramen/luiken")
def luiken():
    m = att(18, 1, 16)
    for x in list(range(0, 4)) + list(range(14, 18)):
        for z in range(16):
            edge = x in (0, 3, 14, 17) or z in (0, 15)
            diag = (z % 8) == (x % 4) * 2
            m.set(x, wd(m, 0), z, "kozijn_groen" if (edge or not diag) else "kozijn_wit")
    return m


@tile("details/ramen/bloembak")
def bloembak():
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


def deur(color, width=8, hgt=19, glass=False, frame="kozijn_wit", transom=True):
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


register("details/deuren/deur_klassiek_groen", lambda: deur("deur_groen"))
register("details/deuren/deur_klassiek_rood", lambda: deur("deur_rood"))
register("details/deuren/deur_klassiek_zwart", lambda: deur("deur_zwart"))
register("details/deuren/deur_klassiek_blauw", lambda: deur("deur_blauw"))
register("details/deuren/deur_modern_hout", lambda: deur("hout1", 8, 18, True, "antraciet1", False))
register("details/deuren/deur_modern_antraciet", lambda: deur("antraciet2", 8, 18, True, "antraciet1", False))
register("details/deuren/deur_dubbel", lambda: deur("deur_groen", 14, 20, True))


@tile("details/deuren/schuifdeur_glas")
def schuifdeur():
    m = att(18, 2, 18)
    for z in range(18):
        for x in range(18):
            edge = x in (0, 17) or z == 17 or x in (8, 9)
            m.set(x, wd(m, 0), z, "metaal3" if edge else "glas_helder")
            if edge:
                m.set(x, wd(m, 1), z, "metaal3")
    return m


@tile("details/deuren/garagedeur")
def garagedeur():
    m = att(24, 1, 16)
    for z in range(16):
        for x in range(24):
            edge = x in (0, 23) or z == 15
            m.set(x, wd(m, 0), z, "antraciet1" if edge else ("metaal1" if (z // 2) % 2 else "metaal2"))
    return m


@tile("details/deuren/stoeptrap")
def stoeptrap():
    m = att(12, 4, 3)
    for d in range(4):
        for x in range(12):
            for z in range(3 - d // 2 if d < 4 else 1):
                m.set(x, wd(m, d), z, "natuursteen1" if z == 2 - d // 2 else "natuursteen2")
    return m


@tile("details/balkons/balkon_klassiek")
def balkon_klassiek():
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
def balkon_frans():
    m = att(12, 1, 8)
    for x in range(12):
        m.set(x, wd(m, 0), 7, "metaal_donker")
        m.set(x, wd(m, 0), 0, "metaal_donker")
        if x % 2 == 0:
            for z in range(8):
                m.set(x, wd(m, 0), z, "metaal_donker")
    return m


@tile("details/balkons/balkon_modern")
def balkon_modern():
    m = att(28, 8, 10)
    for d in range(8):
        for x in range(28):
            m.set(x, wd(m, d), 0, "beton1")
            m.set(x, wd(m, d), 1, "beton2")
    for x in range(28):
        for z in range(2, 9):
            m.set(x, wd(m, 7), z, "glas_helder")
        m.set(x, wd(m, 7), 9, "metaal3")
    for x in (0, 27):
        for d in range(8):
            for z in range(2, 9):
                m.set(x, wd(m, d), z, "glas_helder")
            m.set(x, wd(m, d), 9, "metaal3")
    return m


@tile("details/balkons/balkon_hout")
def balkon_hout():
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


@tile("details/dak/schoorsteen")
def schoorsteen():
    m = V(6, 6, 16)
    for z in range(14):
        for y in range(1, 5):
            for x in range(1, 5):
                m.set(x, y, z, pick(["baksteen2", "baksteen4", "donkersteen1"], (x + y) // 2, z, 0, 5))
    for y in range(6):
        for x in range(6):
            m.set(x, y, 14, "natuursteen2")
    m.set(2, 2, 15, "metaal_donker")
    m.set(3, 3, 15, "metaal_donker")
    m.set(2, 3, 15, "metaal_donker")
    m.set(3, 2, 15, "metaal_donker")
    return m


@tile("details/dak/schoorsteen_dubbel")
def schoorsteen_dubbel():
    m = V(10, 6, 18)
    for z in range(16):
        for y in range(1, 5):
            for x in range(1, 9):
                m.set(x, y, z, pick(["baksteen2", "baksteen4", "donkersteen1"], (x + y) // 2, z, 0, 6))
    for y in range(6):
        for x in range(10):
            m.set(x, y, 16, "natuursteen2")
    for x in (3, 6):
        m.set(x, 2, 17, "terracotta1")
        m.set(x, 3, 17, "terracotta1")
    return m


@tile("details/dak/zonnepanelen")
def zonnepanelen():
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
def dakraam():
    m = V(10, 12, 2)
    for y in range(12):
        for x in range(10):
            edge = x in (0, 9) or y in (0, 11)
            m.set(x, y, 0, "antraciet1")
            m.set(x, y, 1, "antraciet1" if edge else "glas1")
    return m


@tile("details/dak/schotel")
def schotel():
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
def antenne():
    m = V(8, 8, 20)
    for z in range(20):
        m.set(4, 4, z, "metaal2")
    for z in (12, 15, 18):
        for x in range(1, 8):
            m.set(x, 4, z, "metaal2")
    return m


@tile("details/gevel/airco")
def airco():
    m = att(8, 4, 6)
    for d in range(4):
        for x in range(8):
            for z in range(6):
                m.set(x, wd(m, d), z, "stuc1")
    for x in range(1, 7):
        for z in range(1, 5):
            dd = ((x + 0.5 - 4) ** 2 + (z + 0.5 - 3) ** 2) ** 0.5
            if dd < 2.2:
                m.set(x, wd(m, 3), z, "metaal_donker" if (x + z) % 2 else "metaal2")
    return m


@tile("details/gevel/regenpijp")
def regenpijp():
    m = att(2, 2, 24)
    for z in range(24):
        m.set(0, wd(m, 1), z, "zink2")
        m.set(1, wd(m, 1), z, "zink2")
        if z % 8 == 4:
            m.set(0, wd(m, 0), z, "metaal_donker")
    m.set(0, wd(m, 0), 0, "zink1")
    return m


@tile("details/gevel/buitenlamp")
def buitenlamp():
    m = att(4, 3, 6)
    m.set(1, wd(m, 0), 3, "metaal_donker")
    m.set(2, wd(m, 0), 3, "metaal_donker")
    for z in range(1, 5):
        for x in (1, 2):
            m.set(x, wd(m, 1), z, "lamp_warm" if 1 < z < 4 else "metaal_donker")
            m.set(x, wd(m, 2), z, "lamp_warm" if 1 < z < 4 else "metaal_donker")
    return m


@tile("details/gevel/buitenlamp_modern")
def buitenlamp_modern():
    m = att(4, 2, 4)
    for x in range(4):
        for z in range(4):
            m.set(x, wd(m, 0), z, "antraciet1")
        m.set(x, wd(m, 1), 0, "lamp_wit")
        m.set(x, wd(m, 1), 3, "antraciet1")
    return m


@tile("details/gevel/uithangbord")
def uithangbord():
    m = att(2, 10, 12)
    for d in range(10):
        m.set(0, wd(m, d), 11, "metaal_donker")
        m.set(1, wd(m, d), 11, "metaal_donker")
    for d in range(2, 10):
        for z in range(2, 10):
            edge = d in (2, 9) or z in (2, 9)
            c = "messing" if edge else ("bord_rood" if (d + z) % 5 else "bord_wit")
            m.set(0, wd(m, d), z, c)
            m.set(1, wd(m, d), z, c)
    m.set(0, wd(m, 3), 10, "metaal_donker")
    m.set(0, wd(m, 8), 10, "metaal_donker")
    return m


@tile("details/gevel/vlag")
def vlag():
    m = att(2, 16, 24)
    for d in range(16):
        z = d // 2 + 4
        m.set(0, wd(m, d), z, "metaal3")
    for d in range(5, 16):
        top = (d // 2 + 4) - 1
        for i, c in enumerate(["vlag_rood", "vlag_rood", "vlag_wit", "vlag_wit", "vlag_blauw", "vlag_blauw"]):
            m.set(1, wd(m, d), top - i, c)
    return m


@tile("details/gevel/klimop")
def klimop():
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
def muuranker():
    m = att(4, 1, 6)
    for z in range(6):
        m.set(2, wd(m, 0), z, "metaal_donker")
    for x in range(4):
        m.set(x, wd(m, 0), 3, "metaal_donker")
    return m


@tile("details/gevel/hijsbalk")
def hijsbalk():
    m = att(2, 8, 6)
    for d in range(8):
        m.set(0, wd(m, d), 4, "hout_donker2")
        m.set(1, wd(m, d), 4, "hout_donker2")
        m.set(0, wd(m, d), 5, "hout_donker2")
        m.set(1, wd(m, d), 5, "hout_donker2")
    for z in range(1, 4):
        m.set(0, wd(m, 7), z, "metaal_donker")
    return m


@tile("details/gevel/brievenbus_muur")
def brievenbus_muur():
    m = att(4, 2, 6)
    for z in range(6):
        for x in range(4):
            m.set(x, wd(m, 0), z, "bord_rood")
            m.set(x, wd(m, 1), z, "bord_rood" if z < 5 else "bord_rood2")
    m.set(1, wd(m, 1), 4, "rubber")
    m.set(2, wd(m, 1), 4, "rubber")
    return m


@tile("details/gevel/huisnummer")
def huisnummer():
    m = att(6, 1, 4)
    for z in range(4):
        for x in range(6):
            m.set(x, wd(m, 0), z, "bord_blauw" if 0 < x < 5 and 0 < z < 3 else "bord_wit")
    m.set(2, wd(m, 0), 1, "bord_wit")
    m.set(3, wd(m, 0), 2, "bord_wit")
    return m


@tile("details/gevel/reclamebord")
def reclamebord():
    m = att(28, 1, 6)
    for z in range(6):
        for x in range(28):
            edge = x in (0, 27) or z in (0, 5)
            m.set(x, wd(m, 0), z, "metaal_donker" if edge else pick(["reclame1", "reclame2", "reclame3"], x // 7, 0, 0, 10))
    return m


@tile("details/gevel/dakgoot")
def dakgoot():
    m = att(32, 2, 2)
    for x in range(32):
        m.set(x, wd(m, 1), 0, "zink1")
        m.set(x, wd(m, 1), 1, "zink1")
        m.set(x, wd(m, 0), 0, "zink1")
    return m


@tile("details/gevel/kroonlijst")
def kroonlijst():
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
