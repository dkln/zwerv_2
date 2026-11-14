extends "res://tests/integration/support/town_test.gd"
## The view with the player behind buildings (scripts/camera/follow_camera.gd, _choose_turn). As
## the game has it (turn_to_streets off): it never turns, it goes over to the view from above
## (steep_pitch) after top_down_after s. With turn_to_streets on: the view turns, but only in
## whole steps of `turn_step` degrees (so it stays isometric: the yaw a diagonal, 45 + n * 90 by
## default), never further than `turn_most`, and the pitch stays the iso pitch.
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
		# the street has asked for its view long enough already
		camera._wanted_turn = camera._street_turn(player_spot) if camera.turn_to_streets else NAN
		camera._wanted_for = camera.turn_after
		camera._choose_turn(player_spot, camera.zoom_still)
		turns[camera._turn_goal] = int(turns.get(camera._turn_goal, 0)) + 1
	camera._turn_goal = 0.0
	return turns


## The camera itself, placed turned a quarter: the pitch stays the iso one.
func test_turned_camera_keeps_the_iso_pitch(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	set_for_test(camera, "turn_to_streets", true)
	camera._steep = 0.0
	camera._steep_goal = 0.0
	set_for_test(camera, "turn_round_buildings", false)
	camera._turn = 90.0
	camera._turn_goal = 90.0
	await frames(3)
	var cam: Camera3D = camera._cam
	test.check(absf(cam.rotation_degrees.x - Iso.ROTATION.x) < 0.5, "de camera houdt de iso-hoek (%.1f graden)" % cam.rotation_degrees.x)
	camera._turn = 0.0
	camera._turn_goal = 0.0


## As the game has it (turn_to_streets off): behind buildings the view never turns, it goes over
## to the view from above.
func test_behind_buildings_the_view_goes_over_to_above(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	set_for_test(camera, "manual_turning", false)   # turned by itself (whatever the settings say)
	test.check(not camera.turn_to_streets, "het beeld draait niet mee met de straten")
	var turns := _turns_behind_buildings(camera)
	test.check(turns.keys() == [0.0], "achter gebouwen geen andere kijkrichting (%s)" % [turns])
	camera._steep_goal = 0.0
	camera._hidden_for = camera.top_down_after
	var buildings: GridMap = camera._buildings
	var cell: Vector3i = buildings.get_used_cells()[1234]
	var middle := buildings.to_global(buildings.map_to_local(cell))
	var away := -Vector3(Iso.direction().x, 0.0, Iso.direction().z).normalized()
	camera._choose_turn(Vector3(middle.x, buildings.global_position.y, middle.z) + away * 3.5, camera.zoom_still)
	test.check(camera._steep_goal > 0.5, "het beeld gaat naar bovenaf (%.0f graden)" % camera.steep_pitch)
	camera._steep_goal = 0.0
	camera._steep = 0.0


## The player's rim (PlayerModel.rim, figure_rim_mask.gdshader) is on in the town wherever the
## player stands, behind buildings and in the open, in the iso view and from above: its shader
## shows it only where something stands before the figure (no baked map of hidden cells, no
## interval). Its materials know where the figure is, right after a move.
func test_player_rim_is_on_and_follows_the_figure(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	var buildings: GridMap = camera._buildings
	var cell: Vector3i = buildings.get_used_cells()[1234]
	var middle := buildings.to_global(buildings.map_to_local(cell))
	var away := -Vector3(Iso.direction().x, 0.0, Iso.direction().z).normalized()
	var behind := Vector3(middle.x, buildings.global_position.y, middle.z) + away * 3.5
	await put_player(behind)
	var model: Node3D = player._model
	test.check(model.rim, "de rand staat aan achter een gebouw")
	var shells := model.find_children(model.RIM_SHELL, "MeshInstance3D", true, false)
	test.check(not shells.is_empty(), "elk deel heeft een randschil (%d)" % shells.size())
	var centre: Vector3 = model._rim_material.get_shader_parameter("figure_centre")
	var expected: Vector3 = player.global_position + Vector3.UP * model.height() * 0.5
	test.check(centre.distance_to(expected) < 0.5, "de rand weet waar de figuur staat (%s, verwacht %s)" % [centre, expected])
	camera._steep = 1.0
	await frames(2)
	test.check(model.rim, "de rand blijft aan als het beeld van bovenaf kijkt")
	camera._steep = 0.0
	camera._steep_goal = 0.0


## Turned by hand (the setting CameraTurning): Z / X a quarter each way (four views), C back
## to the usual one (the near way round), the street never turns it; inside it does not turn.
func test_turned_by_hand(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	set_for_test(camera, "manual_turning", true)
	set_for_test(camera, "turn_to_streets", true)
	camera._turn = 0.0
	camera._turn_goal = 0.0
	for key: Key in [KEY_X, KEY_X]:
		var press := InputEventKey.new()
		press.keycode = key
		press.physical_keycode = key
		press.pressed = true
		tree.root.push_input(press)
		await frames(1)
	test.check(is_equal_approx(camera._turn_goal, 180.0), "X twee keer: een halve slag (%.0f)" % camera._turn_goal)
	camera.turn_by(-1)
	test.check(is_equal_approx(camera._turn_goal, 90.0), "Z: een kwart terug (%.0f)" % camera._turn_goal)
	camera.turn_by(1)
	camera.turn_by(1)
	camera.turn_by(1)
	camera.turn_back()
	test.check(is_equal_approx(fmod(camera._turn_goal, 360.0), 0.0), "C: terug naar de gewone stand (%.0f)" % camera._turn_goal)
	var goal_before: float = camera._turn_goal
	camera._wanted_turn = 90.0
	camera._wanted_for = camera.turn_after
	camera._turn_held_for = camera.turn_hold_time
	camera._choose_turn(player.global_position, camera.zoom_still)
	test.check(is_equal_approx(camera._turn_goal, goal_before), "de straat draait hem niet meer zelf")
	camera.set_indoors(true)
	camera.turn_by(1)
	test.check(is_equal_approx(camera._turn_goal, 0.0), "binnen draait hij niet")
	camera.set_indoors(false)
	camera._turn = 0.0
	camera._turn_goal = 0.0


## Turned by hand the view is round quickly (manual_turn_glide_time), not in the slow glide of
## turning by itself.
func test_turned_by_hand_is_quick(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	set_for_test(camera, "manual_turning", true)
	camera._turn = 0.0
	camera._turn_goal = 0.0
	camera._turn_velocity = 0.0
	camera.turn_by(1)
	await seconds(camera.manual_turn_glide_time * 4.0)
	test.check(absf(camera._turn - 90.0) < 3.0, "na %.1f s al rond (%.1f graden)" % [camera.manual_turn_glide_time * 4.0, camera._turn])
	camera._turn = 0.0
	camera._turn_goal = 0.0


## Turned by hand: + and - (and the mouse wheel, the right stick) zoom in and out, within
## ZOOM_MOST; it does not look down steeper by itself; turned by itself, + does nothing.
func test_zoom_and_no_tilt_by_hand(test) -> void:
	var camera: Node = scene.get_node("Volgcamera")
	set_for_test(camera, "manual_turning", true)
	camera.user_zoom = 1.0
	for key: Key in [KEY_EQUAL, KEY_EQUAL]:
		var press := InputEventKey.new()
		press.keycode = key
		press.physical_keycode = key
		press.pressed = true
		tree.root.push_input(press)
		await frames(1)
	test.check(camera.user_zoom < 0.8, "+ twee keer: ingezoomd (%.2f)" % camera.user_zoom)
	for step in 20:
		camera.zoom_by(1)
	test.check(is_equal_approx(camera.user_zoom, camera.ZOOM_MOST.y), "niet verder uit dan %.1f×" % camera.ZOOM_MOST.y)
	camera._steep_goal = 0.0
	camera._hidden_for = 100.0
	camera._choose_turn(player.global_position, camera.zoom_still)
	test.check(camera._steep_goal < 0.5, "zelf draaien: hij kantelt niet vanzelf")
	camera.user_zoom = 1.0
	set_for_test(camera, "manual_turning", false)
	camera.zoom_by(-1)
	test.check(is_equal_approx(camera.user_zoom, 1.0), "automatisch: zoomen met + doet niets")
