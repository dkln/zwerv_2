"""Street sellers' carts and market stalls (props/markt/...), all without anyone at them:
a chip van (frietkar), a Dutch street organ (draaiorgel), a Vietnamese spring-roll cart
(loempiakar), an ice-cream tricycle (ijscokar) and market stalls of several kinds (groente,
fruit, bloemen, kaas, vis, stoffen).

Conventions as props.py: 1 voxel = 12.5 cm, x = left->right, y = front->back (front = y=0: the
side a buyer stands at), z = up, the pivot the bottom centre.
"""
from math import atan2

from common import register, tile, text_pixels
from vox import V


def _wheel(m, cx, cz, r, y0, y1, tyre="rubber", hub="metaal2", spokes=None):
    """A wheel standing along x (its axle along y) with its centre at (cx, cz), from y0 to y1."""
    for x in range(int(cx - r - 1), int(cx + r + 2)):
        for z in range(max(0, int(cz - r - 1)), int(cz + r + 2)):
            d = ((x + 0.5 - cx) ** 2 + (z + 0.5 - cz) ** 2) ** 0.5
            if d > r:
                continue
            if d > r - 1.0:
                c = tyre
            elif spokes and (abs(x + 0.5 - cx) < 0.6 or abs(z + 0.5 - cz) < 0.6):
                c = spokes
            elif d < 1.0:
                c = hub
            elif spokes:
                continue
            else:
                c = hub
            for y in range(y0, y1):
                m.set(x, y, z, c)


