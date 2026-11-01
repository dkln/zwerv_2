"""Goxel palette, colour chart and legend for making tiles by hand.

A .gox stores the colour of every voxel; there is no palette in the file and no
limit on the number of colours. The material of a voxel follows from its colour
(assets/tiles/materialen.json), so a tile should use the exact palette colours.
write_palettes() writes, to tools/voxgen/paletten/:
- ``zwervr.gpl``: all colours as a GIMP palette with name and material. Copy it to
  Goxel's palette folder (Goxel shows the folder under Settings, "Palettes: ...")
  and pick the palette "Zwervr" in the colour panel.
- ``palet.gox``: a colour chart (one voxel per colour, one row per section of
  palette.py, front row first) to start a tile from or pick colours with.
- ``palet.md``: legend: section, colour, name and material of every colour.
The folder has a .gdignore so Godot doesn't import the chart as a tile.
"""
import os
import re

from palette import P, PALETTE, ORDER, godot_material
from vox import V, write_tile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "paletten")

# material -> (label, short Dutch explanation), for the palette names, the legend and the handbook
MATERIAL_LABELS = {
    "opaque": ("mat", "gewone, matte kleur"),
    "metal": ("metaal", "metaal"),
    "panel": ("paneel", "spiegelend metaal, zonnepanelen"),
    "glass": ("glas", "doorzichtig glas"),
    "water": ("water", "golvend, spiegelend water"),
    "emit": ("licht", "lichtgevend, vooral 's nachts"),
    "flag": ("vlag", "wapperend doek"),
    "asphalt": ("asfalt", "korrel, slijtplekken en glans"),
    "stone": ("steen", "tegels, keien, natuursteen, beton"),
    "brick": ("baksteen", "metselwerk"),
    "gravel": ("grind", "kleine ronde steentjes"),
    "painted": ("gelakt", "gelakt metaal: palen, borden"),
    "paving": ("tegels", "stoeptegels van 3 x 3 voxels met voegen"),
    "cobble": ("keien", "bolle keien met voegen"),
    "plaster": ("stuc", "stucwerk met haarscheurtjes en putjes"),
}
# Dutch section titles for the legend (keys: the "# ---" comments in palette.py)
SECTION_TITLES = {
    "road surface": "Wegdek",
    "sidewalk / paving": "Stoep en bestrating",
    "nature": "Natuur",
    "rail": "Spoor",
    "facades": "Gevels",
    "roofs": "Daken",
    "doors / details": "Deuren en details",
    "metal / street furniture": "Metaal en straatmeubilair",
    "trees / plants": "Bomen en planten",
    "signs": "Borden",
    "lighting": "Verlichting",
    "textiles / awnings / vehicles": "Stof, luifels en voertuigen",
    "extension: 1930s / 60s / 80s / 2000s styles, churches, sheds, hospitality": "Jaren 30 tot 2000, kerken, schuren, horeca",
    "water": "Water",
    "flags": "Vlaggen",
}


def sections():
    """Section title -> colour names in order, read from the comments in palette.py;
    the water and flag colours come last as sections "water" and "flags"."""
    src = open(os.path.join(HERE, "palette.py")).read()
    block = src[src.index("_ENTRIES = ["):src.index("\n]\n", src.index("_ENTRIES = ["))]
    out, current = {}, None
    for line in block.splitlines():
        m = re.match(r"\s*# ---\s*(.*)", line)
        if m:
            current = out.setdefault(m.group(1).strip(), [])
        elif current is not None:
            current.extend(re.findall(r'\("([a-z0-9_]+)",', line))
    for title, var in (("water", "_WATER"), ("flags", "_FLAG")):
        start = src.index(var + " = [")
        out[title] = re.findall(r'\("([a-z0-9_]+)",', src[start:src.index("\n]\n", start)])
    return out


def legend():
    """[(section, global id, names, (r, g, b), material)]: every palette colour once,
    in palette order per section. Members of a flat group share one id (and colour),
    so they are listed together."""
    names = {}
    for n, g in P.items():
        names.setdefault(g, []).append(n)
    rows, seen = [], set()
    for section, members in sections().items():
        for n in members:
            g = P.get(n)
            if g is None or g in seen:
                continue
            seen.add(g)
            rows.append((section, g, names[g], PALETTE[g], godot_material(g)))
    for g in ORDER:   # colours outside the sections (none today)
        if g not in seen:
            rows.append(("", g, names[g], PALETTE[g], godot_material(g)))
    return rows


def colour_chart(rows):
    """Model with one voxel per colour: one row (y) per section, a gap between rows."""
    by_section = {}
    for section, g, _, _, _ in rows:
        by_section.setdefault(section, []).append(g)
    width = max(len(v) for v in by_section.values())
    m = V(width, 2 * len(by_section) - 1, 1)
    for y, ids in enumerate(by_section.values()):
        for x, g in enumerate(ids):
            m.set(x, 2 * y, 0, g)
    return m


def _label(names, mat):
    """Palette entry name: colour names plus the material; Goxel reads at most 127 bytes."""
    text = ", ".join(names)
    text = text if mat == "opaque" else f"{text} ({MATERIAL_LABELS[mat][0]})"
    return text[:100]


def write_palettes(out_dir=OUT):
    """Write zwervr.gpl, palet.gox and palet.md (removing the old MagicaVoxel
    templates); returns the written paths."""
    os.makedirs(out_dir, exist_ok=True)
    open(os.path.join(out_dir, ".gdignore"), "w").close()
    for f in os.listdir(out_dir):
        if f.startswith("palet_") and f.endswith((".vox", ".png", ".md")):
            os.remove(os.path.join(out_dir, f))
    rows = legend()
    gpl = os.path.join(out_dir, "zwervr.gpl")
    lines = ["GIMP Palette", "Name: Zwervr", "Columns: 16", "#"]
    for _, _, names, rgb, mat in rows:
        lines.append(f"{rgb[0]:3d} {rgb[1]:3d} {rgb[2]:3d} {_label(names, mat)}")
    open(gpl, "w").write("\n".join(lines) + "\n")
    chart = os.path.join(out_dir, "palet.gox")
    write_tile(chart, colour_chart(rows))
    md = os.path.join(out_dir, "palet.md")
    lines = ["# Palet van Zwervr", "",
             "Alle kleuren met naam en het materiaal dat ze in Godot krijgen. Het materiaal hoort",
             "bij de kleur (`assets/tiles/materialen.json`), dus gebruik precies deze kleuren.", ""]
    current = None
    for section, _, names, rgb, mat in rows:
        if section != current:
            current = section
            lines += ["", f"## {SECTION_TITLES.get(section, section)}", "",
                      "| kleur | naam | materiaal |", "|---|---|---|"]
        lines.append(f"| `#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}` | {', '.join(names)} | {MATERIAL_LABELS[mat][0]} |")
    open(md, "w").write("\n".join(lines) + "\n")
    return [gpl, chart, md]
