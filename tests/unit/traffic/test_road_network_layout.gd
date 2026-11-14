extends RefCounted
## Unit tests of where the road surface lies (scripts/traffic/road_network_layout.gd): the
## middle of a cell, the height on the flat and across a ramp, the slope.
##   tests/run_unit_tests.sh road_network_layout

const RoadNetworkLayout = preload("res://scripts/traffic/road_network_layout.gd")

const EAST := Vector2i(1, 0)
const NORTH := Vector2i(0, -1)
## A ramp that rises 1 m towards the east.
const RISE_EAST := [EAST, 1.0]


func test_middle(test) -> void:
	test.check(RoadNetworkLayout.middle(Vector3i(0, 0, 0)) == Vector2(2.0, 2.0), "de eerste cel: 2 m uit de hoek")
	test.check(RoadNetworkLayout.middle(Vector3i(3, 5, -2)) == Vector2(14.0, -6.0), "cellen van 4 m, de laag telt niet")


func test_centre(test) -> void:
	test.check(RoadNetworkLayout.centre(Vector3i(1, 0, 2)) == Vector3(6.0, RoadNetworkLayout.ROAD_SURFACE, 10.0), "vlak: op het wegdek van de laag")
	test.check(RoadNetworkLayout.centre(Vector3i(1, -6, 2)).y == -6.0 + RoadNetworkLayout.ROAD_SURFACE, "in de tunnelbak: 6 m lager")
	test.check(is_equal_approx(RoadNetworkLayout.centre(Vector3i(1, 0, 2), RISE_EAST).y, RoadNetworkLayout.ROAD_SURFACE + 0.5), "midden op een helling van 1 m: een halve meter hoger")


func test_height_on_the_flat_and_across_a_ramp(test) -> void:
	var cell := Vector3i(2, 1, 0)
	var surface := 1.0 + RoadNetworkLayout.ROAD_SURFACE
	test.check(RoadNetworkLayout.height(cell, Vector2(9.0, 1.0)) == surface, "vlak: overal de hoogte van de laag")
	test.check(RoadNetworkLayout.height(cell, Vector2(9.0, 1.0), RoadNetworkLayout.FLAT) == surface, "FLAT is vlak")
	test.check(is_equal_approx(RoadNetworkLayout.height(cell, Vector2(8.0, 2.0), RISE_EAST), surface), "de voet van de helling")
	test.check(is_equal_approx(RoadNetworkLayout.height(cell, Vector2(12.0, 2.0), RISE_EAST), surface + 1.0), "de top")
	test.check(is_equal_approx(RoadNetworkLayout.height(cell, Vector2(9.0, 3.5), RISE_EAST), surface + 0.25), "een kwart erop, de plek opzij telt niet")
	test.check(is_equal_approx(RoadNetworkLayout.height(cell, Vector2(2.0, 2.0), RISE_EAST), surface), "voor de voet: niet lager")
	test.check(is_equal_approx(RoadNetworkLayout.height(cell, Vector2(30.0, 2.0), RISE_EAST), surface + 1.0), "voorbij de top: niet hoger")
	test.check(is_equal_approx(RoadNetworkLayout.height(cell, Vector2(10.0, 0.0), [NORTH, 2.0]), surface + 2.0), "een helling naar het noorden van 2 m: de noordrand is de top")


func test_slope(test) -> void:
	test.check(RoadNetworkLayout.slope(RoadNetworkLayout.FLAT, EAST) == 0.0, "vlak: geen helling")
	test.check(is_equal_approx(RoadNetworkLayout.slope(RISE_EAST, EAST), 0.25), "omhoog: 1 m over 4 m")
	test.check(is_equal_approx(RoadNetworkLayout.slope(RISE_EAST, -EAST), -0.25), "de andere kant op: omlaag")
	test.check(RoadNetworkLayout.slope(RISE_EAST, NORTH) == 0.0, "dwars erop: vlak")
