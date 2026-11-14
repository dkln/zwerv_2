extends RefCounted
## Unit tests of the quests of the HUD, the rules (scripts/ui/hud/quest_log.gd): which quest
## is followed, which steps the tracker shows, where a quest sends the player.
##   tests/run_unit_tests.sh quest_log

const QuestLog = preload("res://scripts/ui/hud/quest_log.gd")


static func _texts(steps: Array) -> Array:
	return steps.map(func(step: Dictionary) -> String: return step.text)


## Three quests: a main one with steps, a side one, and a main one that is done.
static func _quests() -> Array:
	return [
		{"id": "kroket", "kind": "verhaal", "label": "VERHAAL", "title": "Een kroket", "steps": [
			{"text": "Zoek blikjes", "done": true, "xp": 25},
			{"text": "Lever ze in [2/5]", "done": false, "targets": [Vector2(10.0, 0.0), Vector2(100.0, 0.0)], "xp": 50},
			{"text": "Koop een kroket", "done": false, "locked": true, "targets": [Vector2(5.0, 5.0)]}]},
		{"id": "krant", "kind": "zij", "label": "ZIJMISSIE", "title": "Verkoop de krant"},
		{"id": "oud", "kind": "verhaal", "title": "Al gedaan", "done": true},
	]


func test_quest_id_done_and_kind(test) -> void:
	test.check(QuestLog.quest_id({"id": "kroket", "title": "Een kroket"}) == "kroket", "een quest heet naar zijn id")
	test.check(QuestLog.quest_id({"title": "Een kroket"}) == "Een kroket", "zonder id: naar zijn titel")
	test.check(QuestLog.quest_id({}) == "", "zonder iets: leeg")
	test.check(QuestLog.is_done({"done": true}) and not QuestLog.is_done({"done": false}) and not QuestLog.is_done({}), "klaar of niet")
	test.check(QuestLog.is_main({"kind": "verhaal"}) and QuestLog.is_main({}) and not QuestLog.is_main({"kind": "zij"}), "verhaal (ook zonder soort) of zijmissie")


func test_tracker_steps_only_the_last_done_and_the_open_one(test) -> void:
	var quest := {"steps": [{"text": "a", "done": true}, {"text": "b", "done": true}, {"text": "c", "done": false},
		{"text": "d", "done": false, "locked": true}, {"text": "e", "done": false, "locked": true}]}
	test.check(_texts(QuestLog.tracker_steps(quest)) == ["b", "c"], "de laatste afgeronde en de open taak (%s)" % [_texts(QuestLog.tracker_steps(quest))])
	var at_start := {"steps": [{"text": "a", "done": false}, {"text": "b", "done": false, "locked": true}]}
	test.check(_texts(QuestLog.tracker_steps(at_start)) == ["a"], "aan het begin alleen de eerste")
	var optional_first := {"steps": [{"text": "x", "done": false, "optional": true}, {"text": "y", "done": false}]}
	test.check(_texts(QuestLog.tracker_steps(optional_first)) == ["y"], "een optionele niet als er een gewone open is")
	var only_optional := {"steps": [{"text": "a", "done": true}, {"text": "x", "done": false, "optional": true}]}
	test.check(_texts(QuestLog.tracker_steps(only_optional)) == ["a", "x"], "een optionele wel als er niets anders open is")
	var all_done := {"steps": [{"text": "a", "done": true}, {"text": "b", "done": true}]}
	test.check(_texts(QuestLog.tracker_steps(all_done)) == ["b"], "alles klaar: alleen de laatste")
	test.check(QuestLog.tracker_steps({}).is_empty(), "geen stappen: niets")


func test_targets_of_the_step_under_way(test) -> void:
	var quests := _quests()
	test.check(QuestLog.targets_of(quests[0]) == [Vector2(10.0, 0.0), Vector2(100.0, 0.0)], "de plekken van de eerste stap die niet klaar is")
	var locked_next := {"steps": [{"text": "a", "done": true}, {"text": "b", "done": false, "locked": true, "targets": [Vector2.ONE]}]}
	test.check(QuestLog.targets_of(locked_next).is_empty(), "die stap op slot: nog geen plekken")
	var optional_first := {"steps": [{"text": "x", "done": false, "optional": true, "targets": [Vector2.ONE]}, {"text": "y", "done": false, "targets": [Vector2(7.0, 7.0)]}]}
	test.check(QuestLog.targets_of(optional_first) == [Vector2(7.0, 7.0)], "een optionele stap houdt de volgende niet op")
	test.check(QuestLog.targets_of({"steps": [{"text": "a", "done": false}]}).is_empty(), "een stap zonder plekken: geen")
	test.check(QuestLog.targets_of({}).is_empty() and QuestLog.targets_of(quests[1]).is_empty(), "geen stappen: geen plekken")


