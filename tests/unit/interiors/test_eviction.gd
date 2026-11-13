extends RefCounted
## Unit tests of being put out of an interior: the rules of a chase (scripts/world/interiors/pursuit.gd,
## shared by the conductor of the station and whoever puts the player out), the eviction
## itself (scripts/world/interiors/eviction.gd: who comes, after the player, caught only once at them,
## put back after), the walk of the base interior over its free floor round a counter
## (scripts/world/interiors/interior.gd floor_path, walk_evictor, evictor_done) and Interiors making
## the player unwelcome instead of throwing them out at once (scripts/world/interiors/interiors.gd).
## The interior, the player and the HUD are stand-ins; the nodes go into the test's tree.

const Pursuit = preload("res://scripts/world/interiors/pursuit.gd")
const Eviction = preload("res://scripts/world/interiors/eviction.gd")
const Interior = preload("res://scripts/world/interiors/interior.gd")
const Interiors = preload("res://scripts/world/interiors/interiors.gd")


## An interior that says who comes and walks them straight at the player.
class TestInterior:
	extends Node3D
	var evictor: Node3D
	var asked := 0
	var walked := 0.0
	var stopped: Array[Node3D] = []
	var done: Array[Node3D] = []
	var held := false

	func evictor_for(_role: String, _player: Node3D) -> Node3D:
		asked += 1
		return evictor

	func warner_for(_role: String, _player: Node3D) -> Node3D:
		return evictor

	func leave_offence() -> String:
		return String(get_meta("leave", ""))

	func way_back_in() -> Transform3D:
		return Transform3D(Basis(), Vector3(0.0, 0.0, 3.0))

	func walk_evictor(person: Node3D, target: Vector3, speed: float, delta: float) -> float:
		var offset := target - person.global_position
		offset.y = 0.0
		var step := minf(speed * delta, offset.length())
		if step > 0.0:
			person.global_position += offset.normalized() * step
		walked += step
		return step

	func evictor_stops(person: Node3D) -> void:
		stopped.append(person)

	func evictor_done(person: Node3D) -> void:
		done.append(person)

	func evicting_held() -> bool:
		return held


## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _tree_root() -> Node:
	return tree.root


func _at(position: Vector3) -> Node3D:
	var node := Node3D.new()
	_tree_root().add_child(node)
	node.global_position = position
	return node


func _rules() -> Dictionary:
	return {"uitzetter": {"wie": "snackbarhouder", "kreten": ["Eruit!"]},
		"overtredingen": {"bedelen": {"na": 3, "roep": ["Hé jij!"]}}}


## A pursuit catches only when the chaser is within reach on the same level: not from
## far off, not from a floor above.
func test_a_pursuit_catches_only_up_close(test) -> void:
	var chaser := _at(Vector3(5.0, 0.0, 0.0))
	var pursuit := Pursuit.new(chaser, 1.0)
	test.check(pursuit.update(0.1, Vector3.ZERO) == "", "ver weg: nog niet gepakt")
	chaser.global_position = Vector3(0.8, 0.0, 0.0)
	test.check(pursuit.update(0.1, Vector3.ZERO) == Pursuit.CAUGHT, "binnen bereik: gepakt")
	chaser.global_position = Vector3(0.5, 1.5, 0.0)
	test.check(pursuit.update(0.1, Vector3.ZERO) == "", "boven je (perron, spoor): niet gepakt")
	chaser.free()


