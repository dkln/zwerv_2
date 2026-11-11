extends SceneTree
## Lets the traffic of scenes/stad.tscn drive headless, faster than real time, and reports
## every time the bodies of two driving vehicles overlap (seen from above, no margin)
## without a crash: vehicles that drive through each other. Per overlap it prints the
## situation once (speeds, headings, whether it is on a crossing, who waits for whom).
## usage: Godot --headless --script tools/check/overlap_test.gd -- [simulated seconds]

const Common = preload("res://tools/tool_common.gd")
const TIME_SCALE := 8
const STEP := 1.0 / 60.0
## Metres two footprints must overlap by (each shrunk by this) before it counts.
const SHRINK := 0.15


func _init() -> void:
	Common.watchdog(self, 900)
	var seconds := Common.arg_float(0, 300.0)
	var scene := Common.instantiate("res://scenes/stad.tscn")
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	Engine.time_scale = TIME_SCALE
	Engine.physics_ticks_per_second = 60 * TIME_SCALE
	Engine.max_physics_steps_per_frame = 4 * TIME_SCALE
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var vehicles: Array[Vehicle] = Vehicle.all_vehicles.duplicate()
	print("voertuigen: ", vehicles.size())
	var overlapping := {}     # pair key -> true while they overlap
	var overlap_count := 0
	# TRACE=Verkeer4,Verkeer9: also prints these vehicles every half second
	var traced := OS.get_environment("TRACE").split(",", false)
	var elapsed := 0.0
	var trace_clock := 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += STEP
		trace_clock += STEP
		if trace_clock >= 0.5 and not traced.is_empty():
			trace_clock = 0.0
			for vehicle in vehicles:
				if traced.has(vehicle.name):
					print("%6.1f s  %s pos (%.1f, %.1f) %s" % [elapsed, vehicle.name, vehicle.global_position.x, vehicle.global_position.z,
							_describe(vehicle, vehicle)])
					var route := ""
					for index in vehicle._route_cells.size():
						route += " %d,%d%s@%.1f" % [vehicle._route_cells[index].x, vehicle._route_cells[index].z,
								vehicle._route_headings[index], vehicle._route_distances[index]]
					print("        afstand %.1f yield %s route%s" % [vehicle._distance, vehicle.yielding, route])
		for first_index in vehicles.size():
			var first := vehicles[first_index]
			for second_index in range(first_index + 1, vehicles.size()):
				var second := vehicles[second_index]
				var key := "%d-%d" % [first_index, second_index]
				var touching := not first.crashed and not second.crashed and _overlap(first, second)
				if touching and not overlapping.has(key):
					overlap_count += 1
					print("%6.1f s  OVERLAP\n    %s\n    %s" % [elapsed, _describe(first, second), _describe(second, first)])
				if touching:
					overlapping[key] = true
				else:
					overlapping.erase(key)
	print("samen: %d keer door elkaar heen" % overlap_count)
	Engine.time_scale = 1.0
	quit()


func _overlap(first: Vehicle, second: Vehicle) -> bool:
	if first.global_position.distance_to(second.global_position) > first._reach() + second._reach() + 1.0:
		return false
	if absf(first.global_position.y - second.global_position.y) > Vehicle.CRASH_LEVEL_DIFFERENCE:
		return false
	if first._passes(second) or second._passes(first):
		return false
	for mine in first._footprints(-SHRINK):
		for theirs in second._footprints(-SHRINK):
			if Vehicle._rectangles_overlap(mine, theirs):
				return true
	return false


func _describe(vehicle: Vehicle, other: Vehicle) -> String:
	var cell := vehicle._cell_under()
	var forward := vehicle.global_basis.z
	var relative := other.global_position - vehicle.global_position
	var blocker := "-"
	if vehicle._blocked_by:
		blocker = vehicle._blocked_by.name
	return "%s (%s) cel %s kruising %s koers (%.2f, %.2f) %.1f m/s doel-limiet %.1f wacht op %s knijp %.1f andere voor %.1f opzij %.1f" % [
		vehicle.name, vehicle.model.get_file().get_basename(), cell, vehicle.network.is_crossing(cell),
		forward.x, forward.z, vehicle.speed, vehicle._traffic_limit, blocker, vehicle._squeeze_clock,
		relative.dot(forward), relative.cross(Vector3.UP).dot(forward)]
