extends RefCounted
## Unit tests of the loose change on the streets without a town
## (scripts/world/things/loose_change.gd): what a coin is worth, where it stands, how it
## turns, and that taking it pays its value.
##   tests/run_unit_tests.sh loose_change

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


## A HUD that remembers the number that floated up.
class Hud extends Node:
	var shown := []

	func show_floating_number(at: Vector3, text: String, colour: Color) -> void:
		shown.append({"at": at, "text": text, "colour": colour})


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


func test_a_coin_turns_and_bobs_with_the_clock(test) -> void:
	var coins: Node3D = LooseChange.new()
	var town := _town(coins)
	var coin: Node3D = coins._make_find(Vector3(8.0, 0.0, 2.0))
	coins._finds.append(coin)
	var before := coin.rotation.y
	coins._process(0.5)
	test.check(not is_equal_approx(coin.rotation.y, before), "de munt draait")
	test.check(absf(coin.position.y - float(coin.get_meta("base"))) <= 0.05 + 0.0001, "en deint hooguit vijf centimeter")
	test.check(coins._unlock_name() == "kleingeld", "wat het verhaal ontgrendelt")
	town.free()


func test_taking_a_coin_shows_its_value_on_the_hud(test) -> void:
	var coins: Node3D = LooseChange.new()
	var town := _town(coins)
	var walker: Node3D = town.get_node("Speler")
	var hud := Hud.new()
	town.add_child(hud)
	walker._hud = hud
	var coin: Node3D = coins._make_find(Vector3(8.0, 0.0, 2.0))
	coins._finds.append(coin)
	coin.set_meta("value", 0.5)
	test.check(coins.pick_up(0), "de munt opgepakt")
	test.check(hud.shown.size() == 1 and hud.shown[0].text == "+€ 0,50", "het bedrag stijgt op (%s)" % str(hud.shown))
	test.check(is_equal_approx(walker.money, 0.5), "en zit in de portemonnee")
	town.free()
