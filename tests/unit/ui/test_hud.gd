extends RefCounted
## Unit tests of the HUD as a whole (scripts/ui/hud.gd, GameHud) on its own, without the
## town: what the game tells it reaches the right part (stats, experience, notices, quests,
## the marker, money, the clock, the music) and its screens open and close (pause, death,
## story, reward). The parts themselves have their own tests (test_player_frame,
## test_notice_banner, test_quest_rules, test_quest_tracker, test_minimap, test_location,
## test_waypoint, test_clock, test_modal_rules, test_pause_menu, ...); the HUD
## in the town: tests/integration/ui/test_hud.gd.
##   tests/run_unit_tests.sh test_hud

const DeathScreen = preload("res://scripts/ui/screens/death_screen.gd")
const NoticeRules = preload("res://scripts/ui/hud/notice_rules.gd")
const CityMusic = preload("res://scripts/audio/city_music.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Counts the times something is done (the `done` of a story or a reward).
class Counter:
	var count := 0

	func add() -> void:
		count += 1


## A HUD in an empty town (a node of its own, so what the HUD puts beside itself goes with it).
func _hud() -> GameHud:
	var town := Node3D.new()
	town.name = "Proefstad"
	var hud := GameHud.new()
	hud.name = "HUD"
	town.add_child(hud)
	tree.root.add_child(town)
	return hud


func _close(hud: GameHud) -> void:
	tree.paused = false
	hud.get_parent().free()


static func _quests() -> Array:
	return [
		{"id": "kroket", "kind": "verhaal", "title": "Een kroket", "steps": [
			{"text": "Zoek blikjes", "done": true},
			{"text": "Lever ze in", "done": false, "targets": [Vector2(10.0, 0.0)]}]},
		{"id": "krant", "kind": "zij", "title": "Verkoop de krant"},
		{"id": "oud", "title": "Al gedaan", "done": true},
	]


func test_the_hud_starts_with_the_chosen_character(test) -> void:
	var hud := _hud()
	test.check(hud.player_frame != null and hud.notices != null and hud.quest_tracker != null and hud.music != null, "de onderdelen zijn er")
	test.check(hud.pause_menu != null and hud.death_screen != null, "en de schermen")
	test.check(hud.minimap != null and hud.location != null and hud.clock != null and hud.marker != null and hud.money_panel != null and hud.crt != null, "de minimap met de locatie, de klok en de marker, het geld en de CRT-laag")
	test.check(hud.player_frame.view.shown_name() == hud.player_name and hud.player_name != "", "de naam van de gekozen zwerver (%s)" % hud.player_name)
	for stat_name: String in GameHud.STATS:
		var stat := hud.get_stat(stat_name)
		test.check(stat.y > 0.0 and stat.x == (0.0 if stat_name == "overprikkeldheid" else stat.y), "%s: vol, overprikkeldheid leeg (%s)" % [stat_name, stat])
	test.check(not hud.quest_tracker.visible and hud.quests().is_empty(), "nog geen quests")
	test.check(hud.get_node_or_null("Spelmenu") != null, "het spelmenu hangt eronder")
	_close(hud)


func test_stats_experience_and_player_reach_the_frame(test) -> void:
	var hud := _hud()
	hud.set_stat("honger", 35.0, 80.0)
	test.check(hud.get_stat("honger") == Vector2(35.0, 80.0) and hud.player_frame.view.stat_label("honger").text == "35/80", "een stat komt in het spelerskader")
	hud.set_xp(150.0, 300.0)
	test.check(hud.player_frame.view.xp_label().text == "150 / 300", "de XP ook")
	hud.set_player("Sjaan", 3)
	test.check(hud.player_name == "Sjaan" and hud.player_level == 3 and hud.player_frame.view.shown_level() == "LEVEL 3", "naam en level")
	_close(hud)


func test_notices_at_the_top(test) -> void:
	var hud := _hud()
	test.check(not hud.is_showing_notice(), "eerst geen melding")
	hud.show_area("Zeeheldenkwartier")
	test.check(hud.is_showing_notice() and hud.notices.view.heading_text() == NoticeRules.AREA_HEADING and hud.notices.view.name_text() == "Zeeheldenkwartier", "een nieuw gebied")
	hud.show_mission("Lege maag")
	hud.show_notice("— VERDIEPING —", "Burgerzaken")
	test.check(hud.notices.waiting() == 2, "de volgende wachten")
	hud.notices.show_next()
	test.check(hud.notices.view.heading_text() == NoticeRules.MISSION_HEADING and hud.notices.view.name_text() == "Lege maag", "dan de nieuwe missie")
	test.check(hud.music.has_node("MissieDeuntje") or not ResourceLoader.exists(GameHud.MISSION_JINGLE), "met het missiedeuntje")
	hud.notices.show_next()
	test.check(hud.notices.view.heading_text() == "— VERDIEPING —" and hud.notices.view.name_text() == "Burgerzaken", "en een eigen melding")
	_close(hud)


func test_level_up_without_a_choice_is_a_notice(test) -> void:
	var hud := _hud()
	hud.show_level_up(4)
	test.check(hud.player_level == 4 and hud.player_frame.view.shown_level() == "LEVEL 4", "het nieuwe level op het plaatje")
	test.check(hud.is_showing_notice() and hud.notices.view.name_text() == "Level 4", "als melding bovenin")
	test.check(hud.level_ups_waiting().is_empty() and not hud.is_showing_level_up(), "zonder keuze geen level-up-scherm")
	var chosen := Counter.new()
	hud.show_level_up(5, func(_stat_name: String) -> void: chosen.add(), func(_stat_name: String) -> Vector2: return Vector2(50.0, 100.0))
	test.check(hud.level_ups_waiting().size() == 1 and int(hud.level_ups_waiting()[0].level) == 5, "met keuze: het scherm wacht op zijn beurt")
	_close(hud)


func test_quests_reach_the_tracker(test) -> void:
	var hud := _hud()
	hud.set_quests(_quests())
	test.check(hud.quests().size() == 3 and hud.tracked_quest_id() == "kroket" and hud.quest_tracker.visible, "de eerste open quest wordt gevolgd en getoond")
	test.check(hud.quest_by_id("krant").title == "Verkoop de krant" and hud.quest_by_id("niets").is_empty(), "een quest bij zijn id")
	test.check(hud.quest_targets() == [Vector2(10.0, 0.0)], "de plekken van de gevolgde quest")
	hud.track_quest("krant")
	test.check(hud.tracked_quest_id() == "krant" and hud.quest_targets().is_empty(), "een andere quest volgen")
	hud.track_quest("oud")
	test.check(hud.tracked_quest_id() == "krant", "een quest die klaar is kan niet gevolgd worden")
	test.check(hud.next_open_quest_id("krant") == "kroket", "na de laatste open quest weer de eerste")
	test.check(GameHud.quest_id(_quests()[0]) == "kroket" and GameHud.is_quest_done(_quests()[2]) and not GameHud.is_quest_done(_quests()[0]), "id en klaar, zoals het spelmenu ze vraagt")
	var shown: Array = GameHud.tracker_steps(_quests()[0]).map(func(step: Dictionary) -> String: return step.text)
	test.check(shown == ["Zoek blikjes", "Lever ze in"], "de stappen van de tracker (%s)" % [shown])
	hud.set_quests([])
	test.check(not hud.quest_tracker.visible and hud.tracked_quest_id() == "", "geen quests meer: de tracker weg")
	_close(hud)


func test_the_marker_of_the_map(test) -> void:
	var hud := _hud()
	test.check(not hud.has_waypoint() and hud.waypoint() == Vector2.INF and hud.waypoint_name() == "", "eerst geen marker")
	hud.set_waypoint(Vector2(120.0, -40.0), "Het Plein")
	test.check(hud.has_waypoint() and hud.waypoint() == Vector2(120.0, -40.0) and hud.waypoint_name() == "Het Plein", "een marker gezet")
	test.check(hud.marker.visible and hud.marker.view.shown_text() == "HET PLEIN", "met zijn naam in beeld")
	test.check(hud.get_parent().get_child_count() == 2, "en zijn baken in de stad")
	hud.set_waypoint(Vector2(5.0, 5.0), "Station")
	test.check(hud.waypoint() == Vector2(5.0, 5.0) and hud.get_parent().get_child_count() == 2, "een nieuwe plek: hetzelfde baken verzet")
	hud.clear_waypoint()
	test.check(not hud.has_waypoint() and hud.waypoint_name() == "" and not hud.marker.visible, "en weer weg")
	_close(hud)


func test_money_and_clock(test) -> void:
	var hud := _hud()
	hud.set_money(1284.5)
	test.check(hud.money_panel.amount_text() == "1.284,50", "het geld zoals Nederlanders het schrijven (%s)" % hud.money_panel.amount_text())
	hud.set_time(8.5, 3)
	test.check(hud.clock.view.time_text() == "08:30" and hud.clock.view.day_text() == "DAG 3", "de tijd en de dag (%s, %s)" % [hud.clock.view.time_text(), hud.clock.view.day_text()])
	hud.set_time(25.25)
	test.check(hud.clock.view.time_text() == "01:15" and hud.clock.view.day_text() == "DAG 3", "voorbij middernacht telt door vanaf nul, de dag blijft")
	_close(hud)


func test_pause_menu_pauses_the_game(test) -> void:
	var hud := _hud()
	hud.set_paused(true)
	test.check(tree.paused and hud.pause_menu.is_open(), "gepauzeerd met het pauzemenu open")
	hud.pause_menu.choose(hud.pause_menu.item_index("resume"))
	test.check(not tree.paused and not hud.pause_menu.is_open(), "VERDER SPELEN: het spel loopt weer")
	hud.set_paused(true)
	hud.set_paused(false)
	test.check(not tree.paused and not hud.pause_menu.is_open(), "en via de HUD zelf")
	_close(hud)


func test_death_closes_the_pause_menu_and_stops_the_music(test) -> void:
	var hud := _hud()
	hud.set_player("Sjaan", 1)
	hud.music.play_city()
	hud.set_paused(true)
	hud.show_death("honger")
	test.check(hud.death_screen.is_open() and not hud.pause_menu.is_open() and not tree.paused, "het doodscherm, het pauzemenu dicht")
	test.check(hud.death_screen.reason_text() == DeathScreen.reason("honger", "Sjaan"), "met hoe het gebeurde")
	test.check(hud.music.file() == "", "de stadsmuziek gaat uit")
	test.check(hud.music.has_node("DoodDeuntje") or not ResourceLoader.exists(GameHud.DEATH_JINGLE), "en het doodsdeuntje speelt")
	hud.show_death("verdronken")
	test.check(hud.death_screen.reason_text() == DeathScreen.reason("honger", "Sjaan"), "een tweede keer doodgaan verandert niets")
	_close(hud)


func test_music_goes_through_the_hud(test) -> void:
	var hud := _hud()
	test.check(hud.indoor_music() == "", "buiten: geen muziek van een gebouw")
	hud.set_indoor_music("handelaar_loop.ogg")
	test.check(hud.indoor_music() == "handelaar_loop.ogg" and hud.music.file() == "handelaar_loop.ogg", "binnen: de muziek van het gebouw")
	hud.set_indoor_music("")
	test.check(hud.indoor_music() == "", "weer buiten")
	hud.duck_music(true)
	test.check(hud.music.jingles_playing() == 1, "de muziek omlaag voor een omroep")
	hud.duck_music(false)
	test.check(hud.music.jingles_playing() == 0, "en weer omhoog")
	hud.play_task_done()
	test.check(hud.music.has_node("TaakDeuntje") or not ResourceLoader.exists(GameHud.TASK_JINGLE), "een taak klaar: het deuntje")
	_close(hud)


func test_story_box_shows_pages(test) -> void:
	var hud := _hud()
	var done := Counter.new()
	test.check(not hud.is_showing_story(), "eerst geen verhaal")
	hud.show_story([{"text": "Het regent in Den Haag."}], done.add)
	test.check(hud.is_showing_story(), "het verhaalvenster is open")
	hud.show_story([])
	test.check(done.count <= 1, "het einde van een verhaal wordt hooguit één keer gemeld")
	_close(hud)


func test_rewards_wait_their_turn(test) -> void:
	var hud := _hud()
	var done := Counter.new()
	hud.show_reward({"xp": 0, "items": []}, done.add)
	test.check(done.count == 1 and hud.rewards_waiting().is_empty() and not hud.is_showing_reward(), "een lege beloning is meteen klaar")
	hud.show_reward({"heading": "GEVONDEN", "title": "Op straat", "items": [{"item": "blikje", "count": 2}]}, done.add)
	test.check(hud.is_showing_reward() and hud.rewards_waiting().is_empty(), "een beloning komt meteen in beeld")
	hud.show_reward({"xp": 25}, done.add)
	test.check(hud.rewards_waiting().size() == 1, "de volgende wacht tot de eerste weg is")
	test.check(done.count == 1, "en is nog niet klaar")
	_close(hud)


func test_reward_waits_for_the_pause_menu(test) -> void:
	var hud := _hud()
	hud.set_paused(true)
	hud.show_reward({"xp": 25})
	test.check(not hud.is_showing_reward() and hud.rewards_waiting().size() == 1, "in het pauzemenu wacht een beloning")
	hud.set_paused(false)
	hud._open_waiting_reward()
	test.check(hud.is_showing_reward() and hud.rewards_waiting().is_empty(), "daarna komt ze")
	_close(hud)


func test_the_xp_of_a_reward_joins_the_level_up(test) -> void:
	var hud := _hud()
	hud.show_level_up(2, func(_stat_name: String) -> void: pass, func(_stat_name: String) -> Vector2: return Vector2(50.0, 100.0))
	hud.show_reward({"xp": 40})
	test.check(int(hud.level_ups_waiting()[0].get("xp", 0)) == 40, "de XP komt op het level-up-scherm")
	test.check(hud.rewards_waiting().is_empty() and not hud.is_showing_reward(), "en niet nog eens als beloning")
	_close(hud)


func test_small_things_without_a_town(test) -> void:
	var hud := _hud()
	test.check(not hud.is_showing_shop(), "geen winkel open")
	test.check(not hud.is_shrouded(Vector2(10.0, 10.0)), "zonder verhaal is niets verhuld")
	test.check(hud.visited_areas().is_empty(), "nog nergens geweest")
	test.check(hud.hidden_for_modal().is_empty(), "niets van de HUD verborgen voor een scherm over het spelmenu")
	test.check(GameHud.area_display_name("Centraal Station") == "Station Den Haag Centraal" and GameHud.area_display_name("Centrum") == "Centrum", "de naam van een wijk in beeld")
	hud.set_indoor_location("Centrum")
	test.check(hud.location.indoor_area() == "Centrum" and hud.location.seconds_to_look() == 0.0, "binnen: de wijk van het gebouw, meteen bijgewerkt")
	hud.set_menu_locked(true)
	test.check(hud.get_node("Spelmenu").locked, "het spelmenu op slot")
	hud.set_menu_locked(false)
	test.check(not hud.get_node("Spelmenu").locked, "en weer open")
	hud.set_actions([["E", "Praten"]])
	test.check(hud._action_prompts.get_child_count() > 0, "een actie linksonder")
	hud.show_thought("Ik heb honger.")
	test.check(hud._floating_numbers.view.numbers().size() == 0, "zonder speler geen gedachte")
	hud.show_floating_number(Vector3.ZERO, "+€ 0,50", Color.WHITE)
	test.check(hud._floating_numbers.view.numbers().size() == 1, "een getal dat opstijgt")
	hud.show_floating_number(Vector3.ZERO, "+€ 5,00", Color.WHITE, 18, true)
	test.check(hud._numbers_over_story.view.numbers().size() == 1, "en een over het verhaalvenster")
	_close(hud)


func test_minimap_without_a_town(test) -> void:
	var hud := _hud()
	test.check(hud.minimap_metres_per_pixel() > 0.0, "de kaart heeft een schaal")
	var origin_before := hud.minimap_origin()
	var texture_before := hud.minimap_texture()
	hud.show_town_plan()
	test.check(hud.minimap_origin() == origin_before and hud.minimap_texture() == texture_before, "al buiten: de kaart blijft")
	test.check(hud.shroud_image() == null, "zonder stad geen sluier")
	# the plan of an interior comes two physics steps later; going out again before it does
	var interior := Node3D.new()
	hud.get_parent().add_child(interior)
	var exits: Array[Vector3] = [Vector3(1.0, 0.0, 1.0)]
	hud.show_interior_plan(interior, exits)
	hud.show_town_plan()
	test.check(hud.minimap_texture() == texture_before and not hud.minimap.is_indoors(), "even binnen en weer buiten: de kaart van de stad blijft")
	_close(hud)
