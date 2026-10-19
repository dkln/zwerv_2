"""Shared constants, the tile registry and small bitmap fonts / pictograms.

Every tile module registers its tile functions here, either with the ``@tile(path)``
decorator or with ``register(path, fn)``. ``generate.py`` imports all tile modules
(which fills ``TILES``) and then calls each function to build the model and write
``<OUT>/<path>.vox`` plus its ``.tile.json`` metadata.

Sizes are in voxels of 12.5 cm; coordinates follow MagicaVoxel (x = left->right,
y = front->back, z = up; the front of a tile is the y=0 side).
"""

TILES = {}  # tile path (without .vox) -> function returning a vox.V model
SLOPES = {}  # tile path -> slope shapes the importer makes of it (addons/vox_tiles/slopes.gd)
CURVES = {}  # curve cell tile path -> (i, j, parts) for the curve slope shapes
SMOOTH = {}  # tile path -> {"shape", "lift", "keep_x"}: tile is a padded block the importer smooths

# slope shapes, in the order they are written to the metadata
SLOPE_SHAPES = ("steil", "flauw_a", "flauw_b", "hoek_buiten", "hoek_binnen", "brug", "brug_rand",
                "bocht", "bocht_rechts", "brug_bocht", "brug_bocht_rechts", "brug_vlak")

T = 32          # ground tile width in voxels (4 m at 0.125 m/voxel)
ROAD = 2        # top of the road surface (z)
WALK = 3        # top of sidewalk / grass (z)
FLOOR = 8       # height of one ground layer (1 m)
STOREY = 24     # height of one building storey (3 m)


def register(path, fn):
    """Register ``fn`` (no-argument callable returning a V) as the builder for tile ``path``."""
    TILES[path] = fn


def slopes(path, *shapes, curve=None):
    """Let the importer also make the given slope shapes of flat tile ``path``; they become
    tiles grond/helling/helling_<name> (steil), flauw_<name>_a / _b,
    helling_<name>_hoek_buiten / _binnen and helling_brug_<name> / helling_brug_<name>_rand.
    The curve shapes of a flat curve cell need ``curve=(i, j, parts)``: they become
    grond/helling_bocht/<profile>[_rechts]_<i>_<j>, helling_bocht/brug_<profile>[_rechts]_<i>_<j>
    and brug/bocht_<profile>_<i>_<j>. Written to the metadata as "slopes" and "curve"."""
    have = set(SLOPES.get(path, ())) | set(shapes)
    SLOPES[path] = [s for s in SLOPE_SHAPES if s in have]
    if curve:
        CURVES[path] = list(curve)


def smooth(path, shape, lift=2, keep_x=()):
    """Tile ``path`` is a flat surface raised by ``lift`` voxels on a fill block (ground.padded);
    the importer moves it onto the smooth slope ``shape`` (steil, flauw_a, flauw_b,
    hoek_buiten, hoek_binnen or heuvel_top), except the columns x in ``keep_x`` (a wall).
    Written to the metadata as "smooth" (addons/vox_tiles/slopes.gd)."""
    SMOOTH[path] = {"shape": shape, "lift": lift, "keep_x": list(keep_x)} if keep_x else {"shape": shape, "lift": lift}


def tile(path):
    """Decorator form of :func:`register` for tile ``path``; returns the function unchanged."""
    def deco(fn):
        register(path, fn)
        return fn
    return deco


# 3x5 pixel font; each glyph is 5 rows (row 0 = top), '#' = pixel set.
FONT = {
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "##.", "#..", "#.."],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Z": ["###", "..#", ".#.", "#..", "###"],
    " ": ["...", "...", "...", "...", "..."],
    "-": ["...", "...", "###", "...", "..."],
}


def text_pixels(text, spacing=1):
    """Rasterise ``text`` with FONT.

    Returns ``(pixels, (width, height))`` where pixels is a list of (col, row) with
    row 0 = top. Glyphs are 3 wide with ``spacing`` empty columns between them;
    unknown characters render as a space. Height is always 5.
    """
    px = []
    cx = 0
    for ch in text:
        g = FONT.get(ch.upper(), FONT[" "])
        for r, line in enumerate(g):
            for c, v in enumerate(line):
                if v == "#":
                    px.append((cx + c, r))
        cx += 3 + spacing
    return px, (cx - spacing, 5)


# Pictograms used for road markings and signs (row 0 = top, '#' = pixel set).
# Keys are data: other modules look them up by these names.
PICTO = {
    "fiets": [
        "....##.....",
        ".....#..##.",
        "..#######..",
        ".##..#.#.#.",
        "#..#.##.#.#",
        "#..#.#..#.#",
        ".##.....##.",
    ],
    "fiets_klein": [
        "..#.#..",
        ".####..",
        "#.#.#.#",
        "##..###",
    ],
    "voetganger": [
        ".#.",
        "###",
        ".#.",
        "#.#",
    ],
    "huis": [
        "..#..",
        ".###.",
        "#####",
        ".#.#.",
        ".###.",
    ],
    "auto": [
        ".###.",
        "#####",
        "#.#.#",
    ],
    "bus": [
        "#####",
        "#.#.#",
        "#####",
        ".#.#.",
    ],
    "pijl_op": [
        "..#..",
        ".###.",
        "#.#.#",
        "..#..",
        "..#..",
    ],
    "pijl_rechts": [
        "..#..",
        "...#.",
        "#####",
        "...#.",
        "..#..",
    ],
    "uitroep": [
        "#",
        "#",
        "#",
        ".",
        "#",
    ],
}
