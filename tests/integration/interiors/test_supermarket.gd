extends "res://tests/integration/support/town_test.gd"
## The supermarkets in the town (scripts/world/supermarket.gd, Interiors KINDS "derrek" and
## "alfred_steyhn"): every DERREK and ALFRED STEYHN has a way in with the width of its front;
## going in lays out that branch (as wide as its front, its own entrance); a trolley taken at
## the entrance is pushed before you, a shelf puts its product in it; out of the door with
## unpaid goods: thrown out, nothing gained; a basket, things from the shelves, paying at a
## checkout: the story box with the till, the dearest put back when the money is short, the
## rest in the pockets and paid to the cent; the shoppers come in, shop, queue, pay and go out
## again and never walk through the furniture; an ALFRED STEYHN has self-scan and BONUS
## (a quarter off on two kinds of shelf); two branches of one chain are laid out differently.
##   tests/run_integration_tests.sh supermarket

const Supermarket = preload("res://scripts/world/supermarket.gd")
const Layout = preload("res://scripts/world/supermarket_layout.gd")

## Simulated time for the shoppers (seconds), in steps of SIMULATION_STEP.
const SIMULATED := 420.0
const SIMULATION_STEP := 0.2
## Kinds of shelf the basket is filled from, at most.
const SHELVES_FOR_THE_BASKET := 5


## The ways into the supermarkets of `kind` ("derrek", "alfred_steyhn"; "": of both chains).
func _branches(kind := "") -> Array:
	return interiors.supermarkets().filter(func(way_in: Dictionary) -> bool: return kind == "" or way_in.kind == kind)


## The layout of the branch behind `way_in` (SupermarketLayout.plan).
func _plan_of(way_in: Dictionary) -> Dictionary:
	return Layout.plan(String(way_in.kind), int(way_in.seed), int(way_in.width))


## Into the branch behind `way_in` as the player does (at its door, [E]); checks the prompt,
## being inside in the house style of the chain and standing free; returns the shop (null
## if that failed).
func _go_in(test, way_in: Dictionary) -> Node3D:
	player.teleport(way_in.door, 0.0)
	for frame_index in 4:
		await tree.physics_frame
	test.check(prompts() == [["E", "Naar binnen"]], "%s: bij de ingang [E] Naar binnen" % way_in.name)
	await use_door()
	await close_screens()
	var shop: Node3D = interiors._interior
	test.check(interiors.is_inside() and shop != null and shop.has_method("chain"), "%s: binnen" % way_in.name)
	if not interiors.is_inside() or shop == null or not shop.has_method("chain"):
		return null
	test.check(String(shop.brand) == String(way_in.kind), "de huisstijl van %s" % way_in.name)
	for frame_index in 10:
		await tree.physics_frame
	test.check(player._fits(player.global_position), "binnen staat de speler vrij")
	return shop


## Into the first branch of `kind`; null (and a failed check) if there is none or it failed.
func _go_into_first(test, kind: String) -> Node3D:
	var branches := _branches(kind)
	test.check(not branches.is_empty(), "er is een %s" % kind)
	if branches.is_empty():
		return null
	return await _go_in(test, branches[0])


## Out through the door of `shop` as the player does (nothing unpaid with them).
func _go_out(test, shop: Node3D) -> void:
	await put_player_in(shop, (shop.plan.door as Transform3D).origin)
	await use_door()
	await close_screens()
	test.check(not interiors.is_inside(), "weer buiten")


## Takes what is offered at `at` in `shop` (a trolley, a basket, the product of a shelf).
func _use_at(shop: Node3D, at: Vector3) -> void:
	await put_player_in(shop, at)
	use_prompt()
	await frames(1)


## A basket taken and one thing from each of at most SHELVES_FOR_THE_BASKET kinds of shelf
## in it; returns how many kinds of shelf were visited.
func _fill_basket(shop: Node3D) -> int:
	await _use_at(shop, shop.plan.basket_at)
	var shelf_of_category := {}
	for shelf: Dictionary in shop.plan.shelves:
		if shop.product(shelf.category).size() > 0 and not shelf_of_category.has(shelf.category) and shelf_of_category.size() < SHELVES_FOR_THE_BASKET:
			shelf_of_category[shelf.category] = shelf
	for category: String in shelf_of_category:
		await put_player_in(shop, shelf_of_category[category].at)
		print("  bij %s: %s" % [category, prompts()])
		use_prompt()
		await frames(1)
	return shelf_of_category.size()


