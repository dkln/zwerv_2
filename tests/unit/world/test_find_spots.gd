extends RefCounted
## Unit tests of where the finds of the streets lie (scripts/world/things/find_spots.gd) and
## of the finds themselves without a town (street_finds.gd, loose_change.gd,
## lost_bank_cards.gd: candidate cells, taking one).
##   tests/run_unit_tests.sh find_spots

const FindSpots = preload("res://scripts/world/things/find_spots.gd")
const LooseChange = preload("res://scripts/world/things/loose_change.gd")
const LostBankCards = preload("res://scripts/world/things/lost_bank_cards.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Someone who walks over finds: counts the money they get.
class Walker extends Node3D:
	var money := 0.0
	var _hud: Node = null

	func add_money(amount: float) -> void:
		money += amount


static func _middle(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * 4.0 + 2.0, 0.0, cell.z * 4.0 + 2.0)


func test_find_ground_is_square_and_pavement(test) -> void:
	var folders := ["plein/", "stoep/"]
	test.check(FindSpots.is_find_ground("plein/klinkers", folders), "een plein: ja")
	test.check(FindSpots.is_find_ground("stoep/tegel_rand", folders), "een stoep: ja")
	test.check(not FindSpots.is_find_ground("weg/asfalt", folders), "een weg: nee")
	test.check(not FindSpots.is_find_ground("groen/plein/gras", folders), "alleen aan het begin van de naam")
	test.check(not FindSpots.is_find_ground("plein/klinkers", []), "geen mappen: nergens")


func test_ring_by_distance(test) -> void:
	test.check(FindSpots.ring(2.0, 3.0, 60.0, 400.0) == "", "te dichtbij: geen")
	test.check(FindSpots.ring(3.0, 3.0, 60.0, 400.0) == "near", "vanaf de kleinste afstand: dichtbij")
	test.check(FindSpots.ring(60.0, 3.0, 60.0, 400.0) == "near", "tot en met `near`: dichtbij")
	test.check(FindSpots.ring(60.5, 3.0, 60.0, 400.0) == "far", "daarna: ver")
	test.check(FindSpots.ring(400.0, 3.0, 60.0, 400.0) == "far", "tot en met `reach`: ver")
	test.check(FindSpots.ring(401.0, 3.0, 60.0, 400.0) == "", "te ver: geen")


func test_choose_takes_near_first_then_far(test) -> void:
	var near_cells := [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)]
	var far_cells := [Vector3i(20, 0, 0), Vector3i(21, 0, 0), Vector3i(22, 0, 0)]
	var chosen := FindSpots.choose(near_cells, far_cells, 2, 4, 0.0, _middle)
	test.check(chosen == [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(20, 0, 0), Vector3i(21, 0, 0)], "twee dichtbij, dan ver tot het aantal (%s)" % str(chosen))
	test.check(FindSpots.choose(near_cells, far_cells, 0, 1, 0.0, _middle) == [Vector3i(20, 0, 0)], "geen dichtbij: de eerste verre")
	test.check(FindSpots.choose(near_cells, far_cells, 0, 9, 0.0, _middle).size() == 3, "niet meer dan er cellen zijn")
	test.check(FindSpots.choose([], [], 2, 3, 0.0, _middle).is_empty(), "geen cellen: niets")
	test.check(FindSpots.choose(near_cells, far_cells, 3, 2, 0.0, _middle).size() == 3, "meer dichtbij gevraagd dan het aantal: die blijven")


