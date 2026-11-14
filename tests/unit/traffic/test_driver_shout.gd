extends RefCounted
## Unit tests of DriverShout (scripts/vehicles/driver_shout.gd): a line that fits the mood
## (and the kind of vehicle), never the same one twice in a row; who shouts when (the
## pauses, in view, always for some moods), in which balloon and in which voice.
##   tests/run_unit_tests.sh driver_shout

const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
const DriverShoutRules = preload("res://scripts/vehicles/driver_shout_rules.gd")
const DriverShoutView = preload("res://scripts/vehicles/driver_shout_view.gd")
const Babble = preload("res://scripts/audio/babble.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Someone with a voice of their own (as a pedestrian).
class Talker:
	extends Node3D

	func voice() -> String:
		return "vrouw"


## A small world with a camera looking at the origin, nobody having shouted yet.
func _world() -> Node3D:
	var world := Node3D.new()
	tree.root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 4.0, 14.0)
	camera.make_current()
	DriverShout._any_ready_at = 0.0
	return world


func _speaker(world: Node3D, at := Vector3.ZERO) -> Node3D:
	var speaker := Node3D.new()
	world.add_child(speaker)
	speaker.position = at
	return speaker


## Frees the world and the layer of the balloons, so the next test starts clean.
func _clear(world: Node3D) -> void:
	if is_instance_valid(DriverShout._balloon_layer):
		DriverShout._balloon_layer.free()
	DriverShout._balloon_layer = null
	DriverShout._any_ready_at = 0.0
	world.free()


func _balloons() -> int:
	return DriverShout._balloon_layer.get_child_count() if is_instance_valid(DriverShout._balloon_layer) else 0


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


## Every kind that does wheelies has a cocky line to shout (mood "wheelie").
func test_every_wheelie_kind_has_a_line(test) -> void:
	for kind: String in ["fatbike", "brommer", "motor", "rolstoel"]:
		var line := DriverShout.pick_line(kind, "wheelie")
		test.check(line != "", "wheelie-tekst voor %s: %s" % [kind, line])


## With the same draws the lines come in the same order (the draw, then the rule against
## the same line twice).
func test_the_same_draws_give_the_same_lines(test) -> void:
	var state := DriverShout._random.state
	var last := DriverShout._last_line
	var first: Array[String] = []
	for attempt in 12:
		first.append(DriverShout.pick_line("tram", "wachten"))
	DriverShout._random.state = state
	DriverShout._last_line = last
	var draws := RandomNumberGenerator.new()
	draws.state = state
	var lines := DriverShoutRules.lines_for("tram", "wachten")
	for attempt in 12:
		var line := DriverShout.pick_line("tram", "wachten")
		var expected := DriverShoutRules.line_at(lines, draws.randi_range(0, lines.size() - 1), last)
		test.check(line == first[attempt] and line == expected, "regel %d: dezelfde bij dezelfde trekking" % attempt)
		last = line


func test_the_old_names_are_still_there(test) -> void:
	test.check(DriverShout.WAITING_LINES == DriverShoutRules.WAITING_LINES and DriverShout.FALLEN_LINES == DriverShoutRules.FALLEN_LINES, "de regels onder hun oude naam")
	test.check(DriverShout.SHOUT_CHANCE == 0.9 and DriverShout.WARNING_CHANCE == 0.6 and DriverShout.SPEAKER_PAUSE == 6.0 and DriverShout.ANY_PAUSE == 1.5, "de kansen en de pauzes")
	test.check(DriverShout.SHOUT_DISTANCE == 45.0 and DriverShout.HOLD_SECONDS == 2.2 and DriverShout.BALLOON_LAYER == 9, "de afstand, de duur en de laag")
	test.check(DriverShout.MOODS.size() == 12 and DriverShout.DRIVER_ACCENT == DriverShoutView.DRIVER_ACCENT, "de stemmingen en de kleur")


func test_nobody_shouts_outside_the_tree_or_without_a_camera(test) -> void:
	var loose := Node3D.new()
	test.check(not DriverShout.shout(loose, "auto", "doordrukken", 1.9), "niet in de boom: geen roep")
	test.check(not DriverShout.shout_line(loose, "Hé!", 1.9), "ook geen eigen regel")
	test.check(not DriverShout.shout(null, "auto", "doordrukken", 1.9) and not DriverShout.shout_line(null, "Hé!", 1.9), "niemand: geen roep")
	loose.free()
	var world := Node3D.new()
	tree.root.add_child(world)
	var speaker := _speaker(world)
	if speaker.get_viewport().get_camera_3d() == null:
		test.check(not DriverShout.shout(speaker, "auto", "doordrukken", 1.9), "zonder camera: geen roep")
		test.check(not DriverShout.shout_line(speaker, "Hé!", 1.9), "en geen eigen regel")
		test.check(not speaker.has_meta(DriverShout.READY_META), "en geen pauze")
	_clear(world)


