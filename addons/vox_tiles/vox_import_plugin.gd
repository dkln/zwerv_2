@tool
extends EditorImportPlugin
## Importeert .vox bestanden als ArrayMesh. Wijzig je een tile in MagicaVoxel en
## sla je hem op, dan importeert Godot hem automatisch opnieuw.

const Parser = preload("res://addons/vox_tiles/vox_parser.gd")
const Mesher = preload("res://addons/vox_tiles/vox_mesher.gd")


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
	return [
		{"name": "voxel_size", "default_value": 0.125},
		{"name": "ambient_occlusion", "default_value": true},
		{"name": "lod_kleur_tolerantie", "default_value": 24},
		{"name": "lod2_verkleining", "default_value": 2},
		# bomen en planten bewegen in de wind
		{"name": "wind", "default_value": path.contains("/bomen/") or path.contains("/planten/")},
	]


func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return 0


func _can_import_threaded() -> bool:
	return false


func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var vox = Parser.load_file(source_file)
	if vox == null:
		return ERR_PARSE_ERROR
	var vs: float = options.get("voxel_size", 0.125)
	var wind: bool = options.get("wind", false)
	var mesh := Mesher.build(vox, vs, options.get("ambient_occlusion", true), 0, wind)
	mesh.resource_name = source_file.get_file().get_basename()
	# grove versie voor als je ver uitzoomt: gelijkende kleuren samengevoegd, geen AO
	var tol: int = options.get("lod_kleur_tolerantie", 24)
	if tol > 0:
		var lod := Mesher.build(vox, vs, false, tol, wind)
		lod.resource_name = mesh.resource_name + "_lod"
		mesh.set_meta("lod", lod)
	# heel grove versie voor de verste zoom: blokjes van f x f x f voxels samengevoegd
	var f: int = options.get("lod2_verkleining", 2)
	if f > 1:
		var klein = Mesher.verklein(vox, f)
		var lod2 := Mesher.build(klein, vs * f, false, 40, wind)
		lod2.resource_name = mesh.resource_name + "_lod2"
		mesh.set_meta("lod2", lod2)
	return ResourceSaver.save(mesh, "%s.%s" % [save_path, _get_save_extension()])
