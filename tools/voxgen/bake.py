"""How a tile is baked and casts its shadow: the "bake" block of its .tile.json, collected per
item name in the library's meta "bake" (library_builder.gd) and read by the library itself
and by scripts/world/layer_baker.gd. The block (every key is optional):

    shadow         true/false: casts a shadow or not; left out = by its height
                   (SHADOW_MIN_HEIGHT in library_builder.gd).
    merge          true: bake a flag into the chunks too; false: this tile stays a separate
                   mesh. Left out = merged, unless its shader cannot be (wind, floating, flag).
    building_part  false: a detail that doesn't fade with the building it is next to.

The rules go by folder; the first rule of a folder whose base name matches wins."""
import os


# what lies flat on a facade casts no shadow of its own (the building's filled shadow covers it)
FLAT = {"shadow": False}
# what sticks out keeps the shadow its height gives it
STICKS_OUT = {}

_RULES = {
    "details/balkons": [(["*"], STICKS_OUT)],
    "details/dak": [(["*"], STICKS_OUT)],
    "details/luifels": [(["*"], STICKS_OUT)],
    "details/zonwering": [(["knikarmscherm*", "markies*", "uitvalscherm*"], STICKS_OUT), (["*"], FLAT)],
    "details/deuren": [(["bordes*"], STICKS_OUT), (["*"], FLAT)],
    "details/gevel": [
        (["vlag*"], {"shadow": True, "merge": True}),
        (["hijsbalk*", "reclamebord*", "uithangbord*"], STICKS_OUT),
        (["*"], FLAT),
    ],
}


def _matches(base, pattern):
    return base.startswith(pattern[:-1]) if pattern.endswith("*") else base == pattern


def tile_bake(name):
    """The "bake" metadata of tile path ``name`` (e.g. 'details/gevel/vlag'), or None."""
    folder, base = os.path.dirname(name), os.path.basename(name)
    if not name.startswith("details/"):
        return None
    # the top folder under details decides
    rules = _RULES.get("/".join(folder.split("/")[:2]), [(["*"], FLAT)])
    for patterns, bake in rules:
        if any(_matches(base, pattern) for pattern in patterns):
            return dict(bake) or None
    return None
