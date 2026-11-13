extends "res://tests/integration/support/town_test.gd"
## The lanes chosen per placed tile (RoadNetwork.LANE_CHOICES, a meta of the Grond GridMap):
## every combination of sides on a crossing and on a lane tile, turning with the cell, a
## choice for another tile, keeping choices when the city is built again, the road users
## per tile, the speed limit per tile, and vehicles obeying a choice. Every test puts its
## choices on the town's ground and takes them off again (_restore_choices).
##   tests/run_integration_tests.sh lane_choice

const CityBase = preload("res://tools/build/city/base.gd")
const TrafficHelp = preload("res://tests/integration/support/traffic_help.gd")
const SIDES := ["N", "E", "S", "W"]
const DRIVE_SECONDS := 40.0
## The stretch of motorway that gets a low limit: cells from the start, length, km/h.
const SLOW_FROM := 16
const SLOW_CELLS := 6
const SLOW_KMH := 30
const NO_CHOICES := "geen"

## The choices the town's ground had before the test (NO_CHOICES: none).
var _choices_before: Variant = NO_CHOICES


## The ground of the town, its own lane choices remembered for _restore_choices.
func _ground() -> GridMap:
	var ground: GridMap = scene.get_node("Grond")
	if ground.has_meta(RoadNetwork.LANE_CHOICES):
		_choices_before = ground.get_meta(RoadNetwork.LANE_CHOICES)
	return ground


## The ground's lane choices as they were before the test.
func _restore_choices(ground: GridMap) -> void:
	if typeof(_choices_before) == TYPE_STRING:
		ground.remove_meta(RoadNetwork.LANE_CHOICES)
	else:
		ground.set_meta(RoadNetwork.LANE_CHOICES, _choices_before)


## The first road cell at street level, not turned, whose tile's name starts with
## `name_start` (RoadNetwork.NONE if the town has none).
func _first_cell(ground: GridMap, name_start: String) -> Vector3i:
	var network := RoadNetwork.new(ground)
	for cell: Vector3i in network.cells():
		if network.tile_name(cell).begins_with(name_start) and cell.y == 0 \
				and ground.get_cell_item_orientation(cell) == 0:
			return cell
	return RoadNetwork.NONE


## The name of the tile lying on `cell`.
func _tile_at(ground: GridMap, cell: Vector3i) -> String:
	return ground.mesh_library.get_item_name(ground.get_cell_item(cell))


## The only choice on the ground: `sides` as the lanes of `cell`.
func _choose(ground: GridMap, cell: Vector3i, sides: Array) -> void:
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": _tile_at(ground, cell), "lanes": sides}})


## How many of the 15 combinations of sides chosen on `cell` give exactly those headings.
func _correct_combinations(ground: GridMap, cell: Vector3i) -> int:
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
	return correct


## All 15 combinations of sides on a crossing give exactly those headings.
func test_every_combination_on_a_crossing(test) -> void:
	var ground := _ground()
	var crossing := _first_cell(ground, "weg/kruising_vlak")
	var correct := _correct_combinations(ground, crossing)
	test.check(correct == 15, "alle 15 combinaties op %s (%d goed)" % [_tile_at(ground, crossing), correct])
	_restore_choices(ground)


## All 15 combinations of sides on a lane tile give exactly those headings, also next to a
## two-way neighbour.
func test_every_combination_on_a_lane(test) -> void:
	var ground := _ground()
	var lane := _first_cell(ground, "weg/rijstrook_")
	var correct := _correct_combinations(ground, lane)
	test.check(correct == 15, "alle 15 combinaties op %s (%d goed)" % [_tile_at(ground, lane), correct])
	_restore_choices(ground)


## A choice is in the tile's own sides: turn the cell a quarter and the lane turns with it.
func test_choice_turns_with_the_cell(test) -> void:
	var ground := _ground()
	var cell := _first_cell(ground, "weg/kruising_vlak")
	var item := ground.get_cell_item(cell)
	var orientation := ground.get_cell_item_orientation(cell)
	_choose(ground, cell, ["N"])
	var before := RoadNetwork.new(ground).lanes(cell)
	var quarter_turn := ground.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2.0))
	ground.set_cell_item(cell, item, quarter_turn)
	var after := RoadNetwork.new(ground).lanes(cell)
	ground.set_cell_item(cell, item, orientation)
	test.check(before == [Vector2i(0, -1)] and after == [Vector2i(-1, 0)], "keuze draait mee: %s -> %s" % [before, after])
	_restore_choices(ground)


