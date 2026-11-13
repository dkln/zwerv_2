extends "res://tests/integration/support/town_test.gd"
## Turning round buildings (scripts/camera/follow_camera.gd, _choose_turn): with the player
## behind buildings (seen from the camera) the view turns, but only in whole steps of
## `turn_step` degrees (so it stays isometric: the yaw a diagonal, 45 + n * 90 by default),
## never further than `turn_most`, and the pitch stays the iso pitch.
##   tests/run_integration_tests.sh camera_turn

const Iso = preload("res://scripts/camera/iso_camera.gd")
const SAMPLES := 400


## The turn the camera chooses for the player just behind each of SAMPLES buildings (seen
## from the camera, at street level): {turn in degrees: how often}.
func _turns_behind_buildings(camera: Node) -> Dictionary:
	var buildings: GridMap = camera._buildings
	var turns := {}
	if buildings == null:
		return turns
	var cells := buildings.get_used_cells()
	var towards_camera := Iso.direction()
	var flat_away := -Vector3(towards_camera.x, 0.0, towards_camera.z).normalized()
	for sample_index in mini(SAMPLES, cells.size()):
		var building_cell: Vector3i = cells[(sample_index * 7919) % cells.size()]
		var middle := buildings.to_global(buildings.map_to_local(building_cell))
		var player_spot := Vector3(middle.x, buildings.global_position.y, middle.z) + flat_away * 3.5
		camera._turn_goal = 0.0
		camera._usual_free_for = 0.0
		camera._hidden_for = camera.turn_after   # hidden long enough, no turn being held
		camera._turn_held_for = camera.turn_hold_time
		camera._choose_turn(player_spot, camera.zoom_still)
		turns[camera._turn_goal] = int(turns.get(camera._turn_goal, 0)) + 1
	camera._turn_goal = 0.0
	return turns


## Behind buildings the view turns sometimes, always a whole number of steps and never
## further than turn_most.
func test_turns_in_whole_steps_and_not_too_far(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	test.check(camera._buildings != null, "de camera kent de gebouwen")
	var turns := _turns_behind_buildings(camera)
	print("draaiingen (graden: keren): %s" % [turns])
	var off_step := 0
	var too_far := 0
	for goal: float in turns:
		var steps: float = goal / camera.turn_step
		if absf(steps - roundf(steps)) > 0.001:
			off_step += int(turns[goal])
		if absf(goal) > camera.turn_most + 0.001:
			too_far += int(turns[goal])
	test.check(turns.size() > 1, "achter gebouwen draait het beeld soms")
	test.check(off_step == 0, "altijd in hele stappen van %.0f graden (%d niet)" % [camera.turn_step, off_step])
	test.check(too_far == 0, "nooit verder dan %.0f graden" % camera.turn_most)


## Every turn chosen leaves the view on a diagonal (isometric).
func test_every_turn_keeps_the_view_diagonal(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	var turns := _turns_behind_buildings(camera)
	test.check(not turns.is_empty(), "er zijn draaiingen gekozen")
	for goal: float in turns:
		var yaw := fposmod(Iso.ROTATION.y + goal, 360.0)
		test.check(is_equal_approx(fposmod(yaw - 45.0, 90.0), 0.0), "kijkrichting %.0f graden is diagonaal (isometrisch)" % yaw)


## The camera itself, placed turned a quarter: the pitch stays the iso one.
func test_turned_camera_keeps_the_iso_pitch(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	camera._turn = 90.0
	camera._turn_goal = 90.0
	await frames(3)
	var cam: Camera3D = camera._cam
	test.check(absf(cam.rotation_degrees.x - Iso.ROTATION.x) < 0.5, "de camera houdt de iso-hoek (%.1f graden)" % cam.rotation_degrees.x)
	camera._turn = 0.0
	camera._turn_goal = 0.0
