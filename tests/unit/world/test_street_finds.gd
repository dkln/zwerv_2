extends RefCounted
## Unit tests of the finds of the streets without a town (scripts/world/things/street_finds.gd,
## through the loose change that extends it): the candidate cells round the start, laying
## them out once the story allows it, walking over one, and one that cannot be taken.
##   tests/run_unit_tests.sh street_finds

const StreetFinds = preload("res://scripts/world/things/street_finds.gd")
const LooseChange = preload("res://scripts/world/things/loose_change.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Someone who walks over finds: counts the money they get.
class Walker extends Node3D:
	var money := 0.0
	var _hud: Node = null
	var _placed := true
	var asleep := false

	func add_money(amount: float) -> void:
		money += amount

	func is_asleep() -> bool:
		return asleep

	func is_dead() -> bool:
		return false


## A kind of find that cannot be taken (full pockets), and counts how often it was tried.
class Stubborn extends "res://scripts/world/things/street_finds.gd":
	var tries := 0

	func _make_find(at: Vector3) -> Node3D:
		var find := Node3D.new()
		add_child(find)
		find.global_position = at
		return find

	func _take(_find: Node3D) -> bool:
		tries += 1
		return false


## A little town: a row of ground cells (4 m) from x = 0 to 19, squares but for a road at
## cell 5 and a building over cell 6.
func _town(finds: Node3D) -> Node3D:
	var library := MeshLibrary.new()
	for tile_name: String in ["plein/klinkers", "weg/asfalt", "gebouw/huis"]:
		var item := library.get_item_list().size()
		library.create_item(item)
		library.set_item_name(item, tile_name)
	var town := Node3D.new()
	var ground := GridMap.new()
	ground.name = "Grond"
	var buildings := GridMap.new()
	buildings.name = "Gebouwen"
	for grid_map: GridMap in [ground, buildings]:
		grid_map.mesh_library = library
		grid_map.cell_size = Vector3(4.0, 4.0, 4.0)
		town.add_child(grid_map)
	for column in 20:
		ground.set_cell_item(Vector3i(column, 0, 0), 1 if column == 5 else 0)
	ground.set_cell_item(Vector3i(3, 1, 0), 0)   # not on the ground floor: never a candidate
	buildings.set_cell_item(Vector3i(6, 1, 0), 2)
	var walker := Walker.new()
	walker.name = "Speler"
	town.add_child(walker)
	finds.name = "Vondsten"
	town.add_child(finds)
	tree.root.add_child(town)
	return town


func test_candidate_cells_are_open_find_ground_in_reach(test) -> void:
	var coins: Node3D = LooseChange.new()
	coins.near = 20.0
	coins.reach = 60.0
	var town := _town(coins)
	# the start: the middle of cell 0 (x = 2 m); cell 1 is 4 m off, cell 5 is 20 m off
	var rings: Dictionary = coins._candidate_cells(Vector2(2.0, 2.0))
	var near_cells: Array = rings.near
	var far_cells: Array = rings.far
	test.check(not near_cells.has(Vector3i(0, 0, 0)), "de cel van de start zelf niet (te dichtbij)")
	test.check(near_cells.size() == 4 and near_cells.has(Vector3i(1, 0, 0)) and near_cells.has(Vector3i(4, 0, 0)), "vier cellen dichtbij (%s)" % str(near_cells))
	test.check(not near_cells.has(Vector3i(5, 0, 0)) and not far_cells.has(Vector3i(5, 0, 0)), "niet op de weg")
	test.check(not far_cells.has(Vector3i(6, 0, 0)), "niet onder een gebouw")
	test.check(far_cells.has(Vector3i(7, 0, 0)) and far_cells.has(Vector3i(15, 0, 0)), "verder weg: de verre ring")
	test.check(not far_cells.has(Vector3i(16, 0, 0)), "voorbij `reach` niet (64 m)")
	test.check(not near_cells.has(Vector3i(3, 1, 0)) and not far_cells.has(Vector3i(3, 1, 0)), "alleen de begane grond")
	town.free()


func test_a_plain_kind_of_find_has_the_defaults(test) -> void:
	var finds: Node3D = StreetFinds.new()
	test.check(finds._unlock_name() == "" and finds._make_find(Vector3.ZERO) == null, "geen naam, geen vondst")
	test.check(finds._closest() == 3.0 and finds._apart() == 0.0 and finds._scatter() == 1.4, "de standaardafstanden")
	test.check(finds.finds_left() == 0, "niets op straat")
	test.check(StreetFinds.FIND_GROUND == ["plein/", "stoep/"] and StreetFinds.RETRY_SECONDS == 3.0, "de vaste gegevens blijven bereikbaar")
	finds.free()


func test_nothing_is_laid_without_a_player_or_before_the_player_is_placed(test) -> void:
	var coins: Node3D = LooseChange.new()
	var town := _town(coins)
	var walker: Node3D = town.get_node("Speler")
	walker._placed = false
	coins._physics_process(0.016)
	test.check(not coins._laid, "de speler staat nog niet: niets gelegd")
	walker._placed = true
	coins._physics_process(0.016)
	test.check(coins._laid, "de speler staat (en er is geen verhaal dat het tegenhoudt): gelegd")
	town.free()


func test_a_find_that_cannot_be_taken_is_left_alone_for_a_while(test) -> void:
	var finds := Stubborn.new()
	var town := _town(finds)
	var walker: Node3D = town.get_node("Speler")
	walker.global_position = Vector3(8.0, 0.0, 2.0)
	finds._laid = true
	finds._finds.append(finds._make_find(Vector3(8.0, 0.0, 2.0)))
	finds._physics_process(0.016)
	test.check(finds.tries == 1 and finds.finds_left() == 1, "eroverheen: geprobeerd, blijft liggen")
	finds._physics_process(0.016)
	test.check(finds.tries == 1, "even met rust gelaten: niet meteen opnieuw")
	finds._process(StreetFinds.RETRY_SECONDS + 0.1)
	finds._physics_process(0.016)
	test.check(finds.tries == 2, "na de wachttijd opnieuw geprobeerd")
	test.check(not finds.pick_up(0) and finds.finds_left() == 1, "pick_up zegt dat het niet lukte")
	town.free()


func test_a_sleeping_player_takes_nothing(test) -> void:
	var finds := Stubborn.new()
	var town := _town(finds)
	var walker: Node3D = town.get_node("Speler")
	walker.global_position = Vector3(8.0, 0.0, 2.0)
	walker.asleep = true
	finds._laid = true
	finds._finds.append(finds._make_find(Vector3(8.0, 0.0, 2.0)))
	finds._physics_process(0.016)
	test.check(finds.tries == 0, "slapend: niets opgepakt")
	town.free()
