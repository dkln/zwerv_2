extends RefCounted
## Unit tests of the pause menu (scripts/ui/screens/pause_menu.gd) and the death screen
## (scripts/ui/screens/death_screen.gd) on their own, without the HUD or the town.
##   tests/run_unit_tests.sh pause_and_death

const PauseMenu = preload("res://scripts/ui/screens/pause_menu.gd")
const DeathScreen = preload("res://scripts/ui/screens/death_screen.gd")
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


func test_item_index_and_next_index(test) -> void:
	test.check(PauseMenu.item_index("resume") == 0, "verder spelen staat bovenaan")
	test.check(PauseMenu.item_index("quit") == PauseMenu.ITEMS.size() - 1, "afsluiten onderaan")
	test.check(PauseMenu.item_index("bestaat_niet") == -1, "onbekend: -1")
	test.check(PauseMenu.next_index(0, 1, 4) == 1 and PauseMenu.next_index(3, 1, 4) == 0, "omlaag, onderaan weer naar boven")
	test.check(PauseMenu.next_index(0, -1, 4) == 3 and PauseMenu.next_index(2, -1, 4) == 1, "omhoog, bovenaan naar onderen")
	test.check(PauseMenu.next_index(-1, 1, 4) == 0, "nog niets gekozen: het eerste")
	test.check(PauseMenu.next_index(2, 1, 0) == 0, "geen items: 0")


func test_the_menu_opens_on_its_first_page(test) -> void:
	var listener := Listener.new()
	var menu := _menu(listener)
	test.check(not menu.is_open(), "eerst dicht")
	test.check(not menu.handle_input(_key("ui_down")), "dicht: toetsen zijn niet voor het menu")
	menu.set_open(true)
	test.check(menu.is_open() and not menu.in_settings(), "open op het menu zelf")
	test.check(_texts(menu) == PauseMenu.ITEMS.map(func(item: Array) -> String: return item[0]), "de items van het menu (%s)" % [_texts(menu)])
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
	test.check(menu.buttons()[PauseMenu.ITEMS.size() - 1].text.begins_with("→"), "bovenaan omhoog: het onderste")
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
	test.check(menu.buttons()[0].custom_minimum_size.x > PauseMenu.WIDTH, "de knoppen van de instellingen zijn breder")
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


func test_death_reason_names_who_and_how(test) -> void:
	test.check(DeathScreen.reason("honger", "Sjaan") == "Sjaan is van de honger omgekomen.", "van de honger")
	test.check(DeathScreen.reason("verdronken", "Kees").begins_with("Kees is in het water gevallen"), "verdronken")
	test.check(DeathScreen.reason("", "Kees") == "Kees heeft het niet gered.", "geen oorzaak: een algemene regel")
	test.check(DeathScreen.reason("onbekend", "Kees") == "Kees heeft het niet gered.", "een onbekende oorzaak: ook")
	for cause: String in DeathScreen.CAUSES:
		test.check(String(DeathScreen.CAUSES[cause]).count("%s") == 1, "%s: één plek voor de naam" % cause)


func test_death_screen_opens_once_and_keys_wait(test) -> void:
	var screen := DeathScreen.new()
	tree.root.add_child(screen)
	test.check(not screen.is_open() and not screen.keys_ready(), "eerst niet te zien")
	test.check(screen.open("aangereden", "Sjaan"), "het scherm gaat open")
	test.check(screen.is_open() and screen._reason.text == "Sjaan is aangereden en niet meer opgestaan.", "met hoe het gebeurde")
	test.check(screen.modulate.a == 0.0, "het komt op vanuit niets")
	test.check(not screen.open("honger", "Sjaan") and screen._reason.text.contains("aangereden"), "een tweede keer: het blijft zoals het is")
	test.check(not screen.keys_ready(), "de toetsen werken nog niet meteen")
	screen._since -= DeathScreen.KEYS_AFTER
	test.check(screen.keys_ready(), "na de wachttijd wel")
	screen.free()
