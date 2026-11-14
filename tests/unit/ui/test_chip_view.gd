extends RefCounted
## Unit tests of a chip of the HUD (scripts/ui/hud/chip_view.gd): a small panel with its
## things in a row.
##   tests/run_unit_tests.sh chip_view

const ChipView = preload("res://scripts/ui/hud/chip_view.gd")


func test_a_chip_holds_its_things_in_a_row(test) -> void:
	var chip := ChipView.new()
	test.check(chip.items().is_empty() and chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "eerst leeg, klikken gaan erdoorheen")
	var first := Label.new()
	var second := Label.new()
	chip.add_item(first)
	chip.add_item(second)
	test.check(chip.items() == [first, second], "in de volgorde waarin ze erin gingen")
	test.check(first.get_parent() is HBoxContainer and first.get_parent().get_parent() == chip, "naast elkaar in het paneel")
	var style := chip.get_theme_stylebox("panel") as StyleBoxFlat
	test.check(style != null and style.content_margin_left == ChipView.SIDE_MARGIN and style.content_margin_top == ChipView.TOP_MARGIN, "met zijn marges")
	chip.free()
