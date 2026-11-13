extends RefCounted
## What the traffic suites (tests/integration/traffic/) share: the vehicles of the town now,
## and a name for one in a report.


## The vehicles in the town now (valid and in the tree).
static func vehicles_in_town() -> Array[Vehicle]:
	return Vehicle.all_vehicles.filter(func(vehicle: Vehicle) -> bool: return is_instance_valid(vehicle) and vehicle.is_inside_tree())


## A vehicle named for a report: its node and its model.
static func label(vehicle: Vehicle) -> String:
	return "%s (%s)" % [vehicle.name, vehicle.model.get_file()]


## The world with the traffic spread over the whole town (Traffic.whole_town), not only
## round the player: for a suite's world_options, so those suites share one town.
const WHOLE_TOWN := {"traffic": true, "settings": {"Verkeer": {"whole_town": true}}}
## Seconds of game time per physics step (the tests run at 60 steps a second).
const STEP := 1.0 / 60.0


## A new vehicle of scripts/vehicles/<script_name>.gd that will start on road cell
## `start_cell` heading `start_heading` once it is added to the town (not added here).
static func new_vehicle(script_name: String, start_cell: Vector2i, start_heading: Vector2i) -> Vehicle:
	var vehicle: Vehicle = load("res://scripts/vehicles/%s.gd" % script_name).new()
	vehicle.start_cell = start_cell
	vehicle.start_heading = start_heading
	return vehicle


## The middle value of `values` (0 without any).
static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
