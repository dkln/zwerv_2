@tool
extends RefCounted
## The files that belong to a tile besides its model `<name>.gox` (or `<name>.vox`):
##
## - `<name>.tile.json`: settings the model file can't store.
##
##       {
##           "id": 120,
##           "animation": "float",
##           "materials": {"#3a3a3e": "asphalt"}
##       }
##
##   id: pins the MeshLibrary item id (library_builder.gd); left out = assigned automatically.
##   animation: "none", "wind" (trees, plants), "flowers" (flower beds, flowers: sway
##              just above the ground) or "float" (bobs on the water);
##     left out = guessed from the file name (vox_import_plugin.gd).
##   materials: "#rrggbb" colour -> one of Model.MATERIAL_NAMES, for this tile only
##     (for a .vox also a palette index). It beats the colour table and material
##     layers (voxel_model.gd), so it is only needed for exceptions.
##   slopes: slope shapes made of the tile while importing it (slopes.gd), e.g.
##     ["steil", "flauw_a", "flauw_b"]; each becomes an item in the subfolder helling of its category.
##   curve: [i, j, parts] of a flat curve cell, for the curve shapes (slopes.gd).
##   smooth: {"shape": "steil", "lift": 2, "keep_x": [0, 1]}: the tile is the padded block
##     of a slope; the importer moves it onto the smooth slope (slopes.gd own_plan()).
##
##   traffic: {"lanes": ["N"], "road": "straat", "rise": 1.0, "only": ["bus"]}: the lanes
##     vehicles drive on a ground tile, relative to the tile as it lies unturned ("N" =
##     towards its back; both headings of an axis = decided by the road around it), the
##     kind of road (speed limit), how far a ramp rises towards its back (metres) and
##     which vehicle kinds may use it. Written by tools/voxgen/traffic.py, collected per
##     item name in the library's meta "traffic" (library_builder.gd) and read by
##     scripts/world/road_network.gd.
##
##   platform: ["tram", "trein"]: the kinds of rail vehicle that stop beside this ground tile
##     and open their doors there. Written by tools/voxgen/traffic.py, collected per item name
##     in the library's meta "platforms" and read by scripts/world/road_network.gd.
##
##   bake: {"shadow": false, "merge": true, "building_part": false}, every key optional: casts
##     a shadow or not (left out = by its height), bake it into the chunks (true also for a
##     flag) or leave it a separate mesh (false; left out = merged unless its shader cannot
##     be), and whether a detail fades with the building beside it (left out = yes). Written
##     by tools/voxgen/bake.py, collected per item name in the library's meta "bake"
##     (library_builder.gd) and read by scripts/world/layer_baker.gd.
##
##   An alias tile has only this file, no model: {"id": 121, "same_as": "weg/weg_vlak"}.
##   same_as: another tile of the same category (path below assets/tiles/<category>);
##     the alias gets its own item (name and id) with that tile's mesh
##     (library_builder.gd). tools/voxgen/dedupe.py turns identical tiles into aliases.
##
## - `<name>.lod.gox` (or `.lod.vox`): a hand-made coarse version, used instead of the
##   automatic LOD versions. It is not a tile of its own. It may have its own
##   `<name>.lod.tile.json`; otherwise the tile's metadata is applied to it.
##
## - the colour table `assets/tiles/materialen.json` (voxel_model.gd COLOUR_TABLE),
##   shared by all tiles.
##
## Godot only watches the model itself; plugin.gd reimports a tile when one of these
## files is saved. "traffic" needs no reimport: the library build reads it.

const Model = preload("res://addons/vox_tiles/importer/voxel_model.gd")

const ANIMATIONS := ["none", "wind", "flowers", "float"]


## `huis.gox` -> `huis.tile.json`
static func path_for(model_path: String) -> String:
	return model_path.get_basename() + ".tile.json"


## `huis.gox` -> `huis.lod.gox`, or `huis.lod.vox` if only that exists.
static func lod_path_for(model_path: String) -> String:
	var base := model_path.get_basename() + ".lod."
	for ext in Model.EXTENSIONS:
		if FileAccess.file_exists(base + ext):
			return base + ext
	return base + Model.EXTENSIONS[0]


## True for `<name>.lod.gox` / `<name>.lod.vox`: a coarse version, not a tile of its own.
static func is_lod_file(path: String) -> bool:
	return Model.is_model_file(path) and path.get_basename().get_extension() == "lod"


## The model file of tile `base` (a path without extension), or "" if it has none.
static func model_path(base: String) -> String:
	for ext in Model.EXTENSIONS:
		if FileAccess.file_exists(base + "." + ext):
			return base + "." + ext
	return ""


## All side files of a tile whose changes require reimporting it (they may not exist).
static func side_files(path: String) -> Array[String]:
	var base := path.get_basename()
	var out: Array[String] = [path_for(path), base + ".lod.tile.json", Model.COLOUR_TABLE]
	for ext in Model.EXTENSIONS:
		out.append(base + ".lod." + ext)
	return out


## Returns the metadata of a tile, or an empty Dictionary if there is none.
static func read(model_path: String) -> Dictionary:
	var path := path_for(model_path)
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("vox: %s is not a valid JSON object, ignored" % path)
		return {}
	var animation = data.get("animation")
	if animation != null and not animation in ANIMATIONS:
		push_warning("vox: %s: unknown animation '%s' (use %s)" % [path, animation, ", ".join(ANIMATIONS)])
	return data


## Records the item id in the metadata if it has none yet (creates the file if
## needed), so every tile shows its id. Keeps everything else as it is.
static func store_id(model_path: String, id: int) -> void:
	var meta := read(model_path)
	if meta.has("id"):
		return
	var out := {"id": id}
	out.merge(meta)
	var f := FileAccess.open(path_for(model_path), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t", false) + "\n")
