extends SceneTree
## Checks that the rail vehicles fit their platforms: it lets them ride, and at every stop
## with open doors it prints how many door leaves are beside the platform. A vehicle that
## fits has all the leaves of one side there (half of them). Prints each kind of stop once;
## a stop where a leaf misses the platform ends with exit code 1.
## usage: Godot --headless --script tools/check/rail_stop_test.gd [-- <seconds of game time>]

const Common = preload("res://tools/tool_common.gd")
const TIME_SCALE := 8.0

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
	while elapsed < seconds:
		await physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
		for vehicle in vehicles:
			if vehicle._door_amount > 0.5:
				_report(vehicle)
	print("%d stops seen, %d where a door misses the platform" % [_reported.size(), _failures])
	quit(1 if _failures > 0 or _reported.is_empty() else 0)


func _report(vehicle: RailVehicle) -> void:
	var nose := vehicle.global_position
	var key := "%s %d %d" % [vehicle.vehicle_kind, roundi(nose.x / 8.0), roundi(nose.z / 8.0)]
	if _reported.has(key):
		return
	_reported[key] = true
	var wanted: int = vehicle._door_leaves.size() / 2
	var opened: int = vehicle._opening_leaves.size()
	print("%s at cell (%d, %d, level %d): %d of %d leaves beside the platform" % [vehicle.vehicle_kind,
		floori(nose.x / 4.0), floori(nose.z / 4.0), roundi(nose.y), opened, wanted])
	if opened != wanted:
		_failures += 1
