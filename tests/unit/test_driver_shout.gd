extends RefCounted
## Unit tests of DriverShout.pick_line (scripts/vehicles/driver_shout.gd): a line that fits the
## mood (and the kind of vehicle), never the same one twice in a row.

const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")


func test_a_line_fits_the_mood(test) -> void:
	test.check(DriverShout.PUSHING_LINES.has(DriverShout.pick_line("auto", "doordrukken")), "doordrukken: een doordruk-tekst")
	test.check(DriverShout.HIT_LINES.has(DriverShout.pick_line("auto", "aanrijding")), "aanrijding: een aanrijd-tekst")
	var wheelie := DriverShout.pick_line("motor", "wheelie")
	test.check(DriverShout.WHEELIE_LINES.has(wheelie) or (DriverShout.WHEELIE_KIND_LINES.motor as Array).has(wheelie), "wheelie: een stoere tekst (%s)" % wheelie)


func test_never_the_same_line_twice(test) -> void:
	var last := DriverShout.pick_line("auto", "wachten")
	for attempt in 40:
		var next := DriverShout.pick_line("auto", "wachten")
		test.check(next != last, "niet twee keer \"%s\"" % next)
		last = next


func test_own_kind_lines_only_when_waiting_or_warning(test) -> void:
	var bus_lines: Array = DriverShout.KIND_LINES.bus
	for attempt in 40:
		test.check(not bus_lines.has(DriverShout.pick_line("bus", "doordrukken")), "doordrukken zonder eigen bus-teksten")
