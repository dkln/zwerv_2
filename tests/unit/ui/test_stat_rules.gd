extends RefCounted
## Unit tests of the arithmetic of the stats and the experience (scripts/ui/hud/stat_rules.gd).
##   tests/run_unit_tests.sh stat_rules

const StatRules = preload("res://scripts/ui/hud/stat_rules.gd")


func test_stat_values_stay_within_their_maximum(test) -> void:
	test.check(StatRules.clamped(35.0, 80.0, 100.0) == Vector2(35.0, 80.0), "een waarde met een nieuw maximum")
	test.check(StatRules.clamped(35.0, -1.0, 100.0) == Vector2(35.0, 100.0), "zonder maximum: het vorige blijft")
	test.check(StatRules.clamped(120.0, 80.0, 100.0) == Vector2(80.0, 80.0), "niet boven het maximum")
	test.check(StatRules.clamped(-5.0, 80.0, 100.0) == Vector2(0.0, 80.0), "niet onder nul")
	test.check(StatRules.DEFAULT_MAXIMUM == 100.0, "wie nooit een maximum kreeg: 100")


func test_value_text_and_fill(test) -> void:
	test.check(StatRules.value_text(Vector2(34.6, 80.0)) == "35/80", "afgerond geschreven (%s)" % StatRules.value_text(Vector2(34.6, 80.0)))
	test.check(StatRules.value_text(Vector2.ZERO) == "0/0", "leeg")
	test.check(is_equal_approx(StatRules.fill(Vector2(20.0, 80.0)), 0.25), "een kwart vol")
	test.check(StatRules.fill(Vector2(80.0, 80.0)) == 1.0, "vol")
	test.check(StatRules.fill(Vector2(5.0, 0.0)) == 0.0, "een maximum van nul: leeg, geen deling door nul")


func test_a_jump_is_a_change_of_some_points_at_once(test) -> void:
	test.check(StatRules.is_jump(50.0, 40.0) and StatRules.is_jump(40.0, 50.0), "tien punten erbij of eraf: een sprong")
	test.check(not StatRules.is_jump(50.0, 49.5) and not StatRules.is_jump(50.0, 50.0), "langzaam leeglopen niet")
	test.check(StatRules.is_jump(50.0, 50.0 - StatRules.JUMP_FROM), "vanaf de drempel wel")


func test_experience_within_the_level(test) -> void:
	test.check(StatRules.experience(120.0, 300.0) == Vector2(120.0, 300.0), "punten binnen het level")
	test.check(StatRules.experience(400.0, 300.0) == Vector2(300.0, 300.0), "niet meer dan het level lang is")
	test.check(StatRules.experience(-10.0, 300.0) == Vector2(0.0, 300.0), "niet minder dan nul")
	test.check(StatRules.experience(0.0, 0.0) == Vector2(0.0, 1.0), "een level is minstens één punt lang")


func test_experience_and_level_texts(test) -> void:
	test.check(StatRules.experience_text(Vector2(6420.0, 10000.0)) == "6.420 / 10.000", "met punten voor de duizendtallen (%s)" % StatRules.experience_text(Vector2(6420.0, 10000.0)))
	test.check(StatRules.experience_text(Vector2(0.0, 300.0)) == "0 / 300", "aan het begin van een level")
	test.check(StatRules.level_text(4) == "LEVEL 4", "het level op het plaatje")
