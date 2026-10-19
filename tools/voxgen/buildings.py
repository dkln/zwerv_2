"""Building tiles: modular blocks of 4 x 4 x 3 m (32 x 32 x 24 voxels).

Role in the pipeline: this module provides the building toolkit that the other
building modules (buildings2, buildings3, extras*) import -- the Bld drawing
class, the shared STYLES dict, wall colour functions (brick / planks / panels),
make_block, the pitched / flat roof builders and the gable tops -- and it
registers the tiles of the eight base styles (klassiek_*, modern_*, kantoor_*).
generate.py imports it and writes every registered tile to <OUT>/<path>.vox.

Every block sits in the middle of a 48 x 48 canvas (W) at offset O = 8, so
balconies, awnings, stoops and gutters may stick out up to 1 m (8 voxels)
beyond the block without moving the pivot. The front facade is the y = O side
(Godot +Z); 1 voxel = 12.5 cm, z is up.

Tile naming:  gebouwen/<style>/<style>_<part>
  bg_*    ground floor        verd_*  upper storey       dak_*   roofs
  *_hoek  corner block with a facade on the front and the right side
Roofs:
  dak_schuin              half roof: gutter at the front, ridge at the back
                          (two rows back to back = a gable roof 2 tiles deep)
  dak_schuin_hoek_buiten  hip (outer corner of a city block / hipped end)
  dak_schuin_hoek_binnen  valley (inner corner of a city block)
  dak_zadel*              complete roof over 1 tile depth (ridge in the middle)
"""
import math

from common import register, text_pixels
from palette import P
from vox import V, mix, pick, h

W = 48     # canvas width/depth in voxels
O = 8      # offset of the 32x32 block inside the canvas (room for overhangs)
S = 32     # block width/depth in voxels (4 m)
HGT = 24   # storey height in voxels (3 m)


# ------------------------------------------------------------------ wall colour functions
# Each returns f(x, y, z) -> palette index. u = x + y runs along both a front
# (x varies) and a side facade (y varies), so the pattern works on every face.

