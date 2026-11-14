extends RefCounted
## Unit tests of the sizes of what drifts through the intro (scripts/ui/intro/drifter_layout.gd).
##   tests/run_unit_tests.sh drifter_layout

const DrifterLayout = preload("res://scripts/ui/intro/drifter_layout.gd")


func test_the_wheels_of_a_tractor(test) -> void:
	test.check(DrifterLayout.TRACTOR_WHEELS.size() == 4, "vier wielen")
	for wheel: Array in DrifterLayout.TRACTOR_WHEELS:
		var at := DrifterLayout.wheel_position(wheel)
		test.check(is_zero_approx(at.y) and at.x == (wheel[0] as Vector3).x and at.z == (wheel[0] as Vector3).z, "%s op %s staat op de grond onder zijn as" % [wheel[1], wheel[0]])
	test.check(DrifterLayout.wheel_position([Vector3(1, 2, 3), "wiel", 0.5]) == Vector3(1, 1.5, 3), "een wiel staat zijn straal onder de as")


func test_they_tumble_round_their_middle(test) -> void:
	test.check(DrifterLayout.tractor_position() == Vector3(0, -DrifterLayout.TRACTOR_MIDDLE, 0), "de trekker: zijn midden in de oorsprong")
	test.check(DrifterLayout.character_position(1.8).is_equal_approx(Vector3(0, -0.9 * DrifterLayout.CHARACTER_SCALE, 0)), "een personage: de helft van zijn (vergrote) lengte omlaag")
	test.check(DrifterLayout.character_position(0.0) == Vector3.ZERO, "zonder lengte: op zijn plek")
	test.check(DrifterLayout.SIZE > DrifterLayout.PICTURE and DrifterLayout.CAMERA_AT.z > 0.0, "het plaatje wordt vergroot getoond, de camera ervoor")
