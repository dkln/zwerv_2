extends RefCounted
## Unit tests of the picture of the quest tracker (scripts/ui/hud/quest_tracker_view.gd):
## the panel of a main quest, of a side quest, and the distance.
##   tests/run_unit_tests.sh quest_tracker_view

const QuestTrackerView = preload("res://scripts/ui/hud/quest_tracker_view.gd")
const Layout = preload("res://scripts/ui/hud/quest_tracker_layout.gd")
const CheckSquare = preload("res://scripts/ui/widgets/check_square.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _view() -> QuestTrackerView:
	var view := QuestTrackerView.new()
	tree.root.add_child(view)
	return view


## The texts of every Label and RichTextLabel under `node`, in order.
static func _shown_texts(node: Node) -> Array:
	var texts: Array = []
	for child in node.get_children():
		if child is Label or child is RichTextLabel:
			texts.append(child.text)
		texts.append_array(_shown_texts(child))
	return texts


static func _steps() -> Array:
	return [
		{"text": "[s]Zoek blikjes[/s]", "done": true, "locked": false, "xp": "+25 XP"},
		{"text": "Lever ze in", "done": false, "locked": false, "xp": ""},
		{"text": "Koop een kroket", "done": false, "locked": true, "xp": "+50 XP"},
	]


func test_starts_empty_and_as_wide_as_its_layout(test) -> void:
	var view := _view()
	test.check(view.get_child_count() == 0 and view.distance_text() == "", "eerst geen paneel")
	test.check(view.custom_minimum_size.x == Layout.WIDTH, "zo breed als de layout zegt")
	view.show_distance("12 M")
	test.check(view.distance_text() == "", "een afstand zonder paneel doet niets")
	view.free()


func test_main_quest_panel(test) -> void:
	var view := _view()
	view.show_main_quest("VERHAAL", "Een kroket", "240 M", _steps())
	var texts := _shown_texts(view)
	test.check(view.get_child_count() == 1, "één paneel")
	test.check(texts.slice(0, 3) == ["◆ VERHAAL", "240 M", "Een kroket"], "label, afstand en titel (%s)" % [texts])
	test.check(texts.has("[s]Zoek blikjes[/s]") and texts.has("Lever ze in") and texts.has("Koop een kroket"), "de stappen zoals aangereikt")
	test.check(texts.count("+25 XP") == 1 and texts.count("+50 XP") == 1, "de XP alleen waar die er is")
	var rows := view.find_child("Stappen", true, false).get_children()
	var boxes: Array = rows.map(func(row: Node) -> bool: return (row.get_child(0) as CheckSquare).done)
	test.check(boxes == [true, false, false], "het vakje gevuld bij de afgeronde stap (%s)" % [boxes])
	test.check(is_equal_approx(rows[0].modulate.a, 1.0) and is_equal_approx(rows[2].modulate.a, QuestTrackerView.LOCKED_STEP_OPACITY), "een stap op slot is doorzichtig")
	view.free()


func test_distance_in_the_panel(test) -> void:
	var view := _view()
	view.show_main_quest("VERHAAL", "Een kroket", "", [])
	test.check(view.distance_text() == "", "eerst geen afstand")
	view.show_distance("120 M")
	test.check(view.distance_text() == "120 M", "de afstand in het paneel")
	view.show_distance("")
	test.check(view.distance_text() == "", "en weer leeg")
	view.free()


func test_side_quest_panel_replaces_the_one_before(test) -> void:
	var view := _view()
	view.show_main_quest("VERHAAL", "Een kroket", "240 M", _steps())
	view.show_side_quest("ZIJMISSIE", "Verkoop de krant")
	test.check(view.get_child_count() == 1 and _shown_texts(view) == ["! ZIJMISSIE", "Verkoop de krant"], "alleen de zijmissie (%s)" % [_shown_texts(view)])
	test.check(view.distance_text() == "", "een zijmissie heeft geen afstand")
	view.show_nothing()
	test.check(view.get_child_count() == 0, "niets gevolgd: geen paneel")
	view.free()