## Every DERREK and ALFRED STEYHN of the town has a way in, its front 4 to 9 cells wide.
func test_every_supermarket_has_a_way_in(test) -> void:
	var branches := _branches()
	for way_in: Dictionary in branches:
		var layout := _plan_of(way_in)
		print("  %-14s gevel %d cellen, deur %s, seed %d: %d x %d m, ingang x %.0f, %d kassa's, %s" % [way_in.name, int(way_in.width),
			(way_in.door as Vector3).snapped(Vector3.ONE * 0.1), int(way_in.seed), int(layout.width), int(layout.depth),
			(layout.door as Transform3D).origin.x, layout.checkouts.size(), layout.aisles])
	var derreks := _branches("derrek")
	var steyhns := _branches("alfred_steyhn")
	test.check(derreks.size() >= 5 and steyhns.size() >= 4, "supermarkten met een ingang: %d DERREK, %d ALFRED STEYHN" % [derreks.size(), steyhns.size()])
	test.check(branches.all(func(way_in: Dictionary) -> bool: return int(way_in.width) >= 4 and int(way_in.width) <= 9), "elke gevel 4 tot 9 cellen breed")


## Every branch in the town is laid out its own way (the tiles and where they stand).
func test_every_branch_has_its_own_layout(test) -> void:
	var branches := _branches()
	var layouts := {}
	for way_in: Dictionary in branches:
		layouts[str(_plan_of(way_in).tiles)] = true
	test.check(not branches.is_empty() and layouts.size() == branches.size(), "elk filiaal een eigen indeling (%d van %d)" % [layouts.size(), branches.size()])


## Going into a DERREK lays out that branch: as wide as its front, the way out at its own
## entrance, furnished, cashiers sitting at the checkouts and an employee in red.
func test_derrek_is_laid_out_for_its_front_and_staffed(test) -> void:
	var branches := _branches("derrek")
	test.check(not branches.is_empty(), "er is een DERREK")
	if branches.is_empty():
		return
	var way_in: Dictionary = branches[0]
	var shop := await _go_in(test, way_in)
	if shop == null:
		return
	var plan: Dictionary = shop.plan
	test.check(is_equal_approx(float(plan.width), clampi(int(way_in.width), 4, 7) * 4.0), "zo breed als de gevel (%d m)" % int(plan.width))
	var exit: Node3D = interiors._exits["derrek"][0]
	test.check(exit.global_position.distance_to(shop.to_global((plan.door as Transform3D).origin)) < 0.1, "de uitgang bij de ingang van dit filiaal")
	test.check(shop.get_node("Indeling/Inrichting").get_used_cells().size() > 40, "ingericht (%d tiles)" % shop.get_node("Indeling/Inrichting").get_used_cells().size())
	var cashiers: Array = shop.people().filter(func(person: Node) -> bool: return person.role == "kassamedewerker")
	test.check(cashiers.size() >= 2 and cashiers.all(func(person: Node) -> bool: return person.sitting), "caissières aan de kassa's (%d)" % cashiers.size())
	test.check(shop.people().any(func(person: Node) -> bool: return person.role == "medewerker_derrek"), "een medewerker in het rood")
	test.check(shop.people().all(func(person: Node) -> bool: return person.has_node("Botsvorm")), "iedereen binnen heeft een botsvorm")


