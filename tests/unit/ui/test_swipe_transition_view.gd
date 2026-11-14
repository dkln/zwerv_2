extends RefCounted
## Unit tests of how the wipe looks (scripts/ui/screens/swipe_transition_view.gd): the still
## over everything, the shader, the edge it is handed and the sweep across.
##   tests/run_unit_tests.sh swipe_transition_view

const SwipeTransitionView = preload("res://scripts/ui/screens/swipe_transition_view.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_the_still_fills_the_screen_and_stops_clicks(test) -> void:
	var view := SwipeTransitionView.new()
	test.check(view.name == "Beeld" and view.mouse_filter == Control.MOUSE_FILTER_STOP, "het stilstaande beeld houdt klikken tegen")
	test.check(view.anchor_right == 1.0 and view.anchor_bottom == 1.0, "over het hele scherm")
	test.check(view.stretch_mode == TextureRect.STRETCH_SCALE and view.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "uitgerekt tot het scherm")
	test.check(view.material is ShaderMaterial and (view.material as ShaderMaterial).shader.code == SwipeTransitionView.SHADER, "met de shader die het wegveegt")
	test.check(view.texture == null and view.edge() == 0.0, "nog geen beeld, de rand links")
	view.free()


func test_show_still_holds_the_picture(test) -> void:
	var view := SwipeTransitionView.new()
	var image := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	view.show_still(image)
	test.check(view.texture != null and view.texture.get_size() == Vector2(4, 2), "het beeld van daarnet staat erop")
	view.free()


func test_show_edge_goes_to_the_shader(test) -> void:
	var view := SwipeTransitionView.new()
	view.show_edge(0.4)
	test.check(is_equal_approx((view.material as ShaderMaterial).get_shader_parameter("edge"), 0.4), "de rand staat waar hij gezet is")
	test.check(is_equal_approx(view.edge(), 0.4), "en edge() zegt het")
	view.free()


func test_play_wipe_sweeps_the_edge_across(test) -> void:
	var view := SwipeTransitionView.new()
	tree.root.add_child(view)
	var tween := view.play_wipe()
	tween.custom_step(SwipeTransitionView.WIPE_SECONDS * 0.5)
	test.check(view.edge() > 0.3 and view.edge() < 0.7, "halverwege: de rand in het midden (%s)" % view.edge())
	tween.custom_step(SwipeTransitionView.WIPE_SECONDS)
	test.check(is_equal_approx(view.edge(), 1.0), "aan het eind: alles weggeveegd")
	test.check(not tween.is_running(), "en de veeg is klaar")
	view.free()
