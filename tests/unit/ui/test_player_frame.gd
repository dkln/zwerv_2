extends RefCounted
## Unit tests of the player frame of the HUD (scripts/ui/hud/player_frame.gd): what the game
## tells it reaches its picture, and a jump of a stat lights its value up.
##   tests/run_unit_tests.sh test_player_frame.gd

const PlayerFrame = preload("res://scripts/ui/hud/player_frame.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _frame() -> PlayerFrame:
	var frame := PlayerFrame.new()
	tree.root.add_child(frame)
	return frame


func test_starts_empty(test) -> void:
	var frame := _frame()
	test.check(frame.name == "Speler" and frame.view != null and frame.view.get_parent() == frame, "het kader met zijn beeld")
	for stat_name: String in StatLook.STATS:
		test.check(frame.get_stat(stat_name) == Vector2.ZERO, "%s: nog niet gezet" % stat_name)
	test.check(frame.view.xp_label().text == "0 / 0" and frame.view.shown_level() == "LEVEL 1" and frame.view.shown_name() == "", "nog geen XP, level 1, geen naam")
	frame.free()


func test_set_stat_fills_the_bar_and_writes_the_value(test) -> void:
	var frame := _frame()
	frame.set_stat("honger", 35.0, 80.0)
	test.check(frame.get_stat("honger") == Vector2(35.0, 80.0), "waarde en maximum onthouden")
	test.check(is_equal_approx(frame.view.stat_bar("honger").fill, 35.0 / 80.0) and frame.view.stat_label("honger").text == "35/80", "de balk en het getal")
	frame.set_stat("honger", 60.0)
	test.check(frame.get_stat("honger") == Vector2(60.0, 80.0), "zonder maximum: het vorige blijft")
	frame.set_stat("honger", 500.0)
	test.check(frame.get_stat("honger") == Vector2(80.0, 80.0) and is_equal_approx(frame.view.stat_bar("honger").fill, 1.0), "niet boven het maximum")
	frame.set_stat("gezondheid", 40.0)
	test.check(frame.get_stat("gezondheid") == Vector2(40.0, 100.0), "nooit een maximum gekregen: 100")
	frame.set_stat("bestaat_niet", 5.0)
	test.check(frame.get_stat("bestaat_niet") == Vector2.ZERO, "een stat die er niet is: niets")
	frame.free()


func test_a_jump_lights_the_value_up(test) -> void:
	var frame := _frame()
	var text := frame.view.stat_label("gezondheid")
	frame.set_stat("gezondheid", 100.0, 100.0)
	test.check(text.modulate == Color.WHITE, "de eerste keer zetten is geen verandering")
	frame.set_stat("gezondheid", 99.5)
	test.check(text.modulate == Color.WHITE, "een half punt eraf: geen flits")
	frame.set_stat("gezondheid", 70.0)
	test.check(text.modulate == StatLook.LOST_FLASH, "een klap: het getal roodachtig")
	frame.set_stat("gezondheid", 90.0)
	test.check(text.modulate == StatLook.GAINED_FLASH, "eten: het getal licht op")
	frame.free()


func test_experience_and_player(test) -> void:
	var frame := _frame()
	frame.set_xp(150.0, 300.0)
	test.check(is_equal_approx(frame.view.xp_bar().fill, 0.5) and frame.view.xp_label().text == "150 / 300", "half vol (%s)" % frame.view.xp_label().text)
	frame.set_xp(999.0, 300.0)
	test.check(is_equal_approx(frame.view.xp_bar().fill, 1.0) and frame.view.xp_label().text == "300 / 300", "niet voller dan vol")
	frame.set_player("Sjaan", 4)
	test.check(frame.view.shown_name() == "Sjaan" and frame.view.shown_level() == "LEVEL 4", "naam en level")
	frame.free()
