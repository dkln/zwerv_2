extends "res://tests/integration/support/town_test.gd"
## The clustered lookup of the vehicles (Vehicle.near, buckets of Vehicle.BUCKET_SIZE metres,
## filled once per physics frame): with the town full of traffic, for many spots and radii it
## must give every vehicle the old way (going through all of them) finds within the radius plus
## its own reach, never fewer (a few more is fine), and far fewer than all of them. Also
## Traffic._apart (room for a new vehicle) must agree with going through all vehicles.
## The whole town full of traffic (160 vehicles, all kept), so a world of its own.
##   tests/run_integration_tests.sh vehicle_buckets

const TrafficHelp = preload("res://tests/integration/support/traffic_help.gd")
const SPOTS := 400
const RADII := [0.0, 4.0, 12.0, 32.0, 80.0]


static func world_options() -> Dictionary:
	return {"traffic": 160, "settings": {"Verkeer": {"whole_town": true}}}


## The same random numbers every time.
func _seeded() -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = 3
	return random


## SPOTS spots on and round the vehicles and anywhere in the town, each asked with every
## radius of RADII: {"missed" (vehicles within reach that Vehicle.near left out),
## "average" (vehicles given per question)}.
func _ask_near(vehicles: Array[Vehicle]) -> Dictionary:
	var random := _seeded()
	var missed := 0
	var looked := 0
	var found_total := 0
	for spot_index in SPOTS:
		var spot: Vector3
		if spot_index % 2 == 0:
			spot = vehicles[random.randi() % vehicles.size()].global_position + Vector3(random.randf_range(-20.0, 20.0), 0.0, random.randf_range(-20.0, 20.0))
		else:
			spot = Vector3(random.randf_range(0.0, 900.0), 0.0, random.randf_range(0.0, 700.0))
		for radius: float in RADII:
			var near := Vehicle.near(spot, radius)
			found_total += near.size()
			looked += 1
			for vehicle in vehicles:
				if vehicle.global_position.distance_to(spot) <= radius + vehicle._reach() and not vehicle in near:
					missed += 1
	return {"missed": missed, "average": float(found_total) / maxf(looked, 1)}


## The vehicles of the full town, after a physics frame (the buckets filled for this frame).
func _vehicles_this_frame() -> Array[Vehicle]:
	await tree.physics_frame
	return TrafficHelp.vehicles_in_town()


## The town is full of traffic and Vehicle.near never leaves out a vehicle that going
## through all of them finds.
func test_near_never_misses_a_vehicle(test) -> void:
	var vehicles := await _vehicles_this_frame()
	print("voertuigen in de stad: %d" % vehicles.size())
	test.check(vehicles.size() > 100, "de stad zit vol verkeer (%d)" % vehicles.size())
	if vehicles.is_empty():
		return
	var asked := _ask_near(vehicles)
	test.check(asked.missed == 0, "Vehicle.near mist er nooit een (%d gemist)" % asked.missed)


## A question looks at far fewer vehicles than all of them.
func test_near_looks_at_far_fewer_than_all(test) -> void:
	var vehicles := await _vehicles_this_frame()
	test.check(not vehicles.is_empty(), "er is verkeer")
	if vehicles.is_empty():
		return
	var average: float = _ask_near(vehicles).average
	print("gemiddeld %.1f van de %d voertuigen bekeken per vraag" % [average, vehicles.size()])
	test.check(average < vehicles.size() * 0.5, "en bekijkt er veel minder dan allemaal (%.1f van %d)" % [average, vehicles.size()])


## Room for a new vehicle on a road cell (Traffic._apart): the same answer as going through
## all the vehicles.
func test_room_for_a_new_vehicle_as_going_through_all(test) -> void:
	var vehicles := await _vehicles_this_frame()
	var traffic: Traffic = scene.get_node("Verkeer")
	var random := _seeded()
	var network := RoadNetwork.of(scene)
	var cells := network.cells()
	var disagree := 0
	for try_index in 300:
		var cell: Vector3i = cells[random.randi() % cells.size()]
		var centre := network.centre(cell)
		var free_the_old_way := vehicles.all(func(vehicle: Vehicle) -> bool: return vehicle.global_position.distance_to(centre) >= traffic.spacing)
		var empty: Array[Vector3] = []
		if traffic._apart(cell, empty) != free_the_old_way:
			disagree += 1
	test.check(disagree == 0, "ruimte voor een nieuwe: als vroeger (%d anders)" % disagree)
