"""Gebouw-tiles: modulaire blokken van 4x4x3 m (32x32x24 voxels).

Elk blok staat midden op een canvas van 48x48 zodat balkons, luifels, trappen
en dakgoten tot 1 m (8 voxels) buiten het blok mogen uitsteken zonder dat het
draaipunt verschuift. De voorgevel is de y=8 kant (in Godot: +Z).

Naamgeving:  <stijl>/<stijl>_<onderdeel>
  bg_*    begane grond      verd_*  verdieping      dak_*   daken
  *_hoek  hoekblok met gevel aan voor- en rechterkant
Daken:
  dak_schuin            halve kap: goot aan de voorkant, nok aan de achterkant
                        (twee rijen tegen elkaar = zadeldak over 2 tiles diep)
  dak_schuin_hoek_buiten  hoekkeper (buitenhoek van een bouwblok / schildeind)
  dak_schuin_hoek_binnen  kilkeper (binnenhoek van een bouwblok)
  dak_zadel*            complete kap over 1 tile diep (nok in het midden)
"""
import math

from common import tile, register, text_pixels
from palette import P
from vox import V, mix, pick, h

W = 48
O = 8
S = 32
HGT = 24


def brick(names, seed, weights=(4, 4, 3, 2, 1)):
    w = list(weights)[: len(names)]

    def f(x, y, z):
        u = x + y
        off = (z % 2) * 2
        return pick(list(names), (u + off) // 3, z, 0, seed, w)
    return f


def planks(names, seed):
    def f(x, y, z):
        u = x + y
        if u % 3 == 2:
            return P["hout_donker1"]
        return pick(list(names), u // 3, z // 16, 0, seed)
    return f


def panels(names, seed, seam="beton_donker", every=16):
    def f(x, y, z):
        u = x + y
        if u % every == 0 or z % 12 == 0:
            return P[seam]
        return pick(list(names), u // every, z // 12, 0, seed)
    return f


STYLES = {
    "klassiek_rood": dict(fam="klassiek", wall=brick(["baksteen1", "baksteen2", "baksteen3", "baksteen4", "baksteen5"], 1),
                          kozijn="kozijn_wit", deuren=["deur_groen", "deur_zwart", "deur_rood", "deur_blauw"],
                          plint="natuursteen2", sier="natuursteen1", dak=("pan_rood1", "pan_rood2", "pan_rood3"),
                          luik="kozijn_groen", glas="glas1", winkel="kozijn_groen"),
    "klassiek_donker": dict(fam="klassiek", wall=brick(["donkersteen1", "donkersteen2", "donkersteen3"], 2, (3, 2, 2)),
                            kozijn="kozijn_creme", deuren=["deur_zwart", "deur_groen", "deur_wit"],
                            plint="natuursteen3", sier="natuursteen1", dak=("pan_zwart1", "pan_zwart2", "pan_zwart3"),
                            luik="deur_rood", glas="glas2", winkel="kozijn_zwart"),
    "klassiek_geel": dict(fam="klassiek", wall=brick(["geelsteen1", "geelsteen2", "geelsteen3"], 3, (3, 2, 2)),
                          kozijn="kozijn_wit", deuren=["deur_groen", "deur_blauw", "deur_zwart"],
                          plint="natuursteen3", sier="natuursteen1", dak=("leisteen1", "leisteen2", "leisteen1"),
                          luik="kozijn_groen", glas="glas1", winkel="deur_blauw"),
    "modern_wit": dict(fam="modern", wall=mix("stuc1", "stuc2", "stuc3", seed=4, weights=[5, 3, 1]),
                       kozijn="antraciet1", deuren=["hout1", "antraciet2", "hout2"], plint="antraciet2",
                       sier="hout2", dak=("dakgrind1", "dakgrind2"), glas="glas2", winkel="antraciet1", accent=planks(["hout1", "hout2", "hout3"], 5)),
    "modern_donker": dict(fam="modern", wall=brick(["donkersteen1", "donkersteen2", "antraciet2"], 6, (3, 3, 1)),
                          kozijn="antraciet3", deuren=["hout2", "hout1", "antraciet1"], plint="beton_donker",
                          sier="hout1", dak=("dakgrind1", "dakgrind2"), glas="glas2", winkel="antraciet3", accent=planks(["hout1", "hout2", "hout3"], 7)),
    "modern_hout": dict(fam="modern", wall=planks(["hout1", "hout2", "hout3"], 8),
                        kozijn="antraciet1", deuren=["antraciet2", "hout_donker1"], plint="beton_donker",
                        sier="antraciet2", dak=("dakgrind1", "dakgrind2"), glas="glas1", winkel="antraciet1", accent=mix("stuc1", "stuc2", seed=9)),
    "kantoor_glas": dict(fam="kantoor", wall=panels(["paneel1", "paneel2", "paneel3"], 10, "antraciet1"),
                         kozijn="metaal3", deuren=["metaal3"], plint="antraciet1", sier="metaal3",
                         dak=("bitumen1", "bitumen2"), glas="glas_kantoor", winkel="metaal3"),
    "kantoor_beton": dict(fam="kantoor", wall=panels(["beton1", "beton2", "beton3"], 11),
                          kozijn="antraciet1", deuren=["antraciet1"], plint="beton_donker", sier="antraciet1",
                          dak=("bitumen1", "bitumen2"), glas="glas2", winkel="antraciet1"),
}

WINKELS = ["BAKKER", "KAAS", "CAFE", "BLOEM", "FIETS", "BOEKEN", "SNACK", "SLAGER", "KAPPER", "BRIL", "WINKEL", "THEE"]


def fp(face, u, d):
    if face == "v":
        return O + u, O + d
    if face == "r":
        return O + S - 1 - d, O + u
    if face == "a":
        return O + S - 1 - u, O + S - 1 - d
    return O + d, O + S - 1 - u  # l


class Bld:
    def __init__(self, style, name, hgt=HGT):
        self.m = V(W, W, hgt)
        self.st = STYLES[style]
        self.style = style
        self.seed = sum(ord(c) * (i + 1) for i, c in enumerate(name)) % 9973

    def body(self, z0=0, z1=HGT):
        self.m.box(O, O, z0, O + S, O + S, z1, self.st["wall"])
        # vloer/dakplaat bovenop, zodat een blok zonder dak er netjes uitziet
        self.m.box(O + 1, O + 1, z1 - 1, O + S - 1, O + S - 1, z1, mix("beton2", "beton_donker", seed=91))

    def put(self, face, u, z, d, c):
        x, y = fp(face, u, d)
        self.m.set(x, y, z, c)

    def rect(self, face, u0, u1, z0, z1, d0, d1, c):
        for z in range(z0, z1):
            for d in range(d0, d1):
                for u in range(u0, u1):
                    x, y = fp(face, u, d)
                    self.m.set(x, y, z, c)

    def rnd(self, *k):
        return h(self.seed, *k) if len(k) == 2 else h(self.seed, k[0], k[1] if len(k) > 1 else 0, k[2] if len(k) > 2 else 0)

    # ------------------------------------------------------------ onderdelen
    def interior(self, face, u0, u1, z0, z1, d, key, office=False):
        r = h(self.seed, key, 1, 77)
        lit = r < (0.45 if office else 0.3)
        cur = pick(["gordijn1", "gordijn2", "gordijn3"], self.seed, key, 2, 78) if h(self.seed, key, 3, 79) < 0.65 and not office else None
        for z in range(z0, z1):
            for u in range(u0, u1):
                if office:
                    if z == z1 - 1 and lit and u % 4 in (1, 2):
                        c = "licht_wit"
                    elif z < z0 + 3 and u % 6 in (2, 3, 4):
                        c = "paneel2"
                    else:
                        c = "interieur3"
                elif cur and (u in (u0, u1 - 1) or (u in (u0 + 1, u1 - 2) and z > z0 + 2)):
                    c = cur
                elif lit and z >= (z0 + z1) // 2:
                    c = "licht_warm" if h(u, z, key, 80) < 0.6 else "interieur2"
                else:
                    c = "interieur1" if (u + z) % 3 else "interieur2"
                self.put(face, u, z, d, c)

    def window(self, face, u0, z0, w, hh, roedes=False, sill=True, lintel=True, luiken=False,
               frame=None, d0=0, sill_c=None, office=False):
        fr = frame or self.st["kozijn"]
        self.rect(face, u0, u0 + w, z0, z0 + hh, d0, d0 + 3, 0)
        for u in range(u0, u0 + w):
            self.put(face, u, z0, d0 + 1, fr)
            self.put(face, u, z0 + hh - 1, d0 + 1, fr)
        for z in range(z0, z0 + hh):
            self.put(face, u0, z, d0 + 1, fr)
            self.put(face, u0 + w - 1, z, d0 + 1, fr)
        self.rect(face, u0 + 1, u0 + w - 1, z0 + 1, z0 + hh - 1, d0 + 2, d0 + 3, self.st["glas"])
        self.interior(face, u0 + 1, u0 + w - 1, z0 + 1, z0 + hh - 1, d0 + 3, u0 * 31 + z0 * 7 + ord(face))
        if roedes:
            mid = u0 + w // 2
            if w >= 6:
                for z in range(z0, z0 + hh):
                    self.put(face, mid, z, d0 + 1, fr)
            for frac in (1 / 3, 2 / 3) if hh >= 12 else (0.5,):
                zz = z0 + int(hh * frac)
                for u in range(u0, u0 + w):
                    self.put(face, u, zz, d0 + 1, fr)
        if sill:
            sc = sill_c or self.st["sier"]
            self.rect(face, u0 - 1, u0 + w + 1, z0 - 1, z0, d0 - 1, d0 + 1, sc)
        if lintel:
            self.rect(face, u0 - 1, u0 + w + 1, z0 + hh, z0 + hh + 1, d0, d0 + 1, self.st["sier"])
            if self.st["fam"] == "klassiek":
                self.put(face, u0 + w // 2, z0 + hh, d0 - 1, self.st["sier"])
                if w % 2 == 0:
                    self.put(face, u0 + w // 2 - 1, z0 + hh, d0 - 1, self.st["sier"])
        if luiken:
            lc = self.st["luik"]
            for u in list(range(u0 - 4, u0 - 1)) + list(range(u0 + w + 1, u0 + w + 4)):
                for z in range(z0, z0 + hh):
                    edge = u in (u0 - 4, u0 - 2, u0 + w + 1, u0 + w + 3) or z in (z0, z0 + hh - 1)
                    diag = (z - z0) == (u - u0) % hh or (z - z0) == hh - 1 - ((u - u0) % hh)
                    self.put(face, u, z, d0 - 1, lc if (edge or not diag) else self.st["kozijn"])

    def door(self, face, u0, w, z0, hh, color=None, transom=True, steps=0, glass_panel=False):
        fr = self.st["kozijn"]
        dc = color or pick(self.st["deuren"], self.seed, u0, 0, 81)
        self.rect(face, u0, u0 + w, z0, z0 + hh, 0, 3, 0)
        for z in range(z0, z0 + hh):
            self.put(face, u0, z, 1, fr)
            self.put(face, u0 + w - 1, z, 1, fr)
        for u in range(u0, u0 + w):
            self.put(face, u, z0 + hh - 1, 1, fr)
        top = z0 + hh - 1
        if transom:
            for u in range(u0, u0 + w):
                self.put(face, u, top - 4, 1, fr)
            self.rect(face, u0 + 1, u0 + w - 1, top - 3, top, 2, 3, self.st["glas"])
            self.interior(face, u0 + 1, u0 + w - 1, top - 3, top, 3, u0 + 999)
            top -= 4
        self.rect(face, u0 + 1, u0 + w - 1, z0, top, 2, 3, dc)
        if glass_panel:
            self.rect(face, u0 + 2, u0 + w - 2, z0 + (top - z0) // 2, top - 1, 2, 3, self.st["glas"])
        else:
            # paneeldeur: verdiepte panelen
            for z in range(z0 + 2, top - 1):
                for u in range(u0 + 2, u0 + w - 2):
                    if z != (z0 + top) // 2 and u != u0 + w // 2:
                        self.put(face, u, z, 3, dc)
                        self.put(face, u, z, 2, 0)
        self.put(face, u0 + w - 3, z0 + (top - z0) // 2, 1, "messing")
        self.put(face, u0 + w // 2, z0 + (top - z0) // 2 + 1, 1, "messing")
        for i in range(steps):
            self.rect(face, u0 - 1, u0 + w + 1, 0, z0 - i, -1 - i * 2, -i * 2 + (1 if i == 0 else 0), self.st["sier"] if self.st["fam"] == "klassiek" else "beton2")

    def plinth(self, face, hh=2):
        self.rect(face, 0, S, 0, hh, -1 if self.st["fam"] == "klassiek" else 0, 1, self.st["plint"])

    def luifel(self, face, u0, u1, ztop, depth, colors):
        for d in range(1, depth + 1):
            z = ztop - (d - 1) // 2
            for u in range(u0, u1):
                self.put(face, u, z, -d, colors[(u // 3) % len(colors)])
        zl = ztop - (depth - 1) // 2
        for u in range(u0, u1):
            self.put(face, u, zl - 1, -depth, colors[(u // 3) % len(colors)])
            if u % 2 == 0:
                self.put(face, u, zl - 2, -depth, colors[(u // 3) % len(colors)])
        for u in (u0, u1 - 1):
            for d in range(1, depth + 1):
                self.put(face, u, ztop - (d - 1) // 2 - 1, -d, "metaal_donker")

    def sign(self, face, u0, u1, z0, z1, board, text, letter="bord_wit"):
        self.rect(face, u0, u1, z0, z1, -1, 1, board)
        px, (tw, th) = text_pixels(text)
        su = u0 + (u1 - u0 - tw) // 2
        sz = z0 + (z1 - z0 - 5) // 2
        for (c, r) in px:
            self.put(face, su + c, sz + 4 - r, -2, letter)

    def shopfront(self, face, text, luifel_c=None):
        st = self.st
        fr = st["winkel"]
        self.rect(face, 1, 31, 0, 17, 0, 3, 0)
        self.rect(face, 1, 31, 0, 2, 0, 3, st["plint"])
        for z in range(2, 17):
            for u in (1, 2, 11, 21, 29, 30):
                self.put(face, u, z, 1, fr)
        for u in range(1, 31):
            self.put(face, u, 16, 1, fr)
            self.put(face, u, 2, 1, fr)
        self.rect(face, 3, 11, 3, 16, 2, 3, st["glas"])
        self.rect(face, 12, 21, 3, 16, 2, 3, st["glas"])
        self.interior(face, 3, 21, 3, 16, 3, 500)
        # uitstalling
        for u in range(3, 21):
            for z in range(3, 6):
                if h(u, z, self.seed, 82) < 0.5:
                    self.put(face, u, z, 3, pick(["bloem_rood", "bloem_geel", "luifel_wit", "hout1", "bloem_oranje", "luifel_blauw"], u, z, self.seed, 83))
            self.put(face, u, 13, 3, "licht_warm")
        # deur
        self.rect(face, 22, 29, 0, 16, 2, 3, st["glas"])
        for z in range(0, 16):
            self.put(face, 22, z, 2, fr)
            self.put(face, 28, z, 2, fr)
        self.rect(face, 23, 28, 0, 15, 3, 4, "interieur2")
        self.put(face, 23, 8, 1, "rvs")
        self.sign(face, 1, 31, 17, 23, pick(["deur_groen", "deur_rood", "deur_blauw", "deur_zwart", "luifel_geel"], self.seed, 1, 0, 84), text,
                  "bord_wit")
        if luifel_c:
            self.luifel(face, 1, 31, 16, 7, luifel_c)

    def balcony_modern(self, face):
        self.rect(face, 1, 31, 0, 2, -8, 0, "beton1")
        self.rect(face, 1, 31, 2, 9, -8, -7, "glas_helder")
        self.rect(face, 1, 2, 2, 9, -8, 0, "glas_helder")
        self.rect(face, 30, 31, 2, 9, -8, 0, "glas_helder")
        self.rect(face, 1, 31, 9, 10, -8, -7, "metaal3")
        self.rect(face, 1, 2, 9, 10, -8, 0, "metaal3")
        self.rect(face, 30, 31, 9, 10, -8, 0, "metaal3")
        # plantenbak
        self.rect(face, 3, 8, 2, 4, -7, -5, "antraciet2")
        self.rect(face, 3, 8, 4, 6, -7, -5, "blad2")
        self.window(face, 4, 2, 24, 19, sill=False, lintel=False)
        self.put(face, 16, 10, 1, self.st["kozijn"]) if False else None
        for z in range(2, 21):
            self.put(face, 16, z, 1, self.st["kozijn"])

    def railing(self, face, u0, u1, z0, z1, d, c="metaal_donker"):
        for u in range(u0, u1):
            self.put(face, u, z1 - 1, d, c)
            if (u - u0) % 2 == 0:
                for z in range(z0, z1):
                    self.put(face, u, z, d, c)
            self.put(face, u, z0, d, c)


# ------------------------------------------------------------------ gevelontwerpen
# Elke functie tekent één gevel op een vlak (face) van het blok.

def f_klassiek_bg_deur(b, face):
    b.plinth(face)
    b.door(face, 3, 8, 2, 21, steps=2)
    b.window(face, 15, 5, 14, 15, roedes=True)


def f_klassiek_bg_raam(b, face):
    b.plinth(face)
    b.window(face, 3, 5, 10, 15, roedes=True)
    b.window(face, 19, 5, 10, 15, roedes=True)


def f_klassiek_verd_raam(b, face):
    b.window(face, 4, 5, 9, 15, roedes=True)
    b.window(face, 19, 5, 9, 15, roedes=True)


def f_klassiek_verd_luiken(b, face):
    b.window(face, 6, 5, 7, 14, roedes=True, luiken=True)
    b.window(face, 20, 5, 7, 14, roedes=True, luiken=True)


def f_klassiek_verd_drie(b, face):
    for u in (3, 12, 21):
        b.window(face, u, 5, 7, 15, roedes=True)


def f_klassiek_verd_balkon(b, face):
    for u in (4, 19):
        b.window(face, u, 2, 9, 19, roedes=True, sill=False)
        b.rect(face, u - 1, u + 10, 1, 2, -1, 1, b.st["sier"])
        b.railing(face, u - 1, u + 10, 2, 9, -1)


def f_klassiek_verd_erker(b, face):
    b.rect(face, 5, 27, 1, 22, -4, 0, b.st["wall"])
    b.rect(face, 4, 28, 0, 1, -5, 0, b.st["sier"])
    b.rect(face, 4, 28, 22, 23, -5, 0, "zink1")
    b.window(face, 7, 4, 8, 16, roedes=True, d0=-4, sill=False)
    b.window(face, 17, 4, 8, 16, roedes=True, d0=-4, sill=False)


def f_klassiek_verd_dicht(b, face):
    for u in (6, 25):
        for k in (-1, 0, 1):
            b.put(face, u + k, 20, -1, "metaal_donker")
            b.put(face, u, 20 + k, -1, "metaal_donker")
    b.window(face, 13, 9, 6, 7, roedes=True)


def f_klassiek_bg_poort(b, face):
    b.plinth(face)
    for z in range(0, 20):
        for u in range(8, 24):
            dx = u + 0.5 - 16
            if z < 14 or (dx * dx) / 64.0 + ((z - 13.5) ** 2) / 36.0 < 1.0:
                for d in range(0, S):
                    b.put(face, u, z, d, 0)
    for z in range(0, 20):
        for u in range(7, 25):
            dx = u + 0.5 - 16
            inner = z < 14 or (dx * dx) / 64.0 + ((z - 13.5) ** 2) / 36.0 < 1.0
            outer = z < 14 or (dx * dx) / 81.0 + ((z - 13.5) ** 2) / 49.0 < 1.0
            if outer and not inner:
                b.put(face, u, z, 0, b.st["sier"])
                b.put(face, u, z, -1, b.st["sier"])
    for d in range(0, S):
        for u in range(8, 24):
            b.put(face, u, 0, d, pick(["kei1", "kei2", "kei3"], u, d, 0, 85))
    # hekwerk in de poort
    b.railing(face, 8, 24, 1, 14, 2)


def shop_text(b):
    return WINKELS[b.seed % len(WINKELS)]


def f_bg_winkel(b, face):
    b.shopfront(face, shop_text(b))


def f_bg_winkel_luifel(b, face):
    cols = [["luifel_rood", "luifel_wit"], ["luifel_groen", "luifel_wit"], ["luifel_blauw", "luifel_wit"],
            ["luifel_geel", "luifel_oranje"]][b.seed % 4]
    b.shopfront(face, shop_text(b), cols)


def f_modern_bg_deur(b, face):
    b.plinth(face, 1)
    b.window(face, 2, 3, 15, 17, sill=False, lintel=False)
    b.rect(face, 18, 30, 0, 22, 0, 1, b.st["accent"])
    b.door(face, 21, 7, 0, 19, transom=False, glass_panel=True)
    b.rect(face, 19, 30, 19, 20, -3, 0, b.st["kozijn"])
    b.put(face, 24, 16, -4, "lamp_wit")


def f_modern_bg_raam(b, face):
    b.plinth(face, 1)
    b.window(face, 2, 3, 28, 18, sill=False, lintel=False)
    for z in range(3, 21):
        for u in (11, 20):
            b.put(face, u, z, 1, b.st["kozijn"])


def f_modern_bg_garage(b, face):
    b.plinth(face, 1)
    b.rect(face, 3, 29, 0, 16, 0, 3, 0)
    for z in range(0, 16):
        for u in range(3, 29):
            edge = u in (3, 28) or z == 15
            b.put(face, u, z, 1 if edge else 2, b.st["kozijn"] if edge else ("metaal1" if (z // 2) % 2 else "metaal2"))
    b.put(face, 16, 18, -1, "lamp_wit")


def f_modern_verd_raam(b, face):
    b.window(face, 3, 5, 11, 15, sill=True, lintel=False, sill_c="zink1")
    b.window(face, 18, 5, 11, 15, sill=True, lintel=False, sill_c="zink1")


def f_modern_verd_breed(b, face):
    b.rect(face, 1, 31, 4, 21, 0, 1, b.st["accent"])
    b.window(face, 2, 5, 28, 15, sill=False, lintel=False)
    for z in range(5, 20):
        for u in (11, 20):
            b.put(face, u, z, 1, b.st["kozijn"])


def f_modern_verd_balkon(b, face):
    b.balcony_modern(face)


def f_modern_verd_frans(b, face):
    for u in (4, 19):
        b.window(face, u, 2, 9, 19, sill=False, lintel=False)
        b.rect(face, u, u + 9, 2, 8, -1, 0, "glas_helder")
        b.rect(face, u, u + 9, 8, 9, -1, 0, "metaal3")


def f_modern_verd_dicht(b, face):
    b.window(face, 13, 10, 6, 6, sill=False, lintel=False)
    for z in range(2, 22, 2):
        b.put(face, 27, z, -1, "zink2")


def f_kantoor_vlies(b, face, z0=0, z1=23):
    st = b.st
    for z in range(z0, z1):
        for u in range(0, S):
            b.put(face, u, z, 0, 0)
            if u % 8 == 0 or u == S - 1:
                b.put(face, u, z, 0, st["kozijn"])
                b.put(face, u, z, -1, st["kozijn"])
            elif z < z0 + 4:
                b.put(face, u, z, 1, "antraciet2")
            else:
                b.put(face, u, z, 1, st["glas"])
    b.interior(face, 0, S, z0 + 4, z1, 2, z0 + 600, office=True)
    for u in range(0, S):
        b.put(face, u, z0 + 3, 0, st["kozijn"])
        b.put(face, u, z1, 0, st["kozijn"])
        b.put(face, u, z1, -1, st["kozijn"])


def f_kantoor_band(b, face):
    st = b.st
    b.rect(face, 0, S, 0, 7, -1, 1, "beton1" if b.style == "kantoor_beton" else "paneel3")
    b.rect(face, 0, S, 20, 24, -1, 1, "beton1" if b.style == "kantoor_beton" else "paneel3")
    for z in range(7, 20):
        for u in range(0, S):
            b.put(face, u, z, 0, st["kozijn"] if u % 4 == 0 else 0)
            b.put(face, u, z, 1, st["glas"])
    b.interior(face, 0, S, 7, 20, 2, 700, office=True)


def f_kantoor_bg_entree(b, face):
    f_kantoor_vlies(b, face, 0, 20)
    st = b.st
    b.rect(face, 0, S, 20, 24, -1, 1, st["kozijn"] if b.style == "kantoor_glas" else "beton1")
    b.rect(face, 9, 23, 0, 16, -1, 3, 0)
    for z in range(0, 16):
        for u in range(9, 23):
            edge = u in (9, 22) or z == 15
            seam = u in (15, 16)
            b.put(face, u, z, 1, st["kozijn"] if (edge or seam) else "glas_helder")
    b.rect(face, 10, 22, 0, 15, 3, 4, "interieur2")
    b.rect(face, 5, 27, 17, 19, -7, 0, "metaal3")
    for u in range(8, 25, 4):
        b.put(face, u, 16, -4, "lamp_wit")
    b.sign(face, 6, 26, 20, 24, "antraciet1", "ZWERVR", "lamp_wit")


def f_kantoor_bg_glas(b, face):
    f_kantoor_vlies(b, face, 0, 20)
    b.rect(face, 0, S, 20, 24, -1, 1, b.st["kozijn"] if b.style == "kantoor_glas" else "beton1")
    b.rect(face, 0, S, 0, 2, 0, 2, b.st["plint"])


def f_kantoor_dicht(b, face):
    pass


FAM_PIECES = {
    "klassiek": {
        "bg_deur": f_klassiek_bg_deur,
        "bg_raam": f_klassiek_bg_raam,
        "bg_winkel": f_bg_winkel,
        "bg_winkel_luifel": f_bg_winkel_luifel,
        "bg_poort": f_klassiek_bg_poort,
        "verd_raam": f_klassiek_verd_raam,
        "verd_luiken": f_klassiek_verd_luiken,
        "verd_drie_ramen": f_klassiek_verd_drie,
        "verd_balkon": f_klassiek_verd_balkon,
        "verd_erker": f_klassiek_verd_erker,
        "verd_dicht": f_klassiek_verd_dicht,
    },
    "modern": {
        "bg_deur": f_modern_bg_deur,
        "bg_raam": f_modern_bg_raam,
        "bg_garage": f_modern_bg_garage,
        "bg_winkel": f_bg_winkel,
        "verd_raam": f_modern_verd_raam,
        "verd_raam_breed": f_modern_verd_breed,
        "verd_balkon": f_modern_verd_balkon,
        "verd_frans": f_modern_verd_frans,
        "verd_dicht": f_modern_verd_dicht,
    },
    "kantoor": {
        "bg_entree": f_kantoor_bg_entree,
        "bg_glas": f_kantoor_bg_glas,
        "verd_vliesgevel": f_kantoor_vlies,
        "verd_band": f_kantoor_band,
        "verd_dicht": f_kantoor_dicht,
    },
}

# hoekvarianten: (naam, gevel voor, gevel rechts)
FAM_CORNERS = {
    "klassiek": [("bg_raam_hoek", "bg_raam", "bg_raam"), ("bg_winkel_hoek", "bg_winkel", "bg_raam"),
                 ("bg_deur_hoek", "bg_deur", "bg_raam"), ("verd_raam_hoek", "verd_raam", "verd_raam"),
                 ("verd_drie_ramen_hoek", "verd_drie_ramen", "verd_drie_ramen"), ("verd_dicht_hoek", "verd_dicht", "verd_dicht")],
    "modern": [("bg_raam_hoek", "bg_raam", "bg_raam"), ("bg_deur_hoek", "bg_deur", "bg_raam"),
               ("verd_raam_hoek", "verd_raam", "verd_raam"), ("verd_raam_breed_hoek", "verd_raam_breed", "verd_raam_breed"),
               ("verd_balkon_hoek", "verd_balkon", "verd_raam"), ("verd_dicht_hoek", "verd_dicht", "verd_dicht")],
    "kantoor": [("bg_glas_hoek", "bg_glas", "bg_glas"), ("bg_entree_hoek", "bg_entree", "bg_glas"),
                ("verd_vliesgevel_hoek", "verd_vliesgevel", "verd_vliesgevel"), ("verd_band_hoek", "verd_band", "verd_band")],
}


def make_block(style, pieces):
    """pieces: lijst van (face, gevelfunctie)."""
    def fn():
        name = style + "".join(p[0] + p[1].__name__ for p in pieces)
        b = Bld(style, name)
        b.body()
        for face, f in pieces:
            f(b, face)
        return b.m
    return fn


# ------------------------------------------------------------------ daken

def roof_colors(b, H, x, y):
    names = b.st["dak"]
    row = int(H) // 2
    base = names[row % 2] if len(names) > 1 else names[0]
    if h(x, y, row, b.seed) < 0.12:
        base = names[-1]
    return base


def pitched(style, name, Hfun, extra=None, hgt=32):
    """Hfun(px, py) -> hoogte in 'tile-eenheden' (0..32); 32 = nok (24 voxels)."""
    def fn():
        b = Bld(style, name, hgt)
        m = b.m
        tops = {}
        for ly in range(S):
            for lx in range(S):
                H = max(0.0, Hfun(lx + 0.5, ly + 0.5))
                zt = max(1, int(math.ceil(H * 0.75)))
                tops[(lx, ly)] = (zt, H)
                for z in range(zt):
                    if z >= zt - 2:
                        c = roof_colors(b, H, lx, ly)
                        if H > 31.0:
                            c = "pan_zwart3" if b.st["dak"][0].startswith("pan_rood") else "zink2"
                    else:
                        c = b.st["wall"]
                    m.set(O + lx, O + ly, z, c)
        # dakgoot / overstek bij de goot (lage randen)
        for lx in range(S):
            for ly in range(S):
                zt, H = tops[(lx, ly)]
                if zt > 1:
                    continue
                for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                    nx, ny = lx + dx, ly + dy
                    if 0 <= nx < S and 0 <= ny < S:
                        continue
                    m.set(O + nx, O + ny, 0, roof_colors(b, 0, lx, ly))
                    m.set(O + nx + dx, O + ny + dy, 0, "zink1")
                    m.set(O + nx + dx, O + ny + dy, 1, "zink1")
        if extra:
            extra(b, tops)
        return m
    return fn


def x_dakkapel(b, tops):
    m = b.m
    for ly in range(6, 18):
        for lx in range(9, 23):
            for z in range(0, 16):
                if z >= tops[(lx, ly)][0] - 1 or ly == 6:
                    m.set(O + lx, O + ly, z, "kozijn_wit" if (lx in (9, 22) or ly == 6) else b.st["wall"])
    for ly in range(5, 19):
        for lx in range(8, 24):
            m.set(O + lx, O + ly, 16, "zink1")
    for lx in range(10, 22):
        for z in range(max(tops[(lx, 6)][0], 6), 15):
            m.set(O + lx, O + 6, z, "kozijn_wit")
    for lx in range(11, 21):
        for z in range(max(tops[(lx, 6)][0] + 1, 8), 14):
            m.set(O + lx, O + 6, z, b.st["glas"])
            m.set(O + lx, O + 7, z, "interieur1" if (lx + z) % 4 else "licht_warm")
    for z in range(8, 14):
        m.set(O + 16, O + 6, z, "kozijn_wit")


def x_schoorsteen(b, tops, lx0=22, ly0=20):
    m = b.m
    for ly in range(ly0, ly0 + 4):
        for lx in range(lx0, lx0 + 4):
            for z in range(0, 30):
                m.set(O + lx, O + ly, z, brick(["baksteen2", "baksteen4", "donkersteen1"], 12))
    for ly in range(ly0 - 1, ly0 + 5):
        for lx in range(lx0 - 1, lx0 + 5):
            m.set(O + lx, O + ly, 30, "natuursteen2")
    m.set(O + lx0 + 1, O + ly0 + 1, 30, "interieur3")
    m.set(O + lx0 + 2, O + ly0 + 2, 30, "interieur3")


def x_dakraam(b, tops):
    m = b.m
    for ly in range(8, 18):
        for lx in range(10, 18):
            zt = tops[(lx, ly)][0]
            edge = lx in (10, 17) or ly in (8, 17)
            m.set(O + lx, O + ly, zt - 1, "antraciet1" if edge else b.st["glas"])


def x_zonnepanelen_schuin(b, tops):
    m = b.m
    for ly in range(4, 28):
        for lx in range(3, 29):
            zt = tops[(lx, ly)][0]
            if lx % 9 == 2 or ly % 8 == 3:
                c = "metaal3"
            else:
                c = "zonnepaneel"
            m.set(O + lx, O + ly, zt, c)


def x_dakterras(b, tops):
    """Schuine kap deels opengebroken voor een dakterras."""
    m = b.m
    for ly in range(0, 16):
        for lx in range(10, 24):
            for z in range(1, 32):
                m.set(O + lx, O + ly, z, 0)
            m.set(O + lx, O + ly, 0, pick(["hout1", "hout2", "hout3"], lx // 4, ly, 0, 86))
    # zijwangen
    for ly in range(0, 16):
        for lx in (9, 24):
            for z in range(1, tops[(lx, ly)][0]):
                m.set(O + lx, O + ly, z, b.st["wall"])
    # achterwand met deur
    for lx in range(10, 24):
        for z in range(1, tops[(lx, 16)][0]):
            m.set(O + lx, O + 16, z, b.st["wall"])
    for lx in range(13, 21):
        for z in range(1, 11):
            m.set(O + lx, O + 16, z, b.st["glas"] if lx not in (13, 20, 17) and z < 10 else "kozijn_wit")
            m.set(O + lx, O + 17, z, "interieur1")
    # hekje
    for lx in range(10, 24):
        m.set(O + lx, O + 0, 6, "metaal_donker")
        if lx % 2 == 0:
            for z in range(1, 6):
                m.set(O + lx, O + 0, z, "metaal_donker")


H_SCHUIN = lambda px, py: py
H_HOEK_BUITEN = lambda px, py: min(py, S - px)
H_HOEK_BINNEN = lambda px, py: max(py, S - px)
H_ZADEL = lambda px, py: 2 * min(py, S - py)
H_ZADEL_SCHILD = lambda px, py: 2 * min(py, S - py, S - px)
H_ZADEL_HOEK = lambda px, py: 2 * min(py, S - px, max(S - py, px))
H_ZADEL_T = lambda px, py: 2 * max(min(py, S - py), min(px, S - px) if py > S / 2 else 0)
H_HALF_LINKS = lambda px, py: py if px < 16 else -1


def x_half_plat(b, tops):
    """Rechterhelft plat dak met dakrand."""
    m = b.m
    for ly in range(S):
        for lx in range(16, S):
            for z in range(0, 32):
                m.set(O + lx, O + ly, z, 0)
            m.set(O + lx, O + ly, 0, pick(["bitumen1", "bitumen2"], lx, ly, 0, 87))
    for ly in range(S):
        for z in range(0, 3):
            m.set(O + S - 1, O + ly, z, "zink1")
    for lx in range(16, S):
        for z in range(0, 3):
            m.set(O + lx, O, z, "zink1")
            m.set(O + lx, O + S - 1, z, "zink1")


def flat_roof(style, edges, extra=None, kroonlijst=False):
    def fn():
        b = Bld(style, "dak_plat" + edges + str(kroonlijst), 16)
        m = b.m
        fam = b.st["fam"]
        floor = b.st.get("dakvloer", b.st["dak"])
        for ly in range(S):
            for lx in range(S):
                m.set(O + lx, O + ly, 0, pick(list(floor), lx // 2, ly // 2, 0, 88))
        cap = b.st.get("cap") or {"klassiek": "zink1", "modern": "zink1", "kantoor": "metaal3"}.get(fam, "zink1")
        ph = b.st.get("dakrand", 3)
        for face in edges:
            for u in range(S):
                for d in range(0, 2):
                    for z in range(0, ph):
                        b.put(face, u, z, d, b.st["wall"])
                    b.put(face, u, ph, d, cap)
                if b.st.get("boeiboord"):
                    for z in range(0, ph + 1):
                        b.put(face, u, z, -1, b.st["boeiboord"])
            if kroonlijst:
                for u in range(S):
                    b.rect(face, u, u + 1, 0, 1, -2, 0, "kozijn_wit")
                    if u % 2 == 0:
                        b.put(face, u, 1, -1, "kozijn_wit")
                    b.rect(face, u, u + 1, 2, 4, -2, 0, "kozijn_wit")
                    b.put(face, u, 4, -1, "kozijn_wit")
                    b.put(face, u, 4, 0, "kozijn_wit")
        if extra:
            extra(b)
        return m
    return fn


def x_installatie(b):
    m = b.m
    m.box(O + 6, O + 8, 1, O + 20, O + 22, 7, "metaal1")
    for lx in range(7, 19, 4):
        m.cyl(O + lx + 1.5, O + 15, 1.5, 7, 8, "metaal_donker")
    m.box(O + 22, O + 6, 1, O + 28, O + 12, 4, "metaal2")
    for i in range(8):
        m.set(O + 6 + i, O + 23, 1, "metaal2")


def x_zonnepanelen(b):
    m = b.m
    for row in range(3):
        y0 = O + 5 + row * 8
        for ly in range(5):
            z = 1 + ly // 2
            for lx in range(4, 28):
                m.set(O + lx, y0 + ly, z, "metaal3" if lx % 8 == 3 else "zonnepaneel")
            m.set(O + 4, y0 + ly, 1, "metaal2")


def x_lichtkoepel(b):
    m = b.m
    m.box(O + 10, O + 10, 1, O + 22, O + 22, 3, "stuc1")
    m.box(O + 11, O + 11, 3, O + 21, O + 21, 4, "glas_helder")
    m.box(O + 13, O + 13, 4, O + 19, O + 19, 5, "glas_helder")


def x_dakterras_plat(b):
    m = b.m
    for ly in range(4, 28):
        for lx in range(4, 28):
            m.set(O + lx, O + ly, 1, pick(["hout1", "hout2", "hout3"], lx // 4, ly, 0, 89))
    m.box(O + 5, O + 22, 2, O + 9, O + 26, 5, "antraciet2")
    m.ellipsoid(O + 7, O + 24, 7, 3, 3, 3, mix("blad1", "blad2", "blad4", seed=90))
    m.box(O + 14, O + 10, 2, O + 22, O + 12, 4, "hout2")


# ------------------------------------------------------------------ grachtengevels (top)

def gable_top(style, kind):
    def fn():
        b = Bld(style, "gevel" + kind, 32)
        m = b.m
        st = b.st
        # zadeldak met nok van voor naar achter (over y)
        for ly in range(2, S):
            for lx in range(S):
                H = 2 * min(lx + 0.5, S - lx - 0.5)
                zt = max(1, int(math.ceil(H * 0.75)))
                for z in range(zt):
                    m.set(O + lx, O + ly, z, roof_colors(b, H, ly, lx) if z >= zt - 2 else st["wall"])

        def width(z):
            if kind == "trap":
                return max(4, 16 - 3 * (z // 5)) if z < 27 else 0
            if kind == "tuit":
                return max(0, 16 - z * 0.66) + 1 if z < 25 else (1 if z < 27 else 0)
            if kind == "klok":
                if z < 6:
                    return 16
                if z < 24:
                    t = (z - 6) / 18.0
                    return 5 + 11 * (1 - t) ** 2 + 2 * math.sin(t * math.pi)
                return 5 - (z - 24) * 1.5 if z < 27 else 0
            if kind == "hals":
                if z < 6:
                    return 16
                if z < 12:
                    return 6 + (12 - z) * 1.6
                if z < 24:
                    return 6
                return 6 - (z - 24) * 2 if z < 27 else 0
            return 0

        shape = {}
        for z in range(0, 28):
            w = width(z)
            for lx in range(S):
                shape[(lx, z)] = abs(lx + 0.5 - 16) < w
        for (lx, z), inside in shape.items():
            if not inside:
                continue
            edge = not shape.get((lx, z + 1), False) or not shape.get((lx - 1, z), False) or not shape.get((lx + 1, z), False)
            for d in (0, 1):
                m.set(O + lx, O + d, z, st["sier"] if (edge and d == 0 and kind != "tuit") else st["wall"])
            if edge and kind != "tuit":
                m.set(O + lx, O - 1, z, st["sier"]) if z % 2 == 0 and kind == "trap" else None
        if kind == "tuit":
            for (lx, z), inside in shape.items():
                if inside and not shape.get((lx, z + 1), False):
                    m.set(O + lx, O, z, st["sier"])
                    m.set(O + lx, O - 1, z, st["sier"])
        # ramen in de gevel
        b.window("v", 11, 3, 10, 12, roedes=True)
        b.window("v", 14, 18, 4, 5, roedes=False, sill=False)
        # hijsbalk
        for d in range(-6, 0):
            m.set(O + 16, O + d, 24, "hout_donker2")
            m.set(O + 15, O + d, 24, "hout_donker2")
        m.set(O + 16, O - 6, 23, "metaal_donker")
        m.set(O + 16, O - 6, 22, "metaal_donker")
        # bekroning
        top = max(z for (lx, z), v in shape.items() if v)
        m.set(O + 15, O, top + 1, st["sier"])
        m.set(O + 16, O, top + 1, st["sier"])
        return m
    return fn


# ------------------------------------------------------------------ registratie

for _style, _st in list(STYLES.items()):
    fam = _st["fam"]
    base = f"gebouwen/{_style}/{_style}_"
    for _name, _f in FAM_PIECES[fam].items():
        register(base + _name, make_block(_style, [("v", _f)]))
    for _name, _a, _b in FAM_CORNERS[fam]:
        register(base + _name, make_block(_style, [("v", FAM_PIECES[fam][_a]), ("r", FAM_PIECES[fam][_b])]))
    # binnenhoek (alleen gevel achter-links zichtbaar bij bouwblokken) = gewone blokken gedraaid
    register(base + "blok_dicht", make_block(_style, []))

    if fam == "klassiek":
        roofs = {
            "dak_schuin": (H_SCHUIN, None),
            "dak_schuin_hoek_buiten": (H_HOEK_BUITEN, None),
            "dak_schuin_hoek_binnen": (H_HOEK_BINNEN, None),
            "dak_schuin_dakkapel": (H_SCHUIN, x_dakkapel),
            "dak_schuin_schoorsteen": (H_SCHUIN, x_schoorsteen),
            "dak_schuin_dakraam": (H_SCHUIN, x_dakraam),
            "dak_schuin_zonnepanelen": (H_SCHUIN, x_zonnepanelen_schuin),
            "dak_schuin_dakterras": (H_SCHUIN, x_dakterras),
            "dak_schuin_half_plat": (H_SCHUIN, x_half_plat),
            "dak_zadel": (H_ZADEL, None),
            "dak_zadel_schoorsteen": (H_ZADEL, lambda b, t: x_schoorsteen(b, t, 22, 14)),
            "dak_zadel_schild": (H_ZADEL_SCHILD, None),
            "dak_zadel_hoek": (H_ZADEL_HOEK, None),
            "dak_zadel_t": (H_ZADEL_T, None),
        }
        for _rn, (_hf, _ex) in roofs.items():
            register(base + _rn, pitched(_style, _style + _rn, _hf, _ex))
        for _g in ("trap", "klok", "hals", "tuit"):
            register(base + f"gevel_{_g}", gable_top(_style, _g))
        register(base + "dak_plat_kroonlijst_rand", flat_roof(_style, "v", kroonlijst=True))
        register(base + "dak_plat_kroonlijst_hoek", flat_roof(_style, "vr", kroonlijst=True))
        register(base + "dak_plat_midden", flat_roof(_style, ""))
    else:
        flat_sets = {"dak_plat_midden": "", "dak_plat_rand": "v", "dak_plat_hoek": "vr", "dak_plat_tegenover": "va",
                     "dak_plat_eind": "var", "dak_plat_los": "varl"}
        for _rn, _e in flat_sets.items():
            register(base + _rn, flat_roof(_style, _e))
        if fam == "kantoor":
            register(base + "dak_installatie", flat_roof(_style, "", x_installatie))
            register(base + "dak_installatie_rand", flat_roof(_style, "v", x_installatie))
        else:
            register(base + "dak_zonnepanelen", flat_roof(_style, "", x_zonnepanelen))
            register(base + "dak_lichtkoepel", flat_roof(_style, "", x_lichtkoepel))
            register(base + "dak_terras_rand", flat_roof(_style, "v", x_dakterras_plat))
