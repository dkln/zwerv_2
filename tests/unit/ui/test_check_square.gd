extends RefCounted
## Unit tests of scripts/ui/widgets/check_square.gd on its own: the box of a quest step (what
## its drawing depends on: sizes, shapes, flags, clocks).
##   tests/run_unit_tests.sh check_square

const CheckSquare = preload("res://scripts/ui/widgets/check_square.gd")


func test_check_square_starts_open_and_small(test) -> void:
	var square := CheckSquare.new()
	test.check(not square.done, "eerst niet gedaan")
	test.check(square.custom_minimum_size == Vector2(10, 10), "10 bij 10 px")
	test.check(square.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	square.done = true
	test.check(square.done, "gedaan te zetten")
	square.free()
