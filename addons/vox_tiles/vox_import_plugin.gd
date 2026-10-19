@tool
extends EditorImportPlugin
## Imports a MagicaVoxel .vox tile as an ArrayMesh. When you save a tile in
## MagicaVoxel, Godot reimports it and plugin.gd updates the GridMap library.
##
## Steps: parse the .vox (vox_parser.gd) -> apply the tile metadata
## (`<name>.tile.json`, tile_metadata.gd) -> build the mesh (vox_mesher.gd) ->
## attach two coarse versions as meta "lod" and "lod2", which library_builder.gd
## puts in the coarse libraries. A hand-made `<name>.lod.vox` replaces both.

const Parser = preload("res://addons/vox_tiles/vox_parser.gd")
const Mesher = preload("res://addons/vox_tiles/vox_mesher.gd")
const TileMetadata = preload("res://addons/vox_tiles/tile_metadata.gd")

enum AnimationMode { AUTO, NONE, WIND, FLOAT }

## Default import options; "cell_block" is added per folder (default_block).
const DEFAULTS := {
	"voxel_size": 0.125,
	"ambient_occlusion": true,
	# merge colours that differ less than this (0..255) into larger faces (fewer
	# triangles); the shader adds the per-voxel variation back on top
	"color_merge": 14,
	# colour merging of the "lod" version
	"lod_color_tolerance": 24,
	# the "lod2" version merges blocks of n x n x n voxels
	"lod2_downscale": 2,
	# colours in a texture per tile instead of the vertex colours, so faces merge by
	# shape (far fewer triangles); library_builder.gd packs the textures into an atlas
	"textured": true,
	# Auto: from the tile metadata, otherwise guessed from the file name
	"animation": AnimationMode.AUTO,
}
## colour merging of the downscaled "lod2" version
const LOD2_COLOR_TOLERANCE := 40


func _get_importer_name() -> String:
	return "zwervr.vox_tile"


func _get_visible_name() -> String:
	return "Voxel Tile (MagicaVoxel)"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["vox"])


func _get_save_extension() -> String:
	return "mesh"


func _get_resource_type() -> String:
	return "ArrayMesh"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	return "Default"


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for option in DEFAULTS:
		out.append({"name": option, "default_value": DEFAULTS[option]})
	out[-1].merge({"property_hint": PROPERTY_HINT_ENUM, "hint_string": "Auto,None,Wind,Float"})
	# size of the grid cell: triangles are grouped per cell side so hidden sides
	# against neighbouring blocks are dropped when merging (0 = don't)
	out.append({"name": "cell_block", "default_value": default_block(path)})
	return out


func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true


func _get_format_version() -> int:
	return 5


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return 0


## Not threaded: tried, but GDScript import plugins don't run in parallel in Godot
## 4.7 (the threads serialise and a full reimport became many times slower).
func _can_import_threaded() -> bool:
	return false


## Cell size of the GridMap layer a tile belongs to, from its folder.
static func default_block(path: String) -> Vector3:
	if path.contains("/tiles/gebouwen/"):
		return Vector3(4, 3, 4)
	if path.contains("/tiles/grond/"):
		return Vector3(4, 1.5, 4)
	return Vector3.ZERO


## Animation of a tile ("", "wind" or "float"): from its metadata, otherwise
## guessed from the file name (for tiles without metadata, e.g. made by hand).
static func resolve_animation(path: String, meta: Dictionary) -> String:
	var from_meta = meta.get("animation")
	if from_meta is String and from_meta in TileMetadata.ANIMATIONS:
		return "" if from_meta == "none" else from_meta
	var file := path.get_file()
	for prefix in ["sloep", "roeiboot", "reddingsboei", "woonboot", "water_lelies"]:
		if file.begins_with(prefix):
			return "float"
	if path.contains("/bomen/") or path.contains("/planten/") or path.contains("/haag") \
			or path.contains("bloembak") or path.contains("riet") and not path.contains("/daken/"):
		return "wind"
	return ""


func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var meta := TileMetadata.read(source_file)
	var vox = _load_vox(source_file, meta)
	if vox == null:
		return ERR_PARSE_ERROR
	var animation := _animation(options, source_file, meta)
	var block: Vector3 = options.get("cell_block", default_block(source_file))
	var textured: bool = _option(options, "textured")
	var mesh := Mesher.build(vox, _option(options, "voxel_size"), _option(options, "ambient_occlusion"),
		_option(options, "color_merge"), animation, block, textured)
	mesh.resource_name = source_file.get_file().get_basename()
	# a .lod.vox is only used through its tile: no coarse versions of the coarse version
	if not TileMetadata.is_lod_file(source_file):
		var err := _add_lods(mesh, vox, source_file, meta, options, animation, block, textured)
		if err != OK:
			return err
	return ResourceSaver.save(mesh, "%s.%s" % [save_path, _get_save_extension()])


## Attaches the coarse versions to the mesh as meta "lod" and "lod2".
func _add_lods(mesh: ArrayMesh, vox, source_file: String, meta: Dictionary, options: Dictionary,
		animation: String, block: Vector3, textured: bool) -> Error:
	var vs: float = _option(options, "voxel_size")
	var lod_path := TileMetadata.lod_path_for(source_file)
	if FileAccess.file_exists(lod_path):
		# hand-made coarse version for both levels; it may have a lower resolution
		# (e.g. 16x16 instead of 32x32), its voxels then get bigger
		var lod_meta := TileMetadata.read(lod_path)
		var lod_vox = _load_vox(lod_path, lod_meta if not lod_meta.is_empty() else meta)
		if lod_vox == null:
			return ERR_PARSE_ERROR
		var lod_vs := vs * float(vox.size.x) / float(maxi(lod_vox.size.x, 1))
		mesh.set_meta("lod2", _coarse(mesh, "lod", lod_vox, lod_vs, _option(options, "color_merge"), animation, block, textured))
		return OK
	# lod: similar colours merged, no AO
	var tol: int = _option(options, "lod_color_tolerance")
	if tol > 0:
		_coarse(mesh, "lod", vox, vs, tol, animation, block, textured)
	# lod2: blocks of f x f x f voxels merged into one
	var f: int = _option(options, "lod2_downscale")
	if f > 1:
		_coarse(mesh, "lod2", Mesher.downscale(vox, f), vs * f, LOD2_COLOR_TOLERANCE, animation, block, textured)
	return OK


## Builds a coarse mesh (no AO), stores it as meta `level` on the mesh and returns it.
func _coarse(mesh: ArrayMesh, level: String, vox, vs: float, tol: int, animation: String, block: Vector3, textured: bool) -> ArrayMesh:
	var lod := Mesher.build(vox, vs, false, tol, animation, block, textured)
	lod.resource_name = mesh.resource_name + "_" + level
	mesh.set_meta(level, lod)
	return lod


## Parses a .vox and applies the materials from the metadata; null on failure.
func _load_vox(path: String, meta: Dictionary):
	var vox = Parser.load_file(path)
	if vox != null:
		TileMetadata.apply_materials(vox, meta, path)
	return vox


## Animation chosen in the import options, or resolve_animation() for Auto.
func _animation(options: Dictionary, path: String, meta: Dictionary) -> String:
	match int(_option(options, "animation")):
		AnimationMode.WIND:
			return "wind"
		AnimationMode.FLOAT:
			return "float"
		AnimationMode.NONE:
			return ""
	return resolve_animation(path, meta)


## An import option, falling back to its default.
func _option(options: Dictionary, option: String) -> Variant:
	return options.get(option, DEFAULTS[option])
