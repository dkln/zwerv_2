"""Uitbreiding 3: dakpansoorten (ook afgeknot), kantelen, radiotoren, parkeergarage, erker-woning."""
import math

from common import register, text_pixels
from palette import P
from vox import V, mix, pick, h
from buildings import (Bld, STYLES, S, O, W, HGT, brick, make_block, pitched, flat_roof, H_SCHUIN, H_HOEK_BUITEN,
                       H_HOEK_BINNEN, H_ZADEL, H_ZADEL_SCHILD, H_ZADEL_HOEK, H_ZADEL_T, x_dakkapel, x_schoorsteen)
from buildings2 import j60_bg_raam

# ------------------------------------------------------------------ dakpansoorten

DAKSOORTEN = {
    "pannen_rood": ("pan_rood1", "pan_rood2", "pan_rood3"),
    "pannen_oranje": ("pan_oranje1", "pan_oranje2", "pan_rood3"),
    "pannen_zwart_geglazuurd": ("pan_zwart1", "pan_zwart2", "pan_zwart3"),
    "pannen_antraciet": ("pan_antraciet1", "pan_antraciet2", "pan_zwart1"),
    "leisteen": ("leisteen1", "leisteen2", "leisteen1"),
    "riet": ("riet_dak1", "riet_dak2", "riet_dak1"),
    "golfplaat": ("golfplaat1", "golfplaat2", "golfplaat1"),
    "zink": ("zink1", "zink2", "zink1"),
    "koper": ("koper", "koper", "zink1"),
}

AFGEPLAT = 22  # nokhoogte (in tile-eenheden) waarop het dak wordt afgeknot


def cap(fn, top=AFGEPLAT):
    return lambda px, py: min(fn(px, py), top)


VORMEN = {
    "schuin": H_SCHUIN, "schuin_hoek_buiten": H_HOEK_BUITEN, "schuin_hoek_binnen": H_HOEK_BINNEN,
    "zadel": H_ZADEL, "zadel_schild": H_ZADEL_SCHILD, "zadel_hoek": H_ZADEL_HOEK, "zadel_t": H_ZADEL_T,
    "schuin_afgeplat": cap(H_SCHUIN), "schuin_afgeplat_hoek_buiten": cap(H_HOEK_BUITEN),
    "schuin_afgeplat_hoek_binnen": cap(H_HOEK_BINNEN), "zadel_afgeplat": cap(H_ZADEL),
    "piramide": lambda px, py: 2 * min(px, 32 - px, py, 32 - py),
    "lessenaar": lambda px, py: py * 0.5,
}

for _soort, _kleuren in DAKSOORTEN.items():
    _st = "dak_" + _soort
    STYLES[_st] = dict(fam="dak", wall=brick(["baksteen1", "baksteen2", "baksteen3"], 500), kozijn="kozijn_wit",
                       deuren=["deur_groen"], plint="natuursteen2", sier="natuursteen1", dak=_kleuren, glas="glas1",
                       winkel="kozijn_wit", cap="zink1")
    for _vorm, _hf in VORMEN.items():
        register(f"gebouwen/daken/{_soort}/{_soort}_{_vorm}", pitched(_st, _st + _vorm, _hf))
    register(f"gebouwen/daken/{_soort}/{_soort}_schuin_dakkapel", pitched(_st, _st + "dk", H_SCHUIN, x_dakkapel))
    register(f"gebouwen/daken/{_soort}/{_soort}_schuin_schoorsteen", pitched(_st, _st + "sc", H_SCHUIN, x_schoorsteen))


# afgeknotte daken ook voor de klassieke en jaren-30/60 stijlen
for _st in ("klassiek_rood", "klassiek_donker", "klassiek_geel", "jaren30", "jaren60"):
    for _vorm in ("schuin_afgeplat", "schuin_afgeplat_hoek_buiten", "schuin_afgeplat_hoek_binnen", "zadel_afgeplat"):
        register(f"gebouwen/{_st}/{_st}_dak_{_vorm}", pitched(_st, _st + _vorm, VORMEN[_vorm]))


# ------------------------------------------------------------------ kantelen

