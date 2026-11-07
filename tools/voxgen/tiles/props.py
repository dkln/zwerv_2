"""Props: street furniture, signs, trees, plants, fences, bollards, stairs, railway and water items.

Every function here returns a free-standing V model (no ground tile) and is registered under a
``props/...`` path via @tile / register; generate.py writes each to <OUT>/<path>.vox + .tile.json.

Conventions: 1 voxel = 12.5 cm, x = left->right, y = front->back (front = y=0), z = up.
The pivot is the bottom centre of the model. In the Props GridMap (0.5 m grid) the pivot sits on a
grid point, so props can be placed with fine granularity.

Shared helpers used by other modules (props_extra, extras_business_paths/5/7): pole, light_head, sign_panel, shrub,
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


# Slots of a full bike rack (voxels along the rack) that hold a bicycle, and their colours:
# one slot stays empty, so the row reads as separate bicycles.
RACK_BIKES = [(2, "fiets_zwart"), (7, "fiets_rood"), (12, "fiets_zwart"), (17, "fiets_blauw"), (27, "fiets_zwart"), (32, "fiets_zwart")]
# How far every other bicycle stands further forward (a Dutch high-low rack): so the
# handlebars of neighbours never touch.
RACK_STAGGER = 4


@tile("props/fietsen/fietsenrek_vol")
def bike_rack_full():
    """Bike rack with six bicycles parked front-to-back, one slot free: every other bicycle
    stands further forward (a high-low rack), so the handlebars of neighbours lie apart."""
    m = V(36, 22, 10)
    m.paste(bike_rack(), 2, 9, 0)
    for index, (slot, colour) in enumerate(RACK_BIKES):
        forward = RACK_STAGGER if index % 2 else 0
        # rotated bicycle: 6 wide, 16 deep; its frame lies in the middle of the 6
        m.paste(bicycle(colour).rot90(1), slot - 3, 1 + forward, 0)
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

# The bicycle in a lens of a bicycle light (column, row from the bottom): two wheels, the
# frame between them and the handlebars.
BIKE_IN_LENS = [(0, 0), (2, 0), (1, 1), (2, 2)]


def light_head(m, x, y, z, lit="rood", kind="auto"):
    """Draw a Dutch 3-aspect traffic light head into m: a black housing with round-looking
    lenses and a white edge on its contrast board.

    The 4-wide housing spans x..x+3, y..y+1 and z..z+9; lenses face the front at y-1.
    Aspects from bottom to top: green, amber, red; ``lit`` ("groen"/"oranje"/"rood") is lit,
    the others use their "_uit" colour. A white edge is drawn at x-1 and x+4.
    ``kind`` "fiets": a head one wider and three higher, with a bicycle in each lens.
    """
    if kind == "fiets":
        m.box(x, y, z, x + 5, y + 2, z + 13, "bord_zwart")
        for i, name in enumerate(["groen", "oranje", "rood"]):
            c = f"stoplicht_{name}" if name == lit else f"stoplicht_{name}_uit"
            for column, row in BIKE_IN_LENS:
                m.set(x + 1 + column, y - 1, z + 1 + i * 4 + row, c)
        for zz in range(z - 1, z + 14):
            for xx in (x - 1, x + 5):
                m.set(xx, y + 1, zz, "bord_wit")
        return
    m.box(x, y, z, x + 4, y + 2, z + 10, "bord_zwart")
    for i, name in enumerate(["groen", "oranje", "rood"]):
        zz = z + 1 + i * 3
        c = f"stoplicht_{name}" if name == lit else f"stoplicht_{name}_uit"
        m.box(x + 1, y - 1, zz, x + 3, y, zz + 2, c)
    for zz in range(z - 1, z + 11):
        for xx in (x - 1, x + 4):
            m.set(xx, y + 1, zz, "bord_wit")


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
    Model size: (n + 2) x 4 x hgt. Keep the parameter names: SIGNS / props_extra.SIGNS2 pass them as kwargs.
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


@tile("props/borden/bord_afrit")
def sign_exit():
    """Exit sign at the gore (beslispunt): blue board "AFRIT" with an arrow pointing up and to
    the right (away from the motorway), on two poles."""
    m = V(36, 4, 34)
    pole(m, 3, 2, 0, 34, "metaal3")
    pole(m, 32, 2, 0, 34, "metaal3")
    _framed_panel(m, 1, 34, 18, 33, 1, "bord_wit", "bord_blauw", back="metaal1")
    px, (tw, _) = text_pixels("AFRIT")
    _stamp(m, px, 4, 0, 30, "bord_wit")
    # diagonal arrow: shaft from bottom left to top right, head at the top right
    for k in range(8):
        m.set(24 + k, 0, 20 + k, "bord_wit")
        m.set(25 + k, 0, 20 + k, "bord_wit")
    for k in range(4):
        m.set(32 - k, 0, 28, "bord_wit")
        m.set(32, 0, 28 - k, "bord_wit")
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


# Crowns are built from CROWN_BLOCK^3 blocks of one colour each: chunky leaf balls without
# voxel noise, which read calmly from the iso camera (and need far fewer faces).
CROWN_BLOCK = 4


def blocky_ellipsoid(m, cx, cy, cz, rx, ry, rz, colour, origin=(0, 0, 0), block=CROWN_BLOCK):
    """Ellipsoid made of block^3 cubes on a grid starting at ``origin``: a cube is filled
    when its centre lies inside. ``colour(rel)`` gets the height of the cube in the
    ellipsoid (0 = bottom, 1 = top) and returns a colour."""
    ox, oy, oz = origin
    def snap(v, o):
        return int((v - o) // block) * block + o
    for z in range(snap(cz - rz, oz), int(cz + rz) + 1, block):
        for y in range(snap(cy - ry, oy), int(cy + ry) + 1, block):
            for x in range(snap(cx - rx, ox), int(cx + rx) + 1, block):
                c = block / 2
                d = ((x + c - cx) / rx) ** 2 + ((y + c - cy) / ry) ** 2 + ((z + c - cz) / rz) ** 2
                if d <= 1.0:
                    m.box(x, y, z, x + block, y + block, z + block, colour((z + c - (cz - rz)) / (2 * rz)))


def crown_clusters(m, cx, cy, base, top, radius, n, leaves, seed, shape="rond", blossom=None, light="blad_licht"):
    """Tree crown made of n blocky leaf balls between z=base and z=top (blocky_ellipsoid).

    shape: "rond" (round), "zuil" (columnar), "breed" (broad) or anything else (loose).
    leaves: leaf colours, one per ball (the last one is the shaded underside); blossom:
    optional blossom colours (on some blocks of the upper half); light: colour of the
    sunlit top of each ball.
    """
    pts = []
    for i in range(n):
        a = h(i, 0, 0, seed) * math.tau
        t = h(i, 1, 0, seed)
        if shape == "rond":
            r = radius * 0.6 * math.sqrt(h(i, 2, 0, seed))
            z = base + (top - base) * (0.35 + 0.5 * t)
        elif shape == "zuil":
            r = radius * 0.4 * h(i, 2, 0, seed)
            z = base + (top - base) * t
        elif shape == "breed":
            r = radius * 0.7 * math.sqrt(h(i, 2, 0, seed))
            z = base + (top - base) * (0.4 + 0.35 * t)
        else:
            r = radius * 0.55 * h(i, 2, 0, seed)
            z = base + (top - base) * t
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, z))
    # the block grid is centred on the trunk
    origin = (int(cx - CROWN_BLOCK // 2) % CROWN_BLOCK, int(cy - CROWN_BLOCK // 2) % CROWN_BLOCK, int(base) % CROWN_BLOCK)
    body = leaves[:-1] or leaves
    # the stem runs on into the lowest ball and a branch goes to every ball, so the crown
    # rests on the trunk (both hidden inside the crown where it is closed)
    lowest = min(p[2] for p in pts)
    m.cyl(cx, cy, 1.2, int(base) - 2, int(lowest) + 1, "schors2")
    for px, py, pz in pts:
        m.line((cx, cy, base - 4), (px, py, pz), "schors2", 1.0)
    for i, (px, py, pz) in enumerate(pts):
        sr = radius * (0.5 + 0.15 * h(i, 3, 0, seed))
        if shape == "zuil":
            sr *= 0.8
        main = body[i % len(body)]
        flower = blossom[i % len(blossom)] if blossom and i % 2 == 0 else None

        def colour(rel, main=main, flower=flower):
            if rel > 0.72:
                return P[flower] if flower else P[light]
            if rel < 0.3:
                return P[leaves[-1]]
            return P[main]

        blocky_ellipsoid(m, px, py, pz, sr, sr, sr * (1.25 if shape == "zuil" else 0.85), colour, origin)


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
    crown_clusters(m, cx, cy, th, Ht - R * 0.55, R, 4, list(leaves), seed, shape, blossom, light)
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
    crown_clusters(m, 10, 10, 26, 98, 12, 7, ["blad2", "blad4", "blad1", "blad3"], 109, "zuil")
    return m


@tile("props/bomen/berk")
def birch():
    """Birch with white bark and black flecks."""
    m = V(32, 32, 76)

    def bark(x, y, z):
        return P["berkenschors_zwart"] if h(x, y, z // 2, 110) < 0.18 else P["berkenschors"]
    trunk(m, 16, 16, 44, 1.2, bark)
    crown_clusters(m, 16, 16, 34, 70, 12, 6, ["blad4", "blad_licht", "blad2"], 111, "zuil")
    return m


@tile("props/bomen/den")
def pine():
    """Pine tree built from nine shrinking needle discs."""
    m = V(32, 32, 88)
    trunk(m, 16, 16, 40, 1.4, "schors2")
    for layer in range(9):
        z = 30 + layer * 6
        r = 13 - layer * 1.3
        m.ellipsoid(16, 16, z, r, r, 3, ("naald1", "naald2", "naald3")[layer % 3])
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
        m.cyl(7, 7, r, z, z + 1, ("naald1", "naald2", "naald3")[(z // 6) % 3])
    return m


@tile("props/bomen/treurwilg")
def weeping_willow():
    """Weeping willow with hanging branch curtains."""
    m = V(48, 48, 72)
    trunk(m, 24, 24, 30, 2.2, "schors2")
    crown_clusters(m, 24, 24, 34, 60, 18, 5, ["blad4", "blad_licht", "blad2"], 115, "breed")
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


# ------------------------------------------------------------------ cars

def car_greenhouse(model, first, last, roof_height, pillars, roof_up, base_up, paint, inside):
    """The glass upper part of a car from ``first`` to ``last`` along y, one column in from
    the sides: glass with the interior behind it, painted pillars at ``pillars``, a painted
    roof at ``roof_up``. ``roof_height`` gives the rows that slope (windscreen, rear window)
    their lower top; their side columns are painted too."""
    width = model.sx
    for along in range(first, last + 1):
        top = roof_height.get(along, roof_up)
        for across in range(1, width - 1):
            for up in range(base_up, top + 1):
                side = across in (1, width - 2)
                pillar = along in pillars or (along in roof_height and side)
                if up == top and along not in roof_height:
                    colour = paint                      # roof
                elif up == top or side:
                    colour = paint if pillar else "glas2"
                else:
                    colour = inside                     # seats behind the glass
                model.set(across, along, up, colour)


def sedan_body(paint, sill):
    """Sedan of 4.5 x 1.75 x 1.5 m in these colours, without its wheels (auto_wiel, placed
    and turned by scripts/vehicles/vehicle.gd at SEDAN_WHEEL_*): x across (14 voxels), y
    along (36, the front with the headlights at y=0, so it faces the way the prop faces), z
    up. Its lowest voxels (the floor) are 1 voxel above the road."""
    width, length, height = 14, 36, 12
    model = V(width, length, height)
    inside = "auto_interieur"
    # body: sill to beltline, the corners rounded off
    for along in range(length):
        for across in range(width):
            if along in (0, length - 1) and across in (0, width - 1):
                continue
            for up in range(2, 7):
                model.set(across, along, up, sill if up == 2 else paint)
    # greenhouse: windscreen rising y 10..12, roof y 13..24, rear window y 25..27
    car_greenhouse(model, 10, 27, {10: 7, 11: 8, 12: 9, 25: 9, 26: 8, 27: 7}, (13, 19, 24), 10, 7, paint, inside)
    # front: grille, headlights, bumper; rear: tail lights, bumper
    for across in range(width):
        for up in (2, 3):
            model.set(across, 0, up, "metaal_donker")
            model.set(across, length - 1, up, "metaal_donker")
    for across in range(5, 9):
        model.set(across, 0, 4, "rooster")
    for across in (1, 2, 3, width - 4, width - 3, width - 2):
        model.set(across, 0, 4, "lamp_wit")
        model.set(across, length - 1, 5, "signaal_rood")
        model.set(across, length - 1, 4, "signaal_rood")
    # number plates
    for across in range(5, 9):
        model.set(across, 0, 3, "bord_geel")
        model.set(across, length - 1, 3, "bord_geel")
    wheel_arches(model, SEDAN_WHEEL_ALONG, SEDAN_WHEEL_UP, 7)
    # floor and axles under the car
    for across in range(2, width - 2):
        for along in range(3, length - 3):
            model.set(across, along, 1, "metaal_donker")
    # wing mirrors: a painted housing with a dark glass face
    for across in (0, width - 1):
        model.set(across, 12, 6, paint)
        model.set(across, 12, 7, paint)
        model.set(across, 13, 7, "metaal_donker")
    car_details(model, paint=paint, seam=sill, doors=(12, 19, 26), handles=(16, 23), handle_up=6,
                belt_up=6, glass_along=range(13, 25), glass_up=7, grille=(4, 9, 4), fog_up=2,
                bonnet_along=9, boot_along=28, wiper=(10, 7), fuel_along=29, repeater_along=11,
                rear_badge_up=5, wheel_along=SEDAN_WHEEL_ALONG)
    # sunroof and aerial on the roof (height 10, y 13..24)
    for across in range(5, 9):
        for along in range(15, 19):
            model.set(across, along, 10, "glas2")
    model.set(width - 4, 23, 11, "metaal_donker")
    return model


@tile("props/voertuigen/auto_sedan")
def sedan():
    """Blue sedan: painted body with a darker sill and wheel arches, glass greenhouse with
    a dark interior behind it, roof, emissive head and tail lights, a grille, bumpers."""
    return sedan_body("autolak1", "autolak2")


@tile("props/voertuigen/auto_sedan_wit")
def sedan_white():
    """White sedan (the same body as auto_sedan)."""
    return sedan_body("lak_wit1", "lak_wit2")


@tile("props/voertuigen/auto_sedan_zilver")
def sedan_silver():
    """Silver sedan (the same body as auto_sedan)."""
    return sedan_body("lak_zilver1", "lak_zilver2")


def car_details(model, paint, seam, doors, handles, handle_up, belt_up, glass_along, glass_up, grille, fog_up,
                bonnet_along, boot_along, wiper, fuel_along, repeater_along, rear_badge_up, wheel_along):
    """Small details shared by the car bodies: door seams (a darker line down each side at
    ``doors``), chrome door handles (at ``handles``, height ``handle_up``), a chrome strip
    under the side windows (``glass_along`` at height ``glass_up``, over the belt at
    ``belt_up``), a chrome frame round the grille (columns ``grille[0]``..``grille[1]`` at
    height ``grille[2]``) with a badge in the middle, two fog lamps in the front bumper
    (height ``fog_up``), an exhaust pipe under the rear bumper, the shut lines of the bonnet
    (up to row ``bonnet_along``) and of the boot (from ``boot_along``, None = no boot),
    wipers on the windscreen (``wiper`` = its row and height), a fuel cap on the left, an
    orange side repeater on both wings, a badge on the back (height ``rear_badge_up``) and
    rubber mud flaps behind each wheel (``wheel_along``). Leaves the corner voxels for the
    indicators alone."""
    width, length = model.sx, model.sy
    for along in doors:
        for up in range(3, belt_up + 1):
            for across in (0, width - 1):
                if model.get(across, along, up):
                    model.set(across, along, up, seam)
    for along in handles:
        for across in (0, width - 1):
            if model.get(across, along, handle_up):
                model.set(across, along, handle_up, "rvs")
    for along in glass_along:
        for across, inner in ((0, 1), (width - 1, width - 2)):
            if model.get(inner, along, glass_up) and model.get(across, along, belt_up):
                model.set(across, along, belt_up, "rvs")
    left, right, up = grille
    for column in (left, right):
        model.set(column, 0, up, "rvs")
    model.set(width // 2, 0, up, "rvs")
    for across in (2, width - 3):
        model.set(across, 0, fog_up, "metaal3")
    model.set(3, length - 1, 1, "rvs")      # exhaust
    model.set(3, length - 2, 1, "metaal_donker")
    # shut lines on the bonnet and the boot: across at the end, along both edges
    for across in range(2, width - 2):
        model.set(across, bonnet_along, belt_up, seam)
    for along in range(1, bonnet_along):
        model.set(2, along, belt_up, seam)
        model.set(width - 3, along, belt_up, seam)
    if boot_along is not None:
        for across in range(2, width - 2):
            model.set(across, boot_along, belt_up, seam)
        for along in range(boot_along + 1, length - 1):
            model.set(2, along, belt_up, seam)
            model.set(width - 3, along, belt_up, seam)
    # wipers: two dark lines low on the windscreen
    wiper_along, wiper_up = wiper
    for across in (3, 4, 5, width - 6, width - 5, width - 4):
        model.set(across, wiper_along, wiper_up, "metaal_donker")
    model.set(width - 1, fuel_along, belt_up - 1, "metaal_donker")
    for across in (0, width - 1):
        model.set(across, repeater_along, belt_up - 1, "oranje")
        for along in wheel_along:
            flap = int(along) + 4
            if model.get(across, flap, 2):
                model.set(across, flap, 2, "rubber")
    model.set(width // 2, length - 1, rear_badge_up, "rvs")


# where the sedan's wheels go (voxels of its body): centres along (y) and up (z), radius
SEDAN_WHEEL_ALONG = (7.5, 28.0)
SEDAN_WHEEL_UP = 2.5
SEDAN_WHEEL_RADIUS = 2.6
# the wheel arches: this many outer columns are left open, the next one is the dark inner
# wall. A front wheel at full lock (vehicle.gd, max_steering_degrees) swings its corners a
# little past this, behind the wall, and its other side sticks out of the arch: as it does
# on a real car.
ARCH_DEPTH = 3


def wheel_arches(model, wheel_along_list, wheel_up, top, wheel_radius=SEDAN_WHEEL_RADIUS, depth=ARCH_DEPTH):
    """Opens the wheel arches of a body round the wheels (centres along y at
    ``wheel_along_list``, height ``wheel_up``), up to height ``top``: ``depth`` outer
    columns on each side open, a dark inner wall next to them."""
    width = model.sx
    reach = int(wheel_radius + 3)
    for wheel_along in wheel_along_list:
        for along in range(int(wheel_along - reach), int(wheel_along + reach)):
            for up in range(0, top):
                distance = ((along + 0.5 - wheel_along) ** 2 + (up + 0.5 - wheel_up) ** 2) ** 0.5
                if distance > wheel_radius + 0.9:
                    continue
                for column in range(depth):
                    model.set(column, along, up, 0)
                    model.set(width - 1 - column, along, up, 0)
                if up >= 2:
                    model.set(depth, along, up, "metaal_donker")
                    model.set(width - 1 - depth, along, up, "metaal_donker")


@tile("props/voertuigen/auto_suv")
def suv():
    """Body of an SUV of 4.75 x 1.75 x 1.88 m, without its wheels (auto_wiel, the same as
    the sedan's, at SUV_WHEEL_ALONG; placed and turned by scripts/vehicles/suv.gd): x
    across (14 voxels), y along (38, the front with the headlights at y=0), z up. A tall,
    boxy dark green body with black cladding round the bottom and the wheel arches, an
    upright windscreen, a long roof with roof rails, a square tailgate with a spare wheel,
    a big grille. Its floor is 2 voxels above the road (more ground clearance)."""
    width, length, height = 14, 38, 16
    model = V(width, length, height)
    paint, cladding, inside = "autolak3", "metaal_donker", "auto_interieur"
    # body: cladding at the bottom, paint up to the beltline, corners rounded off
    for along in range(length):
        for across in range(width):
            if along in (0, length - 1) and across in (0, width - 1):
                continue
            for up in range(2, 9):
                model.set(across, along, up, cladding if up <= 3 else paint)
    # greenhouse: short bonnet, upright windscreen y 9..10, roof y 11..35, upright tailgate
    roof_height = {9: 11, 10: 12}
    for along in range(9, length - 1):
        top = roof_height.get(along, 13)
        for across in range(1, width - 1):
            for up in range(9, top + 1):
                side = across in (1, width - 2)
                pillar = along in (11, 20, 28, length - 2) or (along in (9, 10) and side)
                if up == top and along >= 11:
                    colour = paint                      # roof
                elif up == top or side:
                    colour = paint if pillar else "glas2"
                elif along == length - 2:
                    colour = "glas2"                    # rear window in the tailgate
                else:
                    colour = inside
                model.set(across, along, up, colour)
    # roof rails
    for along in range(13, length - 4):
        for across in (2, width - 3):
            model.set(across, along, 14, "rvs")
    # front: big grille, headlights, bumper; rear: tail lights, bumper
    for across in range(width):
        for up in (2, 3):
            model.set(across, 0, up, cladding)
            model.set(across, length - 1, up, cladding)
    for across in range(4, 10):
        for up in (4, 5, 6):
            model.set(across, 0, up, "rooster")
    for across in (1, 2, 3, width - 4, width - 3, width - 2):
        model.set(across, 0, 6, "lamp_wit")
        for up in (5, 6, 7):
            model.set(across, length - 1, up, "signaal_rood")
    for across in range(5, 9):
        model.set(across, 0, 3, "bord_geel")
        model.set(across, length - 1, 4, "bord_geel")
    # spare wheel on the tailgate
    for across in range(4, 10):
        for up in range(5, 11):
            if ((across + 0.5 - 7) ** 2 + (up + 0.5 - 8) ** 2) ** 0.5 <= 3.0:
                model.set(across, length - 1, up, "rubber")
    wheel_arches(model, SUV_WHEEL_ALONG, SUV_WHEEL_UP, 9)
    # floor and axles under the car
    for across in range(ARCH_DEPTH + 1, width - ARCH_DEPTH - 1):
        for along in range(3, length - 3):
            model.set(across, along, 1, "metaal_donker")
    # wing mirrors: a painted housing with a dark glass face
    for across in (0, width - 1):
        model.set(across, 11, 8, paint)
        model.set(across, 11, 9, paint)
        model.set(across, 12, 9, "metaal_donker")
    car_details(model, paint=paint, seam="autolak4", doors=(11, 20, 28), handles=(15, 24), handle_up=8,
                belt_up=8, glass_along=range(11, length - 2), glass_up=9, grille=(3, 10, 5), fog_up=3,
                bonnet_along=8, boot_along=None, wiper=(9, 9), fuel_along=31, repeater_along=10,
                rear_badge_up=4, wheel_along=SUV_WHEEL_ALONG)
    # running boards between the wheels, a skid plate under the front bumper
    for along in range(12, 27):
        for across in (0, width - 1):
            model.set(across, along, 3, "rvs")
    for across in range(4, 10):
        model.set(across, 0, 1, "metaal3")
    # cross bars on the roof rails, a shark-fin aerial, a rear wiper
    for along in (16, 30):
        for across in range(2, width - 2):
            model.set(across, along, 14, "rvs")
    model.set(7, length - 6, 14, "metaal_donker")
    model.set(7, length - 7, 14, "metaal_donker")
    for across in range(6, 9):
        model.set(across, length - 2, 11, "metaal_donker")   # on the rear window
    return model


# where the SUV's wheels go (voxels of its body)
SUV_WHEEL_ALONG = (7.5, 30.5)
SUV_WHEEL_UP = 2.5


def hatchback_body(paint, sill):
    """Hatchback of 3.88 x 1.75 x 1.38 m in these colours, without its wheels (auto_wiel, at
    HATCHBACK_WHEEL_ALONG; placed and turned by scripts/vehicles/hatchback.gd): x across
    (14 voxels), y along (31, the front at y=0), z up. Shorter than the sedan, with a short
    bonnet and no boot: the roof runs on to a steep tailgate with a spoiler over its window
    and tall tail lights at the corners."""
    width, length, height = 14, 31, 12
    model = V(width, length, height)
    inside = "auto_interieur"
    for along in range(length):
        for across in range(width):
            if along in (0, length - 1) and across in (0, width - 1):
                continue
            for up in range(2, 7):
                model.set(across, along, up, sill if up == 2 else paint)
    # greenhouse: windscreen rising y 8..10, roof y 11..27, tailgate window y 28..29
    car_greenhouse(model, 8, 29, {8: 7, 9: 8, 10: 9, 28: 9, 29: 8}, (11, 18, 27), 10, 7, paint, inside)
    # front: grille, headlights, bumper; rear: bumper, plate, tail lights up the corners
    for across in range(width):
        for up in (2, 3):
            model.set(across, 0, up, "metaal_donker")
            model.set(across, length - 1, up, "metaal_donker")
    for across in range(5, 9):
        model.set(across, 0, 4, "rooster")
        model.set(across, 0, 3, "bord_geel")
        model.set(across, length - 1, 4, "bord_geel")
    for across in (1, 2, 3, width - 4, width - 3, width - 2):
        model.set(across, 0, 4, "lamp_wit")
    for across in (1, 2, width - 3, width - 2):
        for up in (4, 5, 6):
            model.set(across, length - 1, up, "signaal_rood")
    wheel_arches(model, HATCHBACK_WHEEL_ALONG, SEDAN_WHEEL_UP, 7)
    for across in range(2, width - 2):
        for along in range(3, length - 3):
            model.set(across, along, 1, "metaal_donker")
    for across in (0, width - 1):
        model.set(across, 10, 6, paint)
        model.set(across, 10, 7, paint)
        model.set(across, 11, 7, "metaal_donker")
    car_details(model, paint=paint, seam=sill, doors=(10, 17, 24), handles=(14, 21), handle_up=6,
                belt_up=6, glass_along=range(11, 28), glass_up=7, grille=(4, 9, 4), fog_up=2,
                bonnet_along=7, boot_along=None, wiper=(8, 7), fuel_along=25, repeater_along=9,
                rear_badge_up=5, wheel_along=HATCHBACK_WHEEL_ALONG)
    # spoiler over the tailgate window, with the third brake light in it; rear wiper
    for across in range(2, width - 2):
        model.set(across, 28, 10, paint)
    for across in (6, 7):
        model.set(across, 28, 10, "signaal_rood")
    for across in range(6, 9):
        model.set(across, 29, 8, "metaal_donker")
    return model


# where the hatchback's wheels go (voxels of its body)
HATCHBACK_WHEEL_ALONG = (6.5, 24.5)


@tile("props/voertuigen/auto_hatchback")
def hatchback():
    """Red hatchback (hatchback_body)."""
    return hatchback_body("lak_rood1", "lak_rood2")


@tile("props/voertuigen/auto_hatchback_zilver")
def hatchback_silver():
    """Silver hatchback (hatchback_body); this one tows the trailer."""
    return hatchback_body("lak_zilver1", "lak_zilver2")


@tile("props/voertuigen/auto_hatchback_groen")
def hatchback_green():
    """Dark green hatchback (hatchback_body)."""
    return hatchback_body("autolak3", "autolak4")


# where the van's wheels go (voxels of its body)
VAN_WHEEL_ALONG = (8.0, 31.0)


@tile("props/voertuigen/auto_busje")
def van():
    """White delivery van of 5 x 2 x 2.13 m, without its wheels (auto_wiel, at
    VAN_WHEEL_ALONG; placed and turned by scripts/vehicles/van.gd): x across (16 voxels),
    y along (40, the front at y=0), z up. A short sloping bonnet, a tall windscreen, windows
    in the cab only, a closed cargo box with a sliding door on the right (the pavement side)
    and two rear doors with windows, big mirrors, a ribbed roof."""
    width, length, height = 16, 40, 17
    model = V(width, length, height)
    paint, sill, inside = "lak_wit1", "lak_wit2", "auto_interieur"
    bonnet_top = {0: 7, 1: 7, 2: 8, 3: 8, 4: 9}
    roof_up = 16
    for along in range(length):
        for across in range(width):
            if along in (0, length - 1) and across in (0, width - 1):
                continue
            for up in range(2, bonnet_top.get(along, 9) + 1):
                model.set(across, along, up, sill if up == 2 else paint)
    # upper part: windscreen rising y 5..8, cab windows y 10..16, closed cargo box behind
    windscreen_top = {5: 10, 6: 12, 7: 14, 8: 15}
    for along in range(5, length):
        top = windscreen_top.get(along, roof_up)
        for across in range(1, width - 1):
            side = across in (1, width - 2)
            for up in range(10, top + 1):
                if along in windscreen_top:
                    colour = paint if side else ("glas2" if up == top else inside)
                elif up == top:
                    colour = sill if along % 5 == 0 and not side else paint     # roof ribs
                elif along == length - 1:
                    window = up in (11, 12, 13, 14) and (across in range(3, 7) or across in range(width - 7, width - 3))
                    colour = "glas2" if window else paint
                elif side:
                    window = along in range(10, 17) and up in (11, 12, 13, 14) and along not in (10, 16)
                    colour = "glas2" if window else paint
                else:
                    colour = inside
                model.set(across, along, up, colour)
    # front: bumper, grille with a chrome bar, headlights, plate
    for across in range(width):
        for up in (2, 3):
            model.set(across, 0, up, "metaal_donker")
            model.set(across, length - 1, up, "metaal_donker")
    for across in range(5, 11):
        for up in (5, 6):
            model.set(across, 0, up, "rooster")
        model.set(across, 0, 3, "bord_geel" if across in range(6, 10) else "metaal_donker")
        model.set(across, length - 1, 3, "bord_geel" if across in range(6, 10) else "metaal_donker")
    for across in (1, 2, 3, width - 4, width - 3, width - 2):
        model.set(across, 0, 6, "lamp_wit")
    # rear: tall tail lights at the corners, the seam between the doors, handles
    for across in (1, 2, width - 3, width - 2):
        for up in (6, 7, 8, 9):
            model.set(across, length - 1, up, "signaal_rood")
    for up in range(4, 16):
        model.set(width // 2 - 1, length - 1, up, sill)
    model.set(width // 2 - 2, length - 1, 8, "rvs")
    model.set(width // 2, length - 1, 8, "rvs")
    wheel_arches(model, VAN_WHEEL_ALONG, SEDAN_WHEEL_UP, 7)
    for across in range(ARCH_DEPTH + 1, width - ARCH_DEPTH - 1):
        for along in range(3, length - 3):
            model.set(across, along, 1, "metaal_donker")
    # big mirrors on arms by the windscreen
    for across in (0, width - 1):
        for up in (10, 11, 12):
            model.set(across, 8, up, "metaal_donker")
    car_details(model, paint=paint, seam=sill, doors=(10, 17), handles=(15,), handle_up=9,
                belt_up=9, glass_along=range(11, 16), glass_up=11, grille=(4, 11, 6), fog_up=2,
                bonnet_along=4, boot_along=None, wiper=(5, 10), fuel_along=33, repeater_along=7,
                rear_badge_up=10, wheel_along=VAN_WHEEL_ALONG)
    # sliding door on the right side: its seams up to the roof, a handle, the rail above it
    for along in (18, 29):
        for up in range(3, 10):
            model.set(0, along, up, sill)
        for up in range(10, 16):
            model.set(1, along, up, sill)
    model.set(0, 20, 8, "rvs")
    for along in range(18, 36):
        model.set(0, along, 9, "metaal_donker")
    # the other cargo side: the dark rail only where the door would slide on a left-hand van
    for along in (29,):
        for up in range(3, 10):
            model.set(width - 1, along, up, sill)
    # a black rubbing strip along the cargo box
    for along in range(10, length - 1):
        for across in (0, width - 1):
            if model.get(across, along, 5):
                model.set(across, along, 5, "metaal_donker")
    return model


# the big wheel (auto_wiel_groot) under a truck and a bus: voxels of the body
BIG_WHEEL_UP = 4.0
BIG_WHEEL_RADIUS = 3.6
TRUCK_WHEEL_ALONG = (9.0, 44.0)


@tile("props/voertuigen/auto_vrachtwagen")
def truck():
    """Small yellow truck with an open cargo bed, of 7 x 2.25 x 3 m, without its wheels
    (auto_wiel_groot, at TRUCK_WHEEL_ALONG; placed and turned by
    scripts/vehicles/truck.gd): x across (18 voxels), y along (56, the front at y=0), z
    up. A boxy cab with a flat front, a tall exhaust stack behind it, a dark chassis with a
    fuel tank, mudguards over the rear wheels, and a cargo bed with steel sides and a
    tailgate, loaded with a heap of sand."""
    width, length, height = 18, 56, 24
    model = V(width, length, height)
    paint, sill, inside = "lak_geel1", "lak_geel2", "auto_interieur"
    cab_end = 13          # last row of the cab
    bed_start = 16        # first row of the cargo bed
    bed_floor = 9         # height of its floor
    side_top = 14         # top of its sides
    # chassis
    for along in range(2, length):
        for across in range(4, width - 4):
            for up in (3, 4, 5, 6, 7, 8):
                model.set(across, along, up, "metaal_donker")
    # cab: flat front y=0, body up to the roof at 19
    for along in range(0, cab_end + 1):
        for across in range(width):
            for up in range(2, 20):
                model.set(across, along, up, sill if up <= 3 else paint)
    for along in range(1, cab_end):
        for across in range(1, width - 1):
            for up in range(11, 19):
                model.set(across, along, up, inside)
    # windscreen, side windows (with the door seams and a handle), roof visor
    for across in range(1, width - 1):
        for up in range(11, 18):
            model.set(across, 0, up, "glas2")
    for across in (3, 4, 5, 6, width - 7, width - 6, width - 5, width - 4):
        model.set(across, 0, 11, "metaal_donker")          # wipers
    for across in range(width):
        model.set(across, 0, 18, "metaal_donker")
    for along in range(2, 11):
        for up in range(11, 17):
            for across in (0, width - 1):
                model.set(across, along, up, "glas2")
    for along in (1, 11):
        for up in range(4, 19):
            for across in (0, width - 1):
                model.set(across, along, up, sill)
    for across in (0, width - 1):
        model.set(across, 10, 10, "rvs")
    # wind deflector and marker lamps on the roof
    for across in range(2, width - 2):
        for along in range(2, 11):
            model.set(across, along, 20, paint)
    for across in range(3, width - 3):
        for along in range(4, 9):
            model.set(across, along, 21, paint)
    for across in (3, 8, 9, width - 4):
        model.set(across, 1, 20, "oranje")
    # front: bumper, grille with a chrome frame and a badge, headlights, plate, step
    for across in range(width):
        for up in (2, 3):
            model.set(across, 0, up, "metaal_donker")
    for across in range(4, width - 4):
        for up in range(5, 10):
            edge = across in (4, width - 5) or up in (5, 9)
            model.set(across, 0, up, "rvs" if edge else "rooster")
    model.set(width // 2, 0, 7, "rvs")
    for across in (1, 2, 3, width - 4, width - 3, width - 2):
        model.set(across, 0, 5, "lamp_wit")
        model.set(across, 0, 4, "metaal3")
    for across in range(6, 12):
        model.set(across, 0, 3, "bord_geel")
    # big mirrors on the corners
    for across in (0, width - 1):
        for up in (13, 14, 15, 16):
            model.set(across, 0, up, "metaal_donker")
    wheel_arches(model, TRUCK_WHEEL_ALONG[:1], BIG_WHEEL_UP, 11, BIG_WHEEL_RADIUS, 4)
    # exhaust stack behind the cab, an air intake on the other side
    for up in range(6, 24):
        model.set(width - 2, 14, up, "rvs" if up < 20 else "metaal_donker")
    for up in range(9, 20):
        model.set(1, 14, up, "metaal_donker")
    # fuel tank and a tool box on the chassis
    for along in range(19, 29):
        for across in (1, 2, 3):
            for up in (4, 5, 6):
                model.set(across, along, up, "metaal3")
        for across in (width - 4, width - 3, width - 2):
            for up in (4, 5, 6):
                model.set(across, along, up, "metaal_donker")
    # cargo bed: floor, steel sides with ribs and a top rail, tailgate
    for along in range(bed_start, length):
        for across in range(width):
            model.set(across, along, bed_floor, "metaal_donker")
            if across in (0, width - 1) or along in (bed_start, length - 1):
                for up in range(bed_floor + 1, side_top):
                    rib = along % 6 == 0 or (along in (bed_start, length - 1) and across % 4 == 0)
                    model.set(across, along, up, "metaal1" if rib else "metaal2")
                model.set(across, along, side_top, "rvs")
    # the headboard is taller: it guards the cab
    for across in range(width):
        for up in range(side_top, 18):
            model.set(across, bed_start, up, "metaal2")
    # the load: a heap of sand, highest in the middle
    for along in range(bed_start + 1, length - 1):
        for across in range(1, width - 1):
            from_side = min(across - 1, width - 2 - across)
            from_end = min(along - bed_start - 1, length - 2 - along)
            heap = min(5, 1 + min(from_side // 2 + 1, from_end // 2 + 1))
            for up in range(bed_floor + 1, bed_floor + 1 + heap):
                model.set(across, along, up, "zand2" if int(h(across, along, up, 271) * 4) == 0 else "zand1")
    # mudguards over the rear wheels
    rear_wheel = int(TRUCK_WHEEL_ALONG[1])
    for along in range(rear_wheel - 5, rear_wheel + 6):
        for across in (0, 1, 2, 3, width - 4, width - 3, width - 2, width - 1):
            model.set(across, along, 8, "metaal_donker")
    for across in (0, 1, 2, 3, width - 4, width - 3, width - 2, width - 1):
        for up in (5, 6, 7):
            model.set(across, rear_wheel + 5, up, "rubber")
    # rear: bar with the tail lights and the plate, striped against running into it
    for across in range(width):
        for up in (5, 6, 7, 8):
            model.set(across, length - 1, up, "metaal_donker")
        model.set(across, length - 1, 4, "oranje" if across % 4 < 2 else "bord_wit")
        model.set(across, length - 1, 3, "metaal_donker")
    for across in (1, 2, 3, width - 4, width - 3, width - 2):
        for up in (6, 7):
            model.set(across, length - 1, up, "signaal_rood")
    for across in range(6, 12):
        model.set(across, length - 1, 6, "bord_geel")
    # orange side markers along the bed
    for along in (bed_start + 8, bed_start + 22, length - 3):
        for across in (0, width - 1):
            model.set(across, along, bed_floor, "oranje")
    return model


BUS_WHEEL_ALONG = (15.0, 62.0)


@tile("props/voertuigen/auto_stadsbus")
def city_bus():
    """White city bus with a red band, of 10.5 x 2.5 x 3 m, without its wheels
    (auto_wiel_groot, at BUS_WHEEL_ALONG; placed and turned by
    scripts/vehicles/city_bus.gd): x across (20 voxels), y along (84, the front at y=0), z
    up. A big windscreen with a lit line number over it, a band of windows down each side,
    two double doors on the right (the pavement side), a ventilation grille at the back,
    air-conditioning boxes on the roof."""
    width, length, height = 20, 84, 25
    model = V(width, length, height)
    paint, sill, inside = "lak_wit1", "lak_wit2", "auto_interieur"
    band = "lak_rood1"
    for along in range(length):
        for across in range(width):
            if along in (0, length - 1) and across in (0, width - 1):
                continue
            for up in range(2, 22):
                side = across in (0, width - 1)
                if not side and along not in (0, length - 1) and up > 3:
                    colour = inside
                elif up <= 3:
                    colour = sill
                elif up in (7, 8):
                    colour = band
                elif 10 <= up <= 18 and side:
                    colour = "metaal_donker" if along % 10 == 0 else "glas2"
                else:
                    colour = paint
                model.set(across, along, up, colour)
    # roof, its edge a step in, with two air-conditioning boxes and hatches
    for along in range(1, length - 1):
        for across in range(1, width - 1):
            model.set(across, along, 22, paint)
    for first, last in ((18, 32), (48, 62)):
        for along in range(first, last):
            for across in range(5, width - 5):
                edge = along in (first, last - 1) or across in (5, width - 6)
                model.set(across, along, 23, "metaal3" if edge else "rooster")
    for along in (38, 39, 40, 41):
        for across in range(7, width - 7):
            model.set(across, along, 23, "metaal1")
    # front: bumper, headlights, big windscreen with wipers, sign with the line number
    for across in range(width):
        for up in (2, 3):
            model.set(across, 0, up, "metaal_donker")
            model.set(across, length - 1, up, "metaal_donker")
    for across in range(1, width - 1):
        for up in range(9, 18):
            model.set(across, 0, up, "glas2")
        for up in range(18, 23):
            model.set(across, 0, up, "bord_zwart")
    pixels, (text_width, _) = text_pixels("22")
    for column, row in pixels:
        model.set((width - text_width) // 2 + column, 0, 22 - row, "lamp_warm")
    for across in (5, 6, 7, 8, width - 9, width - 8, width - 7, width - 6):
        model.set(across, 0, 9, "metaal_donker")
    for across in (1, 2, 3, 4, width - 5, width - 4, width - 3, width - 2):
        model.set(across, 0, 5, "lamp_wit")
    for across in range(7, 13):
        model.set(across, 0, 3, "bord_geel")
    model.set(width // 2, 0, 6, "rvs")
    # mirrors hanging on arms by the windscreen
    for across in (0, width - 1):
        for up in (13, 14, 15, 16):
            model.set(across, 1, up, "metaal_donker")
    # rear: window, ventilation grille, tall tail lights, plate
    for across in range(3, width - 3):
        for up in range(12, 19):
            model.set(across, length - 1, up, "glas2")
        for up in range(4, 9):
            model.set(across, length - 1, up, "rooster" if up % 2 == 0 else "metaal_donker")
    for across in (1, 2, width - 3, width - 2):
        for up in (5, 6, 7, 8):
            model.set(across, length - 1, up, "signaal_rood")
    for across in range(7, 13):
        model.set(across, length - 1, 3, "bord_geel")
    wheel_arches(model, BUS_WHEEL_ALONG, BIG_WHEEL_UP, 11, BIG_WHEEL_RADIUS, 4)
    # double doors on the right: glass from low to the top, dark frame, a seam in the middle,
    # one ahead of the front wheels and one in the middle
    for first, last in ((3, 10), (36, 44)):
        for along in range(first, last + 1):
            for up in range(3, 19):
                edge = along in (first, last, (first + last) // 2) or up == 18
                model.set(0, along, up, "metaal_donker" if edge else "glas2")
    # lit line number on the side, above the first windows of the left side too
    for across in (0, width - 1):
        for along in (21, 22, 23):
            model.set(across, along, 19, "lamp_warm")
        # orange side markers along the skirt
        for along in (26, 50, 72):
            model.set(across, along, 4, "oranje")
    # a seam round the engine hatch, a fuel flap on the left
    for along in range(69, 80):
        model.set(0, along, 6, "metaal_donker")
    model.set(width - 1, 30, 5, "metaal_donker")
    model.set(width - 1, 31, 5, "metaal_donker")
    return model


@tile("props/voertuigen/auto_aanhanger")
def trailer():
    """Trailer of 3.25 x 1.75 x 1.13 m with an open bed, without its wheels (auto_wiel,
    placed by scripts/vehicles/vehicle.gd): x across (14 voxels), y along (26), z up. The
    coupling is at the very front (y=0), the point it pivots about on the tow ball; an
    A-frame runs back to the bed, whose axle is at y=18. A wooden floor, galvanised sides
    with a chrome rail, mudguards over the wheels, tail lights and a plate at the back, and
    two crates and a few planks for a load."""
    width, length, height = 14, 26, 11
    model = V(width, length, height)
    frame, side, wood = "gegalvaniseerd", "gegalvaniseerd", "hout1"
    bed_start = 10
    axle = 18
    middle = width // 2
    # coupling (a dark cup over the ball) and the A-frame behind it
    for across in (middle - 1, middle):
        for along in (0, 1):
            for up in (3, 4):
                model.set(across, along, up, "metaal_donker")
    for along in range(2, bed_start):
        spread = (along - 1) * 3 // 4
        for across in (middle - 1 - spread, middle + spread):
            model.set(across, along, 3, frame)
    for across in range(middle - 3, middle + 3):
        model.set(across, 7, 3, frame)
    # the jockey wheel's post, folded up
    for up in (4, 5):
        model.set(middle, 5, up, "metaal_donker")
    # bed: frame, wooden floor, sides with a top rail, tailgate
    for along in range(bed_start, length):
        for across in range(2, width - 2):
            model.set(across, along, 3, frame)
            model.set(across, along, 4, "hout2" if across % 3 == 0 else wood)
            border = across in (2, width - 3) or along in (bed_start, length - 1)
            if border:
                for up in (5, 6, 7):
                    model.set(across, along, up, side)
                model.set(across, along, 8, "rvs")
    # mudguards over the wheels (outside the bed, wheels 0.75 m from the middle)
    for along in range(axle - 4, axle + 4):
        rise = 6 if abs(along + 0.5 - axle) < 3 else 5
        for across in (0, 1, width - 2, width - 1):
            model.set(across, along, rise, "metaal_donker")
    # rear: tail lights, indicators' places, plate, a reflector strip
    for across in (3, 4, width - 5, width - 4):
        model.set(across, length - 1, 4, "signaal_rood")
    for across in (6, 7):
        model.set(across, length - 1, 4, "bord_geel")
    for across in range(3, width - 3):
        model.set(across, length - 1, 3, "metaal_donker")
    # the load: two crates and planks lying alongside them
    for first, last, across_first, across_last, top in ((12, 17, 4, 8, 8), (18, 22, 5, 9, 7)):
        for along in range(first, last):
            for across in range(across_first, across_last):
                for up in range(5, top + 1):
                    edge = along in (first, last - 1) or across in (across_first, across_last - 1)
                    model.set(across, along, up, "hout3" if edge else "hout_donker1")
    for along in range(12, 24):
        for up in (5, 6):
            model.set(10, along, up, "hout2")
    return model


@tile("props/voertuigen/auto_trekhaak")
def tow_bar():
    """Tow bar for under the back of a car (scripts/vehicles/vehicle.gd, hitch_model): a
    dark bar, y along (0 under the bumper, 4 at the back), with the chrome ball the coupling
    of a trailer pivots on at the back end, 2 voxels up."""
    model = V(2, 5, 3)
    for along in range(5):
        for across in range(2):
            model.set(across, along, 0, "metaal_donker")
    for across in range(2):
        model.set(across, 4, 1, "metaal_donker")
        model.set(across, 4, 2, "rvs")
    return model


@tile("props/voertuigen/auto_wiel")
def car_wheel():
    """Car wheel of 0.75 m across, 0.25 m wide: a disc in the y-z plane (2 x 6 x 6
    voxels, the axle along x through the middle), a rubber tyre round a steel rim with
    four dark spokes so it shows when it turns. Turned and steered by
    scripts/vehicles/vehicle.gd."""
    model = V(2, 6, 6)
    for along in range(6):
        for up in range(6):
            distance = ((along + 0.5 - 3.0) ** 2 + (up + 0.5 - 3.0) ** 2) ** 0.5
            if distance > SEDAN_WHEEL_RADIUS + 0.4:
                continue
            if distance > 1.9:
                colour = "rubber"
            elif along in (2, 3) or up in (2, 3):
                colour = "metaal_donker"          # spokes and hub
            else:
                colour = "rvs"
            for across in range(2):
                model.set(across, along, up, colour)
    return model


@tile("props/voertuigen/auto_wiel_groot")
def big_wheel():
    """Wheel of a truck or a bus, 1 m across, 0.38 m wide: the car wheel made bigger
    (3 x 8 x 8 voxels, the axle along x)."""
    model = V(3, 8, 8)
    for along in range(8):
        for up in range(8):
            distance = ((along + 0.5 - 4.0) ** 2 + (up + 0.5 - 4.0) ** 2) ** 0.5
            if distance > 4.0:
                continue
            if distance > 2.6:
                colour = "rubber"
            elif along in (3, 4) or up in (3, 4):
                colour = "metaal_donker"
            else:
                colour = "rvs"
            for across in range(3):
                model.set(across, along, up, colour)
    return model


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
