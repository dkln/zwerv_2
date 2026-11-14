extends RefCounted
## Unit tests of BicycleParts (scripts/vehicles/bicycle_parts.gd): the name the game knows
## the bicycle by hands on the layout and the model under the names they had.
##   tests/run_unit_tests.sh test_bicycle_parts

const BicyclePartsScript = preload("res://scripts/vehicles/bicycle_parts.gd")
const BicyclePartsLayout = preload("res://scripts/vehicles/bicycle_parts_layout.gd")
const BicyclePartsView = preload("res://scripts/vehicles/bicycle_parts_view.gd")


func test_the_points_are_those_of_the_layout(test) -> void:
	test.check(BicycleParts.point(5.0, 6.0) == BicyclePartsLayout.point(5.0, 6.0) and BicycleParts.point(22.5, 9.5, 1.0) == BicyclePartsLayout.point(22.5, 9.5, 1.0), "point")
	test.check(BicycleParts.steer_pivot() == BicyclePartsLayout.steer_pivot(), "steer_pivot")
	test.check(BicycleParts.steer_axis() == BicyclePartsLayout.steer_axis(), "steer_axis")
	test.check(BicycleParts.bottom_bracket() == BicyclePartsLayout.bottom_bracket(), "bottom_bracket")
	test.check(BicycleParts.crank_length() == BicyclePartsLayout.crank_length(), "crank_length")
	test.check(BicycleParts.hip() == BicyclePartsLayout.hip(), "hip")
	test.check(BicycleParts.front_lamp() == BicyclePartsLayout.front_lamp() and BicycleParts.rear_lamp() == BicyclePartsLayout.rear_lamp(), "front_lamp en rear_lamp")
	for left: bool in [true, false]:
		test.check(BicycleParts.grip(left) == BicyclePartsLayout.grip(left), "grip %s" % left)
		test.check(BicycleParts.pedal(1.3, left) == BicyclePartsLayout.pedal(1.3, left), "pedal %s" % left)


func test_the_old_names_are_still_there(test) -> void:
	test.check(BicycleParts.VOXEL == 0.0625 and BicycleParts.MIDDLE == 5 and BicycleParts.WIDTH == 11, "het rooster")
	test.check(BicycleParts.LOWEST_UP == 2.0 and BicycleParts.MODEL_LIFT == 0.125 and BicycleParts.MIDDLE_ALONG == 14.0, "waar het rooster op het voertuig ligt")
	test.check(BicycleParts.FRONT_HUB == Vector2(5.0, 6.0) and BicycleParts.REAR_HUB == Vector2(23.0, 6.0), "de naven")
	test.check(BicycleParts.BRACKET == Vector2(15.5, 4.5) and BicycleParts.CRANK_VOXELS == 2.4, "de trapas en de crank")
	test.check(BicycleParts.HEAD_BOTTOM == Vector2i(7, 10) and BicycleParts.HEAD_TOP == Vector2i(8, 13) and BicycleParts.SEAT_TOP == Vector2i(19, 10), "het balhoofd en de zadelbuis")
	test.check(BicycleParts.HIP == Vector2(19.0, 12.9) and BicycleParts.GRIP_ALONG_UP == Vector2(11.5, 16.5) and BicycleParts.GRIP_ACROSS == 4.5, "de heupen en de handvatten")
	test.check(BicycleParts.FRONT_LAMP == Vector2(6.5, 11.5) and BicycleParts.REAR_LAMP == Vector2(27.5, 10.5), "de lampen")
	test.check(BicycleParts.STEEL == BicyclePartsView.STEEL and BicycleParts.RUBBER == BicyclePartsView.RUBBER and BicycleParts.LAMP_RED == BicyclePartsView.LAMP_RED, "de kleuren van de view")
	test.check(BicyclePartsScript.DARK_METAL == BicyclePartsView.DARK_METAL and BicyclePartsScript.LAMP_WHITE == BicyclePartsView.LAMP_WHITE, "ook via het script zelf")


func test_build_hands_out_the_model_of_the_view(test) -> void:
	var paint := Color("#3A5FA8")
	var parts := BicycleParts.build(paint, true)
	test.check(is_same(parts, BicyclePartsView.build(paint, true, false)), "dezelfde onderdelen als de view bouwt")
	test.check(parts.has("frame") and parts.has("steer") and parts.has("crank"), "frame, stuur en cranks")
	test.check(not is_same(BicycleParts.build(paint, false, true), parts), "een fatbike is een andere")