func test_a_mood_that_always_shouts_puts_a_balloon_up(test) -> void:
	var world := _world()
	var car := _speaker(world)
	test.check(DriverShout.shout(car, "auto", "doordrukken", 1.9), "doordrukken roept altijd")
	test.check(_balloons() == 1 and DriverShout._balloon_layer.get_parent() == tree.root, "één ballon, op de laag onder de root (geen scène)")
	var balloon: Node = car.get_meta(DriverShout.BALLOON_META)
	test.check(balloon.get_parent() == DriverShout._balloon_layer and balloon.is_talking(), "de ballon van deze auto praat")
	test.check(DriverShout.PUSHING_LINES.has(DriverShout._last_line), "met een doordruk-tekst")
	test.check(float(car.get_meta(DriverShout.READY_META)) > DriverShout._any_ready_at, "zijn eigen pauze duurt langer dan die van iedereen")
	test.check(DriverShout.shout(car, "auto", "aanrijding", 1.9) and _balloons() == 1, "nog een keer: in dezelfde ballon")
	_clear(world)


func test_waiting_shouts_now_and_then_and_not_within_the_pauses(test) -> void:
	var world := _world()
	var car := _speaker(world)
	var shouted := false
	for attempt in 50:
		DriverShout._any_ready_at = 0.0
		if DriverShout.shout(car, "auto", "wachten", 1.9):
			shouted = true
			break
	test.check(shouted, "een wachtende auto roept binnen een paar keer toeteren")
	for attempt in 50:
		test.check(not DriverShout.shout(car, "auto", "wachten", 1.9), "meteen daarna niet nog eens")
	var other := _speaker(world, Vector3(2.0, 0.0, 0.0))
	for attempt in 50:
		test.check(not DriverShout.shout(other, "auto", "waarschuwen", 1.9), "ook een ander niet, binnen de pauze van iedereen")
	test.check(DriverShout.shout(other, "auto", "spoor", 1.9) and _balloons() == 2, "maar wie altijd roept wel: een tweede ballon")
	_clear(world)


func test_nobody_shouts_out_of_view_or_too_far_off(test) -> void:
	var world := _world()
	var behind := _speaker(world, Vector3(0.0, 0.0, 40.0))
	test.check(not DriverShout.shout(behind, "auto", "doordrukken", 1.9), "achter de camera: geen roep")
	var far := _speaker(world, Vector3(0.0, 0.0, -DriverShout.SHOUT_DISTANCE - 5.0))
	test.check(not DriverShout.shout(far, "auto", "doordrukken", 1.9), "te ver van de camera: geen roep")
	test.check(_balloons() == 0 and not behind.has_meta(DriverShout.READY_META), "geen ballon, geen pauze")
	_clear(world)


func test_shout_line_always_says_its_line(test) -> void:
	var world := _world()
	var guard := _speaker(world)
	DriverShout._any_ready_at = Time.get_ticks_msec() / 1000.0 + 100.0
	test.check(DriverShout.shout_line(guard, "Wegwezen hier!", 2.1, "boos"), "een eigen regel, ook in de pauze van iedereen")
	test.check(_balloons() == 1 and guard.has_meta(DriverShout.READY_META), "een ballon, en zijn eigen pauze gaat in")
	test.check(not DriverShout.shout_line(guard, "", 2.1), "een lege regel: niets")
	test.check(DriverShout.shout_line(guard, "Nu!", 2.1) and _balloons() == 1, "een nieuwe regel in dezelfde ballon")
	_clear(world)


func test_the_voice_of_a_speaker(test) -> void:
	var talker := Talker.new()
	test.check(DriverShout.voice_of(talker) == "vrouw", "een voetganger: zijn eigen stem")
	talker.free()
	var car := Node3D.new()
	var voice := DriverShout.voice_of(car)
	test.check(Babble.VOICES.has(voice) and DriverShout.voice_of(car) == voice, "een voertuig: een vaste stem uit de stemmen")
	test.check(voice == Babble.VOICES[car.get_instance_id() % Babble.VOICES.size()], "die bij zijn nummer hoort")
	car.free()
