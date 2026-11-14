extends RefCounted
## Unit tests of how the loading screen looks (scripts/ui/screens/loading_screen_view.gd):
## what it builds, the progress it is handed and the fade.
##   tests/run_unit_tests.sh loading_screen_view

const LoadingScreenView = preload("res://scripts/ui/screens/loading_screen_view.gd")
const LoadingScreenLayout = preload("res://scripts/ui/screens/loading_screen_layout.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_it_builds_the_title_the_heading_and_an_empty_bar(test) -> void:
	var view := LoadingScreenView.new("ZWERVR", "— STAD LADEN —")
	test.check(view.name == "Beeld" and view.title_text() == "ZWERVR" and view.heading_text() == "— STAD LADEN —", "de titel en wat er laadt")
	test.check(view.panel.color == UiStyle.INK and view.panel.get_parent() == view, "op inkt")
	test.check(view.bar.segments == LoadingScreenLayout.SEGMENTS and view.bar.segment_height == LoadingScreenLayout.SEGMENT_HEIGHT, "de balk met de maten van de layout")
	test.check(view.bar.full_colour == UiStyle.ACCENT and view.bar.fill == 0.0, "amber blokjes, nog leeg")
	test.check(view.percentage.text == "0%" and view.percentage.custom_minimum_size == LoadingScreenLayout.PERCENTAGE_SIZE, "het percentage ernaast")
	test.check(view.crt.get_parent() == view and view.crt.get_index() > view.panel.get_index(), "het CRT-beeld over het scherm heen")
	var material := view.crt.material as ShaderMaterial
	test.check(is_equal_approx(material.get_shader_parameter("curvature"), LoadingScreenView.CRT_CURVATURE)
		and is_equal_approx(material.get_shader_parameter("corner"), LoadingScreenView.CRT_CORNER), "met de gewone bolling")
	view.free()
	var bent := LoadingScreenView.new("", "", 0.2, 0.1, Vector2(1280, 720))
	var bent_material := bent.crt.material as ShaderMaterial
	test.check(is_equal_approx(bent_material.get_shader_parameter("curvature"), 0.2) and is_equal_approx(bent_material.get_shader_parameter("corner"), 0.1), "of de bolling die het krijgt")
	bent.free()


func test_show_progress(test) -> void:
	var view := LoadingScreenView.new("ZWERVR", "— STAD LADEN —")
	view.show_progress(0.5, "50%")
	test.check(view.percentage.text == "50%" and is_equal_approx(view.bar.fill, 0.5), "de balk half, het percentage erbij")
	view.show_progress(1.0, "klaar")
	test.check(view.percentage.text == "klaar" and view.bar.fill == 1.0, "het schrijft wat het krijgt")
	view.free()


func test_fade_out_fades_the_screen_and_the_crt(test) -> void:
	var view := LoadingScreenView.new("ZWERVR", "— STAD LADEN —")
	tree.root.add_child(view)
	var tween := view.fade_out()
	var material := view.crt.material as ShaderMaterial
	tween.custom_step(LoadingScreenView.FADE_SECONDS * 0.5)
	test.check(is_equal_approx(view.panel.modulate.a, 0.5) and is_equal_approx(material.get_shader_parameter("opacity"), 0.5), "halverwege: half doorzichtig, ook het CRT-beeld")
	tween.custom_step(LoadingScreenView.FADE_SECONDS)
	test.check(is_zero_approx(view.panel.modulate.a) and is_zero_approx(material.get_shader_parameter("opacity")), "daarna helemaal doorzichtig")
	test.check(not view.is_queued_for_deletion(), "opruimen doet het gedrag")
	view.free()
