extends SceneTree
## The supermarkets in the town (scripts/world/supermarket.gd, Interiors KINDS "derrek" and
## "alfred_steyhn"): every DERREK and ALFRED STEYHN has a way in with the width of its front;
## going in lays out that branch (as wide as its front, its own entrance); a trolley taken at
## the entrance is pushed before you, a shelf puts its product in it; out of the door with
## unpaid goods: thrown out, nothing gained; a basket, things from the shelves, paying at a
## checkout: the story box with the till, the dearest put back when the money is short, the
## rest in the pockets and paid to the cent; the shoppers come in, shop, queue, pay and go out
## again and never walk through the furniture; an ALFRED STEYHN has self-scan and BONUS
## (a quarter off on two kinds of shelf); two branches of one chain are laid out differently.
## usage: tools/godot.sh --headless --script tools/check/supermarket_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Supermarket = preload("res://scripts/world/supermarket.gd")
const Layout = preload("res://scripts/world/supermarket_layout.gd")

## Simulated time for the shoppers (seconds), in steps of SIMULATION_STEP.
const SIMULATED := 420.0
const SIMULATION_STEP := 0.2

var _problems: Array[String] = []
var _scene: Node
var _player: Node3D
var _hud: Node
var _interiors: Node


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("martin")
	_scene = Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook"]:
		if _scene.has_node(node_name):
			_scene.get_node(node_name).free()
	_scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(_scene)
	_player = _scene.get_node("Speler")
	_hud = _scene.get_node("HUD")
	_interiors = _scene.get_node("Binnenruimtes")
	_scene.get_node("Volgcamera")._end_arrival()
	for frame_index in 600:
		await physics_frame
		if _player._placed and not _player._sleeping:
			break
	_player._wake_up()
	for attempt in 40:
		if not _player._sleeping:
			break
		await create_timer(0.1, true).timeout
	for frame_index in 120:
		await process_frame
		_skip_story()
	var shops: Array = _interiors.supermarkets()
	var derreks := shops.filter(func(way_in: Dictionary) -> bool: return way_in.kind == "derrek")
	var steyhns := shops.filter(func(way_in: Dictionary) -> bool: return way_in.kind == "alfred_steyhn")
	for way_in: Dictionary in shops:
		var layout := Layout.plan(String(way_in.kind), int(way_in.seed), int(way_in.width))
		print("  %-14s gevel %d cellen, deur %s, seed %d: %d x %d m, ingang x %.0f, %d kassa's, %s" % [way_in.name, int(way_in.width),
			(way_in.door as Vector3).snapped(Vector3.ONE * 0.1), int(way_in.seed), int(layout.width), int(layout.depth),
			(layout.door as Transform3D).origin.x, layout.checkouts.size(), layout.aisles])
	_check(derreks.size() >= 5 and steyhns.size() >= 4, "supermarkten met een ingang: %d DERREK, %d ALFRED STEYHN" % [derreks.size(), steyhns.size()])
	_check(shops.all(func(way_in: Dictionary) -> bool: return int(way_in.width) >= 4 and int(way_in.width) <= 9), "elke gevel 4 tot 9 cellen breed")
	# every branch of a chain laid out its own way (the tiles and where they stand)
	var layouts := {}
	for way_in: Dictionary in shops:
		layouts[str(Layout.plan(String(way_in.kind), int(way_in.seed), int(way_in.width)).tiles)] = true
	_check(layouts.size() == shops.size(), "elk filiaal een eigen indeling (%d van %d)" % [layouts.size(), shops.size()])
	if derreks.is_empty() or steyhns.is_empty():
		_finish()
		return
	await _derrek(derreks)
	await _alfred_steyhn(steyhns)
	_finish()


