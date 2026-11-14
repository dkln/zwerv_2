extends "res://tests/integration/support/town_test.gd"
## The HUD of the town (scripts/ui/hud.gd): its API called once (a stat, the money, quests,
## an area name), the minimap built from the town, and the XP bar in line with the meters.
##   tests/run_integration_tests.sh hud


## A stat set on the HUD is what it gives back; the money is written the Dutch way.
func test_stat_and_money_reach_the_hud(test) -> void:
	var health_before: Vector2 = hud.get_stat("gezondheid")
	var hunger_before: Vector2 = hud.get_stat("honger")
	hud.set_stat("gezondheid", 142, 200)
	hud.set_stat("honger", 35)
	hud.set_money(1284)
	await frames(5)
	test.check(hud.get_stat("gezondheid") == Vector2(142, 200), "gezondheid gezet (%s)" % hud.get_stat("gezondheid"))
	test.check(hud.money_panel.amount_text() == "1.284,00", "geld: " + hud.money_panel.amount_text())
	hud.set_stat("gezondheid", health_before.x, health_before.y)
	hud.set_stat("honger", hunger_before.x, hunger_before.y)
	hud.set_money(player.money)


## Quests and an area name can be set without errors, and the HUD keeps the quests.
func test_quests_and_area_can_be_set(test) -> void:
	var quests_before: Array = hud.quests().duplicate(true)
	hud.set_quests([{"kind": "verhaal", "label": "TEST", "title": "Test", "distance": "10M",
		"steps": [{"text": "klaar", "done": true}, {"text": "open", "done": false}]}, {"kind": "zij", "title": "Test 1/2"}])
	hud.show_area("Testgebied")
	await frames(5)
	test.check(hud.quests().size() == 2, "twee opdrachten gezet (%d)" % hud.quests().size())
	hud.set_quests(quests_before)


## The minimap picture was built from the town, and the clock shows.
func test_minimap_is_built(test) -> void:
	test.check(hud.minimap_texture() != null, "het kaartje is er")
	if hud.minimap_texture():
		print("kaartje: ", hud.minimap_texture().get_size(), " pixels")
	print("tijd: ", hud.clock.view.day_text(), " ", hud.clock.view.time_text())


## The XP bar starts where the stat bars start and is as wide and high, its points under it.
func test_xp_bar_in_line_with_the_meters(test) -> void:
	await frames(5)
	var stat_bar: Control = hud.player_frame.view.stat_bar("uithoudingsvermogen")
	var xp_bar: Control = hud.player_frame.view.xp_bar()
	print("XP-balk op x %.0f, %s (metertje %.0f, %s)" % [xp_bar.global_position.x, xp_bar.size, stat_bar.global_position.x, stat_bar.size])
	test.check(absf(xp_bar.global_position.x - stat_bar.global_position.x) <= 0.5 and absf(xp_bar.size.x - stat_bar.size.x) <= 0.5
			and absf(xp_bar.size.y - stat_bar.size.y) <= 0.5,
		"XP-balk in lijn: %s %s, metertje %s %s" % [xp_bar.global_position.x, xp_bar.size.x, stat_bar.global_position.x, stat_bar.size.x])
	test.check(absf((hud.player_frame.view.xp_label() as Control).global_position.x - xp_bar.global_position.x) <= 0.5, "XP-punten onder de balk")
