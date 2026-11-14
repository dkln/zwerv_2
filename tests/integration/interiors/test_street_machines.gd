extends "res://tests/integration/support/town_test.gd"
## The machines and finds in the town (scenes/stad.tscn): the cash machines and OV posts
## of the node "Straatautomaten" (scripts/world/things/street_machines.gd) stand on the ground with
## a collider and an [E] spot before them; at a cash machine "[E] Pinnen" opens the cash
## machine's screen; at an OV post "[E] Inchecken" checks in with the card, then "[E]
## Uitchecken" (refused without a card; the boarding fare after a trip not checked out);
## the waste bins (node "Prullenbakken") have cans, "[E] Blikje pakken"
## puts one in the pockets; lost bank cards (node "Pinpassen") lie on the streets and walking
## over one gives a "pinpas" of its own (rare: one in the town; loose change is rare too).
## Prints where the cash machines stand.
##   tests/run_integration_tests.sh street_machines

const BankCards = preload("res://scripts/player/bank_cards.gd")
const OvCard = preload("res://scripts/world/station/ov_card.gd")


## The node `node_name` of the town once it has laid out what it holds (the machines placed,
## the cards laid); null if the town has no such node.
func _laid_out(node_name: String) -> Node:
	var node: Node = scene.get_node_or_null(node_name)
	if node == null:
		return null
	await wait_until(func() -> bool:
		return (node.get("_laid") == null or bool(node.get("_laid"))) and (node.get("machines") == null or not (node.get("machines") as Array).is_empty()))
	return node


## The town has cash machines all over and OV posts (no OV machines) at the tram stops.
func test_cash_machines_and_ov_posts_stand_in_the_town(test) -> void:
	var machines := await _laid_out("Straatautomaten")
	test.check(machines != null, "Straatautomaten in de stad")
	if machines == null:
		return
	var cash_machines: Array = machines.cash_machines()
	print("geldautomaten: %d, OV-paaltjes: %d" % [cash_machines.size(), machines.ov_posts().size()])
	test.check(cash_machines.size() >= 15, "geldautomaten door de stad (%d)" % cash_machines.size())
	test.check(machines.ov_posts().size() >= 4 and machines.machines.size() == cash_machines.size() + machines.ov_posts().size(), "OV-paaltjes bij tramhaltes (%d), geen OV-automaten" % machines.ov_posts().size())
	test.check(not machines.machines.any(func(place: Node3D) -> bool: return String(place.name).begins_with("OVAutomaat")), "geen OV-chipkaartautomaten op straat")


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


## At an OV post by a tram stop: [E] Inchecken; without a card it says no, with one it
## checks in (the fare off the balance) and then offers [E] Uitchecken; out of the station
## still checked in, the boarding fare is kept here too.
func test_ov_post_checks_in_and_out(test) -> void:
	var machines := await _laid_out("Straatautomaten")
	test.check(machines != null and not machines.ov_posts().is_empty(), "een OV-paaltje in de stad")
	if machines == null or machines.ov_posts().is_empty():
		return
	for meta: String in [OvCard.CHECKED_IN_WITH_META, OvCard.MISSED_CHECK_OUT_META]:
		if player.has_meta(meta):
			player.remove_meta(meta)
	player.set_meta(OvCard.CHECKED_IN_META, false)
	player.inventory.erase(OvCard.CARD_ITEM)
	player.inventory.erase(OvCard.TICKET_ITEM)
	var post: Node3D = machines.ov_posts()[0]
	var spot: Node3D = post.get_node("Plek")
	await stand_at(spot.global_position)
	test.check(prompts().has(["E", "Inchecken"]), "bij een OV-paaltje: [E] Inchecken (%s)" % str(prompts()))
	spot.go_through()
	test.check(not OvCard.is_checked_in(player), "zonder OV-chipkaart: niet ingecheckt")
	player.inventory[OvCard.CARD_ITEM] = 1
	player.set_meta(OvCard.BALANCE_META, 10.0)
	spot.go_through()
	test.check(OvCard.is_checked_in(player) and is_equal_approx(OvCard.balance(player), 9.0), "met kaart ingecheckt (€ 1 eraf)")
	player._talk_partner = null   # as after [E]: the prompt looked up again
	await frames(2)
	test.check(prompts().has(["E", "Uitchecken"]), "daarna: [E] Uitchecken (%s)" % str(prompts()))
	spot.go_through()
	test.check(not OvCard.is_checked_in(player), "uitgecheckt")
	# a trip left open (out of the station still checked in): the boarding fare
	player.set_meta(OvCard.MISSED_CHECK_OUT_META, true)
	spot.go_through()
	test.check(is_equal_approx(OvCard.balance(player), 9.0 - OvCard.BOARDING_FARE), "niet uitgecheckt: het instaptarief ingehouden (€ %.2f over)" % OvCard.balance(player))
	spot.go_through()
	player.inventory.erase(OvCard.CARD_ITEM)


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
	test.check(cards.cards_left() == 1, "zeldzaam: één pinpas op straat (%d)" % cards.cards_left())
	var start: Vector3 = player.global_position
	var card_at: Vector3 = cards._cards[0].global_position if cards.cards_left() > 0 else start
	test.check(Vector2(card_at.x - start.x, card_at.z - start.z).length() > cards.near, "niet vlak bij de start")
	# room in the pockets: a coat on (its pockets, Items.COAT_SLOTS)
	var had_coat: bool = player.inventory.has("oude_jas")
	player.inventory["oude_jas"] = 1
	var cards_before := BankCards.cards_of(player).size()
	var card: Node3D = cards._cards[0]
	player.global_position = card.global_position - Vector3.UP * 0.12
	for step_index in 5:
		await tree.physics_frame
	test.check(BankCards.cards_of(player).size() == cards_before + 1, "over een pinpas lopen: een pas met eigen rekening erbij")
	BankCards.cards_of(player).clear()
	if not had_coat:
		player.inventory.erase("oude_jas")


## Loose change is very rare: one coin in the whole town (once the story allows it), none by the start.
func test_loose_change_is_rare(test) -> void:
	var coins := await _laid_out("Kleingeld")
	test.check(coins != null, "Kleingeld in de stad")
	if coins == null:
		return
	print("munten op straat: ", coins.coins_left())
	test.check(coins.coins_left() == 1, "heel zeldzaam: één munt in de hele stad (%d)" % coins.coins_left())
	var start: Vector3 = player.global_position
	var near_start: Array = coins._coins.filter(func(coin: Dictionary) -> bool:
		var at: Vector3 = (coin.node as Node3D).global_position
		return Vector2(at.x - start.x, at.z - start.z).length() < coins.near - 5.0)
	test.check(near_start.is_empty(), "geen munten vlak bij de start (%d)" % near_start.size())
