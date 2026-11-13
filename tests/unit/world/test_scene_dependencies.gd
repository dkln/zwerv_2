extends RefCounted
## Unit tests of the scenes in scenes/: every file one of them depends on (a script, a
## library, a texture) still exists. A baked scene (scenes/menu_kaart.scn, made by
## tools/build/build_menu_map.gd) keeps the paths it had when it was baked; when scripts
## move, it no longer loads and the menu quietly shows its drawn backdrop instead of the
## town. After moving scripts: bake again.

const SCENE_FOLDER := "res://scenes/"


func test_every_scene_finds_what_it_depends_on(test) -> void:
	for scene_name in DirAccess.get_files_at(SCENE_FOLDER):
		if not (scene_name.ends_with(".tscn") or scene_name.ends_with(".scn")):
			continue
		var scene_path := SCENE_FOLDER + scene_name
		var missing: Array[String] = []
		for dependency in ResourceLoader.get_dependencies(scene_path):
			# "uid://…::Type::res://path" (or only the path)
			var dependency_path := dependency.get_slice("::", dependency.get_slice_count("::") - 1)
			if dependency_path.begins_with("res://") and not ResourceLoader.exists(dependency_path):
				missing.append(dependency_path)
		test.check(missing.is_empty(), "%s mist %s" % [scene_name, ", ".join(missing)])
