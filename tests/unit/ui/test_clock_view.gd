extends RefCounted
## Unit tests of the picture of the clock (scripts/ui/hud/clock_view.gd).
##   tests/run_unit_tests.sh clock_view

const ClockView = preload("res://scripts/ui/hud/clock_view.gd")


func test_shows_time_and_day(test) -> void:
	var view := ClockView.new()
	test.check(view.time_text() == "12:00" and view.day_text() == "DAG 1" and view.icon_colour() == ClockView.DAY_COLOUR, "eerst twaalf uur op dag 1")
	view.show_clock("08:30", "DAG 3", false)
	test.check(view.time_text() == "08:30" and view.day_text() == "DAG 3" and view.icon_colour() == ClockView.DAY_COLOUR, "de tijd en de dag, overdag")
	view.show_clock("23:10", "DAG 3", true)
	test.check(view.icon_colour() == ClockView.NIGHT_COLOUR and ClockView.NIGHT_COLOUR != ClockView.DAY_COLOUR, "'s nachts het icoon gedimd")
	view.free()