func _derrek(derreks: Array) -> void:
	print("DERREK:")
	var way_in: Dictionary = derreks[0]
	var shop := await _go_in(way_in)
	if shop == null:
		return
	var plan: Dictionary = shop.plan
	_check(is_equal_approx(float(plan.width), clampi(int(way_in.width), 4, 7) * 4.0), "zo breed als de gevel (%d m)" % int(plan.width))
	var exit: Node3D = _interiors._exits["derrek"][0]
	_check(exit.global_position.distance_to(shop.to_global((plan.door as Transform3D).origin)) < 0.1, "de uitgang bij de ingang van dit filiaal")
	_check(shop.get_node("Indeling/Inrichting").get_used_cells().size() > 40, "ingericht (%d tiles)" % shop.get_node("Indeling/Inrichting").get_used_cells().size())
	var cashiers: Array = shop.people().filter(func(person: Node) -> bool: return person.role == "kassamedewerker")
	_check(cashiers.size() >= 2 and cashiers.all(func(person: Node) -> bool: return person.sitting), "caissières aan de kassa's (%d)" % cashiers.size())
	_check(shop.people().any(func(person: Node) -> bool: return person.role == "medewerker_derrek"), "een medewerker in het rood")
	# the trolley
	await _stand_at(shop, plan.cart_at)
	_check(_actions() == [["E", "Karretje pakken"]], "bij de karretjes: [E] Karretje pakken (%s)" % [_actions()])
	_use()
	await process_frame
	_check(shop.carrier() == "karretje" and _player.has_node("Winkelkarretje"), "karretje gepakt, voor de speler")
	# three things from one shelf
	var drinks := (plan.shelves as Array).filter(func(shelf: Dictionary) -> bool: return shelf.category == "drank")
	var shelf: Dictionary = drinks[0] if not drinks.is_empty() else plan.shelves[0]
	await _stand_at(shop, shelf.at)
	var shelf_action := _actions()
	print("  ", shelf_action)
	_check(not shelf_action.is_empty() and String(shelf_action[0][1]).begins_with("Pakken: DERREK"), "bij het schap: [E] Pakken (het huismerk)")
	for take in 3:
		_use()
		await process_frame
		await _stand_at(shop, shelf.at)
	_check(shop.goods().size() == 3, "drie dingen in het karretje (%d)" % shop.goods().size())
	_check(_player.get_node("Winkelkarretje/Spullen").get_child_count() == 3, "te zien in het karretje")
	# out without paying: thrown out
	var money_before: float = _player.money
	var inventory_before: Dictionary = _player.inventory.duplicate()
	await _stand_at(shop, (plan.door as Transform3D).origin)
	_check(_actions() == [["E", "Naar buiten"]], "bij de deur: [E] Naar buiten")
	_use()
	for wait in 80:
		await create_timer(0.1, true).timeout
		_skip_story()
		if not _interiors.is_inside() and not _interiors._throwing:
			break
	_check(not _interiors.is_inside(), "met onbetaalde spullen de deur uit: eruit gegooid")
	_check(int(_interiors._barred_until.get("derrek", 0)) > Time.get_ticks_msec(), "en voorlopig niet meer welkom")
	_check(is_equal_approx(_player.money, money_before) and _player.inventory == inventory_before, "niets betaald, niets gekregen")
	_check(shop.goods().is_empty() and not _player.has_node("Winkelkarretje"), "het karretje bleef binnen")
	_interiors._barred_until.clear()
	for wait in 30:
		await create_timer(0.1, true).timeout
		_skip_story()
	# in again: a basket, things in it, paying
	shop = await _go_in(way_in)
	plan = shop.plan
	await _stand_at(shop, plan.basket_at)
	_use()
	await process_frame
	_check(shop.carrier() == "mandje" and _player.has_node("Winkelmandje"), "mandje gepakt, aan de arm")
	var categories := {}
	for one: Dictionary in plan.shelves:
		if shop.product(one.category).size() > 0 and not categories.has(one.category) and categories.size() < 5:
			categories[one.category] = one
	for category: String in categories:
		await _stand_at(shop, categories[category].at)
		print("  bij %s: %s" % [category, _actions()])
		_use()
		await process_frame
	var picked: Array = shop.goods().duplicate()
	print("  in het mandje: ", picked.map(func(thing: Dictionary) -> String: return "%s %.2f" % [thing.name, thing.price]))
	_check(picked.size() == mini(categories.size(), shop.capacity()), "uit %d schappen in het mandje (%d)" % [categories.size(), picked.size()])
	var checkout: Dictionary = plan.checkouts[0]
	await _stand_at(shop, checkout.pay_at)
	_check(_actions() == [["E", "Afrekenen"]], "bij de kassa: [E] Afrekenen")
	_use()
	await process_frame
	var box: Control = _hud._story_box
	_check(box.is_showing() and not box._current_choices().is_empty(), "de caissière zegt wat het kost, betalen of laat maar")
	print("  kassa: ", box._pages[0].text if not box._pages.is_empty() else "")
	box.hide()
	box._pages = []
	paused = false
	# too little money for all of it: the dearest go back, the rest is paid to the cent
	picked.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.price) > float(second.price))
	var cheapest_two: float = float(picked[-1].price) + float(picked[-2].price) if picked.size() >= 2 else 0.0
	_player.money = cheapest_two + 0.01
	_player.inventory = {}
	var pages: Array = shop.settle(shop.chain().kassa, null, false)
	for page: Dictionary in pages:
		print("  kassa: ", page.text)
	_check(is_equal_approx(_player.money, 0.01), "precies betaald wat er paste (over: %.2f)" % _player.money)
	var in_pockets := 0
	for item_id: String in _player.inventory:
		in_pockets += int(_player.inventory[item_id])
	_check(in_pockets == 2, "de twee goedkoopste in de zakken (%d)" % in_pockets)
	_check(pages.size() >= 2 and String(pages[0].text).contains(String(picked[0].name)), "de duurste teruggelegd en dat gezegd")
	_check(shop.goods().is_empty(), "het mandje leeg na het afrekenen")
	await _shoppers(shop)
	await _go_out(shop)
	# another DERREK: laid out differently
	if derreks.size() > 1:
		var other: Dictionary = derreks[derreks.size() - 1]
		shop = await _go_in(other)
		if shop:
			var second: Dictionary = shop.plan
			var same: bool = str(second.tiles) == str(plan.tiles)
			print("  ander filiaal: %d x %d m, %d kassa's (was %d x %d, %d)" % [int(second.width), int(second.depth), second.checkouts.size(),
				int(plan.width), int(plan.depth), plan.checkouts.size()])
			_check(not same, "een ander filiaal is anders ingedeeld")
			await _go_out(shop)


