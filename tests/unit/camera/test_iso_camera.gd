extends RefCounted
## Unit tests of the iso camera (scripts/camera/iso_camera.gd): a Camera3D set up and read.
##   tests/run_unit_tests.sh iso_camera

const Iso = preload("res://scripts/camera/iso_camera.gd")
const IsoRules = preload("res://scripts/camera/iso_camera_rules.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _camera() -> Camera3D:
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	return camera


func test_the_sums_are_those_of_the_rules(test) -> void:
	test.check(Iso.FOV == IsoRules.FOV and Iso.NEAR == IsoRules.NEAR and Iso.FAR == IsoRules.FAR, "beeldhoek en vlakken")
	test.check(Iso.ROTATION == IsoRules.ROTATION and Iso.DIRECTION == IsoRules.DIRECTION and Iso.ORTHO_SETTING == IsoRules.ORTHO_SETTING, "draaiing, richting en instelling")
	test.check(Iso.ORTHO_DEPTH_FRONT == 60.0 and Iso.ORTHO_DEPTH_BACK == 40.0, "de diepte van het orthografische beeld")
	test.check(is_equal_approx(Iso.distance(30.0), IsoRules.distance(30.0)), "distance")
	test.check(Iso.direction(200.0).is_equal_approx(IsoRules.direction(200.0)) and Iso.direction().is_equal_approx(Iso.DIRECTION), "direction")
	test.check(Iso.position(Vector3(1, 2, 3), 30.0, 45.0).is_equal_approx(IsoRules.position(Vector3(1, 2, 3), 30.0, 45.0)), "position")


func test_orthographic_follows_the_run(test) -> void:
	var expected := IsoRules.orthographic_for(OS.get_cmdline_user_args(), bool(ProjectSettings.get_setting(Iso.ORTHO_SETTING, false)))
	test.check(Iso.orthographic() == expected, "de argumenten van deze run, anders de projectinstelling")


func test_place_sets_the_camera_up(test) -> void:
	var camera := _camera()
	var focus := Vector3(20.0, 0.0, -8.0)
	Iso.place(camera, focus, 40.0)
	test.check(is_equal_approx(camera.fov, Iso.FOV), "de beeldhoek")
	test.check(camera.global_position.is_equal_approx(Iso.position(focus, 40.0)), "op zijn plek boven het punt")
	test.check((camera.rotation_degrees - Iso.ROTATION).length() < 0.01, "onder de iso-hoek (%s)" % camera.rotation_degrees)
	if Iso.orthographic():
		var clip := IsoRules.ortho_clip(40.0)
		test.check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.size, 40.0), "orthografisch, 40 m in beeld")
		test.check(is_equal_approx(camera.near, clip.x) and is_equal_approx(camera.far, clip.y), "de vlakken om de grond in beeld")
	else:
		test.check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "perspectief")
		test.check(is_equal_approx(camera.near, Iso.NEAR) and is_equal_approx(camera.far, Iso.FAR), "de vlakken van het perspectief")
	Iso.place(camera, focus, 40.0, Iso.ROTATION.y + 90.0)
	test.check(absf(wrapf(camera.rotation_degrees.y - 225.0, -180.0, 180.0)) < 0.01 and absf(camera.rotation_degrees.x - Iso.ROTATION.x) < 0.01, "een kwartslag gedraaid, dezelfde hoek omlaag")
	camera.free()


func test_a_placed_camera_reads_back(test) -> void:
	var camera := _camera()
	var focus := Vector3(-30.0, 0.0, 14.0)
	Iso.place(camera, focus, 55.0)
	test.check(Iso.ground_focus(camera).distance_to(focus) < 0.05, "het punt op de grond (%s)" % Iso.ground_focus(camera))
	test.check(absf(Iso.distance_to_ground(camera) - Iso.distance(55.0)) < 0.05, "de afstand tot de grond")
	test.check(absf(Iso.view_size(camera) - 55.0) < 0.05, "de beeldgrootte (%.2f)" % Iso.view_size(camera))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 33.0
	test.check(is_equal_approx(Iso.view_size(camera), 33.0), "orthografisch: zijn size")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.rotation_degrees = Vector3.ZERO
	test.check(is_equal_approx(Iso.distance_to_ground(camera), camera.far * 0.25), "vlak vooruit kijkend: een kwart van het verre vlak")
	camera.free()
