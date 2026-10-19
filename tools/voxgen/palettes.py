"""MagicaVoxel palettes for making tiles by hand.

A .vox file has one palette of 255 colours, of which slots 225..232 are reserved for
water and 233..248 for flag cloth (see palette.py and the Godot importer), so only
224 ordinary colours fit while the global palette has more. The ordinary colours are
therefore split into themes, built from the section comments in palette.py
(``# --- road surface`` etc.).

For every theme write_palettes() writes, to tools/voxgen/paletten/:
- ``palet_<theme>.vox``: a colour chart (one voxel per colour, rows of 16) with the
  theme's colours first, the water and flag colours on their reserved slots and the
  remaining free slots filled with other global colours. It carries the MagicaVoxel
  materials (metal, glass, emit), so it is the template to start a new tile from.
- ``palet_<theme>.png``: the same palette as a 256 x 1 image (pixel k = slot k + 1,
  the last pixel unused), for MagicaVoxel's palette import.
- ``palet_<theme>.md``: legend: slot, colour, name and material of every slot.
The folder has a .gdignore so Godot doesn't import the charts as tiles.
"""
import os
import re
import struct
import zlib

from palette import P, PALETTE, MATERIALS
from vox import V, write_vox, _read_vox_palette, _material_at

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "paletten")

# theme -> palette.py sections (in this order); water and flags are always included
THEMES = {
    "straat": ["road surface", "sidewalk / paving", "nature", "rail", "metal / street furniture",
               "trees / plants", "signs", "lighting", "textiles / awnings / vehicles"],
    "gebouwen": ["facades", "roofs", "doors / details",
                 "extension: 1930s / 60s / 80s / 2000s styles, churches, sheds, hospitality",
                 "lighting", "metal / street furniture", "signs", "textiles / awnings / vehicles"],
}
COLUMNS = 16
# material tag in palette.py -> material name in Godot / the tile metadata
_TAG_TO_META = {None: "opaque", "paneel": "panel"}
for _tag in ("metal", "glass", "emit", "water", "flag", "asphalt", "stone", "brick", "gravel", "painted",
             "paving", "cobble", "plaster"):
    _TAG_TO_META[_tag] = _tag


def sections():
    """Section title -> colour names in order, read from the comments in palette.py."""
    src = open(os.path.join(HERE, "palette.py")).read()
    block = src[src.index("_ENTRIES = ["):src.index("\n]\n", src.index("_ENTRIES = ["))]
    out, current = {}, None
    for line in block.splitlines():
        m = re.match(r"\s*# ---\s*(.*)", line)
        if m:
            current = out.setdefault(m.group(1).strip(), [])
        elif current is not None:
            current.extend(re.findall(r'\("([a-z0-9_]+)",', line))
    return out


def theme_colours(theme):
    """Global colour ids of a theme: its sections' colours, then water and flags."""
    by_section = sections()
    names = []
    for s in THEMES[theme]:
        names += [n for n in by_section[s] if n not in names]
    ids = [P[n] for n in names if n in P]
    special = [g for g in PALETTE if MATERIALS.get(g) in ("water", "flag")]
    return ids + special


def colour_chart(ids):
    """Model with one voxel per colour, in rows of COLUMNS (front row first)."""
    rows = (len(ids) + COLUMNS - 1) // COLUMNS
    m = V(COLUMNS, rows, 1)
    for k, g in enumerate(ids):
        m.set(k % COLUMNS, k // COLUMNS, 0, g)
    return m


def _png(path, pixels):
    """Write an RGB PNG of len(pixels) x 1 (pixels = [(r, g, b)])."""
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    raw = b"\x00" + bytes(c for p in pixels for c in p)
    data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", len(pixels), 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(data)


def _rgba_slots(path):
    """All 255 palette slots of a .vox: slot -> (r, g, b)."""
    data = open(path, "rb").read()
    i = data.index(b"RGBA") + 12
    return {s: tuple(data[i + (s - 1) * 4:i + (s - 1) * 4 + 3]) for s in range(1, 256)}


def legend(vox_path):
    """[(slot, (r, g, b), names, material)] for the used slots of a palette .vox."""
    names = {g: n for n, g in P.items()}
    by_rgb = {}
    for g, rgb in PALETTE.items():
        by_rgb.setdefault(rgb, []).append(names[g])
    rows = []
    for s, (rgb, matl) in sorted(_read_vox_palette(vox_path).items()):
        mat = _material_at(s, rgb, matl) or "opaque"
        # an rgb shared by several colours (e.g. a flag and a sign colour, or plain and
        # metal anthracite): show the names whose material applies to this slot
        candidates = by_rgb.get(rgb, ["?"])
        own = [n for n in candidates if _TAG_TO_META.get(MATERIALS.get(P.get(n)), "opaque") == mat] or candidates
        rows.append((s, rgb, own, mat))
    return rows


def write_palettes(out_dir=OUT):
    """Write the chart, PNG and legend of every theme; returns the written .vox paths."""
    os.makedirs(out_dir, exist_ok=True)
    open(os.path.join(out_dir, ".gdignore"), "w").close()
    written = []
    for theme in THEMES:
        base = os.path.join(out_dir, "palet_" + theme)
        write_vox(base + ".vox", colour_chart(theme_colours(theme)))
        slots = _rgba_slots(base + ".vox")
        _png(base + ".png", [slots[s] for s in range(1, 256)] + [(0, 0, 0)])
        lines = [f"# Palet '{theme}'", "",
                 "Paletnummer (zoals MagicaVoxel het toont), kleur, naam en materiaal in Godot.", "",
                 "| nr | kleur | naam | materiaal |", "|---:|---|---|---|"]
        for s, rgb, names, mat in legend(base + ".vox"):
            lines.append(f"| {s} | `#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}` | {', '.join(names)} | {mat} |")
        open(base + ".md", "w").write("\n".join(lines) + "\n")
        written.append(base + ".vox")
    return written
