"""Uitbreiding gebouwen: jaren 30 bovenhuizen, jaren 60 woningen en galerijflats,
moderne appartementen, herenhuizen, winkels/horeca, kantoren (80/2000/modern),
musea, kerken, scholen, overheid, schuren, hallen/overkappingen (hol) en pilaren.
"""
import math

from common import register, text_pixels
from palette import P
from vox import V, mix, pick, h, blocky
from buildings import (Bld, STYLES, S, O, W, HGT, brick, planks, panels, fp, make_block, pitched, flat_roof,
                       gable_top, H_SCHUIN, H_HOEK_BUITEN, H_HOEK_BINNEN, H_ZADEL, H_ZADEL_SCHILD, H_ZADEL_HOEK,
                       x_dakkapel, x_schoorsteen, x_dakraam, x_installatie, x_zonnepanelen, x_dakterras_plat,
                       f_kantoor_vlies, f_kantoor_band, f_kantoor_bg_entree, f_kantoor_bg_glas, f_bg_winkel,
                       f_bg_winkel_luifel, roof_colors)

NATSTEEN_BLOK = blocky(["natuursteen1", "natuursteen2", "natuursteen3"], size=3, seed=200)
GRIJSSTEEN = blocky(["beton1", "beton3", "natuursteen3", "beton2"], size=3, seed=201)


