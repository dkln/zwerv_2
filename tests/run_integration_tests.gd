extends SceneTree
## The integration tests: every suite under tests/integration/<category>/ (a script that
## extends tests/integration/support/town_test.gd). The town is started once for all
## suites that want the same world (TownTest.world_options; another world: the town once
## more; "town": false: no town, the suite builds its own small scene), and every function
## of a suite whose name starts with "test_" is a test: it gets a `test` to check things on
## and is awaited; before each the world is put back (TownWorld.reset). A test that takes
## longer than TEST_SECONDS of the clock (a suite can set its own: `const TEST_SECONDS`)
## counts as failed and the run goes on. A suite whose world says "own_process" only runs
## when it is asked for by name (test_<name>), never with its category. The run ends with a
## summary and "CHECK_KLAAR ok" or "CHECK_KLAAR fout" (Common.finish).
## Run it through tests/run_integration_tests.sh (headless, game time faster than the clock):
##   tests/run_integration_tests.sh alle           every category, then the own-process suites one by one
##   tests/run_integration_tests.sh throw_out      one suite
##   tests/run_integration_tests.sh interiors      a whole category
##   tests/run_integration_tests.sh traffic_run -- 300   arguments for the suite (TownTest.argument)

const Common = preload("res://tools/tool_common.gd")
const TownWorld = preload("res://tests/integration/support/town_world.gd")
const FOLDER := "res://tests/integration/"
const BASE := "res://tests/integration/support/town_test.gd"
## Seconds of the clock one test may take.
const TEST_SECONDS := 150.0


## What a test gets: check() records whether something holds.
class IntegrationTest:
	var failures: Array[String] = []
	var checks := 0

	func check(condition: bool, what: String) -> void:
		checks += 1
		print(("  ok    " if condition else "  FOUT  ") + what)
		if not condition:
			failures.append(what)


func _init() -> void:
	Common.watchdog(self, 3000)
	await process_frame
	var only := Common.arg(0, "")
	# the suites, grouped by the world they want
	var worlds := {}       # world key -> {"options", "suites": [[path, script]]}
	for path in _suite_files(FOLDER):
		var suite_file := path.get_file().get_basename()
		var by_name := only == suite_file or (only == suite_file.trim_prefix("test_") and not DirAccess.dir_exists_absolute(FOLDER + only))
		var by_category := only == "" or only == "alle" or only == path.get_base_dir().get_file()
		if not by_name and not by_category:
			continue
		var script: GDScript = load(path)
		if script == null or not _is_town_test(script):
			continue
		var options := TownWorld.options_of(script.call("world_options"))
		if bool(options.own_process) and not by_name:
			continue
		var key := TownWorld.key_of(options)
		if not worlds.has(key):
			worlds[key] = {"options": options, "suites": []}
		(worlds[key].suites as Array).append([path, script])
	var passed := 0
	var failed: Array[String] = []
	for key: String in worlds:
		var started := Time.get_ticks_msec()
		var scene: Node3D = await TownWorld.start(self, worlds[key].options)
		print("=== de wereld staat (%s) na %.1f s" % [_asked(worlds[key].options), (Time.get_ticks_msec() - started) / 1000.0])
		for suite: Array in worlds[key].suites:
			var script: GDScript = suite[1]
			var suite_name := String(suite[0]).get_file().get_basename()
			var most_seconds := float(script.get_script_constant_map().get("TEST_SECONDS", TEST_SECONDS))
			for method: Dictionary in script.get_script_method_list():
				var test_name := str(method.name)
				if not test_name.begins_with("test_"):
					continue
				await TownWorld.reset(self, scene)
				var instance: RefCounted = script.new()
				instance.set("tree", self)
				instance.set("scene", scene)
				if scene:
					instance.set("player", scene.get_node_or_null("Speler"))
					instance.set("hud", scene.get_node_or_null("HUD"))
					instance.set("interiors", scene.get_node_or_null("Binnenruimtes"))
				print("--- %s %s" % [suite_name, test_name])
				var test := IntegrationTest.new()
				var state := {"done": false}
				var test_started := Time.get_ticks_msec()
				_run(instance, test_name, test, state)
				while not state.done and Time.get_ticks_msec() - test_started < most_seconds * 1000.0:
					await process_frame
				if not state.done:
					test.failures.append("niet klaar binnen %d s" % int(most_seconds))
				var took := (Time.get_ticks_msec() - test_started) / 1000.0
				if test.failures.is_empty() and test.checks > 0:
					passed += 1
					print("ok    %s %s (%d, %.1f s)" % [suite_name, test_name, test.checks, took])
				else:
					failed.append("%s %s" % [suite_name, test_name])
					print("FOUT  %s %s: %s" % [suite_name, test_name,
						", ".join(test.failures) if not test.failures.is_empty() else "niets gecontroleerd"])
		await TownWorld.stop(self, scene)
	print("integratietests: %d geslaagd, %d mislukt%s" % [passed, failed.size(), (": " + ", ".join(failed)) if not failed.is_empty() else ""])
	Common.finish(self, 0 if failed.is_empty() and passed > 0 else 1)


## One test, awaited; `state.done` once it has returned.
func _run(instance: RefCounted, test_name: String, test: IntegrationTest, state: Dictionary) -> void:
	await instance.call(test_name, test)
	state.done = true


## The options of a world that differ from the usual town, to name it in the output.
static func _asked(options: Dictionary) -> String:
	var asked: Array[String] = []
	for option: String in options:
		if str(options[option]) != str(TownWorld.DEFAULTS[option]):
			asked.append("%s: %s" % [option, options[option]])
	return "de gewone stad" if asked.is_empty() else ", ".join(asked)


static func _is_town_test(script: GDScript) -> bool:
	var base := script.get_base_script()
	while base != null:
		if base.resource_path == BASE:
			return true
		base = base.get_base_script()
	return false


## Every test_*.gd under `folder` (the categories are its sub folders), sorted.
static func _suite_files(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append(folder.path_join(file_name))
	for sub_folder in DirAccess.get_directories_at(folder):
		if sub_folder != "support":
			found.append_array(_suite_files(folder.path_join(sub_folder)))
	found.sort()
	return found
