"""The inside of the city hall on the Spui (category binnen, binnen/stadhuis/): the white
city hall, five floors joined by a lift (scenes/binnen/stadhuis.tscn, built by
tools/build/build_interiors.gd from scripts/world/interiors/city_hall_layout.gd, run by
scripts/world/interiors/city_hall.gd). Every floor has a layout of its own: the hall with the
reception, Burgerzaken with its counters, the open-plan office, the meeting rooms and the
archive, and at the top the council chamber.

White everywhere, as the real building: white panels on a grid, white stone floors in the
hall, blue-grey carpet in the offices, oak in the council chamber; the city's colours
(yellow and green: lak_geel1 and bord_groen; the vlag_ colours are flag cloth and wave in the
wind, so only the flag itself has them) and its coat of arms (a black stork on gold) where the city shows itself.

Voxels of 0.125 m; the pivot is the middle of the bottom of the frame, the front the side
with the lowest y (Godot +z).
"""
from common import tile, register
from vox import V

CELL = 32
WALL_DEPTH = 2
HALL_WALL_HIGH = 32     # 4 m
WALL_LOW = 8            # 1 m: the front and the right, to look in over
GLASS_HIGH = 22         # 2.75 m


def _floor(kind):
    """A 4 x 4 m floor: "steen" white stone slabs of 1 m, "tapijt" blue-grey carpet tiles of
    0.5 m, "parket" oak strips."""
    model = V(CELL, CELL, 1)
    for x in range(CELL):
        for y in range(CELL):
            if kind == "steen":
                joint = x % 8 == 0 or y % 8 == 0
                colour = "voeg" if joint else ("marmer" if (x // 8 + y // 8) % 3 else "natuursteen1")
            elif kind == "tapijt":
                colour = "stof2" if (x // 4 + y // 4) % 2 else "stof3"
            else:
                strip = y // 2
                colour = ("hout2", "hout3", "hout1")[(strip + (x + strip * 5) // 12) % 3]
                if (x + strip * 5) % 12 == 0:
                    colour = "hout_donker2"
            model.set(x, y, 0, colour)
    return model


def _wall(height, width=CELL):
    """A white wall, two deep: a grey plinth, white panels on a grid of 1 m (the white of
    the building outside); a low wall (the front, 1 m) white with a steel top."""
    model = V(width, WALL_DEPTH, height)
    for x in range(width):
        for z in range(height):
            if height <= WALL_LOW:
                colour = "rvs" if z == height - 1 else "lak_wit1"
            elif z < 1:
                colour = "beton2"
            elif x % 8 == 0 or z % 8 == 0:
                colour = "lak_wit2"
            else:
                colour = "lak_wit1"
            for y in range(WALL_DEPTH):
                model.set(x, y, z, colour)
    return model


def _glass_wall(width=CELL):
    """A glass partition (2.75 m high): clear glass in white mullions every metre, a frosted
    band at eye height."""
    model = V(width, 1, GLASS_HIGH)
    model.box(0, 0, 0, width, 1, GLASS_HIGH, "glas_helder")
    model.box(0, 0, 10, width, 1, 13, "glas1")
    for x in list(range(0, width, 8)) + [width - 1]:
        model.box(x, 0, 0, x + 1, 1, GLASS_HIGH, "lak_wit1")
    model.box(0, 0, 0, width, 1, 1, "lak_wit1")
    model.box(0, 0, GLASS_HIGH - 1, width, 1, GLASS_HIGH, "lak_wit1")
    return model


@tile("binnen/stadhuis/lift")
def lift():
    """The lift shaft (4 m wide, 2 m deep, 4 m high): steel round the doors, the doors
    themselves are lift_deur (the game slides them), a dark cabin behind, a display over
    the doors (the floor number is drawn by the game) and the call buttons on the right."""
    model = V(CELL, 16, HALL_WALL_HIGH)
    model.box(0, 0, 0, CELL, 16, HALL_WALL_HIGH, "lak_wit1")
    model.box(6, 0, 0, 26, 1, 22, "rvs")                                   # the frame
    model.clear(10, 0, 0, 22, 14, 18)                                      # the door way and the cabin
    model.box(10, 13, 0, 22, 14, 18, "metaal2")                            # the back of the cabin
    model.box(10, 1, 17, 22, 13, 18, "lamp_wit")                           # its light
    model.box(10, 1, 0, 22, 13, 1, "rubber")                               # its floor
    model.box(12, 0, 19, 20, 1, 22, "bord_zwart")                          # the display
    model.box(23, 0, 8, 25, 1, 12, "metaal_donker")                        # the buttons
    model.set(24, 0, 9, "lamp_warm")
    model.set(24, 0, 11, "lamp_warm")
    return model


@tile("binnen/stadhuis/lift_deur")
def lift_door():
    """One leaf of the lift doors (0.75 m wide, 2.25 m high): brushed steel."""
    model = V(6, 1, 18)
    model.box(0, 0, 0, 6, 1, 18, "rvs")
    model.box(0, 0, 0, 1, 1, 18, "lak_zilver2")
    return model


@tile("binnen/stadhuis/receptie")
def reception_desk():
    """A piece of the reception desk (4 m, 1.5 m deep): a white front 1.1 m high with an oak
    top for the visitors, lower behind it the desk with two screens, a phone and papers."""
    model = V(CELL, 12, 12)
    model.box(0, 0, 0, CELL, 3, 9, "lak_wit1")
    model.box(0, 0, 0, CELL, 3, 1, "beton2")
    model.box(0, 0, 4, CELL, 1, 5, "lak_geel1")                            # a line in the city's colours
    model.box(0, 0, 5, CELL, 1, 6, "bord_groen")
    model.box(0, 0, 9, CELL, 4, 10, "hout2")
    model.box(0, 3, 0, CELL, 10, 6, "lak_wit2")                            # the desk behind
    model.box(0, 3, 6, CELL, 10, 7, "hout3")
    for left in (6, 20):
        model.box(left, 7, 7, left + 5, 8, 11, "scherm")
        model.box(left + 2, 8, 7, left + 3, 9, 9, "metaal_donker")
    model.box(14, 5, 7, 17, 7, 8, "bord_zwart")                            # the phone
    model.box(26, 4, 7, 30, 7, 8, "lak_wit1")                              # papers
    return model


@tile("binnen/stadhuis/loket")
def counter():
    """A counter of Burgerzaken (4 m, 2 m deep): on the visitors' side (the front) a counter
    with a glass screen up to 2 m and a slot, a number board over it (the number is drawn by
    the game), behind it the desk of the civil servant with a screen, a chair."""
    model = V(CELL, 16, 18)
    model.box(0, 0, 0, CELL, 4, 9, "lak_wit1")
    model.box(0, 0, 9, CELL, 4, 10, "hout2")
    model.box(0, 3, 10, CELL, 4, 17, "glas_helder")
    model.box(12, 3, 10, 20, 4, 11, None)                                  # the slot
    for x in (0, CELL - 1):
        model.box(x, 0, 0, x + 1, 16, 18, "lak_wit2")                      # the sides of the booth
    model.box(0, 3, 17, CELL, 4, 18, "lak_wit1")
    model.box(10, 3, 15, 22, 4, 17, "bord_zwart")                          # the number board
    model.box(2, 4, 0, CELL - 2, 9, 6, "lak_wit2")                         # the desk behind
    model.box(2, 4, 6, CELL - 2, 9, 7, "hout3")
    model.box(13, 7, 7, 19, 8, 11, "scherm")
    model.box(15, 8, 7, 17, 9, 8, "metaal_donker")
    model.box(14, 11, 0, 18, 15, 4, "stof1")                               # the chair
    model.box(14, 14, 4, 18, 15, 8, "stof1")
    return model


@tile("binnen/stadhuis/wachtbank")
def waiting_bench():
    """Four linked waiting chairs on a steel beam (2 m): blue-grey seats, a back behind."""
    model = V(16, 4, 7)
    model.box(0, 1, 0, 1, 3, 3, "metaal3")
    model.box(15, 1, 0, 16, 3, 3, "metaal3")
    model.box(0, 1, 3, 16, 3, 4, "metaal_donker")
    for seat in range(4):
        left = seat * 4
        model.box(left, 0, 4, left + 3, 4, 5, "stof2")
        model.box(left, 3, 5, left + 3, 4, 7, "stof2")
    return model


@tile("binnen/stadhuis/nummerautomaat")
def ticket_dispenser():
    """The machine you take a number from (0.5 m square, 1.4 m high): white with a screen,
    a big red button and the ticket slot."""
    model = V(4, 4, 11)
    model.box(0, 0, 0, 4, 4, 11, "lak_wit1")
    model.box(0, 0, 0, 4, 4, 1, "beton2")
    model.box(1, 0, 7, 3, 1, 10, "scherm")
    model.box(1, 0, 5, 3, 1, 6, "signaal_rood")
    model.box(1, 0, 3, 3, 1, 4, "metaal_donker")
    return model


@tile("binnen/stadhuis/bureau")
def desk():
    """An office desk (2 m, 1 m deep): a white top on steel legs, a screen, a keyboard, a
    pile of files, a mug."""
    model = V(16, 8, 10)
    for x, y in ((0, 0), (15, 0), (0, 7), (15, 7)):
        model.box(x, y, 0, x + 1, y + 1, 6, "metaal3")
    model.box(0, 0, 6, 16, 8, 7, "lak_wit1")
    model.box(5, 5, 7, 11, 6, 10, "scherm")
    model.box(7, 6, 7, 9, 7, 8, "metaal_donker")
    model.box(5, 2, 7, 11, 3, 8, "metaal_donker")
    model.box(12, 3, 7, 15, 6, 9, "bord_blauw2")
    model.set(2, 3, 7, "lak_rood1")
    return model


@tile("binnen/stadhuis/bureaustoel")
def office_chair():
    """An office chair (0.5 m): a black seat on a column, a back."""
    model = V(4, 4, 8)
    model.box(1, 1, 0, 3, 3, 1, "metaal_donker")
    model.box(1, 1, 1, 3, 3, 4, "metaal3")
    model.box(0, 0, 4, 4, 4, 5, "stof1")
    model.box(0, 3, 5, 4, 4, 8, "stof1")
    return model


@tile("binnen/stadhuis/kast")
def filing_cabinet():
    """A cabinet of files (4 m, 0.5 m deep, 2 m high): white steel, shelves of ring binders
    in many colours."""
    model = V(CELL, 4, 16)
    model.box(0, 3, 0, CELL, 4, 16, "lak_wit1")
    model.box(0, 0, 0, CELL, 4, 1, "lak_wit2")
    binders = ["bord_blauw", "bord_rood", "lak_geel1", "bord_groen", "lak_wit2", "bord_zwart"]
    for z in (1, 6, 11):
        model.box(0, 0, z + 4, CELL, 4, z + 5, "lak_wit1")
        for x in range(1, CELL - 1):
            if (x * 7 + z) % 9:
                model.box(x, 1, z, x + 1, 3, z + 3 + (x % 2), binders[(x + z) % len(binders)])
    for x in (0, CELL - 1):
        model.box(x, 0, 0, x + 1, 4, 16, "lak_wit2")
    return model


@tile("binnen/stadhuis/printer")
def copier():
    """A big copier (1 m, 0.75 m deep, 1.1 m high): grey with paper trays and a panel."""
    model = V(8, 6, 9)
    model.box(0, 0, 0, 8, 6, 8, "lak_zilver1")
    for z in (1, 3, 5):
        model.box(0, 0, z, 8, 1, z + 1, "lak_zilver2")
    model.box(0, 0, 8, 8, 6, 9, "metaal_donker")
    model.box(1, 0, 7, 4, 1, 8, "scherm")
    return model


@tile("binnen/stadhuis/koffieautomaat")
def coffee_machine():
    """The coffee machine of the floor (0.75 m, 1.75 m high): black with a lit menu, the
    cup spot, a little bin beside it."""
    model = V(6, 6, 14)
    model.box(0, 0, 0, 6, 6, 14, "bord_zwart")
    model.box(1, 0, 8, 5, 1, 12, "scherm")
    model.box(1, 0, 4, 5, 1, 7, "metaal_donker")
    model.box(2, 0, 4, 4, 1, 5, "lak_wit1")
    model.box(0, 0, 12, 6, 1, 13, "lamp_warm")
    return model


@tile("binnen/stadhuis/plant")
def pot_plant():
    """A big plant in a white pot (0.75 m, 1.75 m high)."""
    model = V(6, 6, 14)
    model.box(1, 1, 0, 5, 5, 4, "lak_wit1")
    for z in range(4, 14):
        spread = 3 if 6 <= z <= 11 else 2
        for x in range(3 - spread, 3 + spread):
            for y in range(3 - spread, 3 + spread):
                if (x * 5 + y * 3 + z * 7) % 4:
                    model.set(x, y, z, ("blad1", "blad2", "blad3")[(x + y + z) % 3])
    model.box(2, 2, 4, 4, 4, 8, "schors1")
    return model


@tile("binnen/stadhuis/vergadertafel")
def meeting_table():
    """A long meeting table (4 m, 1.25 m deep): oak on white legs, a jug of water and glasses,
    a speaker phone in the middle."""
    model = V(CELL, 10, 7)
    for x in (2, CELL - 3):
        model.box(x, 2, 0, x + 1, 8, 6, "lak_wit1")
    model.box(0, 0, 6, CELL, 10, 7, "hout2")
    model.box(15, 4, 7, 17, 6, 8, "bord_zwart")
    model.box(6, 4, 7, 7, 5, 9, "glas_helder")
    for x in (9, 22, 26):
        model.set(x, 3, 7, "glas_helder")
    return model


@tile("binnen/stadhuis/raadstafel")
def council_desk():
    """A desk of the council (4 m, 1 m deep): dark oak with a front panel, a microphone on a
    stalk and a name plate for each of the three seats."""
    model = V(CELL, 8, 10)
    model.box(0, 0, 0, CELL, 2, 6, "hout_donker2")
    model.box(0, 0, 6, CELL, 8, 7, "hout_donker1")
    for seat in range(3):
        middle = 5 + seat * 11
        model.box(middle, 5, 7, middle + 1, 6, 10, "metaal_donker")
        model.set(middle, 4, 9, "signaal_rood")
        model.box(middle - 2, 1, 7, middle + 2, 2, 8, "lak_wit1")
    return model


@tile("binnen/stadhuis/voorzittersbank")
def chair_bench():
    """The chair's bench at the head of the council chamber (4 m, 1.5 m deep): a raised
    oak platform of 0.25 m with a high desk on it, the city's colours on its front."""
    model = V(CELL, 12, 12)
    model.box(0, 0, 0, CELL, 12, 2, "hout_donker2")
    model.box(0, 0, 2, CELL, 3, 11, "hout_donker1")
    model.box(0, 0, 11, CELL, 5, 12, "hout2")
    model.box(4, 0, 6, CELL - 4, 1, 7, "lak_geel1")
    model.box(4, 0, 5, CELL - 4, 1, 6, "bord_groen")
    for middle in (8, 16, 24):
        model.box(middle, 4, 12, middle + 1, 5, 12, "metaal_donker")
    return model


@tile("binnen/stadhuis/tribune")
def public_gallery():
    """A piece of the public gallery (4 m, 2 m deep): two rows of seats, the back one higher,
    blue-grey."""
    model = V(CELL, 16, 9)
    model.box(0, 8, 0, CELL, 16, 2, "beton2")
    for row, (y0, z0) in enumerate(((0, 0), (8, 2))):
        for seat in range(8):
            left = seat * 4
            model.box(left, y0 + 1, z0, left + 1, y0 + 3, z0 + 3, "metaal3")
            model.box(left, y0, z0 + 3, left + 3, y0 + 4, z0 + 4, "stof2")
            model.box(left, y0 + 3, z0 + 4, left + 3, y0 + 4, z0 + 7, "stof2")
    return model


@tile("binnen/stadhuis/wapen")
def coat_of_arms():
    """The coat of arms of the city on a wall (1.5 m): a gold shield with a black stork
    holding an eel in its beak, a crown over it.

    Four deep with the shield in the front two (the back half empty); the interiors hang it
    just before the wall (scripts/world/interiors/wall_mount.gd), not in its plane."""
    rows = [
        "....#..#..#....",
        "...#########...",
        "...............",
        "##############.",
        "#............#.",
        "#.....###....#.",
        "#....#####...#.",
        "#.....##.....#.",
        "#.....##.##..#.",
        "#....####....#.",
        "#...######...#.",
        "#....####....#.",
        "#.....#.#....#.",
        ".#....#.#...#..",
        "..#...#.#..#...",
        "...##.....#....",
        ".....#####.....",
    ]
    model = V(15, 4, len(rows))
    for row_index, line in enumerate(rows):
        z = len(rows) - 1 - row_index
        if row_index < 3:
            # the crown: gold where it is drawn
            for x, pixel in enumerate(line):
                if pixel == "#":
                    model.box(x, 0, z, x + 1, 2, z + 1, "goud")
            continue
        # the shield: its edge and the stork black, the field between the edges gold
        left, right = line.find("#"), line.rfind("#")
        for x in range(left, right + 1):
            model.box(x, 0, z, x + 1, 2, z + 1, "bord_zwart" if line[x] == "#" else "goud")
    return model


@tile("binnen/stadhuis/vlag")
def city_flag():
    """The flag of the city on a standing pole (2.5 m): yellow over green, a gold knob."""
    model = V(8, 2, 20)
    model.box(0, 0, 0, 2, 2, 1, "metaal_donker")
    model.box(0, 0, 0, 1, 1, 19, "messing")
    model.set(0, 0, 19, "goud")
    model.box(1, 0, 14, 8, 1, 18, "vlag_geel")
    model.box(1, 0, 10, 8, 1, 14, "vlag_groen")
    return model


@tile("binnen/stadhuis/schilderij")
def painting():
    """A painting on a wall (2 m x 1.25 m): the dunes and the sea at Scheveningen in a gold
    frame."""
    model = V(16, 1, 10)
    model.box(0, 0, 0, 16, 1, 10, "goud")
    model.box(1, 0, 1, 15, 1, 9, "water2")
    model.box(1, 0, 5, 15, 1, 9, "lak_wit2")
    model.box(1, 0, 1, 15, 1, 3, "zand1")
    model.box(5, 0, 3, 7, 1, 5, "zand2")
    return model


@tile("binnen/stadhuis/prullenbak")
def waste_bin():
    """A waste bin by the coffee machine and the benches (0.5 m, 0.875 m high): a white bin
    with a swing lid in the city's green and a dark slot."""
    model = V(4, 4, 7)
    model.box(0, 0, 0, 4, 4, 6, "lak_wit1")
    model.box(0, 0, 0, 4, 4, 1, "metaal_donker")
    model.box(0, 0, 6, 4, 4, 7, "bord_groen")
    model.box(1, 0, 5, 3, 1, 6, "bord_zwart")
    return model


@tile("binnen/stadhuis/infozuil")
def info_pillar():
    """An information pillar in the hall (0.5 m, 1.75 m high): white with a screen and the
    city's colours on top."""
    model = V(4, 3, 14)
    model.box(0, 0, 0, 4, 3, 14, "lak_wit1")
    model.box(0, 0, 6, 4, 1, 12, "scherm")
    model.box(0, 0, 12, 4, 3, 13, "lak_geel1")
    model.box(0, 0, 13, 4, 3, 14, "bord_groen")
    return model


@tile("binnen/stadhuis/deurmat")
def doormat():
    """The doormat inside the entrance (2 m x 1 m): dark grey with the city's colours."""
    model = V(16, 8, 1)
    for x in range(16):
        for y in range(8):
            rim = x in (0, 15) or y in (0, 7)
            model.set(x, y, 0, "bord_groen" if rim else ("antraciet1" if (x + y) % 2 else "antraciet2"))
    return model


for _kind in ("steen", "tapijt", "parket"):
    register(f"binnen/stadhuis/vloer_{_kind}", lambda k=_kind: _floor(k))
register("binnen/stadhuis/muur", lambda: _wall(HALL_WALL_HIGH))
register("binnen/stadhuis/muur_laag", lambda: _wall(WALL_LOW))
# beside a door of 1.5 m: a low wall of 1.25 m
register("binnen/stadhuis/muur_laag_half", lambda: _wall(WALL_LOW, width=10))
register("binnen/stadhuis/glaswand", lambda: _glass_wall())
# beside a door in a glass partition: 1.25 m of glass (the door 1.5 m)
register("binnen/stadhuis/glaswand_kort", lambda: _glass_wall(10))
