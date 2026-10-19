"""Props: street furniture, signs, trees, plants, fences, bollards, stairs, railway and water items.

Every function here returns a free-standing V model (no ground tile) and is registered under a
``props/...`` path via @tile / register; generate.py writes each to <OUT>/<path>.vox + .tile.json.

Conventions: 1 voxel = 12.5 cm, x = left->right, y = front->back (front = y=0), z = up.
The pivot is the bottom centre of the model. In the Props GridMap (0.5 m grid) the pivot sits on a
grid point, so props can be placed with fine granularity.

Shared helpers used by other modules (props2, extras4/5/7): pole, light_head, sign_panel, shrub,
trunk, crown_clusters, deciduous_tree, bicycle and the re-exported PICTO table.
"""
import math

from common import register, tile, PICTO, text_pixels
from palette import P
from vox import V, mix, pick, h

POLE_COLOR = "metaal2"


def pole(m, x, y, z0, z1, c=POLE_COLOR, w=2):
    """Square vertical pole of w x w voxels with its corner at (x, y), filling z in [z0, z1)."""
    m.box(x, y, z0, x + w, y + w, z1, c)


def _stamp(m, px, x0, y, ztop, c):
    """Draw text/picto pixels (col, row) at y; column 0 at x0, row 0 (top) at z = ztop."""
    for (cc, r) in px:
        m.set(x0 + cc, y, ztop - r, c)


def _framed_panel(m, x0, x1, z0, z1, y, rim, fill, back=None):
    """Flat panel in plane y covering x0..x1 and z0..z1 (inclusive) with a 1-voxel rim.

    If ``back`` is given, a backing plate of that colour is placed at y + 1.
    """
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or z in (z0, z1)
            m.set(x, y, z, rim if edge else fill)
            if back:
                m.set(x, y + 1, z, back)


def _post(hgt, color):
    """2x2 post of height hgt; ``color`` is a colour name or a function z -> colour name."""
    m = V(2, 2, hgt)
    for z in range(hgt):
        m.box(0, 0, z, 2, 2, z + 1, color(z) if callable(color) else color)
    return m


# ------------------------------------------------------------------ lighting

@tile("props/verlichting/lantaarn_klassiek")
def streetlight_classic():
    """Classic Amsterdam-green lamp post with a square lantern (12x12x44)."""
    m = V(12, 12, 44)
    g = "amsterdamgroen"
    # square foot with chamfered corners
    for z in range(0, 4):
        for y in range(3, 9):
            for x in range(3, 9):
                if not ((x in (3, 8)) and (y in (3, 8))):
                    m.set(x, y, z, g)
    for z in range(4, 34):
        r = 1.6 if z < 8 else 1.1
        m.cyl(6, 6, r, z, z + 1, g)
    m.cyl(6, 6, 1.6, 26, 27, g)
    # cross bar (ladder rest)
    for x in range(1, 11):
        m.set(x, 6, 30, g)
    for z in range(34, 36):
        m.cyl(6, 6, 2.2, z, z + 1, g)
    # lantern: glowing walls, green corner posts
    for z in range(36, 41):
        for y in range(3, 9):
            for x in range(3, 9):
                edge = x in (3, 8) or y in (3, 8)
                corner = x in (3, 8) and y in (3, 8)
                if edge:
                    m.set(x, y, z, g if corner else "lamp_warm")
    for z in (41, 42):
        m.cyl(6, 6, 3.3 - (z - 41) * 1.6, z, z + 1, g)
    m.set(5, 5, 43, g)
    m.set(6, 6, 43, g)
    return m


@tile("props/verlichting/lantaarn_modern")
def streetlight_modern():
    """Modern single-arm street light (arm towards +x)."""
    m = V(28, 4, 50)
    m.box(14, 1, 0, 15, 3, 48, "metaal3")
    m.box(13, 1, 0, 14, 2, 2, "metaal3")    # foot flanges
    m.box(15, 2, 0, 16, 3, 2, "metaal3")
    m.box(14, 1, 48, 26, 3, 49, "metaal3")  # arm
    m.box(22, 1, 47, 27, 3, 48, "lamp_wit")
    m.box(22, 1, 48, 27, 3, 49, "antraciet1")
    return m


@tile("props/verlichting/lantaarn_dubbel")
def streetlight_double():
    """Double-arm street light with a lamp at both ends."""
    m = V(28, 4, 54)
    m.box(13, 1, 0, 15, 3, 52, "metaal3")
    m.box(2, 1, 52, 26, 3, 53, "metaal3")
    m.box(2, 1, 51, 7, 3, 52, "lamp_wit")
    m.box(21, 1, 51, 26, 3, 52, "lamp_wit")
    return m


@tile("props/verlichting/lantaarn_snelweg")
def streetlight_highway():
    """Tall galvanised highway light with a long arm."""
    m = V(64, 4, 100)
    m.box(31, 1, 0, 33, 3, 96, "gegalvaniseerd")
    # arm: one voxel higher after x = 36
    for x in range(31, 60):
        z = 96 + (1 if x > 36 else 0)
        m.set(x, 1, z, "gegalvaniseerd")
        m.set(x, 2, z, "gegalvaniseerd")
    m.box(53, 1, 96, 60, 3, 97, "lamp_wit")
    m.box(53, 1, 97, 60, 3, 98, "metaal2")
    return m


@tile("props/verlichting/lantaarn_park")
def streetlight_park():
    """Low park light with a globe."""
    m = V(6, 6, 30)
    for z in range(0, 24):
        m.cyl(3, 3, 0.9 if z > 2 else 1.6, z, z + 1, "antraciet1")
    m.ellipsoid(3, 3, 26, 2.6, 2.6, 3, "lamp_warm")
    m.cyl(3, 3, 2.5, 28, 30, "antraciet1")
    return m


# ------------------------------------------------------------------ waste

@tile("props/straat/prullenbak_paal")
def bin_post():
    """Green Amsterdam litter bin on a post."""
    m = V(6, 6, 10)
    pole(m, 2, 2, 0, 9, "amsterdamgroen")
    for z in range(3, 9):
        m.cyl(3, 3, 2.6, z, z + 1, "amsterdamgroen" if z not in (4, 7) else "deur_groen")
    m.cyl(3, 3, 1.5, 8, 9, "interieur3")
    m.cyl(3, 3, 2.8, 9, 10, "metaal_donker")
    # opening in the lid
    m.set(3, 3, 9, 0)
    m.set(2, 3, 9, 0)
    return m


@tile("props/straat/prullenbak_rond")
def bin_round():
    """Round perforated metal litter bin."""
    m = V(6, 6, 8)
    for z in range(0, 8):
        for y in range(6):
            for x in range(6):
                d = math.hypot(x + 0.5 - 3, y + 0.5 - 3)
                # wall with a checkerboard of holes, solid top and bottom rings
                if 2.0 < d < 3.0 and (z < 1 or z > 6 or (x + y + z) % 2 == 0):
                    m.set(x, y, z, "metaal_donker")
                elif d <= 2.0 and z == 0:
                    m.set(x, y, z, "metaal_donker")
    return m


@tile("props/straat/afvalcontainer_ondergronds")
def underground():
    """Underground waste container: steel deck plate with the inlet column."""
    m = V(12, 12, 10)
    m.box(0, 0, 0, 12, 12, 1, "rvs")
    for z in range(1, 9):
        m.cyl(6, 6, 2.6, z, z + 1, "antraciet2")
    m.cyl(6, 6, 3.2, 9, 10, "antraciet1")
    m.box(4, 3, 6, 9, 4, 8, "interieur3")  # inlet flap
    m.set(6, 3, 8, "bord_groen")
    return m


def wheelie_bin(lid):
    """Wheelie bin (6x8x9) with lid colour ``lid``; wheels and handle at the back (high y)."""
    m = V(6, 8, 9)
    m.box(0, 1, 0, 6, 7, 7, "antraciet1")
    m.box(0, 1, 7, 6, 7, 8, lid)
    for x in (0, 5):
        m.set(x, 6, 0, "rubber")
        m.set(x, 7, 1, "rubber")
    m.box(0, 7, 7, 6, 8, 8, "antraciet2")  # handle
    return m


register("props/straat/rolcontainer_grijs", lambda: wheelie_bin("antraciet2"))
register("props/straat/rolcontainer_groen", lambda: wheelie_bin("bord_groen"))
register("props/straat/rolcontainer_blauw", lambda: wheelie_bin("bord_blauw"))


