extends SceneTree
## Tests the lanes chosen per placed tile (RoadNetwork.LANE_CHOICES): every combination of
## sides on a crossing and on a lane tile, turning with the cell, a choice for another
## tile, keeping choices when the city is built again, the road users per tile, the speed
## limit per tile, and vehicles obeying a choice.
## usage: Godot --headless --script tools/check/lane_choice_test.gd

const Common = preload("res://tools/tool_common.gd")
const CityBase = preload("res://tools/build/city/base.gd")
const SIDES := ["N", "E", "S", "W"]
const DRIVE_SECONDS := 40.0
## The stretch of motorway that gets a low limit: cells from the start, length, km/h.
const SLOW_FROM := 16
const SLOW_CELLS := 6
const SLOW_KMH := 30

var failures := 0


func _init() -> void:
	Common.watchdog(self, 200)
	var scene := Common.instantiate("res://scenes/stad.tscn")
	var ground: GridMap = scene.get_node("Grond")
	var network := RoadNetwork.new(ground)
	var crossing := _first_cell(network, ground, "weg/kruising_vlak")
	var lane := _first_cell(network, ground, "weg/rijstrook_")
	_test_every_combination(ground, crossing)
	_test_every_combination(ground, lane)
	_test_turning(ground, crossing)
	_test_other_tile(ground, crossing)
	_test_no_choices_changes_nothing(ground, network)
	_test_keep_on_rebuild(scene, crossing)
	_test_kinds(ground, lane)
	_test_tile_defaults(ground, network)
	_test_speed(ground, lane)
	ground.remove_meta(RoadNetwork.LANE_CHOICES)
	await _test_vehicle(scene)
	print("KLAAR: %d fouten" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FOUT  ") + what)
	if not ok:
		failures += 1


func _first_cell(network: RoadNetwork, ground: GridMap, name_start: String) -> Vector3i:
	for cell: Vector3i in network.cells():
		if network.tile_name(cell).begins_with(name_start) and cell.y == 0 \
				and ground.get_cell_item_orientation(cell) == 0:
			return cell
	push_error("no tile " + name_start)
	quit(1)
	return RoadNetwork.NONE


func _choose(ground: GridMap, cell: Vector3i, sides: Array) -> void:
	var tile := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "lanes": sides}})


## All 15 combinations give exactly those headings, also next to a two-way neighbour.
func _test_every_combination(ground: GridMap, cell: Vector3i) -> void:
	var correct := 0
	for combination in range(1, 1 << SIDES.size()):
		var sides := []
		for side_index in SIDES.size():
			if combination & (1 << side_index):
				sides.append(SIDES[side_index])
		_choose(ground, cell, sides)
		var network := RoadNetwork.new(ground)
		var expected := sides.map(func(side: String) -> Vector2i: return network.heading_of_side(cell, side))
		var actual := network.lanes(cell)
		if actual.size() == expected.size() and expected.all(func(heading: Vector2i) -> bool: return heading in actual) \
				and network.is_chosen(cell):
			correct += 1
		else:
			print("  %s: %s geeft %s" % [cell, sides, actual])
	var tile := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
	_check(correct == 15, "alle 15 combinaties op %s (%d goed)" % [tile, correct])


func _test_turning(ground: GridMap, cell: Vector3i) -> void:
	var item := ground.get_cell_item(cell)
	var orientation := ground.get_cell_item_orientation(cell)
	_choose(ground, cell, ["N"])
	var before := RoadNetwork.new(ground).lanes(cell)
	var quarter_turn := ground.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2.0))
	ground.set_cell_item(cell, item, quarter_turn)
	var after := RoadNetwork.new(ground).lanes(cell)
	ground.set_cell_item(cell, item, orientation)
	_check(before == [Vector2i(0, -1)] and after == [Vector2i(-1, 0)], "keuze draait mee: %s -> %s" % [before, after])


func _test_other_tile(ground: GridMap, cell: Vector3i) -> void:
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": "weg/een_andere_tile", "lanes": ["N"]}})
	_check(not RoadNetwork.new(ground).is_chosen(cell), "keuze telt niet voor een andere tile")


