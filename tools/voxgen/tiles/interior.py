"""Interiors (category binnen): the tiles of the rooms you can walk into, built in their own
scenes (scenes/binnen/, editable in Godot, a GridMap with the library binnen). First the snack
bar (binnen/snackbar/): tiled floors, tiled walls (high at the back and sides, low at the
front, so the iso view looks in over them), a counter with its glass display of snacks, the
fryer, the menu board, a drinks fridge, formica tables and chairs, and a doormat at the way
out. Floors and walls come in a few colour variants (VARIANTS), so no two snack bars look
quite alike: scripts/world/interiors/interior.gd swaps them per snack bar.

Voxels of 0.125 m (the ordinary size); the pivot is the middle of the bottom of the frame,
the front the side with the lowest y. A floor tile and a wall are a 4 m cell wide.
"""
from common import tile, register, text_pixels
from vox import V

CELL = 32          # voxels in a 4 m cell
WALL_HIGH = 24     # 3 m
WALL_LOW = 8       # 1 m: the front wall, to look in over
WALL_DEPTH = 2

# the colour variants: name -> (floor tile A, floor tile B, wall tiles, wall band, front of the counter)
VARIANTS = {
    "zwartwit": ("tegel_wit", "bord_zwart", "tegel_wit", "bord_rood", "lak_rood1"),
    "roodwit": ("tegel_wit", "bord_rood", "tegel_wit", "bord_zwart", "bord_zwart"),
    "geel": ("tegel_wit", "lak_geel1", "lak_geel1", "lak_blauw1", "lak_blauw1"),
    "blauw": ("tegel_wit", "lak_blauw1", "tegel_wit", "lak_blauw1", "lak_geel1"),
}


