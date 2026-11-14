extends RefCounted
## Unit tests of the rules of the screens that hold the game (scripts/ui/hud/modal_rules.gd):
## when a waiting reward or level up may open, what keeps the game paused, and a screen
## over the game menu.
##   tests/run_unit_tests.sh modal_rules

const ModalRules = preload("res://scripts/ui/hud/modal_rules.gd")


## What is showing: nothing but the things named.
static func _showing(up: Array) -> Dictionary:
	var showing := ModalRules.nothing_showing()
	for thing: String in up:
		showing[thing] = true
	return showing


func test_nothing_showing(test) -> void:
	var showing := ModalRules.nothing_showing()
	test.check(showing.size() == 10 and not showing.values().has(true), "tien dingen, geen ervan in beeld")
	for screen: String in ModalRules.SCREENS:
		test.check(showing.has(screen), "%s hoort erbij" % screen)
	showing["story"] = true
	test.check(not ModalRules.nothing_showing()["story"], "elke keer een nieuwe")


func test_what_a_reward_waits_for(test) -> void:
	test.check(not ModalRules.must_wait(_showing([])), "niets in beeld: niet wachten")
	test.check(ModalRules.must_wait(_showing(["story"])), "de pagina's van een verhaal: wachten")
	test.check(not ModalRules.must_wait(_showing(["story", "conversation"])), "een gesprek: niet")
	for thing: String in ["pause_menu", "death", "machine", "loading"]:
		test.check(ModalRules.must_wait(_showing([thing])), "%s: wachten" % thing)
	test.check(not ModalRules.must_wait(_showing(["shop", "game_menu"])), "de winkel en het spelmenu: niet")


func test_a_reward_opens_one_at_a_time(test) -> void:
	test.check(ModalRules.can_open_reward(1, _showing([])), "een beloning, niets in de weg")
	test.check(not ModalRules.can_open_reward(0, _showing([])), "niets dat wacht")
	test.check(not ModalRules.can_open_reward(2, _showing(["reward"])), "er staat er al een")
	test.check(not ModalRules.can_open_reward(1, _showing(["level_up"])), "niet tijdens een level up")
	test.check(not ModalRules.can_open_reward(1, _showing(["pause_menu"])), "niet in het pauzemenu")
	test.check(ModalRules.can_open_reward(1, _showing(["story", "conversation", "game_menu"])), "wel over een gesprek en het spelmenu")


func test_a_level_up_comes_after_the_rewards(test) -> void:
	test.check(ModalRules.can_open_level_up(1, 0, _showing([])), "een level up, niets in de weg")
	test.check(not ModalRules.can_open_level_up(0, 0, _showing([])), "niets dat wacht")
	test.check(not ModalRules.can_open_level_up(1, 1, _showing([])), "eerst de beloningen die wachten")
	test.check(not ModalRules.can_open_level_up(1, 0, _showing(["reward"])) and not ModalRules.can_open_level_up(2, 0, _showing(["level_up"])), "niet over een beloning of een ander level up")
	test.check(not ModalRules.can_open_level_up(1, 0, _showing(["loading"])), "niet over het laadscherm")
	test.check(ModalRules.can_open_level_up(1, 0, _showing(["shop"])), "wel over de winkel")


func test_xp_joins_a_waiting_level_up(test) -> void:
	test.check(ModalRules.xp_for_level_up({"xp": 40}, 1) == 40, "de XP gaat naar het level-up-scherm")
	test.check(ModalRules.xp_for_level_up({"xp": 40}, 0) == 0, "geen level up dat wacht: de beloning houdt ze")
	test.check(ModalRules.xp_for_level_up({"items": []}, 1) == 0 and ModalRules.xp_for_level_up({"xp": 0}, 2) == 0, "geen XP: niets")


func test_what_keeps_the_game_paused(test) -> void:
	test.check(not ModalRules.keeps_paused(ModalRules.REWARD, _showing([])), "niets meer in beeld: het spel gaat door")
	test.check(not ModalRules.keeps_paused(ModalRules.REWARD, _showing(["reward"])), "het scherm dat zelf sluit telt niet")
	test.check(ModalRules.keeps_paused(ModalRules.REWARD, _showing(["story"])) and ModalRules.keeps_paused(ModalRules.STORY, _showing(["reward"])), "een ander scherm staat er nog")
	test.check(ModalRules.keeps_paused(ModalRules.LEVEL_UP, _showing(["shop"])) and ModalRules.keeps_paused(ModalRules.SHOP, _showing(["level_up"])), "ook de winkel en het level up")
	for screen: String in ModalRules.SCREENS:
		test.check(ModalRules.keeps_paused(screen, _showing(["pause_menu"])), "%s: het pauzemenu houdt het spel stil" % screen)
	test.check(ModalRules.keeps_paused(ModalRules.STORY, _showing(["game_menu"])) and ModalRules.keeps_paused(ModalRules.REWARD, _showing(["game_menu"])) and ModalRules.keeps_paused(ModalRules.LEVEL_UP, _showing(["game_menu"])), "het spelmenu ook")
	test.check(not ModalRules.keeps_paused(ModalRules.SHOP, _showing(["game_menu"])), "maar niet voor de winkel")
	test.check(not ModalRules.keeps_paused(ModalRules.STORY, _showing(["death", "machine"])), "wat anders in beeld is telt niet")


func test_a_conversation_waits_under_a_reward(test) -> void:
	test.check(ModalRules.is_story_on_hold(_showing(["reward"])) and ModalRules.is_story_on_hold(_showing(["level_up"])), "onder een beloning of een level up")
	test.check(not ModalRules.is_story_on_hold(_showing(["shop", "pause_menu"])), "anders niet")


func test_a_screen_over_the_game_menu(test) -> void:
	test.check(ModalRules.is_modal_over_menu(true, true, false, false) and ModalRules.is_modal_over_menu(true, false, true, false) and ModalRules.is_modal_over_menu(true, false, false, true), "verhaal, beloning of level up met het menu open")
	test.check(not ModalRules.is_modal_over_menu(false, true, true, true), "het menu dicht: nee")
	test.check(not ModalRules.is_modal_over_menu(true, false, false, false), "alleen het menu: nee")
	test.check(ModalRules.menu_layer(true, 10, 20) == 9, "het menu onder de HUD")
	test.check(ModalRules.menu_layer(false, 10, 20) == 20, "en weer op zijn eigen laag")
