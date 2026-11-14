extends RefCounted
## Unit tests of the CRT look over the screens before the game (scripts/ui/menu/screen_crt_view.gd).
##   tests/run_unit_tests.sh screen_crt_view

const ScreenCrtView = preload("res://scripts/ui/menu/screen_crt_view.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_the_look_on_and_off(test) -> void:
	var view := ScreenCrtView.new()
	tree.root.add_child(view)
	test.check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.get_child_count() == 1 and view.get_child(0) is ColorRect, "een laag over het hele venster, vangt geen muis")
	test.check(view.get_child(0).get_children().any(func(child: Node) -> bool: return child is CrtDisturbance), "met de storingen erbij")
	test.check(float(view.shown("curvature")) == 0.0 and float(view.shown("corner")) == 0.0, "eerst vlak")
	view.show_crt(true)
	test.check(is_equal_approx(view.shown("curvature"), ScreenCrtView.CURVATURE) and is_equal_approx(view.shown("corner"), ScreenCrtView.CORNER), "aan: bol met ronde hoeken")
	view.show_crt(false)
	test.check(float(view.shown("curvature")) == 0.0 and float(view.shown("corner")) == 0.0, "uit: weer vlak")
	view.show_screen_size(Vector2(1920, 1080))
	test.check(view.shown("screen_size") == Vector2(1920, 1080), "de maat van het venster")
	view.play_tape_start(0.8, 1.6)
	test.check(is_equal_approx(view.shown("tracking"), 0.8), "de band start: het beeld is even zijn spoor kwijt")
	view.free()
