"""Ground tiles, extension 4: curves with height. Rising (helical) quarter-circle curves
on an embankment, the same curves as thin bridge decks, flat curved bridge decks, a
curved 3-lane car tunnel, and embankment fill blocks to stack under rising curves.

All families reuse the big multi-tile curves of ground3.py (curve_polar, the profiles in
CURVE_PROFILES, inner radius CURVE_RADIUS = 1 tile): a curve of a w-part profile covers
n x n cells with n = 1 + w, and tile (i, j) of every family has exactly the footprint of
the flat curve tile ``grond/bocht/<profile>_<i>_<j>``. Voxel conventions as everywhere
(32x32 voxels per cell, 12.5 cm voxels, x = left->right, y = front->back, z = up, front
= y=0 = Godot +Z); tiles may be taller than one floor (8 voxels), their z=0 is the floor
of the cell they are placed in.

PLACEMENT GUIDE (for the scene builder)
---------------------------------------
Geometry (rotation k=0, x = east, z = south, in cells): the curve centre is the
south-west corner of cell (hx, hz); cell (i, j) goes to grid cell (hx + i, floor, hz - j),
every cell with the same rotation k (in tools/build_example_city.gd terms:
``o = _rotate_offset(Vector2i(i, -j), k)``, cell (hx + o.x, floor, hz + o.y), rotation k),
exactly like the flat curves. The road enters at the START = the south edge of row
j=0 (columns i=1..w, heading north) and leaves at the END = the west edge of column
i=0 (rows j=1..w, heading west). Profile part d (0 = inner side) lies in column
i = 1 + d at the start and in row j = 1 + d at the end. Cells that would be empty are
not generated (e.g. (3, 3) for n=4; (3, 4), (4, 3), (4, 4) for n=5).

Rising curves rise R = rise_floors(w) floors over the arc (slope along the centre line
~1 m per 4 m like the straight ramps): straat / klinkerstraat / fietspad (n=4): R=4,
weg (n=5): R=5. The height is constant across the road (radially level) and grows
linearly with the angle (the importer makes the surface smooth, addons/vox_tiles/slopes.gd).

* ``grond/helling_bocht/<profile>_<i>_<j>`` (embankment, rises START -> END: climbing
  you turn LEFT). START is at height 0: it joins a flat road on floor 0 (or the top of
  a straight ramp on floor -1). END is at R floors: it joins a flat road / straight
  ramp on floor R (a ramp rising further west uses rotation k+1).
* ``grond/helling_bocht/<profile>_rechts_<i>_<j>`` (embankment, rises END -> START:
  climbing you turn RIGHT). END is at height 0 (floor 0), START at R floors (floor R;
  a ramp rising further south uses rotation k+2).
* ``grond/helling_bocht/brug_<profile>_<i>_<j>`` / ``brug_<profile>_rechts_<i>_<j>``:
  the same surfaces as thin bridge decks with parapets on both curved edges. Same
  cells, same floors, so embankment and bridge cells can be mixed per cell (e.g.
  embankment cells on floor 0, bridge cells above). Cells whose centre lies under the
  deck (pier_cell; table below) carry a pier stub from their z=0 up to the deck, so a
  ``brug/brug_pijler`` stack below them (``brug_pijler_gras/stoep/water`` on floor 0)
  meets the deck without a gap.
* ``grond/helling_bocht/ophoging_<n>x<n>_<i>_<j>``: one floor (8 voxels) of solid earth
  with the footprint of the profile ring of cell (i, j); stack it on floors 1 .. f-1
  under an embankment cell that sits on floor f > 1 (n = 4 or 5).
  ``ophoging_gras_<n>x<n>_<i>_<j>`` is the same block with grass on the rest of the
  cell: put it on floor 0 under every embankment cell with f > 0 (a GridMap cell holds
  one tile, so the grass around the dike foot has to be part of this tile).
* ``grond/brug/bocht_<profile>_<i>_<j>``: flat curved bridge deck (thin deck, parapets
  on both curved edges); every cell on the deck floor H, ``brug_pijler`` stacks under
  the pier cells (table below). Joins ``brug/brug_dek_*`` decks on floor H at START and END.
* ``grond/tunnel/bocht_<i>_<j>`` (n=4): the 3-lane tunnel cross-section
  (``tunnel_rijstrook_wand`` inner, ``tunnel_rijstrook``, ``tunnel_rijstrook_wand_rechts``
  outer) following the curve; every cell on floor -6 (roof at street level). At START
  continue with those straight tunnel tiles (rotation k, wand at i=1, wand_rechts at
  i=3); at END with rotation k+1 (wand in row j=1, wand_rechts in row j=3).

The floor of each cell of a rising curve is the floor of the lowest surface point in
that cell (cell_floor); ``curve_floors(profile, right)`` returns the full table. For
rotation k only the cell positions rotate; floors stay attached to (i, j). Floors per
cell, rows printed from j = n-1 (top) down to j = 0, columns i = 0.. (- = no tile):

  straat, klinkerstraat, fietspad (n=4, R=4)     weg (n=5, R=5)
  left            right                          left               right
  j=3: 3 2 2 -    0 0 1 -                        j=4: 4 3 2 - -     0 0 1 - -
  j=2: 2 2 1 1    0 0 1 2                        j=3: 3 3 2 2 -     0 0 1 2 -
  j=1: 2 1 0 0    0 1 2 2                        j=2: 3 2 1 1 1     0 1 1 2 2
  j=0: 0 0 0 0    0 2 2 3                        j=1: 2 1 1 0 0     0 1 2 3 3
                                                 j=0: 0 0 0 0 0     0 2 3 3 4

Pier cells (a round pier fits under the deck): n=4: every used cell except (0, 0),
(3, 2), (2, 3); n=5: every used cell except (0, 0), (4, 2), (3, 3), (2, 4).

Straight tiles next to a curve (k=0; add k to every rotation): at START part d sits at
(hx + 1 + d, hz + r) for r >= 1 with the usual rotations of a north-south street
(e.g. stoep_rand inner 1, outer 3; ramps rising north 0, rising south 2). At END part d
sits at (hx - r, hz - 1 - d) and every START rotation becomes rotation + 1 (stoep_rand
inner 2, outer 0; ramps rising west 1, rising east 3; brug_dek_stoep_rand inner 1,
outer 3; tunnel tiles 1).
"""
import math
from functools import partial