func _test_no_choices_changes_nothing(ground: GridMap, original: RoadNetwork) -> void:
	ground.remove_meta(RoadNetwork.LANE_CHOICES)
	var again := RoadNetwork.new(ground)
	var same := original.cells().size() == again.cells().size()
	for cell: Vector3i in original.cells():
		same = same and original.lanes(cell) == again.lanes(cell)
	_check(same, "zonder keuzes hetzelfde wegennet (%d cellen)" % again.cells().size())


func _test_keep_on_rebuild(scene: Node, cell: Vector3i) -> void:
	var path := "user://lane_choice_test.tscn"
	var ground: GridMap = scene.get_node("Grond")
	var old_root := Node3D.new()
	var old_ground := GridMap.new()
	old_ground.name = "Grond"
	old_ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": "weg/kruising_vlak", "lanes": ["W"]}})
	old_root.add_child(old_ground)
	old_ground.owner = old_root
	var packed := PackedScene.new()
	packed.pack(old_root)
	ResourceSaver.save(packed, path)
	old_root.free()
	var new_root := Node3D.new()
	var new_ground := GridMap.new()
	new_ground.name = "Grond"
	new_root.add_child(new_ground)
	CityBase.keep_lane_choices(new_root, path)
	var kept: Dictionary = new_ground.get_meta(RoadNetwork.LANE_CHOICES, {})
	_check(kept.has(cell) and kept[cell].lanes == ["W"], "keuze blijft bewaard bij opnieuw bouwen")
	new_root.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ground.set_meta(RoadNetwork.LANE_CHOICES, {})


func _test_kinds(ground: GridMap, cell: Vector3i) -> void:
	var tile := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
	var default_network := RoadNetwork.new(ground)
	var default_lanes := default_network.lanes(cell)
	var everyone_allowed := default_network.allows(cell, "auto") and default_network.allows(cell, "fiets")
	_check(everyone_allowed and not default_network.has_chosen_kinds(cell), "zonder keuze mogen auto en fiets op %s" % tile)
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "kinds": ["brommer", "fiets"]}})
	var network := RoadNetwork.new(ground)
	_check(network.allows(cell, "brommer") and network.allows(cell, "fiets") and not network.allows(cell, "auto") \
			and not network.allows(cell, "bus") and not network.allows(cell, "voetganger") and network.has_chosen_kinds(cell), "alleen brommer en fiets")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "kinds": ["auto"]}})
	_check(RoadNetwork.new(ground).allows(cell, "bus"), "auto laat ook de bus toe")
	_check(network.lanes(cell) == default_lanes and not network.is_chosen(cell), "soorten laten de richtingen met rust")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "kinds": []}})
	network = RoadNetwork.new(ground)
	_check(not network.allows(cell, "auto") and not network.allows(cell, "bus") and network.has(cell), "alles uit sluit de tile af")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": "weg/een_andere_tile", "kinds": []}})
	_check(RoadNetwork.new(ground).allows(cell, "auto"), "soorten tellen niet voor een andere tile")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {})


## What the tiles say themselves, per kind of ground.
func _test_tile_defaults(ground: GridMap, network: RoadNetwork) -> void:
	var expected := {
		"stoep/stoep_vol": ["voetganger"],
		"fietspad/fietspad_recht": ["fiets", "brommer"],
		"plein/plein_tegels": ["voetganger", "fiets"],
		"snelweg/snelweg_rijstrook": ["auto"],
		"weg/zebrapad": ["auto", "brommer", "fiets", "voetganger"],
		"weg/rijstrook_geen_kant": ["auto", "brommer", "fiets"],
		"water/water": [],
	}
	var found := {}
	for cell: Vector3i in network.ground_cells():
		var tile := network.tile_name(cell)
		if expected.has(tile) and not found.has(tile):
			found[tile] = network.allowed_kinds(cell)
	for tile in expected:
		var allowed: Array = found.get(tile, ["niet gevonden"])
		_check(allowed.size() == expected[tile].size() and expected[tile].all(func(kind: String) -> bool: return kind in allowed),
				"%s: %s" % [tile, allowed])


