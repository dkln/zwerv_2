"""Uitbreiding 3: bruggen (ophaalbrug, houten voetbrug, stalen boogbrug, tuibrug, moderne voetbrug)."""
import math

from common import T, ROAD, WALK, FLOOR, tile, register
from palette import P
from vox import V, mix, pick, h
from ground import column, flat, line_y, ASFALT, WATER, BETON, BETON_D, MARK, DASH

HOUT = lambda x, y, z: pick(["hout1", "hout2", "hout3"], x // 4, y, 0, 600) if y % 3 else P["hout_donker1"]
WIT = "kozijn_wit"


def leuning(m, x, base_fn, color=WIT, every=4, hgt=7):
    for y in range(T):
        b = base_fn(y)
        m.set(x, y, b + hgt, color)
        m.set(x, y, b + hgt // 2, color)
        if y % every == 0:
            for z in range(b, b + hgt):
                m.set(x, y, z, color)


# ------------------------------------------------------------------ ophaalbrug (klassiek)

def ophaal_dek():
    m = V(T, T, 12)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, "hout_donker2")
            m.set(x, y, 1, HOUT)
    for x in (0, 31):
        leuning(m, x, lambda y: 2)
    return m


@tile("grond/brug/ophaalbrug_dek")
def ophaalbrug_dek():
    return ophaal_dek()


@tile("grond/brug/ophaalbrug_portaal")
def ophaalbrug_portaal():
    """Dek met het portaal en de balans (wipbrug-stijl); plaats aan één kant van de overspanning."""
    m0 = ophaal_dek()
    m = V(T, T, 64)
    m.paste(m0, 0, 0, 0)
    for x in (1, 30):
        for y in (14, 15, 16, 17):
            for z in range(2, 50):
                m.set(x, y, z, WIT)
    for x in range(1, 31):
        for z in (48, 49):
            m.set(x, 15, z, WIT)
            m.set(x, 16, z, WIT)
    # balans (wip) die schuin over het dek ligt
    for y in range(0, T):
        z = 52 - int(y * 0.35)
        for x in (2, 29):
            m.set(x, y, z, WIT)
            m.set(x, y, z + 1, WIT)
    for x in range(2, 30):
        m.set(x, 0, 52, WIT)
    for y in range(0, T, 6):
        z = 52 - int(y * 0.35)
        for x in range(2, 30, 27):
            for zz in range(2, z):
                if y > 16 and zz > 6 and (zz + y) % 3 == 0:
                    m.set(x, y, zz, "metaal_donker")
    for x in range(1, 31):
        m.set(x, 15, 50, "lamp_warm" if x in (8, 23) else WIT)
    return m


# ------------------------------------------------------------------ houten voetbrug (klein)

@tile("grond/brug/voetbrug_hout_boog")
def voetbrug_hout_boog():
    """Kleine houten boogbrug over een sloot (water zit in de tile)."""
    m = V(T, T, 18)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, "waterbodem")
            m.set(x, y, 1, WATER)
    base = lambda y: WALK - 1 + int(6 * math.sin(math.pi * (y + 0.5) / T))
    for y in range(T):
        b = base(y)
        for x in range(8, 24):
            m.set(x, y, b, HOUT)
            m.set(x, y, b - 1, "hout_donker2")
        for x in (8, 23):
            m.set(x, y, b + 6, "hout_donker1")
            if y % 4 == 0:
                for z in range(b, b + 6):
                    m.set(x, y, z, "hout_donker1")
    for x in (9, 22):
        for y in (2, 29):
            for z in range(0, WALK + 1):
                m.set(x, y, z, "hout_donker2")
    return m


@tile("grond/brug/voetbrug_hout_vlak")
def voetbrug_hout_vlak():
    m = V(T, T, 12)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, "waterbodem")
            m.set(x, y, 1, WATER)
        for x in range(8, 24):
            m.set(x, y, WALK - 1, HOUT)
        for x in (8, 23):
            m.set(x, y, WALK + 6, "hout_donker1")
            if y % 8 == 0:
                for z in range(0, WALK + 6):
                    m.set(x, y, z, "hout_donker1")
    return m


# ------------------------------------------------------------------ moderne voetbrug (klein)

