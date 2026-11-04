"""Ground tiles: square road corners, where the lines of a straight tile bend round.

For straight roads that meet at a right angle on the grid (no rounded road edge, see
ground_bridges_curves for those). Every corner tile is a straight tile bent a quarter
turn, so markings, coloured surfaces and tram rails all carry on through it. A tile is
named after its straight tile, in the same folder:

    <straight>_hoek_rechts   comes in at the front, leaves to the right (x = T side)
    <straight>_hoek_links    comes in at the front, leaves to the left (x = 0 side)

PLACEMENT: where a road of n lanes turns, it covers n x n cells. Number its lanes from
the inside of the corner, 0 .. n-1: lane k runs along row k and column k, so it turns in
cell (k, k) and every other cell is an ordinary straight tile of one of the lanes. With
driving on the right, the inside lane of a two-way road turns right and the outside lane
turns left. The centre line of a two-way road bends in the inside cell, so that cell
takes the tile with the line and the other three none:

    rijstrook_geen_kant                      rijstrook_geen_kant_hoek_links   (outside)
    rijstrook_onderbroken_kant_hoek_rechts   rijstrook_geen_kant

A line between two lanes bends in the inner of their two cells, so a straight tile beside
it must not run that same line on to the middle of the corner: those lanes use a straight
tile without it. Normal lanes have one already (rijstrook_geen_kant); the others are here
("_zonder_streep"). A bus lane in a right-hand bend is the inside lane and carries the
line (rijstrook_bus_leeg_hoek_rechts, the normal lane beside it rijstrook_onderbroken_geen);
in a left-hand bend the normal lane carries it (rijstrook_geen_streep_hoek_links, outside
it rijstrook_bus_leeg_zonder_streep_hoek_links). A motorway likewise: right-hand bend
snelweg_rijstrook_hoek_rechts inside with snelweg_rijstrook_links_zonder_streep beside and
outside it, left-hand bend snelweg_rijstrook_links_hoek_links inside with
snelweg_rijstrook_zonder_streep.

On the outside of a bend the road would end in a square corner of asphalt beyond the
curved lines. The outside lane of a road with a pavement round the bend therefore has tiles
with that pavement in them, its kerb following the same curve:

    <straight>_hoek_links_stoep, _hoek_links_goot, _hoek_links_klinker

named after the kind of pavement beside it (plain, with a gutter, clinkers). The pavement
cell diagonally outside the corner then is a plain full tile, without its own road corner.

Lanes and who may use the tile: tools/voxgen/traffic.py.
"""
import math

from functools import partial

from common import T, TILES, register
from palette import P
from .ground import BUS, CURB, GUTTER, PAVING, column, flat, lane, line_y, paver_fn, DASH, ROAD, WALK, _lines_y

RIGHT = "rechts"
LEFT = "links"
_LINE_COLOURS = {P["markering"], P["markering2"]}


def _bus_lane_without_text():
    """busbaan_vrij without its painted word, which would come out warped in a bend."""
    m = flat(BUS)
    line_y(m, 31, dash=DASH)
    line_y(m, 1)
    return m


def _motorway_lane_left_without_divider():
    """snelweg_rijstrook_links without the divider on its right."""
    m = flat()
    _lines_y(m, (0, 1))
    return m


# Straight tiles without the line that bends in the corner beside them (see the top).
register("grond/weg/rijstrook_bus_leeg_zonder_streep", partial(lane, "geen", "kant", BUS))
register("grond/weg/rijstrook_geen_streep", partial(lane, "geen", "streep"))
register("grond/snelweg/snelweg_rijstrook_links_zonder_streep", _motorway_lane_left_without_divider)
register("grond/snelweg/snelweg_rijstrook_zonder_streep", flat)


