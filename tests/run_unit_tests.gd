extends SceneTree
## The unit tests: small parts of the game tested on their own, without the city (fast, a
## few seconds). Every file tests/unit/test_*.gd is a RefCounted script; every function in it
## whose name starts with "test_" is a test. A test calls check(condition, "what") on the
## UnitTest it gets; it fails when one of those is false (or the test hits a script error).
## The run ends with a summary and exit code 0 (all passed) or 1.
##   tools/godot.sh --headless --script tests/run_unit_tests.gd
##   tools/godot.sh --headless --script tests/run_unit_tests.gd -- babble   (only files with "babble")
## The bigger checks with the whole city stay in tools/check/.

const Common = preload("res://tools/tool_common.gd")
const UNIT_FOLDER := "res://tests/unit/"


## What a test gets: check() records whether something holds.
class UnitTest:
	var failures: Array[String] = []
	var checks := 0

	func check(condition: bool, what: String) -> void:
		checks += 1
		if not condition:
			failures.append(what)


func _init() -> void:
	Common.watchdog(self, 120)
	var only := Common.arg(0, "")
	var passed := 0
	var failed := 0
	for file_name in DirAccess.get_files_at(UNIT_FOLDER):
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd") \
				or (only != "" and not file_name.contains(only)):
			continue
		var script: GDScript = load(UNIT_FOLDER + file_name)
		for method: Dictionary in script.get_script_method_list():
			var test_name := str(method.name)
			if not test_name.begins_with("test_"):
				continue
			var suite: Object = script.new()
			var test := UnitTest.new()
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
