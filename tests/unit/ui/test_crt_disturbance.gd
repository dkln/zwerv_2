extends RefCounted
## Unit tests of the disturbances of the CRT picture (scripts/ui/crt_disturbance.gd): the
## wait before the first and between two, the band rolling down, the tracking trouble, and
## nothing under a parent that is not a CRT overlay.
##   tests/run_unit_tests.sh crt_disturbance

const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Steps every running tween of the tree `seconds` on (a test has no frames of its own).
func _step_tweens(seconds: float) -> void:
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(seconds)


## A CRT overlay in the tree with a disturbance under it, the first after one second.
func _overlay(tracking_chance: float) -> ColorRect:
	var overlay := UiStyle.make_crt_overlay(0.05, 0.035, Vector2(1280, 720))
	var disturbance := CrtDisturbance.new()
	disturbance.name = "Storing"
	disturbance.first_after = 1.0
	disturbance.tracking_chance = tracking_chance
	overlay.add_child(disturbance)
	tree.root.add_child(overlay)
	return overlay


func test_the_first_disturbance_waits(test) -> void:
	var overlay := _overlay(0.0)
	var disturbance: CrtDisturbance = overlay.get_node("Storing")
	var material := overlay.material as ShaderMaterial
	disturbance._process(0.6)
	test.check(material.get_shader_parameter("glitch_strength") == null, "voor `first_after`: nog niets")
	disturbance._process(0.6)
	var strength: float = material.get_shader_parameter("glitch_strength")
	test.check(strength >= 0.6 and strength <= 1.0, "daarna een storing (sterkte %s)" % strength)
	test.check(disturbance._wait >= disturbance.every.x and disturbance._wait <= disturbance.every.y, "de volgende over 6 tot 16 s (%s)" % disturbance._wait)
	overlay.free()


func test_the_band_rolls_down_and_goes(test) -> void:
	var overlay := _overlay(0.0)
	var disturbance: CrtDisturbance = overlay.get_node("Storing")
	var material := overlay.material as ShaderMaterial
	disturbance._process(1.1)
	_step_tweens(disturbance.roll_seconds * 0.5)
	test.check(is_equal_approx(material.get_shader_parameter("glitch_y"), 0.5), "halverwege de rol: midden op het scherm (%s)" % material.get_shader_parameter("glitch_y"))
	_step_tweens(disturbance.roll_seconds)
	test.check(is_equal_approx(material.get_shader_parameter("glitch_y"), -1.0), "na de rol is de band weg")
	test.check(material.get_shader_parameter("tracking") == null, "zonder kans op tracking: het beeld blijft staan")
	overlay.free()


func test_tracking_trouble_comes_on_hard_and_fades(test) -> void:
	var overlay := _overlay(1.0)
	var disturbance: CrtDisturbance = overlay.get_node("Storing")
	var material := overlay.material as ShaderMaterial
	disturbance._process(1.1)
	_step_tweens(0.12)
	var strength: float = material.get_shader_parameter("tracking")
	test.check(strength >= 0.5 and strength <= 1.0, "het beeld verliest zijn tracking (%s)" % strength)
	_step_tweens(disturbance.tracking_seconds * 0.5)
	test.check(is_equal_approx(material.get_shader_parameter("tracking"), strength * 0.4), "het zakt eerst snel")
	_step_tweens(disturbance.tracking_seconds)
	test.check(is_zero_approx(material.get_shader_parameter("tracking")), "en komt weer goed")
	overlay.free()


func test_nothing_without_a_crt_overlay(test) -> void:
	var parent := Node.new()
	var disturbance := CrtDisturbance.new()
	disturbance.first_after = 1.0
	parent.add_child(disturbance)
	tree.root.add_child(parent)
	disturbance._process(5.0)
	test.check(is_equal_approx(disturbance._wait, 1.0), "geen beeld erboven: het wacht niet eens af")
	var plain := ColorRect.new()
	var under_plain := CrtDisturbance.new()
	plain.add_child(under_plain)
	tree.root.add_child(plain)
	under_plain._process(60.0)
	test.check(is_equal_approx(under_plain._wait, under_plain.first_after), "een beeld zonder CRT-shader: ook niet")
	parent.free()
	plain.free()