func _test_speed(ground: GridMap, cell: Vector3i) -> void:
	var tile := ground.mesh_library.get_item_name(ground.get_cell_item(cell))
	var default_limit := RoadNetwork.new(ground).speed_limit_kmh(cell)
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "speed": 70}})
	var network := RoadNetwork.new(ground)
	_check(network.speed_limit_kmh(cell) == 70.0 and network.has_chosen_speed(cell) and is_equal_approx(network.speed_limit(cell), 70.0 / 3.6),
			"gekozen limiet telt: %s km/u (was %s)" % [network.speed_limit_kmh(cell), default_limit])
	_check(not network.is_chosen(cell) and not network.has_chosen_kinds(cell), "limiet laat richtingen en soorten met rust")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": "weg/een_andere_tile", "speed": 70}})
	_check(RoadNetwork.new(ground).speed_limit_kmh(cell) == default_limit, "limiet telt niet voor een andere tile")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {})
	# a stop line has no limit of its own: it takes the one of the lane leading to it
	var plain := RoadNetwork.new(ground)
	var stop_line := RoadNetwork.NONE
	for candidate: Vector3i in plain.cells():
		if plain.tile_name(candidate) != "weg/rijstrook_stopstreep":
			continue
		var behind := plain.step(candidate, -plain.lanes(candidate)[0])
		if behind != RoadNetwork.NONE and not plain.tile_name(behind).contains("stop"):
			stop_line = candidate
			ground.set_meta(RoadNetwork.LANE_CHOICES, {behind: {"tile": plain.tile_name(behind), "speed": 70}})
			break
	var passed_on := RoadNetwork.new(ground)
	_check(stop_line != RoadNetwork.NONE and passed_on.speed_limit_kmh(stop_line) == 70.0 and not passed_on.has_chosen_speed(stop_line),
			"stopstreep neemt de gekozen limiet van de rijstrook over")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {})


## Places on the map where a lane runs into a crossing cell with a way straight on and a
## way to the side: [{approach, crossing, heading, exit}].
func _turns(network: RoadNetwork) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for cell: Vector3i in network.cells():
		if cell.y != 0 or network.lanes(cell).size() != 1 or network.is_zebra(cell):
			continue
		var heading: Vector2i = network.lanes(cell)[0]
		var ahead := network.step(cell, heading)
		if ahead == RoadNetwork.NONE or not network.is_crossing(ahead) or network.step(cell, -heading) == RoadNetwork.NONE:
			continue
		if not network.lanes(ahead).has(heading) or network.step(ahead, heading) == RoadNetwork.NONE:
			continue
		for option in network.lanes(ahead):
			if option != heading and option != -heading and network.step(ahead, option) != RoadNetwork.NONE:
				found.append({"approach": cell, "crossing": ahead, "heading": heading, "exit": option})
				break
	return found