## A trolley taken at the entrance is pushed before the player and collides with them:
## pushed straight on towards the wall it stops there and never ends up in anything.
func test_trolley_is_pushed_and_stops_at_the_wall(test) -> void:
	var shop := await _go_into_first(test, "derrek")
	if shop == null:
		return
	await put_player_in(shop, shop.plan.cart_at)
	test.check(prompts() == [["E", "Karretje pakken"]], "bij de karretjes: [E] Karretje pakken (%s)" % [prompts()])
	use_prompt()
	await frames(1)
	test.check(shop.carrier() == "karretje" and player.has_node("Winkelkarretje"), "karretje gepakt, voor de speler")
	test.check(player._pushed_box.size.z > 0.4, "het karretje botst mee (doos %s)" % [player._pushed_box.size])
	var start_spot: Vector3 = player.global_position
	for step_index in 400:
		player._try_move(player.global_transform.basis.z.normalized() * 0.05)
	await tree.physics_frame
	test.check(player._pushed_fits(player.global_position, player.rotation.y), "het karretje staat nergens in na doorduwen (%.1f m gelopen)" % start_spot.distance_to(player.global_position))


## At a shelf [E] takes its product (the house brand): three times gives three things in
## the trolley, to be seen lying in it.
func test_shelf_puts_its_product_in_the_trolley(test) -> void:
	var shop := await _go_into_first(test, "derrek")
	if shop == null:
		return
	await _use_at(shop, shop.plan.cart_at)
	var drinks := (shop.plan.shelves as Array).filter(func(candidate: Dictionary) -> bool: return candidate.category == "drank")
	var shelf: Dictionary = drinks[0] if not drinks.is_empty() else shop.plan.shelves[0]
	await put_player_in(shop, shelf.at)
	var shelf_action := prompts()
	print("  ", shelf_action)
	test.check(not shelf_action.is_empty() and String(shelf_action[0][1]).begins_with("Pakken: DERREK"), "bij het schap: [E] Pakken (het huismerk)")
	for take in 3:
		await _use_at(shop, shelf.at)
	test.check(shop.goods().size() == 3, "drie dingen in het karretje (%d)" % shop.goods().size())
	test.check(player.get_node("Winkelkarretje/Spullen").get_child_count() == 3, "te zien in het karretje")


## Out of the door with unpaid goods: thrown out and barred for a while, nothing paid and
## nothing gained, the trolley left inside.
func test_out_with_unpaid_goods_gets_you_thrown_out(test) -> void:
	var shop := await _go_into_first(test, "derrek")
	if shop == null:
		return
	await _use_at(shop, shop.plan.cart_at)
	await _use_at(shop, shop.plan.shelves[0].at)
	test.check(not shop.goods().is_empty(), "iets onbetaalds in het karretje")
	var money_before: float = player.money
	var inventory_before: Dictionary = player.inventory.duplicate()
	await put_player_in(shop, (shop.plan.door as Transform3D).origin)
	test.check(prompts() == [["E", "Naar buiten"]], "bij de deur: [E] Naar buiten")
	use_prompt()
	for wait in 80:
		await seconds(0.1)
		await close_screens()
		if not interiors.is_inside() and not interiors._throwing:
			break
	test.check(not interiors.is_inside(), "met onbetaalde spullen de deur uit: eruit gegooid")
	test.check(int(interiors._barred_until.get("derrek", 0)) > Time.get_ticks_msec(), "en voorlopig niet meer welkom")
	test.check(is_equal_approx(player.money, money_before) and player.inventory == inventory_before, "niets betaald, niets gekregen")
	test.check(shop.goods().is_empty() and not player.has_node("Winkelkarretje"), "het karretje bleef binnen")


## A basket hangs on the arm and takes one thing per shelf visited; at the checkout [E]
## opens the story box, the cashier saying what it costs with the choice to pay or not.
func test_basket_filled_and_the_cashier_names_the_price(test) -> void:
	var shop := await _go_into_first(test, "derrek")
	if shop == null:
		return
	var shelves_visited := await _fill_basket(shop)
	test.check(shop.carrier() == "mandje" and player.has_node("Winkelmandje"), "mandje gepakt, aan de arm")
	var picked: Array = shop.goods()
	print("  in het mandje: ", picked.map(func(thing: Dictionary) -> String: return "%s %.2f" % [thing.name, thing.price]))
	test.check(picked.size() == mini(shelves_visited, shop.capacity()), "uit %d schappen in het mandje (%d)" % [shelves_visited, picked.size()])
	await put_player_in(shop, shop.plan.checkouts[0].pay_at)
	test.check(prompts() == [["E", "Afrekenen"]], "bij de kassa: [E] Afrekenen")
	use_prompt()
	await frames(1)
	var box: Control = hud._story_box
	test.check(box.is_showing() and not box._current_choices().is_empty(), "de caissière zegt wat het kost, betalen of laat maar")
	print("  kassa: ", box._pages[0].text if not box._pages.is_empty() else "")
	box.hide()
	box._pages = []
	tree.paused = false