@tile("grond/brug/voetbrug_modern")
def voetbrug_modern():
    m = V(T, T, 12)
    for y in range(T):
        for x in range(6, 26):
            m.set(x, y, 0, "metaal3")
            m.set(x, y, 1, mix("beton1", "beton3", seed=601))
        for x in (6, 25):
            for z in range(2, 9):
                m.set(x, y, z, "glas_helder")
            m.set(x, y, 9, "rvs")
        for x in range(8, 24, 15):
            m.set(x, y, 2, "lamp_wit" if y % 8 == 0 else "metaal3")
    return m


# ------------------------------------------------------------------ stalen boogbrug (groot, 5 tiles)

SPAN = 5
BOOGH = 56


def staalboog(i, sides):
    m = V(T, T, BOOGH + 12)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, "metaal2")
            m.set(x, y, 1, ASFALT)
    line_y(m, 16, dash=DASH) if sides == (0, 31) else None
    L = SPAN * T
    for y in range(T):
        g = i * T + y + 0.5
        t = g / L
        za = int(4 * BOOGH * t * (1 - t)) + 2
        for x in sides:
            for dz in range(0, 4):
                m.set(x, y, za + dz, "stuc1")
                m.set(x + (1 if x == 0 else -1), y, za + dz, "stuc1")
            for z in range(2, 6):
                m.set(x, y, z, "stuc1")
            if int(g) % 8 == 0:
                for z in range(6, za):
                    m.set(x, y, z, "metaal3")
    if sides == (0, 31):
        for y in range(T):
            g = i * T + y + 0.5
            t = g / L
            za = int(4 * BOOGH * t * (1 - t)) + 2
            if za > 30 and y % 8 == 4:
                for x in range(0, 32):
                    m.set(x, y, za + 1, "stuc1")
    return m


for _i in range(SPAN):
    register(f"grond/brug/staalboog_{_i + 1}", (lambda i: lambda: staalboog(i, (0, 31)))(_i))
    register(f"grond/brug/staalboog_rand_{_i + 1}", (lambda i: lambda: staalboog(i, (0,)))(_i))


# ------------------------------------------------------------------ tuibrug (groot)

PYLOON = 120


def tui(i):
    """i=0: pyloon; i=1..3: tiles verder met de tuien die naar het dek lopen."""
    m = V(T, T, PYLOON + 4 if i == 0 else 100)
    for y in range(T):
        for x in range(T):
            m.set(x, y, 0, "beton_donker")
            m.set(x, y, 1, ASFALT)
        for x in (0, 1):
            for z in range(2, 6):
                m.set(x, y, z, "beton1")
    if i == 0:
        for z in range(0, PYLOON):
            w = 3 if z < 80 else 2
            for y in range(16 - w, 16 + w):
                for x in range(0, 4):
                    m.set(x, y, z, "stuc1")
        m.set(1, 16, PYLOON, "signaal_rood")
    # tuien: kabel k verbindt pyloonhoogte zk met het dek op afstand dk (in voxels)
    for k in range(6):
        zk = PYLOON - 8 - k * 9
        dk = (k + 1) * 18
        for y in range(T):
            g = i * T + y - 16 if i > 0 else y - 16
            if 0 <= g <= dk:
                z = int(zk - (zk - 4) * g / dk)
                m.set(1, y, z, "metaal3")
            if i == 0 and -dk <= g < 0:
                z = int(zk - (zk - 4) * (-g) / dk)
                m.set(1, y, z, "metaal3")
    return m


for _i in range(4):
    register(f"grond/brug/tuibrug_{_i}", (lambda i: lambda: tui(i))(_i))


# ------------------------------------------------------------------ kinderkopjes / keien

from ground import keien_tile, gras_tile, column  # noqa: E402


@tile("grond/weg/straat_keien_middengoot")
def straat_keien_goot():
    m = keien_tile()
    for y in range(T):
        for x in range(14, 18):
            m.clear(x, y, 0, x + 1, y + 1, 12)
            column(m, x, y, ROAD - (1 if x in (15, 16) else 0), mix("goot1", "goot2", seed=610))
            if ROAD - 1 <= 0:
                m.set(x, y, 0, "goot2")
    return m


@tile("grond/natuur/keienpad")
def keienpad():
    m = gras_tile(tufts=0.05)
    k = keien_tile(top=3)
    for y in range(T):
        for x in range(10, 22):
            m.clear(x, y, 0, x + 1, y + 1, 8)
            for z in range(k.sz):
                c = k.get(x, y, z)
                if c:
                    m.set(x, y, z, c)
    return m