def _floor(colour_a, colour_b):
    """A 4 x 4 m floor of square tiles (0.5 m), checkered, one voxel thick, with grout lines."""
    model = V(CELL, CELL, 1)
    for x in range(CELL):
        for y in range(CELL):
            grout = x % 4 == 0 or y % 4 == 0
            checker = (x // 4 + y // 4) % 2 == 0
            model.set(x, y, 0, "tegel_voeg" if grout else (colour_a if checker else colour_b))
    return model


def _wall(height, tiles, band, width=CELL):
    """A wall of `width` voxels and `height` high, two deep: tiles up to 1.5 m (grout every
    0.25 m), a coloured band, painted plaster above; the front (y = 0) faces the room."""
    model = V(width, WALL_DEPTH, height)
    for x in range(width):
        for z in range(height):
            if z < 12:
                colour = "tegel_voeg" if x % 2 == 0 and z % 2 == 0 else tiles
            elif z < 14:
                colour = band
            else:
                colour = "beton1"
            for y in range(WALL_DEPTH):
                model.set(x, y, z, colour)
    return model


def counter(front):
    """The counter, 4 m long, 1 m deep: a painted front, a steel top, a glass display on it
    with kroketten, frikandellen and cheese souffles lying in rows."""
    model = V(CELL, 8, 11)
    model.box(0, 0, 0, CELL, 8, 7, front)
    model.box(0, 0, 0, CELL, 8, 1, "metaal_donker")          # the plinth
    model.box(0, 0, 7, CELL, 8, 8, "rvs")                    # the top
    # the display: glass front and top, steel back
    model.box(1, 1, 8, CELL - 1, 2, 11, "glas_helder")
    model.box(1, 1, 10, CELL - 1, 7, 11, "glas_helder")
    model.box(1, 6, 8, CELL - 1, 7, 10, "rvs")
    snacks = ["hout3", "hout_donker1", "lak_geel2"]
    for row in range(3):
        for x in range(2, CELL - 2, 3):
            model.box(x, 2 + row * 1, 8, x + 2, 3 + row * 1, 9, snacks[(x // 3 + row) % len(snacks)])
    return model


@tile("binnen/snackbar/frituur")
def fryer():
    """The fryer on the back wall: a steel unit with two baskets in the golden oil."""
    model = V(24, 6, 9)
    model.box(0, 0, 0, 24, 6, 7, "rvs")
    model.box(0, 0, 0, 24, 6, 1, "metaal_donker")
    for left in (3, 13):
        model.box(left, 1, 6, left + 8, 5, 7, "lak_geel2")   # the oil
        model.box(left + 1, 2, 7, left + 7, 4, 9, "metaal_donker")   # a basket
        model.box(left + 3, 0, 8, left + 5, 2, 9, "metaal3")          # its handle
    return model


@tile("binnen/snackbar/menubord")
def menu_board():
    """The menu board high on the back wall: black, lit letters, a price after each."""
    lines = [("KROKET", "2,-"), ("PATAT", "3,-"), ("FRIKANDEL", "2,-")]
    model = V(48, 1, 22)
    model.box(0, 0, 0, 48, 1, 22, "bord_zwart")
    for index, (name, price) in enumerate(lines):
        top = 22 - 3 - index * 7
        for text, left, colour in ((name, 2, "bord_wit_licht"), (price, 48 - 2 - text_pixels(price)[1][0], "bord_geel_licht")):
            pixels, _ = text_pixels(text)
            for column, row in pixels:
                model.set(left + column, 0, top - row, colour)
    return model


@tile("binnen/snackbar/koelkast")
def fridge():
    """The drinks fridge: a glass door with rows of bottles and cans behind it."""
    model = V(8, 6, 16)
    model.box(0, 0, 0, 8, 6, 16, "metaal3")
    model.box(1, 0, 1, 7, 1, 15, "glas_helder")
    drinks = ["bord_rood", "bord_groen", "lak_geel1", "bord_blauw"]
    for shelf in range(4):
        for x in range(1, 7):
            model.set(x, 2, 2 + shelf * 3, drinks[(x + shelf) % len(drinks)])
            model.set(x, 2, 3 + shelf * 3, drinks[(x + shelf) % len(drinks)])
    return model


@tile("binnen/snackbar/tafel")
def table():
    """A formica table on one steel leg (0.75 m high), for two."""
    model = V(8, 8, 6)
    model.box(3, 3, 0, 5, 5, 5, "metaal3")
    model.box(2, 2, 0, 6, 6, 1, "metaal_donker")
    model.box(0, 0, 5, 8, 8, 6, "lak_wit1")
    return model


@tile("binnen/snackbar/stoel")
def chair():
    """A red snack bar chair: a seat at 0.5 m, a low back (at the back, high y)."""
    model = V(4, 4, 7)
    for x, y in ((0, 0), (3, 0), (0, 3), (3, 3)):
        model.box(x, y, 0, x + 1, y + 1, 4, "metaal3")
    model.box(0, 0, 4, 4, 4, 5, "lak_rood1")
    model.box(0, 3, 5, 4, 4, 7, "lak_rood1")
    return model


@tile("binnen/snackbar/deurmat")
def doormat():
    """The doormat at the way out (1.5 x 1 m), so you see where the door is."""
    model = V(12, 8, 1)
    for x in range(12):
        for y in range(8):
            rim = x in (0, 11) or y in (0, 7)
            model.set(x, y, 0, "bord_zwart" if rim else ("hout_donker1" if (x + y) % 2 else "hout_donker2"))
    return model


for _variant, (_floor_a, _floor_b, _tiles, _band, _front) in VARIANTS.items():
    register(f"binnen/snackbar/vloer_{_variant}", lambda a=_floor_a, b=_floor_b: _floor(a, b))
    register(f"binnen/snackbar/muur_{_variant}", lambda t=_tiles, b=_band: _wall(WALL_HIGH, t, b))
    register(f"binnen/snackbar/muur_laag_{_variant}", lambda t=_tiles, b=_band: _wall(WALL_LOW, t, b))
    # beside the door: a low wall of 1.25 m wide (the door 1.5 m)
    register(f"binnen/snackbar/muur_laag_half_{_variant}", lambda t=_tiles, b=_band: _wall(WALL_LOW, t, b, width=10))
    register(f"binnen/snackbar/toonbank_{_variant}", lambda front=_front: counter(front))


# ---------------------------------------------------------------------------------------------
# Den Haag Centraal (binnen/station/): the inside of the station, a head station of twelve
# tracks under one roof (scenes/binnen/centraal.tscn, tools/build/build_interiors.gd). The
# platforms and the tracks are the tiles of the town (grond/spoor/perron, trein_recht,
# trein_stootblok); these are the rest: the stone floor of the hall, its walls, the OV gates
# (a cabinet per tile, the glass paddles a tile of their own that scripts/world/station/station.gd
# slides open and shut), glass fences, the departure boards and platform displays (their text
# is drawn by the game), the track signs, the clock, ticket machines, columns and the shops.

STATION_WALL_HIGH = 64   # 8 m
STATION_WALL_LOW = 8     # 1 m: the front, the iso view looks in over it
TRACK_OPENING = 44       # 5.5 m: the openings in the back wall the trains come in through


@tile("binnen/station/vloer")
def station_floor():
    """The floor of the hall: slabs of light natural stone of 1 m, a fine joint between them."""
    model = V(CELL, CELL, 1)
    for x in range(CELL):
        for y in range(CELL):
            joint = x % 8 == 0 or y % 8 == 0
            slab = ("natuursteen1", "natuursteen2", "natuursteen1", "natuursteen3")[(x // 8 + 3 * (y // 8)) % 4]
            model.set(x, y, 0, "voeg" if joint else slab)
    return model


def _station_wall(height, opening=0):
    """A wall of the hall, 4 m wide, two deep: a dark plinth, white panels, above 5 m steel and
    glass. `opening`: an opening for a track that high in the middle (24 of the 32 wide)."""
    model = V(CELL, WALL_DEPTH, height)
    for x in range(CELL):
        for z in range(height):
            if z < 4:
                colour = "beton_donker"
            elif z < 40:
                colour = "metaal_donker" if x % 16 == 0 else ("paneel1" if (z // 6) % 2 else "paneel2")
            else:
                mullion = x % 8 == 0 or (z - 40) % 12 == 0
                colour = "metaal_donker" if mullion else "glas_kantoor"
            for y in range(WALL_DEPTH):
                model.set(x, y, z, colour)
    if opening:
        model.clear(4, 0, 0, CELL - 4, WALL_DEPTH, opening)
        model.box(4, 0, opening, CELL - 4, WALL_DEPTH, opening + 2, "beton_donker")   # the lintel
    return model


register("binnen/station/wand", lambda: _station_wall(STATION_WALL_HIGH))
register("binnen/station/wand_spoor", lambda: _station_wall(STATION_WALL_HIGH, TRACK_OPENING))


def _station_wall_low(width):
    """The low front wall (1 m): stone with a steel top, to look in over."""
    model = V(width, WALL_DEPTH, STATION_WALL_LOW)
    model.box(0, 0, 0, width, WALL_DEPTH, STATION_WALL_LOW - 1, "natuursteen3")
    model.box(0, 0, STATION_WALL_LOW - 1, width, WALL_DEPTH, STATION_WALL_LOW, "rvs")
    return model


register("binnen/station/wand_laag", lambda: _station_wall_low(CELL))
# 2 m: the ends of the front wall, beside the corners of the hall
register("binnen/station/wand_laag_half", lambda: _station_wall_low(CELL // 2))


@tile("binnen/station/tunnel")
def station_tunnel():
    """Behind an opening of the back wall: the dark of the track going on outside (4 m wide,
    a black back and roof), so the opening is not a hole in the world."""
    model = V(CELL, 4, TRACK_OPENING + 2)
    model.box(0, 3, 0, CELL, 4, TRACK_OPENING + 2, "bord_zwart")
    model.box(0, 0, TRACK_OPENING, CELL, 4, TRACK_OPENING + 2, "bord_zwart")
    model.box(0, 0, 0, 1, 4, TRACK_OPENING, "bord_zwart")
    model.box(CELL - 1, 0, 0, CELL, 4, TRACK_OPENING, "bord_zwart")
    return model


@tile("binnen/station/poortje_kast")
def gate_cabinet():
    """One cabinet of the OV gates: steel, 1.5 m long (along the way through), 1 m high, with
    a yellow card reader and a little screen at both ends."""
    model = V(3, 12, 8)
    model.box(0, 0, 0, 3, 12, 7, "rvs")
    model.box(0, 0, 0, 3, 12, 1, "metaal_donker")
    model.box(0, 1, 7, 3, 11, 8, "metaal2")
    for end in (1, 9):
        model.box(0, end, 7, 3, end + 2, 8, "lak_geel1")       # the reader on top
        model.set(1, end + (0 if end == 1 else 1), 6, "scherm")
    return model


@tile("binnen/station/poortje_klep")
def gate_paddle():
    """A paddle of a gate: glass in a steel edge, 0.5 m wide, 1 m high; two close a lane."""
    model = V(4, 1, 8)
    model.box(0, 0, 1, 4, 1, 8, "glas_helder")
    model.box(0, 0, 1, 1, 1, 8, "rvs")
    model.box(0, 0, 7, 4, 1, 8, "rvs")
    model.box(1, 0, 4, 4, 1, 5, "bord_rood")                     # the red band
    return model


@tile("binnen/station/hek")
def glass_fence():
    """A glass fence of 4 m, 1.25 m high, steel posts every metre: the gate line before the
    tracks, where no one may pass."""
    model = V(CELL, 1, 10)
    model.box(0, 0, 0, CELL, 1, 10, "glas_helder")
    for x in range(0, CELL, 8):
        model.box(x, 0, 0, x + 1, 1, 10, "rvs")
    model.box(0, 0, 9, CELL, 1, 10, "rvs")
    return model


def _hanging(model, width, board_height, rod_top, rods):
    """Two rods from the top of a board up to `rod_top` (it hangs from the roof)."""
    for x in rods:
        model.box(x, 0, board_height, x + 1, 1, rod_top, "metaal_donker")


@tile("binnen/station/vertrekbord")
def departure_board():
    """A big departure board hanging over the hall: 6 m wide, 1.75 m high, dark blue in a
    black frame, a yellow strip on top (the text is drawn by the game), on two rods 1.5 m up."""
    width, height = 48, 14
    model = V(width, 2, height + 12)
    model.box(0, 0, 0, width, 2, height, "bord_zwart")
    model.box(1, 0, 1, width - 1, 1, height - 2, "bord_blauw")
    model.box(1, 0, height - 2, width - 1, 1, height - 1, "bord_geel")
    _hanging(model, width, height, height + 12, (6, width - 7))
    return model


@tile("binnen/station/perronscherm")
def platform_display():
    """The display at the head of a track: 2.5 m wide, 0.75 m high, dark blue, a white square
    for the track number on the left (both drawn by the game), on two rods."""
    width, height = 20, 6
    model = V(width, 2, height + 10)
    model.box(0, 0, 0, width, 2, height, "bord_zwart")
    model.box(1, 0, 1, width - 1, 1, height - 1, "bord_blauw")
    model.box(1, 0, 1, 6, 1, height - 1, "bord_wit")
    _hanging(model, width, height, height + 10, (3, width - 4))
    return model


@tile("binnen/station/klok")
def station_clock():
    """The station clock hanging in the hall: a white face of 1 m in a black ring (the hands
    are drawn by the game), on a rod."""
    size = 9
    model = V(size, 2, size + 8)
    middle = (size - 1) / 2
    for x in range(size):
        for z in range(size):
            distance = ((x - middle) ** 2 + (z - middle) ** 2) ** 0.5
            if distance <= middle + 0.3:
                ring = distance > middle - 0.9
                model.box(x, 0, z, x + 1, 2, z + 1, "bord_zwart" if ring else "bord_wit")
    for hour in range(12):
        import math
        angle = hour * math.pi / 6
        model.set(round(middle + math.sin(angle) * (middle - 1.4)), 0, round(middle + math.cos(angle) * (middle - 1.4)), "bord_zwart")
    model.box(4, 0, size, 5, 1, size + 8, "metaal_donker")
    return model


@tile("binnen/station/kaartautomaat")
def ticket_machine():
    """A ticket machine (OV-chipkaart), 0.75 x 0.5 x 1.75 m in voxels of 6.25 cm (its import
    has voxel_size 0.0625): dark blue with a yellow top. The face of the body is y = 1, what
    stands out of it y = 0. From the top: a hood over the screen, sunk two voxels deep in a
    dark bezel; under it a dark panel with the buttons standing out (six choices, a green
    and a red one); the yellow reader you lay your card or ticket on, a card on it drawn
    in white; and the tray the ticket drops into, sunk deep, dark inside."""
    model = V(12, 8, 28)
    model.box(0, 1, 2, 12, 8, 28, "bord_blauw")
    model.box(0, 0, 0, 12, 8, 2, "metaal_donker")               # the foot
    model.box(0, 1, 24, 12, 8, 28, "lak_geel1")                 # the yellow top
    # the screen: a dark bezel, the glass sunk behind it, a hood over it
    model.box(1, 1, 14, 11, 2, 22, "metaal_donker")
    model.clear(2, 1, 15, 10, 2, 21)
    model.box(2, 2, 15, 10, 3, 21, "scherm")
    model.box(1, 0, 22, 11, 1, 23, "metaal_donker")
    # the buttons: a dark panel, six light choices, a green and a red one standing out
    model.box(1, 1, 9, 11, 2, 13, "metaal_donker")
    for x in (2, 4, 6):
        for z in (10, 12):
            model.box(x, 0, z, x + 1, 1, z + 1, "lak_wit1")
    model.box(9, 0, 12, 10, 1, 13, "stoplicht_groen")
    model.box(9, 0, 10, 10, 1, 11, "stoplicht_rood")
    # the reader you lay your card or ticket on: a yellow pad standing out, a card drawn on it
    model.box(1, 0, 5, 6, 1, 8, "lak_geel2")
    model.box(2, 0, 6, 5, 1, 7, "lak_wit1")
    # the tray the ticket drops into: a steel rim, deep and dark inside
    model.box(7, 0, 3, 11, 1, 8, "rvs")
    model.clear(8, 0, 4, 10, 4, 7)
    model.box(8, 4, 4, 10, 5, 7, "bord_zwart")
    model.box(7, 1, 3, 11, 4, 4, "bord_zwart")                  # its floor
    return model


@tile("binnen/station/pilaar")
def station_column():
    """A white steel column of the roof, 0.5 m square, 8 m high, on a dark foot."""
    model = V(4, 4, STATION_WALL_HIGH)
    model.box(0, 0, 0, 4, 4, STATION_WALL_HIGH, "lak_wit1")
    model.box(0, 0, 0, 4, 4, 3, "metaal_donker")
    return model


# the shops: name -> (sign colour, inside colour, goods on the shelves)
SHOPS = {
    "koffie": ("bord_groen", "hout_donker1", ["hout3", "lak_wit1", "hout_donker2", "bord_groen"]),
    "broodjes": ("lak_geel1", "hout2", ["hout3", "blad2", "bord_rood", "lak_geel2"]),
    "kiosk": ("bord_rood", "interieur1", ["reclame1", "reclame2", "reclame3", "bord_blauw", "lak_geel1"]),
    "bloemen": ("bord_groen2", "hout1", ["bloem_rood", "bloem_geel", "bloem_paars", "bloem_roze", "bloem_wit", "blad3"]),
    "stroopwafels": ("bord_oranje", "hout3", ["goud", "hout2", "bord_oranje"]),
    "boeken": ("bord_blauw", "hout_donker2", ["reclame1", "bord_rood", "bord_groen", "lak_wit2", "bord_blauw2"]),
    "snoep": ("neon_roze", "lak_wit1", ["bloem_roze", "bord_geel", "bord_rood", "bord_groen", "bloem_paars"]),
    # Smikkels: the snack bar of the station, with a wall of little lit windows (uit de muur)
    "smikkels": ("bord_rood", "lak_geel1", ["hout3", "hout_donker1", "lak_geel2"]),
}


def shop(sign, inside, goods, snack_wall=False):
    """A shop unit of the hall, 4 m wide, 3 m deep, 3.5 m high: walls and a roof, a lit sign
    band over the front (the name is drawn by the game), shelves of goods at the back and a
    counter across the front with a gap at one end for whoever works there."""
    width, depth, height = CELL, 24, 28
    model = V(width, depth, height)
    model.box(0, depth - 2, 0, width, depth, height, inside)                 # the back wall
    model.box(0, 0, 0, 1, depth, height, inside)                             # the sides
    model.box(width - 1, 0, 0, width, depth, height, inside)
    model.box(0, 0, height - 2, width, depth, height, "metaal_donker")       # the roof
    model.box(0, 0, height - 6, width, 1, height - 1, sign)                  # the sign band
    model.box(0, 0, height - 7, width, 1, height - 6, "lamp_wit")
    model.box(1, 2, 0, width - 1, depth - 2, 1, "tegel3")                    # the floor inside
    # shelves on the back wall, goods on them
    for shelf in range(4):
        z = 4 + shelf * 5
        model.box(2, depth - 5, z, width - 2, depth - 2, z + 1, "hout_donker2")
        for x in range(2, width - 2):
            colour = goods[(x // 2 + shelf) % len(goods)]
            model.box(x, depth - 4, z + 1, x + 1, depth - 2, z + 3 if (x + shelf) % 3 else z + 2, colour)
    if snack_wall:
        # the back wall is a wall of little windows, lit, with a snack behind each (kroket,
        # frikandel, kaassoufflé), in steel frames
        model.box(2, depth - 3, 3, width - 2, depth - 2, 23, "rvs")
        for row in range(5):
            for column in range(7):
                x = 3 + column * 4
                z = 4 + row * 4
                model.box(x, depth - 3, z, x + 3, depth - 2, z + 3, "lamp_warm")
                model.box(x + 1, depth - 4, z, x + 2, depth - 3, z + 1, goods[(row + column) % len(goods)])
    # the counter across the front, with a till and a few goods on it
    model.box(1, 2, 0, width - 5, 6, 8, inside)
    model.box(1, 2, 8, width - 5, 6, 9, "rvs")
    model.box(4, 3, 9, 7, 5, 11, "metaal_donker")                            # the till
    model.box(5, 2, 10, 6, 3, 11, "scherm")
    for x in range(10, width - 7, 3):
        model.box(x, 3, 9, x + 2, 5, 10, goods[x % len(goods)])
    return model


for _shop_name, (_sign, _inside, _goods) in SHOPS.items():
    register(f"binnen/station/winkel_{_shop_name}",
             lambda s=_sign, i=_inside, g=_goods, wall=(_shop_name == "smikkels"): shop(s, i, g, snack_wall=wall))
