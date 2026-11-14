extends RefCounted
## Unit tests of the sizes of the quest tracker (scripts/ui/hud/quest_tracker_layout.gd).
##   tests/run_unit_tests.sh quest_tracker_layout

const Layout = preload("res://scripts/ui/hud/quest_tracker_layout.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")


func test_tracker_is_as_wide_as_the_hud_gives_it(test) -> void:
	test.check(Layout.WIDTH == HudLayout.TRACKER_WIDTH and Layout.WIDTH == 300.0, "de breedte die de HUD ervoor vrijhoudt")
	test.check(Layout.WIDTH - 2 * Layout.SIDE_MARGIN - Layout.ACCENT_WIDTH > 200.0, "met genoeg ruimte voor de tekst binnen de marges")


func test_a_main_quest_gets_more_room_than_a_side_quest(test) -> void:
	test.check(Layout.MAIN_MARGIN > Layout.SIDE_QUEST_MARGIN and Layout.MAIN_SEPARATION > Layout.SIDE_QUEST_SEPARATION, "een verhaalquest staat ruimer dan een zijmissie")
	test.check(Layout.STEP_SEPARATION > 0 and Layout.STEP_PART_SEPARATION > 0, "de stappen en hun delen staan los van elkaar")
