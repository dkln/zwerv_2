"""Extension 7: traffic lights in every state; sheds, warehouses, factories and industrial props.

Registers:
- ``props/verkeerslichten/*``: car, bike, mast, pedestrian and public-transport signals, one
  tile per signal state (built with props.pole / props.light_head).
- Industrial building styles ``loods_staal``, ``loods_steen``, ``magazijn`` and ``fabriek``
  (added to buildings.STYLES) with their facade blocks and roofs (flat, rooflights, sawtooth,
  barrel) via buildings2.reg_style, plus a stackable factory chimney.
- ``props/industrie/*``: pallets, shipping containers, silo, storage tank, forklift, cable
  reel and loading platform.

Facade functions take (b, face) with b a buildings.Bld and face one of v/r/a/l
(front/right/back/left); u runs along the facade, z is up (24 voxels per storey) and d is
the depth (negative = in front of the facade plane). Their __name__ seeds the building RNG
(see buildings.LEGACY_SEED_NAMES), so do not rename them. Sizes are in voxels of 12.5 cm.
"""
import math

from common import register, tile
from palette import P
from vox import V, mix, pick
from buildings import Bld, STYLES, S, O, W, HGT, fp, flat_roof
from buildings2 import reg_style, flat_roofs, lancet
from props import pole, light_head

# ------------------------------------------------------------------ traffic lights in every state
# Signals face the front (y = 0); the back board sits at y = 1..2.


def car_light(stand, height=32, head_z=19):
    """Car traffic light on a pole, showing ``stand`` (rood/oranje/groen)."""
    m = V(8, 4, height)
    pole(m, 3, 2, 0, height - 2, "metaal3")
    light_head(m, 2, 1, head_z, stand)
    return m


def bike_light(stand):
    """Lower bicycle traffic light with a bike pictogram on the back board."""
    m = V(8, 4, 24)
    pole(m, 3, 2, 0, 22, "metaal3")
    light_head(m, 2, 1, 11, stand)
    for (c, r) in [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)]:
        m.set(2 + c, 3, 22 - r, "bord_wit")
    return m


def mast_light(stand):
    """Overhead mast (80 wide) with a horizontal arm carrying two signal heads."""
    m = V(80, 4, 44)
    pole(m, 39, 1, 0, 42, "metaal3", 2)
    m.box(39, 1, 41, 78, 3, 42, "metaal3")
    light_head(m, 58, 1, 30, stand)
    light_head(m, 72, 1, 30, stand)
    return m


def pedestrian_light(stand):
    """Pedestrian light: standing red figure above a walking green one, yellow push button below."""
    m = V(8, 4, 26)
    pole(m, 3, 2, 0, 24, "metaal3")
    m.box(2, 1, 14, 6, 3, 24, "bord_zwart")
    standing = [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (1, 3)]
    walking = [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (0, 3), (2, 3)]
    for (c, r) in standing:
        m.set(2 + c, 0, 22 - r, "stoplicht_rood" if stand == "rood" else "stoplicht_rood_uit")
    for (c, r) in walking:
        m.set(2 + c, 0, 18 - r, "stoplicht_groen" if stand == "groen" else "stoplicht_groen_uit")
    m.box(2, 1, 8, 6, 2, 12, "bord_geel")
    return m


def transit_light(stand):
    """Public-transport signal (bus/tram): stop = horizontal bar, rijden (go) = vertical bar,
    attentie = dot; the bottom dot is always lit."""
    m = V(8, 4, 32)
    pole(m, 3, 2, 0, 30, "metaal3")
    m.box(1, 1, 19, 7, 3, 30, "bord_zwart")
    if stand == "stop":
        m.box(2, 0, 25, 6, 1, 26, "lamp_wit")
    elif stand == "rijden":
        m.box(3, 0, 22, 5, 1, 28, "lamp_wit")
    else:
        m.box(3, 0, 24, 5, 1, 26, "lamp_wit")
    m.box(3, 0, 20, 5, 1, 21, "lamp_wit")
    return m


for _s in ("rood", "oranje", "groen"):
    register(f"props/verkeerslichten/auto_{_s}", lambda s=_s: car_light(s))
    register(f"props/verkeerslichten/fiets_{_s}", lambda s=_s: bike_light(s))
    register(f"props/verkeerslichten/mast_{_s}", lambda s=_s: mast_light(s))
