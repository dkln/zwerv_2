extends RefCounted
## Unit tests of how the pause menu looks (scripts/ui/screens/pause_menu_view.gd): what it
## builds and what it shows when told, without the behaviour around it.
##   tests/run_unit_tests.sh pause_menu_view

const PauseMenuView = preload("res://scripts/ui/screens/pause_menu_view.gd")
const PauseMenuLayout = preload("res://scripts/ui/screens/pause_menu_layout.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Remembers what the view passes on of the mouse.
class Listener:
	var hovered: Array = []
	var pressed: Array = []

	func on_hovered(index: int) -> void:
		hovered.append(index)

	func on_pressed(index: int) -> void:
		pressed.append(index)


func _view() -> PauseMenuView:
	var view := PauseMenuView.new()
	tree.root.add_child(view)
	return view


func test_view_has_the_dim_the_title_and_the_keys(test) -> void:
	var view := _view()
	var dims := view.get_children().filter(func(child: Node) -> bool: return child is ColorRect)
	var panels := view.get_children().filter(func(child: Node) -> bool: return child is PanelContainer)
	test.check(dims.size() == 1 and is_equal_approx((dims[0] as ColorRect).color.a, PauseMenuView.DIM_ALPHA), "het spel gedimd erachter")
	test.check(panels.size() == 1, "één paneel")
	var style := (panels[0] as PanelContainer).get_theme_stylebox("panel")
	test.check(style.content_margin_left == PauseMenuLayout.PANEL_MARGIN_SIDE and style.content_margin_top == PauseMenuLayout.PANEL_MARGIN_TOP, "met de marges van de layout")
	test.check(view.title_text().contains("PAUZE"), "de titel (%s)" % view.title_text())
	test.check(view.keys_text().contains("ENTER") and view.keys_text().contains("ESC"), "de regel met de toetsen (%s)" % view.keys_text())
	test.check(view.buttons().is_empty(), "nog geen knoppen")
	view.free()


func test_show_entries_builds_a_button_per_label(test) -> void:
	var view := _view()
	view.show_entries(["EEN", "TWEE", "DRIE"], 320.0)
	var buttons := view.buttons()
	test.check(buttons.size() == 3, "drie knoppen")
	test.check(buttons[1].text.strip_edges() == "TWEE" and not buttons[1].text.contains("→"), "met hun tekst, nog zonder pijl (%s)" % buttons[1].text)
	test.check(buttons[0].custom_minimum_size == PauseMenuLayout.button_size(320.0), "zo breed als gevraagd, zo hoog als de layout zegt")
	test.check(buttons[0].focus_mode == Control.FOCUS_NONE, "zonder eigen focus (het gedrag houdt bij wat gekozen is)")
	var first := buttons[0]
	view.show_entries(["ANDERS"], 400.0)
	test.check(view.buttons().size() == 1 and view.buttons()[0] != first and first.is_queued_for_deletion(), "nieuwe regels vervangen de oude knoppen")
	test.check(view.buttons()[0].custom_minimum_size.x == 400.0, "in de nieuwe breedte")
	view.free()


func test_show_selected_moves_the_arrow_and_writes_the_labels(test) -> void:
	var view := _view()
	view.show_entries(["EEN", "TWEE"], 300.0)
	view.show_selected(1, ["EEN", "TWEE"])
	var buttons := view.buttons()
	test.check(buttons[1].text == PauseMenuView.ARROW + "TWEE" and buttons[0].text == PauseMenuView.NO_ARROW + "EEN", "de pijl bij de tweede")
	test.check(buttons[1].get_theme_color("font_color") == UiStyle.INK and buttons[0].get_theme_color("font_color") == UiStyle.TEXT, "de gekozen knop in de donkere letter")
	view.show_selected(0, ["EEN", "TWEE: AAN"])
	test.check(buttons[0].text.begins_with("→") and not buttons[1].text.begins_with("→"), "de pijl verplaatst")
	test.check(buttons[1].text.strip_edges() == "TWEE: AAN", "en een veranderde tekst staat er meteen")
	view.show_selected(-1, ["EEN", "TWEE"])
	test.check(not buttons[0].text.contains("→") and not buttons[1].text.contains("→"), "-1: geen pijl")
	view.free()


func test_mouse_is_passed_on(test) -> void:
	var view := _view()
	var listener := Listener.new()
	view.entry_hovered.connect(listener.on_hovered)
	view.entry_pressed.connect(listener.on_pressed)
	view.show_entries(["EEN", "TWEE"], 300.0)
	view.buttons()[1].mouse_entered.emit()
	view.buttons()[0].pressed.emit()
	test.check(listener.hovered == [1], "de muis boven een knop: doorgegeven met zijn nummer (%s)" % [listener.hovered])
	test.check(listener.pressed == [0], "een klik: ook (%s)" % [listener.pressed])
	test.check(not view.buttons()[1].text.contains("→"), "de view kiest zelf niets")
	view.free()
