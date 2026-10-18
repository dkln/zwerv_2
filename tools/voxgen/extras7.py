"""Uitbreiding 7: verkeerslichten in alle standen; loodsen, magazijnen, fabrieken en industriële props."""
import math

from common import register, tile
from palette import P
from vox import V, mix, pick, h, blocky
from buildings import Bld, STYLES, S, O, W, HGT, brick, make_block, flat_roof, pitched
from buildings2 import reg_style, flat_roofs
from props import pole, light_head

# ------------------------------------------------------------------ verkeerslichten in elke stand

def auto_licht(stand, hoogte=32, kop_z=19):
    m = V(8, 4, hoogte)
    pole(m, 3, 2, 0, hoogte - 2, "metaal3")
    light_head(m, 2, 1, kop_z, stand)
    return m


def fiets_licht(stand):
    m = V(8, 4, 24)
    pole(m, 3, 2, 0, 22, "metaal3")
    light_head(m, 2, 1, 11, stand)
    # fietspictogram op het achterbord
    for (c, r) in [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)]:
        m.set(2 + c, 3, 22 - r, "bord_wit")
    return m


def mast_licht(stand):
    m = V(80, 4, 44)
    pole(m, 39, 1, 0, 42, "metaal3", 2)
    for x in range(39, 78):
        m.set(x, 1, 41, "metaal3")
        m.set(x, 2, 41, "metaal3")
    light_head(m, 58, 1, 30, stand)
    light_head(m, 72, 1, 30, stand)
    return m


def voetganger_licht(stand):
    m = V(8, 4, 26)
    pole(m, 3, 2, 0, 24, "metaal3")
    for z in range(14, 24):
        for x in range(2, 6):
            m.set(x, 1, z, "bord_zwart")
            m.set(x, 2, z, "bord_zwart")
    staand = [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (1, 3)]
    lopend = [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (0, 3), (2, 3)]
    for (c, r) in staand:
        m.set(2 + c, 0, 22 - r, "stoplicht_rood" if stand == "rood" else "stoplicht_rood_uit")
    for (c, r) in lopend:
        m.set(2 + c, 0, 18 - r, "stoplicht_groen" if stand == "groen" else "stoplicht_groen_uit")
    for z in range(8, 12):
        for x in range(2, 6):
            m.set(x, 1, z, "bord_geel")
    return m


def ov_licht(stand):
    """OV-sein (bus/tram): stop = liggende balk, rijden = staande balk, attentie = punt."""
    m = V(8, 4, 32)
    pole(m, 3, 2, 0, 30, "metaal3")
    for z in range(19, 30):
        for x in range(1, 7):
            m.set(x, 1, z, "bord_zwart")
            m.set(x, 2, z, "bord_zwart")
    if stand == "stop":
        for x in range(2, 6):
            m.set(x, 0, 25, "lamp_wit")
    elif stand == "rijden":
        for z in range(22, 28):
            m.set(3, 0, z, "lamp_wit")
            m.set(4, 0, z, "lamp_wit")
    else:
        for (x, z) in ((3, 24), (4, 24), (3, 25), (4, 25)):
            m.set(x, 0, z, "lamp_wit")
    m.set(3, 0, 20, "lamp_wit")
    m.set(4, 0, 20, "lamp_wit")
    return m


for _s in ("rood", "oranje", "groen"):
    register(f"props/verkeerslichten/auto_{_s}", (lambda s: lambda: auto_licht(s))(_s))
    register(f"props/verkeerslichten/fiets_{_s}", (lambda s: lambda: fiets_licht(s))(_s))
    register(f"props/verkeerslichten/mast_{_s}", (lambda s: lambda: mast_licht(s))(_s))
for _s in ("rood", "groen"):
    register(f"props/verkeerslichten/voetganger_{_s}", (lambda s: lambda: voetganger_licht(s))(_s))
for _s in ("stop", "rijden", "attentie"):
    register(f"props/verkeerslichten/ov_{_s}", (lambda s: lambda: ov_licht(s))(_s))


# ------------------------------------------------------------------ loodsen, magazijnen, fabrieken

