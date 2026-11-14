extends RefCounted
## Unit tests of where the parts of a bicycle are (scripts/vehicles/bicycle_parts_layout.gd):
## the build grid in metres, the hubs, the steering, the cranks and pedals, the saddle, the
## grips and the lamps.
##   tests/run_unit_tests.sh bicycle_parts_layout

const BicyclePartsLayout = preload("res://scripts/vehicles/bicycle_parts_layout.gd")


func _hub(hub: Vector2) -> Vector3:
	return BicyclePartsLayout.point(hub.x, hub.y)


func test_the_grid_in_metres(test) -> void:
	test.check(BicyclePartsLayout.point(BicyclePartsLayout.MIDDLE_ALONG, BicyclePartsLayout.LOWEST_UP) == Vector3(0.0, BicyclePartsLayout.MODEL_LIFT, 0.0), "het midden van het rooster: midden op het voertuig, net boven de weg")
	test.check(BicyclePartsLayout.point(13.0, 2.0).z == BicyclePartsLayout.VOXEL, "een voxel naar voren is +z")
	test.check(BicyclePartsLayout.point(14.0, 3.0).y == BicyclePartsLayout.MODEL_LIFT + BicyclePartsLayout.VOXEL, "een voxel omhoog is +y")
	test.check(BicyclePartsLayout.point(14.0, 2.0, 2.0).x == 2.0 * BicyclePartsLayout.VOXEL and BicyclePartsLayout.point(14.0, 2.0).x == 0.0, "opzij is x, standaard in het midden")
	test.check(BicyclePartsLayout.WIDTH == 2 * BicyclePartsLayout.MIDDLE + 1, "de middelste kolom zit in het midden")


func test_the_hubs_are_those_of_a_dutch_bicycle(test) -> void:
	var front := _hub(BicyclePartsLayout.FRONT_HUB)
	var rear := _hub(BicyclePartsLayout.REAR_HUB)
	test.check(front == Vector3(0.0, 0.375, 0.5625), "de voornaaf 0,5625 m voor het midden, 0,375 m hoog (%s)" % front)
	test.check(rear == Vector3(0.0, 0.375, -0.5625), "de achternaaf even ver erachter (%s)" % rear)


func test_the_steering_turns_about_the_head_tube(test) -> void:
	var pivot := BicyclePartsLayout.steer_pivot()
	var axis := BicyclePartsLayout.steer_axis()
	test.check(pivot.x == 0.0 and pivot.z > 0.0 and pivot.z < _hub(BicyclePartsLayout.FRONT_HUB).z, "het draaipunt in het midden, achter de voornaaf")
	test.check(pivot.y > _hub(BicyclePartsLayout.FRONT_HUB).y, "en erboven")
	test.check(absf(axis.length() - 1.0) < 0.0001 and axis.x == 0.0, "de as is een richting, recht in het midden")
	test.check(axis.y > 0.9 and axis.z < 0.0, "omhoog, naar achteren leunend (%s)" % axis)


func test_the_cranks_and_the_pedals(test) -> void:
	var bracket := BicyclePartsLayout.bottom_bracket()
	var length := BicyclePartsLayout.crank_length()
	test.check(length == BicyclePartsLayout.CRANK_VOXELS * BicyclePartsLayout.VOXEL and absf(length - 0.15) < 0.0001, "de crank is 15 cm")
	test.check(bracket.x == 0.0 and bracket.y < _hub(BicyclePartsLayout.REAR_HUB).y and absf(bracket.z) < 0.2, "de trapas laag tussen de wielen")
	var across := BicyclePartsLayout.PEDAL_ACROSS * BicyclePartsLayout.VOXEL
	var over := BicyclePartsLayout.PEDAL_UP * BicyclePartsLayout.VOXEL
	var right := BicyclePartsLayout.pedal(0.0, true)
	var left := BicyclePartsLayout.pedal(0.0, false)
	test.check(right.is_equal_approx(bracket + Vector3(-across, over - length, 0.0)), "stand nul: de rechter trapper onder (x < 0)")
	test.check(left.is_equal_approx(bracket + Vector3(across, over + length, 0.0)), "en de linker boven")
	test.check(BicyclePartsLayout.pedal(PI, true).is_equal_approx(left - Vector3(2.0 * across, 0.0, 0.0)), "een halve slag: de rechter boven")
	var forward := BicyclePartsLayout.pedal(PI / 2.0, false)
	test.check(absf(forward.z - bracket.z - length) < 0.0001 and absf(forward.y - bracket.y - over) < 0.0001, "een kwart slag: de bovenste trapper gaat naar voren")
	for step in 16:
		var angle := step * TAU / 16.0
		var middle := (BicyclePartsLayout.pedal(angle, true) + BicyclePartsLayout.pedal(angle, false)) * 0.5
		test.check(middle.is_equal_approx(bracket + Vector3(0.0, over, 0.0)), "de trappers staan steeds tegenover elkaar (%d)" % step)
		test.check(absf((BicyclePartsLayout.pedal(angle, true) - Vector3(-across, over, 0.0) - bracket).length() - length) < 0.0001, "op een cranklengte van de trapas (%d)" % step)


func test_the_rider_sits_on_the_saddle_and_holds_the_grips(test) -> void:
	var hip := BicyclePartsLayout.hip()
	test.check(hip.x == 0.0 and hip.z < 0.0 and hip.z > _hub(BicyclePartsLayout.REAR_HUB).z, "de heupen in het midden, voor de achternaaf")
	test.check(hip.y > 0.75 and hip.y < 0.9, "net boven het zadel van 0,75 m (%.3f)" % hip.y)
	var left := BicyclePartsLayout.grip(true)
	var right := BicyclePartsLayout.grip(false)
	test.check(left.x > 0.0 and right == Vector3(-left.x, left.y, left.z), "de handvatten gespiegeld, links op +x")
	test.check(left.x == BicyclePartsLayout.GRIP_ACROSS * BicyclePartsLayout.VOXEL, "zo ver uit het midden")
	test.check(left.y > hip.y and left.z > hip.z and left.z < _hub(BicyclePartsLayout.FRONT_HUB).z, "hoger dan het zadel, ervoor, achter de voornaaf")


func test_the_lamps(test) -> void:
	var front := BicyclePartsLayout.front_lamp()
	var rear := BicyclePartsLayout.rear_lamp()
	test.check(front.x == 0.0 and front.z > 0.4 and front.y > _hub(BicyclePartsLayout.FRONT_HUB).y, "de koplamp voorop, boven het wiel")
	test.check(rear.x == 0.0 and rear.z < _hub(BicyclePartsLayout.REAR_HUB).z and rear.y > _hub(BicyclePartsLayout.REAR_HUB).y, "het achterlicht achter de achternaaf, erboven")
	test.check(front == BicyclePartsLayout.point(6.5, 11.5) and rear == BicyclePartsLayout.point(27.5, 10.5), "op hun punten van het rooster")