func test_choose_keeps_far_ones_apart(test) -> void:
	# cells of 4 m: 20 and 21 lie 4 m apart, 20 and 30 lie 40 m apart
	var far_cells := [Vector3i(20, 0, 0), Vector3i(21, 0, 0), Vector3i(30, 0, 0), Vector3i(31, 0, 0), Vector3i(45, 0, 0)]
	var chosen := FindSpots.choose([], far_cells, 0, 3, 30.0, _middle)
	test.check(chosen == [Vector3i(20, 0, 0), Vector3i(30, 0, 0), Vector3i(45, 0, 0)], "meer dan 30 m uit elkaar (%s)" % str(chosen))
	var with_near := FindSpots.choose([Vector3i(19, 0, 0)], far_cells, 1, 2, 30.0, _middle)
	test.check(with_near == [Vector3i(19, 0, 0), Vector3i(30, 0, 0)], "ook uit de buurt van die dichtbij (%s)" % str(with_near))


func test_walked_over(test) -> void:
	var feet := Vector3(10.0, 0.0, 10.0)
	test.check(FindSpots.walked_over(feet, Vector3(10.5, 0.3, 10.0), 1.0), "eroverheen: ja")
	test.check(not FindSpots.walked_over(feet, Vector3(11.5, 0.3, 10.0), 1.0), "ernaast: nee")
	test.check(not FindSpots.walked_over(feet, Vector3(10.5, 4.0, 10.0), 1.0), "een verdieping hoger: nee")


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


func test_cards_lie_further_from_the_start_and_have_their_own_seed(test) -> void:
	var cards: Node3D = LostBankCards.new()
	var coins: Node3D = LooseChange.new()
	test.check(cards.random_seed != coins.random_seed, "pinpassen en munten: elk hun eigen loting")
	test.check(cards._closest() > coins._closest(), "een pinpas ligt verder van de start")
	test.check(is_equal_approx(cards._apart(), cards.reach / 3.0) and coins._apart() == 0.0, "pinpassen een derde van het bereik uit elkaar, munten overal")
	test.check(cards._unlock_name() == "pinpassen" and coins._unlock_name() == "kleingeld", "wat het verhaal ontgrendelt")
	cards.free()
	coins.free()


func test_taking_a_coin_pays_its_value(test) -> void:
	var coins: Node3D = LooseChange.new()
	var town := _town(coins)
	var walker: Node3D = town.get_node("Speler")
	for number in 40:
		coins._finds.append(coins._make_find(Vector3(8.0 + number * 2.0, 0.0, 2.0)))
	var values := {}
	var total := 0.0
	for coin: Node3D in coins._finds:
		var value := float(coin.get_meta("value"))
		values[value] = true
		total += value
		test.check(LooseChange.VALUES.has(value), "een munt van 10, 20, 50 cent of een euro (%s)" % value)
		test.check(is_equal_approx(coin.global_position.y, LooseChange.LIFT), "op zijn kant boven de grond")
	test.check(values.size() >= 3, "verschillende waardes (%d)" % values.size())
	test.check(coins.finds_left() == 40, "veertig munten")
	# walking over the first one only
	coins._take_what_is_walked_over(Vector3(8.2, 0.0, 2.0))
	test.check(coins.finds_left() == 39, "eroverheen lopen: één munt weg (%d)" % coins.finds_left())
	test.check(walker.money > 0.0, "en het geld erbij (%s)" % walker.money)
	while coins.finds_left() > 0:
		test.check(coins.pick_up(0), "een munt oppakken lukt altijd")
	test.check(is_equal_approx(walker.money, total), "alles opgepakt: de som van de waardes (%s van %s)" % [walker.money, total])
	town.free()


func test_a_find_that_cannot_be_taken_stays(test) -> void:
	var cards: Node3D = LostBankCards.new()
	var town := _town(cards)
	cards._finds.append(cards._make_find(Vector3(8.0, 0.0, 2.0)))
	test.check(cards._finds[0].has_meta("seed"), "een pinpas met zijn eigen seed (zijn rekening)")
	# the walker has no pockets: BankCards cannot give the card
	test.check(not cards.pick_up(0), "geen zakken: de pas blijft liggen")
	test.check(cards.finds_left() == 1 and cards._refused_until > cards._clock, "en wordt even met rust gelaten")
	town.free()
