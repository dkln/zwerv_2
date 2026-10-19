"""Extension 6: university, college (hogeschool) and offices with a front colonnade.

Adds the building styles ``universiteit`` (classic brick + natural stone, arched windows,
portico, roof turret) and ``hogeschool`` (modern glass with coloured louvres) to the shared
buildings.STYLES dict and registers their facade blocks and roofs via buildings2.reg_style
(``gebouwen/<style>/<style>_<piece>`` tiles). It also adds a recessed colonnade ground floor
to several office styles and two facade-lettering detail tiles.

Facade functions take (b, face) with b a buildings.Bld and face one of v/r/a/l
(front/right/back/left); u runs along the facade (0..S-1), z is up (24 voxels per storey)
and d is the depth (negative = in front of the facade plane, positive = into the building).
Their __name__ seeds the building RNG (see buildings.LEGACY_SEED_NAMES), so do not rename.
"""
from common import register
from vox import mix, pick
from buildings import Bld, STYLES, S, W, make_block, flat_roof, x_solar_panels
from buildings2 import (reg_style, flat_roofs, pitched_roofs, lancet, column, pilasters, f_office_curtain_wall, f_office_gf_glass,
                        f_office_band, apt_up_large)
from details2 import facade_text

# ------------------------------------------------------------------ university (classic, brick + natural stone)


