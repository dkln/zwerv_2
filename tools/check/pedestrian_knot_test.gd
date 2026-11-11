extends SceneTree
## A knot of people (scripts/world/pedestrian.gd): walkers, wheelchairs and mobility scooters
## put on one spot, all heading through each other, must untangle (step aside, turn, at
## last walk through each other) and get on their way instead of standing there for good.
## usage: tools/godot.sh --headless --script tools/check/pedestrian_knot_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, true)
	for node_name in ["DetailNiveau", "Rook", "Verhaal", "Camera", "Doorkijk"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	# by day (the game starts at six, when few are out and hardly anyone rides an aid)
	scene.get_node("Dagcyclus").speed = 0.0
	scene.get_node("Dagcyclus").time_of_day = 13.0
	get_root().add_child(scene)
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	for frame_index in 300:
		await physics_frame
		if not walkers.people().is_empty():
			break
	await physics_frame
	var people: Array = walkers.people()
	var riders := people.filter(func(person: Pedestrian) -> bool: return person.aid != null)
	var on_foot := people.filter(func(person: Pedestrian) -> bool: return person.aid == null)
	var knot: Array = riders.slice(0, 3) + on_foot.slice(0, 5)
	_check(knot.size() >= 6, "genoeg mensen voor een kluit (%d)" % knot.size())
	# all on the spot of the first one, in a little ring, facing each other
	var middle: Vector3 = knot[0].global_position
	for index in knot.size():
		var person: Pedestrian = knot[index]
		var angle := TAU * index / knot.size()
		var spot := middle + Vector3(cos(angle), 0.0, sin(angle)) * 0.6
		# on a free spot (not in a lamppost or a bench), else in the middle
		person.global_position = spot if person._stands_free(spot) else middle
		person.rotation.y = angle + PI * 0.5 + PI
		person._pause = 0.0
		person._update_cell()
		# each heading to the other side of the ring
		person._target = middle - Vector3(cos(angle), 0.0, sin(angle)) * 3.0
	var start := {}
	for person: Pedestrian in knot:
		start[person] = person.global_position
	# how far each one got from the knot during the run (it may walk back past it later)
	var farthest := {}
	for frame_index in 60 * 20:
		await physics_frame
		for person: Pedestrian in knot:
			farthest[person] = maxf(float(farthest.get(person, 0.0)), Vector2(person.global_position.x - middle.x, person.global_position.z - middle.z).length())
	var away := 0
	for person: Pedestrian in knot:
		var moved: float = farthest[person]
		print("  %-14s %-11s %.1f m van de kluit" % [person.name, person.mobility if person.mobility != "" else "lopend", moved])
		if moved < 2.0:
			print("    pauze %.1f geblokt %.1f opgehouden %.1f geest %.1f doel %.1f m, mag %s, physics %s, ragdoll %s" % [person._pause, person._blocked, person._held_up, person._ghost_left,
				person._target.distance_to(person.global_position), person._may_go(), person.is_physics_processing(), person._ragdoll != null])
		if moved > 2.0:
			away += 1
	_check(away >= knot.size() - 1, "de kluit valt uiteen (%d van %d weg)" % [away, knot.size()])
	print("kluit ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)