## Too little money for all of the basket: the dearest go back (and the cashier says so),
## the rest is paid to the cent and is in the pockets, the basket empty.
func test_short_of_money_the_dearest_go_back(test) -> void:
	var shop := await _go_into_first(test, "derrek")
	if shop == null:
		return
	await _fill_basket(shop)
	var picked: Array = shop.goods().duplicate()
	test.check(picked.size() >= 2, "minstens twee dingen in het mandje (%d)" % picked.size())
	if picked.size() < 2:
		return
	picked.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.price) > float(second.price))
	player.money = float(picked[-1].price) + float(picked[-2].price) + 0.01
	player.inventory = {}
	var pages: Array = shop.settle(shop.chain().kassa, null, false)
	for page: Dictionary in pages:
		print("  kassa: ", page.text)
	test.check(is_equal_approx(player.money, 0.01), "precies betaald wat er paste (over: %.2f)" % player.money)
	var in_pockets := 0
	for item_id: String in player.inventory:
		in_pockets += int(player.inventory[item_id])
	test.check(in_pockets == 2, "de twee goedkoopste in de zakken (%d)" % in_pockets)
	test.check(pages.size() >= 2 and String(pages[0].text).contains(String(picked[0].name)), "de duurste teruggelegd en dat gezegd")
	test.check(shop.goods().is_empty(), "het mandje leeg na het afrekenen")
	await _go_out(test, shop)


## The shoppers over SIMULATED seconds (their _process in steps): shopping when you come
## in, more coming in, paying at the checkouts and leaving, never more than fit and never
## through the shelves.
func test_shoppers_come_in_pay_and_leave(test) -> void:
	var shop := await _go_into_first(test, "derrek")
	if shop == null:
		return
	var at_start: int = shop.shoppers().size()
	var boxes: Array[AABB] = Supermarket.footprints(shop.plan, load(Supermarket.LIBRARY), load(Supermarket.PROPS_LIBRARY))
	var half_width := float(shop.plan.width) * 0.5
	var half_depth := float(shop.plan.depth) * 0.5
	var inner := boxes.filter(func(box: AABB) -> bool:
		return box.position.x > -half_width + 0.2 and box.end.x < half_width - 0.2 \
			and box.position.z > -half_depth + 0.2 and box.end.z < half_depth - 0.2)
	var samples := 0
	var through := 0
	var most := 0
	for step in int(SIMULATED / SIMULATION_STEP):
		shop._process(SIMULATION_STEP)
		most = maxi(most, shop.shoppers().size())
		if step % 10 == 0:
			for shopper: Dictionary in shop.shoppers():
				var person: Node3D = shopper.person
				samples += 1
				var feet := AABB(person.position + Vector3(-0.05, 0.3, -0.05), Vector3(0.1, 0.5, 0.1))
				if inner.any(func(box: AABB) -> bool: return box.grow(-0.05).intersects(feet)):
					through += 1
		if step % 25 == 0:
			await tree.process_frame   # the figures of the next shoppers are built on a thread
	print("  winkelend: %d bij binnenkomst, hooguit %d tegelijk; %s" % [at_start, most, shop.stats])
	test.check(at_start >= 2, "er wordt al gewinkeld als je binnenkomt (%d)" % at_start)
	test.check(int(shop.stats.binnen) >= 3, "er komen mensen binnenlopen (%d)" % int(shop.stats.binnen))
	test.check(int(shop.stats.betaald) >= 2, "ze rekenen af bij de kassa (%d)" % int(shop.stats.betaald))
	test.check(int(shop.stats.weg) >= 3, "en gaan weer weg (%d)" % int(shop.stats.weg))
	test.check(most <= shop.most_shoppers(), "niet meer dan er passen (%d van %d)" % [most, shop.most_shoppers()])
	test.check(through <= samples / 50, "ze lopen niet door de schappen (%d van %d keer)" % [through, samples])
	await _go_out(test, shop)


