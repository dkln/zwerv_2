extends SceneTree
## Stairs: the player walks up the stairs of the footbridge over the A12 (two flights of 3 m,
## props trappen/trap_3m with their exact collider, library_builder.gd STAIR_TILES) onto the
## deck, 6 m up, and down again at the other end; the pedestrians use them too (Pedestrians:
## the stair routes between the pavement and the deck).
## usage: tools/godot.sh --headless --script tools/check/stairs_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
## The footbridge (tools/build/city/a12.gd): its column, its two end rows; the stairs rise
## east along the middle of those rows, from x STAIR_FOOT_X to the deck.
const FOOTBRIDGE_COLUMN := 160
const FOOTBRIDGE_ROWS := [17, 28]
const STAIR_FOOT_X := 628.5
const DECK_HEIGHT := 6.0
const STEP := 0.05

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 240)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	for frame_index in 300:
		await physics_frame
		if player._placed:
			break
	player.set_physics_process(false)   # moved by hand here
	for row: int in FOOTBRIDGE_ROWS:
		var z := row * 4.0 + 2.0
		var start := Vector3(STAIR_FOOT_X - 2.0, 0.0, z)
		start.y = player._ground_height(start, 3.0, 6.0)
		player.global_position = start
		await physics_frame
		var highest := start.y
		var went := 0.0
		while player.global_position.x < FOOTBRIDGE_COLUMN * 4.0 + 1.5 and went < 30.0:
			var before: Vector3 = player.global_position
			if not player._try_move(Vector3(STEP, 0.0, 0.0)):
				break
			went += STEP
			highest = maxf(highest, player.global_position.y)
			if before.distance_to(player.global_position) < 0.001:
				break
		print("rij %d: van x %.1f (hoogte %.2f) tot x %.1f, hoogte %.2f" % [row, start.x, start.y, player.global_position.x, player.global_position.y])
		_check(player.global_position.y > DECK_HEIGHT - 0.3, "rij %d: de speler loopt de trap op tot op de brug (%.2f m)" % [row, player.global_position.y])
		# and down again
		while player.global_position.x > STAIR_FOOT_X - 1.5:
			if not player._try_move(Vector3(-STEP, 0.0, 0.0)):
				break
		_check(player.global_position.y < start.y + 0.3, "rij %d: en weer naar beneden (%.2f m)" % [row, player.global_position.y])
	player.set_physics_process(true)
	await _check_pedestrians(scene)
	print("trappen ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


## The pedestrians: a route over the stairs at both ends, the deck walkable; one sent up walks
## the treads onto the deck (6 m up) and comes down again.
func _check_pedestrians(scene: Node) -> void:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	for frame_index in 300:
		await physics_frame
		if not walkers.people().is_empty():
			break
	var routes: Array = walkers._stair_routes.keys()
	print("traproutes: ", routes)
	_check(routes.size() == 4, "op en af aan beide kanten van de brug (%d routes)" % routes.size())
	var deck_cells := 0
	for column: Vector2i in walkers._decks:
		deck_cells += 1
	_check(deck_cells >= 10, "het brugdek is beloopbaar (%d cellen)" % deck_cells)
	if routes.is_empty() or walkers.people().is_empty():
		return
	var up: Array = []
	for route: Array in routes:
		if not walkers.is_deck(route[0]) and walkers.is_deck(route[1]):
			up = route
	# the player near the bridge (who is far from it, becomes someone else elsewhere)
	var player: Node3D = scene.get_node("Speler")
	player.global_position = walkers.cell_middle(up[0]) + Vector3(-12.0, 0.0, 6.0)
	player.set_physics_process(false)
	var person: Pedestrian = walkers.people()[0]
	person.restart_at(up[0])
	person.cell = up[0]
	person._pause = 0.0
	_check(person._head_for(up[1]), "een voetganger gaat de trap op")
	var highest := 0.0
	for frame_index in 60 * 40:
		await physics_frame
		person._pause = 0.0
		highest = maxf(highest, person.global_position.y)
		if person.cell == up[1]:
			break
	print("voetganger: cel %s, hoogte %.2f (hoogst %.2f)" % [person.cell, person.global_position.y, highest])
	_check(person.cell == up[1] and person.global_position.y > DECK_HEIGHT - 0.3, "en staat op de brug (%.2f m)" % person.global_position.y)
	person._pause = 0.0
	_check(person._head_for(up[0]), "en gaat weer naar beneden")
	for frame_index in 60 * 40:
		await physics_frame
		person._pause = 0.0
		if person.cell == up[0]:
			break
	_check(person.cell == up[0] and person.global_position.y < 1.0, "en staat weer op de stoep (%.2f m)" % person.global_position.y)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