## A choice made for another tile than the one lying there does not count.
func test_choice_for_another_tile_does_not_count(test) -> void:
	var ground := _ground()
	var cell := _first_cell(ground, "weg/kruising_vlak")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": "weg/een_andere_tile", "lanes": ["N"]}})
	test.check(not RoadNetwork.new(ground).is_chosen(cell), "keuze telt niet voor een andere tile")
	_restore_choices(ground)


## Choices put on and taken off again leave the road network as it was.
func test_without_choices_the_network_is_unchanged(test) -> void:
	var ground := _ground()
	var original := RoadNetwork.new(ground)
	_choose(ground, _first_cell(ground, "weg/kruising_vlak"), ["N"])
	_restore_choices(ground)
	var again := RoadNetwork.new(ground)
	var same := original.cells().size() == again.cells().size()
	for cell: Vector3i in original.cells():
		same = same and original.lanes(cell) == again.lanes(cell)
	test.check(same, "zonder keuzes hetzelfde wegennet (%d cellen)" % again.cells().size())


## Building the city again keeps the choices of the scene that was there
## (CityBase.keep_lane_choices), tried with a small scene of its own on disk.
func test_choices_are_kept_when_the_city_is_built_again(test) -> void:
	var cell := _first_cell(scene.get_node("Grond"), "weg/kruising_vlak")
	var path := "user://lane_choice_test.tscn"
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
	test.check(kept.has(cell) and kept[cell].lanes == ["W"], "keuze blijft bewaard bij opnieuw bouwen")
	new_root.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The road users chosen for a tile: only those may use it ("auto" also lets the bus on),
## none at all closes it, the lanes stay as they were, and a choice for another tile does
## not count.
func test_road_users_chosen_per_tile(test) -> void:
	var ground := _ground()
	var cell := _first_cell(ground, "weg/rijstrook_")
	var tile := _tile_at(ground, cell)
	ground.set_meta(RoadNetwork.LANE_CHOICES, {})
	var default_network := RoadNetwork.new(ground)
	var default_lanes := default_network.lanes(cell)
	var everyone_allowed := default_network.allows(cell, "auto") and default_network.allows(cell, "fiets")
	test.check(everyone_allowed and not default_network.has_chosen_kinds(cell), "zonder keuze mogen auto en fiets op %s" % tile)
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "kinds": ["brommer", "fiets"]}})
	var network := RoadNetwork.new(ground)
	test.check(network.allows(cell, "brommer") and network.allows(cell, "fiets") and not network.allows(cell, "auto") \
			and not network.allows(cell, "bus") and not network.allows(cell, "voetganger") and network.has_chosen_kinds(cell), "alleen brommer en fiets")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "kinds": ["auto"]}})
	test.check(RoadNetwork.new(ground).allows(cell, "bus"), "auto laat ook de bus toe")
	test.check(network.lanes(cell) == default_lanes and not network.is_chosen(cell), "soorten laten de richtingen met rust")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "kinds": []}})
	network = RoadNetwork.new(ground)
	test.check(not network.allows(cell, "auto") and not network.allows(cell, "bus") and network.has(cell), "alles uit sluit de tile af")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": "weg/een_andere_tile", "kinds": []}})
	test.check(RoadNetwork.new(ground).allows(cell, "auto"), "soorten tellen niet voor een andere tile")
	_restore_choices(ground)


## What the tiles say themselves about who may use them, per kind of ground.
func test_road_users_the_tiles_allow_themselves(test) -> void:
	var network := RoadNetwork.new(scene.get_node("Grond"))
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
	for tile: String in expected:
		var allowed: Array = found.get(tile, ["niet gevonden"])
		test.check(allowed.size() == expected[tile].size() and expected[tile].all(func(kind: String) -> bool: return kind in allowed),
				"%s: %s" % [tile, allowed])


## A speed limit chosen for a tile counts there (and leaves lanes and road users alone),
## not for another tile.
func test_speed_limit_chosen_per_tile(test) -> void:
	var ground := _ground()
	var cell := _first_cell(ground, "weg/rijstrook_")
	var tile := _tile_at(ground, cell)
	ground.set_meta(RoadNetwork.LANE_CHOICES, {})
	var default_limit := RoadNetwork.new(ground).speed_limit_kmh(cell)
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": tile, "speed": 70}})
	var network := RoadNetwork.new(ground)
	test.check(network.speed_limit_kmh(cell) == 70.0 and network.has_chosen_speed(cell) and is_equal_approx(network.speed_limit(cell), 70.0 / 3.6),
			"gekozen limiet telt: %s km/u (was %s)" % [network.speed_limit_kmh(cell), default_limit])
	test.check(not network.is_chosen(cell) and not network.has_chosen_kinds(cell), "limiet laat richtingen en soorten met rust")
	ground.set_meta(RoadNetwork.LANE_CHOICES, {cell: {"tile": "weg/een_andere_tile", "speed": 70}})
	test.check(RoadNetwork.new(ground).speed_limit_kmh(cell) == default_limit, "limiet telt niet voor een andere tile")
	_restore_choices(ground)