# ------------------------------------------------------------------ seating

@tile("props/straat/bank_hout")
def bench_wood():
    """Wooden park bench with metal legs and a backrest at y=0."""
    m = V(16, 6, 8)
    for x in (1, 14):
        for z in range(0, 7):
            m.set(x, 1, z, "metaal_donker")
            m.set(x, 4, z if z < 4 else 3, "metaal_donker")
        for y in range(1, 5):
            m.set(x, y, 3, "metaal_donker")
    for x in range(16):
        for y in (1, 2, 3, 4):
            m.set(x, y, 4, "hout_bank1" if y % 2 else "hout_bank2")
        for z in (5, 6):
            m.set(x, 0, z + 1, "hout_bank3" if z == 6 else "hout_bank2")
    return m


@tile("props/straat/bank_beton")
def bench_concrete():
    """Concrete block bench with a wooden seat."""
    m = V(16, 6, 4)
    m.box(0, 1, 0, 16, 5, 3, mix("beton1", "beton2", "beton3", seed=11))
    for x in range(1, 15):
        for y in range(1, 5):
            m.set(x, y, 3, "hout_bank1" if y % 2 else "hout_bank3")
    return m


@tile("props/straat/bank_modern")
def bench_modern():
    """Stainless steel bench with three supports."""
    m = V(20, 6, 7)
    m.box(0, 1, 3, 20, 5, 4, "rvs")
    m.box(0, 1, 4, 20, 2, 7, "rvs")  # backrest
    for x in (1, 9, 18):
        m.box(x, 2, 0, x + 1, 4, 3, "metaal_donker")
    return m


