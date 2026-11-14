extends RefCounted
## Unit tests of how the action prompts look (scripts/ui/screens/action_prompts_view.gd):
## the panels it builds for the texts it is handed and the key caps as wide as each other.
##   tests/run_unit_tests.sh action_prompts_view

const ActionPromptsView = preload("res://scripts/ui/screens/action_prompts_view.gd")
const ActionPromptsLayout = preload("res://scripts/ui/screens/action_prompts_layout.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_show_actions_builds_a_panel_per_row(test) -> void:
	var view := ActionPromptsView.new()
	test.check(view.name == "Beeld" and view.panel_count() == 0, "eerst leeg")
	test.check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.get_theme_constant("separation") == ActionPromptsLayout.PANEL_GAP, "klikken erdoorheen, ruimte tussen de paneeltjes")
	view.show_actions([["SPATIE", "Overslaan"], ["ENTER", "Sneller"]])
	test.check(view.panel_count() == 2, "twee rijen: twee paneeltjes")
	test.check(view.key_text(0) == "SPATIE" and view.action_text(0) == "Overslaan", "de toets en wat hij doet")
	test.check(view.key_text(1) == "ENTER" and view.action_text(1) == "Sneller", "de tweede eronder")
	var panel := view.get_child(0) as PanelContainer
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	test.check(style.bg_color == UiStyle.TRANSLUCENT_INK and style.border_color == UiStyle.BORDER, "op inkt met een rand")
	test.check(style.content_margin_left == ActionPromptsLayout.PANEL_MARGIN_LEFT and style.content_margin_right == ActionPromptsLayout.PANEL_MARGIN_RIGHT, "met de marges van de layout")
	test.check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ook de paneeltjes laten klikken door")
	view.free()


func test_show_actions_replaces_the_panels(test) -> void:
	var view := ActionPromptsView.new()
	view.show_actions([["E", "Praten"], ["F", "Eten"]])
	var first := view.get_child(0)
	view.show_actions([["E", "Naar binnen"]])
	test.check(view.panel_count() == 1 and view.get_child(0) != first and first.is_queued_for_deletion(), "nieuwe rijen vervangen de oude paneeltjes")
	test.check(view.action_text(0) == "Naar binnen", "met de nieuwe tekst")
	view.show_actions([])
	test.check(view.panel_count() == 0, "geen rijen: leeg")
	view.free()


func test_key_cap_looks_like_a_key(test) -> void:
	var view := ActionPromptsView.new()
	view.show_actions([["E", "Praten"]])
	var cap := view.key_cap(0)
	var style := cap.get_theme_stylebox("panel") as StyleBoxFlat
	var label := cap.get_child(0) as Label
	test.check(style.bg_color == UiStyle.TEXT and style.shadow_offset == ActionPromptsLayout.KEY_SHADOW, "een lichte toets met een harde schaduw eronder")
	test.check(label.get_theme_color("font_color") == UiStyle.INK and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "de naam in inkt, in het midden")
	view.free()


func test_key_caps_are_as_wide_as_the_widest(test) -> void:
	var view := ActionPromptsView.new()
	tree.root.add_child(view)
	view.show_actions([["E", "Praten"], ["SPATIE", "Springen"], ["F", "Eten"]])
	view.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var widest_label := (view.key_cap(1).get_child(0) as Control).get_combined_minimum_size().x
	var cap_width := view.key_cap(0).custom_minimum_size.x
	test.check(cap_width > widest_label, "breder dan de breedste naam met zijn randen (%s om %s)" % [cap_width, widest_label])
	test.check(is_equal_approx(view.key_cap(1).custom_minimum_size.x, cap_width) and is_equal_approx(view.key_cap(2).custom_minimum_size.x, cap_width), "alle toetsen even breed")
	view.show_actions([["E", "Praten"]])
	view.notification(Container.NOTIFICATION_SORT_CHILDREN)
	test.check(view.key_cap(0).custom_minimum_size.x < cap_width, "zonder de brede toets: smaller")
	view.notification(Node.NOTIFICATION_PROCESS)
	test.check(view.panel_count() == 1, "een andere melding doet niets")
	view.free()