## Two branches of DERREK, gone into one after the other, are laid out differently.
func test_another_derrek_is_laid_out_differently(test) -> void:
	var branches := _branches("derrek")
	test.check(branches.size() > 1, "meer dan een DERREK (%d)" % branches.size())
	if branches.size() < 2:
		return
	var shop := await _go_in(test, branches[0])
	if shop == null:
		return
	var first_plan: Dictionary = shop.plan
	await _go_out(test, shop)
	shop = await _go_in(test, branches[-1])
	if shop == null:
		return
	var second_plan: Dictionary = shop.plan
	print("  ander filiaal: %d x %d m, %d kassa's (was %d x %d, %d)" % [int(second_plan.width), int(second_plan.depth), second_plan.checkouts.size(),
		int(first_plan.width), int(first_plan.depth), first_plan.checkouts.size()])
	test.check(str(second_plan.tiles) != str(first_plan.tiles), "een ander filiaal is anders ingedeeld")
	await _go_out(test, shop)


## An ALFRED STEYHN has self-scan checkouts, two kinds of shelf in the BONUS (a quarter
## off) and an employee in light blue.
func test_alfred_steyhn_has_self_scan_and_bonus(test) -> void:
	var shop := await _go_into_first(test, "alfred_steyhn")
	if shop == null:
		return
	var plan: Dictionary = shop.plan
	test.check(plan.checkouts.any(func(checkout: Dictionary) -> bool: return checkout.self_scan), "zelfscankassa's (%d)" % int(plan.self_scans))
	test.check(shop._bonus.size() == 2, "twee soorten schappen in de bonus %s" % [shop._bonus])
	if not shop._bonus.is_empty():
		var category: String = shop._bonus[0]
		var full := float(shop.chain().producten[category].prijs)
		var with_bonus := float(shop.product(category).price)
		test.check(with_bonus < full and is_equal_approx(with_bonus, snappedf(full * 0.75, 0.01)), "bonus: %s %.2f in plaats van %.2f" % [category, with_bonus, full])
	test.check(shop.people().any(func(person: Node) -> bool: return person.role == "medewerker_alfred_steyhn"), "een medewerker in het lichtblauw")


## A croissant from the bakery of an ALFRED STEYHN, paid at a self-scan checkout: it is in
## the pockets and the money is less.
func test_self_scan_sells_a_croissant(test) -> void:
	var shop := await _go_into_first(test, "alfred_steyhn")
	if shop == null:
		return
	var plan: Dictionary = shop.plan
	var self_scans: Array = (plan.checkouts as Array).filter(func(checkout: Dictionary) -> bool: return checkout.self_scan)
	var bakery := (plan.shelves as Array).filter(func(shelf: Dictionary) -> bool: return shelf.category == "bakkerij")
	test.check(not self_scans.is_empty(), "een zelfscankassa")
	test.check(not bakery.is_empty(), "een bakkerij")
	if self_scans.is_empty() or bakery.is_empty():
		return
	await _use_at(shop, plan.basket_at)
	await _use_at(shop, bakery[0].at)
	player.money = 10.0
	player.inventory = {}
	await put_player_in(shop, self_scans[0].pay_at)
	test.check(prompts() == [["E", "Afrekenen"]], "bij de zelfscan: [E] Afrekenen")
	var pages: Array = shop.settle(shop.chain().zelfscan, null, true)
	test.check(int(player.inventory.get("croissant", 0)) == 1 and player.money < 10.0, "een croissant gekocht bij de zelfscan (€ %.2f over)" % player.money)
	print("  zelfscan: ", pages[-1].text if not pages.is_empty() else "")
	await _go_out(test, shop)
