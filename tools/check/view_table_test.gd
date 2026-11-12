extends SceneTree
## The view table (scripts/camera/view_table.gd, made when the map is baked or loaded): it is
## there for the town (from the bake cache), it says the same as the follow camera's own test
## of the lines of sight (free or hidden, per street cell and view) for nearly every cell, a
## look-up costs far less than that test, and the view hole follows it: where another view
## shows the player the camera turns and no hole opens (view_hole_wanted false), where no view
## does a hole opens.
## usage: tools/godot.sh --headless --script tools/check/view_table_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const SAMPLES := 600
## Share of the samples on which the table and the live test must agree (free or hidden): the
## table looks from the middle of a cell, the live test from the exact spot.
const AGREE_AT_LEAST := 0.85

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 250)
	PlayerCharacter.choose("jos")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var camera: Node = scene.get_node("Volgcamera")
	var table: ViewTable = null
	for frame_index in 600:
		await process_frame
		table = ViewTable.ready_for(scene)
		if table:
			break
	_check(table != null, "de zichttabel is er")
	if table == null:
		_finish()
		return
	print("zichttabel: %d x %d cellen" % [table.size.x, table.size.y])
	var distance := Iso.distance(camera.zoom_walk)
	var random := RandomNumberGenerator.new()
	random.seed = 9
	var agree := 0
	var counted := 0
	var spots_turn_helps: Array[Vector3] = []
	var spots_nothing_helps: Array[Vector3] = []
	var spots_steep_helps: Array[Vector3] = []
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
				spots_turn_helps.append(spot)
			elif steep_free:
				spots_steep_helps.append(spot)
			else:
				spots_nothing_helps.append(spot)
	var views := ViewTable.TURNS.size() * ViewTable.PITCHES.size()
	var share := float(agree) / maxf(counted * views, 1)
	print("eens met de camera zelf: %.0f%% van %d cellen x %d kijkrichtingen" % [share * 100.0, counted, views])
	_check(share >= AGREE_AT_LEAST, "de tabel zegt hetzelfde als de camera zelf (%.0f%%)" % (share * 100.0))
	# the cost of a look-up against the live test
	var started := Time.get_ticks_usec()
	for repeat in 200:
		table.hidden_at(Vector3(300.0 + repeat, 0.0, 200.0), 90.0)
	var table_usec := (Time.get_ticks_usec() - started) / 200.0
	started = Time.get_ticks_usec()
	for repeat in 200:
		camera._hidden_points(Vector3(300.0 + repeat, 0.0, 200.0), 90.0, distance)
	var live_usec := (Time.get_ticks_usec() - started) / 200.0
	print("opzoeken %.1f µs, zelf testen %.1f µs" % [table_usec, live_usec])
	_check(table_usec * 10.0 < live_usec, "opzoeken is veel goedkoper dan zelf testen")
	# the view hole: only where turning does not help
	var player: Node3D = scene.get_node("Speler")
	camera._end_arrival()
	await process_frame
	print("  camera volgt %s, aankomst %s, draaien %s" % [camera.target_node, camera._arriving, camera.turn_round_buildings])
	camera._turn = 0.0
	camera._turn_goal = 0.0
	camera._turn_held_for = camera.turn_hold_time
	print("  plekken: draaien helpt %d, alleen steiler kijken %d, niets %d" % [spots_turn_helps.size(), spots_steep_helps.size(), spots_nothing_helps.size()])
	_check(not spots_turn_helps.is_empty(), "plekken waar draaien helpt (%d)" % spots_turn_helps.size())
	if not spots_turn_helps.is_empty():
		player.global_position = spots_turn_helps[0]
		_check(not camera.view_hole_wanted(), "kan de camera draaien naar vrij zicht: geen kijkgat")
	if not spots_nothing_helps.is_empty():
		player.global_position = spots_nothing_helps[0]
		_check(camera.view_hole_wanted(), "helpt geen enkele kijkrichting: wel een kijkgat")
	# between tall buildings: only looking down steeper shows it, so the camera does that
	if not spots_steep_helps.is_empty():
		player.global_position = spots_steep_helps[0]
		_check(not camera.view_hole_wanted(), "helpt alleen steiler kijken: geen kijkgat")
		camera._hidden_for = camera.turn_after
		camera._choose_turn(spots_steep_helps[0], camera.zoom_walk)
		_check(camera._steep_goal > 0.5, "en de camera kijkt dan steiler omlaag (doel %.0f graden gedraaid)" % camera._turn_goal)
	_finish()


func _finish() -> void:
	print("zichttabel ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
