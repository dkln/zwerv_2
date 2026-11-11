"""The supermarkets you walk into (category binnen, binnen/supermarkt/): DERREK and ALFRED
STEYHN, the two parody chains of the town (their facades, signs and carts: details_extra,
props). One scene for both (scenes/binnen/supermarkt.tscn): scripts/world/supermarket.gd
lays the shop out anew for every branch (scripts/world/supermarket_layout.gd: its size from
the width of its shop front, the layout from its seed and the chain), with these tiles.

The house style of each chain comes back in every tile that has a `_<brand>` in its name:
DERREK red and white (the basket emblem, square), ALFRED STEYHN light blue with a dark blue
line (the tulip, round). Shelves (schap_<category>_<brand>): gondolas of 4 m with goods on
both sides and a header strip in the chain's colour; against the walls the same in one side
(wandschap_), the fridge wall (koelwand_), chest freezers (diepvries_), the checkouts
(kassa_: belt, scanner, till, a stool for the one at the till, the lane pole in the chain's
colour), self-scan pillars (zelfscan_alfred_steyhn), a stack of baskets and one basket to
carry (mandjes_, mandje_), and per chain something of its own: DERREK promotion pallets
with a big red price board (pallet_derrek), ALFRED STEYHN a bakery counter
(bakkerij_alfred_steyhn). The fruit and vegetable crates and the flower buckets are the
same in both.

Voxels of 0.125 m; the pivot is the middle of the bottom of the frame, the front the side
with the lowest y (Godot +z).
"""
from common import tile, register
from vox import V
from .details_extra import brand_sign, brand_logo

CELL = 32
WALL_DEPTH = 2
SHOP_WALL_HIGH = 28      # 3.5 m
SHOP_WALL_LOW = 8        # 1 m: the front and the right, the iso view looks in over them
GONDOLA_HIGH = 12        # 1.5 m: low enough to see the player in the next aisle
WALL_SHELF_HIGH = 16     # 2 m

# the chains: house colour, its second colour (the line under the band, the lettering),
# the floor (two tiles, checkered), the colour of the baskets and the trim of the shelves
BRANDS = {
    "derrek": {"plate": "winkel_rood", "second": "bord_wit", "floor": ("tegel3", "tegel4"),
               "basket": "winkel_rood", "trim": "bord_wit"},
    "alfred_steyhn": {"plate": "winkel_lichtblauw", "second": "lak_blauw1", "floor": ("natuursteen1", "tegel_wit"),
                      "basket": "winkel_lichtblauw", "trim": "lak_blauw1"},
}

# the goods on a shelf of each category (scripts/world/supermarket_layout.gd CATEGORIES):
# the colours of the packs, and how high a pack stands (voxels)
GOODS = {
    "droog": (["lak_geel1", "bord_rood", "hout3", "bord_blauw", "lak_wit1"], 2),
    "ontbijt": (["bord_oranje", "bord_geel", "hout_donker1", "bord_rood", "bord_groen2"], 2),
    "snoep": (["bloem_roze", "bord_geel", "bord_rood", "bord_groen", "bloem_paars"], 2),
    "drank": (["glas_groen", "glas_brons", "bord_rood", "lak_wit1", "bord_blauw2"], 3),
    "verzorging": (["lak_wit1", "bord_blauw2", "bloem_roze", "bord_groen2", "lak_geel1"], 2),
    "conserven": (["metaal1", "bord_rood", "bord_groen", "lak_geel2", "metaal2"], 1),
    "brood": (["hout3", "hout2", "hout_donker1", "lak_geel2"], 2),
}