@tile("props/straat/picknicktafel")
def picnic_table():
    """Wooden picnic table with two benches and A-frame legs."""
    m = V(16, 14, 7)
    for x in range(1, 15):
        for y in range(4, 10):
            m.set(x, y, 6, "hout_bank1" if y % 2 else "hout_bank2")
        for y in (1, 2, 11, 12):
            m.set(x, y, 3, "hout_bank2")
    for x in (2, 13):
        for z in range(0, 6):
            m.set(x, 7 - z // 2, z, "hout_bank3")
            m.set(x, 7 + z // 2, z, "hout_bank3")
        for y in range(1, 13):
            m.set(x, y, 2, "hout_bank3")
    return m


# ------------------------------------------------------------------ bicycles

def bicycle(color="fiets_zwart"):
    """Side-on bicycle (16x6x10) in the plane y=3, front wheel at high x; frame colour ``color``."""
    m = V(16, 6, 10)
    y = 3
    for cx in (3.5, 12.5):
        for z in range(0, 8):
            for x in range(16):
                d = math.hypot(x + 0.5 - cx, z + 0.5 - 3.5)
                if 2.6 < d < 3.6:
                    m.set(x, y, z, "rubber")
                elif d < 0.8:
                    m.set(x, y, z, "metaal3")
    m.line((3.5, y, 3.5), (8, y, 3.5), color)
    m.line((8, y, 3.5), (5.5, y, 7.5), color)
    m.line((8, y, 3.5), (11.5, y, 7.5), color)
    m.line((5.5, y, 7.5), (11.5, y, 7.5), color)
    m.line((3.5, y, 3.5), (5.5, y, 7.5), color)
    m.line((12.5, y, 3.5), (11.5, y, 8.5), color)
    for yy in range(1, 6):        # handlebar
        m.set(11, yy, 9, "metaal_donker")
    m.set(5, y, 8, "rubber")      # saddle
    m.set(6, y, 8, "rubber")
    m.set(4, y, 8, "rubber")
    # rear carrier and mudguard
    for x in range(1, 6):
        m.set(x, y, 6, "metaal_donker")
    return m


register("props/fietsen/fiets_zwart", lambda: bicycle())
register("props/fietsen/fiets_rood", lambda: bicycle("fiets_rood"))
register("props/fietsen/fiets_blauw", lambda: bicycle("fiets_blauw"))


@tile("props/fietsen/fietsnietje")
def bike_hoop():
    """Stainless steel bike hoop (inverted U)."""
    m = V(8, 2, 8)
    m.box(1, 0, 0, 2, 1, 7, "rvs")
    m.box(6, 0, 0, 7, 1, 7, "rvs")
    m.box(1, 0, 7, 7, 1, 8, "rvs")
    return m


@tile("props/fietsen/fietsenrek")
def bike_rack():
    """Low galvanised bike rack, 32 voxels (4 m) long, with a slot every 4 voxels."""
    m = V(32, 4, 4)
    m.box(0, 1, 0, 32, 3, 1, "gegalvaniseerd")
    for x in range(1, 32, 4):
        m.box(x, 1, 1, x + 1, 3, 4, "gegalvaniseerd")
    return m


@tile("props/fietsen/fietsenrek_vol")
def bike_rack_full():
    """Bike rack filled with eight bicycles parked front-to-back."""
    m = V(32, 18, 10)
    m.paste(bike_rack(), 0, 7, 0)
    colors = ["fiets_zwart", "fiets_rood", "fiets_blauw", "fiets_zwart",
              "fiets_zwart", "fiets_blauw", "fiets_rood", "fiets_zwart"]
    for i, c in enumerate(colors):
        # rotated bicycle: 6 wide, 16 deep
        m.paste(bicycle(c).rot90(1), i * 4 - 1, 1, 0)
    return m


# ------------------------------------------------------------------ public transport

@tile("props/ov/abri")
def abri():
    """Glass bus/tram shelter with an advertising display on the right side, bench and stop sign."""
    m = V(36, 14, 22)
    for x in (1, 34):
        for z in range(0, 20):
            for y in (2, 11):
                m.set(x, y, z, "metaal3")
    # glass roof with a metal frame
    for x in range(0, 36):
        for y in range(0, 14):
            frame = x in (0, 35) or y in (0, 13)
            m.set(x, y, 20, "metaal3" if frame else "glas_helder")
            m.set(x, y, 21, "metaal3" if frame else 0)
    # glass back wall
    for x in range(2, 34):
        for z in range(1, 19):
            m.set(x, 11, z, "glas_helder")
        m.set(x, 11, 0, "metaal3")
        m.set(x, 11, 19, "metaal3")
    # advertising display on the side
    for y in range(3, 12):
        for z in range(1, 19):
            edge = y in (3, 11) or z in (1, 18)
            m.set(34, y, z, "metaal3" if edge else pick(["reclame1", "reclame2", "reclame3"], y // 4, z // 6, 0, 12))
            m.set(35, y, z, "metaal3")
    # bench
    for x in range(6, 22):
        m.set(x, 9, 4, "hout_bank1")
        m.set(x, 10, 4, "hout_bank2")
    for x in (7, 20):
        for z in range(4):
            m.set(x, 10, z, "metaal3")
    # stop sign
    for z in range(15, 20):
        for x in range(4, 14):
            m.set(x, 2, z, "bord_geel" if z > 16 else "bord_blauw")
    return m


@tile("props/ov/bushokje")
def bus_shelter():
    """Small green bus shelter with glass back and left walls and a bench."""
    m = V(28, 12, 21)
    for x in (1, 26):
        for y in (1, 10):
            m.box(x, y, 0, x + 1, y + 1, 19, "amsterdamgroen")
    m.box(0, 0, 19, 28, 12, 20, "amsterdamgroen")
    m.box(1, 1, 20, 27, 11, 21, "amsterdamgroen")
    m.box(2, 10, 2, 26, 11, 18, "glas_helder")
    m.box(1, 2, 2, 2, 10, 18, "glas_helder")
    m.box(4, 9, 4, 20, 10, 5, "hout_bank1")
    m.box(4, 8, 4, 20, 9, 5, "hout_bank2")
    return m


def stop_pole(text, color_top="bord_geel", color_bottom="bord_blauw"):
    """Bus/tram stop pole with a sign showing ``text`` and a timetable box."""
    m = V(14, 4, 28)
    pole(m, 6, 1, 0, 28, "metaal3")
    px, (tw, _) = text_pixels(text)
    w = max(tw + 2, 8)
    x0 = 7 - w // 2
    for z in range(20, 28):
        for x in range(x0, x0 + w):
            m.set(x, 1, z, color_top if z >= 26 else color_bottom)
            m.set(x, 2, z, "metaal2")
    _stamp(m, px, x0 + 1, 0, 25, "bord_wit")
    # timetable box
    for z in range(10, 16):
        for x in range(5, 9):
            m.set(x, 1, z, "stuc1")
            m.set(x, 0, z, "bord_wit" if z % 2 else "bord_zwart")
    return m


register("props/ov/bushalte_paal", lambda: stop_pole("BUS"))
register("props/ov/tramhalte_paal", lambda: stop_pole("TRAM", "bord_geel", "bord_rood"))


@tile("props/ov/reclamezuil")
def advertising_column():
    """Round advertising column (Morris column) with poster patches."""
    m = V(12, 12, 28)
    for z in range(0, 2):
        m.cyl(6, 6, 5, z, z + 1, "amsterdamgroen")
    for z in range(2, 22):
        for y in range(12):
            for x in range(12):
                d = math.hypot(x + 0.5 - 6, y + 0.5 - 6)
                if d < 4.5:
                    ang = math.atan2(y - 6, x - 6)
                    m.set(x, y, z, pick(["reclame1", "luifel_wit", "bloem_geel", "luifel_rood", "luifel_blauw"],
                                        int((ang + 4) * 1.3), z // 5, 0, 13))
    for z in range(22, 25):
        m.cyl(6, 6, 5.2 - (z - 22) * 1.2, z, z + 1, "amsterdamgroen")
    m.cyl(6, 6, 1, 25, 28, "amsterdamgroen")
    return m


# ------------------------------------------------------------------ traffic lights

def light_head(m, x, y, z, lit="rood", kind="auto"):
    """Draw a 3-aspect traffic light head into m.

    The 4-wide housing spans x..x+3, y..y+1 and z..z+9; lenses face the front at y-1.
    Aspects from bottom to top: green, amber, red; ``lit`` ("groen"/"oranje"/"rood") is lit,
    the others use their "_uit" colour. A striped backboard is drawn at x-1 and x+4.
    ``kind`` is unused (kept for API compatibility).
    """
    m.box(x, y, z, x + 4, y + 2, z + 10, "bord_zwart")
    for i, name in enumerate(["groen", "oranje", "rood"]):
        zz = z + 1 + i * 3
        c = f"stoplicht_{name}" if name == lit else f"stoplicht_{name}_uit"
        m.box(x + 1, y - 1, zz, x + 3, y, zz + 2, c)
        m.set(x + 1, y - 1, zz + 2, "bord_zwart")   # visor
        m.set(x + 2, y - 1, zz + 2, "bord_zwart")
    # white/red striped backboard
    for zz in range(z - 1, z + 11):
        for xx in (x - 1, x + 4):
            m.set(xx, y + 1, zz, "bord_wit" if (zz % 2) else "bord_rood")


def _light_pole(hgt, lit=None):
    """8x4xhgt model with a traffic light pole; head at hgt-13 if ``lit`` is given."""
    m = V(8, 4, hgt)
    pole(m, 3, 2, 0, hgt - 2, "metaal3")
    if lit:
        light_head(m, 2, 1, hgt - 13, lit)
    return m


def _push_button_box(m):
    """Yellow push-button box on the front of a traffic light pole (z 8..11)."""
    m.box(2, 1, 8, 6, 2, 12, "bord_geel")


@tile("props/verkeer/verkeerslicht")
def traffic_light():
    """Car traffic light (red) with a push-button box."""
    m = _light_pole(32, "rood")
    _push_button_box(m)
    m.set(3, 0, 10, "bord_zwart")
    return m


@tile("props/verkeer/verkeerslicht_groen")
def traffic_light_green():
    """Car traffic light showing green."""
    return _light_pole(32, "groen")


@tile("props/verkeer/verkeerslicht_fiets")
def traffic_light_bike():
    """Lower traffic light for cyclists (red)."""
    return _light_pole(24, "rood")


@tile("props/verkeer/verkeerslicht_voetganger")
def traffic_light_pedestrian():
    """Pedestrian light with a red and an unlit green walking figure."""
    m = _light_pole(26)
    m.box(2, 1, 14, 6, 3, 24, "bord_zwart")
    # 3x4 pixel figure, row 0 = top
    for (c, r) in [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (0, 3), (2, 3)]:
        m.set(2 + c, 0, 22 - r, "stoplicht_rood")
        m.set(2 + c, 0, 18 - r, "stoplicht_groen_uit")
    _push_button_box(m)
    return m


@tile("props/verkeer/verkeerslicht_mast")
def traffic_light_mast():
    """Overhead traffic light mast with two heads on a long arm."""
    m = V(80, 4, 44)
    pole(m, 39, 1, 0, 42, "metaal3", 2)
    m.box(39, 1, 41, 78, 3, 42, "metaal3")
    light_head(m, 58, 1, 30, "rood")
    light_head(m, 72, 1, 30, "rood")
    return m


# ------------------------------------------------------------------ signs

def plate_shape(shape, x, z, n):
    """Classify plate pixel (x, z) of an n x n sign.

    Returns (inside, border). Shapes: "rond" (round), "vierkant" (square), "achthoek" (octagon),
    "driehoek" (triangle, point up), "driehoek_om" (triangle, point down), "ruit" (diamond).
    """
    c = (n - 1) / 2.0
    dx, dz = x - c, z - c
    if shape == "rond":
        return math.hypot(dx, dz) <= c + 0.3, math.hypot(dx, dz) > c - 0.9
    if shape == "vierkant":
        return True, abs(dx) > c - 0.6 or abs(dz) > c - 0.6
    if shape == "achthoek":
        inside = abs(dx) + abs(dz) <= c * 1.45
        return inside, abs(dx) + abs(dz) > c * 1.45 - 1.2 or abs(dx) > c - 0.6 or abs(dz) > c - 0.6
    if shape == "driehoek":  # point up
        t = z / (n - 1)
        half = c * (1 - t) + 0.4
        return abs(dx) <= half, abs(dx) > half - 1.2 or z == 0
    if shape == "driehoek_om":  # point down
        t = 1 - z / (n - 1)
        half = c * (1 - t) + 0.4
        return abs(dx) <= half, abs(dx) > half - 1.2 or z == n - 1
    if shape == "ruit":
        return abs(dx) + abs(dz) <= c + 0.3, abs(dx) + abs(dz) > c - 1.4
    return False, False


def sign_panel(shape, bg, rim, picto=None, pc="bord_zwart", n=9, text=None, inner=None, hgt=None):
    """Traffic sign on a pole: an n x n plate (see plate_shape) at the top, facing front (y=1).

    shape: plate shape; bg/rim: background and rim colour; picto: PICTO key or list of rows
    ('#' = pixel) drawn in colour pc; text: centred 3x5 font text in pc; inner: inner fill colour
    for a "ruit" (priority road diamond); hgt: total height (default 22 + n).
    Model size: (n + 2) x 4 x hgt. Keep the parameter names: SIGNS / props2.SIGNS2 pass them as kwargs.
    """
    H = hgt or (22 + n)
    m = V(n + 2, 4, H)
    pole(m, n // 2, 2, 0, H - 2, "metaal3")
    z0 = H - n - 1
    for z in range(n):
        for x in range(n):
            inside, border = plate_shape(shape, x, z, n)
            if not inside:
                continue
            c = rim if border and rim else bg
            if inner and not border and shape == "ruit" and abs(x - (n - 1) / 2) + abs(z - (n - 1) / 2) < (n - 1) / 2 - 1.5:
                c = inner
            m.set(x + 1, 1, z0 + z, c)
            m.set(x + 1, 2, z0 + z, "metaal1")
    if picto:
        rows = PICTO[picto] if isinstance(picto, str) else picto
        ph, pw = len(rows), len(rows[0])
        ox = 1 + (n - pw) // 2
        oz = z0 + (n - ph) // 2 + ph - 1
        for r, line in enumerate(rows):
            for cc, v in enumerate(line):
                if v == "#":
                    m.set(ox + cc, 1, oz - r, pc)
    if text:
        px, (tw, _) = text_pixels(text)
        _stamp(m, px, 1 + (n - tw) // 2, 1, z0 + (n - 5) // 2 + 4, pc)
    return m


# Dutch road signs: tile name suffix -> sign_panel kwargs (registered as props/borden/bord_<key>).
SIGNS = {
    "max_30": dict(shape="rond", bg="bord_wit", rim="bord_rood", text="30", n=11),
    "max_50": dict(shape="rond", bg="bord_wit", rim="bord_rood", text="50", n=11),
    "max_80": dict(shape="rond", bg="bord_wit", rim="bord_rood", text="80", n=11),
    "max_100": dict(shape="rond", bg="bord_wit", rim="bord_rood", text="100", n=13),
    "stop": dict(shape="achthoek", bg="bord_rood", rim="bord_wit", picto=["#######"], pc="bord_wit", n=11),
    "voorrang_verlenen": dict(shape="driehoek_om", bg="bord_wit", rim="bord_rood", n=11),
    "voorrangsweg": dict(shape="ruit", bg="bord_wit", rim="bord_zwart", inner="bord_geel", n=11),
    "voorrangskruispunt": dict(shape="driehoek", bg="bord_wit", rim="bord_rood", picto=["..#..", "..#..", "#####", "..#..", "..#.."], n=11),
    "gevaar": dict(shape="driehoek", bg="bord_wit", rim="bord_rood", picto="uitroep", n=11),
    "verboden_in_te_rijden": dict(shape="rond", bg="bord_rood", rim="bord_rood", picto=["#####"], pc="bord_wit"),
    "gesloten_verkeer": dict(shape="rond", bg="bord_wit", rim="bord_rood"),
    "eenrichtingsweg": dict(shape="vierkant", bg="bord_blauw", rim="bord_wit", picto="pijl_rechts", pc="bord_wit"),
    "verplicht_rechtdoor": dict(shape="rond", bg="bord_blauw", rim="bord_wit", picto="pijl_op", pc="bord_wit"),
    "fietspad": dict(shape="rond", bg="bord_blauw", rim="bord_wit", picto="fiets_klein", pc="bord_wit"),
    "voetpad": dict(shape="rond", bg="bord_blauw", rim="bord_wit", picto="voetganger", pc="bord_wit"),
    "parkeren": dict(shape="vierkant", bg="bord_blauw", rim="bord_wit", text="P", pc="bord_wit"),
    "zebrapad": dict(shape="vierkant", bg="bord_blauw", rim="bord_wit", picto=["...#...", "..###..", ".#####.", "#######"], pc="bord_wit"),
    "doodlopend": dict(shape="vierkant", bg="bord_blauw", rim="bord_wit", picto=["#####", "#####", "..#..", "..#..", "..#.."], pc="bord_wit"),
    "woonerf": dict(shape="vierkant", bg="bord_blauw", rim="bord_wit", picto="huis", pc="bord_wit"),
    "bushalte": dict(shape="vierkant", bg="bord_blauw", rim="bord_wit", picto="bus", pc="bord_wit"),
    "inrijverbod_auto": dict(shape="rond", bg="bord_wit", rim="bord_rood", picto="auto"),
}

for _n, _kw in SIGNS.items():
    register(f"props/borden/bord_{_n}", (lambda kw: lambda: sign_panel(**kw))(_kw))


@tile("props/borden/bord_bebouwde_kom")
def sign_place_name():
    """Blue place-name sign ("ZWERVR") on two poles."""
    m = V(32, 4, 30)
    pole(m, 2, 2, 0, 30, "metaal3")
    pole(m, 28, 2, 0, 30, "metaal3")
    px, (tw, _) = text_pixels("ZWERVR")
    _framed_panel(m, 1, 30, 20, 29, 1, "bord_wit", "bord_blauw", back="metaal1")
    _stamp(m, px, 16 - tw // 2, 0, 27, "bord_wit")
    return m


@tile("props/borden/wegwijzer")
def signpost():
    """Direction signpost with two white boards (CENTRUM right, STATION left) and red arrows."""
    m = V(68, 4, 32)
    pole(m, 33, 2, 0, 32, "metaal3")
    for row, (txt, arrow) in enumerate([("CENTRUM", 1), ("STATION", -1)]):
        z0 = 23 - row * 8
        px, _ = text_pixels(txt)
        _framed_panel(m, 35, 66, z0, z0 + 6, 1, "bord_blauw", "bord_wit", back="metaal1")
        _stamp(m, px, 37, 0, z0 + 5, "bord_blauw")
        # arrow: 3-high bar plus a tip pointing in the direction of ``arrow``
        ax = 64 if arrow > 0 else 62
        for dz in range(-1, 2):
            m.set(ax, 0, z0 + 3 + dz, "bord_rood")
        m.set(ax + arrow, 0, z0 + 3, "bord_rood")
    return m


@tile("props/borden/snelweg_portaal")
def highway_gantry():
    """Highway sign gantry: two lattice towers, a truss beam, two direction boards and three matrix signs."""
    m = V(100, 6, 64)
    # hollow 4x4 towers
    for x0 in (2, 94):
        for z in range(0, 62):
            for dx in range(4):
                for dy in range(1, 5):
                    if dx in (0, 3) or dy in (1, 4):
                        m.set(x0 + dx, dy, z, "gegalvaniseerd")
    # truss beam: top and bottom chords with a vertical every 4 voxels
    for x in range(2, 98):
        for z in (54, 61):
            for y in (1, 4):
                m.set(x, y, z, "gegalvaniseerd")
        if x % 4 == 0:
            for z in range(54, 62):
                m.set(x, 1, z, "gegalvaniseerd")
                m.set(x, 4, z, "gegalvaniseerd")
    # direction boards (white rim, blue fill)
    for (x0, x1, txt) in ((10, 46, "ZWERVR"), (52, 90, "CENTRUM")):
        px, (tw, _) = text_pixels(txt)
        _framed_panel(m, x0, x1 - 1, 42, 53, 0, "bord_wit", "bord_blauw")
        _stamp(m, px, (x0 + x1) // 2 - tw // 2, 0, 50, "bord_wit")
        # small arrow below the text
        for dz in range(3):
            for k in range(3 - dz):
                m.set((x0 + x1) // 2 - 1 + k + dz // 2, 0, 44 + dz, "bord_wit")
    # matrix signs (showing a cross) hanging from the beam
    for x0 in (14, 40, 66):
        m.box(x0, 2, 32, x0 + 8, 3, 40, "bord_zwart")
        for k in range(1, 7):
            m.set(x0 + k, 1, 32 + k, "matrix")
            m.set(x0 + 7 - k, 1, 32 + k, "matrix")
        m.box(x0 + 4, 2, 40, x0 + 5, 3, 54, "gegalvaniseerd")
    return m


@tile("props/borden/hectometerpaal")
def hectometre_post():
    """Green hectometre marker post."""
    m = _post(8, "bord_groen")
    m.set(0, 0, 6, "bord_wit")
    m.set(1, 0, 5, "bord_wit")
    return m


@tile("props/borden/reflectorpaal")
def reflector_post():
    """White roadside reflector post."""
    m = _post(8, "bord_wit")
    m.set(0, 0, 6, "bord_zwart")
    m.set(1, 0, 6, "bord_rood")
    return m


@tile("props/verkeer/verkeerskegel")
def traffic_cone():
    """Orange traffic cone with white bands."""
    m = V(6, 6, 6)
    for z in range(6):
        m.cyl(3, 3, 2.8 - z * 0.45, z, z + 1, "bord_oranje" if z not in (2, 4) else "bord_wit")
    m.box(0, 0, 0, 6, 6, 1, "bord_oranje")  # square base
    return m


@tile("props/verkeer/dranghek")
def crowd_barrier():
    """Galvanised crowd-control barrier."""
    m = V(20, 4, 9)
    for x in range(20):
        m.set(x, 2, 8, "gegalvaniseerd")
        m.set(x, 2, 1, "gegalvaniseerd")
        if x % 2 == 0:
            for z in range(1, 8):
                m.set(x, 2, z, "gegalvaniseerd")
    for x in (1, 18):  # feet
        for y in range(4):
            m.set(x, y, 0, "gegalvaniseerd")
    return m


@tile("props/verkeer/wegafzetting")
def road_barrier():
    """Red/white road barrier board with amber lamps."""
    m = V(16, 4, 8)
    for x in range(16):
        for z in (5, 6):
            m.set(x, 1, z, "bord_rood" if (x // 3) % 2 else "bord_wit")
    for x in (2, 13):
        for z in range(0, 7):
            m.set(x, 2, z, "metaal2")
        for y in range(4):
            m.set(x, y, 0, "metaal2")
    m.set(2, 1, 7, "stoplicht_oranje")
    m.set(13, 1, 7, "stoplicht_oranje")
    return m


# ------------------------------------------------------------------ bollards & posts

@tile("props/paaltjes/amsterdammertje")
def amsterdammertje():
    """Brown Amsterdam bollard with the three red crosses (XXX) of the city arms on the front."""
    m = _post(9, "paal_bruin")
    for z in (6, 4, 2):
        m.set(0, 0, z, "luifel_rood")
        m.set(1, 0, z, "luifel_rood")
    return m


@tile("props/paaltjes/paal_beton")
def post_concrete():
    """Round concrete bollard."""
    m = V(4, 4, 6)
    for z in range(5):
        m.cyl(2, 2, 1.8, z, z + 1, mix("beton1", "beton3", seed=14))
    m.cyl(2, 2, 1.0, 5, 6, "beton3")
    return m


@tile("props/paaltjes/paal_rvs")
def post_steel():
    """Stainless steel bollard."""
    return _post(7, "rvs")


@tile("props/paaltjes/paal_afzet")
def bollard():
    """White barrier post with a red band."""
    return _post(8, lambda z: "bord_rood" if z in (5, 6) else "bord_wit")


@tile("props/paaltjes/fietspaal")
def bike_post():
    """White bicycle-path post with red bands every 3 voxels."""
    return _post(8, lambda z: "bord_rood" if z % 3 == 0 else "bord_wit")


@tile("props/paaltjes/bolder")
def quay_bollard():
    """Cast-iron mooring bollard on a quay."""
    m = V(4, 4, 6)
    for z in range(6):
        r = 1.8 if z < 2 else (1.3 if z < 4 else 1.9)
        m.cyl(2, 2, r, z, z + 1, "metaal_donker")
    return m


@tile("props/paaltjes/parkeerautomaat")
def parking_meter():
    """Parking meter with a lit display."""
    m = V(4, 4, 12)
    m.box(0, 1, 0, 4, 4, 11, "antraciet1")
    m.box(0, 1, 11, 4, 4, 12, "metaal3")
    m.box(1, 0, 7, 3, 1, 10, "lamp_wit")  # display
    m.set(2, 0, 5, "bord_geel")
    return m


@tile("props/paaltjes/laadpaal")
def charging_post():
    """EV charging post with a status light and socket."""
    m = V(4, 4, 11)
    m.box(0, 1, 0, 4, 3, 10, "stuc1")
    m.box(0, 1, 10, 4, 3, 11, "bord_groen")
    m.set(1, 0, 8, "stoplicht_groen")
    m.set(2, 0, 6, "rubber")
    m.set(2, 0, 5, "rubber")
    return m


@tile("props/straat/elektriciteitskast")
def electrical_cabinet():
    """Grey electrical/utility cabinet with a door seam."""
    m = V(10, 6, 10)
    m.box(0, 1, 0, 10, 5, 9, "paneel1")
    m.box(0, 1, 9, 10, 5, 10, "paneel2")
    m.box(5, 1, 1, 6, 2, 9, "paneel2")  # door seam
    return m


@tile("props/straat/brievenbus")
def mailbox():
    """Red post box with a mail slot."""
    m = V(6, 6, 10)
    m.box(1, 1, 0, 5, 5, 9, "bord_rood")
    m.box(1, 1, 9, 5, 5, 10, "bord_rood2")
    for x in (2, 3):
        m.set(x, 0, 7, "rubber")
    return m


@tile("props/straat/vlaggenmast")
def flagpole():
    """Flagpole with a waving Dutch flag (red/white/blue)."""
    m = V(28, 4, 64)
    m.box(14, 1, 0, 15, 3, 64, "stuc1")
    for x in range(15, 27):
        for i, c in enumerate(["vlag_rood", "vlag_rood", "vlag_wit", "vlag_wit", "vlag_blauw", "vlag_blauw"]):
            m.set(x, 1, 62 - i - (x // 6), c)
    return m


@tile("props/straat/fontein")
def fountain():
    """Round stone fountain basin with a central jet."""
    m = V(24, 24, 14)
    for y in range(24):
        for x in range(24):
            d = math.hypot(x + 0.5 - 12, y + 0.5 - 12)
            if d < 12:
                m.set(x, y, 0, "natuursteen2")
                if d > 10.6:      # basin rim
                    for z in range(1, 4):
                        m.set(x, y, z, "natuursteen1")
                elif d < 10.6:    # water
                    m.set(x, y, 1, "water1")
                    m.set(x, y, 2, "water3")
    for z in range(1, 8):
        m.cyl(12, 12, 1.5, z, z + 1, "natuursteen1")
    m.cyl(12, 12, 4, 8, 9, "natuursteen1")
    for z in range(9, 13):
        m.cyl(12, 12, 1.0 + (z - 9) * 0.6, z, z + 1, "water3")
    return m


@tile("props/straat/kiosk")
def kiosk():
    """Round green kiosk with window strips and a zinc cone roof."""
    m = V(24, 24, 32)
    for z in range(0, 22):
        for y in range(24):
            for x in range(24):
                d = math.hypot(x + 0.5 - 12, y + 0.5 - 12)
                if d < 9:
                    window = int(math.atan2(y - 12, x - 12) * 4) % 2
                    m.set(x, y, z, "amsterdamgroen" if z < 4 or z > 18 else ("glas1" if window else "amsterdamgroen"))
    m.box(8, 3, 4, 16, 4, 10, "hout1")  # counter flap
    for z in range(22, 30):
        m.cyl(12, 12, 11 - (z - 22) * 1.4, z, z + 1, "zink1")
    m.cyl(12, 12, 1, 30, 32, "amsterdamgroen")
    return m


# ------------------------------------------------------------------ fences

@tile("props/hekken/hek_ijzer")
def fence_iron():
    """Green wrought-iron fence segment (16 voxels = 2 m)."""
    m = V(16, 2, 9)
    for x in range(16):
        m.set(x, 0, 1, "amsterdamgroen")
        m.set(x, 0, 7, "amsterdamgroen")
        if x % 2 == 0:
            for z in range(0, 9):
                m.set(x, 0, z, "amsterdamgroen")
    for x in (0, 15):  # end posts
        m.box(x, 0, 0, x + 1, 2, 9, "amsterdamgroen")
    return m


@tile("props/hekken/hek_ijzer_poort")
def fence_iron_gate():
    """Iron fence segment with a diagonal-braced gate and brass latch."""
    m = fence_iron()
    for z in range(2, 7):
        for x in range(3, 13):
            if (x + z) % 4 == 0:
                m.set(x, 0, z, "amsterdamgroen")
    m.set(8, 1, 4, "messing")
    return m


@tile("props/hekken/schutting_hout")
def fence_wood():
    """Wooden garden fence (vertical boards with back rails)."""
    m = V(16, 2, 15)
    for x in range(16):
        for z in range(14):
            m.set(x, 0, z, pick(["hout2", "hout1", "hout3"], x // 2, 0, 0, 15) if x % 2 == 0 else "hout_donker1")
    for x in (0, 15):
        m.box(x, 1, 0, x + 1, 2, 15, "hout_donker2")
    for z in (3, 11):
        m.box(0, 1, z, 16, 2, z + 1, "hout_donker1")
    return m


@tile("props/hekken/tuinhek_wit")
def garden_gate_white():
    """Low white picket fence."""
    m = V(16, 2, 7)
    for x in range(16):
        m.set(x, 1, 2, "kozijn_wit")
        m.set(x, 1, 5, "kozijn_wit")
        if x % 2 == 0:
            for z in range(0, 6):
                m.set(x, 0, z, "kozijn_wit")
            if x % 4 == 0:
                m.set(x, 0, 6, "kozijn_wit")
    return m


@tile("props/hekken/bouwhek")
def construction_fence():
    """Mesh construction-site fence on concrete feet, with a banner."""
    m = V(28, 6, 17)
    for x in range(28):
        for z in range(1, 17):
            if x in (1, 26) or z in (1, 16) or (x % 2 == 0 and z % 2 == 0):
                m.set(x, 2, z, "gegalvaniseerd")
    for x0 in (0, 25):
        for x in range(x0, x0 + 3):
            for y in range(0, 6):
                m.set(x, y, 0, "beton1")
                m.set(x, y, 1, "beton1" if 1 <= y <= 4 else 0)
    for x in range(4, 24):
        for z in range(10, 15):
            m.set(x, 3, z, "bord_oranje" if z in (10, 14) else "bord_wit")
    return m


@tile("props/hekken/hek_kade")
def fence_quay():
    """Quay railing with posts every 8 voxels and a wavy mid rail."""
    m = V(16, 2, 8)
    for x in range(16):
        m.set(x, 0, 7, "metaal_donker")
        if x % 8 == 0:
            m.box(x, 0, 0, x + 1, 2, 8, "metaal_donker")
        else:
            m.set(x, 0, 4 + int(abs(math.sin(x * math.pi / 8)) * 2), "metaal_donker")
    return m


@tile("props/hekken/vangrail")
def guardrail():
    """Galvanised highway guardrail (32 voxels) with one post."""
    m = V(32, 2, 6)
    m.box(0, 0, 3, 32, 1, 5, "gegalvaniseerd")
    m.box(8, 1, 0, 9, 2, 5, "metaal2")
    m.box(24, 1, 0, 25, 2, 5, "metaal2")
    return m


def _hedge(hgt, leaf, seed):
    """Trimmed hedge segment 16x6xhgt; outer surface slightly ragged (hash seed, pick seed + 1)."""
    m = V(16, 6, hgt)
    for z in range(hgt):
        for y in range(6):
            for x in range(16):
                edge = y in (0, 5) or z == hgt - 1
                if not edge or h(x, y, z, seed) < 0.8:
                    m.set(x, y, z, pick(["haag1", "haag2", leaf], x, y, z, seed + 1))
    return m


@tile("props/hekken/haag")
def hedge():
    """Hedge, 10 voxels high."""
    return _hedge(10, "blad5", 16)


@tile("props/hekken/haag_laag")
def hedge_low():
    """Low hedge, 5 voxels high."""
    return _hedge(5, "blad3", 18)


# ------------------------------------------------------------------ stairs

def stairs(width, steps, rise=1, run=2, railing=True, mat="beton1"):
    """Straight flight of stairs climbing towards +y.

    width: tread width in voxels (x); steps: number of steps; rise/run: step height/depth in voxels;
    railing: add rails on both sides; mat: colour of step edges (tread fill is mixed concrete).
    """
    depth = steps * run
    m = V(width + 2, depth + 2, steps * rise + 8)
    for s in range(steps):
        for y in range(s * run, depth):
            for x in range(1, width + 1):
                for z in range(s * rise, (s + 1) * rise):
                    m.set(x, y + 1, z, mat if y >= (s + 1) * run - 1 or y == s * run else mix("beton2", "beton1", seed=20))
    if railing:
        for x in (0, width + 1):
            for y in range(depth + 1):
                top = min(steps, y // run + 1) * rise
                m.set(x, y + 1, top + 6, "rvs")
                if y % 4 == 0:  # baluster
                    for z in range(max(0, top - rise), top + 6):
                        m.set(x, y + 1, z, "rvs")
    return m


register("props/trappen/stoeptrap", lambda: stairs(12, 3, 1, 2, railing=False, mat="natuursteen1"))
register("props/trappen/trap_1m", lambda: stairs(14, 8, 1, 2))
register("props/trappen/trap_1m_breed", lambda: stairs(30, 8, 1, 2))
register("props/trappen/trap_3m", lambda: stairs(14, 24, 1, 2))


@tile("props/trappen/trap_metaal_3m")
def stairs_metal():
    """Metal stairs, 3 m high."""
    return stairs(10, 24, 1, 2, mat="metaal1")


# ------------------------------------------------------------------ planters & plants

def shrub(m, cx, cy, cz, rx, ry, rz, colors, seed, flowers=None):
    """Draw a closed ellipsoid shrub into m; colour varies per 2x2x2 block.

    colors: leaf colour names; flowers: optional flower colours (~18% of blocks).
    """
    def cfun(x, y, z):
        if flowers and h(x // 2, y // 2, z // 2, seed + 1) < 0.18:
            return pick(flowers, x // 2, y // 2, z // 2, seed + 2)
        return pick(colors, x // 2, y // 2, z // 2, seed + 3)
    m.ellipsoid(cx, cy, cz, rx, ry, rz, cfun)


@tile("props/planten/plantenbak_beton")
def planter_concrete():
    """Concrete planter with a shrub."""
    m = V(16, 8, 12)
    m.box(0, 0, 0, 16, 8, 5, mix("beton1", "beton3", seed=21))
    m.box(1, 1, 4, 15, 7, 5, "aarde_donker")
    shrub(m, 8, 4, 7, 7, 3.5, 3.5, ["blad1", "blad2", "blad4", "blad3"], 22)
    return m


@tile("props/planten/plantenbak_hout")
def planter_wood():
    """Square wooden planter with flowers around a small shrub."""
    m = V(16, 16, 10)
    for z in range(5):
        for y in range(16):
            for x in range(16):
                if x in (0, 15) or y in (0, 15):
                    m.set(x, y, z, "hout2" if z % 2 else "hout1")
                elif z == 4:
                    m.set(x, y, z, "aarde_donker")
    for y in range(2, 14, 2):
        for x in range(2, 14, 2):
            m.set(x, y, 5, "blad2")
            m.set(x, y, 6, pick(["bloem_rood", "bloem_geel", "bloem_paars", "bloem_wit", "bloem_roze"], x, y, 0, 23))
    shrub(m, 8, 8, 7, 3, 3, 2.5, ["blad1", "blad4"], 24)
    return m


@tile("props/planten/pot_terracotta")
def pot_terracotta():
    """Terracotta pot with a flowering plant."""
    m = V(6, 6, 10)
    for z in range(4):
        m.cyl(3, 3, 1.8 + z * 0.3, z, z + 1, "terracotta1" if z < 3 else "terracotta2")
    shrub(m, 3, 3, 6, 2.6, 2.6, 2.8, ["blad2", "blad4", "blad1"], 25, ["bloem_rood", "bloem_roze"])
    return m


@tile("props/planten/boombak")
def tree_planter():
    """Concrete tree planter with a small tree."""
    m = V(20, 20, 56)
    m.box(1, 1, 0, 19, 19, 5, mix("beton1", "beton3", seed=26))
    m.box(2, 2, 4, 18, 18, 5, "aarde_donker")
    for z in range(5, 28):
        m.cyl(10, 10, 1.1, z, z + 1, "schors1")
    shrub(m, 10, 10, 40, 8.5, 8.5, 12, ["blad1", "blad2", "blad4", "blad_licht"], 27)
    return m


@tile("props/planten/struik")
def shrub_round():
    """Round shrub."""
    m = V(12, 12, 9)
    shrub(m, 6, 6, 4, 5.5, 5.5, 4.5, ["blad1", "blad3", "blad5", "blad2"], 28)
    return m


@tile("props/planten/struik_bloei")
def shrub_flowering():
    """Round flowering shrub."""
    m = V(12, 12, 9)
    shrub(m, 6, 6, 4, 5.5, 5.5, 4.5, ["blad1", "blad3", "blad2"], 29, ["bloem_roze", "bloesem1", "bloem_wit"])
    return m


@tile("props/planten/hortensia")
def hydrangea():
    """Hydrangea bush."""
    m = V(10, 10, 8)
    shrub(m, 5, 5, 3.5, 4.5, 4.5, 3.8, ["blad2", "blad1"], 30, ["bloem_paars", "bloem_roze", "luifel_blauw"])
    return m


@tile("props/planten/buxus_bol")
def boxwood():
    """Box ball in a square pot."""
    m = V(8, 8, 8)
    m.box(1, 1, 0, 7, 7, 2, "terracotta2")
    m.ellipsoid(4, 4, 5, 3.2, 3.2, 3, mix("haag1", "haag2", seed=31))
    return m


@tile("props/planten/bloemen")
def flower_bed():
    """Patch of loose flowers."""
    m = V(8, 8, 4)
    for y in range(8):
        for x in range(8):
            if h(x, y, 0, 32) < 0.5:
                m.set(x, y, 0, "blad2")
                m.set(x, y, 1, "blad4")
                if h(x, y, 1, 32) < 0.6:
                    m.set(x, y, 2, pick(["bloem_rood", "bloem_geel", "bloem_paars", "bloem_wit", "bloem_oranje"], x, y, 0, 33))
    return m


@tile("props/planten/varen")
def fern():
    """Fern: seven arching fronds."""
    m = V(10, 10, 6)
    for i in range(7):
        a = i / 7 * math.tau
        for t in range(1, 5):
            x = 5 + math.cos(a) * t
            y = 5 + math.sin(a) * t
            z = 1 + t * 0.7 - (t * t) * 0.15
            m.set(x, y, z, "blad4" if t > 2 else "blad2")
    m.set(5, 5, 0, "blad3")
    return m


@tile("props/planten/riet")
def reeds():
    """Clump of reeds with plumes at varying heights."""
    m = V(8, 8, 16)
    for y in range(8):
        for x in range(8):
            if h(x, y, 0, 34) < 0.35:
                hh = 8 + int(h(x, y, 1, 34) * 7)
                for z in range(hh):
                    m.set(x, y, z, "riet2" if z < hh // 2 else "riet1")
                m.set(x, y, hh, "riet_pluim")
    return m


@tile("props/planten/graspol")
def grass_tuft():
    """Tuft of grass, tallest in the middle."""
    m = V(6, 6, 6)
    for y in range(6):
        for x in range(6):
            d = math.hypot(x + 0.5 - 3, y + 0.5 - 3)
            if d < 2.8:
                hh = int(5 - d * 1.4 + h(x, y, 0, 35) * 2)
                for z in range(max(1, hh)):
                    m.set(x, y, z, "gras_droog" if z > 2 else "gras4")
    return m


# ------------------------------------------------------------------ trees

def trunk(m, cx, cy, height, r, bark):
    """Tapering vertical trunk at (cx, cy) from z=0 to height, with a wider foot (bark: colour or fn)."""
    for z in range(height):
        rr = r + (0.8 if z < 2 else 0) - z * 0.012
        m.cyl(cx, cy, rr, z, z + 1, bark)


def crown_clusters(m, cx, cy, base, top, radius, n, leaves, seed, shape="rond", blossom=None, light="blad_licht"):
    """Tree crown made of n leaf ellipsoids between z=base and z=top, each joined to the trunk by a branch.

    shape: "rond" (round), "zuil" (columnar), "breed" (broad) or anything else (loose).
    leaves: leaf colours (the last one is used for the shaded underside); blossom: optional
    blossom colours (~40% of blocks); light: colour of sunlit tops. Colour varies per 2x2x2 block.
    """
    pts = []
    for i in range(n):
        a = h(i, 0, 0, seed) * math.tau
        t = h(i, 1, 0, seed)
        if shape == "rond":
            r = radius * 0.65 * math.sqrt(h(i, 2, 0, seed))
            z = base + (top - base) * (0.3 + 0.55 * t)
        elif shape == "zuil":
            r = radius * 0.45 * h(i, 2, 0, seed)
            z = base + (top - base) * t
        elif shape == "breed":
            r = radius * 0.75 * math.sqrt(h(i, 2, 0, seed))
            z = base + (top - base) * (0.35 + 0.4 * t)
        else:
            r = radius * 0.6 * h(i, 2, 0, seed)
            z = base + (top - base) * t
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, z))
    for i, (px, py, pz) in enumerate(pts):
        sr = radius * (0.38 + 0.2 * h(i, 3, 0, seed))
        if shape == "zuil":
            sr *= 0.8
        m.line((cx, cy, base - 4), (px, py, pz), "schors2", 0.6)

        def cfun(x, y, z, pz=pz, sr=sr):
            bx, by, bz = x // 2, y // 2, z // 2   # colour per 2x2x2 block: fewer stray faces
            if blossom and h(bx, by, bz, seed + 5) < 0.4:
                return pick(blossom, bx, by, bz, seed + 6)
            rel = (z - (pz - sr)) / (2 * sr)      # 0 = bottom of the cluster, 1 = top
            if rel > 0.7 and h(bx, by, bz, seed + 7) < 0.5:
                return P[light]
            if rel < 0.3:
                return P[leaves[-1]]
            return pick(leaves, bx, by, bz, seed + 8)

        # closed crown; the variation is in the colour
        m.ellipsoid(px, py, pz, sr, sr, sr * (1.25 if shape == "zuil" else 0.85), cfun)


def deciduous_tree(seed, size=1.0, leaves=("blad1", "blad2", "blad4", "blad3"), bark="schors1", shape="rond",
                   blossom=None, trunk_h=None, light="blad_licht"):
    """Generic deciduous tree; the canvas (even width) scales with ``size`` (1.0 = 42x42x78 voxels).

    seed: hash seed for the crown; leaves/bark/shape/blossom/light: see crown_clusters;
    trunk_h: trunk height (default 42% of the model height).
    """
    R = int(18 * size)
    Wd = 2 * R + 6
    Wd += Wd % 2
    Ht = int(72 * size) + 6
    m = V(Wd, Wd, Ht)
    cx = cy = Wd / 2
    th = trunk_h or int(Ht * 0.42)
    trunk(m, cx, cy, th, 1.6 * size + 0.4, bark)
    crown_clusters(m, cx, cy, th, Ht - R * 0.55, R, 6, list(leaves), seed, shape, blossom, light)
    return m


register("props/bomen/linde", lambda: deciduous_tree(101))
register("props/bomen/eik", lambda: deciduous_tree(102, 1.15, ("blad3", "blad1", "blad5", "blad2"), "schors2", "breed"))
register("props/bomen/kastanje", lambda: deciduous_tree(103, 1.1, ("blad5", "blad1", "blad3", "blad5"), "schors2", "rond", ["bloem_wit", "bloesem2"]))
register("props/bomen/plataan", lambda: deciduous_tree(104, 1.2, ("blad2", "blad4", "blad1", "blad3"), "plataanschors", "breed"))
register("props/bomen/herfstboom", lambda: deciduous_tree(105, 1.0, ("herfst1", "herfst2", "herfst3", "herfst2"), "schors1", light="herfst3"))
register("props/bomen/bloesemboom", lambda: deciduous_tree(106, 0.75, ("bloesem1", "bloesem2", "bloesem1", "blad4"), "schors3", light="bloesem2"))
register("props/bomen/jonge_boom", lambda: _young_tree())
register("props/bomen/fruitboom", lambda: deciduous_tree(107, 0.6, ("blad2", "blad4", "blad1"), "schors3", blossom=["bloem_rood"]))


def _young_tree():
    """Small young tree with two support stakes and a cross bar."""
    m = deciduous_tree(108, 0.5, ("blad4", "blad2", "blad_licht"), "schors3")
    cx = m.sx // 2
    for dx in (-3, 3):
        for z in range(0, 14):
            m.set(cx + dx, cx, z, "hout1")
    for x in range(cx - 3, cx + 4):
        m.set(x, cx, 10, "hout2")
    return m


@tile("props/bomen/populier")
def poplar():
    """Tall columnar poplar."""
    m = V(20, 20, 104)
    trunk(m, 10, 10, 30, 1.6, "schors3")
    crown_clusters(m, 10, 10, 26, 98, 12, 12, ["blad2", "blad4", "blad1", "blad3"], 109, "zuil")
    return m


@tile("props/bomen/berk")
def birch():
    """Birch with white bark and black flecks."""
    m = V(32, 32, 76)

    def bark(x, y, z):
        return P["berkenschors_zwart"] if h(x, y, z // 2, 110) < 0.18 else P["berkenschors"]
    trunk(m, 16, 16, 44, 1.2, bark)
    crown_clusters(m, 16, 16, 34, 70, 12, 10, ["blad4", "blad_licht", "blad2"], 111, "zuil")
    return m


@tile("props/bomen/den")
def pine():
    """Pine tree built from nine shrinking needle discs."""
    m = V(32, 32, 88)
    trunk(m, 16, 16, 40, 1.4, "schors2")
    for layer in range(9):
        z = 30 + layer * 6
        r = 13 - layer * 1.3
        m.ellipsoid(16, 16, z, r, r, 3, mix("naald1", "naald2", "naald3", seed=113))
    m.set(16, 16, 86, "naald3")
    m.set(16, 16, 85, "naald3")
    return m


@tile("props/bomen/conifeer")
def conifer():
    """Narrow conical conifer."""
    m = V(14, 14, 40)
    trunk(m, 7, 7, 4, 1, "schors2")
    for z in range(3, 38):
        r = 5.5 * (1 - (z - 3) / 38) + 0.6
        m.cyl(7, 7, r, z, z + 1, mix("naald1", "naald2", "naald3", seed=114))
    return m


@tile("props/bomen/treurwilg")
def weeping_willow():
    """Weeping willow with hanging branch curtains."""
    m = V(48, 48, 72)
    trunk(m, 24, 24, 30, 2.2, "schors2")
    crown_clusters(m, 24, 24, 34, 60, 18, 8, ["blad4", "blad_licht", "blad2"], 115, "breed")
    # hanging branches: 2x2 columns snapped to an even grid, one colour per branch
    for i in range(48):
        a = h(i, 0, 0, 116) * math.tau
        r = 10 + h(i, 1, 0, 116) * 10
        x = int(24 + math.cos(a) * r) // 2 * 2
        y = int(24 + math.sin(a) * r) // 2 * 2
        top = 52 - int(r * 0.4)
        length = 18 + int(h(i, 2, 0, 116) * 20)
        color = "blad_licht" if i % 3 else "blad4"
        m.box(x, y, max(2, top - length), x + 2, y + 2, top, color)
    return m


# ------------------------------------------------------------------ railway

@tile("props/spoor/bovenleidingmast")
def catenary_mast():
    """Railway overhead-line (catenary) mast with cantilever arm and insulator."""
    m = V(40, 4, 60)
    m.box(19, 1, 0, 21, 3, 58, "gegalvaniseerd")
    for z in range(0, 58, 6):
        m.set(19, 0, z, "gegalvaniseerd")
    m.box(20, 1, 52, 38, 2, 53, "gegalvaniseerd")
    m.box(20, 1, 46, 34, 2, 47, "gegalvaniseerd")
    for x in range(20, 34, 2):
        m.set(x, 1, 49, "gegalvaniseerd")
    m.box(30, 1, 42, 31, 2, 52, "metaal2")
    m.set(30, 1, 41, "rubber")
    return m


@tile("props/spoor/seinpaal")
def signal_post():
    """Railway signal post (green aspect lit)."""
    m = V(6, 4, 36)
    pole(m, 2, 1, 0, 28, "metaal2")
    m.box(1, 1, 28, 5, 3, 36, "bord_zwart")
    m.set(2, 0, 33, "stoplicht_groen")
    m.set(2, 0, 30, "stoplicht_rood_uit")
    m.box(0, 0, 27, 6, 1, 28, "bord_wit")
    return m


@tile("props/spoor/spoorboom")
def railway_barrier():
    """Level-crossing barrier: post with lights and St Andrew's cross, boom towards +x."""
    m = V(136, 6, 20)
    m.box(66, 1, 0, 70, 5, 10, "metaal2")
    m.box(66, 1, 10, 70, 5, 14, "bord_wit")
    for x in range(70, 134):
        c = "bord_rood" if (x // 4) % 2 else "bord_wit"
        m.set(x, 2, 8, c)
        m.set(x, 2, 9, c)
    for x in range(66, 70):
        for z in range(14, 20):
            m.set(x, 2, z, "metaal2" if x in (67, 68) else 0)
    # lights and St Andrew's cross
    m.set(66, 0, 12, "stoplicht_rood")
    m.set(69, 0, 12, "stoplicht_rood_uit")
    for i in range(-3, 4):
        c = "bord_rood" if abs(i) < 3 else "bord_wit"
        m.set(68 + i, 1, 17 + i, c)
        m.set(68 - i, 1, 17 + i, c)
    return m


@tile("props/spoor/andreaskruis")
def st_andrews_cross():
    """St Andrew's cross (level-crossing warning) with flashing lights."""
    m = V(12, 4, 30)
    pole(m, 5, 2, 0, 28, "metaal3")
    for i in range(-5, 6):
        c = "bord_rood" if abs(i) % 3 else "bord_wit"
        for (x, z) in ((6 + i, 22 + i), (6 - i, 22 + i)):
            m.set(x, 1, z, c)
            m.set(x, 1, z + 1, c)
    m.set(4, 0, 14, "stoplicht_rood")
    m.set(7, 0, 14, "stoplicht_rood_uit")
    return m


# ------------------------------------------------------------------ water

@tile("props/water/steiger")
def jetty():
    """Wooden jetty (16x32) on posts; deck at z=1."""
    m = V(16, 32, 4)
    for y in range(32):
        for x in range(16):
            m.set(x, y, 1, pick(["hout1", "hout2", "hout3"], x // 3, y, 0, 117) if y % 3 else "hout_donker1")
    for x in (0, 15):
        for y in range(0, 32, 8):
            m.box(x, y, 0, x + 1, y + 1, 4, "hout_donker2")
    return m


@tile("props/water/roeiboot")
def rowing_boat():
    """Open green rowing boat with thwarts, bow and stern along y."""
    m = V(12, 28, 6)
    for y in range(28):
        t = abs(y + 0.5 - 14) / 14
        half = 5.5 * math.sqrt(max(0, 1 - t ** 3))
        for x in range(12):
            dx = abs(x + 0.5 - 6)
            if dx < half:
                for z in range(0, 4):
                    inner = dx < half - 1 and z > 0
                    if not inner:
                        m.set(x, y, z, "boot_groen" if z < 3 else "hout1")
        if y % 9 == 4:  # thwart
            for x in range(2, 10):
                m.set(x, y, 2, "hout2")
    return m


@tile("props/water/sloep")
def sloop():
    """Open motor launch (sloep) with a wooden deck, seating rim and windscreen; bow at high y."""
    m = V(20, 48, 12)
    for y in range(48):
        t = (y + 0.5) / 48
        half = 9 * (1 - max(0, t - 0.7) ** 2 * 6) if t > 0.7 else 9 * min(1, 0.85 + t)
        half = max(1, half)
        for x in range(20):
            dx = abs(x + 0.5 - 10)
            if dx < half:
                for z in range(0, 5):
                    inner = dx < half - 1 and z > 1
                    if not inner:
                        m.set(x, y, z, "boot_wit" if z > 1 else "boot_blauw")
                if dx < half - 1:
                    m.set(x, y, 2, "hout1")
    for x in range(4, 16):
        for y in range(8, 22):
            if x in (4, 15) or y in (8, 21):
                m.set(x, y, 5, "hout2")
    for x in range(5, 15):  # windscreen
        m.set(x, 24, 5, "glas_helder")
        m.set(x, 24, 6, "glas_helder")
        m.set(x, 24, 4, "boot_wit")
    return m


def planks(x, y, z):
    """Colour function for horizontal wooden cladding (dark seam every 3rd row)."""
    return P["hout_donker1"] if (z % 3 == 0) else pick(["hout1", "hout2", "hout3"], (x + y) // 5, z // 3, 0, 118)


@tile("props/water/woonboot")
def houseboat():
    """Houseboat on a concrete hull: wooden cabin with windows, flat roof with solar panels."""
    m = V(36, 96, 28)
    # concrete hull with a raised edge
    for y in range(96):
        for x in range(36):
            for z in range(0, 6):
                edge = x in (0, 35) or y in (0, 95)
                if z < 5 or edge:
                    m.set(x, y, z, "beton_donker" if z < 2 else "beton2")
    # cabin walls; windows every 12 voxels on the long sides, every 10 on the short sides
    for y in range(6, 90):
        for x in range(3, 33):
            for z in range(6, 22):
                if x in (3, 32) or y in (6, 89):
                    win = (z in range(10, 18)) and (y % 12 in range(3, 10) if x in (3, 32) else x % 10 in range(3, 8))
                    m.set(x, y, z, "glas1" if win else planks(x, y, z))
    m.box(1, 4, 22, 35, 92, 23, "antraciet1")
    m.box(8, 20, 23, 28, 40, 24, "zonnepaneel")
    for x in range(4, 32, 4):  # flower pots on the front deck
        m.set(x, 2, 7, "bloem_rood")
        m.set(x, 2, 6, "terracotta1")
    return m


@tile("props/water/meerpaal")
def mooring_post():
    """Wooden mooring post."""
    m = V(4, 4, 12)
    for z in range(12):
        m.cyl(2, 2, 1.6, z, z + 1, "hout_donker2" if z < 10 else "hout_donker1")
    return m


@tile("props/water/reddingsboei")
def lifebuoy():
    """Orange/white lifebuoy hanging on a wooden post."""
    m = V(8, 4, 12)
    pole(m, 3, 2, 0, 12, "hout2")
    for z in range(3, 10):
        for x in range(8):
            d = math.hypot(x + 0.5 - 4, z + 0.5 - 6.5)
            if 2 < d < 3.6:
                m.set(x, 1, z, "bord_oranje" if int(math.atan2(z - 6.5, x - 4) * 2) % 2 else "bord_wit")
    return m
