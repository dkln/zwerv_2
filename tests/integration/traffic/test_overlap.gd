extends "res://tests/integration/support/town_test.gd"
## Lets the traffic of the town drive and reports every time the bodies of two driving
## vehicles overlap (seen from above, no margin) without a crash: vehicles that drive
## through each other. Per overlap it prints the situation once (speeds, headings, whether
## it is on a crossing, who waits for whom). A long simulation with an argument, so a run of
## its own; it is a report: only the traffic being there is checked.
##   tests/run_integration_tests.sh overlap [-- <simulated seconds, default 300>]
##   TRACE=Verkeer4,Verkeer9 ...   also prints these vehicles every half second

const TrafficHelp = preload("res://tests/integration/support/traffic_help.gd")
const TEST_SECONDS := 280.0
const STEP := 1.0 / 60.0
## Metres two footprints must overlap by (each shrunk by this) before it counts.
const SHRINK := 0.15


static func world_options() -> Dictionary:
	return {"own_process": true, "traffic": true}


## Whether the bodies of the two overlap now, on the same level and not passing each other.
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


## The state of `vehicle` for the report, and where `other` is seen from it.
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


## Where a traced vehicle is, its state and the route it plans.
func _trace(vehicle: Vehicle, elapsed: float) -> void:
	print("%6.1f s  %s pos (%.1f, %.1f) %s" % [elapsed, vehicle.name, vehicle.global_position.x, vehicle.global_position.z,
			_describe(vehicle, vehicle)])
	var route := ""
	for index in vehicle._route_cells.size():
		route += " %d,%d%s@%.1f" % [vehicle._route_cells[index].x, vehicle._route_cells[index].z,
				vehicle._route_headings[index], vehicle._route_distances[index]]
	print("        afstand %.1f yield %s route%s" % [vehicle._distance, vehicle.yielding, route])


## The traffic drives for the simulated seconds asked; every pair of vehicles whose bodies
## come to overlap without a crash is reported once, and the number of times at the end.
func test_report_vehicles_driving_through_each_other(test) -> void:
	var simulated_seconds := float(argument(0, "300"))
	await frames(2)
	test.check(not TrafficHelp.vehicles_in_town().is_empty(), "er rijdt verkeer (%d voertuigen)" % TrafficHelp.vehicles_in_town().size())
	var overlapping := {}     # the two vehicles' ids -> true while they overlap
	var overlap_count := 0
	var traced := OS.get_environment("TRACE").split(",", false)
	var elapsed := 0.0
	var trace_clock := 0.0
	while elapsed < simulated_seconds:
		await tree.physics_frame
		elapsed += STEP
		trace_clock += STEP
		# the set round the player changes: the vehicles there now
		var vehicles := TrafficHelp.vehicles_in_town()
		if trace_clock >= 0.5 and not traced.is_empty():
			trace_clock = 0.0
			for vehicle in vehicles:
				if traced.has(vehicle.name):
					_trace(vehicle, elapsed)
		var touching_now := {}
		for first_index in vehicles.size():
			var first := vehicles[first_index]
			for second_index in range(first_index + 1, vehicles.size()):
				var second := vehicles[second_index]
				if first.crashed or second.crashed or not _overlap(first, second):
					continue
				var pair := "%d-%d" % [mini(first.get_instance_id(), second.get_instance_id()), maxi(first.get_instance_id(), second.get_instance_id())]
				touching_now[pair] = true
				if not overlapping.has(pair):
					overlap_count += 1
					print("%6.1f s  OVERLAP\n    %s\n    %s" % [elapsed, _describe(first, second), _describe(second, first)])
		overlapping = touching_now
	print("samen: %d keer door elkaar heen" % overlap_count)
