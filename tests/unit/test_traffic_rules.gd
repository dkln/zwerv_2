extends RefCounted
## Unit tests of the rules of the road (scripts/vehicles/vehicle.gd, scripts/traffic/traffic.gd):
## traffic from the right goes first, an idiot at the wheel weaves (steering, more at speed,
## none standing still) and drives over the limit, a vehicle standing still in a jam is counted,
## and what comes to the edge of the map drives off it.

const TrafficScript = preload("res://scripts/traffic/traffic.gd")
const NORTH := Vector2(0, -1)
const SOUTH := Vector2(0, 1)
const EAST := Vector2(1, 0)
const WEST := Vector2(-1, 0)


func test_from_the_right_goes_first(test) -> void:
	# heading +z (south on the map): its right is -x; one coming from -x heading +x crosses
	# its way from its right
	test.check(Vehicle.comes_from_right(Vector2.ZERO, SOUTH, Vector2(-10, 5), EAST), "van rechts, haaks erover")
	test.check(not Vehicle.comes_from_right(Vector2.ZERO, SOUTH, Vector2(10, 5), WEST), "van links: niet")
	test.check(not Vehicle.comes_from_right(Vector2.ZERO, SOUTH, Vector2(-10, 5), WEST), "rechts, maar de andere kant op: niet")
	test.check(not Vehicle.comes_from_right(Vector2.ZERO, SOUTH, Vector2(0, 10), NORTH), "tegemoet: niet")


func test_two_at_a_crossing_never_both_from_the_right(test) -> void:
	# whoever is right of the other, only one of the two has the other on its right
	var pairs := [[Vector2.ZERO, SOUTH, Vector2(-10, 5), EAST], [Vector2.ZERO, EAST, Vector2(5, 10), NORTH],
		[Vector2(3, 4), WEST, Vector2(-2, -6), SOUTH]]
	for pair: Array in pairs:
		var mine: bool = Vehicle.comes_from_right(pair[0], pair[1], pair[2], pair[3])
		var theirs: bool = Vehicle.comes_from_right(pair[2], pair[3], pair[0], pair[1])
		test.check(not (mine and theirs), "niet allebei van rechts (%s)" % [pair])


func test_an_idiot_weaves_when_it_drives(test) -> void:
	test.check(Vehicle.maniac_weave("", 1.3, 15.0) == 0.0, "een gewone bestuurder slingert niet")
	test.check(Vehicle.maniac_weave("dronken", 1.3, 0.0) == 0.0, "stilstaand slingert niemand")
	var widest := {"dronken": 0.0, "agressief": 0.0}
	for kind: String in widest:
		for step in 400:
			widest[kind] = maxf(widest[kind], absf(Vehicle.maniac_weave(kind, step * 0.05, 15.0)))
	test.check(widest.dronken > 0.4 and widest.dronken < 1.0, "de dronkaard slingert wijd (%.2f m)" % widest.dronken)
	test.check(widest.agressief > 0.1 and widest.agressief < widest.dronken, "de agressieveling minder (%.2f m)" % widest.agressief)
	test.check(absf(Vehicle.maniac_weave("dronken", 2.0, 2.0)) <= absf(Vehicle.maniac_weave("dronken", 2.0, 15.0)) + 1e-6,
		"langzaam minder dan snel")


func test_an_idiot_drives_over_the_limit(test) -> void:
	test.check(Vehicle.MANIAC_SPEED.dronken > 1.0 and Vehicle.MANIAC_SPEED.agressief > Vehicle.MANIAC_SPEED.dronken,
		"harder dan de limiet, de agressieveling het hardst")
	test.check(Vehicle.EMERGENCY_SPEED_FACTOR >= Vehicle.MANIAC_SPEED.agressief, "een sirene nog harder")


func test_standing_still_is_counted(test) -> void:
	var traffic: Node = TrafficScript.new()
	var vehicle := Vehicle.new()
	vehicle.speed = 0.0
	traffic._clock = 10.0
	test.check(traffic._standing_still_for(vehicle) == 0.0, "net stil: 0 s")
	traffic._clock = 41.0
	test.check(is_equal_approx(traffic._standing_still_for(vehicle), 31.0), "31 s later: 31 s")
	test.check(traffic._standing_still_for(vehicle) >= traffic.jam_seconds, "dat is file (vanaf %.0f s)" % traffic.jam_seconds)
	vehicle.speed = 5.0
	test.check(traffic._standing_still_for(vehicle) == 0.0, "rijdt het weer: 0")
	vehicle.speed = 0.0
	test.check(traffic._standing_still_for(vehicle) == 0.0, "en stil telt opnieuw")
	vehicle.free()
	traffic.free()


func test_the_edge_of_the_map(test) -> void:
	var traffic: Node = TrafficScript.new()
	test.check(not traffic.at_map_edge(Vector2(-100, -100)), "zonder kaart: nergens een rand")
	traffic._map_edges = Rect2(0, 0, 800, 600)
	test.check(not traffic.at_map_edge(Vector2(400, 300)), "midden op de kaart: niet")
	test.check(traffic.at_map_edge(Vector2(3, 300)), "3 m van de rand: wel")
	test.check(traffic.at_map_edge(Vector2(400, 598)), "aan de onderkant ook")
	test.check(not traffic.at_map_edge(Vector2(400, 600 - traffic.EDGE_MARGIN - 1.0)), "net binnen de marge: niet")
	traffic.free()
