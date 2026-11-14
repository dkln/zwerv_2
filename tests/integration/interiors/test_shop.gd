extends "res://tests/integration/support/town_test.gd"
## The shop screen (scripts/ui/shop_screen.gd, GameHud.show_shop): talking to the one behind
## the counter of a snack bar opens it (not the story box) with the menu of
## data/gesprekken/snackbarhouder.json and the merchant's music; too little money shows
## TE WEINIG GELD and buys nothing; with money a kroket is bought (money off, in the pockets)
## and that finishes mission 1; full pockets say so; leaving closes it and the game goes on.
## In Den Haag Centraal the sellers can be talked to from before their shop (across the
## counter), each with the goods of its kind (data/gesprekken/winkels.json): a kiosk sells a
## newspaper, Smikkels its own (dearer) kroket; the music is the merchant's while the shop
## is open, and back to what it was after. That the station is dearer than the town:
## tests/unit/interiors/test_station_prices.gd.
##   tests/run_integration_tests.sh shop

const Conversations = preload("res://scripts/story/conversations.gd")
const ShopScreen = preload("res://scripts/ui/shop_screen.gd")
const Items = preload("res://scripts/player/items.gd")


## Into the first snack bar; returns {"bar" (its way in), "keeper" (the one behind the
## counter)}, empty if there is no snack bar or no keeper.
func _into_a_snack_bar() -> Dictionary:
	var bars: Array = interiors.snack_bars()
	if bars.is_empty():
		return {}
	await interiors.enter(bars[0])
	await frames(30)
	var keepers: Array = interiors._interior.people().filter(func(person: Node) -> bool: return person.role == "snackbarhouder")
	return {} if keepers.is_empty() else {"bar": bars[0], "keeper": keepers[0]}


## Into a snack bar with `money` euros and the shop screen opened by talking to the keeper;
## returns what _into_a_snack_bar does.
func _at_the_counter_with(money: float) -> Dictionary:
	var counter := await _into_a_snack_bar()
	if counter.is_empty():
		return {}
	player.add_money(money - player.money)
	await close_screens()   # (a story page that came up on the way in would lie under the shop)
	player.talk_to(counter.keeper)
	await frames(1)
	return counter


## The rows of the shop screen that sell something.
func _goods() -> Array:
	return hud._shop_screen._rows.filter(func(row: Dictionary) -> bool: return row.kind == "kopen")


## Into Den Haag Centraal; returns the station (null if that failed).
func _into_the_station() -> Node3D:
	await enter("centraal")
	await close_screens()   # (as in _at_the_counter_with)
	var station: Node3D = interiors._interior
	return station if station != null and station.has_method("departures") else null


## The keeper of a snack bar is a merchant: [E] Bestellen instead of Praten.
func test_keeper_sells_instead_of_talks(test) -> void:
	test.check(hud._shop_screen != null, "de HUD heeft een winkelscherm")
	test.check(not interiors.snack_bars().is_empty(), "snackbars")
	var counter := await _into_a_snack_bar()
	test.check(not counter.is_empty(), "iemand achter de toonbank")
	if counter.is_empty():
		return
	test.check(Conversations.is_merchant(counter.keeper), "de snackbarhouder verkoopt")
	test.check(counter.keeper.action_text() == "Bestellen", "bij de snackbarhouder: [E] Bestellen in plaats van Praten")


