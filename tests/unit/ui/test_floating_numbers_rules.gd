extends RefCounted
## Unit tests of the life of a floating number (scripts/ui/widgets/floating_numbers_rules.gd).
##   tests/run_unit_tests.sh floating_numbers_rules

const FloatingNumbersRules = preload("res://scripts/ui/widgets/floating_numbers_rules.gd")


func test_rise_slows_down_to_its_height(test) -> void:
	test.check(FloatingNumbersRules.rise(0.0) == 0.0, "aan het begin: op de plek zelf")
	test.check(is_equal_approx(FloatingNumbersRules.rise(1.0), FloatingNumbersRules.RISE_METRES), "aan het eind: RISE_METRES hoger")
	test.check(is_equal_approx(FloatingNumbersRules.rise(0.5), FloatingNumbersRules.RISE_METRES * 0.75), "halverwege al driekwart: eerst snel, dan langzaam")
	test.check(FloatingNumbersRules.rise(0.25) < FloatingNumbersRules.rise(0.5) and FloatingNumbersRules.rise(0.5) < FloatingNumbersRules.rise(0.75), "steeds hoger")


func test_pop_and_fade(test) -> void:
	test.check(is_equal_approx(FloatingNumbersRules.pop_scale(0.0), FloatingNumbersRules.POP_SCALE), "het verschijnt groter")
	test.check(is_equal_approx(FloatingNumbersRules.pop_scale(FloatingNumbersRules.POP_SECONDS * 0.5), (FloatingNumbersRules.POP_SCALE + 1.0) * 0.5), "krimpt")
	test.check(FloatingNumbersRules.pop_scale(FloatingNumbersRules.POP_SECONDS) == 1.0 and FloatingNumbersRules.pop_scale(1.0) == 1.0, "tot zijn eigen maat")
	test.check(FloatingNumbersRules.opacity(0.0) == 1.0 and FloatingNumbersRules.opacity(FloatingNumbersRules.FADE_FROM) == 1.0, "tot FADE_FROM helemaal te zien")
	test.check(is_equal_approx(FloatingNumbersRules.opacity((1.0 + FloatingNumbersRules.FADE_FROM) * 0.5), 0.5), "daarna vervaagt het")
	test.check(is_zero_approx(FloatingNumbersRules.opacity(1.0)) and FloatingNumbersRules.opacity(1.5) == 0.0, "aan het eind weg")
