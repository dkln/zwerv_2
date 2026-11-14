extends RefCounted
## Unit tests of the main menu (scripts/ui/main_menu.gd) without opening it (opened it loads
## the 3D map and plays its music): which item the arrows go to (the greyed-out ones
## skipped), the caret, the look of an item, the lines of the credits, and the settings it
## shares with the HUD (user://instellingen.cfg, put back as it was).
##   tests/run_unit_tests.sh main_menu

const MainMenuScript = preload("res://scripts/ui/main_menu.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")


func test_next_choosable_skips_what_cannot_be_chosen(test) -> void:
	var items: Array = MainMenuScript.ITEMS
	test.check(MainMenuScript.next_choosable(1, 1, items) == 3, "omlaag vanaf NIEUW SPEL: LADEN overgeslagen, INSTELLINGEN")
	test.check(MainMenuScript.next_choosable(3, -1, items) == 1, "en weer terug omhoog")
	test.check(MainMenuScript.next_choosable(1, -1, items) == 5, "omhoog vanaf NIEUW SPEL: VERDERGAAN overgeslagen, onderaan AFSLUITEN")
	test.check(MainMenuScript.next_choosable(5, 1, items) == 1, "onderaan omlaag: weer NIEUW SPEL")
	test.check(MainMenuScript.next_choosable(0, 1, items) == 1, "vanaf een grijs item: het eerste dat kan")
	var none := [["A", false, "a"], ["B", false, "b"]]
	test.check(MainMenuScript.next_choosable(1, 1, none) == 1 and MainMenuScript.next_choosable(0, -1, none) == 0, "niets te kiezen: blijft staan")
	var only := [["A", false, "a"], ["B", true, "b"], ["C", false, "c"]]
	test.check(MainMenuScript.next_choosable(1, 1, only) == 1 and MainMenuScript.next_choosable(1, -1, only) == 1, "één te kiezen: het rondje komt weer daar uit")
	test.check(MainMenuScript.next_choosable(0, 1, []) == 0, "een leeg menu: blijft staan")


func test_the_items_of_the_menu(test) -> void:
	var actions: Array = MainMenuScript.ITEMS.map(func(item: Array) -> String: return String(item[2]))
	test.check(actions == ["continue", "new_game", "load", "settings", "credits", "quit"], "de items in hun volgorde (%s)" % [actions])
	for item: Array in MainMenuScript.ITEMS:
		test.check(item.size() == 3 and String(item[0]) == String(item[0]).to_upper() and item[1] is bool, "%s: een naam in hoofdletters, te kiezen of niet, een actie" % item[0])
	var menu := MainMenuScript.new()
	test.check(MainMenuScript.ITEMS[menu._selected][1] and MainMenuScript.ITEMS[menu._selected][2] == "new_game", "het menu opent op NIEUW SPEL")
	test.check(menu._next_choosable(1, 1) == 3 and menu._next_choosable(1, -1) == 5, "de pijlen van het menu zelf slaan de grijze over")
	menu.free()


func test_caret_and_the_look_of_an_item(test) -> void:
	test.check(MainMenuScript._caret(true) == "→  " and MainMenuScript._caret(false).strip_edges() == "", "de pijl voor het gekozen item, anders ruimte")
	test.check(MainMenuScript._caret(false).length() > 0, "even breed inspringen zonder pijl")
	var menu := MainMenuScript.new()
	var button := Button.new()
	menu._style_menu_button(button, true, true, "NIEUW SPEL")
	test.check(button.text == "→  NIEUW SPEL" and button.get_theme_color("font_color") == UiStyle.INK, "gekozen: de pijl ervoor, donkere tekst op amber")
	menu._style_menu_button(button, false, true, "CREDITS")
	test.check(button.text == "    CREDITS" and button.get_theme_color("font_color") == UiStyle.TEXT, "niet gekozen: gewone tekst")
	menu._style_menu_button(button, false, false, "LADEN")
	test.check(button.get_theme_color("font_color") == UiStyle.BORDER.lightened(0.15) and button.get_theme_color("font_disabled_color") == UiStyle.BORDER.lightened(0.15),
		"niet te kiezen: gedimd")
	menu._loading = true
	menu._style_menu_button(button, true, true, "NIEUW SPEL")
	test.check(button.text == "    LADEN", "tijdens het laden blijft de tekst van het gekozen item staan")
	menu._style_menu_button(button, false, true, "CREDITS")
	test.check(button.text == "    CREDITS", "de andere items worden nog wel bijgewerkt")
	button.free()
	menu.free()


func test_the_credits(test) -> void:
	test.check(MainMenuScript.CREDITS_ROLES.size() > 10 and MainMenuScript.CREDITS_NAME != "", "veel rollen, één naam")
	var seen := {}
	for role: String in MainMenuScript.CREDITS_ROLES:
		test.check(role.strip_edges() == role and role != "" and not seen.has(role), "%s: een rol, één keer" % role)
		seen[role] = true
	test.check(MainMenuScript.CREDITS_SPEED > 0.0 and MainMenuScript.CREDITS_HEIGHT > 0.0, "de rol loopt, door een venster met hoogte")
	var menu := MainMenuScript.new()
	var line: Label = menu._credits_line("REGIE", UiStyle.font(UiStyle.FONT_PIXEL), 11, UiStyle.MUTED)
	test.check(line.text == "REGIE" and line.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and line.get_theme_font_size("font_size") == 11
		and line.get_theme_color("font_color") == UiStyle.MUTED, "een regel van de rol: gecentreerd, in zijn grootte en kleur")
	var gap: Control = menu._credits_gap(14.0)
	test.check(gap.custom_minimum_size == Vector2(0, 14), "een tussenruimte van die hoogte")
	line.free()
	gap.free()
	menu.free()


## The settings are read with CRT on when nothing is stored, and what is written is read
## back; other values in the file stay. The player's own file is put back afterwards.
func test_settings_are_written_and_read_back(test) -> void:
	var path: String = MainMenuScript.SETTINGS_PATH
	var existed := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	test.check(MainMenuScript._read_settings() == {"crt": true}, "niets opgeslagen: het CRT-beeld aan")
	MainMenuScript._write_settings({"crt": false})
	test.check(MainMenuScript._read_settings() == {"crt": false}, "uitgezet en teruggelezen")
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("camera", "handmatig", true)
	config.save(path)
	MainMenuScript._write_settings({"crt": true})
	config = ConfigFile.new()
	config.load(path)
	test.check(MainMenuScript._read_settings() == {"crt": true} and config.get_value("camera", "handmatig", false) == true, "weer aan; wat er verder in staat blijft")
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(before)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	test.check(FileAccess.file_exists(path) == existed and (not existed or FileAccess.get_file_as_bytes(path) == before), "het bestand van de speler staat er weer zoals het was")