## Talking to the keeper opens the shop screen (not the story box), the game paused, the
## merchant's music on; the screen shows the bar's name and logo, the menu of
## snackbarhouder.json, a row to leave and a greeting.
func test_talking_to_the_keeper_opens_the_shop_screen(test) -> void:
	var counter := await _at_the_counter_with(0.0)
	test.check(not counter.is_empty(), "iemand achter de toonbank")
	if counter.is_empty():
		return
	var shop: Control = hud._shop_screen
	test.check(hud.is_showing_shop() and not hud.is_showing_story(), "praten met de snackbarhouder opent het winkelscherm")
	test.check(tree.paused, "het spel staat stil in de winkel")
	test.check(String(hud.indoor_music()) == ShopScreen.SHOP_MUSIC, "de muziek van de handelaar (%s)" % hud.indoor_music())
	var goods := _goods()
	print("snackbar: %s / %s: %s" % [shop._kind_label.text, shop._name_label.text, goods.map(func(row: Dictionary) -> String: return "%s € %.2f" % [row.item, row.price])])
	test.check(shop._name_label.text == String(counter.bar.name).to_upper(), "de naam van de snackbar bovenin (%s)" % shop._name_label.text)
	test.check(shop._logo_badge.visible and shop._logo_icon.bitmap == GameMenu.ITEM_ICONS["kroket"].rows, "het logo van de snackbar in het scherm (een kroket)")
	test.check(goods.size() == 3 and goods[0].item == "kroket" and is_equal_approx(goods[0].price, 2.0), "de kaart van snackbarhouder.json (kroket € 2)")
	test.check(shop._rows.any(func(row: Dictionary) -> bool: return row.kind == "weg"), "een rij om weg te gaan")
	print("  begroeting: ", shop.spoken_text())
	test.check(shop.spoken_text() != "", "een begroeting")


## Without money nothing is bought: the notice TE WEINIG GELD, and the keeper names the price.
func test_too_little_money_buys_nothing(test) -> void:
	var counter := await _at_the_counter_with(0.0)
	test.check(not counter.is_empty() and hud.is_showing_shop(), "in de winkel van de snackbar")
	if counter.is_empty():
		return
	var shop: Control = hud._shop_screen
	player.inventory.erase("kroket")
	var result: String = shop.buy(0)
	print("  zonder geld: %s, %s / %s" % [result, shop.notice_text(), shop.spoken_text()])
	test.check(result == "geld" and shop.notice_text() == "TE WEINIG GELD", "te weinig geld: de melding")
	test.check(int(player.inventory.get("kroket", 0)) == 0 and is_zero_approx(player.money), "te weinig geld: niets gekocht")
	test.check(shop.spoken_text().contains("€ 2,00"), "de snackbarhouder noemt de prijs")


## With money, Enter on the first row buys a kroket (€ 2 off, in the pockets); eaten (F) it
## ticks off its step of mission 1: its pages show over the shop, and after them you are
## still in the shop.
func test_enter_buys_a_kroket_and_eating_it_ticks_off_mission_1(test) -> void:
	var counter := await _at_the_counter_with(5.0)
	test.check(not counter.is_empty() and hud.is_showing_shop(), "in de winkel van de snackbar")
	if counter.is_empty():
		return
	var shop: Control = hud._shop_screen
	var story: Node = scene.get_node("Verhaal")
	for step_id in ["blikjes", "statiegeld", "bedelen"]:
		story.complete_step("missie_1_lege_maag", step_id)
	skip_story()
	var money_before: float = player.money
	var krokets_before := int(player.inventory.get("kroket", 0))
	# Enter on the chosen row (the first: the kroket), as the keys do
	shop._choose(0, false)
	test.check(shop.handle_input(key_press(KEY_ENTER)), "Enter in de winkel")
	print("  gekocht: ", shop.spoken_text())
	test.check(is_equal_approx(player.money, money_before - 2.0) and int(player.inventory.get("kroket", 0)) == krokets_before + 1, "een kroket gekocht (€ 2 eraf, in je zakken)")
	test.check(shop.notice_text() == "", "na het kopen geen melding meer")
	test.check(not story.step_done("missie_1_lege_maag", "kroket"), "gekocht, nog niet gegeten")
	test.check(player.eat_something() and story.step_done("missie_1_lege_maag", "kroket"), "opgegeten (F): de stap is klaar")
	test.check(hud.is_showing_story(), "de missiepagina's over de winkel heen")
	skip_story()
	await frames(1)
	test.check(hud.is_showing_shop() and tree.paused, "daarna nog in de winkel")


