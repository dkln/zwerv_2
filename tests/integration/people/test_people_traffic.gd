extends "res://tests/integration/support/town_test.gd"
## Vehicles and people on foot (scripts/vehicles/vehicle.gd, _watch_people): a vehicle brakes
## for someone standing in its path and stops before them, sounds its horn as it comes, swerves
## round someone at the edge of its path; and the pedestrian lights (traffic_lights.gd
## pedestrian_phase, pedestrians.gd walk_light) go green and red by turns at the zebras of
## intersections with pedestrian lights.
## Impatience: a car that has stood long enough for someone in its way drives on and knocks
## them over (hit_by_vehicle); a pedestrian that is hit loses health, is thrown, gets up again,
## and one whose health runs out lies a while and starts afresh, healthy.
## (The horn of each kind of vehicle: tests/unit/traffic/test_horns.gd.)
## The town with its traffic, and every test without a camera: nothing is out of sight, so
## every vehicle steps every physics step.
##   tests/run_integration_tests.sh people_traffic

const PeopleHelp = preload("res://tests/integration/support/people_help.gd")


static func world_options() -> Dictionary:
	return {"traffic": true}


## An ordinary car driving on at speed, waited for (null if none comes), the camera off.
func _driving_car() -> Vehicle:
	camera_off()
	await wait_until(func() -> bool: return PeopleHelp.driving_car() != null, 60.0)
	return PeopleHelp.driving_car()


## The spot on the route of `car` (which may bend) as far ahead as it needs to stop, and a bit.
func _in_its_path(car: Vehicle) -> Vector3:
	var ahead := car._outer_box.end.z + 4.0 + car.speed * car.speed / (2.0 * car.braking) + car.speed * 0.5
	return car._route_point(car._distance + ahead)


## A car driving on with someone put in its path ahead: it stops, stays clear of them, and
## hoots as it comes.
func test_car_brakes_and_hoots_for_someone_in_its_path(test) -> void:
	var car := await _driving_car()
	test.check(car != null, "een rijdende auto gevonden")
	if car == null:
		return
	var person := PeopleHelp.stand_in(self)
	person.global_position = _in_its_path(car)
	var hooted := car._horn_clock > 0.0
	var closest := INF
	for step in 360:
		await tree.physics_frame
		var gap := car.global_position.distance_to(person.global_position) - car._outer_box.end.z
		closest = minf(closest, gap)
		hooted = hooted or car._horn_clock > 0.0
		if car.speed < 0.05 and step > 30:
			break
	test.check(car.speed < 0.3, "%s stopt voor iemand op zijn pad (%.1f m/s)" % [car.name, car.speed])
	test.check(closest > 0.5, "en blijft er %.1f m voor staan" % closest)
	test.check(hooted, "en toetert (%s)" % car._horn())
	PeopleHelp.put_away(person)


## Someone at the edge of a car's path: it swerves the other way.
func test_car_swerves_round_someone_at_the_edge(test) -> void:
	var car := await _driving_car()
	test.check(car != null, "een rijdende auto gevonden")
	if car == null:
		return
	var person := PeopleHelp.stand_in(self)
	var forward := Vector3(car.global_basis.z.x, 0.0, car.global_basis.z.z).normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var edge := car._outer_box.size.x * 0.5 + 0.3
	person.global_position = car.global_position + forward * (car._outer_box.end.z + 6.0) + right * edge
	var swerved := 0.0
	for step in 16:
		await tree.physics_frame
		swerved = minf(swerved, car._dodge)
	test.check(swerved < -0.1, "%s wijkt uit voor iemand aan de rand van zijn pad (%.2f m)" % [car.name, swerved])
	PeopleHelp.put_away(person)


