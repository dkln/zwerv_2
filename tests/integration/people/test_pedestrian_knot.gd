extends "res://tests/integration/support/town_test.gd"
## A knot of people (scripts/world/people/pedestrian.gd): walkers, wheelchairs and mobility scooters
## put on one spot, all heading through each other, must untangle (step aside, turn, at
## last walk through each other) and get on their way instead of standing there for good.
## By day (the game starts at six, when few are out and hardly anyone rides an aid) and
## away from the station (near it people walk off into it and are gone).
##   tests/run_integration_tests.sh pedestrian_knot

const PeopleHelp = preload("res://tests/integration/support/people_help.gd")
const Crowd = preload("res://scripts/world/people/crowd.gd")
## Seconds (game time) the knot gets to fall apart, and how far (metres) counts as away.
const UNTANGLE_SECONDS := 20
const AWAY_METRES := 2.0


## Up to three riders of an aid and people on foot (eight in all), put in a little ring on the spot
## of the first, each facing and heading to the other side of the ring; returns them.
func _tie_a_knot() -> Array:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var people: Array = walkers.people()
	var riders := people.filter(func(person: Pedestrian) -> bool: return person.aid != null)
	var on_foot := people.filter(func(person: Pedestrian) -> bool: return person.aid == null)
	# (riders are few: when none are near, people on foot make up the eight)
	var knot: Array = riders.slice(0, 3)
	knot += on_foot.slice(0, 8 - knot.size())
	if knot.is_empty():
		return knot
	var middle: Vector3 = knot[0].global_position
	for index in knot.size():
		var person: Pedestrian = knot[index]
		var angle := TAU * index / knot.size()
		var spot := middle + Vector3(cos(angle), 0.0, sin(angle)) * 0.6
		# on a free spot (not in a lamppost or a bench), else in the middle
		person.global_position = spot if person._stands_free(spot) else middle
		person.rotation.y = angle + PI * 0.5 + PI
		person._pause = 0.0
		person._update_cell()
		person._target = middle - Vector3(cos(angle), 0.0, sin(angle)) * 3.0
	return knot


## Eight people on one spot heading through each other: within twenty seconds all but one
## at most have got more than two metres away from it.
func test_a_knot_of_people_falls_apart(test) -> void:
	await put_player(PeopleHelp.street_away_from_station(self))
	await PeopleHelp.crowd_at_hour(self, 13.0)
	var knot := _tie_a_knot()
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	test.check(knot.size() >= 6, "genoeg mensen voor een kluit (%d; %d in de stad, %d gewenst, buurt %s)" % [knot.size(),
			walkers.people().size(), walkers.wanted_count(), Crowd.area_at(scene, player.global_position)])
	if knot.is_empty():
		return
	var middle: Vector3 = knot[0].global_position
	# how far each one got from the knot during the run (it may walk back past it later)
	var farthest := {}
	for frame_index in 60 * UNTANGLE_SECONDS:
		await tree.physics_frame
		for index in knot.size():
			# (someone who walked into a station or a tram meanwhile is gone: it got away)
			if not is_instance_valid(knot[index]):
				farthest[index] = INF
				continue
			var person: Pedestrian = knot[index]
			farthest[index] = maxf(float(farthest.get(index, 0.0)), Vector2(person.global_position.x - middle.x, person.global_position.z - middle.z).length())
	var away := 0
	for index in knot.size():
		var moved: float = farthest[index]
		if not is_instance_valid(knot[index]):
			away += 1
			continue
		var person: Pedestrian = knot[index]
		print("  %-14s %-11s %.1f m van de kluit" % [person.name, person.mobility if person.mobility != "" else "lopend", moved])
		if moved < AWAY_METRES:
			print("    pauze %.1f geblokt %.1f opgehouden %.1f geest %.1f doel %.1f m, mag %s, physics %s, ragdoll %s" % [person._pause, person._blocked, person._held_up, person._ghost_left,
				person._target.distance_to(person.global_position), person._may_go(), person.is_physics_processing(), person._ragdoll != null])
		if moved > AWAY_METRES:
			away += 1
	test.check(away >= knot.size() - 1, "de kluit valt uiteen (%d van %d weg)" % [away, knot.size()])
