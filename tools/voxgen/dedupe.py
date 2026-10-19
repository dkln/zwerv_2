"""Replace identical tiles by aliases.

Two tiles of the same category are identical when their .vox files hold the same
voxels with the same colours and materials (MATL and .tile.json "materials"), and
they import with the same animation, slopes and import options. Of every group of identical
tiles the one with the shortest path (then alphabetical) keeps its .vox; the others
become alias tiles: only a ``<name>.tile.json`` with ``{"id": <their id>, "same_as": "<path of the kept tile>"}``
(path within the category, like the MeshLibrary item names). The library builder
(addons/vox_tiles/library_builder.gd) gives an alias its own item (same name and id
as before, so maps keep working) with the mesh of the kept tile.

An alias follows its tile: to make it different again, delete its .tile.json and
regenerate it (or save a .vox under its name).
"""
import hashlib
import json
import os
import struct

from vox import _read_dict, tile_animation


def _chunks(data):
    """(id, body) of every chunk of a .vox file, MAIN's children inlined."""
    pos = 8
    while pos + 12 <= len(data):
        cid = data[pos:pos + 4]
        content, children = struct.unpack("<ii", data[pos + 4:pos + 12])
        if cid == b"MAIN":
            pos += 12
            continue
        yield cid, data[pos + 12:pos + 12 + content]
        pos += 12 + content + children


def _slot_material(meta, slot, rgb):
    """The .tile.json material of a palette slot (by index or "#rrggbb"), or None."""
    mats = meta.get("materials", {})
    return mats.get(str(slot)) or mats.get("#%02x%02x%02x" % rgb)


def _import_params(vox_path):
    """The [params] section of the tile's .vox.import (import options), as text. A tile
    that was not imported yet gets the options of another tile in its folder (the
    defaults of the folder: Godot writes the .import on the first import)."""
    path = vox_path + ".import"
    if not os.path.exists(path):
        folder = os.path.dirname(vox_path)
        others = sorted(f for f in os.listdir(folder) if f.endswith(".vox.import"))
        if not others:
            return ""
        path = os.path.join(folder, others[0])
    text = open(path).read()
    return text[text.find("[params]"):]


def signature(vox_path, name):
    """Hash of everything that ends up in the imported mesh of tile ``name``."""
    meta_path = os.path.splitext(vox_path)[0] + ".tile.json"
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    size, xyzi, rgba, matl = b"", b"", None, {}
    for cid, body in _chunks(open(vox_path, "rb").read()):
        if cid == b"SIZE" and not size:   # first model only
            size = body
        elif cid == b"XYZI" and not xyzi:
            xyzi = body[4:]
        elif cid == b"RGBA":
            rgba = body
        elif cid == b"MATL":
            matl[struct.unpack("<i", body[:4])[0]] = _read_dict(body, 4)
    # describe every used slot by what it looks like, so palette order doesn't matter
    used = sorted(set(xyzi[3::4]))
    desc = {}
    for s in used:
        rgb = tuple(rgba[(s - 1) * 4:(s - 1) * 4 + 3]) if rgba else (s,)
        desc[s] = repr((rgb, sorted(matl.get(s, {}).items()), _slot_material(meta, s, rgb) if rgba else None))
    order = sorted(set(desc.values()))
    table = bytearray(range(256))
    for s in used:
        table[s] = order.index(desc[s])
    voxels = xyzi.translate(bytes(table))
    voxels = b"".join(sorted(voxels[i:i + 4] for i in range(0, len(voxels), 4)))
    h = hashlib.sha1()
    for part in (size, voxels, repr(order), repr(meta.get("animation", tile_animation(name))), repr(meta.get("slopes")), repr(meta.get("curve")),
                 repr(meta.get("smooth")),
                 _import_params(vox_path)):
        h.update(part if isinstance(part, bytes) else part.encode())
        h.update(b"\0")
    return h.hexdigest()


def dedupe(out_dir, dry_run=False):
    """Turn every identical tile below ``out_dir`` into an alias of the shortest name
    of its group (see the module docstring). Returns [(alias, kept)] tile paths."""
    groups = {}   # (category, signature) -> [tile path]
    for folder, _, files in os.walk(out_dir):
        for f in sorted(files):
            if f.endswith(".vox") and not f.endswith(".lod.vox"):
                name = os.path.relpath(os.path.join(folder, f), out_dir)[:-4].replace(os.sep, "/")
                if os.path.exists(os.path.join(out_dir, name + ".lod.vox")):
                    continue   # a hand-made coarse version makes the tile unique
                key = (name.partition("/")[0], signature(os.path.join(out_dir, name + ".vox"), name))
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
            with open(base + ".tile.json", "w") as fh:
                fh.write(json.dumps(alias, indent="\t") + "\n")
            for ext in (".vox", ".vox.import"):
                if os.path.exists(base + ext):
                    os.remove(base + ext)
    if not dry_run:
        _resolve_chains(out_dir)
    return out


def _resolve_chains(out_dir):
    """Point aliases of aliases at the tile that has the .vox (the library builder only
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


def is_alias(out_dir, name):
    """True if tile ``name`` is an alias (a .tile.json with "same_as", no .vox)."""
    base = os.path.join(out_dir, name)
    if os.path.exists(base + ".vox") or not os.path.exists(base + ".tile.json"):
        return False
    try:
        return "same_as" in json.load(open(base + ".tile.json"))
    except ValueError:
        return False
