extends RefCounted
## Unit tests of the rules of the quests (scripts/ui/hud/quest_rules.gd): what names a quest,
## which one is followed next, which steps the tracker shows, where a quest sends the player.
##   tests/run_unit_tests.sh quest_rules

const QuestRules = preload("res://scripts/ui/hud/quest_rules.gd")


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
	test.check(QuestRules.quest_id({"id": "kroket", "title": "Een kroket"}) == "kroket", "een quest heet naar zijn id")
	test.check(QuestRules.quest_id({"title": "Een kroket"}) == "Een kroket", "zonder id: naar zijn titel")
	test.check(QuestRules.quest_id({}) == "", "zonder iets: leeg")
	test.check(QuestRules.is_done({"done": true}) and not QuestRules.is_done({"done": false}) and not QuestRules.is_done({}), "klaar of niet")
	test.check(QuestRules.is_main({"kind": "verhaal"}) and QuestRules.is_main({}) and not QuestRules.is_main({"kind": "zij"}), "verhaal (ook zonder soort) of zijmissie")


func test_by_id_and_can_track(test) -> void:
	var quests := _quests()
	test.check(QuestRules.by_id(quests, "krant").kind == "zij" and QuestRules.by_id(quests, "bestaat_niet").is_empty(), "een quest bij zijn id")
	test.check(QuestRules.by_id([], "krant").is_empty(), "geen quests: niets")
	test.check(QuestRules.can_track(quests, "krant", "kroket"), "een andere open quest kan gevolgd worden")
	test.check(not QuestRules.can_track(quests, "kroket", "kroket"), "die al gevolgd wordt niet nog eens")
	test.check(not QuestRules.can_track(quests, "oud", "kroket"), "een quest die klaar is niet")
	test.check(not QuestRules.can_track(quests, "bestaat_niet", "kroket"), "een quest die er niet is ook niet")


func test_tracker_steps_only_the_last_done_and_the_open_one(test) -> void:
	var quest := {"steps": [{"text": "a", "done": true}, {"text": "b", "done": true}, {"text": "c", "done": false},
		{"text": "d", "done": false, "locked": true}, {"text": "e", "done": false, "locked": true}]}
	test.check(_texts(QuestRules.tracker_steps(quest)) == ["b", "c"], "de laatste afgeronde en de open taak (%s)" % [_texts(QuestRules.tracker_steps(quest))])
	var at_start := {"steps": [{"text": "a", "done": false}, {"text": "b", "done": false, "locked": true}]}
	test.check(_texts(QuestRules.tracker_steps(at_start)) == ["a"], "aan het begin alleen de eerste")
	var optional_first := {"steps": [{"text": "x", "done": false, "optional": true}, {"text": "y", "done": false}]}
	test.check(_texts(QuestRules.tracker_steps(optional_first)) == ["y"], "een optionele niet als er een gewone open is")
	var only_optional := {"steps": [{"text": "a", "done": true}, {"text": "x", "done": false, "optional": true}]}
	test.check(_texts(QuestRules.tracker_steps(only_optional)) == ["a", "x"], "een optionele wel als er niets anders open is")
	var all_done := {"steps": [{"text": "a", "done": true}, {"text": "b", "done": true}]}
	test.check(_texts(QuestRules.tracker_steps(all_done)) == ["b"], "alles klaar: alleen de laatste")
	test.check(QuestRules.tracker_steps({}).is_empty(), "geen stappen: niets")


func test_a_step_as_it_is_written(test) -> void:
	test.check(QuestRules.step_text({"text": "Praat met [Wim]"}) == "Praat met [lb]Wim]", "haken letterlijk")
	test.check(QuestRules.step_text({"text": "Klaar", "done": true}) == "[s]Klaar[/s]", "klaar: doorgestreept")
	test.check(QuestRules.step_text({}) == "", "zonder tekst: leeg")
	test.check(QuestRules.step_xp_text({"xp": 25}) == "+25 XP" and QuestRules.step_xp_text({}) == "" and QuestRules.step_xp_text({"xp": 0}) == "", "de XP van een stap, of niets")
	test.check(QuestRules.is_locked({"locked": true}) and not QuestRules.is_locked({}), "op slot of niet")
	test.check(not QuestRules.is_locked({"locked": true, "done": true}), "een afgeronde stap is niet meer op slot")


