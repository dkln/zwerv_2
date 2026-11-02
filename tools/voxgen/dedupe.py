"""Replace identical tiles by aliases.

Two tiles of the same category are identical when their .gox files hold the same
voxels with the same colours and materials (colour table, material layers and
.tile.json "materials"), and they import with the same animation, slopes and import
options. Of every group of identical tiles the one with the shortest path (then
alphabetical) keeps its .gox; the others become alias tiles: only a
``<name>.tile.json`` with ``{"id": <their id>, "same_as": "<path of the kept tile>"}``
(path within the category, like the MeshLibrary item names). The library builder
(addons/vox_tiles/library/library_builder.gd) gives an alias its own item (same name and id
as before, so maps keep working) with the mesh of the kept tile. Tiles saved as .vox
(made by hand in MagicaVoxel) are left alone.

An alias follows its tile: to make it different again, delete its .tile.json and
regenerate it (or save a .gox under its name).
"""
import hashlib
import json
import os

from gox import read_gox
from vox import tile_animation, material_table, MATERIAL_NAMES
from traffic import tile_traffic

# Extensions of a tile model, in the order the Godot importer prefers them
TILE_EXTENSIONS = (".gox", ".vox")

_TABLE = None


def _import_params(tile_path):
    """The [params] section of the tile's .import (import options), as text. A tile
    that was not imported yet gets the options of another tile in its folder (the
    defaults of the folder: Godot writes the .import on the first import)."""
    path = tile_path + ".import"
    if not os.path.exists(path):
        folder = os.path.dirname(tile_path)
        others = sorted(f for f in os.listdir(folder) if f.endswith(".gox.import"))
        if not others:
            return ""
        path = os.path.join(folder, others[0])
    text = open(path).read()
    return text[text.find("[params]"):]


def signature(gox_path, name):
    """Hash of everything that ends up in the imported mesh of tile ``name``."""
    global _TABLE
    if _TABLE is None:
        _TABLE = material_table()
    meta_path = os.path.splitext(gox_path)[0] + ".tile.json"
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    overrides = meta.get("materials", {}) if isinstance(meta.get("materials"), dict) else {}
    model = read_gox(gox_path, MATERIAL_NAMES)
    rows = []
    for (x, y, z), (rgb, forced) in model.voxels.items():
        key = "#%02x%02x%02x" % rgb
        mat = overrides.get(key) or forced or _TABLE.get(key, "opaque")
        rows.append(f"{x},{y},{z},{key},{mat}")
    rows.sort()
    h = hashlib.sha1()
    for part in (repr(model.size), "\n".join(rows), repr(meta.get("animation", tile_animation(name))),
                 repr(meta.get("slopes")), repr(meta.get("curve")), repr(meta.get("smooth")),
                 _import_params(gox_path)):
        h.update(part.encode())
        h.update(b"\0")
    return h.hexdigest()


def dedupe(out_dir, dry_run=False):
    """Turn every identical tile below ``out_dir`` into an alias of the shortest name
    of its group (see the module docstring). Returns [(alias, kept)] tile paths."""
    groups = {}   # (category, signature) -> [tile path]
    for folder, _, files in os.walk(out_dir):
        for f in sorted(files):
            if f.endswith(".gox") and not f.endswith(".lod.gox"):
                name = os.path.relpath(os.path.join(folder, f), out_dir)[:-4].replace(os.sep, "/")
                if any(os.path.exists(os.path.join(out_dir, name + ".lod" + e)) for e in TILE_EXTENSIONS):
                    continue   # a hand-made coarse version makes the tile unique
                key = (name.partition("/")[0], signature(os.path.join(out_dir, name + ".gox"), name))
                groups.setdefault(key, []).append(name)
    out = []
    for (cat, _), names in sorted(groups.items()):
        names.sort(key=lambda n: (len(n), n))
        kept = names[0]
        for name in names[1:]:
            out.append((name, kept))
            if dry_run:
                continue
            base = os.path.join(out_dir, name)
            meta = json.load(open(base + ".tile.json")) if os.path.exists(base + ".tile.json") else {}
            alias = {"id": meta["id"]} if "id" in meta else {}
            alias["same_as"] = kept.partition("/")[2]
            traffic = tile_traffic(name)
            if traffic:
                alias["traffic"] = traffic    # its own: the same model can be a different road
            with open(base + ".tile.json", "w") as fh:
                fh.write(json.dumps(alias, indent="\t") + "\n")
            for ext in (".gox", ".gox.import"):
                if os.path.exists(base + ext):
                    os.remove(base + ext)
    if not dry_run:
        _resolve_chains(out_dir)
    return out


def _resolve_chains(out_dir):
    """Point aliases of aliases at the tile that has the model (the library builder only
    follows one step)."""
    aliases = {}   # tile path -> (category, same_as path within the category)
    for folder, _, files in os.walk(out_dir):
        for f in files:
            if f.endswith(".tile.json"):
                name = os.path.relpath(os.path.join(folder, f), out_dir)[:-len(".tile.json")].replace(os.sep, "/")
                if is_alias(out_dir, name):
                    cat = name.partition("/")[0]
                    aliases[name] = (cat, json.load(open(os.path.join(out_dir, name + ".tile.json")))["same_as"])
    for name, (cat, target) in aliases.items():
        final, seen = target, set()
        while f"{cat}/{final}" in aliases and final not in seen:
            seen.add(final)
            final = aliases[f"{cat}/{final}"][1]
        if final != target:
            path = os.path.join(out_dir, name + ".tile.json")
            meta = json.load(open(path))
            meta["same_as"] = final
            with open(path, "w") as fh:
                fh.write(json.dumps(meta, indent="\t") + "\n")


def write_alias_traffic(out_dir, name):
    """Brings the "traffic" of alias tile ``name`` up to date (traffic.tile_traffic): an
    alias shares the model of its tile, not its lanes. Returns True if it has traffic."""
    path = os.path.join(out_dir, name + ".tile.json")
    old = open(path).read()
    meta = json.loads(old)
    traffic = tile_traffic(name)
    if traffic:
        meta["traffic"] = traffic
    else:
        meta.pop("traffic", None)
    text = json.dumps(meta, indent="\t") + "\n"
    if text != old:
        with open(path, "w") as fh:
            fh.write(text)
    return traffic is not None


def is_alias(out_dir, name):
    """True if tile ``name`` is an alias (a .tile.json with "same_as", no model file)."""
    base = os.path.join(out_dir, name)
    if any(os.path.exists(base + e) for e in TILE_EXTENSIONS) or not os.path.exists(base + ".tile.json"):
        return False
    try:
        return "same_as" in json.load(open(base + ".tile.json"))
    except ValueError:
        return False
