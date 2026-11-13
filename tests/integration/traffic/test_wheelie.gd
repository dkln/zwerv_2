extends "res://tests/integration/support/town_test.gd"
## Wheelies in the town (scripts/vehicles/wheelie.gd): the fatbikes, mopeds, scooters and
## motorbikes (TwoWheeler `wheelie_degrees`) and the wheelchairs (Pedestrian,
## MobilityAid.tilt) lift their front on the rear wheel, that wheel staying on the road, and
## in a wheelie they are daredevils. The Wheelie helper itself and the riders' cocky lines
## are unit tests (tests/unit/traffic/test_wheelie.gd).
##   tests/run_integration_tests.sh wheelie

const Wheelie = preload("res://scripts/vehicles/wheelie.gd")
const TrafficHelp = preload("res://tests/integration/support/traffic_help.gd")
## Frames a forced wheelie is watched.
const WATCHED_FRAMES := 60


static func world_options() -> Dictionary:
	return {"traffic": true, "still_camera": true, "without": ["DetailNiveau", "Rook", "Camera", "Doorkijk"]}


## The two-wheelers in the town that can do a wheelie.
func _riders() -> Array[TwoWheeler]:
	var riders: Array[TwoWheeler] = []
	for vehicle in TrafficHelp.vehicles_in_town():
		var two_wheeler := vehicle as TwoWheeler
		if two_wheeler and two_wheeler._wheelie:
			riders.append(two_wheeler)
	return riders


## The people in wheelchairs that can do a wheelie.
func _chairs() -> Array:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	return walkers.people().filter(func(person: Pedestrian) -> bool: return is_instance_valid(person) and person._wheelie != null)


## Every test without a camera (the shared town may have one: then the riders out of view
## leave their wheelie alone), every vehicle looking again at once whether it is seen, and
## at least one wheelchair in town (they are few: someone on foot gets one, as Pedestrians
## does for who it owes one).
func _set_up() -> void:
	camera_off()
	for vehicle in TrafficHelp.vehicles_in_town():
		vehicle._sight_countdown = 0
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	if _chairs().is_empty():
		for person: Pedestrian in walkers.people():
			if person.aid == null and person.mobility == "" and person.role == "" and person._ragdoll == null \
					and person._waiting_become.is_empty():
				person.become(person.walker_seed, person.wanted_look, "rolstoel", 1.0, "", person.crowd_kind)
				break
		await wait_until(func() -> bool: return not _chairs().is_empty(), 10.0)
	await physics_frames(2)


## A wheelie started now, at its full height, kept up for seconds.
func _force(wheelie: Wheelie) -> void:
	wheelie._up_left = 5.0
	wheelie._height = wheelie.most_angle


## Puts every wheelie back down.
func _end_wheelies() -> void:
	for rider in _riders():
		rider._wheelie.stop()
	for person: Pedestrian in _chairs():
		person._wheelie.stop()


## Forced into a wheelie, the two-wheelers lift their front while the rear wheel's contact
## point stays where it was on the road.
func test_two_wheelers_go_up_on_the_rear_wheel(test) -> void:
	await _set_up()
	var riders := _riders()
	test.check(riders.size() > 0, "tweewielers die een wheelie kunnen (%d)" % riders.size())
	for rider in riders:
		_force(rider._wheelie)
	var most_pitch := 0.0
	var worst_rear_lift := 0.0
	for frame_index in WATCHED_FRAMES:
		await tree.process_frame
		for rider in riders:
			if not is_instance_valid(rider) or rider._wheelie.angle < 0.05:
				continue
			# the body's front up compared with the vehicle itself
			most_pitch = maxf(most_pitch, rider.global_basis.z.angle_to(rider._body.global_basis.z))
			# the rear wheel's contact point stays where it was
			var on_road := rider._body.global_transform * rider._rear_contact
			var unturned := rider._body.global_transform * rider._wheelie.tilt_about(rider._rear_contact).affine_inverse() * rider._rear_contact
			worst_rear_lift = maxf(worst_rear_lift, on_road.distance_to(unturned))
	print("hoogste wheelie: %.1f graden, achterwiel verschoven %.3f m" % [rad_to_deg(most_pitch), worst_rear_lift])
	test.check(most_pitch > deg_to_rad(5.0), "tweewielers gaan op het achterwiel")
	test.check(worst_rear_lift < 0.01, "achterwiel blijft op de weg")
	_end_wheelies()


## Forced into a wheelie, the wheelchairs tip back onto their big wheels, and one in a
## wheelie is a daredevil that tears along.
func test_wheelchairs_go_up_on_the_big_wheels(test) -> void:
	await _set_up()
	var chairs := _chairs()
	test.check(chairs.size() > 0, "rolstoelen die een wheelie kunnen (%d)" % chairs.size())
	for person: Pedestrian in chairs:
		_force(person._wheelie)
	var most_chair := 0.0
	for frame_index in WATCHED_FRAMES:
		await tree.process_frame
		for person: Pedestrian in chairs:
			if is_instance_valid(person):
				most_chair = maxf(most_chair, absf((person.aid._tilt as Node3D).rotation.x))
	print("rolstoel %.1f graden" % rad_to_deg(most_chair))
	test.check(most_chair > deg_to_rad(5.0), "rolstoelen gaan op de grote wielen")
	for chair: Pedestrian in chairs:
		if is_instance_valid(chair) and chair._wheelie.is_up():
			test.check(chair.is_daredevil() and chair.daredevil_pace() > 1.5, "een rolstoel in een wheelie scheurt (x%.1f)" % chair.daredevil_pace())
			break
	_end_wheelies()


## A two-wheeler in a wheelie is a daredevil: far over its usual speed, and it brakes for
## neither traffic nor pedestrians.
func test_in_a_wheelie_a_daredevil(test) -> void:
	await _set_up()
	var riders := _riders()
	for rider in riders:
		_force(rider._wheelie)
	await frames(WATCHED_FRAMES)
	var up := riders.filter(func(rider: TwoWheeler) -> bool: return is_instance_valid(rider) and rider._wheelie.is_up())
	var all_daredevils := not up.is_empty()
	var faster := true
	for rider: TwoWheeler in up:
		all_daredevils = all_daredevils and rider.daredevil
		var usual := minf(rider.top_speed_kmh / 3.6, rider.speed_limit)
		faster = faster and rider.daredevil_speed() > usual * 1.2
	test.check(all_daredevils, "in een wheelie een waaghals (%d)" % up.size())
	test.check(faster, "de waaghals rijdt veel harder dan normaal")
	if not up.is_empty():
		var stunting: TwoWheeler = up[0]
		stunting._people_limit = 0.0
		stunting._traffic_limit = 0.0
		var target := stunting._target_speed(1.0 / 60.0)
		test.check(target > 1.0, "de waaghals remt niet voor verkeer of voetgangers (%.1f m/s)" % target)
	_end_wheelies()