## A pursuit without limits never gives up; with a give-up distance and time, or a longest
## time, it does, and also when the chaser is gone.
func test_a_pursuit_gives_up_only_when_it_may(test) -> void:
	var chaser := _at(Vector3(30.0, 0.0, 0.0))
	var never := Pursuit.new(chaser, 1.0)
	var given_up := false
	for second in 120:
		given_up = given_up or never.update(1.0, Vector3.ZERO) == Pursuit.GAVE_UP
	test.check(not given_up, "zonder grens (uitzetten) geeft hij het nooit op")
	var conductor := Pursuit.new(chaser, 1.0)
	conductor.give_up_distance = 15.0
	conductor.give_up_seconds = 3.0
	test.check(conductor.update(2.0, Vector3.ZERO) == "", "even te ver: nog niet")
	test.check(conductor.update(2.0, Vector3.ZERO) == Pursuit.GAVE_UP, "te lang te ver: opgegeven")
	var timed := Pursuit.new(chaser, 1.0)
	timed.longest = 5.0
	test.check(timed.update(6.0, Vector3.ZERO) == Pursuit.GAVE_UP, "na de langste tijd: opgegeven")
	chaser.free()
	test.check(never.update(0.1, Vector3.ZERO) == Pursuit.GAVE_UP, "achtervolger weg: opgegeven")


## The one the house names comes for the player, shouting the offence's line, walks up to
## them and catches only once there; then stands still and goes back to their place after.
func test_the_evictor_comes_and_catches_only_at_the_player(test) -> void:
	var interior := TestInterior.new()
	_tree_root().add_child(interior)
	interior.evictor = _at(Vector3(6.0, 0.0, 0.0))
	var player := _at(Vector3.ZERO)
	var eviction := Eviction.new()
	interior.add_child(eviction)
	var caught := [0]
	eviction.caught.connect(func() -> void: caught[0] += 1)
	eviction.start(interior, "bedelen", _rules(), player, null)
	eviction._process(0.1)
	test.check(interior.asked == 1 and eviction.person == interior.evictor, "wie het huis zegt, komt eraan")
	test.check(eviction._shout_lines == ["Hé jij!"], "die roept de 'roep' van de overtreding")
	test.check(caught[0] == 0, "nog ver weg: niet gepakt")
	var frames := 0
	while caught[0] == 0 and frames < 200:
		eviction._process(0.05)
		frames += 1
	var gap := Vector2(interior.evictor.global_position.x, interior.evictor.global_position.z).length()
	test.check(caught[0] == 1 and gap <= Eviction.CATCH_REACH + 0.01, "pas bij je: gepakt (%.2f m)" % gap)
	test.check(interior.walked > 4.0, "hij liep ernaartoe (%.1f m)" % interior.walked)
	test.check(interior.stopped == [interior.evictor], "gepakt: hij blijft staan")
	test.check(eviction.is_done(), "klaar")
	eviction.end()
	test.check(interior.done == [interior.evictor], "daarna terug naar zijn plek")
	interior.free()
	player.free()


## While the interior holds everything (the lift moving) nobody is asked or walks; someone
## already standing at the player (the conductor) catches at once.
func test_the_evictor_waits_while_held_and_one_already_there_catches_at_once(test) -> void:
	var interior := TestInterior.new()
	_tree_root().add_child(interior)
	interior.evictor = _at(Vector3(6.0, 0.0, 0.0))
	interior.held = true
	var player := _at(Vector3.ZERO)
	var eviction := Eviction.new()
	interior.add_child(eviction)
	eviction.start(interior, "bedelen", _rules(), player, null)
	for frame in 20:
		eviction._process(0.1)
	test.check(interior.asked == 0 and interior.walked == 0.0, "de lift rijdt: alles wacht")
	var conductor := _at(Vector3(0.5, 0.0, 0.0))
	var at_once := Eviction.new()
	interior.add_child(at_once)
	var caught := [false]
	at_once.caught.connect(func() -> void: caught[0] = true)
	at_once.start(interior, "boete_onbetaald", _rules(), player, null, conductor)
	test.check(caught[0] and at_once.person == conductor, "staat er al bij (de conducteur): meteen gepakt")
	interior.free()
	player.free()
	conductor.free()


