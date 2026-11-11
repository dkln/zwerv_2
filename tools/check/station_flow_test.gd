extends SceneTree
## People coming out of Den Haag Centraal and going into it (scripts/world/pedestrians.gd,
## the "station" share of data/drukte.json): in the morning rush, with the player near a
## station door, newcomers come out of the doors, people near it set off for a door and are
## gone through it; far off the station none of that.
## usage: tools/godot.sh --headless --script tools/check/station_flow_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

## Physics steps (60 a second) to watch the station's doors.
const WATCH_STEPS := 2400

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 280)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Verhaal", "Camera", "Doorkijk"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	var day: Node = scene.get_node("Dagcyclus")
	day.speed = 0.0
	day.time_of_day = 7.6
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var traffic: Traffic = scene.get_node("Verkeer")
	walkers.unseen_without_camera = true
	traffic.vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	for frame_index in 300:
		await physics_frame
		if player._placed and not walkers.people().is_empty():
			break
	walkers._find_station()
	print("stationsdeuren: %d, stappen tot een deur bekend voor %d cellen, aandeel in de spits %.2f" % [
		walkers._station_doors.size(), walkers._station_steps.size(), walkers.station_share()])
	_check(not walkers._station_doors.is_empty(), "de deuren van Centraal gevonden")
	if walkers._station_doors.is_empty():
		_finish()
		return
	# the player a little way off a door, on the street
	var door: Vector3 = walkers._station_doors[0]
	var near_cell: Vector3i = walkers._station_door_cells[0]
	for cell in walkers._station_steps:
		if walkers.station_steps(cell) == 6:
			near_cell = cell
			break
	player.call("teleport", walkers.cell_middle(near_cell) + Vector3.UP * 0.3, 0.0)
	for frame_index in 120:
		await physics_frame
	walkers.came_out_of_station = 0
	walkers.went_into_station = 0
	var most_heading := 0
	for step in WATCH_STEPS:
		await physics_frame
		if step % 600 == 0:
			var heading := walkers.people().filter(func(person: Pedestrian) -> bool: return person.heading_to_station)
			var total_steps := 0
			for person: Pedestrian in heading:
				total_steps += walkers.station_steps(person.cell)
			print("  %d s: %d op weg, gemiddeld %.1f cellen van een deur" % [step / 60, heading.size(), float(total_steps) / maxi(heading.size(), 1)])
		if step % 60 == 0 and OS.get_environment("STATION_TRACE") != "":
			var followed: Array = walkers.people().filter(func(person: Pedestrian) -> bool: return person.heading_to_station)
			if not followed.is_empty():
				var person: Pedestrian = followed[0]
				print("    %s cel %s stappen %d op %s doel %s volgende %s pauze %.1f geblokt %.1f binnen %s" % [person.name, person.cell,
					walkers.station_steps(person.cell), person.global_position.snapped(Vector3.ONE * 0.1), person._target.snapped(Vector3.ONE * 0.1),
					person._next_cell, person._pause, person._blocked, person._entering_station])
		if step % 60 == 0:
			most_heading = maxi(most_heading, walkers.people().filter(func(person: Pedestrian) -> bool: return person.heading_to_station).size())
	print("in %d s bij de deur (%.0f m van de speler): %d naar buiten, %d naar binnen, tot %d tegelijk op weg naar binnen, %d voetgangers" % [
		WATCH_STEPS / 60, door.distance_to(player.global_position), walkers.came_out_of_station, walkers.went_into_station,
		most_heading, walkers.people().size()])
	_check(walkers.came_out_of_station > 0, "in de spits komen er mensen uit het station")
	_check(most_heading > 0, "in de spits gaan er mensen op weg naar het station")
	_check(walkers.went_into_station > 0, "en ze verdwijnen door de deur")
	# far off: no coming and going
	var far_cell := near_cell
	for cell in walkers._walkable_cells:
		if walkers.cell_middle(cell).distance_to(door) > walkers.STATION_REACH + 200.0:
			far_cell = cell
			break
	player.call("teleport", walkers.cell_middle(far_cell) + Vector3.UP * 0.3, 0.0)
	for frame_index in 180:
		await physics_frame
	walkers.came_out_of_station = 0
	for step in 600:
		await physics_frame
	_check(walkers.came_out_of_station == 0, "ver van het station komt er niemand uit (%d)" % walkers.came_out_of_station)
	_finish()


func _finish() -> void:
	print("stationsdrukte ok" if _problems.is_empty() else "%d problemen: %s" % [_problems.size(), _problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FOUT ") + what)
	if not ok:
		_problems.append(what)