func _alfred_steyhn(steyhns: Array) -> void:
	print("ALFRED STEYHN:")
	var shop := await _go_in(steyhns[0])
	if shop == null:
		return
	var plan: Dictionary = shop.plan
	_check(plan.checkouts.any(func(checkout: Dictionary) -> bool: return checkout.self_scan), "zelfscankassa's (%d)" % int(plan.self_scans))
	_check(shop._bonus.size() == 2, "twee soorten schappen in de bonus %s" % [shop._bonus])
	if not shop._bonus.is_empty():
		var category: String = shop._bonus[0]
		var full := float(shop.chain().producten[category].prijs)
		var with_bonus := float(shop.product(category).price)
		_check(with_bonus < full and is_equal_approx(with_bonus, snappedf(full * 0.75, 0.01)), "bonus: %s %.2f in plaats van %.2f" % [category, with_bonus, full])
	_check(shop.people().any(func(person: Node) -> bool: return person.role == "medewerker_alfred_steyhn"), "een medewerker in het lichtblauw")
	var self_scan: Dictionary = (plan.checkouts as Array).filter(func(checkout: Dictionary) -> bool: return checkout.self_scan)[0]
	await _stand_at(shop, plan.basket_at)
	_use()
	await process_frame
	var bakery := (plan.shelves as Array).filter(func(shelf: Dictionary) -> bool: return shelf.category == "bakkerij")
	_check(not bakery.is_empty(), "een bakkerij")
	if not bakery.is_empty():
		await _stand_at(shop, bakery[0].at)
		_use()
		await process_frame
	_player.money = 10.0
	_player.inventory = {}
	await _stand_at(shop, self_scan.pay_at)
	_check(_actions() == [["E", "Afrekenen"]], "bij de zelfscan: [E] Afrekenen")
	var pages: Array = shop.settle(shop.chain().zelfscan, null, true)
	_check(int(_player.inventory.get("croissant", 0)) == 1 and _player.money < 10.0, "een croissant gekocht bij de zelfscan (€ %.2f over)" % _player.money)
	print("  zelfscan: ", pages[-1].text if not pages.is_empty() else "")
	await _go_out(shop)


