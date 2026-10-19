@tool
extends RefCounted
## The files that belong to a tile besides its `<name>.vox`:
##
## - `<name>.tile.json`: settings MagicaVoxel can't store.
##
##       {
##           "id": 120,
##           "animation": "float",
##           "materials": {"225": "water", "#3a3a3e": "asphalt"}
##       }
##
##   id: pins the MeshLibrary item id (library_builder.gd); left out = assigned automatically.
##   animation: "none", "wind" (trees, plants) or "float" (bobs on the water);
##     left out = guessed from the file name (vox_import_plugin.gd).
##   materials: palette index (as shown in MagicaVoxel) or "#rrggbb" colour -> one of
##     Parser.MATERIAL_NAMES. Colours not listed keep the material set in MagicaVoxel.
##   slopes: slope shapes made of the tile while importing it (slopes.gd), e.g.
##     ["steil", "flauw_a", "flauw_b"]; each becomes an item grond/helling/... .
##   curve: [i, j, parts] of a flat curve cell, for the curve shapes (slopes.gd).
##   smooth: {"shape": "steil", "lift": 2, "keep_x": [0, 1]}: the tile is the padded block
##     of a slope; the importer moves it onto the smooth slope (slopes.gd own_plan()).
##
##   An alias tile has only this file, no .vox: {"id": 121, "same_as": "weg/weg_vlak"}.
##   same_as: another tile of the same category (path below assets/tiles/<category>);
##     the alias gets its own item (name and id) with that tile's mesh
##     (library_builder.gd). tools/voxgen/dedupe.py turns identical tiles into aliases.
##
## - `<name>.lod.vox`: a hand-made coarse version, used instead of the automatic LOD
##   versions. It is not a tile of its own. It may have its own `<name>.lod.tile.json`;
##   otherwise the tile's materials are applied to it.
##
## Godot only watches the .vox itself; plugin.gd reimports a tile when one of these
## files is saved in the editor.

const Parser = preload("res://addons/vox_tiles/vox_parser.gd")

const ANIMATIONS := ["none", "wind", "float"]


## `huis.vox` -> `huis.tile.json`
static func path_for(vox_path: String) -> String:
	return vox_path.get_basename() + ".tile.json"


## `huis.vox` -> `huis.lod.vox`
static func lod_path_for(vox_path: String) -> String:
	return vox_path.get_basename() + ".lod.vox"


## True for `<name>.lod.vox`: a coarse version, not a tile of its own.
static func is_lod_file(path: String) -> bool:
	return path.get_extension() == "vox" and path.get_basename().get_extension() == "lod"


## All side files of a tile whose changes require reimporting it (they may not exist).
static func side_files(vox_path: String) -> Array[String]:
	var lod := lod_path_for(vox_path)
	return [path_for(vox_path), lod, path_for(lod)]


## Returns the metadata of a tile, or an empty Dictionary if there is none.
static func read(vox_path: String) -> Dictionary:
	var path := path_for(vox_path)
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
static func store_id(vox_path: String, id: int) -> void:
	var meta := read(vox_path)
	if meta.has("id"):
		return
	var out := {"id": id}
	out.merge(meta)
	var f := FileAccess.open(path_for(vox_path), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t", false) + "\n")


## Overrides the materials of a parsed vox with those from the metadata.
## vox_path is only used in warnings.
static func apply_materials(vox, meta: Dictionary, vox_path := "") -> void:
	var mats = meta.get("materials", {})
	if not mats is Dictionary:
		return
	for key in mats:
		var mat := Parser.MATERIAL_NAMES.find(str(mats[key]))
		if mat < 0:
			push_warning("vox: %s: unknown material '%s' (use %s)" % [path_for(vox_path), mats[key], ", ".join(Parser.MATERIAL_NAMES)])
			continue
		for i in _palette_indices(vox, str(key)):
			vox.materials[i] = mat


## Palette indices a metadata key refers to: one index ("225") or every index
## with that colour ("#3a3a3e").
static func _palette_indices(vox, key: String) -> Array[int]:
	var out: Array[int] = []
	if key.begins_with("#"):
		var html := Color.html(key).to_html(false)
		for i in range(1, 256):
			if vox.palette[i].to_html(false) == html:
				out.append(i)
	elif key.is_valid_int() and int(key) >= 1 and int(key) <= 255:
		out.append(int(key))
	return out
