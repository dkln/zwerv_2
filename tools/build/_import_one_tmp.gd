extends SceneTree
## Imports one tile (.gox) to its imported mesh, as the editor's import would, without a
## project-wide import. usage: --script ... -- res://path/to/tile.gox
func _init() -> void:
	var source: String = OS.get_cmdline_user_args()[0]
	var settings := ConfigFile.new()
	settings.load(source + ".import")
	var options := {}
	for key in settings.get_section_keys("params"):
		options[key] = settings.get_value("params", key)
	var save_path: String = String(settings.get_value("remap", "path")).get_basename()
	var plugin = load("res://tools/build/_vox_import_copy_tmp.gd").new()
	var gen_files: Array[String] = []
	var result: int = plugin._import(source, save_path, options, [], gen_files)
	print("import %s -> %s: %s" % [source, save_path, error_string(result)])
	quit()
