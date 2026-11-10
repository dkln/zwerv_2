extends SceneTree
## Vehicles and people on foot (scripts/vehicles/vehicle.gd, _watch_people): a vehicle brakes
## for someone standing in its path and stops before them, sounds its horn as it comes, swerves
## round someone at the edge of its path; each kind has its own horn (a bell on a bicycle);
## and the pedestrian lights (traffic_lights.gd pedestrian_phase, pedestrians.gd walk_light)
## go green and red by turns at the zebras of intersections with pedestrian lights.
## Impatience: a car that has stood long enough for someone in its way drives on and knocks
## them over (hit_by_vehicle); a pedestrian that is hit loses health, is thrown, gets up again,
## and one whose health runs out lies a while and starts afresh, healthy.
## usage: tools/godot.sh --headless --script tools/check/people_traffic_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("martin")
	# no camera: nothing is out of sight, every vehicle steps every physics step
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten", "Verhaal", "Camera", "Doorkijk"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	for frame_index in 240:
		await physics_frame
	_check_horns()
	await _check_braking(scene)
	await _check_swerving(scene)
	await _check_impatience(scene)
	await _check_pedestrian_hit(scene)
	_check_walk_lights(scene)
	print("voetgangers en verkeer ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check_horns() -> void:
	var kinds := {"cyclist": "fiets_bel", "fatbike": "fiets_bel", "moped": "brommer_toeter", "city_bus": "bus_toeter",
		"hatchback": "auto_toeter", "truck": "bus_toeter", "fire_engine": "brandweer_hoorn", "randstadrail": "tram_bel"}
	for script_name: String in kinds:
		var vehicle: Vehicle = load("res://scripts/vehicles/%s.gd" % script_name).new()
		var horn := vehicle._horn()
		_check(horn == kinds[script_name], "%s waarschuwt met %s (%s)" % [script_name, kinds[script_name], horn])
		_check(ResourceLoader.exists("res://assets/audio/geluiden/%s.ogg" % horn), "geluid %s bestaat" % horn)
		vehicle.free()


## A car driving on: someone put in its path ahead, it stops before them and hoots.
func _check_braking(scene: Node) -> void:
	var car := _driving_car()
	if car == null:
		_problems.append("geen rijdende auto gevonden")
		return
	var person := _stand_in(scene)
	var ahead := car._outer_box.end.z + 4.0 + car.speed * car.speed / (2.0 * car.braking) + car.speed * 0.5
	var hooted := car._horn_clock > 0.0
	var closest := INF
	for step in 360:
		# the person keeps standing that far ahead of where the car first was, on its path
		if step == 0:
			# on its route (which may bend), as far ahead as it needs to stop and a bit
			person.global_position = car._route_point(car._distance + ahead)
		await physics_frame
		var gap := car.global_position.distance_to(person.global_position) - car._outer_box.end.z
		closest = minf(closest, gap)
		hooted = hooted or car._horn_clock > 0.0
		if car.speed < 0.05 and step > 30:
			break
	_check(car.speed < 0.3, "%s stopt voor iemand op zijn pad (%.1f m/s)" % [car.name, car.speed])
	_check(closest > 0.5, "en blijft er %.1f m voor staan" % closest)
	_check(hooted, "en toetert (%s)" % car._horn())
	person.global_position = Vector3(0.0, -500.0, 0.0)
	for step in 20:
		await physics_frame


## Someone at the edge of a car's path: it swerves the other way.
func _check_swerving(scene: Node) -> void:
	var car := _driving_car()
	if car == null:
		return
	var person := _stand_in(scene)
	var forward := Vector3(car.global_basis.z.x, 0.0, car.global_basis.z.z).normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var edge := car._outer_box.size.x * 0.5 + 0.3
	person.global_position = car.global_position + forward * (car._outer_box.end.z + 6.0) + right * edge
	var swerved := 0.0
	for step in 16:
		await physics_frame
		swerved = minf(swerved, car._dodge)
	_check(swerved < -0.1, "%s wijkt uit voor iemand aan de rand van zijn pad (%.2f m)" % [car.name, swerved])
	person.global_position = Vector3(0.0, -500.0, 0.0)


func _check_walk_lights(scene: Node) -> void:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var lights: Node = scene.get_node("Verkeerslichten")
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
		var phase := walkers.walk_light(cell, side)
		if phase < 0:
			continue
		with_lights += 1
		for second in 50:
			lights._time = float(second)
			var now := walkers.walk_light(cell, side)
			green_seen = green_seen or now == 0
			red_seen = red_seen or now == 1
	print("zebracellen met voetgangerslichten: %d" % with_lights)
	_check(with_lights > 0, "er zijn zebrapaden met voetgangerslichten")
	_check(green_seen and red_seen, "voetgangerslicht wordt groen en rood")


## A car stopped for someone who does not go away: after IMPATIENT_AFTER s it pushes
## through, and touches them (hit_by_vehicle).
func _check_impatience(scene: Node) -> void:
	var car := _driving_car()
	if car == null:
		_problems.append("geen rijdende auto gevonden (ongeduld)")
		return
	var person := _stand_in(scene)
	var recorder := GDScript.new()
	recorder.source_code = "extends Node3D\nvar hits := 0\nfunc hit_by_vehicle(_vehicle, _push) -> void:\n\thits += 1\n"
	recorder.reload()
	var victim := Node3D.new()
	victim.set_script(recorder)
	victim.name = "TestSlachtoffer"
	victim.add_to_group(Vehicle.WALKERS_GROUP)
	scene.add_child(victim)
	var ahead := car._outer_box.end.z + 4.0 + car.speed * car.speed / (2.0 * car.braking) + car.speed * 0.5
	victim.global_position = car._route_point(car._distance + ahead)
	var stood := false
	var pushed := false
	for step in int((Vehicle.IMPATIENT_AFTER + 16.0) * 60.0):
		await physics_frame
		stood = stood or car.speed < 0.05
		pushed = pushed or car.is_pushing_through()
		if step % 30 == 0 and car.is_pushing_through():
			var to_victim := victim.global_position - car.global_position
			print("    duwt: %.1f m/s, %.2f m voor de neus, %.2f opzij, hoogte %.2f" % [car.speed,
				to_victim.dot(car.global_basis.z) - car._outer_box.end.z, to_victim.dot(car.global_basis.x), to_victim.y])
		if victim.hits > 0:
			break
	_check(stood, "%s stopt eerst voor wie in de weg staat" % car.name)
	_check(pushed, "na %.0f s wachten rijdt hij ongeduldig door" % Vehicle.IMPATIENT_AFTER)
	_check(victim.hits > 0, "en rijdt wie in de weg blijft staan omver (%.1f m/s)" % car.speed)
	victim.queue_free()
	person.global_position = Vector3(0.0, -500.0, 0.0)
	for step in 20:
		await physics_frame


## A pedestrian hit: loses health, is thrown, gets up again; out of health it lies a while
## and starts afresh, healthy.
func _check_pedestrian_hit(scene: Node) -> void:
	var car := _driving_car()
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var people := walkers.people()
	if car == null or people.is_empty():
		_problems.append("geen auto of voetganger voor de aanrijding")
		return
	var walker: Pedestrian = people[0]
	var before := walker.health
	# a gentle push (as an impatient car's): 3 m/s
	car.velocity = car.global_basis.z * 3.0
	walker.hit_by_vehicle(car, car.velocity * 0.8 + Vector3.UP)
	_check(walker.health < before, "voetganger verliest gezondheid (%.0f -> %.0f, %.1f m/s)" % [before, walker.health, car.velocity.length()])
	_check(walker._ragdoll != null and not walker.is_in_group(Vehicle.WALKERS_GROUP), "valt om (en het verkeer stopt er niet voor)")
	for step in int(Pedestrian.KNOCK_DOWN_TIME * 3.0 * 60.0 + 30):
		await physics_frame
		if walker._ragdoll == null:
			break
	_check(walker._ragdoll == null and walker.is_in_group(Vehicle.WALKERS_GROUP), "staat weer op")
	_check(walker._drawn.get_parent() == walker, "figuur weer bij de voetganger")
	walker.health = 1.0
	car = _driving_car()
	if car == null:
		return
	walker.hit_by_vehicle(car, car.velocity * 0.8)
	_check(walker.health <= 0.0 and walker._ragdoll != null, "een harde klap: dood")
	for step in int((Pedestrian.DEAD_LIE + 1.0) * 60.0):
		await physics_frame
	_check(walker._ragdoll == null and walker.health == Pedestrian.MAX_HEALTH, "begint daarna opnieuw, gezond")


## A stand-in for someone on foot (in the walkers' group), put where the test wants it.
func _stand_in(scene: Node) -> Node3D:
	if scene.has_node("TestLoper"):
		return scene.get_node("TestLoper")
	var person := Node3D.new()
	person.name = "TestLoper"
	person.add_to_group(Vehicle.WALKERS_GROUP)
	scene.add_child(person)
	return person


func _driving_car() -> Vehicle:
	var best: Vehicle = null
	for vehicle in Vehicle.all_vehicles:
		if vehicle.crashed or vehicle.vehicle_kind != "auto" or vehicle.has_priority() or vehicle.reckless:
			continue
		if vehicle.speed > 6.0 and (best == null or vehicle.speed > best.speed):
			best = vehicle
	return best


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
