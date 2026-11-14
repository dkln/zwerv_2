extends RefCounted
## Unit test of the scripts themselves: every script of the game (scripts/) loads without a
## parse or compile error. A script no unit test touches (a screen, a vehicle) would
## otherwise only fail once the game runs; this catches a moved file, a renamed function or
## a constant that clashes with one of the script it extends.
##   tests/run_unit_tests.sh scripts_compile

const SCRIPT_FOLDER := "res://scripts/"


func test_every_script_compiles(test) -> void:
	var paths := _scripts_in(SCRIPT_FOLDER)
	test.check(paths.size() > 100, "de scripts gevonden (%d)" % paths.size())
	for path in paths:
		var script := load(path) as GDScript
		test.check(script != null and script.can_instantiate(), "%s laadt niet (scriptfout)" % path)


static func _scripts_in(folder: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(".gd"):
			paths.append(folder + file_name)
	for subfolder in DirAccess.get_directories_at(folder):
		paths.append_array(_scripts_in(folder + subfolder + "/"))
	paths.sort()
	return paths
