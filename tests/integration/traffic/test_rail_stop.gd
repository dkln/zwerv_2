extends "res://tests/integration/support/town_test.gd"
## The rail vehicles fit their platforms: they ride, and at every stop with open doors it
## prints how many door leaves are beside the platform. A vehicle that fits has all the
## leaves of one side there (half of them). Each kind of stop is looked at once; the end of
## a track without a platform is no stop to check. Game time runs TIME_SCALE times faster
## while it looks, and it stops once QUIET_SECONDS pass without a stop it had not seen yet.
##   tests/run_integration_tests.sh rail_stop [-- <seconds of game time, default 2400>]

const TEST_SECONDS := 250.0
const TIME_SCALE := 8.0
## It stops once this much game time has passed without a stop it had not seen yet.
const QUIET_SECONDS := 400.0


## A long ride (most of an hour of game time) with an argument, so a run of its own.
static func world_options() -> Dictionary:
	return {"own_process": true}


## The trams and trains of the town.
func _rail_vehicles() -> Array[RailVehicle]:
	var vehicles: Array[RailVehicle] = []
	for child in scene.get_children():
		if child is RailVehicle:
			vehicles.append(child)
	return vehicles


## The stop `vehicle` stands at with its doors open, as a key (the kind of vehicle and where).
func _stop_key(vehicle: RailVehicle) -> String:
	var nose := vehicle.global_position
	return "%s %d %d" % [vehicle.vehicle_kind, roundi(nose.x / 8.0), roundi(nose.z / 8.0)]


## Says how `vehicle` stands at its stop; false when a door leaf misses the platform
## (true too at the end of a track without a platform: no stop to check).
func _fits_platform(vehicle: RailVehicle) -> bool:
	var nose := vehicle.global_position
	var at_cell := "%s at cell (%d, %d, level %d)" % [vehicle.vehicle_kind, floori(nose.x / 4.0), floori(nose.z / 4.0), roundi(nose.y)]
	if vehicle._waiting_before == RailVehicle.NO_CELL and not vehicle._stands_at_platform():
		print("%s: end of the track, no platform" % at_cell)
		return true
	var wanted: int = vehicle._door_leaves.size() / 2
	var opened: int = vehicle._opening_leaves.size()
	print("%s: %d of %d leaves beside the platform" % [at_cell, opened, wanted])
	return opened == wanted


## The trams and trains ride their lines: at every stop seen all the door leaves of one
## side are beside the platform, and there are stops seen at all.
func test_every_door_opens_beside_the_platform(test) -> void:
	var most_seconds := float(argument(0, "2400"))
	var vehicles := _rail_vehicles()
	test.check(not vehicles.is_empty(), "er rijden trams en treinen (%d)" % vehicles.size())
	var steps_before := Engine.max_physics_steps_per_frame
	Engine.time_scale = TIME_SCALE
	Engine.max_physics_steps_per_frame = 16
	var seen := {}      # stop key -> true
	var misses := 0
	var elapsed := 0.0
	var last_new_stop := 0.0
	while elapsed < most_seconds and elapsed - last_new_stop < QUIET_SECONDS:
		await tree.physics_frame
		elapsed += Engine.time_scale / Engine.physics_ticks_per_second
		for vehicle in vehicles:
			if vehicle._door_amount > 0.5 and not seen.has(_stop_key(vehicle)):
				seen[_stop_key(vehicle)] = true
				last_new_stop = elapsed
				if not _fits_platform(vehicle):
					misses += 1
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = steps_before
	print("%d stops seen in %d s of game time, %d where a door misses the platform" % [seen.size(), roundi(elapsed), misses])
	test.check(not seen.is_empty(), "haltes gezien (%d)" % seen.size())
	test.check(misses == 0, "bij elke halte alle deuren langs het perron (%d keer niet)" % misses)