def brick(names, seed, weights=(4, 4, 3, 2, 1)):
    """Brick bond: 3-voxel stones, every other course shifted by 2."""
    w = list(weights)[: len(names)]

    def f(x, y, z):
        u = x + y
        off = (z % 2) * 2
        return pick(list(names), (u + off) // 3, z, 0, seed, w)
    return f


def planks(names, seed):
    """Vertical wooden boarding: 2-voxel planks with a dark joint every 3rd voxel."""
    def f(x, y, z):
        u = x + y
        if u % 3 == 2:
            return P["hout_donker1"]
        return pick(list(names), u // 3, z // 16, 0, seed)
    return f


def panels(names, seed, seam="beton_donker", every=16):
    """Facade panels of `every` x 12 voxels separated by `seam`-coloured joints."""
    def f(x, y, z):
        u = x + y
        if u % every == 0 or z % 12 == 0:
            return P[seam]
        return pick(list(names), u // every, z // 12, 0, seed)
    return f


# ------------------------------------------------------------------ styles
# STYLES maps a style name (also the tile folder name) to a dict of materials.
# Colours are palette names or colour functions. Keys:
#   family     "klassiek" / "modern" / "kantoor" / ... : picks facade set and details
#   wall       facade material (colour function)
#   frame      window/door frame colour      doors    list of door colours
#   plinth     plinth colour                 trim     sills, lintels, cornices
#   glass      window glass                  shutter  shutter colour (klassiek)
#   shop       shopfront frame colour        accent   accent cladding (modern)
#   roof       tuple of roof colours: [0]/[1] alternate per row, [-1] sprinkled
#   optional (flat_roof / other modules): roof_deck (flat roof surface, default
#   roof), cap (parapet coping), roof_edge (parapet height, default 3), fascia
#   (outer parapet cladding), panels (coloured panel list, buildings2).
# Other modules add their own entries to this shared dict.
STYLES = {
    "klassiek_rood": dict(family="klassiek", wall=brick(["baksteen1", "baksteen2", "baksteen3", "baksteen4", "baksteen5"], 1),
                          frame="kozijn_wit", doors=["deur_groen", "deur_zwart", "deur_rood", "deur_blauw"],
                          plinth="natuursteen2", trim="natuursteen1", roof=("pan_rood1", "pan_rood2", "pan_rood3"),
                          shutter="kozijn_groen", glass="glas1", shop="kozijn_groen"),
    "klassiek_donker": dict(family="klassiek", wall=brick(["donkersteen1", "donkersteen2", "donkersteen3"], 2, (3, 2, 2)),
                            frame="kozijn_creme", doors=["deur_zwart", "deur_groen", "deur_wit"],
                            plinth="natuursteen3", trim="natuursteen1", roof=("pan_zwart1", "pan_zwart2", "pan_zwart3"),
                            shutter="deur_rood", glass="glas2", shop="kozijn_zwart"),
    "klassiek_geel": dict(family="klassiek", wall=brick(["geelsteen1", "geelsteen2", "geelsteen3"], 3, (3, 2, 2)),
                          frame="kozijn_wit", doors=["deur_groen", "deur_blauw", "deur_zwart"],
                          plinth="natuursteen3", trim="natuursteen1", roof=("leisteen1", "leisteen2", "leisteen1"),
                          shutter="kozijn_groen", glass="glas1", shop="deur_blauw"),
    "modern_wit": dict(family="modern", wall=mix("stuc1", "stuc2", "stuc3", seed=4, weights=[5, 3, 1]),
                       frame="antraciet1", doors=["hout1", "antraciet2", "hout2"], plinth="antraciet2",
                       trim="hout2", roof=("dakgrind1", "dakgrind2"), glass="glas2", shop="antraciet1", accent=planks(["hout1", "hout2", "hout3"], 5)),
    "modern_donker": dict(family="modern", wall=brick(["donkersteen1", "donkersteen2", "antraciet2"], 6, (3, 3, 1)),
                          frame="antraciet3", doors=["hout2", "hout1", "antraciet1"], plinth="beton_donker",
                          trim="hout1", roof=("dakgrind1", "dakgrind2"), glass="glas2", shop="antraciet3", accent=planks(["hout1", "hout2", "hout3"], 7)),
    "modern_hout": dict(family="modern", wall=planks(["hout1", "hout2", "hout3"], 8),
                        frame="antraciet1", doors=["antraciet2", "hout_donker1"], plinth="beton_donker",
                        trim="antraciet2", roof=("dakgrind1", "dakgrind2"), glass="glas1", shop="antraciet1", accent=mix("stuc1", "stuc2", seed=9)),
    "kantoor_glas": dict(family="kantoor", wall=panels(["paneel1", "paneel2", "paneel3"], 10, "antraciet1"),
                         frame="metaal3", doors=["metaal3"], plinth="antraciet1", trim="metaal3",
                         roof=("bitumen1", "bitumen2"), glass="glas_kantoor", shop="metaal3"),
    "kantoor_beton": dict(family="kantoor", wall=panels(["beton1", "beton2", "beton3"], 11),
                          frame="antraciet1", doors=["antraciet1"], plinth="beton_donker", trim="antraciet1",
                          roof=("bitumen1", "bitumen2"), glass="glas2", shop="antraciet1"),
}

# Shop sign texts (data: rendered into the tiles).
SHOP_WORDS = ["BAKKER", "KAAS", "CAFE", "BLOEM", "FIETS", "BOEKEN", "SNACK", "SLAGER", "KAPPER", "BRIL", "WINKEL", "THEE"]


def fp(face, u, d):
    """Map facade coordinates to canvas (x, y).

    face: "v" front (y = O side), "r" right (x = O+S-1), "a" back (y = O+S-1),
    "l" left (x = O). u runs 0..S-1 along the facade, left to right as seen
    from outside. d is the depth: 0 = outer wall layer, d > 0 goes into the
    block, d < 0 sticks out of the facade (balconies, sills, awnings).
    """
    if face == "v":
        return O + u, O + d
    if face == "r":
        return O + S - 1 - d, O + u
    if face == "a":
        return O + S - 1 - u, O + S - 1 - d
    return O + d, O + S - 1 - u  # l


class Bld:
    """Drawing helper for one building tile.

    self.m is a V(W, W, hgt) model: a 48 x 48 canvas with the 32 x 32 block at
    offset O (see module docstring). Facade helpers take a face letter
    ("v"/"r"/"a"/"l" = front/right/back/left) and facade coordinates
    (u along the facade, z up, d depth; see fp()).

    self.st is the STYLES entry for `style` (materials, see STYLES). self.seed
    is a deterministic hash of `name` (the block name, e.g. built by make_block
    from the style and the facade functions), so every block gets its own but
    reproducible door colours, lit windows, shop texts, etc.
    """

    def __init__(self, style, name, hgt=HGT):
        self.m = V(W, W, hgt)
        self.st = STYLES[style]
        self.style = style
        self.seed = sum(ord(c) * (i + 1) for i, c in enumerate(name)) % 9973

    def body(self, z0=0, z1=HGT):
        """Fill the solid block from z0 to z1 with the wall material."""
        self.m.box(O, O, z0, O + S, O + S, z1, self.st["wall"])
        # floor/roof slab on top, so a block without a roof still looks tidy
        self.m.box(O + 1, O + 1, z1 - 1, O + S - 1, O + S - 1, z1, mix("beton2", "beton_donker", seed=91))

    def put(self, face, u, z, d, c):
        """Set one voxel in facade coordinates."""
        x, y = fp(face, u, d)
        self.m.set(x, y, z, c)

    def rect(self, face, u0, u1, z0, z1, d0, d1, c):
        """Fill the facade box [u0, u1) x [z0, z1) x [d0, d1) with c (0 = empty)."""
        for z in range(z0, z1):
            for d in range(d0, d1):
                for u in range(u0, u1):
                    self.put(face, u, z, d, c)

    # ------------------------------------------------------------ components
    def interior(self, face, u0, u1, z0, z1, d, key, office=False):
        """Room behind a window at depth d; `key` decides whether the room is lit."""
        r = h(self.seed, key, 1, 77)
        lit = r < (0.45 if office else 0.3)
        for z in range(z0, z1):
            for u in range(u0, u1):
                if office:
                    if z == z1 - 1 and lit and u % 4 in (1, 2):
                        c = "licht_wit"       # ceiling lights
                    elif z < z0 + 3 and u % 6 in (2, 3, 4):
                        c = "paneel2"         # desks
                    else:
                        c = "interieur3"
                elif lit and z >= (z0 + z1) // 2:
                    c = "licht_warm" if h(u, z, key, 80) < 0.6 else "interieur2"
                else:
                    c = "interieur1" if (u + z) % 3 else "interieur2"
                self.put(face, u, z, d, c)

    def window(self, face, u0, z0, w, hh, muntins=False, sill=True, lintel=True, shutters=False,
               frame=None, d0=0, sill_c=None, office=False):
        """Window of w x hh voxels with its bottom-left at (u0, z0).

        Cuts a 3-deep opening from depth d0, draws the frame at d0+1, glass at
        d0+2 and the interior at d0+3. Options: muntins (glazing bars), sill
        (sill_c, default trim), lintel (klassiek adds a keystone), shutters,
        frame colour override. `office` is accepted for compatibility but unused.
        """
        fr = frame or self.st["frame"]
        self.rect(face, u0, u0 + w, z0, z0 + hh, d0, d0 + 3, 0)
        for u in range(u0, u0 + w):
            self.put(face, u, z0, d0 + 1, fr)
            self.put(face, u, z0 + hh - 1, d0 + 1, fr)
        for z in range(z0, z0 + hh):
            self.put(face, u0, z, d0 + 1, fr)
            self.put(face, u0 + w - 1, z, d0 + 1, fr)
        self.rect(face, u0 + 1, u0 + w - 1, z0 + 1, z0 + hh - 1, d0 + 2, d0 + 3, self.st["glass"])
        self.interior(face, u0 + 1, u0 + w - 1, z0 + 1, z0 + hh - 1, d0 + 3, u0 * 31 + z0 * 7 + ord(face))
        if muntins:
            mid = u0 + w // 2
            if w >= 6:
                for z in range(z0, z0 + hh):
                    self.put(face, mid, z, d0 + 1, fr)
            for frac in (1 / 3, 2 / 3) if hh >= 12 else (0.5,):
                zz = z0 + int(hh * frac)
                for u in range(u0, u0 + w):
                    self.put(face, u, zz, d0 + 1, fr)
        if sill:
            sc = sill_c or self.st["trim"]
            self.rect(face, u0 - 1, u0 + w + 1, z0 - 1, z0, d0 - 1, d0 + 1, sc)
        if lintel:
            self.rect(face, u0 - 1, u0 + w + 1, z0 + hh, z0 + hh + 1, d0, d0 + 1, self.st["trim"])
            if self.st["family"] == "klassiek":
                # keystone (2 wide for even widths)
                self.put(face, u0 + w // 2, z0 + hh, d0 - 1, self.st["trim"])
                if w % 2 == 0:
                    self.put(face, u0 + w // 2 - 1, z0 + hh, d0 - 1, self.st["trim"])
        if shutters:
            lc = self.st["shutter"]
            for u in list(range(u0 - 4, u0 - 1)) + list(range(u0 + w + 1, u0 + w + 4)):
                for z in range(z0, z0 + hh):
                    edge = u in (u0 - 4, u0 - 2, u0 + w + 1, u0 + w + 3) or z in (z0, z0 + hh - 1)
                    diag = (z - z0) == (u - u0) % hh or (z - z0) == hh - 1 - ((u - u0) % hh)
                    self.put(face, u, z, d0 - 1, lc if (edge or not diag) else self.st["frame"])

    def door(self, face, u0, w, z0, hh, color=None, transom=True, steps=0, glass_panel=False):
        """Front door of w x hh voxels at (u0, z0).

        color defaults to a seeded pick from st["doors"]. transom adds a 3-high
        glass fanlight, glass_panel a glazed upper half (else a panelled door),
        steps adds that many stoop steps in front of the door.
        """
        fr = self.st["frame"]
        dc = color or pick(self.st["doors"], self.seed, u0, 0, 81)
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
            self.rect(face, u0 + 1, u0 + w - 1, top - 3, top, 2, 3, self.st["glass"])
            self.interior(face, u0 + 1, u0 + w - 1, top - 3, top, 3, u0 + 999)
            top -= 4
        self.rect(face, u0 + 1, u0 + w - 1, z0, top, 2, 3, dc)
        if glass_panel:
            self.rect(face, u0 + 2, u0 + w - 2, z0 + (top - z0) // 2, top - 1, 2, 3, self.st["glass"])
        else:
            # panelled door: recessed panels
            for z in range(z0 + 2, top - 1):
                for u in range(u0 + 2, u0 + w - 2):
                    if z != (z0 + top) // 2 and u != u0 + w // 2:
                        self.put(face, u, z, 3, dc)
                        self.put(face, u, z, 2, 0)
        # handle and letterbox
        self.put(face, u0 + w - 3, z0 + (top - z0) // 2, 1, "messing")
        self.put(face, u0 + w // 2, z0 + (top - z0) // 2 + 1, 1, "messing")
        step_c = self.st["trim"] if self.st["family"] == "klassiek" else "beton2"
        for i in range(steps):
            # step i: one voxel lower and two deeper outward than step i-1
            self.rect(face, u0 - 1, u0 + w + 1, 0, z0 - i, -1 - i * 2, -i * 2 + (1 if i == 0 else 0), step_c)

    def plinth(self, face, hh=2):
        """Plinth along the whole facade, hh high (sticks out 1 voxel for klassiek)."""
        self.rect(face, 0, S, 0, hh, -1 if self.st["family"] == "klassiek" else 0, 1, self.st["plinth"])

    def awning(self, face, u0, u1, ztop, depth, colors):
        """Sloping striped awning from ztop outward over `depth` voxels (stripes of 3)."""
        def stripe(u):
            return colors[(u // 3) % len(colors)]

        for d in range(1, depth + 1):
            z = ztop - (d - 1) // 2
            for u in range(u0, u1):
                self.put(face, u, z, -d, stripe(u))
        # front valance with a scalloped lower edge
        zl = ztop - (depth - 1) // 2
        for u in range(u0, u1):
            self.put(face, u, zl - 1, -depth, stripe(u))
            if u % 2 == 0:
                self.put(face, u, zl - 2, -depth, stripe(u))
        # side arms
        for u in (u0, u1 - 1):
            for d in range(1, depth + 1):
                self.put(face, u, ztop - (d - 1) // 2 - 1, -d, "metaal_donker")

    def sign(self, face, u0, u1, z0, z1, board, text, letter="bord_wit"):
        """Sign board [u0, u1) x [z0, z1) with `text` centred on it (5-voxel font)."""
        self.rect(face, u0, u1, z0, z1, -1, 1, board)
        px, (tw, th) = text_pixels(text)
        su = u0 + (u1 - u0 - tw) // 2
        sz = z0 + (z1 - z0 - 5) // 2
        for (c, r) in px:
            self.put(face, su + c, sz + 4 - r, -2, letter)

    def shopfront(self, face, text, awning_c=None):
        """Ground-floor shopfront: two display windows, glass door on the right,
        a sign with `text` above, and optionally an awning in colours awning_c."""
        st = self.st
        fr = st["shop"]
        self.rect(face, 1, 31, 0, 17, 0, 3, 0)
        self.rect(face, 1, 31, 0, 2, 0, 3, st["plinth"])
        for z in range(2, 17):
            for u in (1, 2, 11, 21, 29, 30):
                self.put(face, u, z, 1, fr)
        for u in range(1, 31):
            self.put(face, u, 16, 1, fr)
            self.put(face, u, 2, 1, fr)
        self.rect(face, 3, 11, 3, 16, 2, 3, st["glass"])
        self.rect(face, 12, 21, 3, 16, 2, 3, st["glass"])
        self.interior(face, 3, 21, 3, 16, 3, 500)
        # window display
        for u in range(3, 21):
            for z in range(3, 6):
                if h(u, z, self.seed, 82) < 0.5:
                    self.put(face, u, z, 3, pick(["bloem_rood", "bloem_geel", "luifel_wit", "hout1", "bloem_oranje", "luifel_blauw"], u, z, self.seed, 83))
            self.put(face, u, 13, 3, "licht_warm")
        # door
        self.rect(face, 22, 29, 0, 16, 2, 3, st["glass"])
        for z in range(0, 16):
            self.put(face, 22, z, 2, fr)
            self.put(face, 28, z, 2, fr)
        self.rect(face, 23, 28, 0, 15, 3, 4, "interieur2")
        self.put(face, 23, 8, 1, "rvs")
        self.sign(face, 1, 31, 17, 23, pick(["deur_groen", "deur_rood", "deur_blauw", "deur_zwart", "luifel_geel"], self.seed, 1, 0, 84), text,
                  "bord_wit")
        if awning_c:
            self.awning(face, 1, 31, 16, 7, awning_c)

    def balcony_modern(self, face):
        """Full-width 1 m deep concrete balcony with a glass balustrade and a
        planter, plus a storey-high glass sliding door behind it."""
        self.rect(face, 1, 31, 0, 2, -8, 0, "beton1")
        # glass balustrade (front and both sides) with a metal handrail
        self.rect(face, 1, 31, 2, 9, -8, -7, "glas_helder")
        self.rect(face, 1, 2, 2, 9, -8, 0, "glas_helder")
        self.rect(face, 30, 31, 2, 9, -8, 0, "glas_helder")
        self.rect(face, 1, 31, 9, 10, -8, -7, "metaal3")
        self.rect(face, 1, 2, 9, 10, -8, 0, "metaal3")
        self.rect(face, 30, 31, 9, 10, -8, 0, "metaal3")
        # planter
        self.rect(face, 3, 8, 2, 4, -7, -5, "antraciet2")
        self.rect(face, 3, 8, 4, 6, -7, -5, "blad2")
        self.window(face, 4, 2, 24, 19, sill=False, lintel=False)
        for z in range(2, 21):
            self.put(face, 16, z, 1, self.st["frame"])

    def railing(self, face, u0, u1, z0, z1, d, c="metaal_donker"):
        """Railing [u0, u1) x [z0, z1) at depth d: top and bottom rail, bars every 2."""
        for u in range(u0, u1):
            self.put(face, u, z1 - 1, d, c)
            if (u - u0) % 2 == 0:
                for z in range(z0, z1):
                    self.put(face, u, z, d, c)
            self.put(face, u, z0, d, c)


# ------------------------------------------------------------------ facade designs
# Each function f(b, face) draws one facade on face `face` of Bld b. Their
# __name__ seeds the block (see LEGACY_SEED_NAMES), so do not rename them.

def f_classic_gf_door(b, face):
    b.plinth(face)
    b.door(face, 3, 8, 2, 21, steps=2)
    b.window(face, 15, 5, 14, 15, muntins=True)


def f_classic_gf_window(b, face):
    b.plinth(face)
    b.window(face, 3, 5, 10, 15, muntins=True)
    b.window(face, 19, 5, 10, 15, muntins=True)


def f_classic_up_window(b, face):
    b.window(face, 4, 5, 9, 15, muntins=True)
    b.window(face, 19, 5, 9, 15, muntins=True)


def f_classic_up_shutters(b, face):
    b.window(face, 6, 5, 7, 14, muntins=True, shutters=True)
    b.window(face, 20, 5, 7, 14, muntins=True, shutters=True)


def f_classic_up_three(b, face):
    for u in (3, 12, 21):
        b.window(face, u, 5, 7, 15, muntins=True)


def f_classic_up_balcony(b, face):
    """Two French windows with a small balcony ledge and railing."""
    for u in (4, 19):
        b.window(face, u, 2, 9, 19, muntins=True, sill=False)
        b.rect(face, u - 1, u + 10, 1, 2, -1, 1, b.st["trim"])
        b.railing(face, u - 1, u + 10, 2, 9, -1)


def f_classic_up_bay(b, face):
    """Bay window sticking out 4 voxels, zinc-covered."""
    b.rect(face, 5, 27, 1, 22, -4, 0, b.st["wall"])
    b.rect(face, 4, 28, 0, 1, -5, 0, b.st["trim"])
    b.rect(face, 4, 28, 22, 23, -5, 0, "zink1")
    b.window(face, 7, 4, 8, 16, muntins=True, d0=-4, sill=False)
    b.window(face, 17, 4, 8, 16, muntins=True, d0=-4, sill=False)


def f_classic_up_blank(b, face):
    """Mostly blank wall: two cross-shaped wall anchors and one small window."""
    for u in (6, 25):
        for k in (-1, 0, 1):
            b.put(face, u + k, 20, -1, "metaal_donker")
            b.put(face, u, 20 + k, -1, "metaal_donker")
    b.window(face, 13, 9, 6, 7, muntins=True)


def _in_arch(u, z, a2, b2):
    """True inside a gateway of width 2*sqrt(a2) centred on u = 16: rectangular
    below z = 14, elliptical arch (vertical radius sqrt(b2)) above."""
    dx = u + 0.5 - 16
    return z < 14 or (dx * dx) / a2 + ((z - 13.5) ** 2) / b2 < 1.0


def f_classic_gf_gate(b, face):
    """Arched gateway right through the block, cobbled floor and a gate."""
    b.plinth(face)
    for z in range(0, 20):
        for u in range(8, 24):
            if _in_arch(u, z, 64.0, 36.0):
                for d in range(0, S):
                    b.put(face, u, z, d, 0)
    # trim ring around the arch
    for z in range(0, 20):
        for u in range(7, 25):
            if _in_arch(u, z, 81.0, 49.0) and not _in_arch(u, z, 64.0, 36.0):
                b.put(face, u, z, 0, b.st["trim"])
                b.put(face, u, z, -1, b.st["trim"])
    for d in range(0, S):
        for u in range(8, 24):
            b.put(face, u, 0, d, pick(["kei1", "kei2", "kei3"], u, d, 0, 85))
    # gate inside the passage
    b.railing(face, 8, 24, 1, 14, 2)


def shop_text(b):
    """Seeded shop sign word for block b."""
    return SHOP_WORDS[b.seed % len(SHOP_WORDS)]


def f_gf_shop(b, face):
    b.shopfront(face, shop_text(b))


def f_gf_shop_awning(b, face):
    cols = [["luifel_rood", "luifel_wit"], ["luifel_groen", "luifel_wit"], ["luifel_blauw", "luifel_wit"],
            ["luifel_geel", "luifel_oranje"]][b.seed % 4]
    b.shopfront(face, shop_text(b), cols)


def _mullions(b, face, z0, z1, us=(11, 20)):
    """Vertical frame bars at the given u positions, z0 <= z < z1, depth 1."""
    for z in range(z0, z1):
        for u in us:
            b.put(face, u, z, 1, b.st["frame"])


def f_modern_gf_door(b, face):
    b.plinth(face, 1)
    b.window(face, 2, 3, 15, 17, sill=False, lintel=False)
    b.rect(face, 18, 30, 0, 22, 0, 1, b.st["accent"])
    b.door(face, 21, 7, 0, 19, transom=False, glass_panel=True)
    b.rect(face, 19, 30, 19, 20, -3, 0, b.st["frame"])   # canopy
    b.put(face, 24, 16, -4, "lamp_wit")


def f_modern_gf_window(b, face):
    b.plinth(face, 1)
    b.window(face, 2, 3, 28, 18, sill=False, lintel=False)
    _mullions(b, face, 3, 21)


def f_modern_gf_garage(b, face):
    """Ribbed garage door."""
    b.plinth(face, 1)
    b.rect(face, 3, 29, 0, 16, 0, 3, 0)
    for z in range(0, 16):
        for u in range(3, 29):
            edge = u in (3, 28) or z == 15
            b.put(face, u, z, 1 if edge else 2, b.st["frame"] if edge else ("metaal1" if (z // 2) % 2 else "metaal2"))
    b.put(face, 16, 18, -1, "lamp_wit")


def f_modern_up_window(b, face):
    b.window(face, 3, 5, 11, 15, sill=True, lintel=False, sill_c="zink1")
    b.window(face, 18, 5, 11, 15, sill=True, lintel=False, sill_c="zink1")


def f_modern_up_wide(b, face):
    """Ribbon window on an accent-clad band."""
    b.rect(face, 1, 31, 4, 21, 0, 1, b.st["accent"])
    b.window(face, 2, 5, 28, 15, sill=False, lintel=False)
    _mullions(b, face, 5, 20)


def f_modern_up_balcony(b, face):
    b.balcony_modern(face)


def f_modern_up_french(b, face):
    """Two French windows with a glass Juliet balcony."""
    for u in (4, 19):
        b.window(face, u, 2, 9, 19, sill=False, lintel=False)
        b.rect(face, u, u + 9, 2, 8, -1, 0, "glas_helder")
        b.rect(face, u, u + 9, 8, 9, -1, 0, "metaal3")


def f_modern_up_blank(b, face):
    """Blank wall with one small window and a rain pipe."""
    b.window(face, 13, 10, 6, 6, sill=False, lintel=False)
    for z in range(2, 22, 2):
        b.put(face, 27, z, -1, "zink2")


def f_office_curtain_wall(b, face, z0=0, z1=23):
    """Curtain wall from z0 to z1: mullions every 8 voxels, a 4-voxel spandrel
    at the bottom and an office interior behind the glass."""
    st = b.st
    for z in range(z0, z1):
        for u in range(0, S):
            b.put(face, u, z, 0, 0)
            if u % 8 == 0 or u == S - 1:
                b.put(face, u, z, 0, st["frame"])
                b.put(face, u, z, -1, st["frame"])
            elif z < z0 + 4:
                b.put(face, u, z, 1, "antraciet2")
            else:
                b.put(face, u, z, 1, st["glass"])
    b.interior(face, 0, S, z0 + 4, z1, 2, z0 + 600, office=True)
    for u in range(0, S):
        b.put(face, u, z0 + 3, 0, st["frame"])
        b.put(face, u, z1, 0, st["frame"])
        b.put(face, u, z1, -1, st["frame"])


def f_office_band(b, face):
    """Horizontal strip window between two solid bands."""
    st = b.st
    band = "beton1" if b.style == "kantoor_beton" else "paneel3"
    b.rect(face, 0, S, 0, 7, -1, 1, band)
    b.rect(face, 0, S, 20, 24, -1, 1, band)
    for z in range(7, 20):
        for u in range(0, S):
            b.put(face, u, z, 0, st["frame"] if u % 4 == 0 else 0)
            b.put(face, u, z, 1, st["glass"])
    b.interior(face, 0, S, 7, 20, 2, 700, office=True)


def _office_gf_base(b, face):
    """Ground-floor curtain wall up to z = 20 with a solid band above it."""
    f_office_curtain_wall(b, face, 0, 20)
    b.rect(face, 0, S, 20, 24, -1, 1, b.st["frame"] if b.style == "kantoor_glas" else "beton1")


def f_office_gf_entrance(b, face):
    """Office entrance: glass double door, canopy with lights and a sign."""
    _office_gf_base(b, face)
    st = b.st
    b.rect(face, 9, 23, 0, 16, -1, 3, 0)
    for z in range(0, 16):
        for u in range(9, 23):
            edge = u in (9, 22) or z == 15
            seam = u in (15, 16)
            b.put(face, u, z, 1, st["frame"] if (edge or seam) else "glas_helder")
    b.rect(face, 10, 22, 0, 15, 3, 4, "interieur2")
    b.rect(face, 5, 27, 17, 19, -7, 0, "metaal3")
    for u in range(8, 25, 4):
        b.put(face, u, 16, -4, "lamp_wit")
    b.sign(face, 6, 26, 20, 24, "antraciet1", "ZWERVR", "lamp_wit")


def f_office_gf_glass(b, face):
    _office_gf_base(b, face)
    b.rect(face, 0, S, 0, 2, 0, 2, b.st["plinth"])


def f_office_blank(b, face):
    """Blank office wall: just the body (nothing extra drawn)."""


# Facade sets per family: part name (tile name suffix) -> facade function.
FAM_PIECES = {
    "klassiek": {
        "bg_deur": f_classic_gf_door,
        "bg_raam": f_classic_gf_window,
        "bg_winkel": f_gf_shop,
        "bg_winkel_luifel": f_gf_shop_awning,
        "bg_poort": f_classic_gf_gate,
        "verd_raam": f_classic_up_window,
        "verd_luiken": f_classic_up_shutters,
        "verd_drie_ramen": f_classic_up_three,
        "verd_balkon": f_classic_up_balcony,
        "verd_erker": f_classic_up_bay,
        "verd_dicht": f_classic_up_blank,
    },
    "modern": {
        "bg_deur": f_modern_gf_door,
        "bg_raam": f_modern_gf_window,
        "bg_garage": f_modern_gf_garage,
        "bg_winkel": f_gf_shop,
        "verd_raam": f_modern_up_window,
        "verd_raam_breed": f_modern_up_wide,
        "verd_balkon": f_modern_up_balcony,
        "verd_frans": f_modern_up_french,
        "verd_dicht": f_modern_up_blank,
    },
    "kantoor": {
        "bg_entree": f_office_gf_entrance,
        "bg_glas": f_office_gf_glass,
        "verd_vliesgevel": f_office_curtain_wall,
        "verd_band": f_office_band,
        "verd_dicht": f_office_blank,
    },
}

# corner variants: (tile name, front facade part, right facade part)
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


# The building RNG is seeded from the block name, which make_block builds from the
# __name__ of each facade function. These functions were renamed when the code was
# translated to English; this table maps them back to their original names so the
# generated tiles stay identical.
LEGACY_SEED_NAMES = {
    "apt_gf_entrance": "app_bg_entree",
    "apt_up_glass": "app_verd_glas",
    "apt_up_large": "app_verd_groot",
    "apt_up_loggia": "app_verd_loggia",
    "apt_up_panel": "app_verd_paneel",
    "apt_up_small": "app_verd_klein",
    "barn_gf_door": "schuur_bg_deur",
    "barn_gf_window": "schuur_bg_raam",
    "barn_hayloft": "schuur_hooi",
    "biz_blank": "bp_dicht",
    "biz_logo": "bp_logo",
    "biz_office": "bp_kantoor",
    "biz_roller_door": "bp_roldeur",
    "biz_rooflight": "bp_lichtstraat",
    "church_buttress": "kerk_steunbeer",
    "church_gf_lancet": "kerk_bg_spitsraam",
    "church_gf_portal": "kerk_bg_portaal",
    "church_tower_clock": "kerk_toren_klok",
    "church_tower_louvre": "kerk_toren_galmgat",
    "church_tower_portal": "kerk_toren_portaal",
    "church_tower_window": "kerk_toren_raam",
    "church_up_lancet": "kerk_verd_spitsraam",
    "church_up_rose": "kerk_verd_roos",
    "colonnade": "kolonnade",
    "f_classic_gf_door": "f_klassiek_bg_deur",
    "f_classic_gf_gate": "f_klassiek_bg_poort",
    "f_classic_gf_window": "f_klassiek_bg_raam",
    "f_classic_up_balcony": "f_klassiek_verd_balkon",
    "f_classic_up_bay": "f_klassiek_verd_erker",
    "f_classic_up_blank": "f_klassiek_verd_dicht",
    "f_classic_up_shutters": "f_klassiek_verd_luiken",
    "f_classic_up_three": "f_klassiek_verd_drie",
    "f_classic_up_window": "f_klassiek_verd_raam",
    "f_gf_shop": "f_bg_winkel",
    "f_gf_shop_awning": "f_bg_winkel_luifel",
    "f_modern_gf_door": "f_modern_bg_deur",
    "f_modern_gf_garage": "f_modern_bg_garage",
    "f_modern_gf_window": "f_modern_bg_raam",
    "f_modern_up_balcony": "f_modern_verd_balkon",
    "f_modern_up_blank": "f_modern_verd_dicht",
    "f_modern_up_french": "f_modern_verd_frans",
    "f_modern_up_wide": "f_modern_verd_breed",
    "f_modern_up_window": "f_modern_verd_raam",
    "f_office_band": "f_kantoor_band",
    "f_office_blank": "f_kantoor_dicht",
    "f_office_curtain_wall": "f_kantoor_vlies",
    "f_office_gf_entrance": "f_kantoor_bg_entree",
    "f_office_gf_glass": "f_kantoor_bg_glas",
    "fac_gate": "fab_poort",
    "fac_window_tall": "fab_raam_hoog",
    "flat_balconies": "flat_balkons",
    "flat_gable_end": "flat_kopgevel",
    "flat_gallery": "flat_galerij",
    "flat_gf_entrance": "flat_bg_entree",
    "flat_gf_storage": "flat_bg_bergingen",
    "flat_stairwell": "flat_trappenhuis",
    "gov_gf_entrance": "overheid_bg_entree",
    "gov_up_balcony": "overheid_verd_balkon",
    "gov_up_window_tall": "overheid_verd_raam_hoog",
    "h1600_gf_door": "h1600_bg_deur",
    "h1600_gf_window": "h1600_bg_raam",
    "h1600_up_balcony": "h1600_verd_balkon",
    "h1600_up_window": "h1600_verd_raam",
    "h1900_gf_door": "h1900_bg_deur",
    "h1900_gf_window_arch": "h1900_bg_raam_boog",
    "h1900_up_bay": "h1900_verd_erker",
    "h1900_up_window_arch": "h1900_verd_raam_boog",
    "hs_entrance": "hs_entree",
    "hs_louvres": "hs_lamellen",
    "ind_blank": "ind_dicht",
    "ind_office": "ind_kantoor",
    "ind_roller_door": "ind_roldeur",
    "ind_rooflight": "ind_lichtstraat",
    "ind_side_door": "ind_loopdeur",
    "ind_wall": "ind_wand",
    "lx_glass": "lx_glas",
    "lx_terrace": "lx_terras",
    "mc_gf_columns": "mk_bg_zuilen",
    "mc_gf_window_arch": "mk_bg_raam_boog",
    "mc_up_relief": "mk_verd_relief",
    "mc_up_window_arch": "mk_verd_raam_boog",
    "mch_gf_entrance": "km_bg_entree",
    "mch_up_cross": "km_verd_kruis",
    "mch_up_slit": "km_verd_spleet",
    "mm_gf_entrance": "mm_bg_entree",
    "mm_up_blank": "mm_verd_dicht",
    "mm_up_light_strip": "mm_verd_lichtstrook",
    "o2000_sun_shading": "k2000_zonwering",
    "o80_mirror_band": "k80_spiegelband",
    "office_large": "kantoor_groot",
    "office_small": "kantoor_klein",
    "om_louvres": "kmodern_lamellen",
    "school_gf_entrance": "school_bg_entree",
    "school_gf_window": "school_bg_raam",
    "school_up_window": "school_verd_raam",
    "uni_portal": "uni_portaal",
    "uni_up_tall": "uni_verd_hoog",
    "uni_up_window": "uni_verd_raam",
    "uni_window_arch": "uni_raam_boog",
    "y30_gf_porch": "j30_bg_portiek",
    "y30_gf_window": "j30_bg_raam",
    "y30_up_balcony": "j30_verd_balkon",
    "y30_up_bay": "j30_verd_erker",
    "y30_up_stairwell": "j30_verd_trappenhuis",
    "y30_up_window": "j30_verd_raam",
    "y60_gallery_door": "j60_galerij_deur",
    "y60_gallery_window": "j60_galerij_raam",
    "y60_gf_bay": "j60_bg_erker",
    "y60_gf_door": "j60_bg_deur",
    "y60_gf_storage": "j60_bg_berging",
    "y60_gf_window": "j60_bg_raam",
    "y60_up_balcony": "j60_verd_balkon",
    "y60_up_window": "j60_verd_raam",
    "y60_up_window_small": "j60_verd_raam_klein",
}


def seed_name(fn):
    """Name of a facade function as used for seeding (see LEGACY_SEED_NAMES)."""
    return LEGACY_SEED_NAMES.get(fn.__name__, fn.__name__)


def make_block(style, pieces):
    """Return a tile function for a one-storey block of `style`.

    pieces: list of (face, facade function) pairs, drawn in order on top of the
    solid body. The block name (and thus the seed) is the style followed by
    face letter + seed_name(function) for every piece.
    """
    def fn():
        name = style + "".join(p[0] + seed_name(p[1]) for p in pieces)
        b = Bld(style, name)
        b.body()
        for face, f in pieces:
            f(b, face)
        return b.m
    return fn


# ------------------------------------------------------------------ roofs

def roof_colors(b, H, x, y):
    """Roof colour at roof height H: [0]/[1] alternate per 2-unit row, with a
    sprinkling (12 %) of the last colour."""
    names = b.st["roof"]
    row = int(H) // 2
    base = names[row % 2] if len(names) > 1 else names[0]
    if h(x, y, row, b.seed) < 0.12:
        base = names[-1]
    return base


def pitched(style, name, Hfun, extra=None, hgt=32):
    """Return a tile function for a pitched roof on top of a block.

    Hfun(px, py) -> height in 'tile units' (0..32) at block coords px, py
    (cell centres, 0..S); 32 = ridge (24 voxels, one unit = 0.75 voxel).
    Negative heights leave the column empty except for 1 voxel. The top two
    voxels of each column get roof colours, the rest the wall material.
    extra(b, tops) can add details; tops maps (lx, ly) -> (top z, H).
    """
    def fn():
        b = Bld(style, name, hgt)
        m = b.m
        ridge_c = "pan_zwart3" if b.st["roof"][0].startswith("pan_rood") else "zink2"
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
                            c = ridge_c   # ridge tiles
                    else:
                        c = b.st["wall"]
                    m.set(O + lx, O + ly, z, c)
        # gutter / overhang along the low (eaves) edges of the block
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


# Roof extras for pitched(): f(b, tops), coordinates lx, ly relative to the block.

def x_dormer(b, tops):
    """Dormer on the front slope with a window."""
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
            m.set(O + lx, O + 6, z, b.st["glass"])
            m.set(O + lx, O + 7, z, "interieur1" if (lx + z) % 4 else "licht_warm")
    for z in range(8, 14):
        m.set(O + 16, O + 6, z, "kozijn_wit")


def x_chimney(b, tops, lx0=22, ly0=20):
    """4x4 brick chimney with its corner at (lx0, ly0), 30 voxels high."""
    m = b.m
    chimney_brick = brick(["baksteen2", "baksteen4", "donkersteen1"], 12)
    for ly in range(ly0, ly0 + 4):
        for lx in range(lx0, lx0 + 4):
            for z in range(0, 30):
                m.set(O + lx, O + ly, z, chimney_brick)
    for ly in range(ly0 - 1, ly0 + 5):
        for lx in range(lx0 - 1, lx0 + 5):
            m.set(O + lx, O + ly, 30, "natuursteen2")
    m.set(O + lx0 + 1, O + ly0 + 1, 30, "interieur3")
    m.set(O + lx0 + 2, O + ly0 + 2, 30, "interieur3")


def x_chimney_mid(b, tops):
    """Chimney on the ridge of a gable roof (dak_zadel)."""
    x_chimney(b, tops, 22, 14)


def x_skylight(b, tops):
    """Roof window flush with the slope."""
    m = b.m
    for ly in range(8, 18):
        for lx in range(10, 18):
            zt = tops[(lx, ly)][0]
            edge = lx in (10, 17) or ly in (8, 17)
            m.set(O + lx, O + ly, zt - 1, "antraciet1" if edge else b.st["glass"])


def x_solar_panels_pitched(b, tops):
    """Solar panels laid on the slope, one voxel above the roof surface."""
    m = b.m
    for ly in range(4, 28):
        for lx in range(3, 29):
            zt = tops[(lx, ly)][0]
            c = "metaal3" if lx % 9 == 2 or ly % 8 == 3 else "zonnepaneel"
            m.set(O + lx, O + ly, zt, c)


def x_roof_terrace(b, tops):
    """Pitched roof partly cut open for a roof terrace."""
    m = b.m
    for ly in range(0, 16):
        for lx in range(10, 24):
            for z in range(1, 32):
                m.set(O + lx, O + ly, z, 0)
            m.set(O + lx, O + ly, 0, pick(["hout1", "hout2", "hout3"], lx // 4, ly, 0, 86))
    # side cheeks
    for ly in range(0, 16):
        for lx in (9, 24):
            for z in range(1, tops[(lx, ly)][0]):
                m.set(O + lx, O + ly, z, b.st["wall"])
    # back wall with a door
    for lx in range(10, 24):
        for z in range(1, tops[(lx, 16)][0]):
            m.set(O + lx, O + 16, z, b.st["wall"])
    for lx in range(13, 21):
        for z in range(1, 11):
            m.set(O + lx, O + 16, z, b.st["glass"] if lx not in (13, 20, 17) and z < 10 else "kozijn_wit")
            m.set(O + lx, O + 17, z, "interieur1")
    # railing
    for lx in range(10, 24):
        m.set(O + lx, O + 0, 6, "metaal_donker")
        if lx % 2 == 0:
            for z in range(1, 6):
                m.set(O + lx, O + 0, z, "metaal_donker")


def x_half_flat(b, tops):
    """Right half replaced by a flat roof with a parapet."""
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


# Roof height functions for pitched(): (px, py) in block coords 0..S -> tile units.
H_SLOPE = lambda px, py: py                                       # rises from front to back
H_CORNER_OUT = lambda px, py: min(py, S - px)                     # hip (outer corner)
H_CORNER_IN = lambda px, py: max(py, S - px)                      # valley (inner corner)
H_GABLE = lambda px, py: 2 * min(py, S - py)                      # ridge left-right in the middle
H_GABLE_HIP = lambda px, py: 2 * min(py, S - py, S - px)          # gable with a hipped right end
H_GABLE_CORNER = lambda px, py: 2 * min(py, S - px, max(S - py, px))   # L-shaped ridge
H_GABLE_T = lambda px, py: 2 * max(min(py, S - py), min(px, S - px) if py > S / 2 else 0)  # T-shaped ridge


def flat_roof(style, edges, extra=None, cornice=False):
    """Return a tile function for a flat roof slab (16 voxels high canvas).

    edges: string of face letters that get a parapet (wall material, height
    st["roof_edge"] (default 3), coping st["cap"], optional st["fascia"]).
    cornice adds a classical white cornice on those edges. extra(b) can add
    roof equipment.
    """
    def fn():
        b = Bld(style, "dak_plat" + edges + str(cornice), 16)
        m = b.m
        family = b.st["family"]
        floor = b.st.get("roof_deck", b.st["roof"])
        for ly in range(S):
            for lx in range(S):
                m.set(O + lx, O + ly, 0, pick(list(floor), lx // 2, ly // 2, 0, 88))
        cap = b.st.get("cap") or ("metaal3" if family == "kantoor" else "zink1")
        ph = b.st.get("roof_edge", 3)
        for face in edges:
            for u in range(S):
                for d in range(0, 2):
                    for z in range(0, ph):
                        b.put(face, u, z, d, b.st["wall"])
                    b.put(face, u, ph, d, cap)
                if b.st.get("fascia"):
                    for z in range(0, ph + 1):
                        b.put(face, u, z, -1, b.st["fascia"])
            if cornice:
                for u in range(S):
                    b.rect(face, u, u + 1, 0, 1, -2, 0, "kozijn_wit")
                    if u % 2 == 0:
                        b.put(face, u, 1, -1, "kozijn_wit")   # dentils
                    b.rect(face, u, u + 1, 2, 4, -2, 0, "kozijn_wit")
                    b.put(face, u, 4, -1, "kozijn_wit")
                    b.put(face, u, 4, 0, "kozijn_wit")
        if extra:
            extra(b)
        return m
    return fn


# Roof extras for flat_roof(): f(b), drawn from z = 1 on the roof slab.

def x_hvac(b):
    """Air handling unit with fans, a second box and a duct."""
    m = b.m
    m.box(O + 6, O + 8, 1, O + 20, O + 22, 7, "metaal1")
    for lx in range(7, 19, 4):
        m.cyl(O + lx + 1.5, O + 15, 1.5, 7, 8, "metaal_donker")
    m.box(O + 22, O + 6, 1, O + 28, O + 12, 4, "metaal2")
    for i in range(8):
        m.set(O + 6 + i, O + 23, 1, "metaal2")


def x_solar_panels(b):
    """Three rows of tilted solar panels."""
    m = b.m
    for row in range(3):
        y0 = O + 5 + row * 8
        for ly in range(5):
            z = 1 + ly // 2
            for lx in range(4, 28):
                m.set(O + lx, y0 + ly, z, "metaal3" if lx % 8 == 3 else "zonnepaneel")
            m.set(O + 4, y0 + ly, 1, "metaal2")


def x_dome_light(b):
    """Stepped glass roof light."""
    m = b.m
    m.box(O + 10, O + 10, 1, O + 22, O + 22, 3, "stuc1")
    m.box(O + 11, O + 11, 3, O + 21, O + 21, 4, "glas_helder")
    m.box(O + 13, O + 13, 4, O + 19, O + 19, 5, "glas_helder")


def x_roof_terrace_flat(b):
    """Wooden deck with a planter (and shrub) and a bench."""
    m = b.m
    for ly in range(4, 28):
        for lx in range(4, 28):
            m.set(O + lx, O + ly, 1, pick(["hout1", "hout2", "hout3"], lx // 4, ly, 0, 89))
    m.box(O + 5, O + 22, 2, O + 9, O + 26, 5, "antraciet2")
    m.ellipsoid(O + 7, O + 24, 7, 3, 3, 3, mix("blad1", "blad2", "blad4", seed=90))
    m.box(O + 14, O + 10, 2, O + 22, O + 12, 4, "hout2")


# ------------------------------------------------------------------ canal house gables (top)

def gable_top(style, kind):
    """Return a tile function for a canal-house gable top on a block.

    A gable roof with its ridge running front-to-back, closed at the front by a
    gable of type kind: "trap" (stepped), "tuit" (spout), "klok" (bell) or
    "hals" (neck). Includes two windows and a hoisting beam.
    """
    def fn():
        b = Bld(style, "gevel" + kind, 32)
        m = b.m
        st = b.st
        # gable roof with the ridge running front to back (along y)
        for ly in range(2, S):
            for lx in range(S):
                H = 2 * min(lx + 0.5, S - lx - 0.5)
                zt = max(1, int(math.ceil(H * 0.75)))
                for z in range(zt):
                    m.set(O + lx, O + ly, z, roof_colors(b, H, ly, lx) if z >= zt - 2 else st["wall"])

        def width(z):
            """Half width of the gable at height z (0 = above the gable)."""
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

        # shape[(lx, z)]: is this cell inside the gable outline?
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
                m.set(O + lx, O + d, z, st["trim"] if (edge and d == 0 and kind != "tuit") else st["wall"])
            if edge and kind == "trap" and z % 2 == 0:
                m.set(O + lx, O - 1, z, st["trim"])
        if kind == "tuit":
            # spout gable: trim only along the top outline
            for (lx, z), inside in shape.items():
                if inside and not shape.get((lx, z + 1), False):
                    m.set(O + lx, O, z, st["trim"])
                    m.set(O + lx, O - 1, z, st["trim"])
        # windows in the gable
        b.window("v", 11, 3, 10, 12, muntins=True)
        b.window("v", 14, 18, 4, 5, muntins=False, sill=False)
        # hoisting beam with hook
        for d in range(-6, 0):
            m.set(O + 16, O + d, 24, "hout_donker2")
            m.set(O + 15, O + d, 24, "hout_donker2")
        m.set(O + 16, O - 6, 23, "metaal_donker")
        m.set(O + 16, O - 6, 22, "metaal_donker")
        # crowning
        top = max(z for (lx, z), v in shape.items() if v)
        m.set(O + 15, O, top + 1, st["trim"])
        m.set(O + 16, O, top + 1, st["trim"])
        return m
    return fn


# ------------------------------------------------------------------ registration

# Pitched roofs of the klassiek family: tile suffix -> (height function, extra).
CLASSIC_PITCHED_ROOFS = {
    "dak_schuin": (H_SLOPE, None),
    "dak_schuin_hoek_buiten": (H_CORNER_OUT, None),
    "dak_schuin_hoek_binnen": (H_CORNER_IN, None),
    "dak_schuin_dakkapel": (H_SLOPE, x_dormer),
    "dak_schuin_schoorsteen": (H_SLOPE, x_chimney),
    "dak_schuin_dakraam": (H_SLOPE, x_skylight),
    "dak_schuin_zonnepanelen": (H_SLOPE, x_solar_panels_pitched),
    "dak_schuin_dakterras": (H_SLOPE, x_roof_terrace),
    "dak_schuin_half_plat": (H_SLOPE, x_half_flat),
    "dak_zadel": (H_GABLE, None),
    "dak_zadel_schoorsteen": (H_GABLE, x_chimney_mid),
    "dak_zadel_schild": (H_GABLE_HIP, None),
    "dak_zadel_hoek": (H_GABLE_CORNER, None),
    "dak_zadel_t": (H_GABLE_T, None),
}

# Flat roofs of the other families: tile suffix -> parapet edges.
FLAT_ROOF_EDGES = {"dak_plat_midden": "", "dak_plat_rand": "v", "dak_plat_hoek": "vr", "dak_plat_tegenover": "va",
                   "dak_plat_eind": "var", "dak_plat_los": "varl"}


def _register_style(style, family):
    """Register all blocks, corners and roofs of one base style."""
    base = f"gebouwen/{style}/{style}_"
    pieces = FAM_PIECES[family]
    for name, f in pieces.items():
        register(base + name, make_block(style, [("v", f)]))
    for name, front, right in FAM_CORNERS[family]:
        register(base + name, make_block(style, [("v", pieces[front]), ("r", pieces[right])]))
    # inner corner (only back-left facades visible in city blocks) = ordinary blocks rotated
    register(base + "blok_dicht", make_block(style, []))

    if family == "klassiek":
        for rn, (hf, ex) in CLASSIC_PITCHED_ROOFS.items():
            register(base + rn, pitched(style, style + rn, hf, ex))
        for g in ("trap", "klok", "hals", "tuit"):
            register(base + f"gevel_{g}", gable_top(style, g))
        register(base + "dak_plat_kroonlijst_rand", flat_roof(style, "v", cornice=True))
        register(base + "dak_plat_kroonlijst_hoek", flat_roof(style, "vr", cornice=True))
        register(base + "dak_plat_midden", flat_roof(style, ""))
    else:
        for rn, e in FLAT_ROOF_EDGES.items():
            register(base + rn, flat_roof(style, e))
        if family == "kantoor":
            register(base + "dak_installatie", flat_roof(style, "", x_hvac))
            register(base + "dak_installatie_rand", flat_roof(style, "v", x_hvac))
        else:
            register(base + "dak_zonnepanelen", flat_roof(style, "", x_solar_panels))
            register(base + "dak_lichtkoepel", flat_roof(style, "", x_dome_light))
            register(base + "dak_terras_rand", flat_roof(style, "v", x_roof_terrace_flat))


for _style, _st in list(STYLES.items()):
    _register_style(_style, _st["family"])
