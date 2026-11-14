extends RefCounted
## Unit tests of the player frame of the HUD (scripts/ui/hud/player_frame.gd): stats,
## experience, name and level.
##   tests/run_unit_tests.sh player_frame

const PlayerFrame = preload("res://scripts/ui/hud/player_frame.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _frame() -> PlayerFrame:
	var frame := PlayerFrame.new()
	tree.root.add_child(frame)
	return frame


func test_xp_text_groups_thousands(test) -> void:
	test.check(PlayerFrame.xp_text(Vector2(6420.0, 10000.0)) == "6.420 / 10.000", "met punten voor de duizendtallen (%s)" % PlayerFrame.xp_text(Vector2(6420.0, 10000.0)))
	test.check(PlayerFrame.xp_text(Vector2(0.0, 300.0)) == "0 / 300", "aan het begin van een level")


func test_frame_has_a_bar_per_stat(test) -> void:
	var frame := _frame()
	for stat_name: String in StatLook.STATS:
		var bar := frame.stat_bar(stat_name)
		test.check(bar != null and bar.segments == int(StatLook.STATS[stat_name].segments) and bar.full_colour == StatLook.STATS[stat_name].colour, "%s: zijn balk in zijn kleur" % stat_name)
		test.check(frame.get_stat(stat_name) == Vector2.ZERO, "%s: nog niet gezet" % stat_name)
	test.check(frame.stat_bar("bestaat_niet") == null and frame.stat_text("bestaat_niet") == "", "een stat die er niet is: geen balk")
	test.check(frame.xp_bar() != null and frame.xp_bar().fill == 0.0 and frame.xp_label().text == "0 / 0", "de XP-balk begint leeg")
	test.check(frame.portrait != null, "met het portret van de speler")
	frame.free()


func test_set_stat_fills_the_bar_and_writes_the_value(test) -> void:
	var frame := _frame()
	frame.set_stat("honger", 35.0, 80.0)
	test.check(frame.get_stat("honger") == Vector2(35.0, 80.0), "waarde en maximum onthouden")
	test.check(is_equal_approx(frame.stat_bar("honger").fill, 35.0 / 80.0) and frame.stat_text("honger") == "35/80", "de balk en het getal (%s)" % frame.stat_text("honger"))
	frame.set_stat("honger", 60.0)
	test.check(frame.get_stat("honger") == Vector2(60.0, 80.0), "zonder maximum: het vorige blijft")
	frame.set_stat("honger", 500.0)
	test.check(frame.get_stat("honger") == Vector2(80.0, 80.0) and is_equal_approx(frame.stat_bar("honger").fill, 1.0), "niet boven het maximum")
	frame.set_stat("gezondheid", 40.0)
	test.check(frame.get_stat("gezondheid") == Vector2(40.0, 100.0), "nooit een maximum gekregen: 100")
	frame.set_stat("bestaat_niet", 5.0)
	test.check(frame.get_stat("bestaat_niet") == Vector2.ZERO, "een stat die er niet is: niets")
	frame.free()


func test_a_jump_lights_the_value_up(test) -> void:
	test.check(PlayerFrame.is_jump(50.0, 40.0) and PlayerFrame.is_jump(40.0, 50.0), "tien punten erbij of eraf: een sprong")
	test.check(not PlayerFrame.is_jump(50.0, 49.5) and PlayerFrame.is_jump(50.0, 50.0 - PlayerFrame.STAT_SHAKE_FROM), "langzaam leeglopen niet, vanaf de drempel wel")
	var frame := _frame()
	var text: Label = frame._stat_texts["gezondheid"]
	frame.set_stat("gezondheid", 100.0, 100.0)
	test.check(text.modulate == Color.WHITE, "de eerste keer zetten is geen verandering")
	frame.set_stat("gezondheid", 99.5)
	test.check(text.modulate == Color.WHITE, "een half punt eraf: geen flits")
	frame.set_stat("gezondheid", 70.0)
	test.check(text.modulate == PlayerFrame.LOST_FLASH, "een klap: het getal roodachtig")
	frame.set_stat("gezondheid", 90.0)
	test.check(text.modulate == PlayerFrame.GAINED_FLASH, "eten: het getal licht op")
	frame.free()


func test_experience_and_player(test) -> void:
	var frame := _frame()
	frame.set_xp(150.0, 300.0)
	test.check(is_equal_approx(frame.xp_bar().fill, 0.5) and frame.xp_label().text == "150 / 300", "half vol (%s)" % frame.xp_label().text)
	frame.set_xp(6420.0, 10000.0)
	test.check(frame.xp_label().text == "6.420 / 10.000", "duizendtallen met een punt")
	frame.set_xp(999.0, 300.0)
	test.check(is_equal_approx(frame.xp_bar().fill, 1.0) and frame.xp_label().text == "300 / 300", "niet voller dan vol")
	frame.set_player("Sjaan", 4)
	test.check(frame.shown_name() == "Sjaan" and frame.shown_level() == "LEVEL 4", "naam en level (%s, %s)" % [frame.shown_name(), frame.shown_level()])
	frame.free()
