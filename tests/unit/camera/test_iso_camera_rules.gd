extends RefCounted
## Unit tests of the sums of the iso view (scripts/camera/iso_camera_rules.gd).
##   tests/run_unit_tests.sh iso_camera_rules

const IsoRules = preload("res://scripts/camera/iso_camera_rules.gd")


func test_orthographic_for_the_arguments_or_the_setting(test) -> void:
	test.check(not IsoRules.orthographic_for(PackedStringArray(), false), "zonder iets: perspectief")
	test.check(IsoRules.orthographic_for(PackedStringArray(), true), "de projectinstelling aan: orthografisch")
	test.check(IsoRules.orthographic_for(PackedStringArray(["--snel", "--ortho"]), false), "--ortho wint van de instelling uit")
	test.check(not IsoRules.orthographic_for(PackedStringArray(["--perspectief"]), true), "--perspectief wint van de instelling aan")
	test.check(IsoRules.orthographic_for(PackedStringArray(["--perspectief", "--ortho"]), false), "allebei: --ortho gaat voor")


func test_distance_grows_with_the_view(test) -> void:
	test.check(is_equal_approx(IsoRules.distance(0.0), 0.0), "niets in beeld: afstand 0")
	test.check(is_equal_approx(IsoRules.distance(20.0), 10.0 / tan(deg_to_rad(10.0))), "20 m in beeld bij 20 graden beeldhoek")
	test.check(is_equal_approx(IsoRules.distance(40.0), 2.0 * IsoRules.distance(20.0)), "twee keer zoveel in beeld: twee keer zo ver")


func test_direction_turns_round_the_vertical(test) -> void:
	test.check(IsoRules.direction().is_equal_approx(IsoRules.DIRECTION), "de gewone blik: DIRECTION")
	test.check(absf(IsoRules.direction().length() - 1.0) < 0.001, "een eenheidsvector")
	var quarter := IsoRules.direction(IsoRules.ROTATION.y + 90.0)
	test.check(is_equal_approx(quarter.y, IsoRules.DIRECTION.y), "gedraaid blijft de hoogte gelijk")
	test.check(absf(quarter.x - IsoRules.DIRECTION.z) < 0.001 and absf(quarter.z + IsoRules.DIRECTION.x) < 0.001, "een kwartslag: x en z gewisseld (%s)" % quarter)
	test.check(IsoRules.direction(IsoRules.ROTATION.y + 360.0).is_equal_approx(IsoRules.DIRECTION), "een hele slag: weer hetzelfde")


func test_position_stands_off_the_focus(test) -> void:
	var focus := Vector3(10.0, 2.0, -5.0)
	var spot := IsoRules.position(focus, 30.0)
	test.check(is_equal_approx(spot.distance_to(focus), IsoRules.distance(30.0)), "op de afstand van 30 m in beeld")
	test.check((spot - focus).normalized().is_equal_approx(IsoRules.DIRECTION), "in de richting van de camera")
	var turned := IsoRules.position(focus, 30.0, IsoRules.ROTATION.y + 180.0)
	test.check(is_equal_approx(turned.y, spot.y) and absf((turned.x - focus.x) + (spot.x - focus.x)) < 0.001, "een halve slag: aan de andere kant, even hoog")


func test_rotation_keeps_the_pitch(test) -> void:
	test.check(IsoRules.rotation() == IsoRules.ROTATION, "de gewone blik")
	test.check(IsoRules.rotation(45.0) == Vector3(IsoRules.ROTATION.x, 45.0, 0.0), "gedraaid: alleen de draaiing anders")


func test_ortho_clip_hugs_the_ground_in_view(test) -> void:
	var near_by := IsoRules.ortho_clip(18.0)
	test.check(is_equal_approx(near_by.x, IsoRules.NEAR), "dichtbij: het nabije vlak niet voor de camera langs (%.1f)" % near_by.x)
	test.check(is_equal_approx(near_by.y, IsoRules.distance(18.0) + 18.0 * 0.75 + IsoRules.ORTHO_DEPTH_BACK), "ver: de grond in beeld en 40 m erachter")
	var far_off := IsoRules.ortho_clip(95.0)
	test.check(is_equal_approx(far_off.x, IsoRules.distance(95.0) - 95.0 * 0.75 - IsoRules.ORTHO_DEPTH_FRONT), "ver uitgezoomd: 60 m voor de grond in beeld")
	test.check(far_off.y - far_off.x < 400.0 and far_off.y < IsoRules.FAR, "veel minder diep dan de 6 km van het perspectief (%.0f m)" % (far_off.y - far_off.x))


func test_distance_to_ground_and_the_focus(test) -> void:
	var down := Vector3.DOWN
	test.check(is_equal_approx(IsoRules.distance_to_ground(50.0, down, 6000.0), 50.0), "recht omlaag: de hoogte")
	var forward := -IsoRules.DIRECTION
	test.check(is_equal_approx(IsoRules.distance_to_ground(57.735, forward, 6000.0), 100.0), "schuin omlaag: langer dan de hoogte")
	test.check(is_equal_approx(IsoRules.distance_to_ground(50.0, Vector3.FORWARD, 6000.0), 1500.0), "vlak vooruit: een kwart van het verre vlak")
	test.check(is_equal_approx(IsoRules.distance_to_ground(50.0, Vector3(0.0, 0.2, -1.0).normalized(), 400.0), 100.0), "omhoog kijkend ook")
	var camera_spot := IsoRules.position(Vector3(12.0, 0.0, 7.0), 60.0)
	var focus := IsoRules.ground_focus(camera_spot, forward, 6000.0)
	test.check(focus.distance_to(Vector3(12.0, 0.0, 7.0)) < 0.01 and focus.y == 0.0, "het punt op de grond waar de camera naar kijkt (%s)" % focus)


func test_perspective_view_size_is_the_inverse_of_the_distance(test) -> void:
	test.check(is_equal_approx(IsoRules.perspective_view_size(IsoRules.distance(44.0), IsoRules.FOV), 44.0), "afstand en beeldgrootte horen bij elkaar")
	test.check(is_equal_approx(IsoRules.perspective_view_size(0.0, IsoRules.FOV), 0.0), "op de grond: niets in beeld")
