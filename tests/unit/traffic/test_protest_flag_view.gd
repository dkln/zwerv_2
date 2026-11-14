extends RefCounted
## Unit tests of the model of the protest flag (scripts/vehicles/protest_flag_view.gd).
##   tests/run_unit_tests.sh protest_flag_view

const ProtestFlagView = preload("res://scripts/vehicles/protest_flag_view.gd")
const ProtestFlagLayout = preload("res://scripts/vehicles/protest_flag_layout.gd")


func _colour(part: MeshInstance3D) -> Color:
	return ((part.mesh as BoxMesh).material as StandardMaterial3D).albedo_color


func test_a_pole_with_a_cloth(test) -> void:
	var view := ProtestFlagView.new()
	test.check(view.name == "Beeld" and view.get_child_count() == 2, "een paal en een doek")
	var pole := view.get_child(0) as MeshInstance3D
	test.check((pole.mesh as BoxMesh).size == ProtestFlagLayout.pole_size() and pole.position == ProtestFlagLayout.pole_centre(), "de paal met de maat en de plek van de layout")
	test.check(_colour(pole) == ProtestFlagView.POLE_COLOUR, "van hout")
	var cloth := view.cloth()
	test.check(cloth == view.get_child(1) and cloth.name == "Doek" and cloth.position == ProtestFlagLayout.cloth_top(), "het doek bovenaan de paal")
	view.free()


func test_the_dutch_flag_upside_down(test) -> void:
	var view := ProtestFlagView.new()
	var cloth := view.cloth()
	test.check(cloth.get_child_count() == 3 and ProtestFlagView.BANDS.size() == ProtestFlagLayout.BAND_COUNT, "drie banen")
	for band_index in cloth.get_child_count():
		var band := cloth.get_child(band_index) as MeshInstance3D
		test.check((band.mesh as BoxMesh).size == ProtestFlagLayout.band_size() and band.position == ProtestFlagLayout.band_centre(band_index), "baan %d op zijn plek" % band_index)
		test.check(_colour(band) == ProtestFlagView.BANDS[band_index], "baan %d in zijn kleur" % band_index)
		test.check(((band.mesh as BoxMesh).material as StandardMaterial3D).roughness == 0.9, "baan %d mat" % band_index)
	var top := _colour(cloth.get_child(0))
	var bottom := _colour(cloth.get_child(2))
	test.check(top.b > top.r and bottom.r > bottom.b, "blauw boven, rood onder")
	var middle := _colour(cloth.get_child(1))
	test.check(middle.r > 0.9 and middle.g > 0.9 and middle.b > 0.9, "wit in het midden")
	view.free()


func test_show_wave_turns_the_cloth_round_the_pole(test) -> void:
	var view := ProtestFlagView.new()
	test.check(view.cloth().rotation == Vector3.ZERO, "eerst recht achteruit")
	view.show_wave(0.15)
	test.check(is_equal_approx(view.cloth().rotation.y, 0.15) and view.cloth().rotation.x == 0.0 and view.cloth().rotation.z == 0.0, "om de paal gedraaid")
	view.show_wave(-0.1)
	test.check(is_equal_approx(view.cloth().rotation.y, -0.1), "en naar de andere kant")
	test.check(view.get_child(0).rotation == Vector3.ZERO, "de paal blijft staan")
	view.free()