## When the evictor goes out of sight (another floor) they are sent back and another one
## comes instead.
func test_another_evictor_when_the_first_is_out_of_sight(test) -> void:
	var interior := TestInterior.new()
	_tree_root().add_child(interior)
	var first := _at(Vector3(8.0, 0.0, 0.0))
	interior.evictor = first
	var player := _at(Vector3.ZERO)
	var eviction := Eviction.new()
	interior.add_child(eviction)
	eviction.start(interior, "bedelen", _rules(), player, null)
	eviction._process(0.1)
	first.visible = false   # another floor
	var second := _at(Vector3(4.0, 0.0, 0.0))
	interior.evictor = second
	eviction._process(0.1)
	test.check(interior.done.has(first) and eviction.person == second, "uit beeld: terug, een ander komt")
	interior.free()
	player.free()
	first.free()
	second.free()


## A room of 6 x 6 m (floor tiles of 2 m) with a counter of 4 x 1 m across the middle.
func _room() -> Node3D:
	var library := MeshLibrary.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(2.0, 0.1, 2.0)
	library.create_item(0)
	library.set_item_mesh(0, floor_mesh)
	library.set_item_mesh_transform(0, Transform3D(Basis(), Vector3(0.0, -0.05, 0.0)))
	var counter_mesh := BoxMesh.new()
	counter_mesh.size = Vector3(4.0, 1.0, 1.0)
	library.create_item(1)
	library.set_item_mesh(1, counter_mesh)
	library.set_item_mesh_transform(1, Transform3D(Basis(), Vector3(0.0, 0.5, 0.0)))
	var room := Node3D.new()
	room.set_script(Interior)
	var floor_grid := GridMap.new()
	floor_grid.name = "Vloer"
	floor_grid.mesh_library = library
	floor_grid.cell_size = Vector3(2.0, 1.0, 2.0)
	for column in range(-2, 1):
		for row in range(-2, 1):
			floor_grid.set_cell_item(Vector3i(column, 0, row), 0)
	room.add_child(floor_grid)
	var furniture := GridMap.new()
	furniture.name = "Inrichting"
	furniture.mesh_library = library
	furniture.cell_size = Vector3(2.0, 1.0, 2.0)
	furniture.set_cell_item(Vector3i(-1, 0, -1), 1)   # middle at (-1, 0.5, -1): x -3..1
	room.add_child(furniture)
	_tree_root().add_child(room)
	return room


## Interior.floor_path leads round the counter, not through it, and ends at the player.
func test_the_floor_path_goes_round_the_counter(test) -> void:
	var room := _room()
	var from := Vector3(-2.0, 0.0, 0.4)    # behind the counter
	var to := Vector3(-2.0, 0.0, -2.4)     # before it
	var path: PackedVector3Array = room.call("floor_path", from, to)
	var through := false
	var round_it := false
	for point in path:
		if point.x > -3.0 and point.x < 1.0 and absf(point.z + 1.0) < 0.5:
			through = true
		if point.x >= 1.0 or point.x <= -3.0:
			round_it = true   # past one end of it
	test.check(path.size() > 2 and not through and round_it, "om de toonbank heen, niet erdoorheen (%d punten)" % path.size())
	test.check(path[path.size() - 1].is_equal_approx(to), "eindigt bij de speler")
	room.free()


## The base Interior gives the keeper as evictor, makes them stand up and walk, puts them
## back as they were afterwards, and has nobody for a role that would come through a door.
func test_the_base_interior_walks_the_evictor_and_puts_them_back(test) -> void:
	var room := _room()
	var keeper := InteriorPerson.create("snackbarhouder", 3, true)
	room.add_child(keeper)
	room.get("_people").append(keeper)
	keeper.position = Vector3(-2.0, 0.0, 0.4)
	var home := keeper.transform
	var player := _at(Vector3(-2.0, 0.0, -2.4))
	test.check(room.evictor_for("snackbarhouder", player) == keeper, "de snackbarhouder zelf komt")
	var walked := 0.0
	for frame in 30:
		walked += room.walk_evictor(keeper, player.global_position, 3.6, 0.1)
	test.check(not keeper.sitting and walked > 1.0, "opgestaan en gelopen (%.1f m)" % walked)
	test.check(keeper.global_position.distance_to(home.origin) > 1.0, "niet meer achter de toonbank")
	room.evictor_done(keeper)
	test.check(keeper.transform.is_equal_approx(home) and keeper.sitting, "daarna terug op zijn plek, zoals hij was")
	var nobody: Node3D = room.evictor_for("beveiliger", player)
	test.check(nobody == null, "geen deur in deze kamer: niemand erbij te halen")
	room.free()
	player.free()


