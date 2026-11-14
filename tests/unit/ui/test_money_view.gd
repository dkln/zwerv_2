extends RefCounted
## Unit tests of the picture of the money of the HUD (scripts/ui/hud/money_view.gd).
##   tests/run_unit_tests.sh money_view

const MoneyView = preload("res://scripts/ui/hud/money_view.gd")


func test_shows_the_amount_it_is_handed(test) -> void:
	var view := MoneyView.new()
	test.check(view.name == "Geld" and view.amount_text() == "0" and view.mouse_filter == Control.MOUSE_FILTER_IGNORE, "eerst nul, klikken gaan erdoorheen")
	view.show_amount("1.284,50")
	test.check(view.amount_text() == "1.284,50", "het bedrag zoals het is aangereikt")
	var style := view.get_theme_stylebox("panel") as StyleBoxFlat
	test.check(style != null and style.content_margin_left == MoneyView.SIDE_MARGIN and style.content_margin_top == MoneyView.TOP_MARGIN, "in een paneel met zijn marges")
	view.free()
