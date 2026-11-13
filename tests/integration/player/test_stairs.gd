extends "res://tests/integration/support/town_test.gd"
## Stairs: the player walks up the stairs of the footbridge over the A12 (two flights of 3 m,
## props trappen/trap_3m with their exact collider, library_builder.gd STAIR_TILES) onto the
## deck, 6 m up, and down again at the other end; the pedestrians use them too (Pedestrians:
## the stair routes between the pavement and the deck).
##   tests/run_integration_tests.sh stairs

## The footbridge (tools/build/city/a12.gd): its column, its two end rows; the stairs rise
## east along the middle of those rows, from x STAIR_FOOT_X to the deck.
const FOOTBRIDGE_COLUMN := 160
const FOOTBRIDGE_ROWS := [17, 28]
const STAIR_FOOT_X := 628.5
const DECK_HEIGHT := 6.0
const STEP := 0.05
## Physics steps a pedestrian gets for one flight of the stairs.
const CLIMB_STEPS := 60 * 40


## The pedestrians of the town, once there are some.
func _walkers() -> Pedestrians:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	await wait_until(func() -> bool: return not walkers.people().is_empty(), 10.0)
	return walkers


## The stair route that goes up ([foot cell, deck cell]), [] if there is none.
func _route_up(walkers: Pedestrians) -> Array:
	for route: Array in walkers._stair_routes.keys():
		if not walkers.is_deck(route[0]) and walkers.is_deck(route[1]):
			return route
	return []


## A pedestrian put at the foot of the stairs `up`, the player standing near (who is far
## from the player becomes someone else elsewhere) and not walking off.
func _person_at_the_foot(walkers: Pedestrians, up: Array) -> Pedestrian:
	player.set_physics_process(false)
	player.global_position = walkers.cell_middle(up[0]) + Vector3(-12.0, 0.0, 6.0)
	var person: Pedestrian = walkers.people()[0]
	person.restart_at(up[0])
	person.cell = up[0]
	person._pause = 0.0
	return person


## `person` walking on without pauses until they are in `cell` (at most CLIMB_STEPS physics
## steps); returns the highest they got.
func _walk_to(person: Pedestrian, cell: Variant) -> float:
	var highest := 0.0
	for step_index in CLIMB_STEPS:
		await tree.physics_frame
		person._pause = 0.0
		highest = maxf(highest, person.global_position.y)
		if person.cell == cell:
			break
	return highest


## At both ends of the footbridge the player walks up the stairs onto the deck and down again.
func test_player_walks_up_onto_the_bridge_and_down_again(test) -> void:
	player.set_physics_process(false)   # moved by hand here
	for row: int in FOOTBRIDGE_ROWS:
		var start := Vector3(STAIR_FOOT_X - 2.0, 0.0, row * 4.0 + 2.0)
		start.y = player._ground_height(start, 3.0, 6.0)
		player.global_position = start
		await physics_frames(1)
		var went := 0.0
		while player.global_position.x < FOOTBRIDGE_COLUMN * 4.0 + 1.5 and went < 30.0:
			var before: Vector3 = player.global_position
			if not player._try_move(Vector3(STEP, 0.0, 0.0)):
				break
			went += STEP
			if before.distance_to(player.global_position) < 0.001:
				break
		print("rij %d: van x %.1f (hoogte %.2f) tot x %.1f, hoogte %.2f" % [row, start.x, start.y, player.global_position.x, player.global_position.y])
		test.check(player.global_position.y > DECK_HEIGHT - 0.3, "rij %d: de speler loopt de trap op tot op de brug (%.2f m)" % [row, player.global_position.y])
		while player.global_position.x > STAIR_FOOT_X - 1.5:
			if not player._try_move(Vector3(-STEP, 0.0, 0.0)):
				break
		test.check(player.global_position.y < start.y + 0.3, "rij %d: en weer naar beneden (%.2f m)" % [row, player.global_position.y])
	player.set_physics_process(true)


## The pedestrians know the stairs: a route up and one down at both ends of the bridge, and
## the deck is walkable for them.
func test_pedestrians_have_stair_routes_and_a_walkable_deck(test) -> void:
	var walkers := await _walkers()
	var routes: Array = walkers._stair_routes.keys()
	print("traproutes: ", routes)
	test.check(routes.size() == 4, "op en af aan beide kanten van de brug (%d routes)" % routes.size())
	test.check(walkers._decks.size() >= 10, "het brugdek is beloopbaar (%d cellen)" % walkers._decks.size())


## A pedestrian sent up walks the treads onto the deck (6 m up) and comes down again onto
## the pavement.
func test_pedestrian_climbs_the_stairs_and_comes_down(test) -> void:
	var walkers := await _walkers()
	var up := _route_up(walkers)
	test.check(not up.is_empty() and not walkers.people().is_empty(), "een trap omhoog en een voetganger")
	if up.is_empty() or walkers.people().is_empty():
		return
	var person := _person_at_the_foot(walkers, up)
	test.check(person._head_for(up[1]), "een voetganger gaat de trap op")
	var highest := await _walk_to(person, up[1])
	print("voetganger: cel %s, hoogte %.2f (hoogst %.2f)" % [person.cell, person.global_position.y, highest])
	test.check(person.cell == up[1] and person.global_position.y > DECK_HEIGHT - 0.3, "en staat op de brug (%.2f m)" % person.global_position.y)
	person._pause = 0.0
	test.check(person._head_for(up[0]), "en gaat weer naar beneden")
	await _walk_to(person, up[0])
	test.check(person.cell == up[0] and person.global_position.y < 1.0, "en staat weer op de stoep (%.2f m)" % person.global_position.y)
	player.set_physics_process(true)
