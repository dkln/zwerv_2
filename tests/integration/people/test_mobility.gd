extends "res://tests/integration/support/town_test.gd"
## Wheelchairs and mobility scooters (scripts/world/mobility_aid.gd, Pedestrian `mobility`):
## some townspeople ride them; they ride about (the wheels rolling through the wheel shader,
## the casters swivelling round their upright axle, the scooter's front wheel steering), the
## rider sits with the feet on the footrests and the hands on the rims or grips, the collider
## holds chair and rider, a scooter someone stands in front of hoots, and the bicycle paths
## are open to the scooters (not to people on foot). By day and without a camera (nothing
## is out of sight, so everyone is drawn moving).
##   tests/run_integration_tests.sh mobility

const PeopleHelp = preload("res://tests/integration/support/people_help.gd")
## Seconds (game time) the riders get to ride about.
const RIDE_SECONDS := 20


## Whether this test has put the player away from the station already (near it people walk
## off into it and are gone while the test watches them).
var has_moved := false


## The people of the town at midday who ride an aid (`mobility`: "rolstoel", "scootmobiel",
## or "" for both).
func _riders(mobility := "") -> Array:
	if not has_moved:
		has_moved = true
		await put_player(PeopleHelp.street_away_from_station(self))
	await PeopleHelp.crowd_at_hour(self, 13.0)
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	return walkers.people().filter(func(person: Pedestrian) -> bool:
		return person.aid != null and (mobility == "" or person.mobility == mobility))


## By day there are both wheelchairs and mobility scooters among the townspeople.
func test_wheelchairs_and_scooters_in_town(test) -> void:
	var chairs := (await _riders("rolstoel")).size()
	var scooters := (await _riders("scootmobiel")).size()
	test.check(chairs > 0 and scooters > 0, "rolstoelen (%d) en scootmobielen (%d) in de stad" % [chairs, scooters])


## The bicycle paths are there for the scooters, and not for who walks.
func test_bicycle_paths_for_scooters_only(test) -> void:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	test.check(walkers._ride.size() > 0, "fietspaden voor de scootmobiel (%d cellen)" % walkers._ride.size())
	var ride_cell: Vector3i = walkers._ride.keys()[0] if walkers._ride.size() > 0 else Vector3i.ZERO
	test.check(walkers.may_use(ride_cell, "scootmobiel") and not walkers.may_use(ride_cell, ""), "fietspad wel voor de scootmobiel, niet voor wie loopt")


## Every rider sits with the feet on the footrests and the hands on the rims (wheelchair)
## or the grips (scooter).
func test_riders_sit_with_feet_and_hands_in_place(test) -> void:
	var riders := await _riders()
	test.check(not riders.is_empty(), "er zijn berijders (%d)" % riders.size())
	for person: Pedestrian in riders:
		var aid := person.aid
		var rider := aid.rider
		aid.pose()
		var worst_foot := 0.0
		var worst_hand := 0.0
		for side: String in ["left", "right"]:
			var shin: Node3D = rider._joints["shin_" + side]
			var foot := rider.position + shin.position + shin.basis * Vector3(0.0, -TownsfolkFigure.shin_length(), 0.0)
			var on_left := rider.rest_joint("thigh_" + side).x > 0.0
			var wanted := Vector3(aid.foot.x if on_left else -aid.foot.x, aid.foot.y, aid.foot.z)
			worst_foot = maxf(worst_foot, foot.distance_to(wanted))
			var arm: Node3D = rider._joints["arm_" + side]
			var hand := rider.position + arm.position + arm.basis * Vector3(0.0, -TownsfolkFigure.arm_length(), 0.0)
			worst_hand = maxf(worst_hand, hand.distance_to(aid._hand(rider.rest_joint("arm_" + side).x > 0.0)))
		test.check(worst_foot < 0.05, "%s (%s): voeten op de voetsteunen (%.3f m ernaast)" % [person.name, person.mobility, worst_foot])
		test.check(worst_hand < 0.06, "%s (%s): handen aan %s (%.3f m ernaast)" % [person.name, person.mobility,
				"de hoepels" if person.mobility == "rolstoel" else "het stuur", worst_hand])


## The collider of every rider is the box round the chair or scooter and who sits in it.
func test_collider_holds_aid_and_rider(test) -> void:
	var riders := await _riders()
	test.check(not riders.is_empty(), "er zijn berijders (%d)" % riders.size())
	for person: Pedestrian in riders:
		var drawn := Vehicle._mesh_bounds(person.aid, person.aid.transform)
		var shape: CollisionShape3D = person._body.get_node("Doos")
		var box := AABB(shape.position - (shape.shape as BoxShape3D).size * 0.5, (shape.shape as BoxShape3D).size)
		var fits := box.grow(0.02).encloses(drawn) and (box.size - drawn.size).length() < 0.3
		test.check(fits, "%s (%s): botsvorm %s om %s" % [person.name, person.mobility, box.size, drawn.size])


## Riding about for twenty seconds: nearly all get somewhere, their wheels roll (the wheel
## shader), the casters swivel and the scooter's front wheel steers.
func test_they_ride_about_wheels_rolling_and_steering(test) -> void:
	var riders := await _riders()
	test.check(not riders.is_empty(), "er zijn berijders (%d)" % riders.size())
	var start := {}
	for person: Pedestrian in riders:
		start[person] = person.global_position
	var swivelled := 0.0
	var steered := 0.0
	for frame_index in 60 * RIDE_SECONDS:
		await tree.physics_frame
		for person: Pedestrian in riders:
			for caster: Array in person.aid._casters:
				swivelled = maxf(swivelled, absf((caster[0] as Node3D).rotation.y))
			if person.aid._steering:
				steered = maxf(steered, absf(person.aid._steering.rotation.y))
	var moved := 0
	var rolled := 0
	for person: Pedestrian in riders:
		if person.global_position.distance_to(start[person]) > 3.0:
			moved += 1
		var wheel: Array = person.aid._wheels[0]
		if absf(wheel[2]) > 0.5 and (wheel[0] as GeometryInstance3D).material_override is ShaderMaterial:
			rolled += 1
	test.check(moved >= riders.size() - 1, "ze rijden rond (%d van %d meer dan 3 m)" % [moved, riders.size()])
	test.check(rolled >= riders.size() - 1, "de wielen rollen (wielshader, %d van %d)" % [rolled, riders.size()])
	test.check(swivelled > 0.3, "zwenkwieltjes draaien om hun as (tot %.2f rad)" % swivelled)
	test.check(steered > 0.1, "het voorwiel van de scootmobiel stuurt in (tot %.2f rad)" % steered)


## A mobility scooter with someone (the player) standing right in front of it hoots.
func test_scooter_hoots_at_who_stands_in_front(test) -> void:
	var scooters := await _riders("scootmobiel")
	test.check(not scooters.is_empty(), "er is een scootmobiel")
	if scooters.is_empty():
		return
	var scooter: Pedestrian = scooters[0]
	var hooted := false
	for frame_index in 180:
		var ahead := Vector3(sin(scooter.rotation.y), 0.0, cos(scooter.rotation.y))
		player.global_position = scooter.global_position + ahead * 1.0
		await tree.physics_frame
		if scooter._horn_clock > 0.0:
			hooted = true
			break
	test.check(hooted, "de scootmobiel toetert naar wie voor hem staat")