@tile("grond/plein/plein_keien")
def plein_keien():
    return keien_tile(top=3)


@tile("grond/stoep/stoep_keien_rand")
def stoep_keien_rand():
    from ground import stoep
    m = stoep("v")
    k = keien_tile(top=3)
    for y in range(1, T):
        for x in range(T):
            for z in range(3):
                m.set(x, y, z, k.get(x, y, z))
    return m


# ------------------------------------------------------------------ afgeronde bochten voor hele straatprofielen

from ground import rijstrook, stoep, fietspad_recht, straat_klinkers, weg_vlak, klinker_fn, GRAS as _GRAS  # noqa: E402
from ground import tram_rails_straight  # noqa: E402


def _tram(l, r):
    m = rijstrook(l, r)
    tram_rails_straight(m)
    return m


# profiel = delen van links (binnenbocht) naar rechts (buitenbocht); rijrichting langs y
BOCHT_PROFIELEN = {
    "straat": (lambda: [stoep("r"), weg_vlak(), stoep("l")], "stoep"),
    "klinkerstraat": (lambda: [stoep("r", surface=klinker_fn), straat_klinkers(), stoep("l", surface=klinker_fn)], "stoep"),
    "weg": (lambda: [stoep("r", goot=True), rijstrook("geen", "kant").rot90(2), rijstrook("onderbroken", "kant"), stoep("l", goot=True)], "stoep"),
    "hoofdweg": (lambda: [stoep("r", goot=True), fietspad_recht(), rijstrook("geen", "kant").rot90(2),
                          rijstrook("onderbroken", "kant"), fietspad_recht(), stoep("l", goot=True)], "stoep"),
    "tramweg": (lambda: [stoep("r"), _tram("geen", "kant").rot90(2), _tram("onderbroken", "kant"), stoep("l")], "stoep"),
    "laan": (lambda: [stoep("r"), rijstrook("onderbroken", "kant").rot90(2), rijstrook("geen", "geen").rot90(2),
                      stoep("lr", surface=_GRAS), rijstrook("geen", "geen"), rijstrook("onderbroken", "kant"), stoep("l")], "stoep"),
    "fietspad": (lambda: [gras_tile(tufts=0.03), fietspad_recht(), gras_tile(tufts=0.03)], "gras"),
}
BOCHT_STRAAL = 1   # binnenstraal in tiles


def _profiel(delen):
    hoogte = max(d.sz for d in delen)
    p = V(T * len(delen), T, hoogte)
    for i, d in enumerate(delen):
        p.paste(d, i * T, 0, 0)
    return p


_bocht_cache = {}


def _bocht_bron(naam):
    if naam not in _bocht_cache:
        maak, vul = BOCHT_PROFIELEN[naam]
        delen = maak()
        binnen = stoep("") if vul == "stoep" else gras_tile(tufts=0.03)
        buiten = gras_tile(tufts=0.05)
        _bocht_cache[naam] = (_profiel(delen), len(delen), binnen, buiten)
    return _bocht_cache[naam]


def bocht_tile(naam, i, j):
    p, w, binnen, buiten = _bocht_bron(naam)
    rin = BOCHT_STRAAL * T
    rout = rin + w * T
    rmid = (rin + rout) / 2.0
    m = V(T, T, p.sz)
    for y in range(T):
        for x in range(T):
            X = i * T + x + 0.5
            Y = j * T + y + 0.5
            r = math.hypot(X, Y)
            if r < rin:
                bron, bx, by = binnen, x, y
            elif r >= rout:
                bron, bx, by = buiten, x, y
            else:
                u = min(int(r - rin), w * T - 1)
                s = math.atan2(Y, X) * rmid
                bron, bx, by = p, u, int(s) % T
            for z in range(min(bron.sz, m.sz)):
                c = bron.get(bx, by, z)
                if c:
                    m.set(x, y, z, c)
    return m


for _naam in BOCHT_PROFIELEN:
    _w = len(BOCHT_PROFIELEN[_naam][0]())
    _n = BOCHT_STRAAL + _w
    for _i in range(_n):
        for _j in range(_n):
            register(f"grond/bocht/{_naam}_{_i}_{_j}", (lambda n, a, b: lambda: bocht_tile(n, a, b))(_naam, _i, _j))
