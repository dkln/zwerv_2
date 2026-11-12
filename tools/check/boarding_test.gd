extends SceneTree
## Getting on and off trams and trains (Pedestrians.door_open_at, Pedestrian.board_at,
## RailVehicle._let_people_on_and_off): the platforms of the tram stops are walkable; with a
## door open beside one, someone standing on it walks to the door and is gone (boarded), and
## someone comes out of the door onto the platform and walks off (alighted). Then a real
## tram at a stop: while its doors stand open people get on and off.
## usage: tools/godot.sh --headless --script tools/check/boarding_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	PlayerCharacter.choose("jos")
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	walkers.unseen_without_camera = true
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	for frame_index in 300:
		await physics_frame
		if player._placed and not walkers.people().is_empty():
			break
	# the platform cells: walkable now
	var ground: GridMap = scene.get_node("Grond")
	var platforms: Array[Vector3i] = []
	for cell: Vector3i in walkers._walkable:
		var item_name := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
		if item_name in Pedestrians.PLATFORM_GROUND:
			platforms.append(cell)
	_check(platforms.size() > 10, "perrons zijn beloopbaar (%d cellen)" % platforms.size())
	if platforms.is_empty():
		_finish()
		return
	var platform: Vector3i = platforms[platforms.size() / 2]
	var door := walkers.cell_middle(platform) + Vector3(1.0, 0.0, 0.0)
	player.teleport(walkers.cell_middle(platform) + Vector3(0.0, 0.0, 12.0), 0.0)
	# someone waiting on the platform
	var waiting: Pedestrian = walkers.people()[0]
	waiting.restart_at(platform)
	for frame_index in 10:
		await physics_frame
	var boarded_before := walkers.boarded
	var alighted_before := walkers.alighted
	for second in 12:
		walkers.door_open_at(door, 1.0)
		for frame_index in 60:
			paused = false
			await physics_frame
	print("ingestapt %d, uitgestapt %d" % [walkers.boarded - boarded_before, walkers.alighted - alighted_before])
	_check(walkers.boarded > boarded_before, "iemand op het perron stapt in (naar de deur, weg)")
	_check(walkers.alighted > alighted_before, "iemand stapt uit, het perron op")
	_finish()


func _finish() -> void:
	print("in- en uitstappen ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
