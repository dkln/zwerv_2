extends SceneTree
## Impatient drivers (scripts/vehicles/driver_shout.gd): a honking vehicle that waits for
## someone sometimes shouts a line in a speech balloon over its roof; not every time (the pause
## per speaker and for everyone), not out of view, gone after a couple of seconds, and the
## same line never twice in a row.
## usage: tools/godot.sh --headless --script tools/check/driver_shout_test.gd

const Common = preload("res://tools/tool_common.gd")
const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 60)
	var world := Node3D.new()
	get_root().add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 4.0, 14.0)
	var car := Node3D.new()
	world.add_child(car)
	var behind := Node3D.new()
	world.add_child(behind)
	behind.position = Vector3(0.0, 0.0, 40.0)
	await process_frame
	# the lines: varied, never twice in a row
	var seen := {}
	var previous := ""
	for pick_index in 200:
		var line := DriverShout.pick_line("auto", "wachten")
		_check(line != previous, "niet twee keer dezelfde regel achter elkaar (%s)" % line)
		previous = line
		seen[line] = true
	_check(seen.size() >= 10, "gevarieerd (%d verschillende regels)" % seen.size())
	_check(DriverShout.pick_line("fiets", "wachten") != "", "ook voor een fietser")
	# out of view: no shout, however often it tries
	var shouted_behind := false
	for try_index in 50:
		shouted_behind = DriverShout.shout(behind, "auto", "wachten", 1.9) or shouted_behind
	_check(not shouted_behind, "geen ballon buiten beeld")
	# in view: within a few honks it shouts
	var shouted := false
	for try_index in 50:
		if DriverShout.shout(car, "auto", "wachten", 1.9):
			shouted = true
			break
	_check(shouted, "een wachtende auto roept iets")
	var layer: CanvasLayer = DriverShout._balloon_layer
	_check(layer != null and layer.get_child_count() == 1, "één ballon op de ballonnenlaag")
	# the pause: right after it, nobody shouts
	var again := false
	for try_index in 50:
		again = DriverShout.shout(car, "auto", "wachten", 1.9) or again
	_check(not again, "niet bij elke toeter (pauze)")
	_check(DriverShout.shout(car, "auto", "doordrukken", 1.9), "doordrukken roept altijd, ook in de pauze")
	_check(layer.get_child_count() == 1, "in dezelfde ballon (geen tweede erbij)")
	if layer and layer.get_child_count() > 0:
		var balloon: Control = layer.get_child(0)
		await create_timer(1.0).timeout
		var text: String = balloon._text.get_parsed_text()
		_check(text.strip_edges() != "" and balloon.visible, "met tekst in beeld")
		print("ballon: ", text)
		await create_timer(DriverShout.HOLD_SECONDS + 1.5).timeout
		_check(not is_instance_valid(balloon), "na een paar seconden weg")
	# a vehicle that goes takes its balloon with it
	DriverShout._any_ready_at = 0.0
	var second_car := Node3D.new()
	world.add_child(second_car)
	var second_shouted := false
	for try_index in 50:
		if DriverShout.shout(second_car, "bus", "wachten", 3.0):
			second_shouted = true
			break
	_check(second_shouted, "een tweede voertuig roept iets")
	second_car.queue_free()
	await process_frame
	await process_frame
	_check(layer.get_child_count() == 0, "ballon weg met het voertuig")
	if _problems.is_empty():
		print("OK: toeterballonnen")
		quit(0)
	else:
		for problem in _problems:
			printerr("FOUT: ", problem)
		quit(1)


func _check(condition: bool, what: String) -> void:
	if not condition:
		_problems.append(what)