## Walking to the door with unpaid things first gives a warning and puts the player back
## in the shop; the next time someone comes for them.
func test_shoplifting_is_warned_first(test) -> void:
	var interiors := Interiors.new()
	interiors.set("_inside", {"kind": "derrek"})
	var interior := TestInterior.new()
	_tree_root().add_child(interior)
	interior.evictor = _at(Vector3(5.0, 0.0, 0.0))
	interiors.set("_interior", interior)
	interiors.set("_player", _at(Vector3.ZERO))
	interiors.offence("winkeldiefstal")
	test.check(not interiors.is_evicting() and String(interiors.last_warning.get("line", "")).contains("afrekenen"),
		"met spullen naar de deur: eerst een waarschuwing (afrekenen)")
	# at the door again: the shop says so (leave_offence), back in it (way_back_in)
	interior.set_meta("leave", "winkeldiefstal")
	(interiors.get("_player") as Node3D).global_position = Vector3(0.0, 0.0, -1.0)
	interiors.set("_offences", {})
	interiors.leave(1)
	test.check(not interiors.is_evicting() and (interiors.get("_player") as Node3D).global_position.is_equal_approx(Vector3(0.0, 0.0, 3.0)),
		"bij de waarschuwing terug de winkel in")
	interiors.offence("winkeldiefstal")
	test.check(interiors.is_evicting(), "nog eens: dan komt iemand je halen")
	interiors.call("_end_eviction")
	(interiors.get("_player") as Node).free()
	interior.evictor.free()
	interior.free()
	interiors.free()


## Begging is warned twice by the keeper; the third time someone comes (not yet thrown
## out), one eviction at a time, and it is over once the player is out of the door.
func test_an_offence_makes_the_player_unwelcome_not_thrown_out(test) -> void:
	var interiors := Interiors.new()
	interiors.set("_inside", {"kind": "snackbar"})
	var interior := TestInterior.new()
	interior.evictor = _at(Vector3(5.0, 0.0, 0.0))
	interiors.set("_interior", interior)
	interiors.set("_player", _at(Vector3.ZERO))
	_tree_root().add_child(interior)
	interiors.offence("bedelen")
	test.check(not interiors.is_evicting() and interiors.warnings_given == 1, "de eerste keer: een waarschuwing")
	test.check(interiors.last_warning.by == interior.evictor and String(interiors.last_warning.line).contains("klanten"),
		"door de snackbarhouder: %s" % interiors.last_warning.get("line", ""))
	interiors.offence("bedelen")
	test.check(not interiors.is_evicting() and interiors.warnings_given == 2 and String(interiors.last_warning.line).contains("Laatste"),
		"de tweede keer: de laatste waarschuwing")
	interiors.offence("bedelen")
	test.check(interiors.is_evicting() and not interiors.get("_throwing") and interiors.warnings_given == 2,
		"de derde keer: geen waarschuwing meer, iemand komt eraan, nog niet eruit")
	test.check(interiors.eviction().offence == "bedelen", "voor het bedelen")
	interiors.offence("geen_geld")
	test.check(interiors.eviction().offence == "bedelen", "één tegelijk: de eerste blijft staan")
	interiors.call("_end_eviction")
	test.check(not interiors.is_evicting(), "weg door de deur: voorbij")
	(interiors.get("_player") as Node).free()
	interior.evictor.free()
	interior.free()
	interiors.free()