## Lets the shoppers run SIMULATED seconds (their _process in steps), and checks what they did.
func _shoppers(shop: Node3D) -> void:
	var at_start: int = shop.shoppers().size()
	var boxes: Array[AABB] = Supermarket.footprints(shop.plan, load(Supermarket.LIBRARY), load(Supermarket.PROPS_LIBRARY))
	var inner := boxes.filter(func(box: AABB) -> bool:
		return box.position.x > -float(shop.plan.width) * 0.5 + 0.2 and box.end.x < float(shop.plan.width) * 0.5 - 0.2 \
			and box.position.z > -float(shop.plan.depth) * 0.5 + 0.2 and box.end.z < float(shop.plan.depth) * 0.5 - 0.2)
	var samples := 0
	var through := 0
	var most := 0
	var steps := int(SIMULATED / SIMULATION_STEP)
	for step in steps:
		shop._process(SIMULATION_STEP)
		most = maxi(most, shop.shoppers().size())
		if step % 10 == 0:
			for shopper: Dictionary in shop.shoppers():
				var person: Node3D = shopper.person
				samples += 1
				var feet := AABB(person.position + Vector3(-0.05, 0.3, -0.05), Vector3(0.1, 0.5, 0.1))
				if inner.any(func(box: AABB) -> bool: return (box as AABB).grow(-0.05).intersects(feet)):
					through += 1
		if step % 25 == 0:
			await process_frame   # the figures of the next shoppers are built on a thread
	print("  winkelend: %d bij binnenkomst, hooguit %d tegelijk; %s" % [at_start, most, shop.stats])
	_check(at_start >= 2, "er wordt al gewinkeld als je binnenkomt (%d)" % at_start)
	_check(int(shop.stats.binnen) >= 3, "er komen mensen binnenlopen (%d)" % int(shop.stats.binnen))
	_check(int(shop.stats.betaald) >= 2, "ze rekenen af bij de kassa (%d)" % int(shop.stats.betaald))
	_check(int(shop.stats.weg) >= 3, "en gaan weer weg (%d)" % int(shop.stats.weg))
	_check(most <= shop.most_shoppers(), "niet meer dan er passen (%d van %d)" % [most, shop.most_shoppers()])
	_check(through <= samples / 50, "ze lopen niet door de schappen (%d van %d keer)" % [through, samples])


func _go_in(way_in: Dictionary) -> Node3D:
	_player.teleport(way_in.door, 0.0)
	for frame_index in 4:
		await physics_frame
	_check(_actions() == [["E", "Naar binnen"]], "%s: bij de ingang [E] Naar binnen" % way_in.name)
	_use()
	await create_timer(1.3, true).timeout
	_skip_story()
	var shop: Node3D = _interiors._interior
	_check(_interiors.is_inside() and shop != null and shop.has_method("chain"), "%s: binnen" % way_in.name)
	if shop == null or not shop.has_method("chain"):
		return null
	_check(String(shop.brand) == String(way_in.kind), "de huisstijl van %s" % way_in.name)
	for frame_index in 10:
		await physics_frame
	_check(_player._fits(_player.global_position), "binnen staat de speler vrij")
	return shop


func _go_out(shop: Node3D) -> void:
	await _stand_at(shop, (shop.plan.door as Transform3D).origin)
	_use()
	await create_timer(1.3, true).timeout
	_skip_story()
	_check(not _interiors.is_inside(), "weer buiten")


## The player at `at` (in the shop's space), a few physics frames for the actions.
func _stand_at(shop: Node3D, at: Vector3) -> void:
	_player.teleport(shop.to_global(at), 0.0)
	_player._talk_partner = null
	for frame_index in 3:
		await physics_frame


func _actions() -> Array:
	return _hud._action_prompts.actions() if _hud._action_prompts.visible else []


func _use() -> void:
	if _player._talk_partner and _player._talk_partner.has_method("go_through"):
		_player._talk_partner.go_through()


func _skip_story() -> void:
	var box: Control = _hud._story_box
	for attempt in 6:
		if not box.is_showing():
			return
		box._pages = box._pages.slice(-1)
		box._page_index = 0
		box._next_page()


func _finish() -> void:
	print("supermarkt ok" if _problems.is_empty() else "supermarkt problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
