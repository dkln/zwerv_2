extends SceneTree
## Turning round buildings (scripts/camera/follow_camera.gd, _choose_turn): with the player
## behind buildings (seen from the camera) the view turns, but only in whole steps of
## `turn_step` degrees (so it stays isometric: the yaw a diagonal, 45 + n * 90 by default),
## never further than `turn_most`, and the pitch stays the iso pitch.
## usage: tools/godot.sh --headless --script tools/check/camera_turn_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")

const SAMPLES := 400

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	PlayerCharacter.choose("jos")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var camera: Node = scene.get_node("Volgcamera")
	await process_frame
	await process_frame
	var buildings: GridMap = camera._buildings
	_check(buildings != null, "de camera kent de gebouwen")
	if buildings == null:
		quit(1)
		return
	var cells := buildings.get_used_cells()
	var towards_camera := Iso.direction()
	var flat_away := -Vector3(towards_camera.x, 0.0, towards_camera.z).normalized()
	var turns := {}
	var off_step := 0
	var too_far := 0
	for sample_index in mini(SAMPLES, cells.size()):
		var building_cell: Vector3i = cells[(sample_index * 7919) % cells.size()]
		var middle := buildings.to_global(buildings.map_to_local(building_cell))
		# just behind the building, seen from the camera, at street level
		var player_spot := Vector3(middle.x, buildings.global_position.y, middle.z) + flat_away * 3.5
		camera._turn_goal = 0.0
		camera._usual_free_for = 0.0
		camera._choose_turn(player_spot, camera.zoom_still)
		var goal: float = camera._turn_goal
		turns[goal] = int(turns.get(goal, 0)) + 1
		var steps: float = goal / camera.turn_step
		if absf(steps - roundf(steps)) > 0.001:
			off_step += 1
		if absf(goal) > camera.turn_most + 0.001:
			too_far += 1
	print("draaiingen (graden: keren): %s" % [turns])
	_check(turns.size() > 1, "achter gebouwen draait het beeld soms")
	_check(off_step == 0, "altijd in hele stappen van %.0f graden (%d niet)" % [camera.turn_step, off_step])
	_check(too_far == 0, "nooit verder dan %.0f graden" % camera.turn_most)
	for goal: float in turns:
		var yaw := fposmod(Iso.ROTATION.y + goal, 360.0)
		_check(is_equal_approx(fposmod(yaw - 45.0, 90.0), 0.0), "kijkrichting %.0f graden is diagonaal (isometrisch)" % yaw)
	# the camera itself: placed turned, the pitch stays the iso one
	camera._turn = 90.0
	camera._turn_goal = 90.0
	for frame_index in 3:
		await process_frame
	var cam: Camera3D = camera._cam
	_check(absf(cam.rotation_degrees.x - Iso.ROTATION.x) < 0.5, "de camera houdt de iso-hoek (%.1f graden)" % cam.rotation_degrees.x)
	print("camera draaien ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
