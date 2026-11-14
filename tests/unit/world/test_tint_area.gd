extends RefCounted
## Unit tests of a tint area (scripts/world/town/tint_area.gd): its size is at least one cell,
## its tint starts as the default, and in the game it has no preview box.

const TintAreaView = preload("res://scripts/world/town/tint_area_view.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## The size never goes under one cell.
func test_the_size_is_at_least_one_cell(test) -> void:
	var area := TintArea.new()
	area.size = Vector2i(0, -2)
	test.check(area.size == Vector2i(1, 1), "minstens 1 x 1 (%s)" % area.size)
	area.size = Vector2i(3, 2)
	test.check(area.size == Vector2i(3, 2), "anders zoals opgegeven")
	area.free()


## A new area has the default tint at full strength, and no preview in the game.
func test_a_new_area(test) -> void:
	var area := TintArea.new()
	test.check(area.color == TintAreaView.DEFAULT_TINT, "de standaardtint")
	test.check(is_equal_approx(area.brightness, 1.0) and is_equal_approx(area.strength, 1.0), "gewoon licht, volle sterkte")
	tree.root.add_child(area)
	area.color = Color(0.2, 0.4, 0.6)
	test.check(area.get_child_count() == 0, "in het spel geen doos")
	area.free()