func test_targets_of_the_step_under_way(test) -> void:
	var quests := _quests()
	test.check(QuestRules.targets_of(quests[0]) == [Vector2(10.0, 0.0), Vector2(100.0, 0.0)], "de plekken van de eerste stap die niet klaar is")
	var locked_next := {"steps": [{"text": "a", "done": true}, {"text": "b", "done": false, "locked": true, "targets": [Vector2.ONE]}]}
	test.check(QuestRules.targets_of(locked_next).is_empty(), "die stap op slot: nog geen plekken")
	var optional_first := {"steps": [{"text": "x", "done": false, "optional": true, "targets": [Vector2.ONE]}, {"text": "y", "done": false, "targets": [Vector2(7.0, 7.0)]}]}
	test.check(QuestRules.targets_of(optional_first) == [Vector2(7.0, 7.0)], "een optionele stap houdt de volgende niet op")
	test.check(QuestRules.targets_of({"steps": [{"text": "a", "done": false}]}).is_empty(), "een stap zonder plekken: geen")
	test.check(QuestRules.targets_of({}).is_empty() and QuestRules.targets_of(quests[1]).is_empty(), "geen stappen: geen plekken")


func test_nearest_distance_and_its_text(test) -> void:
	var targets := [Vector2(10.0, 0.0), Vector2(100.0, 0.0)]
	test.check(is_equal_approx(QuestRules.nearest_distance(targets, Vector2.ZERO), 10.0), "de dichtstbijzijnde plek telt")
	test.check(is_equal_approx(QuestRules.nearest_distance(targets, Vector2(90.0, 0.0)), 10.0), "ook van de andere kant")
	test.check(QuestRules.nearest_distance([], Vector2.ZERO) == INF, "geen plekken: oneindig")
	test.check(QuestRules.distance_text(239.6) == "240 M", "afgerond in meters (%s)" % QuestRules.distance_text(239.6))
	test.check(QuestRules.distance_text(0.2) == "0 M", "vlakbij: 0 M")
	test.check(QuestRules.distance_text(INF) == "", "geen afstand: niets")


func test_next_open_quest(test) -> void:
	var quests := _quests()
	test.check(QuestRules.next_open_id(quests, "") == "kroket", "niets gevolgd: de eerste open quest")
	test.check(QuestRules.next_open_id(quests, "kroket") == "krant", "na de eerste: de volgende open")
	test.check(QuestRules.next_open_id(quests, "krant") == "kroket", "na de laatste open: weer vooraan (de afgeronde overgeslagen)")
	test.check(QuestRules.next_open_id([], "kroket") == "", "geen quests: niets")
	test.check(QuestRules.next_open_id([{"id": "a", "done": true}], "a") == "", "alles klaar: niets")
	var after_removal := [{"id": "a"}, {"id": "c"}, {"id": "d"}]
	test.check(QuestRules.next_open_id(after_removal, "b", ["a", "b", "c", "d"]) == "c", "een quest die weg is: die erna stond")
	test.check(QuestRules.next_open_id(after_removal, "b", ["a", "b"]) == "a", "er stond niets meer na: de eerste open")
	test.check(QuestRules.next_open_id([{"id": "a"}, {"id": "c", "done": true}, {"id": "d"}], "b", ["a", "b", "c", "d"]) == "d", "die erna klaar: de volgende open")


func test_tracked_after_the_quests_change(test) -> void:
	var quests := _quests()
	test.check(QuestRules.tracked_after_change(quests, "", []) == "kroket", "nog niets gevolgd: de eerste open")
	test.check(QuestRules.tracked_after_change(quests, "krant", ["kroket", "krant", "oud"]) == "krant", "de gevolgde is er nog en open: die blijft")
	var done_first := _quests()
	done_first[0]["done"] = true
	test.check(QuestRules.tracked_after_change(done_first, "kroket", ["kroket", "krant", "oud"]) == "krant", "de gevolgde klaar: de eerste open erna")
	test.check(QuestRules.tracked_after_change([], "kroket", ["kroket"]) == "", "geen quests meer: niets")
