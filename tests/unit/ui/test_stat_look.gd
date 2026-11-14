extends RefCounted
## Unit tests of how the stats of the player look and count (scripts/ui/hud/stat_look.gd).
##   tests/run_unit_tests.sh stat_look

const StatLook = preload("res://scripts/ui/hud/stat_look.gd")


func test_every_stat_has_its_look(test) -> void:
	test.check(StatLook.STATS.keys() == ["gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"], "de vier stats in hun volgorde")
	for stat_name: String in StatLook.STATS:
		var stat: Dictionary = StatLook.STATS[stat_name]
		test.check(StatLook.PIXEL_ICONS.has(stat.icon), "%s: zijn icoon bestaat" % stat_name)
		test.check(int(stat.segments) > 0 and int(stat.height) > 0 and stat.colour != stat.empty, "%s: een balk met twee kleuren" % stat_name)
	for icon_name: String in StatLook.PIXEL_ICONS:
		var rows: Array = StatLook.PIXEL_ICONS[icon_name]
		test.check(rows.size() == 7 and rows.all(func(row: String) -> bool: return row.length() == 7), "%s: 7 x 7 pixels" % icon_name)


func test_stat_values_stay_within_their_maximum(test) -> void:
	test.check(StatLook.clamped(35.0, 80.0, 100.0) == Vector2(35.0, 80.0), "een waarde met een nieuw maximum")
	test.check(StatLook.clamped(35.0, -1.0, 100.0) == Vector2(35.0, 100.0), "zonder maximum: het vorige blijft")
	test.check(StatLook.clamped(120.0, 80.0, 100.0) == Vector2(80.0, 80.0), "niet boven het maximum")
	test.check(StatLook.clamped(-5.0, 80.0, 100.0) == Vector2(0.0, 80.0), "niet onder nul")
	test.check(StatLook.value_text(Vector2(34.6, 80.0)) == "35/80", "afgerond geschreven (%s)" % StatLook.value_text(Vector2(34.6, 80.0)))
	test.check(is_equal_approx(StatLook.fill(Vector2(20.0, 80.0)), 0.25), "een kwart vol")
	test.check(StatLook.fill(Vector2(5.0, 0.0)) == 0.0, "een maximum van nul: leeg, geen deling door nul")


func test_experience_within_the_level(test) -> void:
	test.check(StatLook.experience(120.0, 300.0) == Vector2(120.0, 300.0), "punten binnen het level")
	test.check(StatLook.experience(400.0, 300.0) == Vector2(300.0, 300.0), "niet meer dan het level lang is")
	test.check(StatLook.experience(-10.0, 300.0) == Vector2(0.0, 300.0), "niet minder dan nul")
	test.check(StatLook.experience(0.0, 0.0) == Vector2(0.0, 1.0), "een level is minstens één punt lang")
