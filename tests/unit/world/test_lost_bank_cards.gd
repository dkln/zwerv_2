extends RefCounted
## Unit tests of the lost bank cards on the streets without a town
## (scripts/world/things/lost_bank_cards.gd): their own lots and distances, a card with its
## own seed, taking one into the pockets (announced by the reward screen) and one that stays
## when the pockets are full.
##   tests/run_unit_tests.sh lost_bank_cards

const LostBankCards = preload("res://scripts/world/things/lost_bank_cards.gd")
const LooseChange = preload("res://scripts/world/things/loose_change.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")

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


## Someone with pockets: every item fits.
class Carrier extends Node3D:
	var items := {}
	var quiet_adds := 0

	func add_item(item_id: String, count := 1, quiet := false) -> bool:
		items[item_id] = int(items.get(item_id, 0)) + count
		if quiet:
			quiet_adds += 1
		return true


## A HUD that remembers the reward it showed.
class Hud extends Node:
	var rewards := []

	func show_reward(reward: Dictionary) -> void:
		rewards.append(reward)


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


func test_cards_lie_further_from_the_start_and_have_their_own_seed(test) -> void:
	var cards: Node3D = LostBankCards.new()
	var coins: Node3D = LooseChange.new()
	test.check(cards.random_seed != coins.random_seed, "pinpassen en munten: elk hun eigen loting")
	test.check(cards._closest() > coins._closest(), "een pinpas ligt verder van de start")
	test.check(is_equal_approx(cards._apart(), cards.reach / 3.0) and coins._apart() == 0.0, "pinpassen een derde van het bereik uit elkaar, munten overal")
	test.check(cards._unlock_name() == "pinpassen" and coins._unlock_name() == "kleingeld", "wat het verhaal ontgrendelt")
	cards.free()
	coins.free()


func test_a_find_that_cannot_be_taken_stays(test) -> void:
	var cards: Node3D = LostBankCards.new()
	var town := _town(cards)
	cards._finds.append(cards._make_find(Vector3(8.0, 0.0, 2.0)))
	test.check(cards._finds[0].has_meta("seed"), "een pinpas met zijn eigen seed (zijn rekening)")
	# the walker has no pockets: BankCards cannot give the card
	test.check(not cards.pick_up(0), "geen zakken: de pas blijft liggen")
	test.check(cards.finds_left() == 1 and cards._refused_until > cards._clock, "en wordt even met rust gelaten")
	town.free()


func test_a_card_goes_in_the_pockets_and_is_announced(test) -> void:
	var cards: Node3D = LostBankCards.new()
	var town := _town(cards)
	town.get_node("Speler").free()
	var carrier := Carrier.new()
	carrier.name = "Speler"
	town.add_child(carrier)
	var hud := Hud.new()
	hud.name = "HUD"
	town.add_child(hud)
	cards._player = carrier
	cards._finds.append(cards._make_find(Vector3(8.0, 0.0, 2.0)))
	test.check(is_equal_approx(cards._finds[0].global_position.y, LostBankCards.LIFT), "de pas staat een eindje boven de grond")
	test.check(cards.pick_up(0) and cards.finds_left() == 0, "de pas opgepakt")
	test.check(int(carrier.items.get(BankCards.ITEM, 0)) == 1 and BankCards.cards_of(carrier).size() == 1, "een pinpas met een rekening erbij")
	test.check(hud.rewards.size() == 1 and hud.rewards[0].heading == "GEVONDEN" and carrier.quiet_adds == 1, "aangekondigd met het beloningsscherm, zonder losse melding")
	town.free()


func test_a_card_turns_with_the_clock(test) -> void:
	var cards: Node3D = LostBankCards.new()
	var town := _town(cards)
	var card: Node3D = cards._make_find(Vector3(8.0, 0.0, 2.0))
	cards._finds.append(card)
	var before := card.rotation.y
	cards._process(0.5)
	test.check(not is_equal_approx(card.rotation.y, before), "de pas draait")
	test.check(is_equal_approx(cards._scatter(), 1.2), "een pas ligt dichter bij het midden van zijn cel")
	town.free()
