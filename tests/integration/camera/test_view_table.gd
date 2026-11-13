extends "res://tests/integration/support/town_test.gd"
## The view table (scripts/camera/view_table.gd, made when the map is baked or loaded): it is
## there for the town (from the bake cache), it says the same as the follow camera's own test
## of the lines of sight (free or hidden, per street cell and view) for nearly every cell, a
## look-up costs far less than that test, and the view hole follows it: where another view
## shows the player the camera turns and no hole opens (view_hole_wanted false), where no view
## does a hole opens.
##   tests/run_integration_tests.sh view_table

const Iso = preload("res://scripts/camera/iso_camera.gd")
const SAMPLES := 600
## Share of the samples on which the table and the live test must agree (free or hidden): the
## table looks from the middle of a cell, the live test from the exact spot.
const AGREE_AT_LEAST := 0.85


## The view table of the town, waited for (null if it never comes).
func _table() -> ViewTable:
	for frame_index in 600:
		var table := ViewTable.ready_for(scene)
		if table:
			return table
		await tree.process_frame
	return null


## SAMPLES street cells of the table (the same every time), compared with the camera's own
## test: {"share" (of cells x views on which both agree), "counted", and the cells hidden in
## the usual view by what does show them: "turn_helps", "steep_helps", "nothing_helps"}.
func _sample(table: ViewTable, camera: Node) -> Dictionary:
	var distance := Iso.distance(camera.zoom_walk)
	var random := RandomNumberGenerator.new()
	random.seed = 9
	var agree := 0
	var counted := 0
	var turn_helps: Array[Vector3] = []
	var steep_helps: Array[Vector3] = []
	var nothing_helps: Array[Vector3] = []
	for sample_index in SAMPLES * 4:
		if counted >= SAMPLES:
			break
		var cell := table.origin + Vector2i(random.randi() % table.size.x, random.randi() % table.size.y)
		var spot := Vector3((cell.x + 0.5) * table.cell_size, table.street_height, (cell.y + 0.5) * table.cell_size)
		if table.hidden_at(spot, 0.0) < 0:
			continue
		var iso_free := false
		var steep_free := false
		for steep: bool in [false, true]:
			for turn: float in ViewTable.TURNS:
				var from_table := table.hidden_at(spot, turn, steep)
				var live: int = camera._hidden_points(spot, turn, distance, camera.steep_pitch if steep else Iso.ROTATION.x)
				if (from_table == 0) == (live == 0):
					agree += 1
				if from_table == 0:
					if steep:
						steep_free = true
					else:
						iso_free = true
		counted += 1
		if table.hidden_at(spot, 0.0) > 0:
			if iso_free:
				turn_helps.append(spot)
			elif steep_free:
				steep_helps.append(spot)
			else:
				nothing_helps.append(spot)
	var views := ViewTable.TURNS.size() * ViewTable.PITCHES.size()
	return {"share": float(agree) / maxf(counted * views, 1), "counted": counted,
		"turn_helps": turn_helps, "steep_helps": steep_helps, "nothing_helps": nothing_helps}


## The camera looking the usual way, no turn held.
func _camera_unturned() -> Node:
	var camera: Node = scene.get_node("Volgcamera")
	camera._turn = 0.0
	camera._turn_goal = 0.0
	camera._turn_held_for = camera.turn_hold_time
	return camera


## The table is there and agrees with the camera's own test of the lines of sight on
## nearly every sampled cell and view.
func test_table_says_what_the_camera_itself_finds(test) -> void:
	var table := await _table()
	test.check(table != null, "de zichttabel is er")
	if table == null:
		return
	print("zichttabel: %d x %d cellen" % [table.size.x, table.size.y])
	var sample := _sample(table, scene.get_node("Volgcamera"))
	var views := ViewTable.TURNS.size() * ViewTable.PITCHES.size()
	print("eens met de camera zelf: %.0f%% van %d cellen x %d kijkrichtingen" % [sample.share * 100.0, sample.counted, views])
	test.check(sample.share >= AGREE_AT_LEAST, "de tabel zegt hetzelfde als de camera zelf (%.0f%%)" % (sample.share * 100.0))


## A look-up in the table costs far less than the camera's own test (measured on the clock).
func test_look_up_is_far_cheaper_than_testing(test) -> void:
	var table := await _table()
	test.check(table != null, "de zichttabel is er")
	if table == null:
		return
	var camera: Node = scene.get_node("Volgcamera")
	var distance := Iso.distance(camera.zoom_walk)
	var started := Time.get_ticks_usec()
	for repeat in 200:
		table.hidden_at(Vector3(300.0 + repeat, 0.0, 200.0), 90.0)
	var table_usec := (Time.get_ticks_usec() - started) / 200.0
	started = Time.get_ticks_usec()
	for repeat in 200:
		camera._hidden_points(Vector3(300.0 + repeat, 0.0, 200.0), 90.0, distance)
	var live_usec := (Time.get_ticks_usec() - started) / 200.0
	print("opzoeken %.1f µs, zelf testen %.1f µs" % [table_usec, live_usec])
	test.check(table_usec * 10.0 < live_usec, "opzoeken is veel goedkoper dan zelf testen")


## Where turning shows the player the camera turns: no view hole.
func test_no_view_hole_where_turning_helps(test) -> void:
	var table := await _table()
	var camera := _camera_unturned()
	var spots: Array[Vector3] = _sample(table, camera).turn_helps if table else ([] as Array[Vector3])
	test.check(not spots.is_empty(), "plekken waar draaien helpt (%d)" % spots.size())
	if not spots.is_empty():
		player.global_position = spots[0]
		test.check(not camera.view_hole_wanted(), "kan de camera draaien naar vrij zicht: geen kijkgat")


## Where no view shows the player a view hole opens (if the town has such spots).
func test_view_hole_where_no_view_helps(test) -> void:
	var table := await _table()
	var camera := _camera_unturned()
	test.check(table != null, "de zichttabel is er")
	var spots: Array[Vector3] = _sample(table, camera).nothing_helps if table else ([] as Array[Vector3])
	print("  plekken waar niets helpt: %d" % spots.size())
	if not spots.is_empty():
		player.global_position = spots[0]
		test.check(camera.view_hole_wanted(), "helpt geen enkele kijkrichting: wel een kijkgat")


## Between tall buildings, where only looking down steeper shows the player: no view hole,
## and the camera goes for the steeper pitch (if the town has such spots).
func test_camera_looks_steeper_where_only_that_helps(test) -> void:
	var table := await _table()
	var camera := _camera_unturned()
	test.check(table != null, "de zichttabel is er")
	var spots: Array[Vector3] = _sample(table, camera).steep_helps if table else ([] as Array[Vector3])
	print("  plekken waar alleen steiler kijken helpt: %d" % spots.size())
	if not spots.is_empty():
		player.global_position = spots[0]
		test.check(not camera.view_hole_wanted(), "helpt alleen steiler kijken: geen kijkgat")
		camera._hidden_for = camera.turn_after
		camera._choose_turn(spots[0], camera.zoom_walk)
		test.check(camera._steep_goal > 0.5, "en de camera kijkt dan steiler omlaag (doel %.0f graden gedraaid)" % camera._turn_goal)
		camera._steep_goal = 0.0
		camera._turn_goal = 0.0
