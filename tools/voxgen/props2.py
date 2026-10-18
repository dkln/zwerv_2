"""Uitbreiding props: hekwerk, poorten, muurtjes, terrassen, speeltuin, bosjes,
containers, steigers, zwembad, vlaggen, plaatsnaamborden, drukknoppaal."""
import math

from common import register, tile, text_pixels
from palette import P
from vox import V, mix, pick, h
from props import pole, struik, fiets, trunk, crown_clusters, loofboom, bord

BRICK = lambda seed: (lambda x, y, z: pick(["baksteen1", "baksteen2", "baksteen3", "baksteen4"], (x + y + (z % 2) * 2) // 3, z, 0, seed))


# ------------------------------------------------------------------ hekwerk en poorten

@tile("props/hekken/hek_hoog_spijlen")
def hek_hoog_spijlen():
    m = V(16, 2, 20)
    for x in range(16):
        m.set(x, 0, 2, "antraciet1")
        m.set(x, 0, 17, "antraciet1")
        if x % 2 == 0:
            for z in range(0, 19):
                m.set(x, 0, z, "antraciet1")
            m.set(x, 0, 19, "antraciet1") if x % 4 == 0 else None
    for x in (0, 15):
        for z in range(20):
            m.set(x, 1, z, "antraciet1")
    return m


@tile("props/hekken/hek_gaas_hoog")
def hek_gaas_hoog():
    m = V(24, 2, 17)
    for x in range(24):
        for z in range(0, 16):
            if x in (0, 23) or z in (0, 15) or (x + z) % 2 == 0:
                m.set(x, 0, z, "bord_groen2" if x not in (0, 23) else "gegalvaniseerd")
    for z in range(17):
        m.set(0, 1, z, "gegalvaniseerd")
        m.set(23, 1, z, "gegalvaniseerd")
    return m


@tile("props/hekken/schoolhek")
def schoolhek():
    m = V(16, 2, 10)
    for x in range(16):
        m.set(x, 0, 1, "paneel_groen")
        m.set(x, 0, 8, "paneel_groen")
        if x % 2 == 0:
            for z in range(0, 10):
                m.set(x, 0, z, "paneel_groen")
    return m


def poort(width=32, color="amsterdamgroen", pillar=True):
    m = V(width + 12, 8, 26)
    if pillar:
        for x0 in (0, width + 6):
            for z in range(0, 22):
                for x in range(x0, x0 + 6):
                    for y in range(1, 7):
                        m.set(x, y, z, BRICK(400)(x, y, z))
            for x in range(x0 - 1, x0 + 7):
                for y in range(0, 8):
                    m.set(x, y, 22, "natuursteen1")
            m.ellipsoid(x0 + 3, 4, 24, 2, 2, 2, "natuursteen1")
    for x in range(6, width + 6):
        dx = x + 0.5 - (width / 2 + 6)
        top = 16 + int(4 * (1 - (dx / (width / 2)) ** 2))
        for z in range(0, top):
            if x % 2 == 0 or z in (1, 8, top - 1):
                m.set(x, 4, z, color)
    m.set(width // 2 + 5, 3, 8, "messing")
    m.set(width // 2 + 7, 3, 8, "messing")
    for z in range(0, 18):
        m.set(width // 2 + 6, 4, z, color)
    return m


register("props/hekken/poort_groot", lambda: poort())
register("props/hekken/poort_klein", lambda: poort(12))
register("props/hekken/poort_hout", lambda: poort(20, "hout2", True))


@tile("props/hekken/poortpijler")
def poortpijler():
    m = V(8, 8, 26)
    for z in range(22):
        for x in range(1, 7):
            for y in range(1, 7):
                m.set(x, y, z, BRICK(401)(x, y, z))
    for x in range(8):
        for y in range(8):
            m.set(x, y, 22, "natuursteen1")
    m.ellipsoid(4, 4, 24, 2, 2, 2, "natuursteen1")
    return m


# ------------------------------------------------------------------ muurtjes

def muurtje(mat, hgt, length=16, cap="natuursteen2", depth=3):
    m = V(length, 4, hgt + 1)
    for z in range(hgt):
        for x in range(length):
            for y in range(1, 1 + depth):
                m.set(x, y, z, mat(x, y, z) if callable(mat) else P[mat])
    if cap:
        for x in range(length):
            for y in range(0, 2 + depth):
                if y < 4:
                    m.set(x, y, hgt, cap)
    return m


register("props/muurtjes/muurtje_baksteen", lambda: muurtje(BRICK(402), 5))
register("props/muurtjes/muurtje_baksteen_hoog", lambda: muurtje(BRICK(403), 14))
register("props/muurtjes/muurtje_natuursteen", lambda: muurtje(lambda x, y, z: pick(["natuursteen1", "natuursteen2", "natuursteen3"], (x + (z % 2) * 2) // 4, z, 0, 404), 6, cap="natuursteen1"))
register("props/muurtjes/muurtje_beton", lambda: muurtje(mix("beton1", "beton2", "beton3", seed=405), 5, cap=None))
register("props/muurtjes/zitrand_beton", lambda: muurtje(mix("beton1", "beton3", seed=406), 3, cap="hout_bank1"))
register("props/muurtjes/muurtje_kort", lambda: muurtje(BRICK(407), 5, 8))


@tile("props/muurtjes/muurtje_hoek")
def muurtje_hoek():
    m = V(16, 16, 6)
    f = BRICK(408)
    for z in range(5):
        for x in range(16):
            for y in range(13, 16):
                m.set(x, y, z, f(x, y, z))
        for y in range(16):
            for x in range(0, 3):
                m.set(x, y, z, f(x, y, z))
    for x in range(16):
        for y in range(16):
            if m.get(x, y, 4):
                m.set(x, y, 5, "natuursteen2")
    return m


# ------------------------------------------------------------------ terras

def stoel(m, x, y, color="metaal_donker", facing=1):
    for z in range(0, 4):
        m.set(x, y, z, color)
        m.set(x + 2, y, z, color)
        m.set(x, y + 2, z, color)
        m.set(x + 2, y + 2, z, color)
    for dx in range(3):
        for dy in range(3):
            m.set(x + dx, y + dy, 3, "hout_bank2")
    by = y + (2 if facing > 0 else 0)
    for dx in range(3):
        for z in range(4, 7):
            m.set(x + dx, by, z, color)


def terras_set(parasol=False, kleur="luifel_rood"):
    m = V(20 if not parasol else 24, 20 if not parasol else 24, 22 if parasol else 8)
    c = m.sx // 2
    for z in range(0, 5):
        m.set(c, c, z, "metaal_donker")
    m.cyl(c, c, 3, 5, 6, "hout_bank1")
    stoel(m, c - 1, c - 8, facing=-1)
    stoel(m, c - 1, c + 5, facing=1)
    if parasol:
        for z in range(6, 19):
            m.set(c, c, z, "hout2")
        for z in range(15, 20):
            r = 11 - (z - 15) * 2.2
            for y in range(m.sy):
                for x in range(m.sx):
                    d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                    if r - 1.4 < d <= r:
                        ang = math.atan2(y - c, x - c)
                        m.set(x, y, z, kleur if int((ang + 4) * 4 / math.pi) % 2 else "luifel_wit")
    return m


register("props/terras/terras_set", lambda: terras_set())
register("props/terras/terras_set_parasol", lambda: terras_set(True))
register("props/terras/terras_set_parasol_groen", lambda: terras_set(True, "luifel_groen"))


@tile("props/terras/terras_scherm")
def terras_scherm():
    m = V(24, 2, 12)
    for x in range(24):
        for z in range(0, 12):
            edge = x in (0, 23) or z in (0, 11) or x % 8 == 0
            m.set(x, 0, z, "metaal3" if edge else ("glas_helder" if z > 4 else "luifel_rood"))
    return m


@tile("props/terras/stoepbord")
def stoepbord():
    m = V(6, 6, 8)
    for z in range(8):
        for x in range(6):
            yy = 1 + z // 3
            m.set(x, yy, z, "hout2" if x in (0, 5) or z in (0, 7) else "bord_zwart")
            m.set(x, 5 - z // 3 - 1 + 1, z, "hout2" if x in (0, 5) or z in (0, 7) else "bord_zwart")
    for x in (1, 3):
        m.set(x, 2, 5, "bord_wit")
        m.set(x + 1, 2, 3, "bord_wit")
    return m


@tile("props/terras/statafel")
def statafel():
    m = V(8, 8, 10)
    for z in range(9):
        m.set(4, 4, z, "metaal3")
    m.cyl(4, 4, 3, 9, 10, "hout_bank1")
    m.cyl(4, 4, 2, 0, 1, "metaal3")
    return m


@tile("props/terras/bloembak_terras")
def bloembak_terras():
    m = V(16, 6, 9)
    m.box(0, 1, 0, 16, 5, 4, "hout_donker1")
    struik(m, 8, 3, 6, 7, 2.5, 3, ["blad2", "blad1", "blad4"], 409, ["bloem_rood", "bloem_wit"])
    return m


# ------------------------------------------------------------------ speeltuin

@tile("props/speeltuin/schommel")
def schommel():
    m = V(28, 16, 22)
    for (x0, x1) in ((1, 26),):
        for t in range(0, 21):
            for x in (x0, x1):
                m.set(x, 8 - t * 6 // 21, t, "paneel_rood")
                m.set(x, 8 + t * 6 // 21, t, "paneel_rood")
    for x in range(1, 27):
        m.set(x, 8, 21, "paneel_rood")
    for xs in (8, 18):
        for z in range(6, 21):
            m.set(xs, 8, z, "metaal3")
            m.set(xs + 3, 8, z, "metaal3")
        for x in range(xs, xs + 4):
            m.set(x, 8, 5, "rubber")
    return m


@tile("props/speeltuin/glijbaan")
def glijbaan():
    m = V(12, 36, 20)
    for z in range(0, 14):
        for y in (2, 7):
            m.set(3, y, z, "paneel_geel")
            m.set(8, y, z, "paneel_geel")
    for y in range(2, 8):
        for x in range(3, 9):
            m.set(x, y, 13, "hout2")
    for z in range(14, 19):
        for y in (2, 7):
            m.set(3, y, z, "paneel_geel")
            m.set(8, y, z, "paneel_geel")
    for x in range(3, 9):
        m.set(x, 2, 18, "paneel_rood")
        m.set(x, 7, 18, "paneel_rood")
    for i in range(14):
        m.set(5, 1 - 0 if False else 0, 0, 0)
        for x in range(4, 8):
            m.set(x, 1 - i // 14, 13 - i, "rvs") if False else None
    for y in range(8, 34):
        z = max(0, 13 - (y - 8) // 2)
        for x in range(4, 8):
            m.set(x, y, z, "rvs")
        m.set(3, y, z + 1, "rvs")
        m.set(8, y, z + 1, "rvs")
    for z in range(0, 13):
        for x in (3, 8):
            m.set(x, 1 - 0, z, "paneel_geel")
        if z % 2 == 0:
            for x in range(4, 8):
                m.set(x, 0, z, "hout2")
    return m


@tile("props/speeltuin/klimrek")
def klimrek():
    m = V(24, 24, 16)
    for z in range(0, 16, 5):
        for i in range(0, 24, 5):
            for j in range(24):
                if z < 16:
                    m.set(i, j, z, "paneel_blauw")
                    m.set(j, i, z, "paneel_blauw")
    for x in range(0, 24, 5):
        for y in range(0, 24, 5):
            for z in range(16):
                m.set(x, y, z, "paneel_blauw")
    return m


@tile("props/speeltuin/wipwap")
def wipwap():
    m = V(28, 6, 8)
    m.box(12, 2, 0, 16, 4, 4, "paneel_rood")
    for x in range(1, 27):
        z = 4 + (x - 14) * 3 // 26
        m.set(x, 2, z, "hout2")
        m.set(x, 3, z, "hout2")
    for x in (3, 24):
        z = 4 + (x - 14) * 3 // 26
        for zz in range(z + 1, z + 4):
            m.set(x, 2, zz, "paneel_geel")
    return m


@tile("props/speeltuin/zandbak")
def zandbak():
    m = V(24, 24, 4)
    for y in range(24):
        for x in range(24):
            edge = x in (0, 23) or y in (0, 23)
            for z in range(3 if edge else 2):
                m.set(x, y, z, "hout1" if edge else "zand1")
    m.set(6, 6, 2, "paneel_rood")
    m.set(7, 6, 2, "paneel_rood")
    m.set(14, 15, 2, "paneel_geel")
    return m


@tile("props/speeltuin/draaimolen")
def draaimolen():
    m = V(20, 20, 8)
    m.cyl(10, 10, 9, 1, 2, "paneel_rood")
    m.cyl(10, 10, 1, 0, 8, "metaal3")
    for a in range(4):
        ang = a * math.pi / 2
        for t in range(2, 9):
            m.set(10 + math.cos(ang) * t, 10 + math.sin(ang) * t, 6, "metaal3")
    return m


@tile("props/speeltuin/speelhuisje")
def speelhuisje():
    m = V(16, 16, 24)
    for (x, y) in ((1, 1), (14, 1), (1, 14), (14, 14)):
        for z in range(0, 14):
            m.set(x, y, z, "hout2")
    m.box(1, 1, 8, 15, 15, 9, "hout1")
    for z in range(9, 14):
        for i in range(1, 15):
            if i % 3 == 0:
                m.set(i, 1, z, "hout1")
                m.set(1, i, z, "hout1")
    for z in range(14, 22):
        w = (22 - z)
        m.box(8 - w, 0, z, 8 + w, 16, z + 1, "paneel_rood")
    for z in range(0, 8):
        if z % 2 == 0:
            for x in range(5, 10):
                m.set(x, 0, z, "hout2")
    return m


@tile("props/speeltuin/voetbaldoel")
def voetbaldoel():
    m = V(40, 12, 18)
    for z in range(17):
        m.set(1, 1, z, "bord_wit")
        m.set(38, 1, z, "bord_wit")
    for x in range(1, 39):
        m.set(x, 1, 16, "bord_wit")
    for x in range(1, 39):
        for z in range(16):
            y = 1 + int((16 - z) * 0.6)
            if (x + z) % 3 == 0:
                m.set(x, y, z, "stuc3")
    return m


@tile("props/speeltuin/basketbalpaal")
def basketbalpaal():
    m = V(12, 12, 32)
    pole(m, 5, 9, 0, 28, "metaal3")
    for x in range(1, 11):
        for z in range(22, 30):
            m.set(x, 8, z, "bord_wit" if not (x in (4, 7) and 23 < z < 27) else "bord_rood")
    for x in range(3, 9):
        m.set(x, 6, 23, "bord_oranje")
        m.set(x, 4, 23, "bord_oranje")
    m.set(3, 5, 23, "bord_oranje")
    m.set(8, 5, 23, "bord_oranje")
    return m


@tile("props/speeltuin/pingpongtafel")
def pingpongtafel():
    m = V(24, 14, 8)
    m.box(0, 0, 6, 24, 14, 7, "beton2")
    for x in (3, 20):
        m.box(x, 4, 0, x + 1, 10, 6, "beton1")
    for y in range(14):
        m.set(12, y, 7, "metaal3")
    return m


# ------------------------------------------------------------------ bosjes

def bosje(seed, size):
    m = V(size, size, 40)
    c = size / 2
    n = size // 4
    for i in range(n):
        x = 4 + h(i, 0, 0, seed) * (size - 8)
        y = 4 + h(i, 1, 0, seed) * (size - 8)
        r = 3 + h(i, 2, 0, seed) * 4
        struik(m, x, y, r * 0.7, r, r, r * 0.9, ["blad1", "blad3", "blad5", "haag1", "blad2"], seed + i)
    for i in range(max(1, n // 4)):
        x = 6 + h(i, 5, 0, seed) * (size - 12)
        y = 6 + h(i, 6, 0, seed) * (size - 12)
        trunk(m, x, y, 16, 0.9, "schors2")
        crown_clusters(m, x, y, 14, 32, 7, 4, ["blad1", "blad2", "blad4"], seed + 50 + i)
    return m


register("props/planten/bosje_klein", lambda: bosje(410, 24))
register("props/planten/bosje_groot", lambda: bosje(411, 48))
register("props/planten/struikgewas", lambda: bosje(412, 32))


@tile("props/planten/braamstruik")
def braam():
    m = V(16, 12, 8)
    struik(m, 8, 6, 3, 7.5, 5.5, 4, ["blad3", "blad5", "haag2"], 413, ["bord_zwart", "bloem_rood"])
    return m


# ------------------------------------------------------------------ containers

@tile("props/straat/container_groot")
def container_groot():
    m = V(48, 20, 18)
    for z in range(0, 16):
        for y in range(1, 19):
            for x in range(0, 48):
                edge = x in (0, 47) or y in (1, 18)
                inner = not edge and z > 1
                if not inner:
                    m.set(x, y, z, "paneel_geel" if (x % 4 or z < 2) else "bord_oranje")
    for x in range(0, 48, 6):
        for z in range(2, 16):
            m.set(x, 0, z, "bord_oranje")
            m.set(x, 19, z, "bord_oranje")
    for y in range(2, 18):
        for x in range(1, 47):
            if h(x, y, 0, 414) < 0.7:
                m.set(x, y, 12, pick(["hout1", "stuc2", "beton2", "baksteen2"], x, y, 0, 414))
    return m


@tile("props/straat/container_klein")
def container_klein():
    m = V(12, 10, 12)
    for z in range(1, 11):
        for y in range(1, 9):
            for x in range(0, 12):
                m.set(x, y, z, "metaal1" if z < 10 else "bord_groen")
    for x in (1, 10):
        for y in (1, 8):
            m.set(x, y, 0, "rubber")
    return m


@tile("props/straat/glasbak")
def glasbak():
    m = V(12, 12, 14)
    for z in range(0, 12):
        m.cyl(6, 6, 5, z, z + 1, "bord_groen" if z < 11 else "metaal2")
    for z in range(12, 14):
        m.set(6, 6, z, "metaal2")
    for x in (3, 4, 7, 8):
        m.set(x, 1, 9, "interieur3")
    return m


@tile("props/straat/kledingcontainer")
def kledingcontainer():
    m = V(12, 10, 16)
    m.box(0, 1, 0, 12, 9, 15, "paneel_groen")
    m.box(0, 1, 15, 12, 9, 16, "stuc1")
    m.box(3, 0, 9, 9, 1, 12, "metaal2")
    return m


@tile("props/straat/bouwkeet")
def bouwkeet():
    m = V(48, 20, 22)
    m.box(0, 0, 0, 48, 20, 20, "stuc1")
    m.box(0, 0, 20, 48, 20, 21, "metaal2")
    for x0 in (6, 30):
        m.box(x0, 0, 8, x0 + 10, 1, 15, "glas2")
    m.box(20, 0, 0, 26, 1, 16, "metaal1")
    return m


# ------------------------------------------------------------------ steigers

def steiger_lang(length=32, width=12, trap=False):
    m = V(width, length, 6)
    for y in range(length):
        for x in range(width):
            m.set(x, y, 1, pick(["hout1", "hout2", "hout3"], x // 3, y, 0, 415) if y % 3 else "hout_donker1")
    for x in (0, width - 1):
        for y in range(0, length, 8):
            for z in range(0, 5):
                m.set(x, y, z, "hout_donker2")
    if trap:
        for i in range(4):
            for x in range(3, width - 3):
                m.set(x, length - 1 - i, 1 - i // 2 if i < 2 else 0, "hout_donker1")
    return m


register("props/water/steiger_lang", lambda: steiger_lang(64))
register("props/water/steiger_breed", lambda: steiger_lang(32, 24))
register("props/water/steiger_trap", lambda: steiger_lang(32, 12, True))


@tile("props/water/steiger_L")
def steiger_L():
    m = V(32, 32, 6)
    for y in range(32):
        for x in range(32):
            if x < 10 or y >= 22:
                m.set(x, y, 1, pick(["hout1", "hout2", "hout3"], x // 3, y, 0, 416) if (y + x) % 3 else "hout_donker1")
    for (x, y) in ((0, 0), (9, 0), (0, 31), (31, 31), (31, 22), (9, 22)):
        for z in range(5):
            m.set(x, y, z, "hout_donker2")
    return m


# ------------------------------------------------------------------ zwembad

@tile("props/zwembad/zwembadtrap")
def zwembadtrap():
    m = V(8, 6, 12)
    for x in (1, 6):
        for z in range(0, 11):
            m.set(x, 1 if z < 9 else 1 + (z - 8), z, "rvs")
        m.set(x, 4, 10, "rvs")
    for z in range(1, 8, 2):
        for x in range(2, 6):
            m.set(x, 1, z, "rvs")
    return m


@tile("props/zwembad/duikplank")
def duikplank():
    m = V(8, 32, 8)
    m.box(1, 24, 0, 7, 32, 6, "beton1")
    for y in range(4, 26):
        for x in range(2, 6):
            m.set(x, y, 6, "bord_blauw")
    return m


@tile("props/zwembad/ligstoel")
def ligstoel():
    m = V(8, 18, 8)
    for y in range(2, 16):
        z = 2 if y < 12 else 2 + (y - 11)
        for x in range(1, 7):
            m.set(x, y, z, "bord_wit" if (y % 3) else "paneel_blauw")
    for (x, y) in ((1, 2), (6, 2), (1, 11), (6, 11)):
        for z in range(0, 2):
            m.set(x, y, z, "rvs")
    return m


@tile("props/zwembad/badmeesterstoel")
def badmeesterstoel():
    m = V(10, 10, 24)
    for (x, y) in ((1, 1), (8, 1), (1, 8), (8, 8)):
        for z in range(0, 16):
            m.set(x, y, z, "bord_wit")
    m.box(1, 1, 16, 9, 9, 17, "bord_wit")
    m.box(2, 7, 17, 8, 9, 22, "bord_rood")
    for z in range(0, 16, 2):
        for x in range(2, 8):
            m.set(x, 1, z, "bord_wit")
    return m


@tile("props/zwembad/parasol")
def parasol():
    m = V(24, 24, 20)
    c = 12
    for z in range(0, 16):
        m.set(c, c, z, "hout2")
    m.cyl(c, c, 2, 0, 1, "beton2")
    for z in range(13, 18):
        r = 11 - (z - 13) * 2.4
        m.cyl(c, c, r, z, z + 1, lambda x, y, zz: P["luifel_geel"] if int((math.atan2(y - c, x - c) + 4) * 4 / math.pi) % 2 else P["luifel_wit"])
    return m


# ------------------------------------------------------------------ vlaggen en borden

FLAGS = {
    "nl": ["vlag_rood", "vlag_rood", "vlag_wit", "vlag_wit", "vlag_blauw", "vlag_blauw"],
    "regenboog": ["vlag_rood", "vlag_oranje", "vlag_geel", "vlag_groen", "vlag_blauw", "vlag_paars"],
    "denhaag": ["vlag_geel", "vlag_geel", "vlag_geel", "vlag_groen", "vlag_groen", "vlag_groen"],
    "amsterdam": ["vlag_rood", "vlag_rood", "vlag_zwart", "vlag_zwart", "vlag_rood", "vlag_rood"],
    "rotterdam": ["vlag_groen", "vlag_groen", "vlag_wit", "vlag_wit", "vlag_groen", "vlag_groen"],
    "utrecht": ["vlag_wit", "vlag_wit", "vlag_wit", "vlag_rood", "vlag_rood", "vlag_rood"],
    "transgender": ["vlag_lichtblauw", "vlag_roze", "vlag_wit", "vlag_wit", "vlag_roze", "vlag_lichtblauw"],
    "eu": ["vlag_donkerblauw"] * 6,
    "oranje": ["vlag_oranje"] * 6,
    "zwervr": ["vlag_zwart", "vlag_geel", "vlag_geel", "vlag_geel", "vlag_geel", "vlag_zwart"],
}


def vlaggenmast(kind):
    m = V(28, 4, 64)
    for z in range(64):
        m.set(14, 1, z, "stuc1")
        m.set(14, 2, z, "stuc1")
    m.set(14, 1, 63, "goud")
    cols = FLAGS[kind]
    for x in range(15, 27):
        for i in range(6):
            z = 62 - i
            c = cols[i]
            if kind == "eu" and (x - 15, i) in ((5, 1), (3, 2), (8, 2), (3, 4), (8, 4), (5, 5)):
                c = "vlag_geel"
            if kind == "amsterdam" and i in (2, 3) and x in (17, 20, 23):
                c = "vlag_wit"
            m.set(x, 1, z, c)
    return m


for _k in FLAGS:
    register(f"props/straat/vlaggenmast_{_k}", (lambda k: lambda: vlaggenmast(k))(_k))


def plaatsnaam(text):
    px, (tw, th) = text_pixels(text)
    w = max(32, tw + 6)
    w += w % 2
    m = V(w, 4, 30)
    pole(m, 2, 2, 0, 30, "metaal3")
    pole(m, w - 4, 2, 0, 30, "metaal3")
    for z in range(20, 30):
        for x in range(1, w - 1):
            edge = x in (1, w - 2) or z in (20, 29)
            m.set(x, 1, z, "bord_wit" if edge else "bord_blauw")
            m.set(x, 2, z, "metaal1")
    for (c, r) in px:
        m.set(w // 2 - tw // 2 + c, 0, 27 - r, "bord_wit")
    return m


register("props/borden/bord_plaatsnaam_den_haag", lambda: plaatsnaam("DEN HAAG"))
register("props/borden/bord_plaatsnaam_einde", lambda: _einde())


def _einde():
    m = plaatsnaam("ZWERVR")
    for i in range(3, m.sx - 3):
        z = 21 + int((i - 3) * 7 / (m.sx - 6))
        m.set(i, 0, z, "bord_rood")
    return m


register("props/borden/bord_eenrichting_fiets_uitgezonderd",
         lambda: bord("vierkant", "bord_blauw", "bord_wit", "pijl_rechts", "bord_wit", n=11))
register("props/borden/bord_busbaan", lambda: bord("vierkant", "bord_blauw", "bord_wit", "bus", "bord_wit", n=11))
register("props/borden/bord_fietsstraat",
         lambda: bord("vierkant", "bord_wit", "bord_rood", "fiets_klein", "bord_rood", n=11))


# ------------------------------------------------------------------ fietsers drukknop

@tile("props/verkeer/drukknop_fiets")
def drukknop_fiets():
    m = V(4, 4, 10)
    for z in range(0, 7):
        m.set(1, 1, z, "metaal3")
        m.set(2, 1, z, "metaal3")
    for z in range(7, 10):
        for x in range(0, 4):
            m.set(x, 1, z, "bord_geel")
            m.set(x, 2, z, "bord_geel")
    m.set(1, 0, 8, "bord_zwart")
    m.set(2, 0, 8, "stoplicht_rood")
    return m


@tile("props/verkeer/drukknop_voetganger")
def drukknop_voetganger():
    m = V(4, 4, 14)
    for z in range(0, 14):
        m.set(1, 1, z, "metaal3")
        m.set(2, 1, z, "metaal3")
    for z in range(9, 13):
        for x in range(0, 4):
            m.set(x, 1, z, "bord_geel")
    m.set(1, 0, 11, "bord_zwart")
    m.set(2, 0, 10, "stoplicht_rood")
    return m


@tile("props/verkeer/wegafzetting_paal_flitser")
def flitspaal():
    m = V(6, 6, 28)
    for z in range(0, 18):
        m.cyl(3, 3, 1.2, z, z + 1, "metaal3")
    m.box(1, 1, 18, 5, 5, 27, "bord_geel")
    m.box(2, 0, 22, 4, 1, 25, "interieur3")
    return m


# ------------------------------------------------------------------ verkeerslichten bus/tram en tram-bovenleiding

@tile("props/verkeer/verkeerslicht_bus")
def verkeerslicht_bus():
    """OV-sein: witte balken/punten (stop = horizontale balk)."""
    m = V(8, 4, 32)
    pole(m, 3, 2, 0, 30, "metaal3")
    for z in range(19, 30):
        for x in range(1, 7):
            m.set(x, 1, z, "bord_zwart")
            m.set(x, 2, z, "bord_zwart")
    for x in range(2, 6):
        m.set(x, 0, 27, "lamp_wit")
    for x in (2, 5):
        m.set(x, 0, 23, "stoplicht_rood_uit")
    m.set(3, 0, 21, "lamp_wit")
    m.set(4, 0, 21, "lamp_wit")
    return m


@tile("props/verkeer/verkeerslicht_set")
def verkeerslicht_set():
    """Paal met lichten voor auto, fiets en voetganger samen."""
    from props import light_head
    m = V(16, 4, 32)
    pole(m, 7, 2, 0, 30, "metaal3")
    light_head(m, 6, 1, 19, "rood")
    light_head(m, 1, 1, 9, "groen")
    for z in range(9, 17):
        for x in range(11, 15):
            m.set(x, 1, z, "bord_zwart")
    for (c, r) in [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (0, 3), (2, 3)]:
        m.set(11 + c, 0, 16 - r, "stoplicht_rood")
    for x in range(1, 15):
        m.set(x, 2, 12, "metaal3")
    return m


@tile("props/ov/tram_bovenleiding_mast")
def tram_bovenleiding_mast():
    m = V(72, 4, 56)
    for z in range(0, 54):
        m.set(35, 1, z, "amsterdamgroen")
        m.set(36, 1, z, "amsterdamgroen")
        m.set(35, 2, z, "amsterdamgroen")
        m.set(36, 2, z, "amsterdamgroen")
    for x in range(36, 70):
        z = 50 - (x - 36) // 12
        m.set(x, 1, z, "metaal_donker")
    for xw in (46, 62):
        for z in range(44, 49):
            m.set(xw, 1, z, "metaal_donker")
        m.set(xw, 1, 43, "rubber")
    return m


@tile("props/ov/tram_bovenleiding_dubbel")
def tram_bovenleiding_dubbel():
    m = V(88, 4, 56)
    for x0 in (2, 84):
        for z in range(0, 54):
            for dx in (0, 1):
                m.set(x0 + dx, 1, z, "amsterdamgroen")
                m.set(x0 + dx, 2, z, "amsterdamgroen")
    for x in range(3, 85):
        m.set(x, 1, 50, "metaal_donker")
    for xw in (26, 62):
        for z in range(44, 50):
            m.set(xw, 1, z, "metaal_donker")
        m.set(xw, 1, 43, "rubber")
    return m


# ------------------------------------------------------------------ meer Nederlandse verkeersborden (RVV)

PX = {
    "vracht": ["###..", "####.", "#####", ".#..#"],
    "kind": [".#.#.", "#####", ".#.#.", "#.#.#"],
    "drempel": [".....", ".###.", "#####"],
    "rotonde": [".###.", "#...#", "#.#.#", "#...#", ".###."],
    "werk": ["..#..", ".###.", "#.#..", "..##.", ".#..#"],
    "spoor": ["#####", "#.#.#", "#####", "#...#"],
    "slip": ["##...", "..#..", "...##", "#.#.#"],
    "twee_autos": ["##.##", "##.##", "#..#."],
    "rechts": ["..#..", "...#.", "#####", "...#.", "..#.."],
    "links": ["..#..", ".#...", "#####", ".#...", "..#.."],
    "file": ["##.##", "#####", "##.##"],
    "tram": ["#####", "#.#.#", "#####", "#...#"],
}


def _plate_line(m, n, kind, color):
    z0 = m.sz - n - 3
    for i in range(1, n - 1):
        if kind in ("slash", "x"):
            m.set(1 + i, 0, z0 + n - 1 - i, color)
        if kind == "x":
            m.set(1 + i, 0, z0 + i, color)
    return m


SIGNS2 = {
    "max_60": dict(shape="rond", bg="bord_wit", rand="bord_rood", text="60", n=11),
    "max_70": dict(shape="rond", bg="bord_wit", rand="bord_rood", text="70", n=11),
    "max_120": dict(shape="rond", bg="bord_wit", rand="bord_rood", text="120", n=13),
    "max_130": dict(shape="rond", bg="bord_wit", rand="bord_rood", text="130", n=13),
    "vrachtauto_verboden": dict(shape="rond", bg="bord_wit", rand="bord_rood", picto=PX["vracht"], n=11),
    "fiets_verboden": dict(shape="rond", bg="bord_wit", rand="bord_rood", picto="fiets_klein", n=11),
    "inhaalverbod": dict(shape="rond", bg="bord_wit", rand="bord_rood", picto=PX["twee_autos"], n=11),
    "rotonde": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto=PX["rotonde"], pc="bord_wit", n=11),
    "verplicht_rechtsaf": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto=PX["rechts"], pc="bord_wit", n=11),
    "verplicht_linksaf": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto=PX["links"], pc="bord_wit", n=11),
    "fiets_en_voetpad": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto="voetganger", pc="bord_wit", n=11),
    "busbaan_rond": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto="bus", pc="bord_wit", n=11),
    "trambaan": dict(shape="rond", bg="bord_blauw", rand="bord_wit", picto=PX["tram"], pc="bord_wit", n=11),
    "let_op_kinderen": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=PX["kind"], n=13),
    "drempel": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=PX["drempel"], n=13),
    "werk_in_uitvoering": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=PX["werk"], n=13),
    "spoorwegovergang": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=PX["spoor"], n=13),
    "slipgevaar": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=PX["slip"], n=13),
    "rotonde_vooraankondiging": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=PX["rotonde"], n=13),
    "file": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=PX["file"], n=13),
    "fietsers_oversteken": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto="fiets_klein", n=13),
    "tram_kruist": dict(shape="driehoek", bg="bord_wit", rand="bord_rood", picto=PX["tram"], n=13),
    "autosnelweg": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", picto=["#...#", "##.##", "#.#.#", "#...#"], pc="bord_wit", n=11),
    "autoweg": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", picto="auto", pc="bord_wit", n=11),
    "tunnel": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", picto=[".###.", "#...#", "#...#", "#...#"], pc="bord_wit", n=11),
    "ziekenhuis": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", text="H", pc="bord_wit", n=11),
    "informatie": dict(shape="vierkant", bg="bord_blauw", rand="bord_wit", text="I", pc="bord_wit", n=11),
}
for _n, _kw in SIGNS2.items():
    register(f"props/borden/bord_{_n}", (lambda kw: lambda: bord(**kw))(_kw))


@tile("props/borden/bord_parkeerverbod")
def bord_parkeerverbod():
    m = bord("rond", "bord_blauw", "bord_rood", n=11)
    return _plate_line(m, 11, "slash", "bord_rood")


@tile("props/borden/bord_stopverbod")
def bord_stopverbod():
    m = bord("rond", "bord_blauw", "bord_rood", n=11)
    return _plate_line(m, 11, "x", "bord_rood")


@tile("props/borden/bord_einde_voorrangsweg")
def bord_einde_voorrangsweg():
    m = bord("ruit", "bord_wit", "bord_zwart", inner="bord_geel", n=11)
    return _plate_line(m, 11, "slash", "bord_zwart")


@tile("props/borden/bord_einde_maximum")
def bord_einde_maximum():
    m = bord("rond", "bord_wit", "bord_zwart", text="50", pc="antraciet2", n=11)
    return _plate_line(m, 11, "slash", "bord_zwart")


@tile("props/borden/bord_onderbord_uitgezonderd")
def bord_onderbord():
    m = V(13, 4, 26)
    pole(m, 6, 2, 0, 26, "metaal3")
    for z in range(14, 19):
        for x in range(1, 12):
            m.set(x, 1, z, "bord_wit" if 1 < x < 11 and 14 < z < 18 else "bord_zwart")
    from props import PICTO
    for r, line in enumerate(PICTO["fiets_klein"]):
        for c, v in enumerate(line):
            if v == "#":
                m.set(3 + c, 0, 17 - r, "bord_zwart")
    return m


# ------------------------------------------------------------------ tuinmuren (middelhoog) met poort

def tuinmuur(hgt=11, poort_=False, length=16):
    m = muurtje(BRICK(420), hgt, length)
    if poort_:
        for z in range(0, hgt + 1):
            for x in range(4, 12):
                for y in range(0, 4):
                    m.set(x, y, z, 0)
        for z in range(0, hgt - 1):
            for x in range(4, 12):
                m.set(x, 2, z, "hout2" if x % 2 else "hout_donker1")
        m.set(10, 1, 5, "messing")
    return m


register("props/muurtjes/tuinmuur_middel", lambda: tuinmuur(11))
register("props/muurtjes/tuinmuur_hoog", lambda: tuinmuur(15))
register("props/muurtjes/tuinmuur_poort", lambda: tuinmuur(11, True))
register("props/muurtjes/tuinmuur_hoog_poort", lambda: tuinmuur(15, True))