def golf_staal(names):
    def f(x, y, z):
        u = x + y
        return P[names[0]] if u % 3 else P[names[1]]
    return f


def betonpaneel(x, y, z):
    u = x + y
    if u % 24 == 0 or z % 24 == 0:
        return P["beton_donker"]
    return pick(["beton1", "beton2", "beton3"], u // 24, z // 24, 0, 1000)


def fabrieksteen(x, y, z):
    u = x + y
    if z % 12 == 0:
        return P["donkersteen2"]
    return pick(["baksteen2", "baksteen4", "donkersteen1"], (u + (z % 2) * 2) // 3, z, 0, 1001, [3, 2, 1])


def staal_op_plint(x, y, z):
    if z < 8:
        return fabrieksteen(x, y, z)
    u = x + y
    return P["paneel_blauw"] if u % 3 else P["bord_blauw2"]


STYLES.update({
    "loods_staal": dict(fam="industrie", wall=golf_staal(["golfplaat1", "golfplaat2"]), kozijn="antraciet1", deuren=["metaal1"],
                        plint="beton2", sier="antraciet1", dak=("golfplaat1", "golfplaat2"), dakvloer=("golfplaat1", "golfplaat2"),
                        glas="glas2", winkel="antraciet1", cap="antraciet1", accent="bord_geel"),
    "loods_steen": dict(fam="industrie", wall=staal_op_plint, kozijn="antraciet1", deuren=["metaal1"],
                        plint="baksteen4", sier="antraciet1", dak=("golfplaat1", "golfplaat2"), dakvloer=("bitumen1", "bitumen2"),
                        glas="glas2", winkel="antraciet1", cap="antraciet1", accent="bord_geel"),
    "magazijn": dict(fam="industrie", wall=betonpaneel, kozijn="antraciet1", deuren=["metaal2"],
                     plint="beton_donker", sier="antraciet2", dak=("bitumen1", "bitumen2"), dakvloer=("bitumen1", "bitumen2"),
                     glas="glas2", winkel="antraciet1", cap="metaal3", accent="bord_oranje"),
    "fabriek": dict(fam="industrie", wall=fabrieksteen, kozijn="kozijn_zwart", deuren=["kozijn_groen"],
                    plint="donkersteen2", sier="natuursteen2", dak=("leisteen1", "leisteen2"), dakvloer=("bitumen1", "bitumen2"),
                    glas="glas1", winkel="kozijn_zwart", cap="natuursteen2", accent="bord_geel"),
})


def ind_dock(b, face):
    """Laaddock: hoge deur met dockshelter en stootbuffers, verhoogde vloer."""
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plint"])
    b.rect(face, 6, 26, 0, 20, 0, 2, 0)
    for z in range(0, 20):
        for u in range(6, 26):
            edge = u in (6, 25) or z == 19
            b.put(face, u, z, 1, "rubber" if edge else ("metaal1" if (z // 2) % 2 else "metaal2"))
    b.rect(face, 5, 27, 20, 22, -2, 0, "rubber")
    for u in (5, 26):
        b.rect(face, u, u + 1, 0, 20, -2, 0, "rubber")
    for u in (8, 23):
        b.rect(face, u, u + 1, 6, 9, -2, 0, "rubber")
    b.put(face, 28, 14, -1, "stoplicht_groen")
    b.put(face, 28, 12, -1, "stoplicht_rood_uit")


def ind_roldeur(b, face):
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plint"])
    b.rect(face, 3, 29, 0, 22, 0, 2, 0)
    for z in range(0, 22):
        for u in range(3, 29):
            edge = u in (3, 28) or z == 21
            b.put(face, u, z, 1, b.st["kozijn"] if edge else ("metaal1" if z % 2 else "metaal2"))
    for u in (1, 30):
        for z in range(0, 6):
            b.put(face, u, z, -1, b.st["accent"] if z % 2 else "bord_zwart")


def ind_loopdeur(b, face):
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plint"])
    b.rect(face, 13, 19, 0, 17, 0, 2, 0)
    b.rect(face, 13, 19, 0, 17, 1, 2, "metaal1")
    b.rect(face, 11, 21, 17, 18, -4, 0, b.st["kozijn"])
    b.put(face, 16, 18, -1, "lamp_wit")
    b.window(face, 3, 6, 6, 6, sill=False, lintel=False)
    b.window(face, 23, 6, 6, 6, sill=False, lintel=False)


def ind_kantoor(b, face):
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plint"])
    b.window(face, 2, 4, 28, 14, sill=False, lintel=False)
    b.rect(face, 12, 20, 0, 18, 0, 3, 0)
    b.rect(face, 12, 20, 0, 17, 1, 2, "glas_helder")
    b.rect(face, 10, 22, 18, 19, -5, 0, b.st["kozijn"])


def ind_dicht(b, face):
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plint"])


def ind_lichtstraat(b, face):
    b.window(face, 0, 14, 32, 6, sill=False, lintel=False)
    for u in range(0, 32, 4):
        for z in range(14, 20):
            b.put(face, u, z, 1, b.st["kozijn"])


def ind_wand(b, face):
    pass


def ind_logo(b, face):
    b.sign(face, 2, 30, 8, 16, b.st["accent"] if b.st["accent"] != "bord_geel" else "bord_blauw", "ZWERVR", "bord_wit")


def fab_raam_hoog(b, face):
    """Fabrieksramen: hoge stalen ramen met kleine ruitjes en een rondboog."""
    from buildings2 import lancet
    for u0 in (3, 18):
        lancet(b, face, u0, 11, 2, 16, 22, kind="rond", glass="glas1", frame=b.st["sier"])
        for z in range(2, 22, 3):
            for u in range(u0, u0 + 11):
                if b.m.get(*_xy(face, u, 2), z):
                    b.put(face, u, z, 2, "kozijn_zwart")


def _xy(face, u, d):
    from buildings import fp
    return fp(face, u, d)


def fab_poort(b, face):
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plint"])
    b.rect(face, 6, 26, 0, 18, 0, 2, 0)
    for z in range(0, 18):
        for u in range(6, 26):
            edge = u in (6, 25, 15, 16) or z == 17
            diag = (u - 6) % 10 == z % 10
            b.put(face, u, z, 1, b.st["sier"] if (edge or diag) else "kozijn_groen")
    b.rect(face, 5, 27, 18, 21, -1, 1, b.st["sier"])


def sheddak(style, edges=""):
    """Zaagtanddak (sheddak): steile glazen kant naar het noorden, schuine dichte kant."""
    def fn():
        b = Bld(style, "shed" + edges, 32)
        m = b.m
        for ly in range(S):
            for lx in range(S):
                t = ly % 16
                zt = 2 + int(t * 1.1)
                for z in range(0, zt):
                    glas = t == 15 or ly % 16 == 0
                    if z >= zt - 1:
                        c = "zink1" if (lx % 4) else "zink2"
                    else:
                        c = b.st["wall"]
                    m.set(O + lx, O + ly, z, c)
                if t == 0:
                    for z in range(2, 19):
                        m.set(O + lx, O + ly, z, b.st["glas"] if lx % 4 else "kozijn_zwart")
        for f in edges:
            for u in range(S):
                for z in range(0, 3):
                    b.put(f, u, z, 0, b.st["wall"])
        return m
    return fn


def tondak(style):
    """Gebogen tondak (1 tile breed, nok van voor naar achter); naast elkaar = golvend dak."""
    def fn():
        b = Bld(style, "ton", 32)
        m = b.m
        for ly in range(S):
            for lx in range(S):
                dx = (lx + 0.5 - 16) / 16.0
                zt = 2 + int(10 * math.sqrt(max(0.0, 1 - dx * dx)))
                for z in range(0, zt):
                    m.set(O + lx, O + ly, z, ("golfplaat1" if lx % 3 else "golfplaat2") if z >= zt - 2 else b.st["wall"])
        for ly in range(4, S, 8):
            for lx in range(12, 20):
                dx = (lx + 0.5 - 16) / 16.0
                zt = 2 + int(10 * math.sqrt(max(0.0, 1 - dx * dx)))
                m.set(O + lx, O + ly, zt - 1, "glas_helder")
        return m
    return fn


def x_lichtstraten(b):
    m = b.m
    for ly in range(4, 30, 8):
        for lx in range(4, 28):
            m.set(O + lx, O + ly, 1, "metaal3")
            m.set(O + lx, O + ly + 1, 1, "glas_helder")
            m.set(O + lx, O + ly + 1, 2, "glas_helder")
            m.set(O + lx, O + ly + 2, 1, "metaal3")


for _st in ("loods_staal", "loods_steen", "magazijn", "fabriek"):
    pieces = {"bg_dock": ind_dock, "bg_roldeur": ind_roldeur, "bg_loopdeur": ind_loopdeur, "bg_kantoor": ind_kantoor,
              "bg_dicht": ind_dicht, "verd_wand": ind_wand, "verd_lichtstraat": ind_lichtstraat, "verd_logo": ind_logo}
    if _st == "fabriek":
        pieces.update({"bg_poort": fab_poort, "verd_raam_hoog": fab_raam_hoog})
    corners = [("bg_dicht_hoek", "bg_dicht", "bg_dicht"), ("bg_roldeur_hoek", "bg_roldeur", "bg_dicht"),
               ("bg_kantoor_hoek", "bg_kantoor", "bg_loopdeur"), ("verd_wand_hoek", "verd_wand", "verd_wand"),
               ("verd_lichtstraat_hoek", "verd_lichtstraat", "verd_lichtstraat")]
    if _st == "fabriek":
        corners.append(("verd_raam_hoog_hoek", "verd_raam_hoog", "verd_raam_hoog"))
    roofs = dict(flat_roofs(_st))
    roofs["dak_lichtstraten"] = flat_roof(_st, "", x_lichtstraten)
    roofs["dak_shed"] = sheddak(_st)
    roofs["dak_shed_rand"] = sheddak(_st, "v")
    roofs["dak_ton"] = tondak(_st)
    reg_style(_st, pieces, corners, roofs)


# fabrieksschoorsteen (stapelbaar, 3 m per stuk)
def schoorsteen_deel(deel):
    def fn():
        m = V(W, W, HGT + (6 if deel == "top" else 0))
        c = W / 2
        r0 = {"voet": 7.0, "segment": 4.6, "top": 4.2}[deel]
        for z in range(HGT):
            r = r0 - (z / HGT) * (2.2 if deel == "voet" else 0.3)
            for y in range(W):
                for x in range(W):
                    d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                    if d <= r and (d > r - 1.6 or deel == "voet"):
                        m.set(x, y, z, fabrieksteen(x, y, z) if not (deel == "voet" and z < 4) else P["natuursteen2"])
        if deel == "top":
            for z in range(HGT, HGT + 3):
                m.cyl(c, c, 5.2, z, z + 1, "donkersteen2")
                m.cyl(c, c, 3.4, z, z + 1, 0)
            m.set(c + 4, c, HGT + 3, "signaal_rood")
        return m
    return fn


for _d in ("voet", "segment", "top"):
    register(f"gebouwen/overig/fabrieksschoorsteen_{_d}", schoorsteen_deel(_d))


# ------------------------------------------------------------------ industriële props

@tile("props/industrie/pallet_stapel")
def pallet_stapel():
    m = V(10, 10, 12)
    for lvl in range(4):
        z = lvl * 3
        for y in range(1, 9):
            for x in range(1, 9):
                if (y % 3 != 1) or lvl % 2:
                    m.set(x, y, z, "hout2" if (x + lvl) % 2 else "hout3")
        for y in (1, 4, 8):
            for x in range(1, 9):
                m.set(x, y, z + 1, "hout_donker1")
    for y in range(2, 8):
        for x in range(2, 8):
            for z in range(1, 3):
                m.set(x, y, z, "zand1")
    return m


@tile("props/industrie/zeecontainer")
def zeecontainer():
    m = V(48, 20, 20)
    for z in range(0, 20):
        for y in range(0, 20):
            for x in range(0, 48):
                edge = x in (0, 47) or y in (0, 19) or z in (0, 19)
                if edge:
                    m.set(x, y, z, "bord_rood2" if (x % 2 or z in (0, 19)) else "bord_rood")
    for z in range(2, 18):
        m.set(47, 9, z, "metaal_donker")
        m.set(47, 10, z, "metaal_donker")
    return m


@tile("props/industrie/zeecontainer_stapel")
def zeecontainer_stapel():
    m = V(48, 44, 40)
    kleuren = [("bord_rood", "bord_rood2"), ("bord_blauw", "bord_blauw2"), ("bord_groen", "bord_groen2"), ("bord_oranje", "oranje")]
    for i, (oy, oz) in enumerate(((2, 0), (22, 0), (2, 20))):
        k = kleuren[i]
        for z in range(oz, oz + 20):
            for y in range(oy, oy + 20):
                for x in range(0, 48):
                    edge = x in (0, 47) or y in (oy, oy + 19) or z in (oz, oz + 19)
                    if edge:
                        m.set(x, y, z, k[1] if x % 2 else k[0])
    return m


@tile("props/industrie/silo")
def silo():
    m = V(28, 28, 96)
    for z in range(0, 96):
        if z < 10:
            for (x, y) in ((6, 6), (21, 6), (6, 21), (21, 21)):
                m.box(x, y, z, x + 2, y + 2, z + 1, "metaal2")
            continue
        r = 11 if z < 84 else 11 - (z - 84) * 0.9
        m.cyl(14, 14, max(1, r), z, z + 1, "rvs" if (z // 6) % 2 else "metaal3")
    for z in range(0, 90):
        m.set(26, 14, z, "metaal_donker")
    return m


@tile("props/industrie/opslagtank")
def opslagtank():
    m = V(40, 40, 40)
    for z in range(0, 36):
        m.cyl(20, 20, 18, z, z + 1, "stuc1" if z % 8 else "stuc3")
    for z in range(36, 40):
        m.cyl(20, 20, 18 - (z - 35) * 3.5, z, z + 1, "stuc2")
    for t in range(0, 36):
        a = t / 36 * math.pi
        m.set(20 + math.cos(a) * 18.5, 20 + math.sin(a) * 18.5, t, "metaal_donker")
    return m


@tile("props/industrie/heftruck")
def heftruck():
    m = V(12, 24, 20)
    m.box(1, 6, 1, 11, 20, 7, "bord_oranje")
    m.box(1, 14, 7, 11, 20, 9, "bord_oranje")
    for (x, y) in ((1, 8), (10, 8), (1, 17), (10, 17)):
        m.cyl(x + 0.5, y + 0.5, 1.6, 0, 3, "rubber") if False else m.box(x - 1 if x == 1 else x, y - 1, 0, x + 1 if x == 1 else x + 2, y + 2, 3, "rubber")
    for (x, y) in ((2, 8), (9, 8), (2, 17), (9, 17)):
        for z in range(7, 16):
            m.set(x, y, z, "bord_zwart")
    m.box(2, 8, 15, 10, 18, 16, "bord_zwart")
    m.box(3, 11, 7, 9, 13, 10, "bord_zwart")
    for x in (3, 8):
        for z in range(1, 17):
            m.set(x, 4, z, "metaal_donker")
        for y in range(0, 5):
            m.set(x, y, 1, "metaal3")
    return m


@tile("props/industrie/kabelhaspel")
def kabelhaspel():
    m = V(12, 8, 12)
    for x in range(12):
        for z in range(12):
            d = math.hypot(x + 0.5 - 6, z + 0.5 - 6)
            if d < 6:
                for y in (1, 6):
                    m.set(x, y, z, "hout2")
            if d < 3:
                for y in range(2, 6):
                    m.set(x, y, z, "bord_zwart")
    return m


@tile("props/industrie/laadperron")
def laadperron():
    m = V(24, 16, 10)
    m.box(0, 0, 0, 24, 16, 9, mix("beton1", "beton2", seed=1002))
    for x in range(24):
        m.set(x, 0, 8, "bord_geel" if (x // 3) % 2 else "bord_zwart")
    return m
