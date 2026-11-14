extends RefCounted
## Unit tests of the level-up screen (scripts/ui/level_up_screen.gd): the maximum now -> after per
## stat, choosing with the keys, no key before KEYS_AFTER, a number picks and takes at once,
## the choice to the player, the pause back as it was.

const LevelUpScreen = preload("res://scripts/ui/level_up_screen.gd")

const RAISE := {"gezondheid": 10.0, "uithoudingsvermogen": 10.0, "honger": 20.0, "overprikkeldheid": 15.0}
const MAXIMA := {"gezondheid": Vector2(50, 70), "uithoudingsvermogen": Vector2(60, 60),
		"honger": Vector2(80, 140), "overprikkeldheid": Vector2(10, 100)}


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_choosing_a_stat(test) -> void:
	var screen := LevelUpScreen.new()
	test.tree.root.add_child(screen)
	var chosen: Array[String] = []
	var was_paused: bool = test.tree.paused
	screen.open(3, func(stat_name: String) -> void: chosen.append(stat_name),
			func(stat_name: String) -> Vector2: return MAXIMA[stat_name], RAISE)
	test.check(screen.is_showing() and test.tree.paused, "open, het spel gepauzeerd")
	test.check(screen._level_label.text == "LEVEL 3", "het nieuwe level: " + screen._level_label.text)
	test.check(screen._row_values[0].text == "70 → 80" and screen._row_values[2].text == "140 → 160",
			"maximum nu → straks (%s, %s)" % [screen._row_values[0].text, screen._row_values[2].text])
	screen.handle_input(_key(KEY_S))
	screen.handle_input(_key(KEY_S))
	test.check(screen.selected_stat() == "honger", "twee keer S: honger (%s)" % screen.selected_stat())
	screen.handle_input(_key(KEY_W))
	test.check(screen.selected_stat() == "uithoudingsvermogen", "W terug (%s)" % screen.selected_stat())
	screen.handle_input(_key(KEY_UP))
	screen.handle_input(_key(KEY_UP))
	test.check(screen.selected_stat() == "overprikkeldheid", "omhoog vanaf de eerste: de laatste (%s)" % screen.selected_stat())
	screen.handle_input(_key(KEY_ENTER))
	test.check(screen.is_showing() and chosen.is_empty(), "Enter te vroeg (een toets nog van het spel) doet niets")
	screen.handle_input(_key(KEY_ESCAPE))
	test.check(screen.is_showing(), "Escape sluit niet: een level kies je altijd")
	screen._since = LevelUpScreen.KEYS_AFTER
	screen.handle_input(_key(KEY_1))
	test.check(chosen.size() == 1 and chosen[0] == "gezondheid", "1 kiest en neemt gezondheid (%s)" % [chosen])
	test.check(not screen.is_showing() and test.tree.paused == was_paused, "dicht, de pauze terug zoals hij was")
	screen.free()


## A screen in the tree, opened for level 2 with the maxima of MAXIMA; `chosen` gets the stats taken.
static func _opened(test, chosen: Array[String], xp_gained := 0) -> LevelUpScreen:
	var screen := LevelUpScreen.new()
	test.tree.root.add_child(screen)
	screen.open(2, func(stat_name: String) -> void: chosen.append(stat_name),
			func(stat_name: String) -> Vector2: return MAXIMA[stat_name], RAISE, xp_gained)
	return screen


func test_value_text(test) -> void:
	test.check(LevelUpScreen.value_text(70.0, 10.0) == "70 → 80", "nu → straks")
	test.check(LevelUpScreen.value_text(99.6, 0.0) == "100 → 100", "afgerond op hele punten, niets erbij")
	test.check(LevelUpScreen.value_text(0.0, 15.0) == "0 → 15", "vanaf nul")


func test_the_options_are_the_four_stats(test) -> void:
	var stats := LevelUpScreen.OPTIONS.map(func(option: Dictionary) -> String: return String(option.stat))
	test.check(stats == ["gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"], "de vier stats, in deze volgorde (%s)" % [stats])
	for option: Dictionary in LevelUpScreen.OPTIONS:
		test.check(String(option.name) != "" and String(option.text) != "" and RAISE.has(option.stat), "%s: een naam, een uitleg en een verhoging" % option.stat)


func test_take_gives_the_selected_stat_and_closes_once(test) -> void:
	var chosen: Array[String] = []
	var was_paused: bool = test.tree.paused
	var screen := _opened(test, chosen)
	var finished := [0]
	screen.finished.connect(func() -> void: finished[0] += 1)
	test.check(screen.selected_stat() == "gezondheid" and screen._rows.size() == LevelUpScreen.OPTIONS.size(), "de eerste gekozen, een rij per stat")
	test.check(not screen._xp_label.visible, "zonder XP erbij: geen XP-regel")
	screen.handle_input(_key(KEY_DOWN))
	screen.take()
	test.check(chosen == ["uithoudingsvermogen"] and not screen.is_showing() and finished[0] == 1, "take: de gekozen stat, dicht, finished")
	screen.take()
	test.check(chosen.size() == 1 and finished[0] == 1, "nog een keer op een dicht scherm: niets")
	test.check(not screen.handle_input(_key(KEY_S)) and screen.selected_stat() == "uithoudingsvermogen", "dicht: toetsen zijn niet voor het scherm")
	test.tree.paused = was_paused
	screen.free()


