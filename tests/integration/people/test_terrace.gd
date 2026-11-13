extends "res://tests/integration/support/town_test.gd"
## The terraces (scripts/world/terraces.gd): on the café tables of the Plein and the Grote Markt
## people sit (on a chair: by a table, facing it, at seat height), you can talk to them, and
## the terraces have fewer parasols than plain tables.
##   tests/run_integration_tests.sh terrace

const Conversations = preload("res://scripts/story/conversations.gd")
## Metres round a square within which a guest counts as on its terrace.
const NEAR_THE_SQUARE := 40.0


## Who sits on the terraces of the town.
func _guests() -> Array:
	var terraces: Node = scene.get_node_or_null("Terrassen")
	return terraces.guests() if terraces else []


## The town has its terraces with people sitting on them.
func test_people_sit_on_the_terraces(test) -> void:
	test.check(scene.get_node_or_null("Terrassen") != null, "de node Terrassen")
	var guests := _guests()
	print("terrasgasten: %d" % guests.size())
	test.check(guests.size() >= 8, "mensen op de terrasjes (%d)" % guests.size())


## Both the Plein and the Grote Markt have guests on their terrace.
func test_guests_at_the_plein_and_the_grote_markt(test) -> void:
	var guests := _guests()
	var places: Dictionary = scene.get_meta("places")
	for place_key: String in ["plein", "grote_markt"]:
		var place: Vector2 = places.get(place_key, Vector2.INF)
		var near := guests.filter(func(guest: Node3D) -> bool: return Vector2(guest.global_position.x, guest.global_position.z).distance_to(place) < NEAR_THE_SQUARE)
		test.check(near.size() >= 2, "op het terras bij %s (%d)" % [place_key, near.size()])


## Of the terrace tables in the town clearly fewer have a parasol than not.
func test_fewer_parasols_than_plain_tables(test) -> void:
	var props: GridMap = scene.get_node("Props")
	var parasols := 0
	var plain := 0
	for cell in props.get_used_cells():
		var item_name := props.mesh_library.get_item_name(props.get_cell_item(cell))
		if item_name.begins_with("terras/terras_set_parasol"):
			parasols += 1
		elif item_name == "terras/terras_set" or item_name.begins_with("terras/tafel_"):
			plain += 1
	print("terrastafels: %d met parasol, %d zonder" % [parasols, plain])
	test.check(plain > parasols * 1.5, "minder parasols dan tafeltjes")


## A guest sits, can be talked to, and has a conversation with choices.
func test_a_guest_sits_and_can_be_talked_to(test) -> void:
	var guests := _guests()
	test.check(not guests.is_empty(), "er zit iemand")
	if guests.is_empty():
		return
	var guest: Node3D = guests[0]
	test.check(guest.sitting and guest.is_in_group("aanspreekbaar"), "ze zitten en zijn aan te spreken")
	var talk := Conversations.new(guest, null, null)
	test.check(not (talk.opening()[0] as Dictionary).get("choices", []).is_empty(), "een gesprek met een terrasgast")
