"""Uitbreiding 5: meer winkels, tunnelbakken, tram met belijning, vrije trambaan, middenbermen,
busbaan zonder tekst, luxe appartementen met dakterras en penthouse."""
import math

from common import T, ROAD, WALK, FLOOR, register, tile, text_pixels
from palette import P
from vox import V, mix, pick, h, blocky
from ground import (column, flat, new, rijstrook, stoep, paint, line_y, fietspad_recht, klinker_fn, ASFALT, FIETS,
                    GRAS, BETON, BETON_D, MARK, TEGEL, BAND, DASH, tram_rails_straight, BUS)
from buildings import Bld, STYLES, S, O, W, HGT, make_block, flat_roof, planks, x_dakterras_plat
from buildings2 import reg_style, flat_roofs, colored_panel

# ------------------------------------------------------------------ meer winkels

WINKEL_SOORTEN = {
    "bakker": ("BAKKER", ["hout2", "hout3", "zand1", "terracotta1"], "licht_warm", ["luifel_geel", "luifel_wit"], "deur_rood"),
    "slager": ("SLAGER", ["bord_rood", "bloem_roze", "stuc1", "bord_rood2"], "licht_wit", ["luifel_rood", "luifel_wit"], "bord_rood2"),
    "bloemist": ("BLOEMEN", ["bloem_rood", "bloem_geel", "bloem_paars", "bloem_roze", "blad2", "bloem_wit"], "licht_warm", ["luifel_groen", "luifel_wit"], "deur_groen"),
    "boekhandel": ("BOEKEN", ["stof1", "stof2", "paneel_geel", "paneel_groen", "deur_blauw", "stof3"], "licht_warm", None, "deur_blauw"),
    "fietsenwinkel": ("FIETSEN", ["fiets_zwart", "fiets_rood", "fiets_blauw", "rubber"], "licht_wit", None, "bord_zwart"),
    "supermarkt": ("SUPER", ["bloem_oranje", "paneel_blauw", "bloem_geel", "bord_rood", "paneel_groen", "stuc1"], "licht_wit", None, "bord_blauw"),
    "drogist": ("DROGIST", ["bloem_roze", "stuc1", "paneel_blauw", "luifel_wit"], "licht_wit", None, "bord_groen"),
    "kapper": ("KAPPER", ["glas_helder", "bord_zwart", "rvs", "stuc1"], "licht_wit", None, "bord_zwart"),
    "ijssalon": ("IJS", ["bloem_roze", "bloesem2", "zand1", "luifel_geel", "bloem_wit"], "licht_warm", ["bloem_roze", "luifel_wit"], "bloem_roze"),
    "snackbar": ("SNACKS", ["bord_geel", "bloem_oranje", "rvs", "bord_rood"], "licht_wit", None, "bord_geel"),
    "juwelier": ("JUWELEN", ["goud", "messing", "bord_zwart", "rvs"], "licht_warm", None, "bord_zwart"),
    "dierenwinkel": ("DIEREN", ["hout2", "blad2", "paneel_groen", "zand1"], "licht_warm", ["luifel_groen", "luifel_geel"], "deur_groen"),
}


def winkel(kind):
    text, goods, licht, luifel, bord = WINKEL_SOORTEN[kind]

    def f(b, face):
        b.shopfront(face, text, luifel)
        for u in range(3, 21):
            if u == 11:
                continue
            for z in range(3, 16):
                if z == 15:
                    c = licht
                elif z % 4 == 2:
                    c = "hout_donker1"
                elif z < 14 and h(u, z, b.seed, 800) < 0.75:
                    c = pick(goods, u, z, b.seed, 801)
                else:
                    c = "interieur2"
                b.put(face, u, z, 3, c)
        b.sign(face, 1, 31, 17, 23, bord, text, "goud" if kind in ("juwelier", "bakker") else "bord_wit")
    f.__name__ = "f_winkel_" + kind
    return f


