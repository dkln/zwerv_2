extends SceneTree
## The unit tests: small parts of the game tested on their own, without the city (fast, a
## few seconds). Every file tests/unit/<category>/test_*.gd is a RefCounted script; every function in it
## whose name starts with "test_" is a test. A test calls check(condition, "what") on the
## UnitTest it gets; it fails when one of those is false (or the test hits a script error).
## A test that needs its nodes in a tree adds them to test.tree.root (and frees them).
## The run ends with a summary and exit code 0 (all passed) or 1.
##   tools/godot.sh --headless --script tests/run_unit_tests.gd
##   tools/godot.sh --headless --script tests/run_unit_tests.gd -- babble   (only files with "babble")
##   tools/godot.sh --headless --script tests/run_unit_tests.gd -- audio    (only that category)
## The scenarios in the whole city are the integration tests (tests/run_integration_tests.sh).

const Common = preload("res://tools/tool_common.gd")
const UNIT_FOLDER := "res://tests/unit/"


## What a test gets: check() records whether something holds.
class UnitTest:
	var failures: Array[String] = []
	var checks := 0
	## The tree of the run, for a test whose nodes must be in one (UnitTest.tree.root).
	var tree: SceneTree

	func check(condition: bool, what: String) -> void:
		checks += 1
		if not condition:
			failures.append(what)


func _init() -> void:
	Common.watchdog(self, 120)
	# one frame first: then the root is in the tree (for the suites with a `tree`)
	await process_frame
	var only := Common.arg(0, "")
	var passed := 0
	var failed := 0
	for path in _test_files(UNIT_FOLDER):
		var file_name := path.get_file()
		# "-- babble": the files with that in their name; "-- audio": a whole category (its folder)
		if only != "" and not file_name.contains(only) and path.get_base_dir().get_file() != only:
			continue
		var script: GDScript = load(path)
		# a file that does not load (a parse error) is a failure, not nothing
		if script == null or not script.can_instantiate():
			failed += 1
			print("FOUT  %s: laadt niet (scriptfout)" % file_name.get_basename())
			continue
		for method: Dictionary in script.get_script_method_list():
			var test_name := str(method.name)
			if not test_name.begins_with("test_"):
				continue
			var suite: Object = script.new()
			if "tree" in suite:
				suite.set("tree", self)   # a suite that wants the tree of the run
			var test := UnitTest.new()
			test.tree = self
			suite.call(test_name, test)
			if test.failures.is_empty() and test.checks > 0:
				passed += 1
				print("ok    %s %s (%d)" % [file_name.get_basename(), test_name, test.checks])
			else:
				failed += 1
				print("FOUT  %s %s: %s" % [file_name.get_basename(), test_name,
						", ".join(test.failures) if not test.failures.is_empty() else "niets gecontroleerd"])
	print("unit tests: %d geslaagd, %d mislukt" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


## Every test_*.gd under `folder` (the categories are its sub folders), sorted.
static func _test_files(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append(folder.path_join(file_name))
	for sub_folder in DirAccess.get_directories_at(folder):
		found.append_array(_test_files(folder.path_join(sub_folder)))
	found.sort()
	return found
