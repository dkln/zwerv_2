extends RefCounted
## Unit tests of the layouts of the snack bars (scripts/world/snack_bar_layout.gd) and of the
## one interior building itself from them (scripts/world/interior.gd dress): every snack bar
## its own room, the same one every time for the same place.

const SnackBarLayout = preload("res://scripts/world/snack_bar_layout.gd")
const SCENE := "res://scenes/binnen/snackbar.tscn"
const LIBRARY := "res://assets/libraries/binnen.res"

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Many seeds: rooms of different sizes, doors, counters and numbers of tables; the same
## seed always the same room; every tile it names is in the library.
func test_every_snack_bar_its_own_room(test) -> void:
	var library: MeshLibrary = load(LIBRARY)
	var kinds := {}
	var sizes := {}
	var missing := {}
	var without_table := 0
	var odd_seats := 0
	var door_off_front := 0
	for seed in 120:
		var plan := SnackBarLayout.plan(seed)
		var door: Transform3D = plan.door
		var keeper: Transform3D = plan.keeper
		sizes["%dx%d" % [int(plan.width), int(plan.depth)]] = true
		kinds["%dx%d deur %.0f toonbank %.0f tafels %d" % [int(plan.width), int(plan.depth), door.origin.x, keeper.origin.x, plan.seats.size() / 2]] = true
		if plan.seats.is_empty():
			without_table += 1
		if plan.seats.size() % 2 != 0:
			odd_seats += 1
		if absf(door.origin.z - (-float(plan.depth) * 0.5 + SnackBarLayout.DOOR_INSIDE)) > 0.01 or absf(door.origin.x) > float(plan.width) * 0.5:
			door_off_front += 1
		for entry: Array in plan.tiles:
			var tile_name := "snackbar/" + String(entry[0]) + ("_zwartwit" if bool(entry[3]) else "")
			if library.find_item_by_name(tile_name) < 0:
				missing[tile_name] = true
	test.check(sizes.size() >= 5, "kamers van verschillende grootte (%s)" % str(sizes.keys()))
	test.check(kinds.size() >= 40, "veel verschillende indelingen (%d van 120)" % kinds.size())
	test.check(missing.is_empty(), "elke tile bestaat in de bibliotheek (%s)" % str(missing.keys()))
	test.check(without_table == 0 and odd_seats == 0, "overal minstens één tafel, met twee stoelen")
	test.check(door_off_front == 0, "de deur zit in de voorwand")
	test.check(SnackBarLayout.plan(77).hash() == SnackBarLayout.plan(77).hash(), "dezelfde zaak: dezelfde kamer")


## The interior builds the room of its seed: the floor as big as the plan, the door and the
## keeper where the plan says, a guest at a seat, and from the door you can walk to the
## counter over the free floor.
func test_the_interior_builds_its_room(test) -> void:
	var first_cells := -1
	var differs := false
	for seed: int in [3, 11, 42]:
		var room: Node3D = (load(SCENE) as PackedScene).instantiate()
		tree.root.add_child(room)
		room.dress("Proef", seed)
		var plan: Dictionary = room.layout
		var floor_cells := (room.get_node("Vloer") as GridMap).get_used_cells().size()
		test.check(floor_cells == roundi(float(plan.width) / 4.0) * roundi(float(plan.depth) / 4.0),
			"zaak %d: de vloer van %d x %d m" % [seed, int(plan.width), int(plan.depth)])
		test.check(room.door().origin.is_equal_approx(room.to_global((plan.door as Transform3D).origin)), "zaak %d: de deur waar de indeling hem zet" % seed)
		var keepers: Array = room.people().filter(func(person: InteriorPerson) -> bool: return person.role == "snackbarhouder")
		test.check(keepers.size() == 1 and (keepers[0] as Node3D).position.is_equal_approx((plan.keeper as Transform3D).origin), "zaak %d: de snackbarhouder achter de toonbank" % seed)
		var before_counter: Vector3 = room.to_global((plan.keeper as Transform3D).origin + Vector3(0.5, 0.0, -2.2))
		var path: PackedVector3Array = room.floor_path(room.door().origin, before_counter)
		test.check(path.size() >= 2, "zaak %d: van de deur naar de toonbank lopen (%d punten)" % [seed, path.size()])
		if first_cells < 0:
			first_cells = hash([floor_cells, (plan.door as Transform3D).origin, (plan.keeper as Transform3D).origin, plan.seats.size()])
		elif first_cells != hash([floor_cells, (plan.door as Transform3D).origin, (plan.keeper as Transform3D).origin, plan.seats.size()]):
			differs = true
		room.free()
	test.check(differs, "de drie zaken zijn niet dezelfde kamer")