func test_nearest_distance_and_its_text(test) -> void:
	var targets := [Vector2(10.0, 0.0), Vector2(100.0, 0.0)]
	test.check(is_equal_approx(QuestLog.nearest_distance(targets, Vector2.ZERO), 10.0), "de dichtstbijzijnde plek telt")
	test.check(is_equal_approx(QuestLog.nearest_distance(targets, Vector2(90.0, 0.0)), 10.0), "ook van de andere kant")
	test.check(QuestLog.nearest_distance([], Vector2.ZERO) == INF, "geen plekken: oneindig")
	test.check(QuestLog.distance_text(239.6) == "240 M", "afgerond in meters (%s)" % QuestLog.distance_text(239.6))
	test.check(QuestLog.distance_text(0.2) == "0 M", "vlakbij: 0 M")
	test.check(QuestLog.distance_text(INF) == "", "geen afstand: niets")


func test_the_first_open_quest_is_followed(test) -> void:
	var quest_log := QuestLog.new()
	test.check(quest_log.tracked_id() == "" and quest_log.tracked().is_empty() and quest_log.targets().is_empty(), "zonder quests: niets gevolgd")
	test.check(quest_log.next_open_id("") == "", "en niets om te volgen")
	quest_log.set_quests(_quests())
	test.check(quest_log.quests().size() == 3, "drie quests")
	test.check(quest_log.tracked_id() == "kroket", "de eerste open quest wordt gevolgd")
	test.check(quest_log.tracked().title == "Een kroket", "de gevolgde quest zelf")
	test.check(quest_log.by_id("krant").kind == "zij" and quest_log.by_id("bestaat_niet").is_empty(), "een quest bij zijn id")
	test.check(quest_log.targets() == [Vector2(10.0, 0.0), Vector2(100.0, 0.0)], "de plekken van de gevolgde quest")


func test_the_log_keeps_a_copy(test) -> void:
	var quest_log := QuestLog.new()
	var given := _quests()
	quest_log.set_quests(given)
	given[0].title = "Veranderd"
	(given[0].steps as Array).clear()
	test.check(quest_log.by_id("kroket").title == "Een kroket" and (quest_log.by_id("kroket").steps as Array).size() == 3, "wat erna verandert raakt het logboek niet")


func test_track_follows_another_open_quest(test) -> void:
	var quest_log := QuestLog.new()
	quest_log.set_quests(_quests())
	test.check(quest_log.track("krant") and quest_log.tracked_id() == "krant", "een andere open quest volgen")
	test.check(not quest_log.track("krant"), "die al gevolgd wordt: er verandert niets")
	test.check(not quest_log.track("oud") and quest_log.tracked_id() == "krant", "een quest die klaar is kan niet gevolgd worden")
	test.check(not quest_log.track("bestaat_niet") and quest_log.tracked_id() == "krant", "een quest die er niet is ook niet")
	quest_log.set_quests(_quests())
	test.check(quest_log.tracked_id() == "krant", "dezelfde quests opnieuw: de gevolgde blijft")


func test_next_open_quest_after_one_is_done_or_gone(test) -> void:
	var quest_log := QuestLog.new()
	quest_log.set_quests(_quests())
	var done_first := _quests()
	done_first[0]["done"] = true
	quest_log.set_quests(done_first)
	test.check(quest_log.tracked_id() == "krant", "de gevolgde quest klaar: de eerste open erna (%s)" % quest_log.tracked_id())
	var four := [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}]
	quest_log.set_quests(four)
	quest_log.track("b")
	quest_log.set_quests([{"id": "a"}, {"id": "c"}, {"id": "d"}])
	test.check(quest_log.tracked_id() == "c", "de gevolgde quest weg: die erna stond (%s)" % quest_log.tracked_id())
	quest_log.track("d")
	quest_log.set_quests([{"id": "a"}, {"id": "c"}, {"id": "d", "done": true}])
	test.check(quest_log.tracked_id() == "a", "de laatste klaar: weer vooraan (%s)" % quest_log.tracked_id())
	quest_log.set_quests([{"id": "a", "done": true}, {"id": "c", "done": true}])
	test.check(quest_log.tracked_id() == "", "alles klaar: niets meer te volgen")
	test.check(quest_log.next_open_id("a") == "" and quest_log.next_open_id("weg", ["weg", "c"]) == "", "ook niet na een quest die weg is")