def wall_uni(x, y, z):
    """University wall colour: stone bands at the bottom (z 0-2) and top (z 22-23) of each storey, brick in between."""
    if z in (0, 1, 2, 22, 23):
        return pick(["natuursteen1", "natuursteen2"], (x + y) // 4, z, 0, 900)
    u = x + y
    return pick(["baksteen2", "baksteen4", "baksteen1"], (u + (z % 2) * 2) // 3, z, 0, 901)


STYLES["universiteit"] = dict(family="uni", wall=wall_uni, frame="kozijn_wit", doors=["hout_donker1"], plinth="natuursteen3",
                              trim="natuursteen1", roof=("leisteen1", "leisteen2", "leisteen1"), roof_deck=("zink1", "zink2"),
                              glass="glas1", shop="kozijn_wit", cap="natuursteen1")


def uni_portal(b, face):
    """Ground-floor portico: recessed entrance behind four columns, stone steps and an entablature."""
    b.rect(face, 0, S, 0, 24, -7, 0, 0)
    for i in range(3):
        b.rect(face, 2, 30, 0, 3 - i, -7 + i * 2, 0, b.st["trim"])
    for uc in (4, 12, 20, 28):
        column(b, face, uc, -5, 3, 21, 1.5)
    b.rect(face, 0, S, 21, 24, -8, 0, b.st["trim"])
    lancet(b, face, 11, 10, 3, 14, 20, kind="rond", glass="hout_donker1", frame=b.st["trim"])


def uni_window_arch(b, face):
    """Ground floor with a plinth and three round-arched windows."""
    b.plinth(face, 3)
    for u0 in (3, 13, 23):
        lancet(b, face, u0, 6, 5, 15, 21, kind="rond", glass="glas1", frame=b.st["trim"])


def uni_up_window(b, face):
    """Upper floor with three tall windows with muntins."""
    for u0 in (3, 13, 23):
        b.window(face, u0, 4, 6, 16, muntins=True)


def uni_up_tall(b, face):
    """Upper floor with pilasters and two tall round-arched windows."""
    pilasters(b, face)
    for u0 in (5, 18):
        lancet(b, face, u0, 9, 2, 14, 22, kind="rond", glass="glas1", frame=b.st["trim"])


def roof_turret(style):
    """Roof tile with a central turret: octagonal open lantern, copper spire and gold finial."""
    def fn():
        b = Bld(style, "dakruiter", 48)
        m = b.m
        c = W / 2

        def offsets(x, y):
            return abs(x + 0.5 - c), abs(y + 0.5 - c)

        # lantern: octagon (square with cut corners), open arcades in the middle of each side
        for z in range(0, 14):
            for y in range(W):
                for x in range(W):
                    dx, dy = offsets(x, y)
                    if max(dx, dy) <= 5 and dx + dy <= 7:
                        open_ = 4 < z < 11 and (dx < 1.5 or dy < 1.5)
                        m.set(x, y, z, 0 if open_ else ("kozijn_wit" if z < 13 else b.st["trim"]))
        # tapering octagonal spire
        for z in range(14, 30):
            hs = 5 - (z - 14) * 0.32
            for y in range(W):
                for x in range(W):
                    dx, dy = offsets(x, y)
                    if max(dx, dy) <= hs and dx + dy <= hs * 1.4:
                        m.set(x, y, z, "koper")
        for z in range(30, 35):
            m.set(c, c, z, "goud")
        m.cyl(c, c, 1.5, 6, 9, "messing")  # bell
        return m
    return fn


_roofs = pitched_roofs("universiteit")
_roofs.update(flat_roofs("universiteit"))
_roofs["dak_dakruiter"] = roof_turret("universiteit")
reg_style("universiteit", {"bg_portaal": uni_portal, "bg_raam_boog": uni_window_arch, "verd_raam": uni_up_window,
                           "verd_raam_hoog": uni_up_tall},
          [("bg_raam_boog_hoek", "bg_raam_boog", "bg_raam_boog"), ("verd_raam_hoek", "verd_raam", "verd_raam"),
           ("verd_raam_hoog_hoek", "verd_raam_hoog", "verd_raam_hoog")], _roofs)


# ------------------------------------------------------------------ college (modern, glass + coloured louvres)

STYLES["hogeschool"] = dict(family="hs", wall=mix("paneel3", "stuc1", "paneel1", seed=902, weights=[3, 2, 1]), frame="antraciet1",
                            doors=["antraciet1"], plinth="antraciet2", trim="antraciet1", roof=("dakgrind1", "dakgrind2"),
                            glass="glas2", shop="antraciet1", cap="alu")

LOUVRE_COLORS = ["paneel_rood", "paneel_geel", "paneel_blauw", "paneel_groen"]


def hs_entrance(b, face):
    """Full-height glass entrance with a wooden inner wall, canopy and a coloured CAMPUS sign."""
    b.rect(face, 0, S, 0, 24, 0, 3, 0)
    for z in range(0, 24):
        for u in range(S):
            edge = u % 8 == 0 or z in (0, 23) or z == 18
            b.put(face, u, z, 1, "antraciet1" if edge else "glas_helder")
    b.rect(face, 1, 31, 0, 23, 3, 4, "hout1")
    b.rect(face, 0, S, 19, 22, -8, 0, "antraciet1")
    b.sign(face, 4, 28, 19, 24, LOUVRE_COLORS[b.seed % 4], "CAMPUS", "bord_wit")


def hs_louvres(b, face):
    """Glass storey with vertical louvres (3 deep, every 3rd column) in rotating colours."""
    b.rect(face, 0, S, 0, 24, 0, 1, 0)
    b.rect(face, 0, S, 0, 24, 1, 2, b.st["glass"])
    b.interior(face, 0, S, 1, 23, 2, 950, office=True)
    for u in range(1, S, 3):
        c = LOUVRE_COLORS[(u // 3 + b.seed) % 4]
        b.rect(face, u, u + 1, 0, 24, -3, 0, c)


reg_style("hogeschool", {"bg_entree": hs_entrance, "bg_glas": f_office_gf_glass, "verd_lamellen": hs_louvres,
                         "verd_vliesgevel": f_office_curtain_wall, "verd_raam_groot": apt_up_large, "verd_band": f_office_band},
          [("bg_glas_hoek", "bg_glas", "bg_glas"), ("verd_lamellen_hoek", "verd_lamellen", "verd_lamellen"),
           ("verd_vliesgevel_hoek", "verd_vliesgevel", "verd_vliesgevel"), ("bg_entree_hoek", "bg_entree", "bg_glas")],
          dict(flat_roofs("hogeschool"), dak_zonnepanelen=flat_roof("hogeschool", "", x_solar_panels)))


# ------------------------------------------------------------------ offices with a colonnade (pillars at the front)

def colonnade(b, face):
    """Ground floor set back 1 m behind square pillars at the front, with a beam on top."""
    b.rect(face, 0, S, 0, 24, -7, 0, 0)
    b.rect(face, 0, S, 0, 24, 0, 1, 0)
    for z in range(0, 24):
        for u in range(S):
            edge = u % 8 == 0 or z in (0, 20)
            b.put(face, u, z, 1, b.st["frame"] if edge else b.st["glass"])
    b.interior(face, 1, 31, 1, 20, 2, 990, office=True)
    pillar = b.st["frame"] if b.style != "kantoor_beton" else "beton1"
    for uc in (0, 16, 29):
        b.rect(face, uc, uc + 3, 0, 24, -7, -4, pillar)
    b.rect(face, 0, S, 21, 24, -7, 0, pillar)


for _st in ("kantoor_glas", "kantoor_beton", "kantoor_80", "kantoor_2000", "kantoor_modern", "hogeschool"):
    register(f"gebouwen/{_st}/{_st}_bg_kolonnade", make_block(_st, [("v", colonnade)]))
    register(f"gebouwen/{_st}/{_st}_bg_kolonnade_hoek", make_block(_st, [("v", colonnade), ("r", colonnade)]))

register("details/tekst/tekst_universiteit", lambda: facade_text("UNIVERSITEIT"))
register("details/tekst/tekst_hogeschool", lambda: facade_text("HOGESCHOOL"))
