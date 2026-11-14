extends RefCounted
## Unit tests of the shape of the arrow (scripts/world/things/interaction_mark_layout.gd).
##   tests/run_unit_tests.sh interaction_mark_layout

const InteractionMarkLayout = preload("res://scripts/world/things/interaction_mark_layout.gd")


func test_arrow_corners_point_down_at_the_origin(test) -> void:
	var corners := InteractionMarkLayout.arrow_corners()
	test.check(corners.size() == 9, "drie driehoeken")
	test.check(corners[0] == Vector3.ZERO, "de punt op de oorsprong")
	var box := AABB(corners[0], Vector3.ZERO)
	for corner: Vector3 in corners:
		box = box.expand(corner)
		test.check(corner.y >= 0.0 and corner.z == 0.0, "plat, alles boven de punt")
	test.check(is_equal_approx(box.size.x, InteractionMarkLayout.HEAD_WIDTH), "zo breed als de kop")
	test.check(is_equal_approx(box.size.y, InteractionMarkLayout.HEAD_HEIGHT + InteractionMarkLayout.SHAFT_LENGTH), "kop plus schacht hoog")
	test.check(is_equal_approx(corners[5].x - corners[3].x, InteractionMarkLayout.SHAFT_WIDTH), "de schacht smaller dan de kop")


func test_places_of_arrow_and_shadow(test) -> void:
	test.check(InteractionMarkLayout.arrow_place(2.7) == Vector3(0.0, 2.7, 0.0), "de pijl op zijn hoogte")
	test.check(InteractionMarkLayout.shadow_place(2.7).is_equal_approx(Vector3(0.0, 2.7 - InteractionMarkLayout.SHADOW_DROP, 0.0)), "de donkere kopie er net onder")
