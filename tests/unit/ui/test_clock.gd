extends RefCounted
## Unit tests of the clock of the HUD (scripts/ui/hud/clock.gd): the time of the day
## cycle, the days going by, and the clock set by hand.
##   tests/run_unit_tests.sh test_clock.gd

const Clock = preload("res://scripts/ui/hud/clock.gd")


## The day cycle of a town: only its hour.
class DayCycle extends Node:
	var time_of_day := 8.0


func test_follows_the_day_cycle(test) -> void:
	var clock := Clock.new()
	var day_cycle := DayCycle.new()
	test.check(clock.name == "Klok" and clock.day() == 1 and clock.hour() == 12.0, "eerst twaalf uur op dag 1")
	clock.set_day(4)
	clock.follow(day_cycle)
	test.check(clock.hour() == 8.0 and clock.day() == 4 and clock.view.time_text() == "08:00" and clock.view.day_text() == "DAG 4", "de tijd van de dagcyclus")
	day_cycle.time_of_day = 23.75
	clock.follow(day_cycle)
	test.check(clock.day() == 4 and clock.view.time_text() == "23:45", "later op de dag")
	day_cycle.time_of_day = 0.1
	clock.follow(day_cycle)
	test.check(clock.day() == 5 and clock.view.day_text() == "DAG 5" and clock.view.time_text() == "00:06", "rond middernacht: een dag erbij")
	clock.follow(day_cycle)
	test.check(clock.day() == 5, "een keer")
	day_cycle.free()
	clock.free()


func test_without_a_day_cycle_the_clock_stands(test) -> void:
	var clock := Clock.new()
	clock.follow(null)
	test.check(clock.view.time_text() == "12:00" and clock.view.day_text() == "DAG 1", "geen dagcyclus: twaalf uur")
	var no_clock := Node.new()
	clock.follow(no_clock)
	test.check(clock.hour() == 12.0, "een node zonder tijd: ook")
	no_clock.free()
	clock.free()


func test_set_by_hand(test) -> void:
	var clock := Clock.new()
	var day_cycle := DayCycle.new()
	clock.set_time(8.5, 3)
	test.check(clock.hour() == 8.5 and clock.day() == 3 and clock.view.time_text() == "08:30" and clock.view.day_text() == "DAG 3", "tijd en dag gezet")
	clock.set_time(25.25)
	test.check(clock.hour() == 1.25 and clock.day() == 3 and clock.view.time_text() == "01:15", "voorbij middernacht telt door vanaf nul, de dag blijft")
	clock.follow(day_cycle)
	test.check(clock.hour() == 1.25 and clock.view.time_text() == "01:15", "daarna wordt de dagcyclus niet meer gevolgd")
	test.check(clock.view.icon_colour() == clock.view.NIGHT_COLOUR, "en het is nacht")
	day_cycle.free()
	clock.free()
