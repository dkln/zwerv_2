extends SceneTree
## Checks that the rail vehicles fit their platforms: it lets them ride, and at every stop
## with open doors it prints how many door leaves are beside the platform. A vehicle that
## fits has all the leaves of one side there (half of them). Prints each kind of stop once;
## a stop where a leaf misses the platform ends with exit code 1. The end of a track without
## a platform is no stop to check. It stops looking after WALL_SECONDS of real time and
## then reports what it has seen.
## usage: Godot --headless --script tools/check/rail_stop_test.gd [-- <seconds of game time>]

const Common = preload("res://tools/tool_common.gd")
const TIME_SCALE := 8.0
const WALL_SECONDS := 460.0
## It stops once this much game time has passed without a stop it had not seen yet.
const QUIET_SECONDS := 400.0

var _reported := {}
var _failures := 0


func _init() -> void:
	Common.watchdog(self, 500)
	var seconds := Common.arg_float(0, 2400.0)
	var scene := Common.instantiate("res://scenes/stad.tscn", false)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	await process_frame
	var vehicles: Array[RailVehicle] = []
	for child in scene.get_children():
		if child is RailVehicle:
			vehicles.append(child)
	Engine.time_scale = TIME_SCALE
	Engine.max_physics_steps_per_frame = 16
	var elapsed := 0.0
	var last_new_stop := 0.0
	var stops_seen := 0
	while elapsed < seconds and elapsed - last_new_stop < QUIET_SECONDS and Time.get_ticks_msec() < WALL_SECONDS * 1000.0:
		await physics_frame
		elapsed += Engine.time_scale / Engine.physics_ticks_per_second
		for vehicle in vehicles:
			if vehicle._door_amount > 0.5:
				_report(vehicle)
		if _reported.size() > stops_seen:
			stops_seen = _reported.size()
			last_new_stop = elapsed
	print("%d stops seen in %d s of game time, %d where a door misses the platform" % [_reported.size(), roundi(elapsed), _failures])
	quit(1 if _failures > 0 or _reported.is_empty() else 0)


func _report(vehicle: RailVehicle) -> void:
	var nose := vehicle.global_position
	var key := "%s %d %d" % [vehicle.vehicle_kind, roundi(nose.x / 8.0), roundi(nose.z / 8.0)]
	if _reported.has(key):
		return
	_reported[key] = true
	if vehicle._waiting_before == RailVehicle.NO_CELL and not vehicle._stands_at_platform():
		print("%s at cell (%d, %d, level %d): end of the track, no platform" % [vehicle.vehicle_kind,
			floori(nose.x / 4.0), floori(nose.z / 4.0), roundi(nose.y)])
		return
	var wanted: int = vehicle._door_leaves.size() / 2
	var opened: int = vehicle._opening_leaves.size()
	print("%s at cell (%d, %d, level %d): %d of %d leaves beside the platform" % [vehicle.vehicle_kind,
		floori(nose.x / 4.0), floori(nose.z / 4.0), roundi(nose.y), opened, wanted])
	if opened != wanted:
		_failures += 1