from common import T, FLOOR, register, slopes
from vox import V
from ground import EARTH, grass_tile
from ground2 import tunnel
from ground3 import CURVE_PROFILES, CURVE_RADIUS, curve_polar, _curve_source, _profile

QUARTER = math.pi / 2
RISING_PROFILES = ("straat", "klinkerstraat", "weg", "fietspad")   # profiles that get height variants
PIER_R = 5.2          # radius of brug_pijler (ground.pier)


def curve_size(w):
    """Number of cells along each side of the curve of a w-part profile."""
    return CURVE_RADIUS + w


def rise_floors(w):
    """Floors a rising curve of a w-part profile climbs: arc length at the mid radius / 1 tile, rounded."""
    rmid = CURVE_RADIUS * T + w * T / 2.0
    return max(1, round(rmid * QUARTER / T))


def rise_height(a, floors, right=False):
    """Surface offset (voxels above floor 0) at angle a for a curve rising `floors` floors.

    Left (default): 0 at the start (a=0) up to floors*FLOOR-1 at the end (a=pi/2);
    right: the other way round. Always in 0 .. floors*FLOOR-1, so the next tile at the
    high end (on floor `floors`) is one voxel step higher, as between straight ramps.
    """
    t = a / QUARTER
    if right:
        t = 1.0 - t
    return min(max(int(t * floors * FLOOR), 0), floors * FLOOR - 1)


def ring_columns(i, j, w):
    """[(x, y, u, a, r)] for the columns of cell (i, j) that lie on the profile ring."""
    out = []
    for y in range(T):
        for x in range(T):
            r, u, a, _ = curve_polar(i, j, x, y, w)
            if u is not None:
                out.append((x, y, u, a, r))
    return out


