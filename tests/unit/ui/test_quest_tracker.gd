extends RefCounted
## Unit tests of the quest tracker of the HUD (scripts/ui/hud/quest_tracker.gd): it keeps
## the quests and which one is followed, and shows that one. The rules behind it:
## test_quest_rules.gd; its picture: test_quest_tracker_view.gd.
##   tests/run_unit_tests.sh test_quest_tracker.gd

const QuestTracker = preload("res://scripts/ui/hud/quest_tracker.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


static func _quests() -> Array:
	return [
		{"id": "kroket", "kind": "verhaal", "label": "VERHAAL", "title": "Een kroket", "steps": [
			{"text": "Zoek blikjes", "done": true, "xp": 25},
			{"text": "Lever ze in [2/5]", "done": false, "targets": [Vector2(10.0, 0.0), Vector2(100.0, 0.0)], "xp": 50},
			{"text": "Koop een kroket", "done": false, "locked": true, "targets": [Vector2(5.0, 5.0)]}]},
		{"id": "krant", "kind": "zij", "label": "ZIJMISSIE", "title": "Verkoop de krant"},
		{"id": "oud", "kind": "verhaal", "title": "Al gedaan", "done": true},
	]


func _tracker() -> QuestTracker:
	var tracker := QuestTracker.new()
	tree.root.add_child(tracker)
	return tracker


## The texts of every Label and RichTextLabel under `node`, in order.
static func _shown_texts(node: Node) -> Array:
	var texts: Array = []
	for child in node.get_children():
		if child is Label or child is RichTextLabel:
			texts.append(child.text)
		texts.append_array(_shown_texts(child))
	return texts


func test_hidden_without_a_quest(test) -> void:
	var tracker := _tracker()
	test.check(tracker.name == "Opdrachten" and not tracker.visible and tracker.quests().is_empty(), "zonder quests: niet te zien")
	test.check(tracker.tracked_id() == "" and tracker.tracked().is_empty() and tracker.targets().is_empty(), "niets gevolgd")
	test.check(tracker.next_open_id("") == "", "en niets om te volgen")
	tracker.set_quests([{"id": "a", "done": true}])
	test.check(not tracker.visible and tracker.tracked_id() == "", "alleen quests die klaar zijn: ook niet")
	tracker.free()


func test_the_first_open_quest_is_followed_and_shown(test) -> void:
	var tracker := _tracker()
	tracker.set_quests(_quests())
	test.check(tracker.visible and tracker.tracked_id() == "kroket" and tracker.tracked().title == "Een kroket", "de eerste open quest")
	test.check(tracker.quests().size() == 3 and tracker.by_id("krant").kind == "zij" and tracker.by_id("niets").is_empty(), "de quests bij hun id")
	test.check(tracker.targets() == [Vector2(10.0, 0.0), Vector2(100.0, 0.0)], "de plekken van de gevolgde quest")
	var texts := _shown_texts(tracker.view)
	test.check(texts.has("◆ VERHAAL") and texts.has("Een kroket"), "zijn label en titel in beeld (%s)" % [texts])
	test.check(texts.has("[s]Zoek blikjes[/s]") and texts.has("Lever ze in [lb]2/5]") and not texts.has("Koop een kroket"), "de laatste afgeronde en de open stap, niet die op slot")
	test.check(texts.has("+25 XP") and texts.has("+50 XP"), "met hun XP")
	tracker.free()


func test_the_tracker_keeps_a_copy(test) -> void:
	var tracker := _tracker()
	var given := _quests()
	tracker.set_quests(given)
	given[0].title = "Veranderd"
	test.check(tracker.by_id("kroket").title == "Een kroket", "wat erna verandert raakt de tracker niet")
	tracker.free()


func test_track_follows_another_open_quest(test) -> void:
	var tracker := _tracker()
	tracker.set_quests(_quests())
	tracker.track("krant")
	test.check(tracker.tracked_id() == "krant" and _shown_texts(tracker.view) == ["! ZIJMISSIE", "Verkoop de krant"], "een zijmissie volgen: haar paneel (%s)" % [_shown_texts(tracker.view)])
	tracker.track("oud")
	tracker.track("bestaat_niet")
	test.check(tracker.tracked_id() == "krant", "een quest die klaar is of er niet is: er verandert niets")
	tracker.set_quests(_quests())
	test.check(tracker.tracked_id() == "krant", "dezelfde quests opnieuw: de gevolgde blijft")
	test.check(tracker.next_open_id("krant") == "kroket", "na de laatste open quest weer de eerste")
	tracker.free()


func test_goes_on_when_the_followed_quest_is_done_or_gone(test) -> void:
	var tracker := _tracker()
	tracker.set_quests(_quests())
	var done_first := _quests()
	done_first[0]["done"] = true
	tracker.set_quests(done_first)
	test.check(tracker.tracked_id() == "krant", "de gevolgde klaar: de eerste open erna")
	tracker.set_quests([{"id": "a"}, {"id": "b"}, {"id": "c"}])
	tracker.track("b")
	tracker.set_quests([{"id": "a"}, {"id": "c"}])
	test.check(tracker.tracked_id() == "c", "de gevolgde weg: die erna stond (%s)" % tracker.tracked_id())
	tracker.set_quests([])
	test.check(tracker.tracked_id() == "" and not tracker.visible, "geen quests meer: de tracker weg")
	tracker.free()


func test_distance_to_the_nearest_place(test) -> void:
	var tracker := _tracker()
	tracker.set_quests(_quests())
	tracker.show_distance_from(Vector2(90.0, 0.0))
	test.check(tracker.view.distance_text() == "10 M", "de dichtstbijzijnde plek van de gevolgde quest (%s)" % tracker.view.distance_text())
	tracker.track("krant")
	tracker.show_distance_from(Vector2(90.0, 0.0))
	test.check(tracker.view.distance_text() == "", "een zijmissie zonder plekken: geen afstand")
	tracker.free()
