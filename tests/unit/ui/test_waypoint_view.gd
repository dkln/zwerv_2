extends RefCounted
## Unit tests of the chip of the marker under the minimap (scripts/ui/hud/waypoint_view.gd).
##   tests/run_unit_tests.sh waypoint_view

const WaypointView = preload("res://scripts/ui/hud/waypoint_view.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")


func test_shows_its_text_in_a_chip_as_wide_as_the_minimap(test) -> void:
	var view := WaypointView.new()
	test.check(view.shown_text() == "" and view.get_child_count() == 1, "een lege chip")
	test.check((view.get_child(0) as Control).custom_minimum_size.x == HudLayout.MINIMAP_SIZE, "zo breed als de minimap")
	view.show_text("DERREK · 70 M")
	test.check(view.shown_text() == "DERREK · 70 M", "de naam en de afstand")
	view.free()