for _st in ("klassiek_rood", "klassiek_donker", "klassiek_geel", "modern_wit", "modern_donker", "modern_hout", "jaren30", "herenhuis_1900"):
    for _k in WINKEL_SOORTEN:
        register(f"gebouwen/{_st}/{_st}_bg_{_k}", make_block(_st, [("v", winkel(_k))]))


# ------------------------------------------------------------------ tunnelbak (open bak, verdiept)

def bak(d, kind, wall):
    if kind == "rijstrook":
        base = rijstrook("geen", "onderbroken")
    elif kind == "fietspad":
        base = fietspad_recht()
    else:
        base = stoep("")
    out = V(T, T, d * FLOOR + 10)
    out.paste(base, 0, 0, 0)
    if wall:
        top = d * FLOOR + WALK
        for y in range(T):
            for z in range(0, top):
                out.set(0, y, z, BETON_D if z % 12 == 0 else BETON)
                out.set(1, y, z, BETON)
            out.set(0, y, top + 5, "metaal_donker")
            if y % 8 == 0:
                for z in range(top, top + 5):
                    out.set(0, y, z, "metaal_donker")
    return out


for _d in range(1, 7):
    for _k in ("rijstrook", "fietspad", "stoep"):
        register(f"grond/tunnel/tunnelbak_{_k}_d{_d}", (lambda d, k: lambda: bak(d, k, False))(_d, _k))
        register(f"grond/tunnel/tunnelbak_{_k}_wand_d{_d}", (lambda d, k: lambda: bak(d, k, True))(_d, _k))
        register(f"grond/tunnel/tunnelbak_{_k}_wand_rechts_d{_d}", (lambda d, k: lambda: bak(d, k, True).mirror_x())(_d, _k))


def tunnel_fiets_naast(wall):
    """Tunnel-tile (6 lagen) met een fietspad; om naast autotunnel-tiles te leggen."""
    from ground2 import tunnel
    return tunnel(wall, fiets=True)


register("grond/tunnel/tunnel_fietspad", lambda: tunnel_fiets_naast(False))


# ------------------------------------------------------------------ tram met gewone belijning

for _l, _r in (("onderbroken", "kant"), ("geen", "kant"), ("streep", "kant"), ("onderbroken", "geen"), ("geen", "geen"), ("dubbel", "kant")):
    def _f(l=_l, r=_r):
        m = rijstrook(l, r)
        tram_rails_straight(m)
        return m
    register(f"grond/tram/tram_rijstrook_{_l}_{_r}", _f)


@tile("grond/tram/trambaan_vrij")
def trambaan_vrij():
    """Vrije trambaan: verhoogde strook met banden aan beide kanten."""
    m = new()
    for y in range(T):
        for x in range(T):
            if x in (0, 31):
                column(m, x, y, WALK, BAND, BAND)
            else:
                column(m, x, y, WALK, klinker_fn)
    for y in range(T):
        for r in (10, 21):
            m.set(r, y, WALK - 1, "rail_glim")
            m.set(r + (1 if r == 10 else -1), y, WALK - 1, "railgroef")
    return m


@tile("grond/tram/trambaan_vrij_gras")
def trambaan_vrij_gras():
    m = trambaan_vrij()
    for y in range(T):
        for x in range(1, 31):
            if x not in (10, 11, 20, 21):
                m.set(x, y, WALK - 1, pick(["gras1", "gras2", "gras4"], x, y, 0, 802))
    return m


@tile("grond/tram/tramhalte_middenperron")
def tramhalte_middenperron():
    """Perron tussen twee trambanen in: banden aan beide kanten, geleidelijnen."""
    m = V(T, T, 10)
    for y in range(T):
        for x in range(T):
            column(m, x, y, 5, TEGEL, BETON_D)
    for y in range(T):
        for x in (0, 31):
            column(m, x, y, 5, BAND, BAND)
        for x in (2, 29):
            paint(m, x, y, P["markering"])
        for x in (4, 27):
            paint(m, x, y, P["ribbel"])
    return m


# ------------------------------------------------------------------ middenbermen

