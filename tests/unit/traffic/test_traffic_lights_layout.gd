extends RefCounted
## Unit tests of where the traffic lights stand (scripts/traffic/traffic_lights_layout.gd):
## the lights per intersection, the middles and the nearest intersection, as plain geometry.
##   tests/run_unit_tests.sh traffic_lights_layout

const TrafficLightsLayout = preload("res://scripts/traffic/traffic_lights_layout.gd")

## Two intersections: four lights round the origin, two a long way east.
const POSITIONS := [Vector3(-4, 0, -4), Vector3(100, 0, 2), Vector3(4, 0, -4), Vector3(4, 0, 4), Vector3(-4, 0, 4), Vector3(108, 0, 2)]


func test_groups_per_intersection(test) -> void:
	var group_of := TrafficLightsLayout.groups(POSITIONS, 14.0)
	test.check(group_of == ([0, 1, 0, 0, 0, 1] as Array[int]), "per kruispunt, geteld in de volgorde van hun eerste licht (%s)" % str(group_of))
	test.check(TrafficLightsLayout.groups(POSITIONS, 1.0) == ([0, 1, 2, 3, 4, 5] as Array[int]), "niets dicht genoeg bij elkaar: elk licht zijn eigen kruispunt")
	test.check(TrafficLightsLayout.groups(POSITIONS, 500.0) == ([0, 0, 0, 0, 0, 0] as Array[int]), "alles binnen bereik: één kruispunt")
	test.check(TrafficLightsLayout.groups([], 14.0).is_empty(), "geen lichten: geen kruispunten")


func test_groups_chain_and_ignore_height(test) -> void:
	# each 10 m from the next: the ends are 20 m apart but joined by the middle one
	var chain := [Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(10, 0, 0)]
	test.check(TrafficLightsLayout.groups(chain, 14.0) == ([0, 0, 0] as Array[int]), "via een licht ertussen: één kruispunt")
	test.check(TrafficLightsLayout.groups([Vector3(0, 0, 0), Vector3(0, 50, 0)], 14.0) == ([0, 0] as Array[int]), "de hoogte telt niet")
	test.check(TrafficLightsLayout.groups([Vector3(0, 0, 0), Vector3(14, 0, 0)], 14.0) == ([0, 0] as Array[int]), "precies op de afstand: samen")


func test_group_count_and_first_lights(test) -> void:
	var group_of := TrafficLightsLayout.groups(POSITIONS, 14.0)
	test.check(TrafficLightsLayout.group_count(group_of) == 2, "twee kruispunten")
	test.check(TrafficLightsLayout.group_count([]) == 0, "geen lichten: 0")
	test.check(TrafficLightsLayout.first_lights(group_of) == ([0, 1] as Array[int]), "het eerste licht van elk kruispunt")
	test.check(TrafficLightsLayout.first_lights([]).is_empty(), "geen lichten: geen eerste")


func test_centres(test) -> void:
	var group_of := TrafficLightsLayout.groups(POSITIONS, 14.0)
	var middles := TrafficLightsLayout.centres(POSITIONS, group_of)
	test.check(middles.size() == 2, "een midden per kruispunt")
	test.check(middles[0].is_equal_approx(Vector3.ZERO), "het gemiddelde van de vier lichten (%s)" % str(middles[0]))
	test.check(middles[1].is_equal_approx(Vector3(104, 0, 2)), "en van de twee (%s)" % str(middles[1]))
	test.check(TrafficLightsLayout.centres([], []).is_empty(), "geen lichten: geen middens")


func test_nearest(test) -> void:
	var middles := [Vector3(0, 0, 0), Vector3(104, 0, 2), Vector3(20, 0, 0)]
	var all := [0, 1, 2]
	test.check(TrafficLightsLayout.nearest(middles, all, Vector3(3, 9, 3), 14.0) == 0, "het dichtstbijzijnde (de hoogte telt niet)")
	test.check(TrafficLightsLayout.nearest(middles, all, Vector3(14, 0, 0), 14.0) == 2, "dichter bij het derde")
	test.check(TrafficLightsLayout.nearest(middles, all, Vector3(50, 0, 50), 14.0) == TrafficLightsLayout.NONE, "niets binnen de straal: geen")
	test.check(TrafficLightsLayout.nearest(middles, all, Vector3(14, 0, 0), 14.0 - 0.01) == 2, "het eerste valt net buiten de straal")
	test.check(TrafficLightsLayout.nearest(middles, all, Vector3(10, 0, 0), 14.0) == 2, "even ver: het latere")
	test.check(TrafficLightsLayout.nearest(middles, [0, 1], Vector3(14, 0, 0), 14.0) == 0, "alleen de genoemde kruispunten tellen")
	test.check(TrafficLightsLayout.nearest(middles, [], Vector3(0, 0, 0), 14.0) == TrafficLightsLayout.NONE, "geen kruispunten genoemd: geen")
	test.check(TrafficLightsLayout.nearest(middles, all, Vector3(0, 0, 14), 14.0) == 0, "precies op de straal: telt")


func test_flat_distance(test) -> void:
	test.check(TrafficLightsLayout.flat_distance(Vector3(0, 0, 0), Vector3(3, 100, 4)) == 5.0, "langs x en z, zonder de hoogte")
	test.check(TrafficLightsLayout.flat_distance(Vector3(2, 1, 2), Vector3(2, 9, 2)) == 0.0, "recht boven elkaar: 0")