def wall_flat60(x, y, z):
    u = x + y
    if u % 16 == 0 or z in (0, 1):
        return P["beton60"]
    return pick(["geelsteen60_1", "geelsteen60_2"], (u + (z % 2) * 2) // 3, z, 0, 202)


def wall_1900(x, y, z):
    if z in (0, 1, 13, 22, 23):
        return pick(["stuc1", "stuc2"], x + y, z, 0, 203)
    u = x + y
    return pick(["baksteen1", "baksteen3", "baksteen5"], (u + (z % 2) * 2) // 3, z, 0, 204)


def wall_overheid(x, y, z):
    if z in (0, 1, 2, 12, 23):
        return pick(["natuursteen1", "natuursteen2"], (x + y) // 4, z, 0, 205)
    u = x + y
    return pick(["donkersteen1", "baksteen4", "donkersteen3"], (u + (z % 2) * 2) // 3, z, 0, 206)


def wall_school(x, y, z):
    if z in (0, 1):
        return P["beton60"]
    u = x + y
    return pick(["baksteen5", "geelsteen1", "baksteen3"], (u + (z % 2) * 2) // 3, z, 0, 207, [3, 2, 2])


def wall_museum_m(x, y, z):
    u = x + y
    if u % 16 == 0 or z == 0:
        return P["stuc3"]
    return pick(["stuc1", "stuc2"], u // 16, z // 12, 0, 208)


NEW_STYLES = {
    "jaren30": dict(fam="jaren30", wall=brick(["baksteen30_1", "baksteen30_2", "baksteen30_3"], 210, (3, 3, 2)),
                    kozijn="kozijn_creme", deuren=["deur_groen", "deur_rood", "hout_donker1"], plint="donkersteen2",
                    sier="natuursteen2", dak=("pan_zwart1", "pan_zwart2", "pan_zwart3"), dakvloer=("bitumen1", "bitumen2"),
                    glas="glas1", winkel="hout_donker1", luik="kozijn_groen", cap="zink1"),
    "jaren60": dict(fam="jaren60", wall=brick(["geelsteen60_1", "geelsteen60_2"], 211, (3, 2)),
                    kozijn="kozijn_wit", deuren=["paneel_blauw", "paneel_geel", "paneel_rood", "paneel_groen"],
                    plint="beton60", sier="beton60", dak=("pan_zwart1", "pan_zwart2", "pan_zwart3"),
                    dakvloer=("dakgrind1", "dakgrind2"), glas="glas2", winkel="kozijn_wit", cap="kozijn_wit",
                    boeiboord="kozijn_wit", panelen=["paneel_blauw", "paneel_geel", "paneel_rood", "paneel_groen"]),
    "galerijflat": dict(fam="flat", wall=wall_flat60, kozijn="kozijn_wit", deuren=["paneel_blauw", "paneel_geel", "paneel_rood"],
                        plint="beton60", sier="beton60", dak=("dakgrind1", "dakgrind2"), glas="glas2", winkel="kozijn_wit",
                        cap="beton60", panelen=["paneel_blauw", "paneel_geel", "paneel_rood", "paneel_groen"]),
    "appartement_modern": dict(fam="appmodern", wall=mix("stuc1", "paneel3", "stuc2", seed=212, weights=[4, 1, 2]),
                               kozijn="antraciet1", deuren=["antraciet2"], plint="antraciet2", sier="antraciet1",
                               dak=("dakgrind1", "dakgrind2"), glas="glas2", winkel="antraciet1", cap="alu", accent=planks(["hout1", "hout2", "hout3"], 213)),
    "herenhuis_1600": dict(fam="heren1600", wall=NATSTEEN_BLOK, kozijn="kozijn_wit", deuren=["deur_groen", "deur_zwart"],
                           plint="natuursteen3", sier="natuursteen1", dak=("leisteen1", "leisteen2", "leisteen1"),
                           dakvloer=("zink1", "zink2"), glas="glas1", winkel="kozijn_groen", luik="kozijn_groen", cap="natuursteen1"),
    "herenhuis_1900": dict(fam="heren1900", wall=wall_1900, kozijn="kozijn_wit", deuren=["deur_rood", "deur_groen", "hout_donker1"],
                           plint="natuursteen3", sier="stuc1", dak=("pan_zwart1", "pan_zwart2", "leisteen1"),
                           dakvloer=("zink1", "zink2"), glas="glas1", winkel="kozijn_groen", luik="kozijn_groen", cap="zink1"),
    "kantoor_80": dict(fam="kantoor", wall=panels(["bruin80_1", "bruin80_2"], 214, "antraciet3", 8), kozijn="antraciet3", deuren=["antraciet3"],
                       plint="bruin80_1", sier="antraciet3", dak=("bitumen1", "bitumen2"), glas="glas_brons", winkel="antraciet3", cap="antraciet1"),
    "kantoor_2000": dict(fam="kantoor", wall=panels(["paneel3", "paneel1"], 215, "alu", 16), kozijn="alu", deuren=["alu"],
                         plint="antraciet1", sier="alu", dak=("bitumen1", "bitumen2"), glas="glas_blauw", winkel="alu", cap="alu"),
    "kantoor_modern": dict(fam="kantoor", wall=mix("stuc1", "paneel3", seed=216, weights=[5, 1]), kozijn="stuc1", deuren=["antraciet1"],
                           plint="antraciet1", sier="stuc1", dak=("dakgrind1", "dakgrind2"), glas="glas_groen", winkel="stuc1", cap="stuc1",
                           accent=planks(["hout1", "hout2", "hout3"], 217)),
    "museum_klassiek": dict(fam="museum_k", wall=NATSTEEN_BLOK, kozijn="kozijn_creme", deuren=["hout_donker1"], plint="natuursteen3",
                            sier="natuursteen1", dak=("koper", "koper", "leisteen1"), dakvloer=("zink1", "zink2"), glas="glas1",
                            winkel="hout_donker1", cap="natuursteen1"),
    "museum_modern": dict(fam="museum_m", wall=wall_museum_m, kozijn="antraciet1", deuren=["antraciet1"], plint="antraciet2",
                          sier="antraciet1", dak=("dakgrind1", "dakgrind2"), glas="glas2", winkel="antraciet1", cap="stuc1"),
    "kerk_baksteen": dict(fam="kerk", wall=brick(["baksteen2", "baksteen4", "donkersteen1", "baksteen1"], 218, (3, 3, 1, 2)),
                          kozijn="natuursteen2", deuren=["hout_donker2"], plint="natuursteen3", sier="natuursteen2",
                          dak=("leisteen1", "leisteen2", "leisteen1"), dakvloer=("zink1",), glas="glas_lood_blauw", winkel="hout_donker2", cap="natuursteen2"),
    "kerk_steen": dict(fam="kerk", wall=GRIJSSTEEN, kozijn="natuursteen1", deuren=["hout_donker2"], plint="natuursteen3",
                       sier="natuursteen1", dak=("leisteen2", "leisteen1", "koper"), dakvloer=("zink1",), glas="glas_lood_rood",
                       winkel="hout_donker2", cap="natuursteen1"),
    "kerk_modern": dict(fam="kerk_modern", wall=brick(["geelsteen60_1", "geelsteen60_2", "geelsteen2"], 219, (3, 2, 1)),
                        kozijn="antraciet1", deuren=["hout2"], plint="beton60", sier="beton60", dak=("zink1", "zink2"),
                        dakvloer=("dakgrind1", "dakgrind2"), glas="glas_lood_geel", winkel="antraciet1", cap="beton60"),
    "school": dict(fam="school", wall=wall_school, kozijn="kozijn_zwart", deuren=["paneel_groen"], plint="beton60",
                   sier="beton60", dak=("dakgrind1", "dakgrind2"), glas="glas1", winkel="kozijn_zwart", cap="zink1"),
    "overheid": dict(fam="overheid", wall=wall_overheid, kozijn="kozijn_wit", deuren=["hout_donker1"], plint="natuursteen3",
                     sier="natuursteen1", dak=("leisteen1", "leisteen2", "leisteen1"), dakvloer=("zink1", "zink2"), glas="glas1",
                     winkel="kozijn_wit", cap="natuursteen1"),
    "schuur_zwart": dict(fam="schuur", wall=planks(["schuur_zwart", "schuur_zwart", "antraciet3"], 220), kozijn="kozijn_wit",
                         deuren=["schuur_zwart"], plint="baksteen4", sier="kozijn_wit", dak=("riet_dak1", "riet_dak2", "riet_dak1"),
                         glas="glas2", winkel="kozijn_wit", cap="zink1"),
    "schuur_rood": dict(fam="schuur", wall=planks(["schuur_rood", "baksteen4", "schuur_rood"], 221), kozijn="kozijn_wit",
                        deuren=["kozijn_groen"], plint="baksteen4", sier="kozijn_wit", dak=("pan_rood1", "pan_rood2", "pan_rood3"),
                        glas="glas2", winkel="kozijn_wit", cap="zink1"),
}
STYLES.update(NEW_STYLES)


# ------------------------------------------------------------------ hulpjes

def lancet(b, face, u0, w, z0, z_spring, z_top, d0=0, glass=None, frame=None, kind="spits"):
    """Spitsboog-/rondboograam. Tussen z0 en z_spring recht, daarboven de boog."""
    fr = frame or b.st["sier"]
    cu = u0 + w / 2.0
    for z in range(z0, z_top + 1):
        for u in range(u0 - 1, u0 + w + 1):
            uc = u + 0.5
            if z < z_spring:
                inside = u0 <= u < u0 + w
                ring = u in (u0 - 1, u0 + w)
            else:
                zz = z + 0.5 - z_spring
                if kind == "spits":
                    r = w
                    d1 = math.hypot(uc - u0, zz)
                    d2 = math.hypot(uc - (u0 + w), zz)
                    inside = d1 <= r - 0.0 and d2 <= r - 0.0 and u0 <= u < u0 + w
                    ring = (d1 <= r + 1 and d2 <= r + 1) and not inside and u0 - 1 <= u <= u0 + w
                else:
                    r = w / 2.0
                    d = math.hypot(uc - cu, zz)
                    inside = d <= r
                    ring = r < d <= r + 1.2
            if inside:
                b.put(face, u, z, d0, 0)
                b.put(face, u, z, d0 + 1, 0)
                gc = glass or pick(["glas_lood_blauw", "glas_lood_rood", "glas_lood_geel", "glas_lood_blauw"], u, z, b.seed, 230)
                if (u - u0) % 3 == 2 or z % 4 == 0:
                    gc = "metaal_donker"
                b.put(face, u, z, d0 + 2, gc)
                b.put(face, u, z, d0 + 3, "interieur1" if (u + z) % 3 else "licht_warm")
            elif ring:
                b.put(face, u, z, d0, fr)


def clock(b, face, cu, cz, r=6.0, d=-1):
    for z in range(int(cz - r - 1), int(cz + r + 2)):
        for u in range(int(cu - r - 1), int(cu + r + 2)):
            dd = math.hypot(u + 0.5 - cu, z + 0.5 - cz)
            if dd <= r:
                b.put(face, u, z, d, "bord_wit" if dd < r - 1 else "goud")
    for t in range(int(r) - 1):
        b.put(face, int(cu), int(cz) + t, d - 1, "bord_zwart")
    for t in range(int(r * 0.6)):
        b.put(face, int(cu) + t, int(cz), d - 1, "bord_zwart")
    for k in range(12):
        a = k / 12 * math.tau
        b.put(face, int(cu + math.sin(a) * (r - 1.6)), int(cz + math.cos(a) * (r - 1.6)), d - 1, "bord_zwart")


def colored_panel(b, face, u0, u1, z0, z1, d=0, key=0):
    c = b.st.get("panelen", ["paneel_blauw"])[(b.seed + key) % len(b.st.get("panelen", ["x"]))]
    b.rect(face, u0, u1, z0, z1, d, d + 1, c)


def gallery(b, face, depth=8):
    """Galerij (uitkragende loopgang) met borstwering."""
    b.rect(face, 0, S, 0, 2, -depth, 0, b.st["sier"])
    b.rect(face, 0, S, 2, 9, -depth, -depth + 1, b.st["sier"])
    for u in range(0, S, 4):
        b.rect(face, u, u + 3, 3, 8, -depth - 1, -depth, b.st.get("panelen", ["paneel_blauw"])[(u // 4 + b.seed) % 4])
    b.rect(face, 0, S, 9, 10, -depth, -depth + 1, "metaal3")


# ------------------------------------------------------------------ winkels en horeca

def shop_interior(b, face, kind):
    for u in range(3, 21):
        for z in range(3, 16):
            if u == 11:
                continue
            c = None
            if kind == "kleding":
                if u % 5 == 1 and z < 13:
                    c = "stuc1" if z > 10 else pick(["stof1", "stof2", "stof3", "luifel_geel"], u, 0, b.seed, 231)
                elif z == 12 and u % 5 in (3, 4):
                    c = "rvs"
                elif z < 12 and u % 5 in (3, 4) and z > 6:
                    c = pick(["stof1", "stof2", "stof3", "bloem_roze", "luifel_blauw"], u, z, b.seed, 232)
                else:
                    c = "stof3" if z < 3 else ("licht_wit" if z == 15 else "stuc2")
            elif kind == "restaurant":
                if z in (6, 7) and u % 6 in (1, 2, 3, 4):
                    c = "tafelkleed"
                elif z < 6 and u % 6 in (2, 3):
                    c = "hout_donker1"
                elif z == 14 and u % 6 == 3:
                    c = "licht_warm"
                else:
                    c = "deur_rood" if z < 9 else "interieur2"
            elif kind == "cafe":
                if z < 8 and u > 14:
                    c = "hout2"
                elif z == 8 and u > 14:
                    c = "hout_donker1"
                elif z > 10 and u > 14 and u % 2 == 0:
                    c = pick(["glas_lood_geel", "glas_lood_rood", "bloem_groen" if False else "blad3"], u, z, b.seed, 233)
                elif z == 14:
                    c = "licht_warm"
                else:
                    c = "hout_donker1" if z < 5 else "interieur2"
            elif kind == "bar":
                if z == 13 or (u == 4 and z > 4):
                    c = "neon_blauw"
                elif z < 7 and u > 13:
                    c = "hout_donker2"
                else:
                    c = "interieur3"
            elif kind == "telefoon":
                if z in (6, 7) and u % 4 in (1, 2):
                    c = "scherm"
                elif z == 5:
                    c = "stuc1"
                elif z == 15:
                    c = "licht_wit"
                else:
                    c = "stuc1" if z < 5 else "stuc2"
            if c:
                b.put(face, u, z, 3, c)


SHOP_TYPES = {
    "kleding": ("MODE", ["luifel_wit", "bord_zwart"], "bord_zwart", "bord_wit"),
    "restaurant": ("BISTRO", ["luifel_rood", "luifel_rood"], "deur_rood", "goud"),
    "cafe": ("CAFE", ["luifel_groen", "luifel_wit"], "deur_groen", "goud"),
    "bar": ("BAR", None, "bord_zwart", "neon_roze"),
    "telefoon": ("TELECOM", None, "bord_blauw", "bord_wit"),
}


def shop_piece(kind):
    text, luifel, board, letter = SHOP_TYPES[kind]

    def f(b, face):
        b.shopfront(face, text, luifel)
        shop_interior(b, face, kind)
        b.sign(face, 1, 31, 17, 23, board, text, letter)
        if kind == "bar":
            for u in range(2, 30):
                b.put(face, u, 17, -2, "neon_roze" if u % 2 else 0)
        if kind == "telefoon":
            b.rect(face, 1, 31, 16, 17, 0, 1, "scherm")
    f.__name__ = "f_shop_" + kind
    return f


SHOP_PIECES = {f"bg_{k}": shop_piece(k) for k in SHOP_TYPES}


# ------------------------------------------------------------------ jaren 30

def j30_bg_portiek(b, face):
    b.plinth(face, 2)
    b.rect(face, 10, 22, 0, 19, 0, 7, 0)
    b.rect(face, 10, 22, 0, 1, 0, 7, "natuursteen3")
    for z in range(19, 21):
        b.rect(face, 9, 23, z, z + 1, -1, 1, b.st["sier"])
    for u, c in ((11, "deur_groen"), (17, "deur_rood")):
        b.rect(face, u, u + 4, 1, 17, 7, 8, c)
        b.rect(face, u, u + 4, 13, 16, 7, 8, "glas_lood_geel")
        b.put(face, u + 3, 8, 6, "messing")
    b.rect(face, 15, 17, 1, 18, 7, 8, b.st["wall"])
    b.put(face, 16, 12, 6, "lamp_warm")
    b.window(face, 2, 5, 7, 14, sill=True, lintel=False)
    b.window(face, 24, 5, 7, 14, sill=True, lintel=False)
    _lood(b, face, 2, 7, 15)
    _lood(b, face, 24, 7, 15)


def _lood(b, face, u0, w, zt):
    for u in range(u0 + 1, u0 + w - 1):
        for z in (zt, zt + 1):
            b.put(face, u, z, 2, pick(["glas_lood_geel", "glas_lood_rood", "glas_lood_blauw"], u, z, b.seed, 234))


def j30_bg_raam(b, face):
    b.plinth(face, 2)
    b.window(face, 3, 4, 26, 16, sill=True, lintel=False)
    for z in range(4, 20):
        for u in (11, 20):
            b.put(face, u, z, 1, b.st["kozijn"])
    for u in range(3, 29):
        b.put(face, u, 15, 1, b.st["kozijn"])
    _lood(b, face, 3, 26, 16)


def j30_verd_raam(b, face):
    for u0 in (3, 18):
        b.window(face, u0, 5, 11, 15, sill=True, lintel=False)
        for z in range(5, 20):
            b.put(face, u0 + 5, z, 1, b.st["kozijn"])
        for u in range(u0, u0 + 11):
            b.put(face, u, 15, 1, b.st["kozijn"])
        _lood(b, face, u0, 11, 16)
    b.rect(face, 0, S, 22, 23, 0, 1, "donkersteen2")


def j30_verd_erker(b, face):
    for z in range(0, 23):
        for d in range(1, 5):
            inset = max(0, d - 2)
            b.rect(face, 5 + inset, 27 - inset, z, z + 1, -d, -d + 1, b.st["wall"])
    b.rect(face, 4, 28, 22, 23, -5, 0, "zink1")
    b.window(face, 8, 5, 16, 15, sill=False, lintel=False, d0=-4)
    for z in range(5, 20):
        b.put(face, 13, z, -3, b.st["kozijn"])
        b.put(face, 18, z, -3, b.st["kozijn"])
    _lood_d(b, face, 8, 16, 16, -4)
    b.rect(face, 5, 27, 0, 3, -5, 0, b.st["sier"])


def _lood_d(b, face, u0, w, zt, d0):
    for u in range(u0 + 1, u0 + w - 1):
        for z in (zt, zt + 1):
            b.put(face, u, z, d0 + 2, pick(["glas_lood_geel", "glas_lood_rood", "glas_lood_blauw"], u, z, b.seed, 235))


def j30_verd_balkon(b, face):
    b.rect(face, 2, 30, 0, 1, -5, 0, "beton60")
    b.rect(face, 2, 30, 1, 8, -5, -4, b.st["wall"])
    b.rect(face, 2, 3, 1, 8, -5, 0, b.st["wall"])
    b.rect(face, 29, 30, 1, 8, -5, 0, b.st["wall"])
    b.rect(face, 2, 30, 8, 9, -5, -4, b.st["sier"])
    b.window(face, 4, 2, 9, 19, sill=False, lintel=False)
    b.window(face, 18, 5, 11, 15, sill=False, lintel=False)


def j30_verd_trappenhuis(b, face):
    b.window(face, 12, 1, 8, 22, sill=False, lintel=False)
    for z in range(1, 23, 3):
        for u in range(12, 20):
            b.put(face, u, z, 2, pick(["glas_lood_geel", "glas1", "glas_lood_rood"], u, z, b.seed, 236))
    b.window(face, 3, 6, 6, 12)
    b.window(face, 23, 6, 6, 12)


# ------------------------------------------------------------------ jaren 60

def j60_bg_deur(b, face):
    b.plinth(face, 1)
    b.door(face, 3, 7, 0, 17, transom=False, glass_panel=True)
    b.rect(face, 10, 12, 0, 17, 0, 3, 0)
    b.rect(face, 10, 12, 0, 17, 2, 3, "glas2")
    b.rect(face, 1, 14, 18, 19, -6, 0, "beton60")
    b.window(face, 15, 4, 15, 14, sill=True, lintel=False, sill_c="beton60")
    colored_panel(b, face, 15, 30, 18, 23, 0, 1)
    b.put(face, 8, 14, -1, "lamp_wit")


def j60_bg_raam(b, face):
    b.plinth(face, 1)
    b.window(face, 2, 2, 28, 16, sill=False, lintel=False)
    for z in range(2, 18):
        b.put(face, 16, z, 1, b.st["kozijn"])
    colored_panel(b, face, 2, 30, 19, 23, 0, 2)


def j60_bg_berging(b, face):
    b.plinth(face, 1)
    for u0 in (2, 12, 22):
        b.rect(face, u0, u0 + 8, 0, 16, 0, 2, 0)
        b.rect(face, u0, u0 + 8, 0, 16, 1, 2, b.st["deuren"][(u0 + b.seed) % 4])
        b.put(face, u0 + 6, 8, 0, "rvs")


def j60_verd_raam(b, face):
    colored_panel(b, face, 1, 31, 1, 6, 0, 3)
    b.window(face, 1, 6, 30, 13, sill=False, lintel=False)
    for z in range(6, 19):
        for u in (11, 21):
            b.put(face, u, z, 1, b.st["kozijn"])


def j60_verd_raam_klein(b, face):
    for u0 in (3, 13, 23):
        b.window(face, u0, 9, 7, 10, sill=True, lintel=False, sill_c="beton60")


def j60_galerij_deur(b, face):
    gallery(b, face)
    b.door(face, 3, 7, 2, 19, transom=False, glass_panel=True, color=b.st["deuren"][b.seed % 4])
    b.window(face, 13, 10, 8, 9, sill=False, lintel=False)
    b.window(face, 23, 10, 7, 9, sill=False, lintel=False)
    b.put(face, 11, 14, -1, "lamp_wit")


def j60_galerij_raam(b, face):
    gallery(b, face)
    b.window(face, 3, 10, 12, 9, sill=False, lintel=False)
    b.window(face, 18, 10, 12, 9, sill=False, lintel=False)


def j60_verd_balkon(b, face):
    b.rect(face, 3, 29, 0, 2, -7, 0, "beton60")
    b.rect(face, 3, 29, 2, 9, -7, -6, b.st.get("panelen")[b.seed % 4])
    b.rect(face, 3, 4, 2, 9, -7, 0, "metaal3")
    b.rect(face, 28, 29, 2, 9, -7, 0, "metaal3")
    b.window(face, 4, 2, 10, 19, sill=False, lintel=False)
    b.window(face, 16, 6, 13, 14, sill=False, lintel=False)


# ------------------------------------------------------------------ galerijflat

def flat_galerij(b, face):
    gallery(b, face, 8)
    for i, u0 in enumerate((1, 17)):
        b.door(face, u0, 6, 2, 19, transom=False, glass_panel=True, color=b.st["deuren"][(b.seed + i) % 3])
        b.window(face, u0 + 8, 9, 6, 10, sill=False, lintel=False)
    b.put(face, 15, 15, -1, "lamp_wit")


def flat_balkons(b, face):
    b.rect(face, 1, 31, 0, 22, 0, 6, 0)
    b.rect(face, 1, 31, 0, 1, 0, 6, "beton60")
    b.rect(face, 1, 31, 1, 8, 0, 1, b.st["panelen"][b.seed % 4])
    b.rect(face, 1, 31, 8, 9, 0, 1, "metaal3")
    b.rect(face, 15, 17, 0, 22, 0, 6, "beton60")
    for u0 in (2, 18):
        b.window(face, u0, 2, 12, 18, sill=False, lintel=False, d0=5)


def flat_trappenhuis(b, face):
    b.window(face, 10, 0, 12, 23, sill=False, lintel=False)
    for z in range(0, 23, 4):
        for u in range(10, 22):
            b.put(face, u, z, 1, b.st["kozijn"])


def flat_kopgevel(b, face):
    b.window(face, 14, 9, 4, 6, sill=False, lintel=False)


def flat_bg_entree(b, face):
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plint"])
    b.window(face, 6, 0, 20, 21, sill=False, lintel=False)
    b.rect(face, 12, 20, 0, 18, 1, 3, "glas_helder")
    for z in range(0, 18):
        b.put(face, 16, z, 1, "metaal3")
    b.rect(face, 4, 28, 21, 22, -6, 0, "beton60")
    for u in range(7, 11):
        b.put(face, u, 8, 2, "metaal3")


def flat_bg_bergingen(b, face):
    b.rect(face, 0, S, 0, 1, 0, 1, b.st["plint"])
    for u0 in (1, 9, 17, 25):
        b.rect(face, u0, u0 + 6, 0, 16, 0, 2, 0)
        b.rect(face, u0, u0 + 6, 0, 16, 1, 2, "paneel2" if u0 % 2 else "paneel1")
        b.put(face, u0 + 4, 8, 0, "rvs")
    for u in range(0, S):
        b.put(face, u, 19, 0, "glas2" if u % 8 not in (0, 7) else b.st["kozijn"])


# ------------------------------------------------------------------ modern appartement

def app_bg_entree(b, face):
    b.window(face, 2, 0, 28, 23, sill=False, lintel=False)
    b.rect(face, 10, 22, 0, 19, 1, 3, "glas_helder")
    b.rect(face, 0, S, 22, 24, -4, 1, b.st["accent"])
    b.sign(face, 6, 26, 18, 22, "antraciet1", "ENTREE", "lamp_wit") if False else None


def app_verd_glas(b, face):
    b.window(face, 1, 1, 30, 22, sill=False, lintel=False)
    b.rect(face, 1, 31, 2, 9, 0, 1, "glas_helder")
    b.rect(face, 1, 31, 9, 10, 0, 1, "rvs")
    for u in (10, 21):
        for z in range(1, 23):
            b.put(face, u, z, 1, b.st["kozijn"])


def app_verd_loggia(b, face):
    b.rect(face, 2, 30, 0, 22, 0, 8, 0)
    b.rect(face, 2, 30, 0, 1, 0, 8, b.st["accent"])
    b.rect(face, 2, 30, 21, 22, 0, 8, b.st["accent"])
    b.rect(face, 2, 30, 1, 9, 0, 1, "glas_helder")
    b.window(face, 3, 1, 26, 20, sill=False, lintel=False, d0=7)


def app_verd_paneel(b, face):
    b.rect(face, 0, 12, 0, 24, 0, 1, b.st["accent"])
    b.window(face, 14, 3, 14, 18, sill=False, lintel=False)


def app_verd_klein(b, face):
    for u0 in (3, 11, 19, 27):
        b.window(face, u0, 8, 3, 8, sill=False, lintel=False)


def app_verd_groot(b, face):
    b.rect(face, 0, S, 0, 24, 0, 3, 0)
    for z in range(0, 24):
        for u in range(0, S):
            edge = u in (0, 31) or z in (0, 23) or u == 16
            b.put(face, u, z, 0, b.st["kozijn"] if edge else 0)
            b.put(face, u, z, 1, 0 if edge else b.st["glas"])
    b.interior(face, 1, 31, 1, 23, 2, 900)


# ------------------------------------------------------------------ herenhuizen

def pilasters(b, face, z0=0, z1=24):
    for u in (0, 1, 30, 31):
        for z in range(z0, z1):
            b.put(face, u, z, -1, b.st["sier"])
    for u in (-1, 0, 1, 2, 29, 30, 31, 32):
        if 0 <= u < S:
            b.put(face, u, z1 - 1, -2, b.st["sier"])


def h1600_bg_deur(b, face):
    pilasters(b, face)
    b.plinth(face, 3)
    b.door(face, 11, 10, 4, 20, steps=0)
    for i in range(4):
        b.rect(face, 8 - i * 2, 24 + i * 2, 0, 4 - i, -1 - i, -i, "natuursteen1")
    b.rect(face, 9, 23, 3, 4, -6, -1, "natuursteen1")
    for u in (8, 23):
        for z in range(4, 9):
            b.put(face, u, z, -5, "metaal_donker")
    b.window(face, 3, 6, 6, 14, roedes=True)
    b.window(face, 25, 6, 5, 14, roedes=True)


def h1600_bg_raam(b, face):
    pilasters(b, face)
    b.plinth(face, 3)
    for u0 in (4, 13, 22):
        b.window(face, u0, 6, 7, 15, roedes=True)


def h1600_verd_raam(b, face):
    pilasters(b, face)
    for u0 in (4, 13, 22):
        b.window(face, u0, 4, 7, 17, roedes=True)


def h1600_verd_balkon(b, face):
    pilasters(b, face)
    b.window(face, 12, 2, 8, 19, roedes=True, sill=False)
    b.rect(face, 9, 23, 0, 2, -4, 0, "natuursteen1")
    for u in range(9, 23):
        b.put(face, u, 7, -4, "natuursteen1")
        if u % 2 == 0:
            for z in range(2, 7):
                b.put(face, u, z, -4, "natuursteen2")
    b.window(face, 3, 4, 6, 17, roedes=True)
    b.window(face, 24, 4, 6, 17, roedes=True)


def top_lijstgevel(style, fronton=True):
    def fn():
        b = Bld(style, "lijst" + str(fronton), 24)
        st = b.st
        b.m.box(O, O + 2, 0, O + S, O + S, 6, st["wall"])
        b.m.box(O, O + 2, 6, O + S, O + S, 7, "zink1")
        for u in range(S):
            for d in range(-3, 1):
                b.put("v", u, 0, d, "kozijn_wit")
                b.put("v", u, 1, d, "kozijn_wit")
            if u % 2 == 0:
                b.put("v", u, 2, -1, "kozijn_wit")
            for z in range(3, 9):
                b.put("v", u, z, 0, st["wall"])
            if u % 3 == 0:
                for z in range(3, 8):
                    b.put("v", u, z, -1, st["sier"])
            b.put("v", u, 8, -1, st["sier"])
            b.put("v", u, 8, 0, st["sier"])
        if fronton:
            for z in range(9, 17):
                half = 16 - (z - 9) * 2
                for u in range(16 - half, 16 + half):
                    edge = u in (16 - half, 16 + half - 1) or z == 9
                    b.put("v", u, z, 0, st["sier"] if edge else st["wall"])
                    b.put("v", u, z, 1, st["wall"])
            b.window(b and "v", 13, 10, 6, 4, sill=False, lintel=False)
        return b.m
    return fn


def h1900_bg_deur(b, face):
    b.plinth(face, 2)
    b.door(face, 3, 8, 2, 19, steps=2)
    lancet(b, face, 15, 13, 4, 15, 21, kind="rond", glass="glas1", frame=b.st["sier"])


def h1900_bg_raam_boog(b, face):
    b.plinth(face, 2)
    lancet(b, face, 3, 11, 4, 15, 21, kind="rond", glass="glas1", frame=b.st["sier"])
    lancet(b, face, 18, 11, 4, 15, 21, kind="rond", glass="glas1", frame=b.st["sier"])


def h1900_verd_raam_boog(b, face):
    for u0 in (3, 18):
        lancet(b, face, u0, 10, 4, 15, 20, kind="rond", glass="glas1", frame=b.st["sier"])
        b.rect(face, u0 - 1, u0 + 11, 3, 4, -1, 1, b.st["sier"])


def h1900_verd_erker(b, face):
    for d in range(1, 5):
        b.rect(face, 6, 26, 0, 23, -d, -d + 1, b.st["wall"])
    b.rect(face, 5, 27, 23, 24, -5, 0, "zink1")
    b.window(face, 8, 4, 16, 16, roedes=True, d0=-4, sill=False)
    b.rect(face, 6, 26, 0, 2, -5, 0, b.st["sier"])


def mansarde(style, edges):
    """Mansardedak: steile onderste helling met dakkapellen, plat bovenop."""
    def fn():
        b = Bld(style, "mansarde" + edges, 32)
        m = b.m
        for ly in range(S):
            for lx in range(S):
                dists = []
                if "v" in edges: dists.append(ly)
                if "a" in edges: dists.append(S - 1 - ly)
                if "l" in edges: dists.append(lx)
                if "r" in edges: dists.append(S - 1 - lx)
                d = min(dists) if dists else 99
                top = 16 if d >= 6 else int(2 + d * 2.4)
                for z in range(top):
                    c = roof_colors(b, z, lx, ly) if (d < 6 and z >= top - 3) else b.st["wall"]
                    m.set(O + lx, O + ly, z, c)
                if d >= 6:
                    m.set(O + lx, O + ly, 16, "zink1")
        for face in edges:
            for u0 in (6, 20):
                b.rect(face, u0, u0 + 6, 2, 13, 0, 3, "kozijn_wit")
                b.rect(face, u0 + 1, u0 + 5, 3, 11, 0, 1, b.st["glas"])
                b.rect(face, u0 - 1, u0 + 7, 13, 14, -1, 3, "zink1")
        return m
    return fn


# ------------------------------------------------------------------ kantoren

def k80_spiegelband(b, face):
    b.rect(face, 0, S, 0, 8, -1, 1, "bruin80_2")
    for z in range(8, 22):
        for u in range(S):
            b.put(face, u, z, 0, "antraciet3" if u % 8 == 0 else 0)
            b.put(face, u, z, 1, "glas_brons")
    b.interior(face, 0, S, 8, 22, 2, 1100, office=True)
    b.rect(face, 0, S, 22, 24, -1, 1, "bruin80_1")


def k2000_zonwering(b, face):
    f_kantoor_vlies(b, face)
    for z in (8, 15, 21):
        for u in range(S):
            for d in range(-4, 0):
                b.put(face, u, z, d, "alu")


def kmodern_lamellen(b, face):
    for z in range(0, 24):
        for u in range(S):
            b.put(face, u, z, 0, 0)
            b.put(face, u, z, 1, b.st["glas"])
    b.interior(face, 0, S, 1, 23, 2, 1200, office=True)
    for u in range(0, S, 3):
        for z in range(0, 24):
            for d in range(-4, 0):
                b.put(face, u, z, d, b.st["accent"] if u % 6 == 0 else "stuc1")
    b.rect(face, 0, S, 23, 24, -4, 1, "stuc1")


def kantoor_klein(b, face):
    for u0 in (2, 10, 18, 26):
        b.window(face, u0, 8, 4, 10, sill=False, lintel=False)


def kantoor_groot(b, face):
    app_verd_groot(b, face)


# ------------------------------------------------------------------ musea

def column(b, face, uc, d, z0, z1, r=1.6, c=None):
    c = c or b.st["sier"]
    for z in range(z0, z1):
        rr = r + (0.9 if (z < z0 + 2 or z > z1 - 3) else 0)
        for u in range(int(uc - rr - 1), int(uc + rr + 2)):
            for dd in range(int(d - rr - 1), int(d + rr + 2)):
                if math.hypot(u + 0.5 - uc, dd + 0.5 - d) <= rr:
                    b.put(face, u, z, dd, c)


def mk_bg_zuilen(b, face):
    b.rect(face, 0, S, 0, 24, -7, 0, 0)
    b.rect(face, 0, S, 0, 2, -8, 0, b.st["plint"])
    for uc in (4, 12, 20, 28):
        column(b, face, uc, -5, 2, 22)
    b.rect(face, 0, S, 22, 24, -8, 0, b.st["sier"])
    b.door(face, 11, 10, 2, 18, transom=True)


def mk_bg_raam_boog(b, face):
    b.plinth(face, 3)
    lancet(b, face, 9, 14, 5, 14, 21, kind="rond", glass="glas1", frame=b.st["sier"])


def mk_verd_raam_boog(b, face):
    lancet(b, face, 9, 14, 3, 13, 20, kind="rond", glass="glas1", frame=b.st["sier"])
    pilasters(b, face)


def mk_verd_relief(b, face):
    pilasters(b, face)
    for z in range(6, 18):
        for u in range(6, 26):
            edge = z in (6, 17) or u in (6, 25)
            if edge or (u + z) % 4 == 0:
                b.put(face, u, z, -1, b.st["sier"])


def mk_fronton(style):
    def fn():
        b = Bld(style, "fronton", 24)
        st = b.st
        b.m.box(O, O, 0, O + S, O + S, 3, st["wall"])
        for u in range(S):
            for d in (-2, -1, 0):
                b.put("v", u, 0, d, st["sier"])
        for z in range(3, 16):
            half = 16 - int((z - 3) * 1.25)
            for u in range(16 - half, 16 + half):
                edge = u in (16 - half, 16 + half - 1) or z == 3
                b.put("v", u, z, -1, st["sier"] if edge else st["wall"])
                for d in range(0, S):
                    b.put("v", u, z, d, roof_colors(b, z, u, d) if d > 0 and (z == 3 + int((16 - abs(u + 0.5 - 16)) * 0.8)) else st["wall"]) if False else None
        # zadeldak achter het fronton
        for ly in range(1, S):
            for lx in range(S):
                hh = 2 * min(lx + 0.5, S - lx - 0.5) * 0.4 + 3
                for z in range(3, int(hh)):
                    b.m.set(O + lx, O + ly, z, roof_colors(b, z * 2, lx, ly) if z >= int(hh) - 2 else st["wall"])
        return b.m
    return fn


def dome(style, big=False):
    def fn():
        b = Bld(style, "koepel" + str(big), 48)
        if big:
            size = 112
            m = V(size, size, 72)
            c = size / 2
            R = 40
            drum = 12
        else:
            m = b.m
            c = W / 2
            R = 13
            drum = 6
        for z in range(drum):
            for y in range(m.sy):
                for x in range(m.sx):
                    d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                    if d <= R + 2:
                        ang = math.atan2(y - c, x - c)
                        win = d > R + 1 and 3 < z < drum - 2 and int((ang + 4) * R / 6) % 2 == 0
                        m.set(x, y, z, "glas1" if win else b.st["sier"])
        Rz = R * 0.85
        for z in range(drum, int(drum + Rz) + 1):
            for y in range(m.sy):
                for x in range(m.sx):
                    d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                    zz = (z - drum) / Rz
                    if d <= R * math.sqrt(max(0.0, 1 - zz * zz)):
                        ang = math.atan2(y - c, x - c)
                        rib = int((ang + 4) * 8 / math.pi) % 4 == 0
                        m.set(x, y, z, "zink1" if rib else "koper")
        top = int(drum + Rz)
        lr = max(2, R // 6)
        for z in range(top, top + lr * 2):
            for y in range(m.sy):
                for x in range(m.sx):
                    if math.hypot(x + 0.5 - c, y + 0.5 - c) <= lr:
                        m.set(x, y, z, "glas1" if (z - top) % 3 else b.st["sier"])
        for z in range(top + lr * 2, top + lr * 2 + 4):
            m.set(int(c), int(c), z, "goud")
        return m
    return fn


def mm_bg_entree(b, face):
    b.rect(face, 0, S, 0, 24, 0, 3, 0)
    for z in range(0, 24):
        for u in range(S):
            edge = u % 8 == 0 or z in (0, 23)
            b.put(face, u, z, 1, "antraciet1" if edge else "glas_helder")
    b.rect(face, 0, S, 0, 23, 3, 4, "stuc2")
    b.sign(face, 4, 28, 18, 23, "stuc1", "MUSEUM", "antraciet1")


def mm_verd_lichtstrook(b, face):
    b.window(face, 0, 9, 32, 4, sill=False, lintel=False)


def mm_verd_dicht(b, face):
    for z in range(0, 24):
        for u in range(S):
            if (u + z) % 12 == 0:
                b.put(face, u, z, -1, "stuc3")


def mm_dak_overstek(style):
    def fn():
        b = Bld(style, "overstek", 8)
        b.m.box(O, O - 8, 0, O + S, O + S, 3, "stuc1")
        b.m.box(O, O - 8, 0, O + S, O - 7, 3, "antraciet1")
        for x in range(O + 2, O + S, 6):
            b.m.set(x, O - 4, 0, "lamp_wit")
        return b.m
    return fn


# ------------------------------------------------------------------ kerken

def kerk_bg_portaal(b, face):
    b.plinth(face, 2)
    for k in range(3):
        lancet(b, face, 9 - k * 2, 14 + k * 4, 0, 14, 23, d0=-k + 0, glass="hout_donker2", frame=b.st["sier"])
    b.rect(face, 10, 22, 0, 14, 0, 2, 0)
    b.rect(face, 10, 22, 0, 14, 2, 3, "hout_donker2")
    for z in range(0, 14):
        b.put(face, 16, z, 2, "metaal_donker")
    b.put(face, 14, 7, 1, "metaal_donker")
    b.put(face, 17, 7, 1, "metaal_donker")


def kerk_bg_spitsraam(b, face):
    b.plinth(face, 2)
    lancet(b, face, 10, 12, 6, 24, 24)


def kerk_verd_spitsraam(b, face):
    lancet(b, face, 10, 12, 0, 6, 20)


def kerk_verd_roos(b, face):
    cu, cz, r = 16, 12, 10.5
    for z in range(0, 24):
        for u in range(S):
            d = math.hypot(u + 0.5 - cu, z + 0.5 - cz)
            if d <= r:
                b.put(face, u, z, 0, 0)
                b.put(face, u, z, 1, 0)
                ang = math.atan2(z - cz, u - cu)
                spoke = int((ang + 4) * 12 / math.pi) % 3 == 0 or abs(d - r * 0.45) < 0.6 or d < 1.5
                c = b.st["sier"] if spoke else pick(["glas_lood_blauw", "glas_lood_rood", "glas_lood_geel"], int(d), int((ang + 4) * 4), b.seed, 237)
                b.put(face, u, z, 2, c)
                b.put(face, u, z, 3, "licht_warm")
            elif d <= r + 1.5:
                b.put(face, u, z, 0, b.st["sier"])
                b.put(face, u, z, -1, b.st["sier"])


def kerk_steunbeer(b, face):
    for z in range(0, 24):
        depth = 6 - z // 5
        for d in range(-depth, 0):
            for u in (0, 1, 2):
                b.put(face, u, z, d, b.st["wall"])
        b.put(face, 0, z, -depth, b.st["sier"]) if z % 5 == 4 else None
    lancet(b, face, 12, 10, 4, 14, 22)


def kerk_toren_portaal(b, face):
    if face == "v":
        kerk_bg_portaal(b, face)
    else:
        lancet(b, face, 13, 6, 6, 14, 20)


def kerk_toren_raam(b, face):
    lancet(b, face, 13, 6, 4, 13, 20)
    b.rect(face, 0, S, 22, 23, -1, 1, b.st["sier"])


def kerk_toren_klok(b, face):
    clock(b, face, 16, 12, 8.0)
    b.rect(face, 0, S, 22, 23, -1, 1, b.st["sier"])


def kerk_toren_galmgat(b, face):
    for u0 in (6, 18):
        lancet(b, face, u0, 7, 3, 12, 20, glass="metaal_donker")
        for z in range(4, 18, 2):
            b.rect(face, u0, u0 + 7, z, z + 1, 1, 2, "hout_donker2")
    b.rect(face, 0, S, 22, 24, -1, 1, b.st["sier"])


def toren_spits(style, part):
    def fn():
        b = Bld(style, "spits" + part, 48)
        m = b.m
        c = W / 2
        z0 = 0 if part == "onder" else 24
        for z in range(0, 48):
            Z = z + z0
            hs = 16 - Z * 0.36
            if hs <= 0.5:
                break
            for y in range(W):
                for x in range(W):
                    dx, dy = abs(x + 0.5 - c), abs(y + 0.5 - c)
                    if max(dx, dy) <= hs and dx + dy <= hs * 1.35:
                        m.set(x, y, z, roof_colors(b, Z, x, y) if (max(dx, dy) > hs - 1.5 or dx + dy > hs * 1.35 - 1.5) else b.st["wall"])
        if part == "onder":
            for (px, py) in ((O + 1, O + 1), (O + S - 3, O + 1), (O + 1, O + S - 3), (O + S - 3, O + S - 3)):
                for z in range(0, 10):
                    r = 1.5 - z * 0.12
                    m.cyl(px + 1, py + 1, max(0.6, r), z, z + 1, b.st["sier"])
            for face in "vral":
                b.rect(face, 0, S, 0, 2, -1, 1, b.st["sier"])
        else:
            top = int(16 / 0.36) - z0
            for z in range(top - 2, top + 8):
                m.set(int(c), int(c), z, "goud")
            for x in range(int(c) - 2, int(c) + 3):
                m.set(x, int(c), top + 5, "goud")
            m.set(int(c) + 1, int(c), top + 8, "goud")
            m.set(int(c), int(c), top + 8, "goud")
        return m
    return fn


def toren_pinakels(style):
    def fn():
        b = Bld(style, "pinakels", 40)
        m = b.m
        b.m.box(O, O, 0, O + S, O + S, 2, b.st["sier"])
        for face in "vral":
            for u in range(0, S, 4):
                for z in range(2, 6):
                    b.put(face, u, z, 0, b.st["sier"])
        for (px, py) in ((O + 2, O + 2), (O + S - 2, O + 2), (O + 2, O + S - 2), (O + S - 2, O + S - 2)):
            for z in range(0, 30):
                r = 2.4 - z * 0.075
                m.cyl(px, py, max(0.5, r), z, z + 1, b.st["sier"] if z < 26 else "goud")
        return m
    return fn


def luchtboog(style):
    def fn():
        b = Bld(style, "luchtboog")
        m = b.m
        st = b.st
        # steunpilaar aan de voorkant, boog naar achteren (tegen het schip)
        for z in range(0, 24):
            for ly in range(0, 6):
                for lx in range(13, 19):
                    m.set(O + lx, O + ly, z, st["wall"])
        for z in range(24, 30):
            m.cyl(O + 16, O + 3, 2.2 - (z - 24) * 0.3, z, z + 1, st["sier"])
        for t in range(0, 40):
            ly = 5 + t * 26 / 40.0
            z = 22 - 12 * (1 - ((ly - 5) / 26.0 - 1) ** 2) * 0 - (ly - 5) * 0.0 + 0
            z = 14 + 8 * math.sin((ly - 5) / 26.0 * math.pi / 2)
            for lx in range(14, 18):
                for dz in range(0, 3):
                    m.set(O + lx, O + int(ly), int(z) + dz, st["sier"])
        return m
    return fn


def km_bg_entree(b, face):
    b.plinth(face, 1)
    b.window(face, 6, 0, 20, 17, sill=False, lintel=False)
    b.rect(face, 12, 20, 0, 16, 1, 3, "hout2")
    b.rect(face, 2, 30, 17, 19, -7, 0, "beton60")


def km_verd_spleet(b, face):
    for u0 in (4, 10, 21, 27):
        b.window(face, u0, 0, 2, 24, sill=False, lintel=False, frame="beton60")


def km_verd_kruis(b, face):
    for z in range(3, 22):
        b.put(face, 15, z, -1, "beton60")
        b.put(face, 16, z, -1, "beton60")
    for u in range(10, 22):
        b.put(face, u, 15, -1, "beton60")
        b.put(face, u, 16, -1, "beton60")


def km_toren(style, klok):
    def fn():
        b = Bld(style, "kloktoren" + str(klok), 32 if klok else 24)
        m = b.m
        for z in range(0, 24):
            for (lx, ly) in ((10, 10), (20, 10), (10, 20), (20, 20)):
                m.box(O + lx, O + ly, z, O + lx + 2, O + ly + 2, z + 1, "beton60")
        for z in (0, 12, 23):
            for lx in range(10, 22):
                for ly in (10, 21):
                    m.set(O + lx, O + ly, z, "beton60")
                    m.set(O + ly, O + lx, z, "beton60")
        if klok:
            for z in range(14, 21):
                r = 1.5 + (21 - z) * 0.35
                m.cyl(O + 16, O + 16, r, z, z + 1, "messing")
            for z in range(24, 32):
                m.set(O + 16, O + 16, z, "metaal_donker")
            for lx in range(13, 20):
                m.set(O + lx, O + 16, 29, "metaal_donker")
        return m
    return fn


# ------------------------------------------------------------------ school / overheid / schuur

def school_bg_entree(b, face):
    b.plinth(face, 2)
    b.window(face, 8, 0, 16, 18, sill=False, lintel=False)
    b.rect(face, 11, 21, 0, 17, 1, 3, "glas_helder")
    for z in range(0, 17):
        b.put(face, 16, z, 1, b.st["kozijn"])
    b.rect(face, 4, 28, 18, 19, -6, 0, "beton60")
    b.sign(face, 6, 26, 19, 24, "paneel_groen", "SCHOOL", "bord_wit")


def school_raam(b, face, z0=4, hh=16):
    b.window(face, 2, z0, 28, hh, sill=True, lintel=False, sill_c="beton60")
    for z in range(z0, z0 + hh):
        for u in range(2, 30):
            if (u - 2) % 4 == 0 or (z - z0) % 4 == 0:
                b.put(face, u, z, 1, b.st["kozijn"])


def school_bg_raam(b, face):
    b.plinth(face, 2)
    school_raam(b, face)


def school_verd_raam(b, face):
    school_raam(b, face, 3, 18)


def overheid_bg_entree(b, face):
    b.rect(face, 0, S, 0, 24, -7, 0, 0)
    for i in range(3):
        b.rect(face, 4, 28, 0, 3 - i, -7 + i * 2, 0, b.st["sier"])
    for uc in (5, 13, 19, 27):
        column(b, face, uc, -5, 3, 21, 1.4)
    b.rect(face, 0, S, 21, 24, -8, 0, b.st["sier"])
    b.door(face, 11, 10, 3, 17, transom=True)
    b.sign(face, 6, 26, 21, 24, "natuursteen1", "RAADHUIS", "goud") if False else None
    px, (tw, th) = text_pixels("RAADHUIS")
    for (c, r) in px:
        b.put(face, 16 - tw // 2 + c, 21 + 4 - r - 1 + 1, -9, "goud") if False else None


def overheid_verd_raam_hoog(b, face):
    for u0 in (3, 13, 23):
        b.window(face, u0, 3, 6, 19, roedes=True)


def overheid_verd_balkon(b, face):
    overheid_verd_raam_hoog(b, face)
    b.rect(face, 10, 22, 0, 2, -4, 0, b.st["sier"])
    for u in range(10, 22):
        b.put(face, u, 7, -4, b.st["sier"])
        if u % 2 == 0:
            for z in range(2, 7):
                b.put(face, u, z, -4, b.st["sier"])


def overheid_naam(style):
    def fn():
        b = Bld(style, "naambord", 8)
        b.m.box(O, O, 0, O + S, O + S, 1, "zink1")
        for u in range(S):
            for z in range(0, 7):
                b.put("v", u, z, 0, b.st["sier"])
        px, (tw, th) = text_pixels("RAADHUIS")
        for (c, r) in px:
            b.put("v", 16 - tw // 2 + c, 5 - r, -1, "goud")
        return b.m
    return fn


def schuur_bg_deur(b, face):
    b.rect(face, 6, 26, 0, 20, 0, 2, 0)
    for z in range(0, 20):
        for u in range(6, 26):
            edge = u in (6, 15, 16, 25) or z == 19
            diag = (u - 6) % 10 == z % 10 or (u - 6) % 10 == 9 - z % 10
            b.put(face, u, z, 1, b.st["sier"] if (edge or diag) else b.st["deuren"][0])
    b.rect(face, 0, S, 0, 1, 0, 1, b.st["plint"])


def schuur_bg_raam(b, face):
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plint"])
    b.window(face, 6, 8, 6, 6, roedes=True, sill=False, lintel=False)
    b.window(face, 20, 8, 6, 6, roedes=True, sill=False, lintel=False)


def schuur_hooi(b, face):
    b.rect(face, 12, 20, 6, 18, 0, 2, 0)
    b.rect(face, 12, 20, 6, 18, 1, 2, b.st["deuren"][0])
    for z in range(6, 18):
        b.put(face, 12, z, 1, b.st["sier"])
        b.put(face, 19, z, 1, b.st["sier"])
    for d in range(-5, 0):
        b.put(face, 16, 20, d, "hout_donker2")


# ------------------------------------------------------------------ holle hallen en overkappingen

HAL_STYLES = {
    "hal_glas": dict(frame="metaal3", wall="glas_helder", sokkel="antraciet1", dak="glas_helder", balk="metaal3"),
    "hal_zwembad": dict(frame="stuc1", wall="glas1", sokkel="tegel_wit", dak="paneel3", balk="stuc1"),
    "hal_sport": dict(frame="baksteen2", wall="glas2", sokkel="baksteen4", dak="zink1", balk="metaal2"),
}


def hal(stylename, walls="v", roof=True, door=False, columns=()):
    hs = HAL_STYLES[stylename]

    def fn():
        m = V(W, W, HGT)
        b = Bld("modern_wit", stylename + walls + str(roof) + str(door) + str(columns), HGT)
        b.m = m
        for face in walls:
            for u in range(S):
                for z in range(0, 24):
                    if z < 3:
                        c = hs["sokkel"]
                    elif u % 8 == 0 or u == S - 1 or z in (3, 12, 23):
                        c = hs["frame"]
                    else:
                        c = hs["wall"]
                    b.put(face, u, z, 0, c)
                    if u % 8 == 0 or u == S - 1:
                        b.put(face, u, z, 1, hs["frame"])
            if door and face == "v":
                b.rect("v", 10, 22, 0, 18, 0, 1, "glas_helder")
                for z in range(0, 18):
                    b.put("v", 10, z, 0, hs["frame"])
                    b.put("v", 21, z, 0, hs["frame"])
                    b.put("v", 16, z, 0, hs["frame"])
                for u in range(10, 22):
                    b.put("v", u, 18, 0, hs["frame"])
        if roof:
            for ly in range(S):
                for lx in range(S):
                    beam = lx % 8 == 0 or ly % 16 == 0
                    m.set(O + lx, O + ly, 23, hs["balk"] if beam else hs["dak"])
                    if beam and (lx % 8 == 0):
                        m.set(O + lx, O + ly, 22, hs["balk"])
            for lx in range(4, S, 8):
                m.set(O + lx, O + 16, 21, "lamp_wit")
        for (cu, cd) in columns:
            for z in range(0, 24):
                m.box(O + cu, O + cd, z, O + cu + 2, O + cd + 2, z + 1, hs["frame"])
        return m
    return fn


def overkapping(kolom):
    def fn():
        m = V(W, W, HGT)
        for ly in range(S):
            for lx in range(S):
                beam = lx in (0, 31) or ly in (0, 31) or ly % 8 == 0
                m.set(O + lx, O + ly, 22, "metaal3" if beam else "glas_helder")
            m.set(O + 0, O + ly, 21, "metaal3")
            m.set(O + 31, O + ly, 21, "metaal3")
        if kolom:
            for z in range(0, 22):
                m.box(O, O, z, O + 2, O + 2, z + 1, "metaal3")
        return m
    return fn


# ------------------------------------------------------------------ pilaren

def pilaar(kind):
    def fn():
        m = V(W, W, HGT)
        c = W / 2
        for z in range(HGT):
            if kind == "klassiek":
                base = z < 2 or z > 21
                if base:
                    m.box(int(c - 3), int(c - 3), z, int(c + 3), int(c + 3), z + 1, "natuursteen1")
                else:
                    r = 2.2 - (z - 2) * 0.012
                    for y in range(W):
                        for x in range(W):
                            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                            if d <= r:
                                ang = math.atan2(y - c, x - c)
                                flute = int((ang + 4) * 8 / math.pi) % 2 == 0 and d > r - 0.8
                                m.set(x, y, z, "natuursteen2" if flute else "natuursteen1")
            elif kind == "beton":
                m.box(int(c - 2), int(c - 2), z, int(c + 2), int(c + 2), z + 1, "beton1" if z % 12 else "beton_donker")
            elif kind == "baksteen":
                m.box(int(c - 3), int(c - 3), z, int(c + 3), int(c + 3), z + 1,
                      lambda x, y, zz: pick(["baksteen1", "baksteen2", "baksteen3"], (x + y + (zz % 2) * 2) // 3, zz, 0, 240))
                if z == HGT - 1:
                    m.box(int(c - 4), int(c - 4), z, int(c + 4), int(c + 4), z + 1, "natuursteen2")
            elif kind == "staal":
                m.box(int(c - 1), int(c - 2), z, int(c + 1), int(c + 2), z + 1, "metaal3")
                m.box(int(c - 2), int(c - 2), z, int(c + 2), int(c - 1), z + 1, "metaal3")
                m.box(int(c - 2), int(c + 1), z, int(c + 2), int(c + 2), z + 1, "metaal3")
        return m
    return fn


def zuilengang(kind):
    def fn():
        b = Bld("klassiek_rood" if kind == "klassiek" else "kantoor_beton", "zuilengang" + kind, HGT)
        m = b.m
        mat = "natuursteen1" if kind == "klassiek" else "beton1"
        for ly in range(S):
            for lx in range(S):
                for z in (21, 22, 23):
                    m.set(O + lx, O + ly, z, mat)
        for (lx, ly) in ((4, 4), (28, 4)):
            if kind == "klassiek":
                for z in range(0, 21):
                    m.cyl(O + lx, O + ly, 1.8 if 1 < z < 19 else 2.6, z, z + 1, mat)
            else:
                m.box(O + lx - 2, O + ly - 2, 0, O + lx + 2, O + ly + 2, 21, mat)
        if kind == "klassiek":
            for lx in range(4, 29):
                dx = lx + 0.5 - 16
                z = int(20 - max(0, 1 - (dx / 12.0) ** 2) * 5)
                for zz in range(z, 21):
                    m.set(O + lx, O + 3, zz, mat)
                    m.set(O + lx, O + 4, zz, mat)
        return m
    return fn


# ------------------------------------------------------------------ registratie

def reg_style(style, pieces, corners, roofs):
    base = f"gebouwen/{style}/{style}_"
    for name, f in pieces.items():
        register(base + name, make_block(style, [("v", f)]))
    for name, a, c in corners:
        register(base + name, make_block(style, [("v", pieces[a]), ("r", pieces[c])]))
    register(base + "blok_dicht", make_block(style, []))
    for name, fn in roofs.items():
        register(base + name, fn)


def flat_roofs(style, extras=True):
    r = {
        "dak_plat_midden": flat_roof(style, ""), "dak_plat_rand": flat_roof(style, "v"), "dak_plat_hoek": flat_roof(style, "vr"),
        "dak_plat_tegenover": flat_roof(style, "va"), "dak_plat_eind": flat_roof(style, "var"),
    }
    return r


def pitched_roofs(style):
    return {
        "dak_schuin": pitched(style, style + "s", H_SCHUIN),
        "dak_schuin_hoek_buiten": pitched(style, style + "hb", H_HOEK_BUITEN),
        "dak_schuin_hoek_binnen": pitched(style, style + "hi", H_HOEK_BINNEN),
        "dak_schuin_dakkapel": pitched(style, style + "dk", H_SCHUIN, x_dakkapel),
        "dak_schuin_schoorsteen": pitched(style, style + "sc", H_SCHUIN, x_schoorsteen),
        "dak_zadel": pitched(style, style + "z", H_ZADEL),
        "dak_zadel_schild": pitched(style, style + "zs", H_ZADEL_SCHILD),
        "dak_zadel_hoek": pitched(style, style + "zh", H_ZADEL_HOEK),
    }


def with_shops(pieces):
    p = dict(pieces)
    p.update(SHOP_PIECES)
    return p


# jaren 30
_p = with_shops({"bg_portiek": j30_bg_portiek, "bg_raam": j30_bg_raam, "bg_winkel": f_bg_winkel, "bg_winkel_luifel": f_bg_winkel_luifel,
                 "verd_raam": j30_verd_raam, "verd_erker": j30_verd_erker, "verd_balkon": j30_verd_balkon,
                 "verd_trappenhuis": j30_verd_trappenhuis})
_r = pitched_roofs("jaren30")
_r.update(flat_roofs("jaren30"))
reg_style("jaren30", _p, [("bg_raam_hoek", "bg_raam", "bg_raam"), ("verd_raam_hoek", "verd_raam", "verd_raam"),
                          ("verd_erker_hoek", "verd_erker", "verd_raam"), ("bg_winkel_hoek", "bg_winkel", "bg_raam"),
                          ("bg_cafe_hoek", "bg_cafe", "bg_raam")], _r)

# jaren 60
_p = {"bg_deur": j60_bg_deur, "bg_raam": j60_bg_raam, "bg_berging": j60_bg_berging, "verd_raam": j60_verd_raam,
      "verd_raam_klein": j60_verd_raam_klein, "verd_galerij_deur": j60_galerij_deur, "verd_galerij_raam": j60_galerij_raam,
      "verd_balkon": j60_verd_balkon, "verd_dicht": lambda b, f: None}
_r = pitched_roofs("jaren60")
_r.update(flat_roofs("jaren60"))
reg_style("jaren60", _p, [("bg_raam_hoek", "bg_raam", "verd_dicht"), ("bg_deur_hoek", "bg_deur", "verd_dicht"),
                          ("verd_raam_hoek", "verd_raam", "verd_dicht"), ("verd_raam_klein_hoek", "verd_raam_klein", "verd_dicht"),
                          ("verd_galerij_deur_hoek", "verd_galerij_deur", "verd_dicht"), ("verd_galerij_raam_hoek", "verd_galerij_raam", "verd_dicht")], _r)

# galerijflat
_p = {"bg_entree": flat_bg_entree, "bg_bergingen": flat_bg_bergingen, "verd_galerij": flat_galerij, "verd_balkons": flat_balkons,
      "verd_trappenhuis": flat_trappenhuis, "verd_kopgevel": flat_kopgevel}
_r = flat_roofs("galerijflat")
_r["dak_liftopbouw"] = flat_roof("galerijflat", "", lambda b: b.m.box(O + 8, O + 8, 1, O + 24, O + 24, 14, wall_flat60))
reg_style("galerijflat", _p, [("verd_galerij_hoek", "verd_galerij", "verd_kopgevel"), ("verd_balkons_hoek", "verd_balkons", "verd_kopgevel"),
                              ("bg_bergingen_hoek", "bg_bergingen", "verd_kopgevel"), ("bg_entree_hoek", "bg_entree", "verd_kopgevel")], _r)

# modern appartement
_p = {"bg_entree": app_bg_entree, "bg_glas": f_kantoor_bg_glas, "verd_glas": app_verd_glas, "verd_loggia": app_verd_loggia,
      "verd_balkon": lambda b, f: b.balcony_modern(f), "verd_paneel": app_verd_paneel, "verd_raam_groot": app_verd_groot,
      "verd_raam_klein": app_verd_klein}
_r = flat_roofs("appartement_modern")
_r["dak_daktuin"] = flat_roof("appartement_modern", "v", x_dakterras_plat)
reg_style("appartement_modern", _p, [("verd_glas_hoek", "verd_glas", "verd_glas"), ("verd_balkon_hoek", "verd_balkon", "verd_glas"),
                                     ("bg_glas_hoek", "bg_glas", "bg_glas"), ("verd_raam_groot_hoek", "verd_raam_groot", "verd_raam_groot"),
                                     ("verd_raam_klein_hoek", "verd_raam_klein", "verd_raam_klein"), ("verd_loggia_hoek", "verd_loggia", "verd_paneel")], _r)

# herenhuizen
_p = {"bg_deur": h1600_bg_deur, "bg_raam": h1600_bg_raam, "verd_raam": h1600_verd_raam, "verd_balkon": h1600_verd_balkon}
_r = pitched_roofs("herenhuis_1600")
_r.update({"top_lijstgevel": top_lijstgevel("herenhuis_1600", False), "top_lijstgevel_fronton": top_lijstgevel("herenhuis_1600", True),
           "gevel_klok": gable_top("herenhuis_1600", "klok"), "gevel_hals": gable_top("herenhuis_1600", "hals"),
           "dak_plat_midden": flat_roof("herenhuis_1600", "")})
reg_style("herenhuis_1600", _p, [("bg_raam_hoek", "bg_raam", "bg_raam"), ("verd_raam_hoek", "verd_raam", "verd_raam")], _r)

_p = with_shops({"bg_deur": h1900_bg_deur, "bg_raam_boog": h1900_bg_raam_boog, "verd_raam_boog": h1900_verd_raam_boog,
                 "verd_erker": h1900_verd_erker, "verd_balkon": h1600_verd_balkon})
_r = pitched_roofs("herenhuis_1900")
_r.update({"dak_mansarde_rand": mansarde("herenhuis_1900", "v"), "dak_mansarde_hoek": mansarde("herenhuis_1900", "vr"),
           "dak_mansarde_tegenover": mansarde("herenhuis_1900", "va"), "gevel_tuit": gable_top("herenhuis_1900", "tuit"),
           "dak_plat_midden": flat_roof("herenhuis_1900", "")})
reg_style("herenhuis_1900", _p, [("bg_raam_boog_hoek", "bg_raam_boog", "bg_raam_boog"), ("verd_raam_boog_hoek", "verd_raam_boog", "verd_raam_boog"),
                                 ("verd_erker_hoek", "verd_erker", "verd_raam_boog")], _r)

# kantoren
for _st, _extra in (("kantoor_80", {"verd_spiegelband": k80_spiegelband}),
                    ("kantoor_2000", {"verd_zonwering": k2000_zonwering}),
                    ("kantoor_modern", {"verd_lamellen": kmodern_lamellen})):
    _p = {"bg_entree": f_kantoor_bg_entree, "bg_glas": f_kantoor_bg_glas, "verd_vliesgevel": f_kantoor_vlies,
          "verd_band": f_kantoor_band, "verd_raam_groot": kantoor_groot, "verd_raam_klein": kantoor_klein}
    _p.update(_extra)
    _k = list(_extra)[0]
    _r = flat_roofs(_st)
    _r["dak_installatie"] = flat_roof(_st, "", x_installatie)
    _r["dak_installatie_rand"] = flat_roof(_st, "v", x_installatie)
    _r["dak_kroon_rand"] = flat_roof(_st, "v", lambda b: [b.rect("v", u, u + 1, 0, 16, -1, 0, b.st["kozijn"]) for u in range(0, S, 4)])
    reg_style(_st, _p, [("bg_glas_hoek", "bg_glas", "bg_glas"), ("bg_entree_hoek", "bg_entree", "bg_glas"),
                        ("verd_vliesgevel_hoek", "verd_vliesgevel", "verd_vliesgevel"), ("verd_band_hoek", "verd_band", "verd_band"),
                        (_k + "_hoek", _k, _k), ("verd_raam_groot_hoek", "verd_raam_groot", "verd_raam_groot"),
                        ("verd_raam_klein_hoek", "verd_raam_klein", "verd_raam_klein")], _r)

# musea
_p = {"bg_zuilen": mk_bg_zuilen, "bg_raam_boog": mk_bg_raam_boog, "verd_raam_boog": mk_verd_raam_boog, "verd_relief": mk_verd_relief}
_r = {"top_fronton": mk_fronton("museum_klassiek"), "dak_koepel": dome("museum_klassiek"), "dak_koepel_3x3": dome("museum_klassiek", True),
      "dak_kroonlijst_rand": flat_roof("museum_klassiek", "v", kroonlijst=True), "dak_kroonlijst_hoek": flat_roof("museum_klassiek", "vr", kroonlijst=True),
      "dak_plat_midden": flat_roof("museum_klassiek", "")}
reg_style("museum_klassiek", _p, [("bg_raam_boog_hoek", "bg_raam_boog", "bg_raam_boog"), ("verd_raam_boog_hoek", "verd_raam_boog", "verd_raam_boog"),
                                  ("verd_relief_hoek", "verd_relief", "verd_relief")], _r)

_p = {"bg_entree": mm_bg_entree, "bg_dicht": mm_verd_dicht, "verd_lichtstrook": mm_verd_lichtstrook, "verd_dicht": mm_verd_dicht}
_r = flat_roofs("museum_modern")
_r["dak_overstek"] = mm_dak_overstek("museum_modern")
reg_style("museum_modern", _p, [("verd_lichtstrook_hoek", "verd_lichtstrook", "verd_lichtstrook"), ("verd_dicht_hoek", "verd_dicht", "verd_dicht"),
                                ("bg_entree_hoek", "bg_entree", "bg_dicht")], _r)

# kerken
for _st in ("kerk_baksteen", "kerk_steen"):
    _p = {"bg_portaal": kerk_bg_portaal, "bg_spitsraam": kerk_bg_spitsraam, "verd_spitsraam": kerk_verd_spitsraam,
          "verd_roosvenster": kerk_verd_roos, "verd_steunbeer": kerk_steunbeer, "verd_dicht": lambda b, f: None}
    _r = pitched_roofs(_st)
    _r["dak_plat_midden"] = flat_roof(_st, "")
    _r.update({"gevel_spits": gable_top(_st, "tuit"),
               "toren_portaal": make_block(_st, [(f, kerk_toren_portaal) for f in "vral"]),
               "toren_raam": make_block(_st, [(f, kerk_toren_raam) for f in "vral"]),
               "toren_klok": make_block(_st, [(f, kerk_toren_klok) for f in "vral"]),
               "toren_galmgat": make_block(_st, [(f, kerk_toren_galmgat) for f in "vral"]),
               "toren_spits_onder": toren_spits(_st, "onder"), "toren_spits_boven": toren_spits(_st, "boven"),
               "toren_pinakels": toren_pinakels(_st), "luchtboog": luchtboog(_st)})
    reg_style(_st, _p, [("verd_spitsraam_hoek", "verd_spitsraam", "verd_spitsraam"), ("bg_spitsraam_hoek", "bg_spitsraam", "bg_spitsraam")], _r)

_p = {"bg_entree": km_bg_entree, "bg_dicht": lambda b, f: b.plinth(f, 1), "verd_spleet": km_verd_spleet, "verd_kruis": km_verd_kruis}
_r = flat_roofs("kerk_modern")
_r.update({"dak_lessenaar": pitched("kerk_modern", "lessenaar", lambda px, py: py * 0.5),
           "toren_beton": km_toren("kerk_modern", False), "toren_beton_klok": km_toren("kerk_modern", True)})
reg_style("kerk_modern", _p, [("verd_spleet_hoek", "verd_spleet", "verd_spleet"), ("bg_entree_hoek", "bg_entree", "bg_dicht")], _r)

# school
_p = {"bg_entree": school_bg_entree, "bg_raam": school_bg_raam, "verd_raam": school_verd_raam}
_r = flat_roofs("school")
_r["dak_zonnepanelen"] = flat_roof("school", "", x_zonnepanelen)
reg_style("school", _p, [("bg_raam_hoek", "bg_raam", "bg_raam"), ("verd_raam_hoek", "verd_raam", "verd_raam"), ("bg_entree_hoek", "bg_entree", "bg_raam")], _r)

# overheid
_p = {"bg_entree": overheid_bg_entree, "bg_raam": lambda b, f: (b.plinth(f, 3), overheid_verd_raam_hoog(b, f)),
      "verd_raam_hoog": overheid_verd_raam_hoog, "verd_balkon": overheid_verd_balkon}
_r = pitched_roofs("overheid")
_r.update({"top_fronton": mk_fronton("overheid"), "top_naambord": overheid_naam("overheid"),
           "toren_klok": make_block("overheid", [(f, kerk_toren_klok) for f in "vral"]),
           "toren_spits_onder": toren_spits("overheid", "onder"), "toren_spits_boven": toren_spits("overheid", "boven"),
           "dak_plat_midden": flat_roof("overheid", "")})
reg_style("overheid", _p, [("bg_raam_hoek", "bg_raam", "bg_raam"), ("verd_raam_hoog_hoek", "verd_raam_hoog", "verd_raam_hoog")], _r)

# schuren
for _st in ("schuur_zwart", "schuur_rood"):
    _p = {"bg_deur_groot": schuur_bg_deur, "bg_raam": schuur_bg_raam, "verd_hooideur": schuur_hooi, "bg_dicht": lambda b, f: b.plinth(f, 1)}
    _r = pitched_roofs(_st)
    reg_style(_st, _p, [("bg_raam_hoek", "bg_raam", "bg_raam"), ("bg_deur_groot_hoek", "bg_deur_groot", "bg_raam")], _r)

# klassieke stijlen krijgen ook horeca/winkeltypes
for _st in ("klassiek_rood", "klassiek_donker", "klassiek_geel", "modern_wit", "modern_donker", "modern_hout"):
    for _n, _f in SHOP_PIECES.items():
        register(f"gebouwen/{_st}/{_st}_{_n}", make_block(_st, [("v", _f)]))

# extra daksoorten (bitumen / grind) voor de oorspronkelijke platte-dak stijlen
for _st in ("modern_wit", "modern_donker", "modern_hout", "kantoor_glas", "kantoor_beton", "jaren60", "galerijflat",
            "appartement_modern", "kantoor_80", "kantoor_2000", "kantoor_modern", "school", "jaren30"):
    for _soort, _vloer in (("bitumen", ("bitumen1", "bitumen2")), ("grind", ("dakgrind1", "dakgrind2"))):
        def _mk(st=_st, vloer=_vloer, edges=""):
            orig = STYLES[st].get("dakvloer")
            def fn():
                STYLES[st]["dakvloer"] = vloer
                try:
                    return flat_roof(st, edges)()
                finally:
                    if orig is None:
                        STYLES[st].pop("dakvloer", None)
                    else:
                        STYLES[st]["dakvloer"] = orig
            return fn
        for _e, _en in (("", "midden"), ("v", "rand"), ("vr", "hoek")):
            register(f"gebouwen/{_st}/{_st}_dak_{_soort}_{_en}", _mk(edges=_e))

# kantoor / appartement: grote en kleine ramen ook voor de oude kantoorstijlen
for _st in ("kantoor_glas", "kantoor_beton"):
    register(f"gebouwen/{_st}/{_st}_verd_raam_groot", make_block(_st, [("v", kantoor_groot)]))
    register(f"gebouwen/{_st}/{_st}_verd_raam_klein", make_block(_st, [("v", kantoor_klein)]))

# hallen, overkappingen en pilaren
for _hs in HAL_STYLES:
    base = f"gebouwen/hallen/{_hs}_"
    register(base + "wand", hal(_hs, "v", roof=False))
    register(base + "wand_dak", hal(_hs, "v", roof=True))
    register(base + "wand_deur_dak", hal(_hs, "v", roof=True, door=True))
    register(base + "hoek", hal(_hs, "vr", roof=False))
    register(base + "hoek_dak", hal(_hs, "vr", roof=True))
    register(base + "dak", hal(_hs, "", roof=True))
    register(base + "dak_kolom", hal(_hs, "", roof=True, columns=((0, 0),)))
register("gebouwen/overkapping/overkapping_glas", overkapping(False))
register("gebouwen/overkapping/overkapping_glas_kolom", overkapping(True))
for _k in ("klassiek", "beton", "baksteen", "staal"):
    register(f"gebouwen/pilaren/pilaar_{_k}", pilaar(_k))
register("gebouwen/pilaren/zuilengang_klassiek", zuilengang("klassiek"))
register("gebouwen/pilaren/zuilengang_beton", zuilengang("beton"))