register("grond/weg/middenberm_gras", lambda: stoep("lr", surface=GRAS))
register("grond/weg/middenberm_gras_kop", lambda: stoep("lra", surface=GRAS))
register("grond/weg/middenberm_klinkers", lambda: stoep("lr", surface=klinker_fn))


@tile("grond/weg/rijstrook_bus_leeg")
def rijstrook_bus_leeg():
    return rijstrook("streep", "kant", BUS)


# ------------------------------------------------------------------ luxe appartementen met dakterras en penthouse

STYLES["luxe_appartement"] = dict(fam="luxe", wall=blocky(["natuursteen1", "stuc1", "natuursteen2"], size=4, seed=803),
                                  kozijn="antraciet3", deuren=["antraciet3"], plint="antraciet3", sier="goud",
                                  dak=("dakgrind1", "dakgrind2"), glas="glas2", winkel="antraciet3", cap="antraciet3",
                                  accent=planks(["hout1", "hout2", "hout3"], 804))


def lx_lobby(b, face):
    b.rect(face, 0, S, 0, 24, 0, 3, 0)
    for z in range(0, 24):
        for u in range(S):
            edge = u in (0, 31) or u % 8 == 0 or z in (0, 23)
            b.put(face, u, z, 1, "antraciet3" if edge else "glas_helder")
    b.rect(face, 1, 31, 0, 23, 3, 4, "hout1")
    for u in range(4, 28, 6):
        b.put(face, u, 18, 3, "licht_warm")
    b.rect(face, 4, 28, 18, 20, -7, 0, "antraciet3")
    b.sign(face, 10, 22, 20, 24, "antraciet3", "LUXE", "goud")


def lx_terras(b, face):
    b.rect(face, 0, S, 0, 2, -8, 0, "stuc1")
    for u in range(S):
        for z in range(2, 9):
            b.put(face, u, z, -8, "glas_helder")
        b.put(face, u, 9, -8, "rvs")
    for u0 in (2, 26):
        b.rect(face, u0, u0 + 4, 2, 5, -7, -3, "antraciet2")
        b.rect(face, u0, u0 + 4, 5, 8, -7, -3, "blad2")
    b.window(face, 1, 2, 30, 20, sill=False, lintel=False)
    for z in range(2, 22):
        for u in (11, 21):
            b.put(face, u, z, 1, "antraciet3")


def lx_glas(b, face):
    b.window(face, 1, 1, 30, 22, sill=False, lintel=False)
    b.rect(face, 0, S, 0, 1, -2, 1, "stuc1")
    for z in range(1, 23):
        for u in (8, 16, 24):
            b.put(face, u, z, 1, "antraciet3")


