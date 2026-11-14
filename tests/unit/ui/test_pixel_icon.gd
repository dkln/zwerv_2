extends RefCounted
## Unit tests of scripts/ui/widgets/pixel_icon.gd on its own: a bitmap icon (what its drawing
## depends on: sizes, shapes, flags, clocks).
##   tests/run_unit_tests.sh pixel_icon

const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")


func test_pixel_icon_is_as_big_as_its_bitmap(test) -> void:
	var icon := PixelIcon.new()
	test.check(icon.custom_minimum_size == Vector2.ZERO, "zonder bitmap: niets")
	test.check(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	icon.bitmap = ["#..#.", ".##..", "#..#."]
	test.check(icon.custom_minimum_size == Vector2(10, 6) and icon.size == Vector2(10, 6), "5 x 3 pixels van 2 px (%s)" % icon.custom_minimum_size)
	icon.pixel = 4.0
	test.check(icon.custom_minimum_size == Vector2(20, 12) and icon.size == Vector2(20, 12), "grotere pixels: groter icoon")
	icon.colour = Color.RED
	test.check(icon.colour == Color.RED and icon.custom_minimum_size == Vector2(20, 12), "een kleur verandert de maat niet")
	icon.bitmap = []
	test.check(icon.custom_minimum_size == Vector2.ZERO, "een lege bitmap: weer niets")
	icon.free()