def cell_floor(i, j, w, height):
    """Floor for cell (i, j): floor of its lowest surface point; None for an empty cell.

    height(a) is the surface offset (voxels above floor 0) at angle a.
    """
    cols = ring_columns(i, j, w)
    if not cols:
        return None
    return min(height(a) for (_, _, _, a, _) in cols) // FLOOR


def used_cells(w):
    """Cells (i, j) of an n x n curve that contain part of the profile ring."""
    n = curve_size(w)
    return [(i, j) for i in range(n) for j in range(n) if ring_columns(i, j, w)]


def pier_cell(i, j, w):
    """True when a round pier (radius PIER_R) under the centre of cell (i, j) lies fully under the deck."""
    r = math.hypot(i * T + T / 2, j * T + T / 2)
    rin = CURVE_RADIUS * T
    return rin + PIER_R <= r <= rin + w * T - PIER_R


def curve_floors(profile, right=False):
    """{(i, j): floor} for the rising curve of `profile` (left or right variant)."""
    w = _curve_source(profile)[1]
    hf = partial(rise_height, floors=rise_floors(w), right=right)
    return {c: cell_floor(c[0], c[1], w, hf) for c in used_cells(w)}


def curve_cell(src, w, i, j):
    """Build cell (i, j) of a flat curve that maps the wide profile model `src` onto the
    ring (the tunnel curve; the rising curves and curved bridge decks are made by the
    importer from the flat curve cells, see the registration below)."""
    m = V(T, T, src.sz)
    rmid = CURVE_RADIUS * T + w * T / 2.0
    for (x, y, u, a, r) in ring_columns(i, j, w):
        by = int(a * rmid) % T
        for z in range(src.sz):
            c = src.get(u, by, z)
            if c:
                m.set(x, y, z, c)
    return m


def fill_block(w, i, j, grass=False):
    """One floor of solid earth with the footprint of the profile ring in cell (i, j);
    with `grass` the rest of the cell is a grass tile (for floor 0)."""
    m = grass_tile() if grass else V(T, T, FLOOR)
    for (x, y, _, _, _) in ring_columns(i, j, w):
        for z in range(FLOOR):
            m.set(x, y, z, EARTH)
    return m


_tunnel_src = []


def tunnel_curve(i, j):
    """Cell (i, j) of the curved 3-lane car tunnel (place every cell on floor -6)."""
    if not _tunnel_src:
        _tunnel_src.append(_profile([tunnel(True), tunnel(False), tunnel(True).mirror_x()]))
    return curve_cell(_tunnel_src[0], 3, i, j)


# ------------------------------------------------------------------ registration

# the rising curves and flat curved bridge decks are made by the importer from the flat
# curve cells grond/bocht/<profile>_<i>_<j> (addons/vox_tiles/slopes.gd does what
# curve_cell does here: rise_height for bocht / bocht_rechts, deck=True for brug_*; off
# the ring a cell on floor 0 keeps the flat cell's columns)
for _pname in RISING_PROFILES:
    _w = len(CURVE_PROFILES[_pname][0]())
    for (_i, _j) in used_cells(_w):
        slopes(f"grond/bocht/{_pname}_{_i}_{_j}", "bocht", "bocht_rechts", "brug_bocht", "brug_bocht_rechts", "brug_vlak",
               curve=(_i, _j, _w))

for _w in sorted({len(CURVE_PROFILES[_p][0]()) for _p in RISING_PROFILES}):
    _n = curve_size(_w)
    for (_i, _j) in used_cells(_w):
        register(f"grond/helling_bocht/ophoging_{_n}x{_n}_{_i}_{_j}", partial(fill_block, _w, _i, _j))
        register(f"grond/helling_bocht/ophoging_gras_{_n}x{_n}_{_i}_{_j}", partial(fill_block, _w, _i, _j, True))

for (_i, _j) in used_cells(3):
    register(f"grond/tunnel/bocht_{_i}_{_j}", partial(tunnel_curve, _i, _j))