# The straight tiles that get corners. Tiles with a word or pictogram get theirs through
# a version without it: rijstrook_bus through rijstrook_bus_leeg, rijstrook_fietsstrook
# through fietsstrook.
SOURCES = {
    "grond/weg": [f"rijstrook_{left}_{right}" for left, right in (
        ("geen", "geen"), ("geen", "kant"), ("geen", "kant_onderbroken"),
        ("onderbroken", "kant"), ("onderbroken", "geen"), ("onderbroken", "onderbroken"),
        ("streep", "kant"), ("streep", "geen"), ("dubbel", "kant"), ("dubbel", "geen"),
        ("blok", "kant"), ("blok", "geen"))
    ] + ["rijstrook_doorgetrokken_dubbel", "rijstrook_geen_streep", "rijstrook_bus_leeg",
          "rijstrook_bus_leeg_zonder_streep", "busbaan_vrij", "fietsstrook", "fietsstraat"],
    "grond/tram": [f"tram_rijstrook_{left}_{right}" for left, right in (
        ("onderbroken", "kant"), ("geen", "kant"), ("streep", "kant"),
        ("onderbroken", "geen"), ("geen", "geen"), ("dubbel", "kant"))],
    "grond/snelweg": ["snelweg_rijstrook", "snelweg_rijstrook_links", "snelweg_rijstrook_zonder_streep",
                      "snelweg_rijstrook_links_zonder_streep", "snelweg_vluchtstrook",
                      "snelweg_blokmarkering", "snelweg_aansluiting"],
    "grond/fietspad": ["fietspad_naast_weg"],
}
_SOURCE_MAKERS = {"grond/weg/busbaan_vrij": _bus_lane_without_text}


def _column_has_line(straight, x):
    """True if a marking runs anywhere along column x of a straight tile."""
    for y in range(T):
        top = straight.top(x, y)
        if top and straight.get(x, y, top - 1) in _LINE_COLOURS:
            return True
    return False


def _clean_outer_column(straight, turn):
    """The column nearest the outside of the bend without a line: what fills the tile
    beyond the arc of the outermost column."""
    columns = range(T) if turn == RIGHT else range(T - 1, -1, -1)
    return next((x for x in columns if not _column_has_line(straight, x)), T // 2)


def bend(straight, turn):
    """Tile `straight` bent a quarter turn round the corner on the inside of the bend.

    Each column of the new tile is taken from the straight tile by polar coordinates:
    its radius gives the place across the lane, its arc length the place along it, so a
    line at distance r from the inside edge stays at distance r and dashes keep their
    length. The corner beyond the arc takes the surface of the outermost clean column.
    """
    m = type(straight)(T, T, straight.sz)
    outer_column = _clean_outer_column(straight, turn)
    for y in range(T):
        for x in range(T):
            from_centre = T - x - 0.5 if turn == RIGHT else x + 0.5
            radius = math.hypot(from_centre, y + 0.5)
            across = int(T - radius) if turn == RIGHT else int(radius)
            along = int(math.atan2(y + 0.5, from_centre) * radius) % T
            if not 0 <= across < T or radius > T:
                across, along = outer_column, y
            for z in range(straight.sz):
                colour = straight.get(across, along, z)
                if colour:
                    m.set(x, y, z, colour)
    return m


def bend_with_pavement(straight, surface, gutter):
    """Tile `straight` bent to the left, with a pavement of `surface` beyond the arc of its
    outermost column: a kerb along the curve, in front of it a gutter if `gutter`."""
    m = bend(straight, LEFT)
    kerb_start = 3 if gutter else 0
    for y in range(T):
        for x in range(T):
            beyond_arc = math.hypot(x + 0.5, y + 0.5) - T
            if beyond_arc <= 0:
                continue
            m.clear(x, y, 0, x + 1, y + 1, m.sz)
            if beyond_arc < kerb_start:
                column(m, x, y, ROAD, GUTTER)
            elif beyond_arc < kerb_start + 1:
                column(m, x, y, WALK, CURB, CURB)
            else:
                column(m, x, y, WALK, surface)
    return m


def _corner_maker(path, turn):
    """Tile function: the straight tile `path` bent to the side `turn`."""
    def make():
        return bend(_SOURCE_MAKERS.get(path, TILES[path])(), turn)
    return make


for _folder, _names in SOURCES.items():
    for _name in _names:
        for _turn in (RIGHT, LEFT):
            register(f"{_folder}/{_name}_hoek_{_turn}", _corner_maker(f"{_folder}/{_name}", _turn))

# The outside lanes of the bends in the streets, per kind of pavement (see the top).
for _path in ("grond/weg/rijstrook_geen_kant", "grond/tram/tram_rijstrook_geen_kant", "grond/weg/fietsstraat", "grond/weg/fietsstrook"):
    for _pavement, _surface, _gutter in (("stoep", PAVING, False), ("goot", PAVING, True), ("klinker", paver_fn, False)):
        register(f"{_path}_hoek_links_{_pavement}",
                 partial(lambda path, surface, gutter: bend_with_pavement(TILES[path](), surface, gutter), _path, _surface, _gutter))
