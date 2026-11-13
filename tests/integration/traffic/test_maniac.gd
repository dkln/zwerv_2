extends "res://tests/integration/support/town_test.gd"
## An idiot at the wheel (Vehicle.maniac): a few cars of the whole town made drunk or
## aggressive, the rest normal. Per kind it prints how far over the speed limit they went,
## how far on average the body turned away from the road's own direction on a straight road
## (the weave is steered: the body turns, it does not slide sideways), and the crashes. The
## idiots should go faster and steer to and fro; the normal cars hardly. (Headless every
## vehicle counts as out of sight, so the front wheels are not turned here; in view they
## follow the front axle.) With a second argument it also prints the first idiot every
## quarter of a second.
##   tests/run_integration_tests.sh maniac [-- <simulated seconds, default 40> [volg]]

const TrafficHelp = preload("res://tests/integration/support/traffic_help.gd")
const MANIACS := ["dronken", "dronken", "agressief", "agressief"]
const KINDS := ["dronken", "agressief", "gewoon"]


static func world_options() -> Dictionary:
	return TrafficHelp.WHOLE_TOWN


## True if the road runs straight from a few metres behind its front axle to a few ahead (no
## corner there, so any turn of the body or the wheels is steering of its own).
func _straight_ahead(vehicle: Vehicle) -> bool:
	return absf(vehicle._bend_ahead(vehicle._distance + vehicle._front_axle)) < 0.01 \
		and absf(vehicle._bend_ahead(vehicle._distance + vehicle._front_axle + 6.0)) < 0.01


## The direction of the road round the front axle of `vehicle` (from 2 m behind it to 2 m ahead).
func _road_direction(vehicle: Vehicle) -> Vector2:
	return vehicle._rounded_route_point(vehicle._distance + vehicle._front_axle + 2.0) \
		- vehicle._rounded_route_point(vehicle._distance + vehicle._front_axle - 2.0)


## Makes the first cars of the town drunk or aggressive (MANIACS) and lets everyone drive
## for `drive_seconds`; returns per kind (KINDS) the most a car went over the limit
## ("over_limit", a factor), the mean angle of the body to a straight road ("body_turn",
## degrees) and the crashes. Afterwards the cars are normal again.
func _drive_with_maniacs(drive_seconds: float, follow_first: bool) -> Dictionary:
	var kinds := {}   # vehicle -> "dronken", "agressief" or "gewoon"
	var made := 0
	for vehicle in TrafficHelp.vehicles_in_town():
		if vehicle.vehicle_kind != "auto" or vehicle.emergency:
			continue
		if made < MANIACS.size() and vehicle.maniac == "":
			vehicle.maniac = MANIACS[made]
			kinds[vehicle] = MANIACS[made]
			made += 1
		else:
			kinds[vehicle] = "gewoon" if vehicle.maniac == "" else vehicle.maniac
	var over_limit := {}
	var body_turn := {}
	var straight_samples := {}
	var crashes := {}
	for kind: String in KINDS:
		over_limit[kind] = 0.0
		body_turn[kind] = 0.0
		straight_samples[kind] = 0
		crashes[kind] = 0
	if kinds.is_empty():
		return {"over_limit": over_limit, "body_turn": body_turn, "crashes": crashes, "made": 0}
	var was_crashed := {}
	var elapsed := 0.0
	var watched: Vehicle = kinds.keys()[0]
	var printed_at := 0.0
	while elapsed < drive_seconds:
		await tree.physics_frame
		elapsed += TrafficHelp.STEP
		if follow_first and is_instance_valid(watched) and elapsed - printed_at > 0.25:
			printed_at = elapsed
			print("%5.2f %s v %.1f weave %.2f zij %.2f stuur %.1f romp-weg %.1f bocht %.3f onzichtbaar %s" % [elapsed, watched.maniac, watched.speed, watched._weave, watched._side_offset,
				rad_to_deg(watched._steering), rad_to_deg(_road_direction(watched).angle_to(Vector2(watched.global_basis.z.x, watched.global_basis.z.z))), watched._bend_ahead(watched._distance + watched._front_axle), watched.unseen])
		for vehicle: Variant in kinds:
			if not is_instance_valid(vehicle):
				continue
			var kind: String = kinds[vehicle]
			if vehicle.crashed:
				if not was_crashed.get(vehicle, false):
					crashes[kind] += 1
				was_crashed[vehicle] = true
				continue
			was_crashed[vehicle] = false
			var limit: float = vehicle.network.speed_limit(vehicle._cell_under()) if vehicle.network else 0.0
			if limit > 0.5:
				over_limit[kind] = maxf(over_limit[kind], vehicle.speed / limit)
			if vehicle.speed < 3.0 or not _straight_ahead(vehicle):
				continue
			var road := _road_direction(vehicle)
			var body := Vector2(vehicle.global_basis.z.x, vehicle.global_basis.z.z)
			if road.length_squared() > 0.01 and body.length_squared() > 0.01:
				body_turn[kind] += rad_to_deg(absf(road.angle_to(body)))
				straight_samples[kind] += 1
	for kind: String in KINDS:
		body_turn[kind] /= maxf(straight_samples[kind], 1)
		print("%-10s harder dan de limiet tot %.2fx, carrosserie gemiddeld %4.1f graden van de weg (rechtdoor), botsingen %d" % [
			kind, over_limit[kind], body_turn[kind], crashes[kind]])
	for vehicle: Variant in kinds:
		if is_instance_valid(vehicle) and kinds[vehicle] != "gewoon":
			vehicle.maniac = ""
	return {"over_limit": over_limit, "body_turn": body_turn, "crashes": crashes, "made": made}


## The drive of this test: argument 0 the game seconds (default 40), argument 1 (anything)
## to print the first idiot as it goes.
func _drive() -> Dictionary:
	return await _drive_with_maniacs(float(argument(0, "40")), argument(1) != "")


## The drunk and the aggressive drivers go well over the speed limit, the normal cars do not.
func test_maniacs_drive_faster_than_the_limit(test) -> void:
	var drive := await _drive()
	test.check(drive.made == MANIACS.size(), "vier auto's tot idioot gemaakt (%d)" % drive.made)
	test.check(drive.over_limit.dronken > 1.15 and drive.over_limit.agressief > 1.4, "idioten rijden harder dan de limiet")
	test.check(drive.over_limit.gewoon < 1.1, "gewone auto's niet")


## On a straight road the drunk steers to and fro (the body turns with it), the aggressive
## one too but less; both clearly more than the normal cars.
func test_maniacs_weave_on_a_straight_road(test) -> void:
	var drive := await _drive()
	test.check(drive.body_turn.dronken > 1.5 and drive.body_turn.dronken > drive.body_turn.gewoon * 2.0, "de dronkaard stuurt heen en weer (de carrosserie draait mee)")
	test.check(drive.body_turn.agressief > drive.body_turn.gewoon * 1.5, "de agressieveling ook, wat minder")