## With full pockets nothing is paid: the notice ZAKKEN VOL.
func test_full_pockets_pay_nothing(test) -> void:
	var counter := await _at_the_counter_with(5.0)
	test.check(not counter.is_empty() and hud.is_showing_shop(), "in de winkel van de snackbar")
	if counter.is_empty():
		return
	var shop: Control = hud._shop_screen
	for filler_index in 6:
		player.inventory["vulsel_%d" % filler_index] = 1
	var money_before: float = player.money
	var result: String = shop.buy(1)
	test.check(result == "vol" and shop.notice_text() == "ZAKKEN VOL" and is_equal_approx(player.money, money_before), "zakken vol: niets betaald")


## Escape says goodbye and then closes the shop: the game goes on, and in the snack bar the
## merchant's music stays.
func test_leaving_closes_the_shop(test) -> void:
	var counter := await _at_the_counter_with(5.0)
	test.check(not counter.is_empty() and hud.is_showing_shop(), "in de winkel van de snackbar")
	if counter.is_empty():
		return
	var shop: Control = hud._shop_screen
	shop.handle_input(key_press(KEY_ESCAPE))
	print("  dag: ", shop.spoken_text())
	await seconds(4.0)
	skip_story()
	await frames(1)
	test.check(not hud.is_showing_shop() and not tree.paused, "weggaan sluit de winkel, het spel gaat door")
	test.check(String(hud.indoor_music()) == ShopScreen.SHOP_MUSIC, "in de snackbar blijft de handelaarsmuziek")


## Every seller in Den Haag Centraal is a merchant, with goods for its kind of shop in
## winkels.json, each of them a known item.
func test_station_sellers_have_goods_of_their_kind(test) -> void:
	test.check(not interiors.ways_in().filter(func(way: Dictionary) -> bool: return way.kind == "centraal").is_empty(), "Centraal heeft een ingang")
	var station := await _into_the_station()
	test.check(interiors.is_inside() and station != null, "binnen in het station")
	if station == null:
		return
	var sellers: Array = station.people()
	var kinds := {}
	for seller: Node3D in sellers:
		kinds[String(seller.get_meta("kind", ""))] = true
		test.check(Conversations.is_merchant(seller), "%s verkoopt (%s)" % [seller.get_meta("shop_name", "?"), seller.role])
	print("verkopers in het station: %d, soorten: %s" % [sellers.size(), kinds.keys()])
	var shops: Dictionary = Conversations.shops().get("winkels", {})
	for kind: String in kinds:
		test.check(shops.has(kind), "een assortiment voor %s in winkels.json" % kind)
		for entry: Dictionary in (shops.get(kind, {}) as Dictionary).get("menu", []):
			test.check(not Items.item(String(entry.item)).is_empty(), "%s: %s staat in items.gd" % [kind, entry.item])