func test_the_xp_that_did_it_and_reopening(test) -> void:
	var chosen: Array[String] = []
	var was_paused: bool = test.tree.paused
	var screen := _opened(test, chosen, 150)
	test.check(screen._xp_label.visible and screen._xp_label.text == "+150 XP", "de XP waarmee het kwam")
	screen.handle_input(_key(KEY_S))
	screen._process(LevelUpScreen.KEYS_AFTER)
	screen.open(5, Callable(), Callable(), {})
	test.check(screen._level_label.text == "LEVEL 5" and screen.selected_stat() == "gezondheid" and screen._since == 0.0 and not screen._xp_label.visible,
		"opnieuw geopend: het nieuwe level, weer de eerste, de wachttijd opnieuw, geen XP")
	test.check(screen._row_values[0].text == "0 → 0", "zonder gegevens: nul")
	screen.take()
	test.check(chosen.is_empty() and not screen.is_showing() and test.tree.paused == was_paused, "zonder keuzefunctie sluit hij gewoon, de pauze van voor de eerste keer terug")
	test.tree.paused = was_paused
	screen.free()


func test_keys_that_take_wait_for_keys_after(test) -> void:
	var was_paused: bool = test.tree.paused
	for keycode: Key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E, KEY_3]:
		var chosen: Array[String] = []
		var screen := _opened(test, chosen)
		screen._process(LevelUpScreen.KEYS_AFTER * 0.5)
		test.check(screen.handle_input(_key(keycode)) and screen.is_showing() and chosen.is_empty() and screen.selected_stat() == "gezondheid",
			"%s te vroeg: niets" % OS.get_keycode_string(keycode))
		screen._process(LevelUpScreen.KEYS_AFTER * 0.6)
		screen.handle_input(_key(keycode))
		test.check(not screen.is_showing() and chosen == (["honger"] if keycode == KEY_3 else ["gezondheid"]), "%s na de wachttijd neemt (%s)" % [OS.get_keycode_string(keycode), chosen])
		screen.free()
	test.tree.paused = was_paused


func test_other_events(test) -> void:
	var chosen: Array[String] = []
	var was_paused: bool = test.tree.paused
	var screen := _opened(test, chosen)
	screen._since = LevelUpScreen.KEYS_AFTER
	var released := _key(KEY_ENTER)
	released.pressed = false
	test.check(screen.handle_input(released) and screen.is_showing(), "een losgelaten toets is van het scherm maar doet niets")
	var echo := _key(KEY_S)
	echo.echo = true
	screen.handle_input(echo)
	test.check(screen.selected_stat() == "gezondheid", "een ingehouden toets kiest niet door")
	test.check(screen.handle_input(_key(KEY_Q)) and screen.is_showing(), "een andere toets: van het scherm, doet niets")
	test.check(not screen.handle_input(InputEventJoypadButton.new()), "een controllerknop is niet voor handle_input")
	var far_away := InputEventMouseButton.new()
	far_away.button_index = MOUSE_BUTTON_LEFT
	far_away.pressed = true
	far_away.position = Vector2(-500, -500)
	test.check(screen.handle_input(far_away) and screen.is_showing() and chosen.is_empty(), "een klik naast de rijen neemt niets")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(-500, -500)
	test.check(screen.handle_input(motion) and screen.selected_stat() == "gezondheid", "de muis naast de rijen kiest niets")
	test.check(screen._row_at(Vector2(-500, -500)) == -1, "geen rij onder dat punt")
	screen.take()
	test.tree.paused = was_paused
	screen.free()


func test_the_chosen_row_has_the_colour_of_its_stat(test) -> void:
	var chosen: Array[String] = []
	var was_paused: bool = test.tree.paused
	var screen := LevelUpScreen.new()
	screen.stat_looks = {"gezondheid": {"colour": Color("#FF5D73")}}
	test.tree.root.add_child(screen)
	screen.open(2, Callable(), func(stat_name: String) -> Vector2: return MAXIMA[stat_name], RAISE)
	test.check(screen._row_values[0].get_theme_color("font_color") == Color("#FF5D73"), "de gekozen rij: zijn waarde in de kleur van de stat")
	test.check(screen._row_values[1].get_theme_color("font_color") == LevelUpScreen.UiStyle.MUTED, "de andere gedimd")
	screen.handle_input(_key(KEY_S))
	test.check(screen._row_values[0].get_theme_color("font_color") == LevelUpScreen.UiStyle.MUTED
		and screen._row_values[1].get_theme_color("font_color") == LevelUpScreen.UiStyle.ACCENT, "een stat zonder eigen kleur: de accentkleur")
	screen.take()
	test.check(chosen.is_empty(), "zonder keuzefunctie krijgt niemand iets")
	test.tree.paused = was_paused
	screen.free()


func test_keep_paused_decides_the_pause_after_closing(test) -> void:
	var chosen: Array[String] = []
	var was_paused: bool = test.tree.paused
	var screen := _opened(test, chosen)
	screen.keep_paused = func() -> bool: return true
	screen.take()
	test.check(test.tree.paused, "een ander scherm staat nog open: het spel blijft stil")
	test.tree.paused = false
	screen.keep_paused = func() -> bool: return false
	screen.open(3, Callable(), Callable(), {})
	screen.take()
	test.check(not test.tree.paused, "niets meer open: het spel gaat door")
	test.tree.paused = was_paused
	screen.free()
