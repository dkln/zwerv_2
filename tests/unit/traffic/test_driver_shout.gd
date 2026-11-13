extends RefCounted
## Unit tests of DriverShout.pick_line (scripts/vehicles/driver_shout.gd): a line that fits the
## mood (and the kind of vehicle), never the same one twice in a row.

const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")


## The line picked belongs to the mood asked for (pushing on, a collision, a wheelie).
func test_a_line_fits_the_mood(test) -> void:
	test.check(DriverShout.PUSHING_LINES.has(DriverShout.pick_line("auto", "doordrukken")), "doordrukken: een doordruk-tekst")
	test.check(DriverShout.HIT_LINES.has(DriverShout.pick_line("auto", "aanrijding")), "aanrijding: een aanrijd-tekst")
	var wheelie := DriverShout.pick_line("motor", "wheelie")
	test.check(DriverShout.WHEELIE_LINES.has(wheelie) or (DriverShout.WHEELIE_KIND_LINES.motor as Array).has(wheelie), "wheelie: een stoere tekst (%s)" % wheelie)


## The same mood never gives the same line twice in a row.
func test_never_the_same_line_twice(test) -> void:
	var last := DriverShout.pick_line("auto", "wachten")
	for attempt in 40:
		var next := DriverShout.pick_line("auto", "wachten")
		test.check(next != last, "niet twee keer \"%s\"" % next)
		last = next


## The lines of a kind of vehicle (the bus) are never picked for pushing on: they are
## only for waiting or warning.
func test_own_kind_lines_only_when_waiting_or_warning(test) -> void:
	var bus_lines: Array = DriverShout.KIND_LINES.bus
	for attempt in 40:
		test.check(not bus_lines.has(DriverShout.pick_line("bus", "doordrukken")), "doordrukken zonder eigen bus-teksten")


## A drunk and an aggressive driver have lines of their own, and babble in their mood.
func test_an_idiot_at_the_wheel_has_lines_of_its_own(test) -> void:
	for attempt in 10:
		test.check(DriverShout.DRUNK_LINES.has(DriverShout.pick_line("auto", "dronken")), "dronken: een dronken tekst")
		test.check(DriverShout.AGGRESSIVE_LINES.has(DriverShout.pick_line("auto", "agressief")), "agressief: een agressieve tekst")
	test.check(DriverShout.BABBLE_MOOD.dronken == "opgewonden" and DriverShout.BABBLE_MOOD.agressief == "boos", "brabbelt in de stemming")