## The kiosk in the station: from before the shop the seller is the one to talk to (across
## the counter, [E] Winkelen); the shop screen shows the kiosk and its name, the seller
## talks with a moving mouth, a newspaper is bought (€ 3,50), and the merchant's music plays
## only while the shop is open.
func test_kiosk_sells_a_newspaper_across_the_counter(test) -> void:
	var station := await _into_the_station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var shop: Control = hud._shop_screen
	var music_in_station := String(hud.indoor_music())
	var sellers: Array = station.people()
	var kiosk_number := 0
	for seller_number in range(1, sellers.size() + 1):
		var marker := station.get_node_or_null("Verkoper_%d" % seller_number) as Node3D
		if marker and String(marker.get_meta("kind", "")) == "kiosk":
			kiosk_number = seller_number
			break
	test.check(kiosk_number > 0, "er is een kiosk")
	if kiosk_number == 0:
		return
	var front := station.get_node("Winkel_%d" % kiosk_number) as Node3D
	var kiosk_seller: Node3D = sellers[kiosk_number - 1]
	await stand_at(front.global_position, front.global_rotation.y)
	print("  voor de kiosk: %.1f m van de verkoper, partner %s" % [player.global_position.distance_to(kiosk_seller.global_position), player._talk_partner])
	test.check(player._talk_partner == kiosk_seller and prompts() == [["E", "Winkelen"]], "voor de kiosk: [E] Winkelen bij de verkoper")
	player.inventory.clear()
	player.add_money(20.0 - player.money)
	player.talk_to(kiosk_seller)
	await frames(1)
	test.check(hud.is_showing_shop(), "praten met de kioskhouder opent het winkelscherm")
	test.check(String(hud.indoor_music()) == ShopScreen.SHOP_MUSIC, "in het station de muziek van de handelaar zolang de winkel open is")
	var goods := _goods()
	print("kiosk: %s / %s / %s: %s" % [shop._kind_label.text, shop._name_label.text, shop._speaker_label.text, goods.map(func(row: Dictionary) -> String: return "%s € %.2f" % [row.item, row.price])])
	test.check(shop._kind_label.text == "KIOSK" and shop._name_label.text == String(kiosk_seller.get_meta("shop_name")).to_upper(), "de kiosk en zijn naam bovenin")
	var newspaper := -1
	for good_index in goods.size():
		if goods[good_index].item == "krant":
			newspaper = good_index
	test.check(newspaper >= 0, "de kiosk verkoopt kranten")
	var vendor_face: TownsfolkFigure = shop._portrait._townsfolk if shop._portrait else null
	var vendor_mouths := {}
	for sample in 16:
		await seconds(0.04)
		if shop._typewriter.is_done() or vendor_face == null:
			break
		vendor_mouths[snappedf(vendor_face.mouth_opening(), 0.01)] = true
	print("  mond van de verkoper: ", vendor_mouths.keys())
	test.check(vendor_face != null and shop._portrait.source_figure == kiosk_seller.figure and vendor_mouths.size() >= 2, "de verkoper praat met een bewegend mondje en volgt de figuur in de winkel")
	shop._typewriter.finish()
	await seconds(0.1)
	test.check(vendor_face != null and is_zero_approx(vendor_face.mouth_opening()), "mondje van de verkoper dicht als de zin er staat")
	print("  begroeting: ", shop.spoken_text())
	var result: String = shop.buy(newspaper)
	print("  krant: %s, € %.2f over: %s" % [result, player.money, shop.spoken_text()])
	test.check(result == "ok" and int(player.inventory.get("krant", 0)) == 1 and is_equal_approx(player.money, 20.0 - 3.5), "een krant gekocht (€ 3,50)")
	skip_story()   # (a page of the story over the shop would keep it open)
	shop.leave()
	await wait_until(func() -> bool:
		skip_story()
		return not hud.is_showing_shop(), 8.0)
	print("  afscheid: %s (verhaal %s)" % [shop.spoken_text(), hud.is_showing_story()])
	test.check(not hud.is_showing_shop(), "weg bij de kiosk")
	test.check(String(hud.indoor_music()) == music_in_station, "daarna de muziek van het station weer (%s)" % hud.indoor_music())


## Smikkels, a snack bar in the station: its own (dearer) kroket, its name in the greeting,
## and what it leaves out of snackbarhouder.json.
func test_smikkels_sells_its_own_dearer_kroket(test) -> void:
	var station := await _into_the_station()
	test.check(station != null, "binnen in het station")
	if station == null:
		return
	var smikkels: Array = station.people().filter(func(seller: Node) -> bool: return String(seller.get_meta("kind", "")) == "smikkels")
	test.check(not smikkels.is_empty(), "Smikkels in het station")
	if smikkels.is_empty():
		return
	var talk := Conversations.new(smikkels[0], player, hud)
	var menu: Array = talk.shop_goods()
	test.check(talk.is_shop() and menu[0].item == "kroket" and is_equal_approx(float(menu[0].prijs), 2.75), "Smikkels: een kroket voor € 2,75")
	test.check(talk.shop_name() == "Smikkels" and String(talk.shop_greeting().text).find("{") < 0, "Smikkels: de naam in de begroeting")
	test.check(not (talk.shop_data_of(smikkels[0]).get("gekocht", []) as Array).is_empty(), "Smikkels: wat het weglaat uit snackbarhouder.json")