def penthouse(edges):
    """Penthouse: teruggelegen glazen opbouw met terras en overstekend dak."""
    def fn():
        b = Bld("luxe_appartement", "penthouse" + edges, HGT)
        m = b.m
        inset = {f: (8 if f in edges else 0) for f in "vral"}
        x0, x1 = O + inset["l"], O + S - inset["r"]
        y0, y1 = O + inset["v"], O + S - inset["a"]
        for ly in range(S):
            for lx in range(S):
                m.set(O + lx, O + ly, 0, pick(["hout1", "hout2", "hout3"], lx // 4, ly, 0, 805))
        m.box(x0, y0, 1, x1, y1, 21, "glas2")
        m.box(x0 + 1, y0 + 1, 1, x1 - 1, y1 - 1, 21, "interieur2")
        for z in range(1, 21):
            for x in range(x0, x1, 8):
                m.set(x, y0, z, "antraciet3")
                m.set(x, y1 - 1, z, "antraciet3")
        m.box(O - 2 if "l" in edges else x0, O - 2 if "v" in edges else y0, 21,
              O + S + 2 if "r" in edges else x1, O + S + 2 if "a" in edges else y1, 23, "antraciet3")
        for f in edges:
            for u in range(S):
                for z in range(1, 8):
                    b.put(f, u, z, 0, "glas_helder")
                b.put(f, u, 8, 0, "rvs")
        b.m.box(O + 2, O + 2, 1, O + 6, O + 6, 4, "antraciet2")
        b.m.ellipsoid(O + 4, O + 4, 6, 2.5, 2.5, 2.5, mix("blad1", "blad2", "blad4", seed=806))
        return m
    return fn


def x_dakzwembad(b):
    m = b.m
    for ly in range(2, 30):
        for lx in range(2, 30):
            m.set(O + lx, O + ly, 1, pick(["hout1", "hout2", "hout3"], lx // 4, ly, 0, 807))
    for ly in range(6, 26):
        for lx in range(6, 22):
            edge = lx in (6, 21) or ly in (6, 25)
            # rand van 25 cm rond het verzonken water
            m.set(O + lx, O + ly, 1, "tegel_wit" if edge else "water_zwembad")
            m.set(O + lx, O + ly, 2, "tegel_wit" if edge else 0)
            m.set(O + lx, O + ly, 3, "tegel_wit" if edge else 0)
    for ly in (8, 14, 20):
        for lx in range(24, 28):
            m.set(O + lx, O + ly, 2, "bord_wit")
            m.set(O + lx, O + ly + 1, 2, "bord_wit")


reg_style("luxe_appartement",
          {"bg_lobby": lx_lobby, "bg_glas": lx_glas, "verd_terras": lx_terras, "verd_glas": lx_glas},
          [("bg_glas_hoek", "bg_glas", "bg_glas"), ("verd_terras_hoek", "verd_terras", "verd_terras"),
           ("verd_glas_hoek", "verd_glas", "verd_glas"), ("bg_lobby_hoek", "bg_lobby", "bg_glas")],
          dict(flat_roofs("luxe_appartement"),
               dak_terras=flat_roof("luxe_appartement", "v", x_dakterras_plat),
               dak_zwembad=flat_roof("luxe_appartement", "v", x_dakzwembad),
               penthouse_rand=penthouse("v"), penthouse_hoek=penthouse("vr"), penthouse_tegenover=penthouse("va"),
               penthouse_midden=penthouse("")))


# ------------------------------------------------------------------ extra tunnel-varianten (fietsbak naast autobak)

from ground2 import tunnel, toerit  # noqa: E402

register("grond/tunnel/tunnel_fiets_wand_rechts", lambda: tunnel(True, fiets=True).mirror_x())
register("grond/tunnel/tunnel_fiets_wand_rechts_portaal", lambda: tunnel(True, fiets=True, portaal=True).mirror_x())
for _d in range(1, 7):
    register(f"grond/tunnel/fietstunnel_toerit_wand_rechts_d{_d}", (lambda d: lambda: toerit(d, True, True).mirror_x())(_d))


# ------------------------------------------------------------------ klassieke lantaarnpalen

from props import pole  # noqa: E402


def _lantaarnkop(m, cx, cy, z, groen="amsterdamgroen"):
    for zz in range(z, z + 5):
        for y in range(int(cy) - 2, int(cy) + 3):
            for x in range(int(cx) - 2, int(cx) + 3):
                edge = abs(x - cx) >= 1.5 or abs(y - cy) >= 1.5
                corner = abs(x - cx) >= 1.5 and abs(y - cy) >= 1.5
                if edge:
                    m.set(x, y, zz, groen if corner else "lamp_warm")
    for zz in (z + 5, z + 6):
        m.cyl(cx + 0.5, cy + 0.5, 3 - (zz - z - 5) * 1.5, zz, zz + 1, groen)


@tile("props/verlichting/lantaarn_klassiek_dubbel")
def lantaarn_klassiek_dubbel():
    m = V(24, 8, 44)
    g = "amsterdamgroen"
    m.box(9, 2, 0, 15, 6, 3, g)
    for z in range(3, 34):
        m.cyl(12, 4, 1.2, z, z + 1, g)
    for x in range(3, 21):
        m.set(x, 4, 34, g)
        m.set(x, 3, 34, g)
    for cx in (4, 19):
        for z in range(31, 34):
            m.set(cx, 4, z, g)
        _lantaarnkop(m, cx, 4, 26)
    return m


@tile("props/verlichting/lantaarn_gietijzer")
def lantaarn_gietijzer():
    m = V(24, 6, 40)
    c = "bord_zwart"
    m.box(10, 1, 0, 14, 5, 3, c)
    for z in range(3, 34):
        m.cyl(12, 3, 1.0 if z > 6 else 1.5, z, z + 1, c)
    for t in range(0, 20):
        a = t / 19 * math.pi
        x = 12 + 6 * (1 - math.cos(a))
        z = 33 + 3 * math.sin(a)
        m.set(x, 3, z, c)
    for z in range(30, 34):
        m.set(23, 3, z, c) if False else m.set(22, 3, z, c)
    _lantaarnkop(m, 22, 3, 24, c)
    return m


@tile("props/verlichting/lantaarn_bol")
def lantaarn_bol():
    m = V(8, 8, 36)
    for z in range(0, 28):
        m.cyl(4, 4, 1.0 if z > 3 else 2.0, z, z + 1, "antraciet1")
    m.ellipsoid(4, 4, 31, 3.4, 3.4, 3.6, "lamp_warm")
    m.cyl(4, 4, 1.5, 34, 35, "antraciet1")
    return m


@tile("props/verlichting/lantaarn_wand_klassiek")
def lantaarn_wand_klassiek():
    from details import att, wd
    m = att(6, 6, 12)
    for d in range(0, 5):
        m.set(3, wd(m, d), 9, "bord_zwart")
    for z in range(2, 8):
        for d in range(3, 6):
            for x in range(2, 5):
                edge = x in (2, 4) and d in (3, 5)
                m.set(x, wd(m, d), z, "bord_zwart" if edge or z in (2, 7) else "lamp_warm")
    return m


# ------------------------------------------------------------------ terras: tafeltjes en parasols

def tafel(vorm, stoelen):
    m = V(16, 16, 8)
    c = 8
    for z in range(0, 5):
        m.set(c, c, z, "metaal_donker")
    m.box(c - 2, c - 2, 0, c + 2, c + 2, 1, "metaal_donker") if False else None
    if vorm == "rond":
        m.cyl(c, c, 3.2, 5, 6, "hout_bank1")
    else:
        m.box(c - 3, c - 3, 5, c + 3, c + 3, 6, "stuc1")
    if stoelen:
        for (dx, dy) in ((0, -6), (0, 5), (-6, 0), (5, 0)):
            x, y = c + dx - 1, c + dy - 1
            for z in range(0, 3):
                for (a, b_) in ((0, 0), (2, 0), (0, 2), (2, 2)):
                    m.set(x + a, y + b_, z, "metaal_donker")
            m.box(x, y, 3, x + 3, y + 3, 4, "hout_bank2")
            bx = (x, x + 3) if dx == 0 else ((x, x + 1) if dx < 0 else (x + 2, x + 3))
            by = ((y, y + 1) if dy < 0 else (y + 2, y + 3)) if dx == 0 else (y, y + 3)
            m.box(bx[0], by[0], 4, bx[1], by[1], 7, "metaal_donker")
    return m


for _v in ("rond", "vierkant"):
    register(f"props/terras/tafel_{_v}", (lambda v: lambda: tafel(v, False))(_v))
    register(f"props/terras/tafel_{_v}_stoelen", (lambda v: lambda: tafel(v, True))(_v))


@tile("props/terras/bistrostoel")
def bistrostoel():
    m = V(4, 4, 7)
    for z in range(0, 3):
        for (a, b_) in ((0, 0), (3, 0), (0, 3), (3, 3)):
            m.set(a, b_, z, "metaal_donker")
    m.box(0, 0, 3, 4, 4, 4, "hout_bank2")
    m.box(0, 3, 4, 4, 4, 7, "metaal_donker")
    return m


def parasol(kleuren, vierkant=False, r=11):
    size = int(r * 2 + 2)
    size += size % 2
    m = V(size, size, 22)
    c = size / 2
    for z in range(0, 18):
        m.set(c, c, z, "hout2")
    m.box(int(c) - 2, int(c) - 2, 0, int(c) + 2, int(c) + 2, 1, "beton2")
    for z in range(14, 19):
        rr = r - (z - 14) * (r / 4.5)
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                d = max(abs(dx), abs(dy)) if vierkant else math.hypot(dx, dy)
                if rr - 1.6 < d <= rr:
                    a = math.atan2(dy, dx)
                    m.set(x, y, z, kleuren[int((a + 4) * 4 / math.pi) % len(kleuren)])
    if not vierkant:
        for x in range(size):
            for y in range(size):
                d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                if r - 1 < d <= r and (x + y) % 2 == 0:
                    m.set(x, y, 13, kleuren[0])
    return m


register("props/terras/parasol_rood", lambda: parasol(["luifel_rood", "luifel_wit"]))
register("props/terras/parasol_groen", lambda: parasol(["luifel_groen"]))
register("props/terras/parasol_blauw", lambda: parasol(["luifel_blauw", "luifel_wit"]))
register("props/terras/parasol_naturel", lambda: parasol(["luifel_wit"]))
register("props/terras/parasol_vierkant", lambda: parasol(["antraciet2"], True))
register("props/terras/parasol_groot", lambda: parasol(["luifel_wit", "stuc2"], True, 15))


# ------------------------------------------------------------------ standbeelden

def sokkel(m, cx, cy, w, hgt, mat="natuursteen2"):
    for z in range(hgt):
        ww = w + (1 if z in (0, hgt - 1) else 0)
        m.box(int(cx - ww), int(cy - ww), z, int(cx + ww), int(cy + ww), z + 1, mat if z not in (0, hgt - 1) else "natuursteen1")


def figuur(m, cx, cy, z0, schaal=1.0, mat="brons_patina"):
    s = schaal
    def e(x, y, z, rx, ry, rz):
        m.ellipsoid(cx + x * s, cy + y * s, z0 + z * s, rx * s, ry * s, rz * s, mat)
    e(-1.2, 0, 4, 1.1, 1.1, 4.2)    # benen
    e(1.2, 0, 4, 1.1, 1.1, 4.2)
    e(0, 0, 10.5, 2.6, 1.8, 3.6)    # romp
    e(-3.0, 0, 11, 0.9, 0.9, 3.0)   # armen
    e(3.2, -1.2, 13, 0.9, 0.9, 3.0)
    e(0, 0, 15.5, 1.5, 1.5, 1.7)    # hoofd


@tile("props/standbeelden/standbeeld_persoon")
def standbeeld_persoon():
    m = V(14, 14, 34)
    sokkel(m, 7, 7, 4, 12)
    figuur(m, 7, 7, 12, 1.2)
    return m


@tile("props/standbeelden/ruiterstandbeeld")
def ruiterstandbeeld():
    m = V(28, 16, 44)
    sokkel(m, 14, 8, 6, 12)
    b = "brons_patina"
    m.ellipsoid(14, 8, 21, 8, 3, 3.5, b)                      # paardenlijf
    for (x, y) in ((8.5, 6.5), (8.5, 9.5), (19.5, 6.5), (19.5, 9.5)):
        m.line((x, y, 12), (x + (1 if x < 14 else -1), y, 19), b, 0.9)
    m.line((21, 8, 22), (24, 8, 28), b, 1.4)                   # hals
    m.ellipsoid(24.5, 8, 29, 2.2, 1.4, 1.6, b)                # hoofd
    m.line((6, 8, 22), (4, 8, 16), b, 0.8)                     # staart
    figuur(m, 14, 8, 21, 0.8)
    return m


@tile("props/standbeelden/buste")
def buste():
    m = V(8, 8, 18)
    sokkel(m, 4, 4, 2, 10, "marmer")
    m.ellipsoid(4, 4, 12, 3, 2, 2, "brons")
    m.ellipsoid(4, 4, 15.5, 1.6, 1.6, 2, "brons")
    return m


@tile("props/standbeelden/obelisk")
def obelisk():
    m = V(12, 12, 60)
    sokkel(m, 6, 6, 4, 6)
    for z in range(6, 56):
        hw = 2.6 - (z - 6) * 0.025
        m.box(int(6 - hw), int(6 - hw), z, int(6 + hw + 0.5), int(6 + hw + 0.5), z + 1, "natuursteen1")
    for z in range(56, 60):
        hw = (60 - z) * 0.5
        m.box(int(6 - hw), int(6 - hw), z, int(6 + hw + 0.5), int(6 + hw + 0.5), z + 1, "goud")
    return m


@tile("props/standbeelden/kunstwerk_modern")
def kunstwerk_modern():
    m = V(20, 20, 40)
    m.box(4, 4, 0, 16, 16, 2, "beton1")
    for t in range(0, 120):
        a = t / 120 * math.tau * 1.5
        x = 10 + math.cos(a) * 5
        y = 10 + math.sin(a) * 5
        z = 2 + t * 0.3
        m.line((x, y, z), (x, y, z + 1), "rvs", 1.2)
    return m


@tile("props/standbeelden/fontein_beeld")
def fontein_beeld():
    m = V(32, 32, 30)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - 16, y + 0.5 - 16)
            if d < 16:
                m.set(x, y, 0, "natuursteen2")
                if d > 14.5:
                    for z in range(1, 4):
                        m.set(x, y, z, "natuursteen1")
                else:
                    m.set(x, y, 1, "water1")
                    m.set(x, y, 2, "water3")
    sokkel(m, 16, 16, 3, 9)
    figuur(m, 16, 16, 9, 1.0, "brons")
    return m


# ------------------------------------------------------------------ groendaken (sedum)

SEDUM = ("sedum1", "sedum3", "sedum2", "sedum1", "sedum4")


def x_sedum(b):
    m = b.m
    for ly in range(2, 30):
        for lx in range(2, 30):
            if h(lx, ly, 0, 810) < 0.12:
                m.set(O + lx, O + ly, 1, pick(["sedum1", "gras4", "bloem_geel", "bloem_paars"], lx, ly, 1, 811))


def groendak(st, edges, extra=True):
    def fn():
        orig = STYLES[st].get("dakvloer")
        STYLES[st]["dakvloer"] = SEDUM
        try:
            return flat_roof(st, edges, x_sedum if extra else None)()
        finally:
            if orig is None:
                STYLES[st].pop("dakvloer", None)
            else:
                STYLES[st]["dakvloer"] = orig
    return fn


for _st in ("modern_wit", "modern_donker", "modern_hout", "kantoor_glas", "kantoor_beton", "jaren60", "galerijflat",
            "appartement_modern", "kantoor_80", "kantoor_2000", "kantoor_modern", "school", "jaren30", "luxe_appartement",
            "bedrijfspand", "museum_modern"):
    for _e, _n in (("", "midden"), ("v", "rand"), ("vr", "hoek")):
        register(f"gebouwen/{_st}/{_st}_dak_groen_{_n}", groendak(_st, _e))

from buildings3 import VORMEN  # noqa: E402
from buildings import pitched, brick  # noqa: E402

STYLES["dak_sedum"] = dict(fam="dak", wall=brick(["baksteen1", "baksteen2", "baksteen3"], 812), kozijn="kozijn_wit",
                           deuren=["deur_groen"], plint="natuursteen2", sier="natuursteen1", dak=SEDUM, glas="glas1",
                           winkel="kozijn_wit", cap="zink1")
for _vorm in ("schuin", "schuin_hoek_buiten", "schuin_hoek_binnen", "zadel", "zadel_schild", "zadel_hoek", "lessenaar", "schuin_afgeplat"):
    register(f"gebouwen/daken/sedum/sedum_{_vorm}", pitched("dak_sedum", "sedum" + _vorm, VORMEN[_vorm]))
