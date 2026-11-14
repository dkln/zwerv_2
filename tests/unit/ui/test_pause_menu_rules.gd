extends RefCounted
## Unit tests of the logic of the pause menu (scripts/ui/screens/pause_menu_rules.gd): the
## items, the next item and how the settings read, without nodes.
##   tests/run_unit_tests.sh pause_menu_rules

const PauseMenuRules = preload("res://scripts/ui/screens/pause_menu_rules.gd")


func test_item_index(test) -> void:
	test.check(PauseMenuRules.item_index("resume") == 0, "verder spelen staat bovenaan")
	test.check(PauseMenuRules.item_index("quit") == PauseMenuRules.ITEMS.size() - 1, "afsluiten onderaan")
	test.check(PauseMenuRules.item_index("bestaat_niet") == -1, "onbekend: -1")


func test_next_index_goes_round(test) -> void:
	test.check(PauseMenuRules.next_index(0, 1, 4) == 1 and PauseMenuRules.next_index(3, 1, 4) == 0, "omlaag, onderaan weer naar boven")
	test.check(PauseMenuRules.next_index(0, -1, 4) == 3 and PauseMenuRules.next_index(2, -1, 4) == 1, "omhoog, bovenaan naar onderen")
	test.check(PauseMenuRules.next_index(-1, 1, 4) == 0, "nog niets gekozen: het eerste")
	test.check(PauseMenuRules.next_index(2, 1, 0) == 0, "geen items: 0")


func test_labels_and_actions_follow_the_items(test) -> void:
	var labels := PauseMenuRules.item_labels()
	var actions := PauseMenuRules.item_actions()
	test.check(labels == ["VERDER SPELEN", "INSTELLINGEN", "HOOFDMENU", "AFSLUITEN"], "wat de items zeggen (%s)" % [labels])
	test.check(actions == ["resume", "settings", "menu", "quit"], "wat ze doen (%s)" % [actions])
	for index in actions.size():
		test.check(PauseMenuRules.item_index(actions[index]) == index, "%s staat op zijn plek" % actions[index])


func test_only_resume_is_silent(test) -> void:
	test.check(not PauseMenuRules.action_sounds("resume"), "verder spelen: geen eigen geluid (het menu sluit)")
	for action: String in ["settings", "menu", "quit"]:
		test.check(PauseMenuRules.action_sounds(action), "%s: wel" % action)


func test_setting_labels(test) -> void:
	test.check(PauseMenuRules.anti_aliasing_label("MSAA 2X") == "ANTI-ALIASING: MSAA 2X", "anti-aliasing met zijn waarde")
	test.check(PauseMenuRules.render_scale_label("75%") == "RENDERSCHAAL: 75%", "de renderschaal met zijn waarde")
	test.check(PauseMenuRules.crt_label(true) == "CRT-BEELD: AAN" and PauseMenuRules.crt_label(false) == "CRT-BEELD: UIT", "het CRT-beeld aan of uit")
	test.check(PauseMenuRules.BACK_LABEL == "TERUG", "en terug")
