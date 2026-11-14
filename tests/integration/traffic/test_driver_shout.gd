extends "res://tests/integration/support/town_test.gd"
## Impatient drivers (scripts/vehicles/driver_shout.gd): a honking vehicle that waits for
## someone sometimes shouts a line in a speech balloon over its roof; not every time (the pause
## per speaker and for everyone), not out of view, gone after a couple of seconds, and the
## same line never twice in a row. Without the town: a camera and a few stand-in vehicles.
##   tests/run_integration_tests.sh driver_shout

const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
## How often a waiting vehicle "honks" (tries to shout) in a test.
const TRIES := 50

var _world: Node3D


static func world_options() -> Dictionary:
	return {"town": false}


## A small world with a camera looking at the origin, nobody having shouted yet.
func _set_up() -> void:
	_world = Node3D.new()
	add_to_root(_world)
	var camera := Camera3D.new()
	_world.add_child(camera)
	camera.position = Vector3(0.0, 4.0, 14.0)
	DriverShout._any_ready_at = 0.0
	await frames(1)


## A stand-in for a vehicle at `at`.
func _vehicle_at(at := Vector3.ZERO) -> Node3D:
	var vehicle := Node3D.new()
	_world.add_child(vehicle)
	vehicle.position = at
	return vehicle


## Lets `vehicle` (of `kind`, its roof at `roof_height`) honk TRIES times while waiting,
## stopping at its first shout if `until_first`; returns whether it shouted at all.
func _honk(vehicle: Node3D, kind := "auto", roof_height := 1.9, until_first := true) -> bool:
	var shouted := false
	for try_index in TRIES:
		if DriverShout.shout(vehicle, kind, "wachten", roof_height):
			shouted = true
			if until_first:
				break
	return shouted


## The lines are varied, never the same one twice in a row, and there are some for a cyclist too.
func test_lines_are_varied_and_never_twice_in_a_row(test) -> void:
	var seen := {}
	var previous := ""
	for pick_index in 200:
		var line := DriverShout.pick_line("auto", "wachten")
		test.check(line != previous, "niet twee keer dezelfde regel achter elkaar (%s)" % line)
		previous = line
		seen[line] = true
	test.check(seen.size() >= 10, "gevarieerd (%d verschillende regels)" % seen.size())
	test.check(DriverShout.pick_line("fiets", "wachten") != "", "ook voor een fietser")


## A vehicle out of view never shouts, however often it tries.
func test_no_balloon_out_of_view(test) -> void:
	await _set_up()
	var behind := _vehicle_at(Vector3(0.0, 0.0, 40.0))
	test.check(not _honk(behind, "auto", 1.9, false), "geen ballon buiten beeld")


## A waiting vehicle in view shouts within a few honks: one balloon on the balloon layer.
func test_a_waiting_vehicle_in_view_shouts(test) -> void:
	await _set_up()
	test.check(_honk(_vehicle_at()), "een wachtende auto roept iets")
	var layer: CanvasLayer = DriverShout._balloon_layer
	test.check(layer != null and is_instance_valid(layer) and layer.get_child_count() == 1, "één ballon op de ballonnenlaag")


## Right after a shout nobody shouts again (the pause), but pushing through always does,
## in the same balloon.
func test_pause_after_a_shout_but_pushing_always_shouts(test) -> void:
	await _set_up()
	var car := _vehicle_at()
	test.check(_honk(car), "een wachtende auto roept iets")
	test.check(not _honk(car, "auto", 1.9, false), "niet bij elke toeter (pauze)")
	test.check(DriverShout.shout(car, "auto", "doordrukken", 1.9), "doordrukken roept altijd, ook in de pauze")
	test.check(DriverShout._balloon_layer.get_child_count() == 1, "in dezelfde ballon (geen tweede erbij)")


## The balloon shows its text in view and is gone after a couple of seconds.
func test_the_balloon_shows_its_line_and_goes(test) -> void:
	await _set_up()
	test.check(_honk(_vehicle_at()), "een wachtende auto roept iets")
	var layer: CanvasLayer = DriverShout._balloon_layer
	test.check(layer != null and layer.get_child_count() == 1, "één ballon op de ballonnenlaag")
	if layer == null or layer.get_child_count() == 0:
		return
	var balloon: Control = layer.get_child(0)
	await seconds(1.0)
	var text: String = balloon.view.text_label().get_parsed_text()
	test.check(text.strip_edges() != "" and balloon.visible, "met tekst in beeld")
	print("ballon: ", text)
	await seconds(DriverShout.HOLD_SECONDS + 1.5)
	test.check(not is_instance_valid(balloon), "na een paar seconden weg")


## A vehicle that goes (is freed) takes its balloon with it.
func test_the_balloon_goes_with_its_vehicle(test) -> void:
	await _set_up()
	var bus := _vehicle_at()
	test.check(_honk(bus, "bus", 3.0), "een tweede voertuig roept iets")
	var layer: CanvasLayer = DriverShout._balloon_layer
	bus.queue_free()
	await frames(2)
	test.check(layer != null and layer.get_child_count() == 0, "ballon weg met het voertuig")