## A hatchback driving towards a crossing cell whose only way out is one turn leaves it
## that way, though it could otherwise also go straight on. Another, far away, never drives
## onto the cell beside a crossing that is closed to cars. A third slows down to the limit
## chosen for a stretch of the motorway.
func _test_vehicle(scene: Node) -> void:
	var ground: GridMap = scene.get_node("Grond")
	var network := RoadNetwork.new(ground)
	var turns := _turns(network)
	if turns.is_empty():
		_check(false, "geen kruising gevonden om te rijden")
		return
	var turning: Dictionary = turns[0]
	var avoiding: Dictionary = turns.filter(func(turn: Dictionary) -> bool:
		return absi(turn.crossing.x - turning.crossing.x) + absi(turn.crossing.z - turning.crossing.z) > 30).front()
	var exit_side := ""
	for side in SIDES:
		if network.heading_of_side(turning.crossing, side) == turning.exit:
			exit_side = side
	var closed := network.step(avoiding.crossing, avoiding.exit)
	var library := ground.mesh_library
	var choices := {
		turning.crossing: {"tile": library.get_item_name(ground.get_cell_item(turning.crossing)), "lanes": [exit_side]},
		closed: {"tile": library.get_item_name(ground.get_cell_item(closed)), "kinds": ["fiets"]},
	}
	var slow_start := _motorway_start(network)
	var slow_stretch: Array[Vector3i] = []
	var motorway_heading: Vector2i = network.lanes(slow_start)[0]
	var along := slow_start
	for step_index in SLOW_FROM + SLOW_CELLS:
		along = network.step(along, motorway_heading)
		if step_index >= SLOW_FROM:
			slow_stretch.append(along)
			choices[along] = {"tile": library.get_item_name(ground.get_cell_item(along)), "speed": SLOW_KMH}
	ground.set_meta(RoadNetwork.LANE_CHOICES, choices)
	for node_name in ["DetailNiveau", "Rook", "Volgcamera", "Verkeerslichten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	var turning_car := _hatchback(turning)
	var avoiding_car := _hatchback(avoiding)
	var motorway_car := _hatchback({"approach": slow_start, "heading": motorway_heading})
	get_root().add_child(scene)
	await process_frame
	await process_frame
	scene.get_node("Auto").queue_free()
	scene.get_node("SUV").queue_free()
	scene.add_child(turning_car)
	scene.add_child(avoiding_car)
	scene.add_child(motorway_car)
	var elapsed := 0.0
	var fastest_before := 0.0
	var fastest_in_stretch := 0.0
	var stretch_middle := slow_stretch[SLOW_CELLS / 2]
	var motorway_along := Vector2(motorway_heading)
	var middle_at := Vector2(stretch_middle.x + 0.5, stretch_middle.z + 0.5) * RoadNetwork.CELL
	var end_at := Vector2(slow_stretch[-1].x + 0.5, slow_stretch[-1].z + 0.5) * RoadNetwork.CELL
	var passed_stretch := false
	var turning_headings := {}
	var avoiding_headings := {}
	var drove_on_closed := false
	while elapsed < DRIVE_SECONDS and (turning_headings.is_empty() or avoiding_headings.is_empty() or not passed_stretch):
		await physics_frame
		elapsed += 1.0 / 60.0
		var motorway_at := Vector2(motorway_car.global_position.x, motorway_car.global_position.z)
		var to_middle := (middle_at - motorway_at).dot(motorway_along)
		if to_middle > RoadNetwork.CELL * (SLOW_CELLS / 2 + 1):
			fastest_before = maxf(fastest_before, motorway_car.speed)
		elif to_middle <= 0.0 and (end_at - motorway_at).dot(motorway_along) > 0.0:
			fastest_in_stretch = maxf(fastest_in_stretch, motorway_car.speed)
		passed_stretch = passed_stretch or (end_at - motorway_at).dot(motorway_along) < 0.0
		_note_headings(turning_car, turning.crossing, turning_headings)
		_note_headings(avoiding_car, avoiding.crossing, avoiding_headings)
		drove_on_closed = drove_on_closed or closed in avoiding_car._route_cells
	_check(turning_headings.keys() == [turning.exit],
			"auto verlaat kruising %s via %s (kreeg %s)" % [turning.crossing, turning.exit, turning_headings.keys()])
	_check(not avoiding_headings.is_empty() and not avoiding.exit in avoiding_headings and not drove_on_closed,
			"auto rijdt niet op afgesloten cel %s (bij kruising %s: %s)" % [closed, avoiding.crossing, avoiding_headings.keys()])
	_check(passed_stretch and fastest_before * 3.6 > SLOW_KMH * 1.5 and fastest_in_stretch * 3.6 <= SLOW_KMH * 1.05,
			"auto op de snelweg: %.0f km/u ervoor, %.0f km/u op het stuk met limiet %d" % [fastest_before * 3.6, fastest_in_stretch * 3.6, SLOW_KMH])


## A motorway cell at street level with enough straight road ahead for the slow stretch.
func _motorway_start(network: RoadNetwork) -> Vector3i:
	for cell: Vector3i in network.cells():
		if network.kind(cell) != RoadNetwork.Kind.MOTORWAY or network.lanes(cell).size() != 1:
			continue
		var heading: Vector2i = network.lanes(cell)[0]
		var along := cell
		var straight := 0
		while straight < SLOW_FROM + SLOW_CELLS:
			along = network.step(along, heading)
			if along == RoadNetwork.NONE or not network.lanes(along).has(heading):
				break
			straight += 1
		if straight == SLOW_FROM + SLOW_CELLS:
			return cell
	push_error("no straight motorway")
	quit(1)
	return RoadNetwork.NONE


func _hatchback(start: Dictionary) -> Vehicle:
	var car: Vehicle = load("res://scripts/vehicles/hatchback.gd").new()
	car.start_cell = Vector2i(start.approach.x, start.approach.z)
	car.start_heading = start.heading
	return car


func _note_headings(car: Vehicle, crossing: Vector3i, headings: Dictionary) -> void:
	for index in car._route_cells.size():
		if car._route_cells[index] == crossing:
			headings[car._route_headings[index]] = true