## A stop line has no limit of its own: it takes the one chosen for the lane leading to it.
func test_stop_line_takes_the_limit_of_its_lane(test) -> void:
	var ground := _ground()
	ground.set_meta(RoadNetwork.LANE_CHOICES, {})
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
	test.check(stop_line != RoadNetwork.NONE and passed_on.speed_limit_kmh(stop_line) == 70.0 and not passed_on.has_chosen_speed(stop_line),
			"stopstreep neemt de gekozen limiet van de rijstrook over")
	_restore_choices(ground)


## Places on the map where a lane for cars runs into a crossing cell (of the road) with a way straight on and a
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
		# (a car's crossing: not one of the tram's or the cycle path's)
		if not network.allows(cell, "auto") or not network.allows(ahead, "auto") or not network.tile_name(ahead).begins_with("weg/"):
			continue
		if not network.lanes(ahead).has(heading) or network.step(ahead, heading) == RoadNetwork.NONE:
			continue
		for option in network.lanes(ahead):
			if option != heading and option != -heading and network.step(ahead, option) != RoadNetwork.NONE \
					and network.allows(network.step(ahead, option), "auto"):
				found.append({"approach": cell, "crossing": ahead, "heading": heading, "exit": option})
				break
	return found


## A motorway cell at street level with enough straight road ahead for the slow stretch
## (RoadNetwork.NONE if the town has none).
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
	return RoadNetwork.NONE


## A hatchback that starts on `start_cell` heading `heading` and does not wait for traffic
## lights and steps every physics step, added to the town (it then takes the town's road network as it is now).
func _hatchback(start_cell: Vector3i, heading: Vector2i) -> Vehicle:
	var car := TrafficHelp.new_vehicle("hatchback", Vector2i(start_cell.x, start_cell.z), heading)
	car.obeys_lights = false
	camera_off()   # nothing out of sight: the car takes every step, wherever it is
	scene.add_child(car)
	return car


## Cells a car starts before the crossing it is to take: its first cells are laid straight
## ahead, so it has to plan the crossing while driving.
const RUN_UP_CELLS := 5


## The cell up to RUN_UP_CELLS back from `approach` along the lane heading `heading` (as far
## as that lane runs straight, for cars, without a crossing).
func _run_up_start(network: RoadNetwork, approach: Vector3i, heading: Vector2i) -> Vector3i:
	var start := approach
	for cell_index in RUN_UP_CELLS:
		var behind := network.step(start, -heading)
		if behind == RoadNetwork.NONE or network.is_crossing(behind) or network.lanes(behind) != [heading] or not network.allows(behind, "auto"):
			break
		start = behind
	return start


## The headings with which `car` plans to leave `crossing`, added to `headings` (as keys).
func _note_headings(car: Vehicle, crossing: Vector3i, headings: Dictionary) -> void:
	for index in car._route_cells.size():
		if car._route_cells[index] == crossing:
			headings[car._route_headings[index]] = true


## The town's road network made anew from `choices` on the ground (what the vehicles added
## after this drive by); returns the network it had, for _take_choices_off.
func _put_choices_on(ground: GridMap, choices: Dictionary) -> RoadNetwork:
	var network_before := RoadNetwork.of(scene)
	ground.set_meta(RoadNetwork.LANE_CHOICES, choices)
	RoadNetwork._networks[scene.get_instance_id()] = RoadNetwork.new(ground)
	return network_before


## The choices off the ground again and the town's road network as it was; `cars` taken away.
func _take_choices_off(ground: GridMap, network_before: RoadNetwork, cars: Array) -> void:
	for car: Vehicle in cars:
		car.queue_free()
	_restore_choices(ground)
	RoadNetwork._networks[scene.get_instance_id()] = network_before


## A hatchback driving towards a crossing cell whose only way out (chosen) is one turn
## leaves it that way, though it could otherwise also go straight on.
func test_vehicle_leaves_a_crossing_by_the_chosen_lane(test) -> void:
	var ground := _ground()
	var turns := _turns(RoadNetwork.new(ground))
	test.check(not turns.is_empty(), "een kruising gevonden om te rijden")
	if turns.is_empty():
		return
	var turning: Dictionary = turns[0]
	var network := RoadNetwork.new(ground)
	var exit_side := ""
	for side: String in SIDES:
		if network.heading_of_side(turning.crossing, side) == turning.exit:
			exit_side = side
	var network_before := _put_choices_on(ground, {turning.crossing: {"tile": _tile_at(ground, turning.crossing), "lanes": [exit_side]}})
	var car := _hatchback(_run_up_start(network, turning.approach, turning.heading), turning.heading)
	var headings := {}
	var elapsed := 0.0
	while elapsed < DRIVE_SECONDS and headings.is_empty():
		await tree.physics_frame
		elapsed += TrafficHelp.STEP
		_note_headings(car, turning.crossing, headings)
	test.check(headings.keys() == [turning.exit],
			"auto verlaat kruising %s via %s (kreeg %s)" % [turning.crossing, turning.exit, headings.keys()])
	_take_choices_off(ground, network_before, [car])