for _s in ("rood", "groen"):
    register(f"props/verkeerslichten/voetganger_{_s}", lambda s=_s: pedestrian_light(s))
for _s in ("stop", "rijden", "attentie"):
    register(f"props/verkeerslichten/ov_{_s}", lambda s=_s: transit_light(s))


# ------------------------------------------------------------------ sheds, warehouses, factories
# Wall colour functions take world voxel coordinates; u = x + y runs along any facade.

def corrugated_steel(names):
    """Wall function for corrugated sheet: names[1] on every 3rd rib, names[0] elsewhere."""
    def f(x, y, z):
        u = x + y
        return P[names[0]] if u % 3 else P[names[1]]
    return f


def concrete_panel(x, y, z):
    """Wall of 24x24 precast concrete panels with dark joints."""
    u = x + y
    if u % 24 == 0 or z % 24 == 0:
        return P["beton_donker"]
    return pick(["beton1", "beton2", "beton3"], u // 24, z // 24, 0, 1000)


def factory_brick(x, y, z):
    """Factory brick in running bond with a dark brick band every 12 voxels."""
    u = x + y
    if z % 12 == 0:
        return P["donkersteen2"]
    return pick(["baksteen2", "baksteen4", "donkersteen1"], (u + (z % 2) * 2) // 3, z, 0, 1001, [3, 2, 1])


def steel_on_plinth(x, y, z):
    """Blue steel cladding on a 1 m brick plinth."""
    if z < 8:
        return factory_brick(x, y, z)
    u = x + y
    return P["paneel_blauw"] if u % 3 else P["bord_blauw2"]


STYLES.update({
    "loods_staal": dict(family="industrie", wall=corrugated_steel(["golfplaat1", "golfplaat2"]), frame="antraciet1", doors=["metaal1"],
                        plinth="beton2", trim="antraciet1", roof=("golfplaat1", "golfplaat2"), roof_deck=("golfplaat1", "golfplaat2"),
                        glass="glas2", shop="antraciet1", cap="antraciet1", accent="bord_geel"),
    "loods_steen": dict(family="industrie", wall=steel_on_plinth, frame="antraciet1", doors=["metaal1"],
                        plinth="baksteen4", trim="antraciet1", roof=("golfplaat1", "golfplaat2"), roof_deck=("bitumen1", "bitumen2"),
                        glass="glas2", shop="antraciet1", cap="antraciet1", accent="bord_geel"),
    "magazijn": dict(family="industrie", wall=concrete_panel, frame="antraciet1", doors=["metaal2"],
                     plinth="beton_donker", trim="antraciet2", roof=("bitumen1", "bitumen2"), roof_deck=("bitumen1", "bitumen2"),
                     glass="glas2", shop="antraciet1", cap="metaal3", accent="bord_oranje"),
    "fabriek": dict(family="industrie", wall=factory_brick, frame="kozijn_zwart", doors=["kozijn_groen"],
                    plinth="donkersteen2", trim="natuursteen2", roof=("leisteen1", "leisteen2"), roof_deck=("bitumen1", "bitumen2"),
                    glass="glas1", shop="kozijn_zwart", cap="natuursteen2", accent="bord_geel"),
})


def _ind_plinth(b, face):
    """2-voxel plinth strip in the style's plinth colour (facade plane, d = 0)."""
    b.rect(face, 0, S, 0, 2, 0, 1, b.st["plinth"])


def ind_dock(b, face):
    """Loading dock: tall door with a rubber dock shelter, bumpers and a status light."""
    _ind_plinth(b, face)
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


def ind_roller_door(b, face):
    """Large roller door with striped bollard markings on both sides."""
    _ind_plinth(b, face)
    b.rect(face, 3, 29, 0, 22, 0, 2, 0)
    for z in range(0, 22):
        for u in range(3, 29):
            edge = u in (3, 28) or z == 21
            b.put(face, u, z, 1, b.st["frame"] if edge else ("metaal1" if z % 2 else "metaal2"))
    for u in (1, 30):
        for z in range(0, 6):
            b.put(face, u, z, -1, b.st["accent"] if z % 2 else "bord_zwart")


def ind_side_door(b, face):
    """Personnel door with a small canopy and lamp, flanked by two windows."""
    _ind_plinth(b, face)
    b.rect(face, 13, 19, 0, 17, 0, 2, 0)
    b.rect(face, 13, 19, 0, 17, 1, 2, "metaal1")
    b.rect(face, 11, 21, 17, 18, -4, 0, b.st["frame"])
    b.put(face, 16, 18, -1, "lamp_wit")
    b.window(face, 3, 6, 6, 6, sill=False, lintel=False)
    b.window(face, 23, 6, 6, 6, sill=False, lintel=False)


def ind_office(b, face):
    """Office front: wide ribbon window with a glass door and canopy."""
    _ind_plinth(b, face)
    b.window(face, 2, 4, 28, 14, sill=False, lintel=False)
    b.rect(face, 12, 20, 0, 18, 0, 3, 0)
    b.rect(face, 12, 20, 0, 17, 1, 2, "glas_helder")
    b.rect(face, 10, 22, 18, 19, -5, 0, b.st["frame"])


def ind_blank(b, face):
    """Closed ground floor with only the plinth."""
    _ind_plinth(b, face)


def ind_rooflight(b, face):
    """Upper wall with a high horizontal light band divided by mullions every 4 voxels."""
    b.window(face, 0, 14, 32, 6, sill=False, lintel=False)
    for u in range(0, 32, 4):
        for z in range(14, 20):
            b.put(face, u, z, 1, b.st["frame"])


def ind_wall(b, face):
    """Plain upper wall (body only)."""


def ind_logo(b, face):
    """Upper wall with a large ZWERVR company sign (blue when the accent colour is yellow)."""
    b.sign(face, 2, 30, 8, 16, b.st["accent"] if b.st["accent"] != "bord_geel" else "bord_blauw", "ZWERVR", "bord_wit")


def fac_window_tall(b, face):
    """Factory windows: tall steel round-arched windows divided into small panes."""
    for u0 in (3, 18):
        lancet(b, face, u0, 11, 2, 16, 22, kind="rond", glass="glas1", frame=b.st["trim"])
        # horizontal glazing bars every 3 voxels, only where the window has glass at d = 2
        for z in range(2, 22, 3):
            for u in range(u0, u0 + 11):
                if b.m.get(*fp(face, u, 2), z):
                    b.put(face, u, z, 2, "kozijn_zwart")


def fac_gate(b, face):
    """Green wooden double gate with diagonal braces and a lintel."""
    _ind_plinth(b, face)
    b.rect(face, 6, 26, 0, 18, 0, 2, 0)
    for z in range(0, 18):
        for u in range(6, 26):
            edge = u in (6, 25, 15, 16) or z == 17
            diag = (u - 6) % 10 == z % 10
            b.put(face, u, z, 1, b.st["trim"] if (edge or diag) else "kozijn_groen")
    b.rect(face, 5, 27, 18, 21, -1, 1, b.st["trim"])


def sawtooth_roof(style, edges=""):
    """Sawtooth (shed) roof: two 16-deep teeth with a steep glazed side and a sloped closed side.

    ``edges`` lists faces (v/r/a/l) that get a 3-voxel parapet of wall material.
    """
    def fn():
        b = Bld(style, "shed" + edges, 32)
        m = b.m
        for ly in range(S):
            for lx in range(S):
                t = ly % 16
                zt = 2 + int(t * 1.1)
                for z in range(0, zt):
                    if z >= zt - 1:
                        c = "zink1" if (lx % 4) else "zink2"
                    else:
                        c = b.st["wall"]
                    m.set(O + lx, O + ly, z, c)
                if t == 0:
                    # glazed vertical side, mullion every 4 voxels
                    for z in range(2, 19):
                        m.set(O + lx, O + ly, z, b.st["glass"] if lx % 4 else "kozijn_zwart")
        for f in edges:
            b.rect(f, 0, S, 0, 3, 0, 1, b.st["wall"])
        return m
    return fn


def _barrel_top(lx):
    """Height (exclusive) of the barrel roof at block column ``lx``: a half circle over 32 voxels."""
    dx = (lx + 0.5 - 16) / 16.0
    return 2 + int(10 * math.sqrt(max(0.0, 1 - dx * dx)))


def barrel_roof(style):
    """Curved barrel roof (1 tile wide, ridge running front to back); side by side = wavy roof."""
    def fn():
        b = Bld(style, "ton", 32)
        m = b.m
        for ly in range(S):
            for lx in range(S):
                zt = _barrel_top(lx)
                for z in range(0, zt):
                    m.set(O + lx, O + ly, z, ("golfplaat1" if lx % 3 else "golfplaat2") if z >= zt - 2 else b.st["wall"])
        # glass strips across the ridge every 8 voxels
        for ly in range(4, S, 8):
            for lx in range(12, 20):
                m.set(O + lx, O + ly, _barrel_top(lx) - 1, "glas_helder")
        return m
    return fn


def x_rooflights(b):
    """Flat-roof extra: four rows of glass rooflights with metal kerbs."""
    m = b.m
    for ly in range(4, 30, 8):
        m.box(O + 4, O + ly, 1, O + 28, O + ly + 1, 2, "metaal3")
        m.box(O + 4, O + ly + 1, 1, O + 28, O + ly + 2, 3, "glas_helder")
        m.box(O + 4, O + ly + 2, 1, O + 28, O + ly + 3, 2, "metaal3")


IND_PIECES = {"bg_dock": ind_dock, "bg_roldeur": ind_roller_door, "bg_loopdeur": ind_side_door, "bg_kantoor": ind_office,
              "bg_dicht": ind_blank, "verd_wand": ind_wall, "verd_lichtstraat": ind_rooflight, "verd_logo": ind_logo}
IND_CORNERS = [("bg_dicht_hoek", "bg_dicht", "bg_dicht"), ("bg_roldeur_hoek", "bg_roldeur", "bg_dicht"),
               ("bg_kantoor_hoek", "bg_kantoor", "bg_loopdeur"), ("verd_wand_hoek", "verd_wand", "verd_wand"),
               ("verd_lichtstraat_hoek", "verd_lichtstraat", "verd_lichtstraat")]

for _st in ("loods_staal", "loods_steen", "magazijn", "fabriek"):
    pieces = dict(IND_PIECES)
    corners = list(IND_CORNERS)
    if _st == "fabriek":
        pieces.update({"bg_poort": fac_gate, "verd_raam_hoog": fac_window_tall})
        corners.append(("verd_raam_hoog_hoek", "verd_raam_hoog", "verd_raam_hoog"))
    roofs = dict(flat_roofs(_st))
    roofs["dak_lichtstraten"] = flat_roof(_st, "", x_rooflights)
    roofs["dak_shed"] = sawtooth_roof(_st)
    roofs["dak_shed_rand"] = sawtooth_roof(_st, "v")
    roofs["dak_ton"] = barrel_roof(_st)
    reg_style(_st, pieces, corners, roofs)


# ------------------------------------------------------------------ factory chimney (stackable, 3 m per piece)

def chimney_part(part):
    """One storey-high piece of a round brick factory chimney, centred on a W x W canvas.

    part: ``voet`` (solid, tapering base with a stone footing), ``segment`` (hollow shaft)
    or ``top`` (shaft with a crown ring and an aircraft warning light).
    """
    def fn():
        m = V(W, W, HGT + (6 if part == "top" else 0))
        c = W / 2
        r0 = {"voet": 7.0, "segment": 4.6, "top": 4.2}[part]
        for z in range(HGT):
            r = r0 - (z / HGT) * (2.2 if part == "voet" else 0.3)
            for y in range(W):
                for x in range(W):
                    d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                    if d <= r and (d > r - 1.6 or part == "voet"):
                        m.set(x, y, z, factory_brick(x, y, z) if not (part == "voet" and z < 4) else P["natuursteen2"])
        if part == "top":
            for z in range(HGT, HGT + 3):
                m.cyl(c, c, 5.2, z, z + 1, "donkersteen2")
                m.cyl(c, c, 3.4, z, z + 1, 0)
            m.set(c + 4, c, HGT + 3, "signaal_rood")
        return m
    return fn


for _d in ("voet", "segment", "top"):
    register(f"gebouwen/overig/fabrieksschoorsteen_{_d}", chimney_part(_d))


# ------------------------------------------------------------------ industrial props

@tile("props/industrie/pallet_stapel")
def pallet_stack():
    """Stack of four pallets with a sand-coloured load inside."""
    m = V(10, 10, 12)
    for lvl in range(4):
        z = lvl * 3
        for y in range(1, 9):
            for x in range(1, 9):
                if (y % 3 != 1) or lvl % 2:
                    m.set(x, y, z, "hout2" if (x + lvl) % 2 else "hout3")
        for y in (1, 4, 8):
            m.box(1, y, z + 1, 9, y + 1, z + 2, "hout_donker1")
    m.box(2, 2, 1, 8, 8, 3, "zand1")
    return m


def _container_shell(m, oy, oz, color):
    """Hollow 48x20x20 container shell at (0, oy, oz); ``color(x, z)`` gives the voxel colour."""
    for z in range(oz, oz + 20):
        for y in range(oy, oy + 20):
            for x in range(0, 48):
                if x in (0, 47) or y in (oy, oy + 19) or z in (oz, oz + 19):
                    m.set(x, y, z, color(x, z))


@tile("props/industrie/zeecontainer")
def shipping_container():
    """Single red 20 ft shipping container with door bars on the right end."""
    m = V(48, 20, 20)
    _container_shell(m, 0, 0, lambda x, z: "bord_rood2" if (x % 2 or z in (0, 19)) else "bord_rood")
    m.box(47, 9, 2, 48, 11, 18, "metaal_donker")
    return m


@tile("props/industrie/zeecontainer_stapel")
def shipping_container_stack():
    """Three containers: two side by side, one stacked on the front one."""
    m = V(48, 44, 40)
    colors = [("bord_rood", "bord_rood2"), ("bord_blauw", "bord_blauw2"), ("bord_groen", "bord_groen2")]
    for (oy, oz), k in zip(((2, 0), (22, 0), (2, 20)), colors):
        _container_shell(m, oy, oz, lambda x, z, k=k: k[1] if x % 2 else k[0])
    return m


@tile("props/industrie/silo")
def silo():
    """Tall banded steel silo on four legs, conical top and a ladder."""
    m = V(28, 28, 96)
    for (x, y) in ((6, 6), (21, 6), (6, 21), (21, 21)):
        m.box(x, y, 0, x + 2, y + 2, 10, "metaal2")
    for z in range(10, 96):
        r = 11 if z < 84 else 11 - (z - 84) * 0.9
        m.cyl(14, 14, max(1, r), z, z + 1, "rvs" if (z // 6) % 2 else "metaal3")
    m.box(26, 14, 0, 27, 15, 90, "metaal_donker")
    return m


@tile("props/industrie/opslagtank")
def storage_tank():
    """Round storage tank with a domed roof and a spiral stair."""
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
def forklift():
    """Orange forklift with cab frame, mast and forks at the front (y = 0)."""
    m = V(12, 24, 20)
    m.box(1, 6, 1, 11, 20, 7, "bord_oranje")
    m.box(1, 14, 7, 11, 20, 9, "bord_oranje")
    for (x0, x1, y) in ((0, 2, 8), (10, 12, 8), (0, 2, 17), (10, 12, 17)):
        m.box(x0, y - 1, 0, x1, y + 2, 3, "rubber")  # wheels
    for (x, y) in ((2, 8), (9, 8), (2, 17), (9, 17)):
        m.box(x, y, 7, x + 1, y + 1, 16, "bord_zwart")  # cab posts
    m.box(2, 8, 15, 10, 18, 16, "bord_zwart")
    m.box(3, 11, 7, 9, 13, 10, "bord_zwart")
    for x in (3, 8):
        m.box(x, 4, 1, x + 1, 5, 17, "metaal_donker")  # mast
        m.box(x, 0, 1, x + 1, 5, 2, "metaal3")  # fork
    return m


@tile("props/industrie/kabelhaspel")
def cable_reel():
    """Wooden cable reel lying on its side, axis along y."""
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
def loading_dock():
    """Concrete loading platform with a yellow/black striped front edge."""
    m = V(24, 16, 10)
    m.box(0, 0, 0, 24, 16, 9, mix("beton1", "beton2", seed=1002))
    for x in range(24):
        m.set(x, 0, 8, "bord_geel" if (x // 3) % 2 else "bord_zwart")
    return m
