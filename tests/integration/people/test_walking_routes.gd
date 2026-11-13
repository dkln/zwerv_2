extends "res://tests/integration/support/town_test.gd"
## People on foot going somewhere (Pedestrians.route_to_somewhere, Pedestrian._next_on_the_way):
## a route to a place a few blocks off over the pavements and the zebras, most of the people
## round the player on such a way, and people really crossing the roads at the zebras.
##   tests/run_integration_tests.sh walking_routes


## The pedestrians of the town (the node Voetgangers).
func _town() -> Node:
	return scene.get_node("Voetgangers")


## A route from where someone stands leads over linked cells to a place blocks away, and
## routes cross the roads: a good share of them go over a zebra.
func test_a_route_leads_blocks_away_and_over_zebras(test) -> void:
	var town := _town()
	var routes := 0
	var broken := 0
	var over_a_zebra := 0
	var longest := 0
	for person: Pedestrian in town.people().slice(0, 40):
		var route: Array[Vector3i] = town.route_to_somewhere(person.cell, "")
		if route.is_empty():
			continue
		routes += 1
		longest = maxi(longest, route.size())
		var at: Vector3i = person.cell
		for next in route:
			if not next in town.links(at):
				broken += 1
				break
			at = next
		if route.any(func(cell: Vector3i) -> bool: return town.is_zebra(cell)):
			over_a_zebra += 1
	test.check(routes >= 10, "voor de meesten is er een route (%d)" % routes)
	test.check(broken == 0, "elke stap van een route is een gekoppelde cel (%d kapot)" % broken)
	test.check(longest >= 12, "een route gaat blokken ver (langste %d cellen)" % longest)
	test.check(over_a_zebra * 3 >= routes, "veel routes steken een straat over via een zebra (%d van %d)" % [over_a_zebra, routes])


## Walking a while: most people are on their way somewhere, and some of them are seen
## crossing a road on a zebra.
func test_people_walk_their_way_and_cross(test) -> void:
	var town := _town()
	var crossed := {}
	var on_a_way := 0
	for second in 90:
		await seconds(1.0)
		for person: Pedestrian in town.people():
			if town.is_zebra(person.cell):
				crossed[person.get_instance_id()] = true
	# who is not on a way, and why (to the station, wandering a while, a role, riding)
	var reasons := {}
	for person: Pedestrian in town.people():
		if not person.way_ahead().is_empty():
			on_a_way += 1
			continue
		var reason := "naar station" if person.heading_to_station else "dwaalt" if person._wander_left > 0 \
				else "rol " + person.role if person.role != "" else "valt" if person._ragdoll else "zomaar"
		reasons[reason] = int(reasons.get(reason, 0)) + 1
	print("  niet op weg: ", reasons)
	var people: int = town.people().size()
	test.check(people > 0 and on_a_way * 2 >= people, "de meesten zijn ergens naar op weg (%d van %d)" % [on_a_way, people])
	test.check(crossed.size() >= 3, "mensen steken echt over bij een zebra (%d in 90 s)" % crossed.size())
