extends RefCounted
## Unit tests of where the protest flag stands and how big it is
## (scripts/vehicles/protest_flag_layout.gd).
##   tests/run_unit_tests.sh protest_flag_layout

const ProtestFlagLayout = preload("res://scripts/vehicles/protest_flag_layout.gd")


func test_the_pole_stands_on_the_rear_corner_of_the_roof(test) -> void:
	test.check(ProtestFlagLayout.POLE_FOOT == Vector3(0.6, 2.55, -1.62), "de voet op de achterhoek van het cabinedak")
	test.check(ProtestFlagLayout.pole_size() == Vector3(0.05, 1.15, 0.05), "een dunne paal van 1,15 m")
	test.check(ProtestFlagLayout.pole_centre() == Vector3(0.0, 0.575, 0.0), "zijn midden op halve hoogte: de voet op het dak")


func test_the_cloth_hangs_from_the_top_backwards(test) -> void:
	var top := ProtestFlagLayout.cloth_top()
	test.check(top.x == 0.0 and top.z == 0.0 and absf(top.y - 1.13) < 0.0001, "het doek net onder de top van de paal")
	test.check(top.y - ProtestFlagLayout.CLOTH_SIZE.y > 0.5, "en ruim boven het dak")
	test.check(ProtestFlagLayout.CLOTH_SIZE == Vector3(0.04, 0.5, 0.75), "dun, een halve meter hoog, 75 cm lang")


func test_three_equal_bands_from_top_to_bottom(test) -> void:
	test.check(ProtestFlagLayout.BAND_COUNT == 3, "drie banen")
	test.check(is_equal_approx(ProtestFlagLayout.band_height() * 3.0, ProtestFlagLayout.CLOTH_SIZE.y), "samen zo hoog als het doek")
	test.check(ProtestFlagLayout.band_size() == Vector3(0.04, ProtestFlagLayout.band_height(), 0.75), "elke baan zo dik en zo lang als het doek")
	var height := ProtestFlagLayout.band_height()
	for band_index in ProtestFlagLayout.BAND_COUNT:
		var centre := ProtestFlagLayout.band_centre(band_index)
		test.check(is_equal_approx(centre.y, -height * (band_index + 0.5)), "baan %d: onder de vorige" % band_index)
		test.check(centre.x == 0.0 and is_equal_approx(centre.z, -0.4), "baan %d: achter de paal, er net tegenaan" % band_index)
	test.check(is_equal_approx(ProtestFlagLayout.band_centre(0).y + height * 0.5, 0.0), "de bovenste baan begint bovenaan het doek")
	test.check(is_equal_approx(ProtestFlagLayout.band_centre(2).y - height * 0.5, -ProtestFlagLayout.CLOTH_SIZE.y), "de onderste eindigt onderaan")
	test.check(is_equal_approx(ProtestFlagLayout.band_centre(0).z + ProtestFlagLayout.CLOTH_SIZE.z * 0.5, -ProtestFlagLayout.POLE_WIDTH * 0.5), "het doek begint aan de achterkant van de paal")
