extends RefCounted
## Unit tests of the logic of the level-up screen (scripts/ui/screens/level_up_screen_rules.gd):
## the stats, the next one, from when a key takes, and the texts, without nodes.
##   tests/run_unit_tests.sh level_up_screen_rules

const LevelUpScreenRules = preload("res://scripts/ui/screens/level_up_screen_rules.gd")


func test_the_options_are_the_four_stats(test) -> void:
	var stats := LevelUpScreenRules.OPTIONS.map(func(option: Dictionary) -> String: return String(option.stat))
	test.check(stats == ["gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"], "de vier stats, in deze volgorde (%s)" % [stats])
	for option: Dictionary in LevelUpScreenRules.OPTIONS:
		test.check(String(option.name) != "" and String(option.text) != "", "%s: een naam en een uitleg" % option.stat)


func test_stat_at(test) -> void:
	test.check(LevelUpScreenRules.stat_at(0) == "gezondheid" and LevelUpScreenRules.stat_at(3) == "overprikkeldheid", "de eerste en de laatste")
	test.check(LevelUpScreenRules.stat_at(-1) == "" and LevelUpScreenRules.stat_at(4) == "", "buiten de lijst: niets")


func test_next_index_goes_round(test) -> void:
	test.check(LevelUpScreenRules.next_index(0, 1) == 1 and LevelUpScreenRules.next_index(3, 1) == 0, "omlaag, onderaan weer naar boven")
	test.check(LevelUpScreenRules.next_index(0, -1) == 3 and LevelUpScreenRules.next_index(2, -1) == 1, "omhoog, bovenaan naar onderen")
	test.check(LevelUpScreenRules.next_index(1, 0) == 1, "geen stap: blijft")


func test_keys_work_after_a_moment(test) -> void:
	test.check(not LevelUpScreenRules.keys_work(0.0), "meteen: nog niet")
	test.check(not LevelUpScreenRules.keys_work(LevelUpScreenRules.KEYS_AFTER - 0.01), "vlak ervoor: nog niet")
	test.check(LevelUpScreenRules.keys_work(LevelUpScreenRules.KEYS_AFTER), "precies op tijd: wel")
	test.check(LevelUpScreenRules.keys_work(10.0), "lang erna: wel")


func test_level_and_xp_texts(test) -> void:
	test.check(LevelUpScreenRules.level_text(3) == "LEVEL 3" and LevelUpScreenRules.level_text(12) == "LEVEL 12", "het nieuwe level")
	test.check(LevelUpScreenRules.xp_text(150) == "+150 XP" and LevelUpScreenRules.xp_text(0) == "+0 XP", "de XP waarmee het kwam")
	test.check(LevelUpScreenRules.shows_xp(1) and not LevelUpScreenRules.shows_xp(0) and not LevelUpScreenRules.shows_xp(-5), "alleen te zien als er XP bij was")


func test_value_text(test) -> void:
	test.check(LevelUpScreenRules.value_text(70.0, 10.0) == "70 → 80", "nu → straks")
	test.check(LevelUpScreenRules.value_text(99.6, 0.0) == "100 → 100", "afgerond op hele punten, niets erbij")
	test.check(LevelUpScreenRules.value_text(0.0, 15.0) == "0 → 15", "vanaf nul")
	test.check(LevelUpScreenRules.value_text(70.4, 10.2) == "70 → 81", "nu en straks elk voor zich afgerond")
