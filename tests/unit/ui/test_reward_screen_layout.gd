extends RefCounted
## Unit tests of the sizes of the reward screen (scripts/ui/screens/reward_screen_layout.gd).
##   tests/run_unit_tests.sh reward_screen_layout

const RewardScreenLayout = preload("res://scripts/ui/screens/reward_screen_layout.gd")


func test_panel_stage_and_text(test) -> void:
	test.check(RewardScreenLayout.PANEL_SIZE == Vector2(560, 600) and RewardScreenLayout.STAGE_SIZE == Vector2(512, 260), "het paneel en het podium")
	test.check(RewardScreenLayout.STAGE_SIZE.x == RewardScreenLayout.PANEL_SIZE.x - RewardScreenLayout.PADDING * 2.0, "het podium past precies tussen de marges")
	test.check(RewardScreenLayout.panel_margin_top() == 18.0, "boven en onder driekwart van de marge opzij")
	test.check(RewardScreenLayout.text_size() == Vector2(512, 0), "de regel van het item zo breed als het paneel binnen zijn marges")
