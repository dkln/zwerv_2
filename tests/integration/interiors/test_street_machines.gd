extends "res://tests/integration/support/town_test.gd"
## The machines and finds in the town (scenes/stad.tscn): the cash machines and OV machines
## of the node "Straatautomaten" (scripts/world/street_machines.gd) stand on the ground with
## a collider and an [E] spot before them; at a cash machine "[E] Pinnen" opens the cash
## machine's screen; the waste bins (node "Prullenbakken") have cans, "[E] Blikje pakken"
## puts one in the pockets; lost bank cards (node "Pinpassen") lie on the streets and walking
## over one gives a "pinpas" of its own. Prints where the cash machines stand.
##   tests/run_integration_tests.sh street_machines

const BankCards = preload("res://scripts/player/bank_cards.gd")


## The node `node_name` of the town once it has laid out what it holds (the machines placed,
## the cards laid); null if the town has no such node.
func _laid_out(node_name: String) -> Node:
	var node: Node = scene.get_node_or_null(node_name)
	if node == null:
		return null
	await wait_until(func() -> bool:
		return (node.get("_laid") == null or bool(node.get("_laid"))) and (node.get("machines") == null or not (node.get("machines") as Array).is_empty()))
	return node


## The town has cash machines all over and OV machines besides.
func test_cash_and_ov_machines_stand_in_the_town(test) -> void:
	var machines := await _laid_out("Straatautomaten")
	test.check(machines != null, "Straatautomaten in de stad")
	if machines == null:
		return
	var cash_machines: Array = machines.cash_machines()
	print("geldautomaten: %d, OV-automaten: %d" % [cash_machines.size(), machines.machines.size() - cash_machines.size()])
	test.check(cash_machines.size() >= 15, "geldautomaten door de stad (%d)" % cash_machines.size())
	test.check(machines.machines.size() > cash_machines.size(), "OV-automaten bij tramhaltes")


## Every machine stands on the ground: a ray down from it hits something other than itself.
func test_every_machine_stands_on_the_ground(test) -> void:
	var machines := await _laid_out("Straatautomaten")
	test.check(machines != null, "Straatautomaten in de stad")
	if machines == null:
		return
	var floating := 0
	for place: Node3D in machines.machines:
		print("  %s bij (%.0f, %.1f, %.0f)" % [place.name, place.global_position.x, place.global_position.y, place.global_position.z])
		var space := place.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(place.global_position + Vector3.UP * 0.3, place.global_position + Vector3.DOWN * 0.4, 1)
		query.exclude = [(place.get_child(0).get_node("Botsvorm") as CollisionObject3D).get_rid()]
		if space.intersect_ray(query).is_empty():
			floating += 1
	test.check(floating == 0, "alle automaten staan op de grond (%d zweven)" % floating)


## At a cash machine the HUD offers [E] Pinnen, and using it opens the machine's own screen
## with the game paused.
func test_cash_machine_opens_its_screen(test) -> void:
	var machines := await _laid_out("Straatautomaten")
	test.check(machines != null and not machines.cash_machines().is_empty(), "een geldautomaat in de stad")
	if machines == null or machines.cash_machines().is_empty():
		return
	var spot: Node3D = (machines.cash_machines()[0] as Node3D).get_node("Plek")
	await stand_at(spot.global_position)
	test.check(prompts().has(["E", "Pinnen"]), "bij een geldautomaat: [E] Pinnen (%s)" % str(prompts()))
	player.give_found_bank_card()
	spot.go_through()
	await wait_until(func() -> bool:
		return tree.root.has_node("Automaatscherm") and tree.root.get_node("Automaatscherm").visible, 2.0)
	var screen: Node = tree.root.get_node_or_null("Automaatscherm")
	test.check(screen != null and tree.paused, "de geldautomaat opent zijn eigen scherm (het spel staat stil)")
	await close_screens()
	BankCards.cards_of(player).clear()


## The waste bins hold cans, and taking one at a bin puts it in the pockets.
func test_taking_a_can_from_a_bin(test) -> void:
	var bins := await _laid_out("Prullenbakken")
	test.check(bins != null, "Prullenbakken in de stad")
	if bins == null:
		return
	print("prullenbakken: %d, met blikje: %d" % [bins.bin_count(), bins.cans_left()])
	test.check(bins.bin_count() > 20 and bins.cans_left() > 5, "blikjes in prullenbakken")
	var can_spot: Node3D = bins.a_can_spot()
	var cans_before: int = bins.cans_left()
	player.inventory.erase("blikje")
	can_spot.go_through()
	await frames(1)
	test.check(int(player.inventory.get("blikje", 0)) == 1 and bins.cans_left() == cans_before - 1, "[E] Blikje pakken: het blikje in je zakken")


## Lost bank cards lie on the streets, and walking over one gives a card with an account
## of its own.
func test_walking_over_a_lost_bank_card(test) -> void:
	var cards := await _laid_out("Pinpassen")
	test.check(cards != null, "Pinpassen in de stad")
	if cards == null:
		return
	test.check(cards.cards_left() >= 3, "pinpassen op straat (%d)" % cards.cards_left())
	var had_backpack: bool = player.get("has_backpack")
	player.set("has_backpack", true)
	var cards_before := BankCards.cards_of(player).size()
	var card: Node3D = cards._cards[0]
	player.global_position = card.global_position - Vector3.UP * 0.12
	for step_index in 5:
		await tree.physics_frame
	test.check(BankCards.cards_of(player).size() == cards_before + 1, "over een pinpas lopen: een pas met eigen rekening erbij")
	BankCards.cards_of(player).clear()
	player.set("has_backpack", had_backpack)
