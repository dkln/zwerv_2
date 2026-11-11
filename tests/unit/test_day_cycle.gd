extends RefCounted
## Unit tests of the colours of the day (scripts/world/day_cycle.gd, DAY_COLOURS): every moment
## has every colour, they blend without jumps, the night is dark and the day light, and the day
## ends where it begins.

const DayCycle = preload("res://scripts/world/day_cycle.gd")


func test_every_moment_has_every_colour(test) -> void:
	var keys: Array = (DayCycle.DAY_COLOURS[0] as Array)[1].keys()
	for moment: Array in DayCycle.DAY_COLOURS:
		test.check((moment[1] as Dictionary).keys() == keys, "%.1f uur: alle kleuren" % moment[0])


func test_night_and_day(test) -> void:
	var midnight: Dictionary = DayCycle._colours_at(0.0)
	var noon: Dictionary = DayCycle._colours_at(13.0)
	test.check(float(midnight.night) > 0.9 and float(noon.night) < 0.1, "'s nachts donker, 's middags licht")
	test.check(float(noon.sun_energy) > float(midnight.sun_energy), "'s middags staat de zon aan")


func test_the_day_closes_round(test) -> void:
	var start: Dictionary = DayCycle._colours_at(0.0)
	var end: Dictionary = DayCycle._colours_at(24.0)
	test.check(is_equal_approx(float(start.night), float(end.night)) and (start.sky_top as Color).is_equal_approx(end.sky_top),
		"middernacht aan het eind is middernacht aan het begin")


func test_no_jumps(test) -> void:
	# a minute later the light changes only a little
	var biggest := 0.0
	var before: Dictionary = DayCycle._colours_at(0.0)
	for minute in range(1, 24 * 60 + 1):
		var now: Dictionary = DayCycle._colours_at(minute / 60.0)
		biggest = maxf(biggest, absf(float(now.night) - float(before.night)))
		biggest = maxf(biggest, absf(float(now.sun_energy) - float(before.sun_energy)))
		before = now
	test.check(biggest < 0.05, "geen sprongen (grootste stap per minuut %.3f)" % biggest)