def kantelen(style, edges):
    def fn():
        b = Bld(style, "kantelen" + edges, 16)
        m = b.m
        for ly in range(S):
            for lx in range(S):
                m.set(O + lx, O + ly, 0, pick(["zink1", "natuursteen3"], lx, ly, 0, 501))
        for face in edges:
            for u in range(S):
                for d in range(0, 3):
                    for z in range(0, 5):
                        b.put(face, u, z, d, b.st["wall"])
                    if (u // 4) % 2 == 0:
                        for z in range(5, 10):
                            b.put(face, u, z, d, b.st["wall"])
                b.put(face, u, 4, -1, b.st["sier"])
        return m
    return fn


for _st in ("klassiek_rood", "klassiek_donker", "kerk_baksteen", "kerk_steen", "overheid", "herenhuis_1600", "museum_klassiek"):
    for _e, _n in (("v", "rand"), ("vr", "hoek"), ("varl", "toren")):
        register(f"gebouwen/{_st}/{_st}_dak_kantelen_{_n}", kantelen(_st, _e))


# ------------------------------------------------------------------ radiotoren (stapelbaar, 3 m per stuk)

def radiotoren(part):
    def fn():
        hgt = 48 if part == "top" else HGT
        m = V(W, W, hgt)
        c = W / 2
        half = {"voet": 10, "segment": 6, "top": 6}[part]
        for z in range(0, HGT):
            hs = half if part != "voet" else 10 - z * 4 / 24.0
            for (sx, sy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                m.set(c + sx * hs, c + sy * hs, z, "bord_rood" if (z // 6) % 2 else "bord_wit")
            if z % 6 == 0:
                for i in range(int(-hs), int(hs) + 1):
                    for (a, b_) in ((i, -hs), (i, hs), (-hs, i), (hs, i)):
                        m.set(c + a, c + b_, z, "metaal3")
            k = z % 6
            for i in range(int(hs * 2)):
                t = -hs + i
                if abs(t - (-hs + k * 2 * hs / 6)) < 1:
                    for (a, b_) in ((t, -hs), (t, hs), (-hs, t), (hs, t)):
                        m.set(c + a, c + b_, z, "metaal3")
        if part == "top":
            for z in range(HGT, 46):
                m.set(c, c, z, "metaal3")
                m.set(c - 1, c, z, "metaal3")
            for z in (28, 36):
                for (dx, dy) in ((-4, 0), (4, 0), (0, -4), (0, 4)):
                    m.cyl(c + dx, c + dy, 1.5, z, z + 3, "stuc1")
            m.set(c, c, 46, "signaal_rood")
            m.set(c - 1, c, 46, "signaal_rood")
            m.set(c + 6, c + 6, 23, "signaal_rood")
            m.set(c - 6, c - 6, 23, "signaal_rood")
        return m
    return fn


for _p in ("voet", "segment", "top"):
    register(f"gebouwen/overig/radiotoren_{_p}", radiotoren(_p))


# ------------------------------------------------------------------ parkeergarage (hol, open dekken)

BETONG = mix("beton1", "beton2", "beton3", seed=502)


def garage(kind, edges=""):
    def fn():
        m = V(W, W, HGT)
        b = Bld("kantoor_beton", "garage" + kind + edges, HGT)
        b.m = m
        if kind != "helling":
            for ly in range(S):
                for lx in range(S):
                    m.set(O + lx, O + ly, 0, BETONG)
                    m.set(O + lx, O + ly, 1, "asfalt2" if not (lx % 32 == 0 and ly > 8) else "markering")
            for ly in range(10, S):
                m.set(O, O + ly, 1, "markering")
            for lx in range(S):
                m.set(O + lx, O + 10, 1, "markering")
        else:
            for ly in range(S):
                zt = int(ly * 24 / 32)
                for lx in range(S):
                    for z in range(max(0, zt - 1), zt + 2):
                        m.set(O + lx, O + ly, z, BETONG if z < zt + 1 else "asfalt2")
        for (cx, cy) in ((0, 0), (30, 0), (0, 30), (30, 30)):
            for z in range(0, HGT):
                m.box(O + cx, O + cy, z, O + cx + 2, O + cy + 2, z + 1, BETONG)
        for face in edges:
            for u in range(S):
                for z in range(2, 9):
                    b.put(face, u, z, 0, BETONG if z < 8 else "beton_donker")
                for z in (14, 15):
                    if u % 2 == 0:
                        b.put(face, u, z, 0, "metaal2")
        if kind == "inrit":
            for u in range(4, 28):
                for z in range(2, 9):
                    b.put("v", u, z, 0, 0)
            for z in range(0, 7):
                b.put("v", 4, z, 1, "bord_geel")
            for u in range(4, 24):
                b.put("v", u, 6, 1, "bord_rood" if (u // 3) % 2 else "bord_wit")
            for u in range(4, 28):
                b.put("v", u, 22, -1, "bord_blauw")
                b.put("v", u, 23, -1, "bord_blauw")
            px, (tw, th) = text_pixels("P")
            for z in range(16, 23):
                for u in range(12, 20):
                    b.put("v", u, z, -1, "bord_blauw")
            for (c, r) in px:
                b.put("v", 15 + c, 21 - r, -2, "bord_wit")
        if kind == "dak":
            for (lx, ly) in ((16, 16),):
                for z in range(2, 20):
                    m.set(O + lx, O + ly, z, "metaal3")
                m.set(O + lx, O + ly, 20, "lamp_wit")
        if kind in ("dek", "inrit"):
            for lx in range(4, S, 8):
                m.set(O + lx, O + 16, 23, "lamp_wit")
                m.set(O + lx, O + 16, 22, "metaal3")
        return m
    return fn


for _k in ("dek", "dak"):
    for _e, _n in (("", "midden"), ("v", "rand"), ("vr", "hoek")):
        register(f"gebouwen/parkeergarage/parkeergarage_{_k}_{_n}", garage(_k, _e))
register("gebouwen/parkeergarage/parkeergarage_inrit", garage("inrit", ""))
register("gebouwen/parkeergarage/parkeergarage_helling", garage("helling", ""))
register("gebouwen/parkeergarage/parkeergarage_helling_rand", garage("helling", "l"))


@lambda f: register("gebouwen/parkeergarage/parkeergarage_trappenhuis", f)
def garage_trappenhuis():
    b = Bld("kantoor_beton", "garagetrap", HGT)
    b.body()
    for face in "vral":
        b.window(face, 10, 0, 12, 23, sill=False, lintel=False)
    return b.m


# ------------------------------------------------------------------ jaren 60 woning met erker beneden

def j60_bg_erker(b, face):
    b.plinth(face, 1)
    for d in range(1, 6):
        b.rect(face, 3, 29, 0, 16, -d, -d + 1, b.st["wall"])
    b.rect(face, 2, 30, 16, 17, -6, 0, "kozijn_wit")
    b.window(face, 5, 3, 22, 12, sill=False, lintel=False, d0=-5)
    b.door(face, 0, 3, 0, 18, transom=False) if False else None


register("gebouwen/jaren60/jaren60_bg_erker", make_block("jaren60", [("v", j60_bg_erker)]))
register("gebouwen/jaren30/jaren30_bg_erker", make_block("jaren30", [("v", j60_bg_erker)]))
