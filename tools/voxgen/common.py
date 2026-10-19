"""Shared constants, the tile registry and small bitmap fonts / pictograms.

Every tile module registers its tile functions here, either with the ``@tile(path)``
decorator or with ``register(path, fn)``. ``generate.py`` imports all tile modules
(which fills ``TILES``) and then calls each function to build the model and write
``<OUT>/<path>.vox`` plus its ``.tile.json`` metadata.

Sizes are in voxels of 12.5 cm; coordinates follow MagicaVoxel (x = left->right,
y = front->back, z = up; the front of a tile is the y=0 side).
"""

TILES = {}  # tile path (without .vox) -> function returning a vox.V model

T = 32          # ground tile width in voxels (4 m at 0.125 m/voxel)
ROAD = 2        # top of the road surface (z)
WALK = 3        # top of sidewalk / grass (z)
FLOOR = 8       # height of one ground layer (1 m)
STOREY = 24     # height of one building storey (3 m)


def register(path, fn):
    """Register ``fn`` (no-argument callable returning a V) as the builder for tile ``path``."""
    TILES[path] = fn


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
