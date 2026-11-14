extends RefCounted
## Unit tests of the sizes of the pause menu (scripts/ui/screens/pause_menu_layout.gd),
## without nodes.
##   tests/run_unit_tests.sh pause_menu_layout

const PauseMenuLayout = preload("res://scripts/ui/screens/pause_menu_layout.gd")


func test_settings_buttons_are_wider(test) -> void:
	test.check(PauseMenuLayout.button_width(false) == PauseMenuLayout.WIDTH, "het menu zelf: de gewone breedte")
	test.check(PauseMenuLayout.button_width(true) == PauseMenuLayout.WIDTH + PauseMenuLayout.SETTINGS_WIDER, "de instellingen: breder")
	test.check(PauseMenuLayout.button_width(true) > PauseMenuLayout.button_width(false), "dus breder dan het menu")


func test_button_size_has_the_fixed_height(test) -> void:
	test.check(PauseMenuLayout.button_size(300.0) == Vector2(300.0, PauseMenuLayout.BUTTON_HEIGHT), "de breedte die gevraagd is, de vaste hoogte")
	test.check(PauseMenuLayout.button_size(400.0).y == PauseMenuLayout.button_size(300.0).y, "breder: even hoog")


func test_margins_are_positive(test) -> void:
	test.check(PauseMenuLayout.PANEL_MARGIN_SIDE > 0.0 and PauseMenuLayout.PANEL_MARGIN_TOP > 0.0 and PauseMenuLayout.PANEL_MARGIN_BOTTOM > 0.0, "ruimte rond de inhoud van het paneel")
	test.check(PauseMenuLayout.ROW_SEPARATION > 0 and PauseMenuLayout.PANEL_BORDER > 0, "ruimte tussen de regels en een rand")