## A hatchback never drives onto the cell beside a crossing that is closed to cars (only
## bicycles chosen for it), though that was a way out.
func test_vehicle_keeps_off_a_cell_closed_to_cars(test) -> void:
	var ground := _ground()
	var network := RoadNetwork.new(ground)
	var turns := _turns(network)
	test.check(not turns.is_empty(), "een kruising gevonden om te rijden")
	if turns.is_empty():
		return
	var avoiding: Dictionary = turns[turns.size() / 2]
	var closed := network.step(avoiding.crossing, avoiding.exit)
	var network_before := _put_choices_on(ground, {closed: {"tile": _tile_at(ground, closed), "kinds": ["fiets"]}})
	var car := _hatchback(_run_up_start(network, avoiding.approach, avoiding.heading), avoiding.heading)
	var headings := {}
	var drove_on_closed := false
	var elapsed := 0.0
	while elapsed < DRIVE_SECONDS and headings.is_empty():
		await tree.physics_frame
		elapsed += TrafficHelp.STEP
		_note_headings(car, avoiding.crossing, headings)
		drove_on_closed = drove_on_closed or closed in car._route_cells
	test.check(not headings.is_empty() and not avoiding.exit in headings and not drove_on_closed,
			"auto rijdt niet op afgesloten cel %s (bij kruising %s: %s)" % [closed, avoiding.crossing, headings.keys()])
	_take_choices_off(ground, network_before, [car])


## A hatchback on the motorway slows down to the limit chosen for a stretch of it: well
## above it before, not above it on the stretch.
func test_vehicle_slows_down_to_a_chosen_limit(test) -> void:
	var ground := _ground()
	var network := RoadNetwork.new(ground)
	var slow_start := _motorway_start(network)
	test.check(slow_start != RoadNetwork.NONE, "een recht stuk snelweg gevonden")
	if slow_start == RoadNetwork.NONE:
		return
	var motorway_heading: Vector2i = network.lanes(slow_start)[0]
	var slow_stretch: Array[Vector3i] = []
	var choices := {}
	var along := slow_start
	for step_index in SLOW_FROM + SLOW_CELLS:
		along = network.step(along, motorway_heading)
		if step_index >= SLOW_FROM:
			slow_stretch.append(along)
			choices[along] = {"tile": _tile_at(ground, along), "speed": SLOW_KMH}
	var network_before := _put_choices_on(ground, choices)
	var car := _hatchback(slow_start, motorway_heading)
	var stretch_middle := slow_stretch[SLOW_CELLS / 2]
	var motorway_along := Vector2(motorway_heading)
	var middle_at := Vector2(stretch_middle.x + 0.5, stretch_middle.z + 0.5) * RoadNetwork.CELL
	var end_at := Vector2(slow_stretch[-1].x + 0.5, slow_stretch[-1].z + 0.5) * RoadNetwork.CELL
	var fastest_before := 0.0
	var fastest_in_stretch := 0.0
	var passed_stretch := false
	var elapsed := 0.0
	while elapsed < DRIVE_SECONDS and not passed_stretch:
		await tree.physics_frame
		elapsed += TrafficHelp.STEP
		var car_at := Vector2(car.global_position.x, car.global_position.z)
		var to_middle := (middle_at - car_at).dot(motorway_along)
		if to_middle > RoadNetwork.CELL * (SLOW_CELLS / 2 + 1):
			fastest_before = maxf(fastest_before, car.speed)
		elif to_middle <= 0.0 and (end_at - car_at).dot(motorway_along) > 0.0:
			fastest_in_stretch = maxf(fastest_in_stretch, car.speed)
		passed_stretch = (end_at - car_at).dot(motorway_along) < 0.0
	test.check(passed_stretch and fastest_before * 3.6 > SLOW_KMH * 1.5 and fastest_in_stretch * 3.6 <= SLOW_KMH * 1.05,
			"auto op de snelweg: %.0f km/u ervoor, %.0f km/u op het stuk met limiet %d" % [fastest_before * 3.6, fastest_in_stretch * 3.6, SLOW_KMH])
	_take_choices_off(ground, network_before, [car])
