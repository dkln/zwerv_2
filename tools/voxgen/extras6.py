"""Uitbreiding 6: universiteit, hogeschool, kantoren met kolonnade (pilaren aan de voorkant)."""
import math

from common import register
from palette import P
from vox import V, mix, pick, h, blocky
from buildings import Bld, STYLES, S, O, W, HGT, brick, make_block, flat_roof, pitched, H_SCHUIN, H_HOEK_BUITEN, x_zonnepanelen
from buildings2 import (reg_style, flat_roofs, pitched_roofs, lancet, column, pilasters, f_kantoor_vlies, f_kantoor_bg_glas,
                        f_kantoor_band, app_verd_groot)
from details2 import gevel_tekst

# ------------------------------------------------------------------ universiteit (klassiek, baksteen + natuursteen)

def wall_uni(x, y, z):
    if z in (0, 1, 2, 22, 23):
        return pick(["natuursteen1", "natuursteen2"], (x + y) // 4, z, 0, 900)
    u = x + y
    return pick(["baksteen2", "baksteen4", "baksteen1"], (u + (z % 2) * 2) // 3, z, 0, 901)


STYLES["universiteit"] = dict(fam="uni", wall=wall_uni, kozijn="kozijn_wit", deuren=["hout_donker1"], plint="natuursteen3",
                              sier="natuursteen1", dak=("leisteen1", "leisteen2", "leisteen1"), dakvloer=("zink1", "zink2"),
                              glas="glas1", winkel="kozijn_wit", cap="natuursteen1")


def uni_portaal(b, face):
    b.rect(face, 0, S, 0, 24, -7, 0, 0)
    for i in range(3):
        b.rect(face, 2, 30, 0, 3 - i, -7 + i * 2, 0, b.st["sier"])
    for uc in (4, 12, 20, 28):
        column(b, face, uc, -5, 3, 21, 1.5)
    b.rect(face, 0, S, 21, 24, -8, 0, b.st["sier"])
    lancet(b, face, 11, 10, 3, 14, 20, kind="rond", glass="hout_donker1", frame=b.st["sier"])
    b.sign(face, 8, 24, 21, 24, b.st["sier"], "AULA", "goud") if False else None


def uni_raam_boog(b, face):
    b.plinth(face, 3)
    for u0 in (3, 13, 23):
        lancet(b, face, u0, 6, 5, 15, 21, kind="rond", glass="glas1", frame=b.st["sier"])


def uni_verd_raam(b, face):
    for u0 in (3, 13, 23):
        b.window(face, u0, 4, 6, 16, roedes=True)


def uni_verd_hoog(b, face):
    pilasters(b, face)
    for u0 in (5, 18):
        lancet(b, face, u0, 9, 2, 14, 22, kind="rond", glass="glas1", frame=b.st["sier"])


def dakruiter(style):
    def fn():
        b = Bld(style, "dakruiter", 48)
        m = b.m
        c = W / 2
        for z in range(0, 14):
            for y in range(W):
                for x in range(W):
                    dx, dy = abs(x + 0.5 - c), abs(y + 0.5 - c)
                    if max(dx, dy) <= 5 and dx + dy <= 7:
                        open_ = 4 < z < 11 and (dx < 1.5 or dy < 1.5)
                        m.set(x, y, z, 0 if open_ else ("kozijn_wit" if z < 13 else b.st["sier"]))
        for z in range(14, 30):
            hs = 5 - (z - 14) * 0.32
            for y in range(W):
                for x in range(W):
                    dx, dy = abs(x + 0.5 - c), abs(y + 0.5 - c)
                    if max(dx, dy) <= hs and dx + dy <= hs * 1.4:
                        m.set(x, y, z, "koper")
        for z in range(30, 35):
            m.set(c, c, z, "goud")
        m.cyl(c, c, 1.5, 6, 9, "messing")
        return m
    return fn


_r = pitched_roofs("universiteit")
_r.update(flat_roofs("universiteit"))
_r["dak_dakruiter"] = dakruiter("universiteit")
reg_style("universiteit", {"bg_portaal": uni_portaal, "bg_raam_boog": uni_raam_boog, "verd_raam": uni_verd_raam,
                           "verd_raam_hoog": uni_verd_hoog},
          [("bg_raam_boog_hoek", "bg_raam_boog", "bg_raam_boog"), ("verd_raam_hoek", "verd_raam", "verd_raam"),
           ("verd_raam_hoog_hoek", "verd_raam_hoog", "verd_raam_hoog")], _r)


# ------------------------------------------------------------------ hogeschool (modern, glas + gekleurde lamellen)

STYLES["hogeschool"] = dict(fam="hs", wall=mix("paneel3", "stuc1", "paneel1", seed=902, weights=[3, 2, 1]), kozijn="antraciet1",
                            deuren=["antraciet1"], plint="antraciet2", sier="antraciet1", dak=("dakgrind1", "dakgrind2"),
                            glas="glas2", winkel="antraciet1", cap="alu")

LAMEL = ["paneel_rood", "paneel_geel", "paneel_blauw", "paneel_groen"]


def hs_entree(b, face):
    b.rect(face, 0, S, 0, 24, 0, 3, 0)
    for z in range(0, 24):
        for u in range(S):
            edge = u % 8 == 0 or z in (0, 23) or z == 18
            b.put(face, u, z, 1, "antraciet1" if edge else "glas_helder")
    b.rect(face, 1, 31, 0, 23, 3, 4, "hout1")
    b.rect(face, 0, S, 19, 22, -8, 0, "antraciet1")
    b.sign(face, 4, 28, 19, 24, LAMEL[b.seed % 4], "CAMPUS", "bord_wit")


def hs_lamellen(b, face):
    for z in range(0, 24):
        for u in range(S):
            b.put(face, u, z, 0, 0)
            b.put(face, u, z, 1, b.st["glas"])
    b.interior(face, 0, S, 1, 23, 2, 950, office=True)
    for u in range(1, S, 3):
        c = LAMEL[(u // 3 + b.seed) % 4]
        for z in range(0, 24):
            for d in range(-3, 0):
                b.put(face, u, z, d, c)


reg_style("hogeschool", {"bg_entree": hs_entree, "bg_glas": f_kantoor_bg_glas, "verd_lamellen": hs_lamellen,
                         "verd_vliesgevel": f_kantoor_vlies, "verd_raam_groot": app_verd_groot, "verd_band": f_kantoor_band},
          [("bg_glas_hoek", "bg_glas", "bg_glas"), ("verd_lamellen_hoek", "verd_lamellen", "verd_lamellen"),
           ("verd_vliesgevel_hoek", "verd_vliesgevel", "verd_vliesgevel"), ("bg_entree_hoek", "bg_entree", "bg_glas")],
          dict(flat_roofs("hogeschool"), dak_zonnepanelen=flat_roof("hogeschool", "", x_zonnepanelen)))


# ------------------------------------------------------------------ kantoren met kolonnade (pilaren aan de voorkant)

def kolonnade(b, face):
    """Begane grond die 1 m terugligt, met vierkante pilaren aan de voorkant."""
    b.rect(face, 0, S, 0, 24, -7, 0, 0)
    for z in range(0, 24):
        for u in range(S):
            b.put(face, u, z, 0, 0)
            edge = u % 8 == 0 or z in (0, 20)
            b.put(face, u, z, 1, b.st["kozijn"] if edge else b.st["glas"])
    b.interior(face, 1, 31, 1, 20, 2, 990, office=True)
    for uc in (0, 16):
        b.rect(face, uc, uc + 3, 0, 24, -7, -4, b.st["kozijn"] if b.style != "kantoor_beton" else "beton1")
    b.rect(face, 29, 32, 0, 24, -7, -4, b.st["kozijn"] if b.style != "kantoor_beton" else "beton1")
    b.rect(face, 0, S, 21, 24, -7, 0, b.st["kozijn"] if b.style != "kantoor_beton" else "beton1")


for _st in ("kantoor_glas", "kantoor_beton", "kantoor_80", "kantoor_2000", "kantoor_modern", "hogeschool"):
    register(f"gebouwen/{_st}/{_st}_bg_kolonnade", make_block(_st, [("v", kolonnade)]))
    register(f"gebouwen/{_st}/{_st}_bg_kolonnade_hoek", make_block(_st, [("v", kolonnade), ("r", kolonnade)]))

register("details/tekst/tekst_universiteit", lambda: gevel_tekst("UNIVERSITEIT"))
register("details/tekst/tekst_hogeschool", lambda: gevel_tekst("HOGESCHOOL"))