## A car stopped for someone who does not go away: after IMPATIENT_AFTER seconds it pushes
## through and knocks them over (hit_by_vehicle).
func test_impatient_car_drives_on_and_knocks_them_over(test) -> void:
	var car := await _driving_car()
	test.check(car != null, "een rijdende auto gevonden (ongeduld)")
	if car == null:
		return
	# someone who counts how often they are hit
	var recorder := GDScript.new()
	recorder.source_code = "extends Node3D\nvar hits := 0\nfunc hit_by_vehicle(_vehicle, _push) -> void:\n\thits += 1\n"
	recorder.reload()
	var victim := Node3D.new()
	victim.set_script(recorder)
	victim.name = "TestSlachtoffer"
	victim.add_to_group(Vehicle.WALKERS_GROUP)
	scene.add_child(victim)
	victim.global_position = _in_its_path(car)
	var stood := false
	var pushed := false
	for step in int((Vehicle.IMPATIENT_AFTER + 16.0) * 60.0):
		await tree.physics_frame
		stood = stood or car.speed < 0.05
		pushed = pushed or car.is_pushing_through()
		if step % 30 == 0 and car.is_pushing_through():
			var to_victim := victim.global_position - car.global_position
			print("    duwt: %.1f m/s, %.2f m voor de neus, %.2f opzij, hoogte %.2f; verkeer %.1f (%s), regel %s, mensen %.1f" % [car.speed,
				to_victim.dot(car.global_basis.z) - car._outer_box.end.z, to_victim.dot(car.global_basis.x), to_victim.y,
				car._traffic_limit, car._blocked_by.name if car._blocked_by else "-", car._held_by_rule, car._people_limit])
		if victim.hits > 0:
			break
	test.check(stood, "%s stopt eerst voor wie in de weg staat" % car.name)
	test.check(pushed, "na %.0f s wachten rijdt hij ongeduldig door" % Vehicle.IMPATIENT_AFTER)
	test.check(victim.hits > 0, "en rijdt wie in de weg blijft staan omver (%.1f m/s)" % car.speed)
	victim.free()


## A pedestrian given a gentle push by a car loses health, falls (the traffic no longer
## stops for them) and gets up again, the figure back with them.
func test_pedestrian_hit_falls_and_gets_up(test) -> void:
	var car := await _driving_car()
	var people: Array[Pedestrian] = (scene.get_node("Voetgangers") as Pedestrians).people()
	test.check(car != null and not people.is_empty(), "een auto en een voetganger voor de aanrijding")
	if car == null or people.is_empty():
		return
	var walker: Pedestrian = people[0]
	var before := walker.health
	# a gentle push (as an impatient car's): 3 m/s
	car.velocity = car.global_basis.z * 3.0
	walker.hit_by_vehicle(car, car.velocity * 0.8 + Vector3.UP)
	test.check(walker.health < before, "voetganger verliest gezondheid (%.0f -> %.0f, %.1f m/s)" % [before, walker.health, car.velocity.length()])
	test.check(walker._ragdoll != null and not walker.is_in_group(Vehicle.WALKERS_GROUP), "valt om (en het verkeer stopt er niet voor)")
	for step in int(Pedestrian.KNOCK_DOWN_TIME * 3.0 * 60.0 + 30):
		await tree.physics_frame
		if walker._ragdoll == null:
			break
	test.check(walker._ragdoll == null and walker.is_in_group(Vehicle.WALKERS_GROUP), "staat weer op")
	test.check(walker._drawn.get_parent() == walker, "figuur weer bij de voetganger")


## A pedestrian whose health runs out at a hard blow lies a while and starts afresh, healthy.
func test_pedestrian_out_of_health_starts_afresh(test) -> void:
	var car := await _driving_car()
	var people: Array[Pedestrian] = (scene.get_node("Voetgangers") as Pedestrians).people()
	test.check(car != null and not people.is_empty(), "een auto en een voetganger voor de aanrijding")
	if car == null or people.is_empty():
		return
	var walker: Pedestrian = people[0]
	walker.health = 1.0
	walker.hit_by_vehicle(car, car.velocity * 0.8)
	test.check(walker.health <= 0.0 and walker._ragdoll != null, "een harde klap: dood")
	await physics_frames(int((Pedestrian.DEAD_LIE + 1.0) * 60.0))
	test.check(walker._ragdoll == null and walker.health == Pedestrian.MAX_HEALTH, "begint daarna opnieuw, gezond")


## There are zebras with pedestrian lights, and over a cycle of the lights they show green
## and red by turns.
func test_pedestrian_lights_go_green_and_red(test) -> void:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var lights: Node = scene.get_node("Verkeerslichten")
	var time_before: float = lights._time
	var with_lights := 0
	var green_seen := false
	var red_seen := false
	for cell: Vector3i in walkers._links.keys():
		if not walkers.is_zebra(cell):
			continue
		var ways: Array = walkers.links(cell)
		if ways.is_empty():
			continue
		var side: Vector3i = (ways[0] as Vector3i) - cell
		if walkers.walk_light(cell, side) < 0:
			continue
		with_lights += 1
		for second in 50:
			lights._time = float(second)
			var now := walkers.walk_light(cell, side)
			green_seen = green_seen or now == 0
			red_seen = red_seen or now == 1
	lights._time = time_before
	print("zebracellen met voetgangerslichten: %d" % with_lights)
	test.check(with_lights > 0, "er zijn zebrapaden met voetgangerslichten")
	test.check(green_seen and red_seen, "voetgangerslicht wordt groen en rood")
