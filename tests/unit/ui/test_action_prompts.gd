extends RefCounted
## Unit tests of the action prompts (scripts/ui/action_prompts.gd, the behaviour): the
## panels set_actions asks for, actions(), the key caps as wide as each other, and the
## controller's names on them. Its logic, sizes and look: test_action_prompts_rules.gd,
## test_action_prompts_layout.gd, test_action_prompts_view.gd.
##   tests/run_unit_tests.sh action_prompts

const PadKeys = preload("res://scripts/ui/pad_keys.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## The key cap (the PanelContainer round the key's name) of panel `index`.
static func _key_cap(prompts: ActionPrompts, index: int) -> Control:
	return prompts.view().key_cap(index)


static func _key_text(prompts: ActionPrompts, index: int) -> String:
	return prompts.view().key_text(index)


static func _action_text(prompts: ActionPrompts, index: int) -> String:
	return prompts.view().action_text(index)


func test_set_actions_makes_a_panel_per_action(test) -> void:
	var prompts := ActionPrompts.new()
	test.check(not prompts.visible and prompts.actions().is_empty(), "eerst niets te doen: verborgen")
	test.check(prompts.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	var was_pad: bool = PadKeys.last_was_pad
	PadKeys.last_was_pad = false
	prompts.set_actions([["SPATIE", "Overslaan"], ["ENTER", "Sneller"]])
	test.check(prompts.visible and prompts.view().panel_count() == 2, "twee acties: twee paneeltjes")
	test.check(_key_text(prompts, 0) == "SPATIE" and _action_text(prompts, 0) == "Overslaan", "de toets en wat hij doet")
	test.check(_key_text(prompts, 1) == "ENTER" and _action_text(prompts, 1) == "Sneller", "de tweede eronder")
	test.check(prompts.view().get_theme_constant("separation") == ActionPrompts.PANEL_GAP, "met ruimte ertussen")
	test.check((prompts.view().get_child(0) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE and prompts.view().get_parent() == prompts, "ook de paneeltjes laten klikken door")
	prompts.set_actions([[1, 2]])
	test.check(_key_text(prompts, 0) == "1" and _action_text(prompts, 0) == "2", "wat geen tekst is wordt tekst")
	PadKeys.last_was_pad = was_pad
	prompts.free()


func test_actions_gives_a_copy(test) -> void:
	var prompts := ActionPrompts.new()
	var wanted := [["E", "Praten"], ["F", "Eten"]]
	prompts.set_actions(wanted)
	test.check(prompts.actions() == wanted, "wat er nu staat")
	wanted[0][1] = "Iets anders"
	test.check(prompts.actions()[0][1] == "Praten", "de lijst van de aanroeper veranderen doet niets")
	var given := prompts.actions()
	given.clear()
	test.check(prompts.actions().size() == 2, "en die van actions() ook niet")
	prompts.free()


func test_the_same_actions_again_change_nothing(test) -> void:
	var prompts := ActionPrompts.new()
	prompts.set_actions([["E", "Praten"]])
	var panel := prompts.view().get_child(0)
	prompts.set_actions([["E", "Praten"]])
	test.check(prompts.view().get_child(0) == panel, "dezelfde acties: de paneeltjes blijven")
	prompts.set_actions([["E", "Naar binnen"]])
	test.check(prompts.view().panel_count() == 1 and prompts.view().get_child(0) != panel, "andere acties: nieuwe paneeltjes")
	test.check(_action_text(prompts, 0) == "Naar binnen", "met de nieuwe tekst")
	prompts.free()


func test_no_actions_hide_it(test) -> void:
	var prompts := ActionPrompts.new()
	prompts.set_actions([["E", "Praten"]])
	prompts.set_actions([])
	test.check(not prompts.visible and prompts.view().panel_count() == 0, "niets te doen: verborgen en leeg")
	test.check(prompts.actions().is_empty(), "en actions() is leeg")
	prompts.free()


func test_key_caps_are_as_wide_as_the_widest(test) -> void:
	var prompts := ActionPrompts.new()
	tree.root.add_child(prompts)
	var was_pad: bool = PadKeys.last_was_pad
	PadKeys.last_was_pad = false
	prompts.set_actions([["E", "Praten"], ["SPATIE", "Springen"], ["F", "Eten"]])
	prompts.view().notification(Container.NOTIFICATION_SORT_CHILDREN)
	var widest_label := 0.0
	for index in 3:
		widest_label = maxf(widest_label, (_key_cap(prompts, index).get_child(0) as Control).get_combined_minimum_size().x)
	var cap_width := _key_cap(prompts, 0).custom_minimum_size.x
	test.check(cap_width > widest_label, "breder dan de breedste naam (SPATIE) met zijn randen (%s om %s)" % [cap_width, widest_label])
	test.check(is_equal_approx(_key_cap(prompts, 1).custom_minimum_size.x, cap_width) and is_equal_approx(_key_cap(prompts, 2).custom_minimum_size.x, cap_width), "alle toetsen even breed")
	test.check((_key_cap(prompts, 0).get_child(0) as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "de naam in het midden")
	prompts.set_actions([["E", "Praten"], ["F", "Eten"]])
	prompts.view().notification(Container.NOTIFICATION_SORT_CHILDREN)
	test.check(_key_cap(prompts, 0).custom_minimum_size.x < cap_width, "zonder de brede toets: smaller")
	PadKeys.last_was_pad = was_pad
	prompts.free()


func test_a_controller_shows_its_own_buttons(test) -> void:
	var prompts := ActionPrompts.new()
	var was_pad: bool = PadKeys.last_was_pad
	PadKeys.last_was_pad = true
	prompts.set_actions([["E", "Praten"], ["SPATIE", "Springen"], ["F4", "Iets"]])
	test.check(_key_text(prompts, 0) == "A" and _key_text(prompts, 1) == "B", "met een controller: zijn knoppen (%s, %s)" % [_key_text(prompts, 0), _key_text(prompts, 1)])
	test.check(_key_text(prompts, 2) == "F4", "een toets zonder knop blijft")
	test.check(prompts.actions()[0][0] == "E", "actions() geeft wat gevraagd is")
	PadKeys.last_was_pad = was_pad
	prompts.free()