def _letters(m, text, cx, y, ztop, c, spacing=1):
    """Text centred on x = cx at depth y, its top row at z = ztop."""
    pixels, (width, _) = text_pixels(text, spacing)
    for (column, row) in pixels:
        m.set(cx - width // 2 + column, y, ztop - row, c)


# ------------------------------------------------------------------ carts

@tile("props/markt/frietkar")
def chip_van():
    """A chip van (patatkraam) on one axle: white with a red skirt and a yellow band, the
    serving hatch open at the front under its propped-up flap, a yellow FRIET sign on the roof
    and the drawbar on its jockey wheel. Hollow: walls of one voxel round a room with a tiled
    floor at 0.625 m (z 5) and a ceiling at 2.625 m, room for the seller (1.75 m) between the
    counter and the fryer and the warmer against the back wall (street_vendors.gd puts them
    there: seen through the hatch from the waist up)."""
    m = V(32, 18, 30)
    # the body on its chassis
    m.box(3, 3, 4, 27, 16, 22, "lak_wit1")
    m.box(3, 3, 4, 27, 16, 7, "lak_rood1")
    m.box(3, 3, 19, 27, 16, 21, "lak_geel1")
    m.box(3, 3, 22, 27, 16, 23, "lak_wit2")
    m.box(2, 2, 22, 28, 17, 23, "lak_zilver1")                 # the roof's rim
    # the room inside: floor (the body's bottom, tiled), the walls one voxel thick
    m.clear(4, 4, 5, 26, 15, 21)
    m.box(4, 4, 4, 26, 15, 5, "tegel_wit")                     # the floor
    m.box(4, 14, 5, 26, 15, 21, "tegel_wit")                   # the back wall inside
    # the hatch: open from the counter up to 2.5 m, the counter under it
    m.clear(6, 3, 11, 24, 4, 20)
    m.box(5, 2, 10, 25, 4, 11, "rvs")                          # counter
    # the fryer and the warmer against the back wall
    m.box(6, 11, 5, 13, 14, 10, "rvs")                         # the fryer
    m.box(7, 12, 10, 12, 13, 11, "goud")                       # chips in the basket
    m.box(16, 11, 5, 24, 14, 11, "metaal1")                    # the warmer with chips
    m.box(17, 12, 10, 23, 13, 11, "bord_geel")
    m.box(16, 11, 11, 24, 14, 12, "glas_helder")
    # the flap propped up over the hatch, red and white
    for x in range(5, 25):
        for y in range(0, 3):
            m.set(x, y, 20 + (2 - y) // 2, "luifel_rood" if (x // 2) % 2 else "luifel_wit")
    m.box(5, 0, 16, 6, 1, 21, "metaal2")
    m.box(24, 0, 16, 25, 1, 21, "metaal2")
    # the sign on the roof
    m.box(8, 8, 23, 22, 10, 29, "bord_geel")
    _letters(m, "FRIET", 15, 7, 27, "bord_rood")
    # wheel and mudguard on each side, the chassis, the drawbar to its jockey wheel
    _wheel(m, 15, 4, 3.5, 1, 3)
    _wheel(m, 15, 4, 3.5, 16, 18)
    m.box(11, 1, 7, 20, 3, 8, "antraciet1")
    m.box(11, 16, 7, 20, 18, 8, "antraciet1")
    m.box(27, 8, 4, 31, 11, 5, "antraciet1")
    m.box(30, 9, 0, 31, 10, 4, "metaal2")
    m.box(29, 8, 0, 31, 11, 1, "rubber")
    # the gas bottle on the drawbar
    m.cyl(28.5, 13.5, 1.2, 5, 9, "lak_rood2")
    return m


@tile("props/markt/draaiorgel")
def street_organ():
    """A Dutch street organ on its four big wooden wheels: the ornate front (gold scrollwork
    round red panels) with the brass pipes in the middle and a painted crest on top, the big
    crank wheel on its side, the red body behind under a little roof; no figures on it."""
    m = V(30, 18, 32)
    # the wagon and its wheels
    m.box(2, 3, 5, 28, 15, 7, "hout_donker1")
    for cx in (7, 23):
        _wheel(m, cx, 4.5, 4.5, 1, 3, tyre="hout_donker2", hub="hout_donker1", spokes="hout_donker1")
        _wheel(m, cx, 4.5, 4.5, 15, 17, tyre="hout_donker2", hub="hout_donker1", spokes="hout_donker1")
    # the body behind the front
    m.box(3, 5, 7, 27, 15, 23, "lak_rood1")
    m.box(3, 5, 7, 27, 15, 8, "goud")
    m.box(2, 4, 23, 28, 16, 24, "hout_donker1")                # the roof
    # the front: red side panels with gold borders and dots, the pipes in the middle
    m.box(3, 3, 7, 27, 5, 26, "goud")
    m.box(4, 3, 8, 9, 4, 24, "lak_rood1")
    m.box(21, 3, 8, 26, 4, 24, "lak_rood1")
    for z in range(10, 23, 3):
        m.set(6, 2, z, "goud")
        m.set(23, 2, z, "goud")
    m.box(10, 3, 8, 20, 4, 24, "lak_blauw2")
    heights = [9, 11, 13, 14, 15, 14, 13, 11, 9]
    for index, height in enumerate(heights):
        x = 11 + index
        m.box(x, 2, 10, x + 1, 3, 10 + height, "messing" if index % 2 else "koper")
        m.set(x, 2, 9, "antraciet1")                           # the mouth of the pipe
    # the crest on top: an arch of gold round a painted panel
    for x in range(5, 25):
        rise = int(6 - abs(x - 14.5) * 0.45)
        m.box(x, 3, 26, x + 1, 5, 26 + max(rise, 1), "goud")
        if 8 <= x <= 21:
            m.box(x, 2, 27, x + 1, 3, 26 + max(rise - 1, 1), "lak_wit1" if x % 3 else "bloem_roze")
    m.box(13, 2, 32 - 1, 17, 4, 32, "goud")
    # the crank wheel on the right side
    _wheel(m, 26, 14, 3.5, 15, 16, tyre="metaal_donker", hub="messing", spokes="metaal_donker")
    m.box(25, 16, 13, 27, 17, 15, "hout_donker2")              # the handle
    return m


@tile("props/markt/loempiakar")
def spring_roll_cart():
    """A Vietnamese spring-roll cart: a red cart with a yellow trim on two wheels, a glass
    case with golden spring rolls on top, a little yellow roof with LOEMPIA on its front, the
    push handle at the back."""
    m = V(26, 16, 24)
    m.box(2, 3, 5, 24, 13, 13, "lak_rood1")
    m.box(2, 3, 12, 24, 13, 13, "lak_geel1")
    m.box(2, 3, 5, 24, 13, 6, "lak_geel1")
    m.box(4, 2, 7, 22, 3, 11, "lak_geel2")                     # the front panel
    m.box(6, 2, 8, 20, 2, 10, "lak_rood2")
    # the glass case and the rolls in it, the woks beside it
    m.box(4, 4, 13, 22, 12, 17, "glas_helder")
    m.box(5, 5, 13, 21, 11, 14, "rvs")
    for x in range(6, 20, 3):
        m.box(x, 6, 14, x + 2, 10, 15, "goud")
    m.cyl(23.0, 8.0, 1.5, 13, 14, "metaal_donker")
    # the roof on four thin posts, its front with the name
    for x in (2, 23):
        for y in (3, 12):
            m.box(x, y, 13, x + 1, y + 1, 20, "metaal2")
    m.box(0, 1, 20, 26, 14, 21, "luifel_geel")
    m.box(0, 0, 18, 26, 1, 21, "luifel_rood")
    _letters(m, "LOEMPIA", 13, 0, 20, "lak_wit1", spacing=0)
    # the wheels and the handle
    _wheel(m, 13, 3.5, 3.0, 1, 3)
    _wheel(m, 13, 3.5, 3.0, 13, 15)
    m.box(24, 6, 11, 26, 7, 12, "metaal2")
    m.box(24, 9, 11, 26, 10, 12, "metaal2")
    m.box(25, 6, 11, 26, 10, 12, "rubber")
    m.box(1, 7, 0, 2, 9, 5, "metaal2")                         # the stand at the front
    return m


@tile("props/markt/ijscokar")
def ice_cream_trike():
    """An ice-cream tricycle: the white cool box with a blue band in front on two wheels, IJS
    on it and a big cone painted beside it, the saddle and the handlebar behind over the
    rear wheel, a red and white parasol over it all."""
    m = V(24, 24, 30)
    # the cool box
    m.box(5, 2, 5, 19, 12, 14, "lak_wit1")
    m.box(5, 2, 8, 19, 12, 10, "lak_blauw1")
    m.box(5, 2, 14, 19, 12, 15, "lak_zilver1")                 # the lid
    _letters(m, "IJS", 9, 1, 13, "lak_blauw1")
    # a cone on the front: the wafer and a pink scoop
    for z in range(5, 9):
        half = (z - 5) // 2
        m.box(15 - half, 1, z, 16 + half, 2, z + 1, "goud")
    m.box(13, 1, 9, 18, 2, 12, "bloem_roze")
    # the front wheels under the box, the frame to the rear wheel
    _wheel(m, 8, 3, 2.5, 3, 4)
    _wheel(m, 16, 3, 2.5, 3, 4)
    _wheel(m, 8, 3, 2.5, 10, 11)
    _wheel(m, 16, 3, 2.5, 10, 11)
    m.box(11, 12, 5, 13, 19, 6, "lak_blauw2")
    _wheel(m, 12, 3, 2.5, 18, 19, spokes="metaal2")
    m.box(11, 15, 6, 13, 16, 11, "lak_blauw2")                 # the seat post
    m.box(10, 15, 11, 14, 18, 12, "fiets_zadel")
    m.box(9, 13, 13, 15, 14, 14, "metaal2")                    # the handlebar
    m.box(9, 13, 13, 10, 14, 14, "rubber")
    m.box(14, 13, 13, 15, 14, 14, "rubber")
    # the parasol
    m.box(6, 7, 15, 7, 8, 26, "metaal2")
    for x in range(24):
        for y in range(24):
            dx, dy = x + 0.5 - 6.5, y + 0.5 - 7.5
            distance = (dx * dx + dy * dy) ** 0.5
            if distance <= 10.5:
                segment = int((atan2(dy, dx) + 3.2) / 6.4 * 8) % 2
                m.set(x, y, 26 - int(distance / 4.0), "luifel_rood" if segment else "luifel_wit")
    return m


# ------------------------------------------------------------------ market stalls

STALL_ROOFS = {
    "groente": ("luifel_groen", "luifel_wit"),
    "fruit": ("luifel_oranje", "luifel_wit"),
    "bloemen": ("luifel_rood", "luifel_wit"),
    "kaas": ("luifel_geel", "luifel_wit"),
    "vis": ("luifel_blauw", "luifel_wit"),
    "stoffen": ("luifel_rood", "luifel_geel"),
}


def _stall(kind):
    """A market stall: a galvanised frame, a table with a cloth to the ground in front, a
    striped canvas roof sloping down to the front, and the wares of its kind on the table."""
    m = V(24, 16, 24)
    stripe, white = STALL_ROOFS[kind]
    for x in (0, 23):
        for y in (1, 14):
            m.box(x, y, 0, x + 1, y + 1, 20 if y == 1 else 22, "gegalvaniseerd")
    m.box(0, 1, 7, 24, 10, 8, "hout1")                          # the table
    m.box(0, 1, 1, 24, 2, 7, "tafelkleed")                      # the cloth in front
    m.box(0, 13, 0, 24, 15, 10, "hout2")                        # crates at the back
    for x in range(24):
        for y in range(16):
            z = 20 + (y * 3) // 16
            m.set(x, y, z, stripe if (x // 3) % 2 else white)
    for x in range(24):
        m.set(x, 0, 19, stripe if (x // 3) % 2 else white)      # the flap along the front
    _WARES[kind](m)
    return m


def _crates(m, colours, seed=0):
    """Low wooden crates along the table, each heaped with one colour."""
    for index, x in enumerate(range(1, 23, 4)):
        m.box(x, 2, 8, x + 4, 9, 9, "hout2")
        colour = colours[(index + seed) % len(colours)]
        m.box(x + 1, 3, 9, x + 3, 8, 10, colour)
        m.box(x + 1, 4, 10, x + 3, 7, 11, colour)


def _greens(m):
    _crates(m, ["blad1", "oranje", "bloem_rood", "aarde2", "blad3", "bloem_paars"])


def _fruit(m):
    _crates(m, ["bloem_geel", "bloem_rood", "oranje", "blad_licht", "bloem_paars", "lak_rood1"], 1)


def _flowers(m):
    for index, x in enumerate(range(1, 23, 3)):
        m.box(x, 3, 8, x + 2, 7, 11, "metaal1")                 # a bucket
        colour = ["bloem_rood", "bloem_geel", "bloem_roze", "bloem_wit", "bloem_paars", "bloem_oranje", "bloem_rood", "bloem_geel"][index]
        m.box(x, 3, 11, x + 2, 7, 13, "blad2")
        m.box(x, 3, 13, x + 2, 7, 15, colour)


def _cheese(m):
    for index, x in enumerate((3, 9, 15, 21)):
        for level in range(2 if index % 2 else 3):
            m.cyl(x, 5.5, 2.6, 8 + level * 2, 10 + level * 2, "bord_geel" if level % 2 else "goud")
    m.box(1, 8, 8, 4, 9, 9, "lak_wit1")                         # the cutting board


def _fish(m):
    m.box(0, 2, 8, 24, 9, 9, "tegel_wit")                       # the ice
    for x in range(1, 23, 2):
        for y in (3, 5, 7):
            m.set(x, y, 9, "lak_zilver1" if (x + y) % 4 else "lak_zilver2")
            m.set(x + 1, y, 9, "lak_zilver2" if (x + y) % 4 else "bord_oranje")
    m.box(9, 13, 10, 15, 14, 14, "bord_blauw")
    _letters(m, "VIS", 12, 12, 13, "bord_wit")


def _cloth(m):
    for index, x in enumerate(range(1, 23, 3)):
        colour = ["stof1", "vlag_rood", "stof2", "vlag_blauw", "stof3", "vlag_geel", "vlag_paars", "vlag_groen"][index]
        m.box(x, 2, 8, x + 3, 9, 10, colour)                    # a roll lying on the table
    for x in range(2, 22, 4):
        colour = ["vlag_roze", "vlag_lichtblauw", "vlag_oranje", "vlag_groen", "stof2"][(x // 4) % 5]
        m.box(x, 1, 12, x + 3, 2, 19, colour)                   # hanging from the front bar
    m.box(0, 1, 19, 24, 2, 20, "gegalvaniseerd")


_WARES = {"groente": _greens, "fruit": _fruit, "bloemen": _flowers, "kaas": _cheese, "vis": _fish, "stoffen": _cloth}

for _kind in STALL_ROOFS:
    register("props/markt/kraam_" + _kind, lambda kind=_kind: _stall(kind))
