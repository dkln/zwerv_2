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
