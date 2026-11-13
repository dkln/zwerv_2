extends "res://tests/integration/support/town_test.gd"
## Lets the car of scenes/stad.tscn (node "Auto", scripts/vehicles/car.gd, a Vehicle)
## drive on its own and prints what it did: distance, cells visited, stops, its top speed
## and time per kind of road (against the speed limit), the lowest level it reached (the
## A12 trough is -6), and every moment it was off its lanes, above or below the road
## surface, too fast, or turned more sharply than a corner allows. A measurement with
## arguments (the car's start is set before the town starts), so a run of its own.
##   tests/run_integration_tests.sh drive [-- <simulated seconds> [<start x> <start z> <heading x> <heading z>]]
## e.g. the A12 eastbound from the Koningskade: -- 300 70 24 1 0

const TrafficHelp = preload("res://tests/integration/support/traffic_help.gd")
const MAX_TURN_RATE := 3.0     # rad/s
const KIND_NAMES := ["straat", "hoofdweg", "tunnel", "snelweg"]
const TEST_SECONDS := 280.0


static func world_options() -> Dictionary:
	var options := {"own_process": true}
	# (argument 0 of the run is the name of the suite: the suite's own start at 1)
	if Common.arg_count() >= 6:
		options["settings"] = {"Auto": {
			"start_cell": Vector2i(int(Common.arg_float(2)), int(Common.arg_float(3))),
			"start_heading": Vector2i(int(Common.arg_float(4)), int(Common.arg_float(5)))}}
	return options


## Counts a problem and prints the first five of each sort.
func _problem(problems: Dictionary, sort: String, message: String) -> void:
	problems[sort] += 1
	if problems[sort] <= 5:
		print(sort, ": ", message)


## The car has its model and drives for the given time (argument 0, default 300 s); what
## it did and the problems on the way (off the road, wrong height, too fast, a jerk) are
## printed, not judged.
func test_the_car_drives_on_its_own(test) -> void:
	var drive_seconds := float(argument(0, "300"))
	var car: Vehicle = scene.get_node("Auto")
	var network := car.network
	test.check(car.has_node("Carrosserie/Model"), "de auto heeft een model")
	var elapsed := 0.0
	var distance := 0.0
	var last_position := car.global_position
	var last_yaw := car.rotation.y
	var visited := {}
	var problems := {"naast de weg": 0, "hoogte": 0, "te snel": 0, "ruk": 0}
	var stops := 0
	var standing := 0.0
	var longest_stop := 0.0
	var lowest_level := 0
	var time_per_kind := [0.0, 0.0, 0.0, 0.0]
	var top_per_kind := [0.0, 0.0, 0.0, 0.0]
	while elapsed < drive_seconds:
		await tree.physics_frame
		elapsed += TrafficHelp.STEP
		var position_now := car.global_position
		distance += (position_now - last_position).length()
		last_position = position_now
		var cell := car._cell_under()
		visited[cell] = true
		lowest_level = mini(lowest_level, cell.y)
		var kind := network.kind(cell)
		time_per_kind[kind] += TrafficHelp.STEP
		top_per_kind[kind] = maxf(top_per_kind[kind], car.speed)
		if not network.has(cell):
			_problem(problems, "naast de weg", "t=%.1f cel %s" % [elapsed, cell])
		# the road right under the car (moving over, it crosses cells off its route)
		var under := network.find(floori(position_now.x / RoadNetwork.CELL), floori(position_now.z / RoadNetwork.CELL), cell.y, cell, 2)
		var surface := network.height(under if under != RoadNetwork.NONE else cell, Vector2(position_now.x, position_now.z))
		if absf(position_now.y - surface) > 0.15:
			_problem(problems, "hoogte", "t=%.1f cel %s: %.2f m, wegdek %.2f m" % [elapsed, cell, position_now.y, surface])
		if car.speed > network.speed_limit(cell) + 0.5:
			_problem(problems, "te snel", "t=%.1f cel %s: %.0f km/u, max %.0f" % [elapsed, cell, car.speed * 3.6, network.speed_limit(cell) * 3.6])
		var turn_rate := absf(wrapf(car.rotation.y - last_yaw, -PI, PI)) / TrafficHelp.STEP
		last_yaw = car.rotation.y
		if turn_rate > MAX_TURN_RATE:
			_problem(problems, "ruk", "t=%.1f %.1f rad/s bij %s" % [elapsed, turn_rate, cell])
		if car.speed < 0.05:
			if standing == 0.0:
				stops += 1
			standing += TrafficHelp.STEP
			longest_stop = maxf(longest_stop, standing)
		else:
			standing = 0.0
	print("AUTO: %.0f s, %.0f m (gem. %.1f m/s), %d cellen, %d stops (langste %.1f s), laagste niveau %d" % [
		drive_seconds, distance, distance / drive_seconds, visited.size(), stops, longest_stop, lowest_level])
	for kind in KIND_NAMES.size():
		if time_per_kind[kind] > 0.0:
			print("  %-9s %5.0f s, top %3.0f km/u (max %3.0f)" % [KIND_NAMES[kind], time_per_kind[kind],
				top_per_kind[kind] * 3.6, RoadNetwork.SPEED_LIMIT_KMH[kind]])
	print("  problemen: ", problems)
	test.check(distance > 0.0, "de auto heeft gereden (%.0f m)" % distance)
