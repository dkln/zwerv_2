extends RefCounted
## What the suites about the people on foot and the traffic round the player share
## (tests/integration/people/, traffic/): the crowd of an hour made at once, the ticks of
## the traffic, a stand-in for someone on foot. The functions take the suite (a TownTest)
## they work for; what they set in the town is for that test only (TownTest.set_for_test).


## The town at `hour`, the clock standing still, and the people and the traffic round the
## player as that hour wants them, at once (not a few a second) and without a camera
## (nobody in sight, so anyone may go and everything steps every physics step). Waits
## until who comes has a figure (built on a thread) and the numbers are there; after that
## the coming and going is as slow as in the game again, so who is there stays a while.
static func crowd_at_hour(suite: RefCounted, hour: float) -> void:
	var scene: Node3D = suite.scene
	var day: Node = scene.get_node("Dagcyclus")
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var traffic: Traffic = scene.get_node("Verkeer")
	var changes_per_second := walkers.changes_per_second
	var changes_per_tick := traffic.changes_per_tick
	suite.camera_off()
	suite.set_for_test(day, "speed", 0.0)
	suite.set_for_test(day, "time_of_day", hour)
	suite.set_for_test(walkers, "unseen_without_camera", true)
	suite.set_for_test(traffic, "unseen_without_camera", true)
	suite.set_for_test(walkers, "changes_per_second", 1000)
	suite.set_for_test(traffic, "changes_per_tick", 1000)
	walkers._keep_round_player()
	await traffic_ticks(suite, 2)
	for attempt in 150:
		if walkers._arriving.is_empty() and walkers.people().size() >= walkers.wanted_count() \
				and traffic._town.size() >= traffic.wanted_counts().x:
			break
		walkers._keep_round_player()
		await traffic_ticks(suite, 1)
	# from here on as the game: a few changes at a time, nobody sent off for being unseen
	# (so the people and vehicles a test picks stay while it watches them)
	walkers.changes_per_second = changes_per_second
	traffic.changes_per_tick = changes_per_tick
	walkers.unseen_without_camera = false
	traffic.unseen_without_camera = false
	# who was told to become someone else does so once the new figure is built: wait for
	# that too, or the people a test picks change under its hands
	for attempt in 600:
		if not walkers.people().any(func(person: Pedestrian) -> bool: return not person._waiting_become.is_empty()):
			break
		await suite.tree.physics_frame


## A pavement spot (just above it, to put the player on) at least `metres` from every door
## of the station: there nobody is drawn into the station (and gone) while a test watches
## them. Vector3.INF if the town has no such spot.
static func street_away_from_station(suite: RefCounted, metres := 150.0) -> Vector3:
	var walkers: Pedestrians = suite.scene.get_node("Voetgangers")
	walkers._find_station()
	for cell in walkers._walkable_cells:
		var spot := walkers.cell_middle(cell)
		if walkers._near_station(spot) or walkers.links(cell).size() < 2:
			continue
		if walkers._station_doors.all(func(door: Vector3) -> bool: return door.distance_to(spot) >= metres):
			return spot + Vector3.UP * 0.3
	return Vector3.INF


## `ticks` rounds of the traffic's coming and going (Traffic, once every tick_seconds), now.
static func traffic_ticks(suite: RefCounted, ticks: int) -> void:
	var traffic: Traffic = suite.scene.get_node("Verkeer")
	for tick in ticks:
		traffic._tick_clock = 0.0
		await suite.tree.physics_frame
		await suite.tree.physics_frame


## A stand-in for someone on foot (a bare node in the walkers' group, which the traffic
## watches), in the town of `suite`; the same one every time. Put it where the test wants
## it; put_away takes it out of everyone's way again.
static func stand_in(suite: RefCounted) -> Node3D:
	var scene: Node3D = suite.scene
	if scene.has_node("TestLoper"):
		return scene.get_node("TestLoper")
	var person := Node3D.new()
	person.name = "TestLoper"
	person.add_to_group(Vehicle.WALKERS_GROUP)
	scene.add_child(person)
	return person


## `someone` (a stand_in) far under the town, where no vehicle minds it.
static func put_away(someone: Node3D) -> void:
	someone.global_position = Vector3(0.0, -500.0, 0.0)


## The car that drives fastest now (over `at_least` m/s; an ordinary one: no priority, not
## reckless, not crashed), or null.
static func driving_car(at_least := 6.0) -> Vehicle:
	var best: Vehicle = null
	for vehicle in Vehicle.all_vehicles:
		if vehicle.crashed or vehicle.vehicle_kind != "auto" or vehicle.has_priority() or vehicle.reckless:
			continue
		if vehicle.speed > at_least and (best == null or vehicle.speed > best.speed):
			best = vehicle
	return best


## How many of `group` (nodes) are within `metres` of `spot`.
static func near(group: Array, spot: Vector3, metres: float) -> int:
	return group.filter(func(node: Node3D) -> bool: return node.global_position.distance_to(spot) <= metres).size()
