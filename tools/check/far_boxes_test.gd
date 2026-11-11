extends SceneTree
## Far out the people and vehicles are blocks (scripts/world/far_boxes.gd): zoomed out (the
## arrival, 300 m in view) their own models are hidden and there is one block for each; zoomed
## in again their models are back and the blocks gone.
## usage: tools/godot.sh --headless --script tools/check/far_boxes_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	get_root().add_child(scene)
	for frame_index in 120:
		await process_frame
	var boxes: Node = scene.get_node("VerreBlokjes")
	var walkers: Node = scene.get_node("Voetgangers")
	var camera := get_root().get_viewport().get_camera_3d()
	# far: from high up (the iso camera's distance gives what is in view)
	var focus: Vector3 = scene.get_node("Speler").global_position
	scene.get_node("Volgcamera").process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = Iso.position(focus, 300.0)
	for frame_index in 5:
		await process_frame
	var people: Array = walkers.people()
	var hidden_people: int = people.filter(func(person: Node) -> bool: return person._drawn and not person._drawn.visible).size()
	var vehicles := Vehicle.all_vehicles.filter(func(vehicle: Vehicle) -> bool: return not vehicle.crashed)
	var hidden_vehicles := vehicles.filter(func(vehicle: Vehicle) -> bool: return not vehicle._body.visible).size()
	print("ver: %d van %d voetgangers en %d van %d voertuigen als blokje; blokjes %d + %d" % [hidden_people, people.size(),
			hidden_vehicles, vehicles.size(), boxes._people.multimesh.visible_instance_count, boxes._vehicles.multimesh.visible_instance_count])
	_check(boxes.far and hidden_people == people.size() and people.size() > 0, "ver weg: voetgangers zijn blokjes")
	_check(hidden_vehicles == vehicles.size() and vehicles.size() > 0, "ver weg: voertuigen zijn blokjes")
	_check(boxes._people.multimesh.visible_instance_count == people.size() and boxes._vehicles.multimesh.visible_instance_count == vehicles.size(),
			"één blokje per voetganger en voertuig")
	# near again
	camera.global_position = Iso.position(focus, 20.0)
	for frame_index in 5:
		await process_frame
	var shown_people: int = walkers.people().filter(func(person: Node) -> bool: return person._drawn and person._drawn.visible).size()
	var shown_vehicles := Vehicle.all_vehicles.filter(func(vehicle: Vehicle) -> bool: return vehicle._body.visible).size()
	_check(not boxes.far and not boxes._people.visible and shown_people == walkers.people().size() and shown_vehicles == Vehicle.all_vehicles.size(),
			"dichtbij weer de echte figuren")
	print("verre blokjes ok" if _problems.is_empty() else "%d problemen: %s" % [_problems.size(), _problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FOUT ") + what)
	if not ok:
		_problems.append(what)