def _floor(brand):
    """A 4 x 4 m floor of big tiles (1 m), checkered in the chain's two floor colours, with a
    fine joint."""
    first, second = BRANDS[brand]["floor"]
    model = V(CELL, CELL, 1)
    for x in range(CELL):
        for y in range(CELL):
            joint = x % 8 == 0 or y % 8 == 0
            model.set(x, y, 0, "voeg" if joint else (first if (x // 8 + y // 8) % 2 == 0 else second))
    return model


def _wall(brand, height, width=CELL):
    """A wall of the shop, two deep: white panels, a band in the house colour from 2.25 to
    2.75 m with its second colour as a line under it, white above; a low wall (the front) is
    the house colour with a steel top."""
    plate = BRANDS[brand]["plate"]
    second = BRANDS[brand]["second"]
    model = V(width, WALL_DEPTH, height)
    for x in range(width):
        for z in range(height):
            if height <= SHOP_WALL_LOW:
                colour = "rvs" if z == height - 1 else (plate if z >= 2 else "metaal_donker")
            elif z < 1:
                colour = "metaal_donker"
            elif 18 <= z < 22:
                colour = plate
            elif z == 17:
                colour = second
            else:
                colour = "paneel1" if (x // 16) % 2 else "paneel2"
            for y in range(WALL_DEPTH):
                model.set(x, y, z, colour)
    return model


def _goods_row(model, x0, x1, y0, y1, z, category, seed):
    """Packs on a shelf at height z between x0 and x1 (the y range is their depth): side by
    side in the colours of the category, a gap now and then (someone took one)."""
    colours, high = GOODS[category]
    x = x0
    index = seed
    while x < x1:
        wide = 1 + (index * 7 + z) % 2
        if (index * 13 + z * 3) % 11 != 0:
            model.box(x, y0, z, min(x + wide, x1), y1, z + high + ((index + z) % 2 if high > 1 else 0),
                      colours[index % len(colours)])
        x += wide
        index += 1


def gondola(category, brand, length=CELL):
    """A gondola of `length` (4 m), 1 m deep and 1.5 m high: a dark plinth, a panel down the
    middle, three shelves of goods on both sides, white price strips on the shelf edges and
    on top a header strip in the house colour with the second colour as its edge."""
    plate = BRANDS[brand]["plate"]
    trim = BRANDS[brand]["trim"]
    model = V(length, 8, GONDOLA_HIGH)
    model.box(0, 0, 0, length, 8, 1, "metaal_donker")
    model.box(0, 3, 1, length, 5, GONDOLA_HIGH - 1, "lak_wit2")
    for level, z in enumerate((1, 4, 7)):
        model.box(0, 0, z, length, 8, z + 1, "lak_wit1")                  # the shelf
        for side_y0, side_y1 in ((0, 3), (5, 8)):
            _goods_row(model, 1, length - 1, side_y0 + (1 if side_y0 == 0 else 0), side_y1 - (1 if side_y0 else 0),
                       z + 1, category, level * 5 + side_y0)
        for x in range(1, length - 1, 4):
            model.set(x, 0, z, "bord_wit")                                  # price strips
            model.set(x, 7, z, "bord_wit")
    model.box(0, 2, GONDOLA_HIGH - 1, length, 6, GONDOLA_HIGH, plate)       # the header strip
    model.box(0, 2, GONDOLA_HIGH - 2, length, 3, GONDOLA_HIGH - 1, trim)
    model.box(0, 5, GONDOLA_HIGH - 2, length, 6, GONDOLA_HIGH - 1, trim)
    for x in (0, length - 1):                                               # the end posts
        model.box(x, 0, 0, x + 1, 8, GONDOLA_HIGH - 1, "metaal3")
    return model


def wall_shelf(category, brand):
    """Shelves against a wall (4 m, 0.75 m deep, 2 m high): five shelves of goods on one side
    (the front), a steel back, and a header in the house colour on top."""
    plate = BRANDS[brand]["plate"]
    trim = BRANDS[brand]["trim"]
    model = V(CELL, 6, WALL_SHELF_HIGH)
    model.box(0, 5, 0, CELL, 6, WALL_SHELF_HIGH, "metaal3")
    model.box(0, 0, 0, CELL, 6, 1, "metaal_donker")
    for level, z in enumerate((1, 4, 7, 10)):
        model.box(0, 0, z, CELL, 5, z + 1, "lak_wit1")
        _goods_row(model, 1, CELL - 1, 1, 5, z + 1, category, level * 3)
        for x in range(1, CELL - 1, 4):
            model.set(x, 0, z, "bord_wit")
    model.box(0, 0, WALL_SHELF_HIGH - 3, CELL, 6, WALL_SHELF_HIGH, plate)
    model.box(0, 0, WALL_SHELF_HIGH - 3, CELL, 1, WALL_SHELF_HIGH - 2, trim)
    for x in (0, CELL - 1):
        model.box(x, 0, 0, x + 1, 6, WALL_SHELF_HIGH - 3, "metaal3")
    return model


def fridge_wall(brand):
    """The fridge wall (4 m, 0.75 m deep, 2.1 m high): four glass doors in dark frames, lit
    inside, milk, yoghurt and cheese on the shelves behind them, a header in the house colour
    with a white light strip under it."""
    plate = BRANDS[brand]["plate"]
    model = V(CELL, 6, 17)
    model.box(0, 0, 0, CELL, 6, 17, "metaal_donker")
    model.clear(1, 0, 1, CELL - 1, 5, 14)
    dairy = ["lak_wit1", "bord_blauw2", "lak_geel1", "lak_wit2", "bord_rood", "bord_groen2"]
    for level, z in enumerate((1, 4, 7, 10)):
        model.box(1, 1, z, CELL - 1, 5, z + 1, "rvs")
        for x in range(1, CELL - 1):
            if (x + level) % 5 != 0:
                model.box(x, 2, z + 1, x + 1, 5, z + 2 + (x + level) % 2, dairy[(x // 2 + level) % len(dairy)])
    model.box(1, 4, 1, CELL - 1, 5, 14, "lamp_wit")                         # the lit back
    for door in range(4):
        left = 1 + door * 8
        model.box(left, 0, 1, left + 7, 1, 14, "glas_helder")
        model.box(left + 6, 0, 5, left + 7, 1, 10, "rvs")                   # the handle
    for x in (0, 8, 16, 24, CELL - 1):
        model.box(x, 0, 0, x + 1, 1, 14, "metaal_donker")
    model.box(0, 0, 14, CELL, 6, 17, plate)
    model.box(1, 0, 13, CELL - 1, 1, 14, "lamp_wit")
    return model


def chest_freezer(brand):
    """A chest freezer (4 m, 1 m deep, 0.9 m high): white, a band in the house colour, a
    glass lid, frozen goods inside (ice, pizza, peas)."""
    plate = BRANDS[brand]["plate"]
    model = V(CELL, 8, 7)
    model.box(0, 0, 0, CELL, 8, 6, "lak_wit1")
    model.box(0, 0, 0, CELL, 8, 1, "metaal_donker")
    model.box(0, 0, 3, CELL, 1, 5, plate)
    model.box(0, 7, 3, CELL, 8, 5, plate)
    model.clear(1, 1, 3, CELL - 1, 7, 6)
    frozen = ["bord_blauw", "lak_wit2", "bloem_roze", "bord_groen", "lak_geel1"]
    for x in range(1, CELL - 1, 2):
        for y in range(1, 7, 2):
            model.box(x, y, 3, x + 2, y + 2, 4 + (x + y) % 2, frozen[(x // 2 + y) % len(frozen)])
    model.box(0, 0, 6, CELL, 8, 7, "glas_helder")
    for x in range(0, CELL, 8):
        model.box(x, 0, 6, x + 1, 8, 7, "rvs")
    return model


def checkout(brand):
    """A checkout (3 m long along x, 1.5 m deep): at the front (y 0..6) the counter, the
    front panel in the house colour, the belt in black (from the right, x high, where the
    goods go on, to the scanner), the glass scanner, the till with its screen and a card
    reader, a ledge for the bags at the left end; behind it (y 6..12) the stool of the one
    at the till; at the right end a pole with a box in the house colour (the lane number is
    drawn by the game)."""
    plate = BRANDS[brand]["plate"]
    second = BRANDS[brand]["second"]
    length = 24
    model = V(length, 12, 18)
    model.box(0, 0, 0, length, 6, 7, plate)                                 # the counter
    model.box(0, 0, 0, length, 6, 1, "metaal_donker")
    model.box(0, 0, 5, length, 1, 6, second)
    model.box(0, 0, 7, length, 6, 8, "rvs")                                 # the top
    model.box(9, 1, 8, length - 1, 5, 9, "rubber")                          # the belt
    model.box(6, 1, 8, 9, 5, 9, "glas_helder")                              # the scanner
    model.box(2, 6, 7, 6, 9, 11, "metaal_donker")                           # the till
    model.box(3, 6, 11, 6, 7, 14, "scherm")
    model.box(3, 6, 11, 6, 9, 12, "metaal_donker")
    model.box(1, 1, 8, 3, 3, 9, "metaal_donker")                            # the card reader
    model.set(1, 1, 9, "scherm")
    model.box(0, 0, 8, 2, 6, 9, "lak_wit1")                                 # the bag ledge
    model.box(10, 8, 0, 11, 9, 5, "metaal3")                                # the stool
    model.box(9, 7, 5, 12, 10, 6, "rubber")
    model.box(length - 1, 0, 0, length, 1, 18, "metaal3")                   # the lane pole
    model.box(length - 2, 0, 14, length, 2, 18, plate)
    model.box(length - 2, 0, 15, length, 1, 17, "lamp_wit")
    return model


@tile("binnen/supermarkt/zelfscan_alfred_steyhn")
def self_scan():
    """A self-scan pillar of ALFRED STEYHN (0.75 m square, 1.6 m high): dark blue, a screen
    leaning back, the scanner glass and a bag ledge, a light blue top with the tulip."""
    plate = BRANDS["alfred_steyhn"]["plate"]
    model = V(6, 6, 13)
    model.box(1, 1, 0, 5, 5, 8, "lak_blauw1")
    model.box(0, 0, 8, 6, 6, 9, "rvs")
    model.box(1, 0, 9, 5, 1, 12, "scherm")
    model.box(1, 1, 9, 5, 3, 12, "metaal_donker")
    model.box(1, 3, 9, 5, 4, 10, "glas_helder")
    model.box(0, 0, 12, 6, 6, 13, plate)
    model.box(0, 0, 6, 6, 1, 7, plate)
    return model


@tile("binnen/supermarkt/bakkerij_alfred_steyhn")
def bakery():
    """The bakery of ALFRED STEYHN against a wall (4 m, 1.25 m deep, 2.25 m high): racks of
    loaves and rolls behind, a glass counter with pastries in front, a header in light blue
    with a warm light strip."""
    plate = BRANDS["alfred_steyhn"]["plate"]
    model = V(CELL, 10, 18)
    model.box(0, 8, 0, CELL, 10, 18, "hout2")                               # the racks behind
    for level, z in enumerate((2, 6, 10)):
        model.box(0, 6, z, CELL, 10, z + 1, "hout_donker1")
        _goods_row(model, 1, CELL - 1, 6, 9, z + 1, "brood", level)
    model.box(0, 0, 0, CELL, 4, 7, "hout_donker2")                          # the counter
    model.box(0, 0, 7, CELL, 4, 8, "rvs")
    model.box(1, 0, 8, CELL - 1, 1, 10, "glas_helder")
    model.box(1, 0, 10, CELL - 1, 4, 11, "glas_helder")
    for x in range(2, CELL - 2, 3):
        model.box(x, 1, 8, x + 2, 3, 9, ("lak_geel2", "hout3", "bloem_roze")[x % 3])
    model.box(0, 0, 15, CELL, 10, 18, plate)
    model.box(0, 0, 14, CELL, 1, 15, "lamp_warm")
    return model


@tile("binnen/supermarkt/pallet_derrek")
def promotion_pallet():
    """A promotion pallet of DERREK (1.25 m square): a wooden pallet with boxes stacked on it,
    red and white, and a red price board on a pole over it (its price is drawn by the game)."""
    model = V(10, 10, 20)
    model.box(0, 0, 0, 10, 10, 1, "hout2")
    for y in range(0, 10, 3):
        model.box(0, y, 0, 10, y + 1, 1, "hout3")
    for layer in range(4):
        for x0 in (0, 5):
            for y0 in (0, 5):
                colour = "winkel_rood" if (x0 + y0 // 5 + layer) % 2 == 0 else "bord_wit"
                model.box(x0, y0, 1 + layer * 2, x0 + 5, y0 + 5, 3 + layer * 2, colour)
    model.box(4, 4, 9, 6, 6, 14, "metaal3")
    model.box(1, 4, 14, 9, 6, 20, "winkel_rood")
    model.box(2, 3, 15, 8, 4, 19, "bord_wit")
    return model


@tile("binnen/supermarkt/groentebak")
def produce_stand():
    """The fruit and vegetables (4 m, 1 m deep, 1 m high): wooden crates in two rows leaning
    to the front, apples, bananas, oranges, lettuce, peppers, aubergines."""
    model = V(CELL, 8, 8)
    model.box(0, 0, 0, CELL, 8, 3, "hout_donker1")
    produce = ["bord_rood", "lak_geel1", "bord_oranje", "bord_groen", "blad2", "bloem_paars", "bord_groen2"]
    for row, (y0, y1, z) in enumerate(((0, 4, 3), (4, 8, 5))):
        model.box(0, y0, z - 1 if row else 3, CELL, y1, z, "hout2")
        for crate in range(8):
            left = crate * 4
            model.box(left, y0, z, left + 4, y1, z + 1, "hout3")
            model.box(left + 1, y0 + 1, z, left + 3, y1 - 1, z + 2, produce[(crate + row * 3) % len(produce)])
        if row:
            model.box(0, y0, 3, CELL, y1, z - 1, "hout_donker1")
    return model


@tile("binnen/supermarkt/bloemen")
def flower_buckets():
    """Flowers by the entrance (2 m, 1 m deep): a low stand with zinc buckets, bunches of
    tulips and roses in them."""
    model = V(16, 8, 9)
    model.box(0, 0, 0, 16, 8, 2, "hout_donker1")
    flowers = ["bloem_rood", "bloem_geel", "bloem_roze", "bloem_wit", "bloem_oranje", "bloem_paars"]
    for index, (x, y) in enumerate(((1, 1), (6, 1), (11, 1), (1, 5), (6, 5), (11, 5))):
        model.box(x, y, 2, x + 3, y + 3, 5, "zink1")
        model.box(x, y, 5, x + 3, y + 3, 7, "blad2")
        model.box(x, y, 7, x + 3, y + 3, 9, flowers[index])
    return model


@tile("binnen/supermarkt/deur_personeel")
def staff_door():
    """A door in the back wall for the staff (1 m wide, 2.1 m high): grey with a round window
    and a push plate."""
    model = V(8, 1, 17)
    model.box(0, 0, 0, 8, 1, 17, "metaal2")
    model.box(1, 0, 1, 7, 1, 16, "lak_zilver1")
    model.box(3, 0, 11, 5, 1, 13, "glas_helder")
    model.box(5, 0, 7, 6, 1, 9, "rvs")
    return model


def basket_stack(brand):
    """A stack of shopping baskets (0.5 m square, 0.75 m high) in the chain's colour."""
    colour = BRANDS[brand]["basket"]
    model = V(4, 4, 6)
    for z in range(6):
        for x in range(4):
            for y in range(4):
                if x in (0, 3) or y in (0, 3) or z == 0:
                    model.set(x, y, z, colour if z % 2 == 0 or (x + y) % 2 else "metaal_donker")
    return model


def basket(brand):
    """One shopping basket to carry (0.5 x 0.375 m, 0.25 m high), the handle up."""
    colour = BRANDS[brand]["basket"]
    model = V(4, 3, 4)
    for x in range(4):
        for y in range(3):
            model.set(x, y, 0, colour)
            for z in (1, 2):
                if x in (0, 3) or y in (0, 2):
                    model.set(x, y, z, colour)
    model.box(0, 1, 3, 4, 2, 4, "metaal_donker")
    return model


for _brand in BRANDS:
    register(f"binnen/supermarkt/vloer_{_brand}", lambda b=_brand: _floor(b))
    register(f"binnen/supermarkt/muur_{_brand}", lambda b=_brand: _wall(b, SHOP_WALL_HIGH))
    register(f"binnen/supermarkt/muur_laag_{_brand}", lambda b=_brand: _wall(b, SHOP_WALL_LOW))
    # beside the entrance: low walls of 1 m, the doors 2 m wide between them
    register(f"binnen/supermarkt/muur_laag_kort_{_brand}", lambda b=_brand: _wall(b, SHOP_WALL_LOW, width=8))
    for _category in ("droog", "ontbijt", "snoep", "drank", "verzorging", "conserven"):
        register(f"binnen/supermarkt/schap_{_category}_{_brand}", lambda c=_category, b=_brand: gondola(c, b))
    for _category in ("drank", "brood", "verzorging", "snoep"):
        register(f"binnen/supermarkt/wandschap_{_category}_{_brand}", lambda c=_category, b=_brand: wall_shelf(c, b))
    register(f"binnen/supermarkt/koelwand_{_brand}", lambda b=_brand: fridge_wall(b))
    register(f"binnen/supermarkt/diepvries_{_brand}", lambda b=_brand: chest_freezer(b))
    register(f"binnen/supermarkt/kassa_{_brand}", lambda b=_brand: checkout(b))
    register(f"binnen/supermarkt/mandjes_{_brand}", lambda b=_brand: basket_stack(b))
    register(f"binnen/supermarkt/mandje_{_brand}", lambda b=_brand: basket(b))
    # the name of the chain on the back wall and its emblem, as on the facade but smaller
    # (the wall is 3.5 m high): the emblem 1 m, the letters 0.375 m
    register(f"binnen/supermarkt/logo_{_brand}", lambda b=_brand: brand_logo(b, BRANDS[b]["plate"], size=8))

register("binnen/supermarkt/naambord_derrek", lambda: brand_sign("DERREK", 1, "winkel_rood", brand="derrek"))
register("binnen/supermarkt/naambord_alfred_steyhn", lambda: brand_sign("ALFRED STEYHN", 1, "winkel_lichtblauw",
                                                                       brand="alfred_steyhn"))
