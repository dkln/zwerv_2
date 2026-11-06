extends SceneTree
## Checks switching vehicles with the follow camera (Tab, Shift+Tab, scripts/camera/follow_camera.gd):
## real key presses go through the input of the window, and per switch it prints which vehicle
## is followed, the biggest step of the camera in one frame and how far the view ends up from
## the vehicle. Every vehicle gets one turn, trains included; a failure ends with exit code 1.
## usage: Godot --headless --script tools/check/follow_switch_test.gd

const Common = preload("res://tools/tool_common.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
## Metres from the view's centre to the vehicle that still counts as arrived (the view
## looks ahead of a driving vehicle).
const ARRIVED_WITHIN := 30.0

var _failures := 0


func _init() -> void:
	Common.watchdog(self, 300)
	var scene := Common.instantiate("res://scenes/stad.tscn", false)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var follow: Node = scene.get_node("Volgcamera")
	var camera: Camera3D = get_root().get_camera_3d()
	print("voertuigen: ", Vehicle.all_vehicles.size())

	_press(KEY_TAB)
	await process_frame
	await process_frame
	_check(follow.is_following(), "Tab without following starts following")
	_check(follow.target_node == scene.get_node("Auto"), "the first Tab follows the Auto")

	var order: Array[Vehicle] = Vehicle.all_vehicles.duplicate()
	var seen := {}
	for turn in order.size():
		var before: Node3D = follow.target_node
		_press(KEY_TAB)
		await process_frame
		var followed: Vehicle = follow.target_node
		_check(followed != before, "Tab changes the vehicle")
		_check(not seen.has(followed), "Tab reaches every vehicle once")
		seen[followed] = true
		await _report(followed, camera, follow)

	_press(KEY_SHIFT)
	await process_frame
	_check(follow.is_following(), "Shift alone keeps following")
	var before_back: Node3D = follow.target_node
	var expected_back: Vehicle = order[posmod(order.find(before_back) - 1, order.size())]
	_press(KEY_TAB, true)
	await process_frame
	_check(follow.target_node == expected_back, "Shift+Tab goes back one")

	# one press after another while still gliding must not jump either
	_press(KEY_TAB)
	await process_frame
	_press(KEY_TAB)
	await process_frame
	await _report(follow.target_node, camera, follow)

	# a train changing ends jumps its length: the view glides over instead of jumping along
	var train: Vehicle = scene.get_node("Trein1")
	follow.switch_vehicle(order.find(train) - order.find(follow.target_node))
	_check(follow.target_node == train, "switch_vehicle reaches the train")
	await _report(train, camera, follow)
	var nose_before := train.drawn_position()
	train.call("_change_ends")
	await process_frame
	print("trein wisselt van cabine: sprong %.1f m" % train.drawn_position().distance_to(nose_before))
	_check(follow._glide_over_left > 0.0, "the jump of the train starts a glide")
	await _report(train, camera, follow)

	# B while following a train: the demo crash must not fail on it
	_press(KEY_B)
	await process_frame
	await create_timer(1.0).timeout
	_check(follow.is_following(), "B keeps following the train")

	_press(KEY_X)
	await process_frame
	_check(not follow.is_following(), "another key gives back the free camera")
	var last_followed: Node3D = follow.target_node
	_press(KEY_F)
	await process_frame
	await process_frame
	_check(follow.is_following() and follow.target_node == last_followed, "F follows the last vehicle again")

	print("KLAAR, mislukt: ", _failures)
	quit(1 if _failures else 0)


## Follows the glide over; prints the biggest camera step and the distance at the end.
func _report(vehicle: Vehicle, camera: Camera3D, follow: Node) -> void:
	var biggest_step := 0.0
	var start := camera.global_position
	var last := start
	var elapsed := 0.0
	while elapsed < follow.switch_time + 1.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		biggest_step = maxf(biggest_step, camera.global_position.distance_to(last))
		last = camera.global_position
	var focus := Iso.ground_focus(camera)
	var spot := vehicle.drawn_position()
	var off := Vector2(focus.x - spot.x, focus.z - spot.z).length()
	print("%-12s %-22s afstand %6.1f m, grootste stap %5.2f m, uit het midden %5.1f m" % [
		vehicle.name, vehicle.get_script().resource_path.get_file(), start.distance_to(last), biggest_step, off])
	_check(off < ARRIVED_WITHIN or spot.y < -0.5, "the view arrives at %s" % vehicle.name)


func _press(key: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.shift_pressed = shift
	event.pressed = true
	get_root().push_input(event)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("MISLUKT: ", what)
