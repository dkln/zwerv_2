extends RefCounted
## Unit tests of the sizes of the minimap (scripts/ui/hud/minimap_layout.gd).
##   tests/run_unit_tests.sh minimap_layout

const Layout = preload("res://scripts/ui/hud/minimap_layout.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")


func test_the_map_lies_inside_the_border(test) -> void:
	test.check(Layout.frame_size() == Vector2(200.0, 200.0) and Layout.SIZE == HudLayout.MINIMAP_SIZE, "de lijst zo groot als de HUD ervoor vrijhoudt")
	test.check(Layout.map_rect() == Rect2(3.0, 3.0, 194.0, 194.0), "de kaart binnen de rand (%s)" % Layout.map_rect())
	test.check(Layout.centre() == Vector2(97.0, 97.0), "de speler in het midden van de kaart")
	test.check(Rect2(Vector2.ZERO, Layout.frame_size()).has_point(Layout.NORTH_POSITION) and Layout.NORTH_POSITION.y < Layout.centre().y, "de N bovenin de lijst")
