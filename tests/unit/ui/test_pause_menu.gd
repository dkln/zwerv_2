extends RefCounted
## Unit tests of the pause menu (scripts/ui/screens/pause_menu.gd, the behaviour) on its own,
## without the HUD or the town: open and closed, the keys, the pages, the settings. Its
## logic, sizes and look: test_pause_menu_rules.gd, test_pause_menu_layout.gd,
## test_pause_menu_view.gd.
##   tests/run_unit_tests.sh pause_menu

const PauseMenu = preload("res://scripts/ui/screens/pause_menu.gd")
const PauseMenuRules = preload("res://scripts/ui/screens/pause_menu_rules.gd")
const PauseMenuLayout = preload("res://scripts/ui/screens/pause_menu_layout.gd")
const CameraTurning = preload("res://scripts/camera/camera_turning.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Counts what the pause menu asks of the HUD.
class Listener:
	var resumes := 0
	var crt_changes: Array = []

	func on_resume() -> void:
		resumes += 1

	func on_crt(on: bool) -> void:
		crt_changes.append(on)


func _menu(listener: Listener) -> PauseMenu:
	var menu := PauseMenu.new()
	menu.resume_wanted.connect(listener.on_resume)
	menu.crt_changed.connect(listener.on_crt)
	tree.root.add_child(menu)
	return menu


static func _key(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


static func _texts(menu: PauseMenu) -> Array:
	return menu.buttons().map(func(button: Button) -> String: return button.text.strip_edges().trim_prefix("→").strip_edges())


func test_item_index_is_the_rules(test) -> void:
	for action: String in ["resume", "settings", "menu", "quit", "bestaat_niet"]:
		test.check(PauseMenu.item_index(action) == PauseMenuRules.item_index(action), "%s: hetzelfde als de logica" % action)


func test_the_menu_opens_on_its_first_page(test) -> void:
	var listener := Listener.new()
	var menu := _menu(listener)
	test.check(menu.name == "Pauze" and not menu.is_open(), "eerst dicht")
	test.check(not menu.handle_input(_key("ui_down")), "dicht: toetsen zijn niet voor het menu")
	menu.set_open(true)
	test.check(menu.is_open() and not menu.in_settings(), "open op het menu zelf")
	test.check(_texts(menu) == Array(PauseMenuRules.item_labels()), "de items van het menu (%s)" % [_texts(menu)])
	test.check(menu.buttons()[0].text.begins_with("→"), "de pijl bij het eerste")
	menu.set_open(false)
	test.check(not menu.is_open(), "weer dicht")
	menu.free()


func test_keys_move_the_arrow_and_escape_resumes(test) -> void:
	var listener := Listener.new()
	var menu := _menu(listener)
	menu.set_open(true)
	test.check(menu.handle_input(_key("ui_down")), "omlaag is voor het menu")
	test.check(menu.buttons()[1].text.begins_with("→") and not menu.buttons()[0].text.begins_with("→"), "de pijl een omlaag")
	menu.handle_input(_key("ui_up"))
	menu.handle_input(_key("ui_up"))
	test.check(menu.buttons()[PauseMenuRules.ITEMS.size() - 1].text.begins_with("→"), "bovenaan omhoog: het onderste")
	test.check(not menu.handle_input(_key("ui_left")), "een andere toets: niet voor het menu")
	test.check(menu.handle_input(_key("ui_cancel")) and listener.resumes == 1, "Escape op het menu: verder spelen")
	menu.select(PauseMenu.item_index("resume"))
	menu.handle_input(_key("ui_accept"))
	test.check(listener.resumes == 2, "Enter op VERDER SPELEN: ook")
	menu.free()


func test_settings_page_and_back(test) -> void:
	var listener := Listener.new()
	var menu := _menu(listener)
	menu.set_open(true)
	menu.choose(PauseMenu.item_index("settings"))
	var texts := _texts(menu)
	test.check(menu.in_settings(), "INSTELLINGEN: de instellingen in het paneel")
	for wanted: String in ["ANTI-ALIASING", "RENDERSCHAAL", "CRT-BEELD", "CAMERA", "TERUG"]:
		test.check(texts.any(func(text: String) -> bool: return text.begins_with(wanted)), "een regel %s (%s)" % [wanted, texts])
	test.check(menu.buttons()[0].custom_minimum_size.x == PauseMenuLayout.button_width(true) and PauseMenuLayout.button_width(true) > PauseMenuLayout.WIDTH, "de knoppen van de instellingen zijn breder")
	test.check(menu.handle_input(_key("ui_cancel")) and not menu.in_settings() and listener.resumes == 0, "Escape: terug naar het menu, niet verder spelen")
	menu.choose(PauseMenu.item_index("settings"))
	menu.choose(texts.find("TERUG"))
	test.check(not menu.in_settings(), "TERUG: ook")
	menu.set_open(false)
	menu.choose(PauseMenu.item_index("settings"))
	menu.set_open(true)
	test.check(not menu.in_settings(), "opnieuw geopend: weer het menu zelf")
	menu.free()


func test_camera_setting_changes_at_once(test) -> void:
	var listener := Listener.new()
	var menu := _menu(listener)
	var was_manual: bool = CameraTurning.is_manual()
	menu.set_open(true)
	menu.choose(PauseMenu.item_index("settings"))
	var camera_index: int = _texts(menu).map(func(text: String) -> bool: return text.begins_with("CAMERA")).find(true)
	menu.choose(camera_index)
	test.check(CameraTurning.is_manual() != was_manual, "de camera omgezet")
	test.check(menu.buttons()[camera_index].text.contains(CameraTurning.label()), "het knopje zegt het meteen")
	menu.choose(camera_index)
	test.check(CameraTurning.is_manual() == was_manual, "en weer terug")
	menu.choose(99)
	menu.choose(-1)
	test.check(menu.in_settings(), "een item dat er niet is: er gebeurt niets")
	menu.free()


func test_crt_setting_tells_the_hud(test) -> void:
	var listener := Listener.new()
	var menu := _menu(listener)
	var was_on := PauseMenu.crt_on()
	menu.set_open(true)
	menu.choose(PauseMenu.item_index("settings"))
	var crt_index: int = _texts(menu).map(func(text: String) -> bool: return text.begins_with("CRT")).find(true)
	menu.choose(crt_index)
	test.check(PauseMenu.crt_on() != was_on and listener.crt_changes == [not was_on], "CRT omgezet en doorgegeven (%s)" % [listener.crt_changes])
	test.check(menu.buttons()[crt_index].text.ends_with("UIT" if was_on else "AAN"), "het knopje zegt het meteen (%s)" % menu.buttons()[crt_index].text)
	menu.choose(crt_index)
	test.check(PauseMenu.crt_on() == was_on and listener.crt_changes == [not was_on, was_on], "en weer terug")
	menu.free()


func test_show_page_and_select(test) -> void:
	var listener := Listener.new()
	var menu := _menu(listener)
	menu.set_open(true)
	menu.show_page(true)
	test.check(menu.in_settings() and menu.buttons()[0].text.begins_with("→"), "de instellingen, de pijl bovenaan")
	menu.select(2)
	test.check(menu.buttons()[2].text.begins_with("→") and not menu.buttons()[0].text.begins_with("→"), "select zet de pijl")
	menu.show_page(false)
	test.check(not menu.in_settings() and menu.buttons().size() == PauseMenuRules.ITEMS.size() and menu.buttons()[0].text.begins_with("→"), "terug op het menu, de pijl weer bovenaan")
	test.check(menu.buttons()[0].custom_minimum_size.x == PauseMenuLayout.WIDTH, "in de gewone breedte")
	menu.free()


func test_the_mouse_selects_and_chooses(test) -> void:
	var listener := Listener.new()
	var menu := _menu(listener)
	menu.set_open(true)
	menu.buttons()[2].mouse_entered.emit()
	test.check(menu.buttons()[2].text.begins_with("→"), "de muis boven een knop: de pijl erbij")
	menu.buttons()[PauseMenu.item_index("resume")].pressed.emit()
	test.check(listener.resumes == 1, "een klik op VERDER SPELEN: verder spelen")
	menu.buttons()[PauseMenu.item_index("settings")].pressed.emit()
	test.check(menu.in_settings(), "een klik op INSTELLINGEN: de instellingen")
	menu.free()
