extends RefCounted
## Unit tests of the rules of the clock (scripts/ui/hud/clock_rules.gd).
##   tests/run_unit_tests.sh clock_rules

const ClockRules = preload("res://scripts/ui/hud/clock_rules.gd")


func test_time_and_day_as_written(test) -> void:
	test.check(ClockRules.time_text(8.5) == "08:30", "half negen")
	test.check(ClockRules.time_text(0.0) == "00:00" and ClockRules.time_text(23.99) == "23:59", "het begin en het eind van de dag")
	test.check(ClockRules.time_text(24.0) == "00:00", "middernacht is nul uur")
	test.check(ClockRules.time_text(12.25) == "12:15", "kwart over twaalf")
	test.check(ClockRules.day_text(3) == "DAG 3", "de dag")


func test_hour_of_day(test) -> void:
	test.check(ClockRules.hour_of_day(25.25) == 1.25, "voorbij middernacht telt door vanaf nul")
	test.check(ClockRules.hour_of_day(8.5) == 8.5 and ClockRules.hour_of_day(-1.0) == 23.0, "een gewoon uur, en een uur terug")


func test_night(test) -> void:
	test.check(ClockRules.is_night(3.0) and ClockRules.is_night(22.0), "diep in de nacht en laat op de avond")
	test.check(not ClockRules.is_night(6.5) and not ClockRules.is_night(12.0) and not ClockRules.is_night(21.0), "overdag, tot en met negen uur 's avonds")


func test_a_day_passes_round_midnight(test) -> void:
	test.check(ClockRules.day_passed(23.9, 0.1), "van vlak voor naar vlak na middernacht")
	test.check(not ClockRules.day_passed(10.0, 10.1) and not ClockRules.day_passed(10.0, 9.0), "de tijd loopt gewoon door, of een beetje terug")
	test.check(not ClockRules.day_passed(ClockRules.NO_HOUR, 0.1), "de eerste keer kijken is geen nieuwe dag")
