extends RefCounted
## Unit tests of the way round rectangles on a flat floor (scripts/pathfinding/detour.gd).
##   tests/run_unit_tests.sh detour

const Detour = preload("res://scripts/pathfinding/detour.gd")


func test_detour_round_a_box(test) -> void:
	var box := Rect2(-1.0, -1.0, 2.0, 2.0)
	var from := Vector2(-5.0, 0.0)
	var to := Vector2(5.0, 0.0)
	test.check(Detour.hits(from, to, box), "de rechte lijn raakt de doos")
	var points := Detour.around(from, to, [box], 0.5, 3)
	test.check(points.size() >= 2 and points[-1] == to, "via hoeken naar het doel")
	var here := from
	for point in points:
		test.check(not Detour.hits(here, point, box.grow(0.5)), "geen stuk door de doos (met marge)")
		here = point


func test_detour_straight_when_clear(test) -> void:
	var box := Rect2(-1.0, 3.0, 2.0, 2.0)
	var points := Detour.around(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), [box], 0.5, 3)
	test.check(points == ([Vector2(5.0, 0.0)] as Array[Vector2]), "niets in de weg: rechtdoor")
	test.check(Detour.first_obstacle(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), [box], 0.5) == Rect2(), "geen obstakel")
	test.check(Detour.around(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), [Rect2(-1, -1, 2, 2)], 0.5, 0) == ([Vector2(5.0, 0.0)] as Array[Vector2]),
			"diepte 0: rechtdoor")


func test_detour_picks_the_nearest_obstacle(test) -> void:
	var near := Rect2(-3.0, -1.0, 1.0, 2.0)
	var far := Rect2(2.0, -1.0, 1.0, 2.0)
	test.check(Detour.first_obstacle(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), [far, near], 0.2) == near, "de dichtstbijzijnde eerst")
	test.check(Detour.inside_any(Vector2(-2.9, 1.1), [near], 0.2), "binnen de marge telt als binnen")
	test.check(not Detour.inside_any(Vector2(0.0, 0.0), [near, far], 0.2), "ertussen: vrij")


func test_hits(test) -> void:
	var area := Rect2(0.0, 0.0, 2.0, 2.0)
	test.check(Detour.hits(Vector2(1.0, 1.0), Vector2(9.0, 9.0), area), "begint erin: raakt")
	test.check(Detour.hits(Vector2(9.0, 9.0), Vector2(1.0, 1.0), area), "eindigt erin: raakt")
	test.check(Detour.hits(Vector2(-1.0, 1.0), Vector2(3.0, 1.0), area), "dwars erdoor: raakt")
	test.check(not Detour.hits(Vector2(-1.0, 3.0), Vector2(3.0, 3.0), area), "erlangs: raakt niet")
	test.check(not Detour.hits(Vector2(-3.0, 1.0), Vector2(-1.0, 1.0), area), "stopt ervoor: raakt niet")


func test_first_obstacle_skips_one_an_end_lies_in(test) -> void:
	var box := Rect2(-1.0, -1.0, 2.0, 2.0)
	test.check(Detour.first_obstacle(Vector2(0.0, 0.0), Vector2(6.0, 0.0), [box], 0.2) == Rect2(), "begin in het obstakel: telt niet")
	test.check(Detour.first_obstacle(Vector2(-6.0, 0.0), Vector2(1.1, 0.0), [box], 0.2) == Rect2(), "doel binnen de marge: telt niet")
	test.check(Detour.first_obstacle(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), [], 0.2) == Rect2(), "geen obstakels: geen")


func test_detour_round_two_boxes(test) -> void:
	var boxes := [Rect2(-4.0, -1.0, 2.0, 2.0), Rect2(2.0, -1.0, 2.0, 2.0)]
	var from := Vector2(-8.0, 0.0)
	var to := Vector2(8.0, 0.0)
	var points := Detour.around(from, to, boxes, 0.3, 4)
	test.check(points[-1] == to and points.size() >= 3, "om beide heen naar het doel (%d punten)" % points.size())
	var here := from
	for point in points:
		for box: Rect2 in boxes:
			test.check(not Detour.hits(here, point, box.grow(0.3)), "geen stuk door een doos")
		here = point
