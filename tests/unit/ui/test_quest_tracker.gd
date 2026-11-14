extends RefCounted
## Unit tests of the quest tracker of the HUD (scripts/ui/hud/quest_tracker.gd): the panel
## of the quest that is followed. The rules behind it: test_quest_log.gd.
##   tests/run_unit_tests.sh quest_tracker

const QuestTracker = preload("res://scripts/ui/hud/quest_tracker.gd")
const CheckSquare = preload("res://scripts/ui/widgets/check_square.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


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


func test_tracker_is_hidden_without_a_quest(test) -> void:
	var tracker := _tracker()
	test.check(not tracker.visible and tracker.get_child_count() == 0, "zonder quests: niet te zien")
	tracker.set_quests([{"id": "a", "done": true}])
	test.check(not tracker.visible, "alleen quests die klaar zijn: ook niet")
	test.check(tracker.distance_text() == "", "en geen afstand")
	tracker.set_distance(12.0)
	test.check(tracker.distance_text() == "", "een afstand zetten zonder paneel doet niets")
	tracker.free()


func test_tracker_shows_the_followed_main_quest(test) -> void:
	var tracker := _tracker()
	tracker.set_quests(_quests())
	test.check(tracker.visible and tracker.get_child_count() == 1, "één paneel: de gevolgde quest")
	var texts := _shown_texts(tracker)
	test.check(texts.has("◆ VERHAAL") and texts.has("Een kroket"), "met zijn label en titel (%s)" % [texts])
	test.check(texts.has("[s]Zoek blikjes[/s]") and texts.has("Lever ze in [lb]2/5]"), "de laatste afgeronde stap doorgestreept en de open stap (%s)" % [texts])
	test.check(not texts.has("Koop een kroket"), "een stap die op slot zit staat er niet")
	test.check(texts.has("+25 XP") and texts.has("+50 XP"), "met de XP van de stappen")
	var steps := tracker.find_child("Stappen", true, false)
	var boxes: Array = steps.find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node is CheckSquare)
	test.check(boxes.size() == 2 and boxes[0].done and not boxes[1].done, "het vakje van de afgeronde stap is gevuld")
	tracker.free()


func test_tracker_distance(test) -> void:
	var tracker := _tracker()
	tracker.set_quests(_quests())
	test.check(tracker.distance_text() == "", "eerst geen afstand")
	tracker.set_distance(239.6)
	test.check(tracker.distance_text() == "240 M", "de afstand in het paneel (%s)" % tracker.distance_text())
	tracker.set_distance(INF)
	test.check(tracker.distance_text() == "", "geen plek meer: leeg")
	tracker.free()


func test_tracker_follows_a_side_quest(test) -> void:
	var tracker := _tracker()
	tracker.set_quests(_quests())
	tracker.track("krant")
	var texts := _shown_texts(tracker)
	test.check(tracker.get_child_count() == 1 and texts == ["! ZIJMISSIE", "Verkoop de krant"], "een zijmissie: label en titel (%s)" % [texts])
	test.check(tracker.distance_text() == "", "een zijmissie heeft geen afstand")
	tracker.track("oud")
	test.check(_shown_texts(tracker) == texts, "een quest die klaar is volgen: het paneel blijft")
	tracker.free()


func test_step_text_and_locked_steps(test) -> void:
	test.check(QuestTracker.step_text({"text": "Praat met [Wim]"}) == "Praat met [lb]Wim]", "haken letterlijk")
	test.check(QuestTracker.step_text({"text": "Klaar", "done": true}) == "[s]Klaar[/s]", "klaar: doorgestreept")
	test.check(QuestTracker.step_text({}) == "", "zonder tekst: leeg")
	var tracker := _tracker()
	# a locked step shows when it is the only one open: an optional one that is locked is not open
	tracker.set_quests([{"id": "a", "steps": [{"text": "eerst", "done": false}, {"text": "later", "done": false, "locked": true}]}])
	var rows := tracker.find_child("Stappen", true, false).get_children()
	test.check(rows.size() == 1 and is_equal_approx(rows[0].modulate.a, 1.0), "de open stap is gewoon te zien")
	tracker.free()
