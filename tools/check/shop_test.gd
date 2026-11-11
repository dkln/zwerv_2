extends SceneTree
## The shop screen (scripts/ui/shop_screen.gd, GameHud.show_shop): talking to the one behind
## the counter of a snack bar opens it (not the story box) with the menu of
## data/gesprekken/snackbarhouder.json and the merchant's music; too little money shows
## TE WEINIG GELD and buys nothing; with money a kroket is bought (money off, in the pockets)
## and that finishes mission 1; full pockets say so; leaving closes it and the game goes on.
## In Den Haag Centraal the sellers can be talked to from before their shop (across the
## counter), each with the goods of its kind (data/gesprekken/winkels.json): a kiosk sells a
## newspaper, Smikkels its own (dearer) kroket; the music is the merchant's while the shop
## is open, and back to what it was after.
## usage: tools/godot.sh --headless --script tools/check/shop_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
const ShopScreen = preload("res://scripts/ui/shop_screen.gd")
const Items = preload("res://scripts/player/items.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	_check_station_prices()
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var hud: Node = scene.get_node("HUD")
	var follow: Node = scene.get_node("Volgcamera")
	follow._end_arrival()
	for frame_index in 600:
		await physics_frame
		if player._placed and not player._sleeping:
			break
	player._wake_up()
	for attempt in 40:
		if not player._sleeping:
			break
		await create_timer(0.1, true).timeout
	for frame_index in 120:
		await process_frame
		_skip_story(hud)
	var interiors: Node = scene.get_node("Binnenruimtes")
	var story: Node = scene.get_node("Verhaal")
	var shop: Control = hud._shop_screen
	_check(shop != null, "de HUD heeft een winkelscherm")

	# ---------------------------------------------------------------- a snack bar
	var bars: Array = interiors.snack_bars()
	_check(not bars.is_empty(), "snackbars")
	if bars.is_empty():
		_finish()
		return
	interiors.enter(bars[0])
	await create_timer(1.2, true).timeout
	var interior: Node3D = interiors._interior
	var keepers: Array = interior.people().filter(func(person: Node) -> bool: return person.role == "snackbarhouder")
	_check(keepers.size() == 1, "iemand achter de toonbank")
	if keepers.is_empty():
		_finish()
		return
	var keeper: Node3D = keepers[0]
	_check(Conversations.is_merchant(keeper), "de snackbarhouder verkoopt")
	_check(keeper.action_text() == "Bestellen", "bij de snackbarhouder: [E] Bestellen in plaats van Praten")
	# no money: nothing bought, the notice
	player.add_money(-player.money)
	player.talk_to(keeper)
	await process_frame
	_check(hud.is_showing_shop() and not hud.is_showing_story(), "praten met de snackbarhouder opent het winkelscherm")
	_check(paused, "het spel staat stil in de winkel")
	_check(String(hud._indoor_music) == ShopScreen.SHOP_MUSIC, "de muziek van de handelaar (%s)" % hud._indoor_music)
	var goods: Array = shop._rows.filter(func(row: Dictionary) -> bool: return row.kind == "kopen")
	print("snackbar: %s / %s: %s" % [shop._kind_label.text, shop._name_label.text, goods.map(func(row: Dictionary) -> String: return "%s € %.2f" % [row.item, row.price])])
	_check(shop._name_label.text == String(bars[0].name).to_upper(), "de naam van de snackbar bovenin (%s)" % shop._name_label.text)
	_check(shop._logo_badge.visible and shop._logo_icon.bitmap == GameMenu.ITEM_ICONS["kroket"].rows, "het logo van de snackbar in het scherm (een kroket)")
	_check(goods.size() == 3 and goods[0].item == "kroket" and is_equal_approx(goods[0].price, 2.0), "de kaart van snackbarhouder.json (kroket € 2)")
	_check(shop._rows.any(func(row: Dictionary) -> bool: return row.kind == "weg"), "een rij om weg te gaan")
	print("  begroeting: ", shop.spoken_text())
	_check(shop.spoken_text() != "", "een begroeting")
	var result: String = shop.buy(0)
	print("  zonder geld: %s, %s / %s" % [result, shop.notice_text(), shop.spoken_text()])
	_check(result == "geld" and shop.notice_text() == "TE WEINIG GELD", "te weinig geld: de melding")
	_check(int(player.inventory.get("kroket", 0)) == 0 and is_zero_approx(player.money), "te weinig geld: niets gekocht")
	_check(shop.spoken_text().contains("€ 2,00"), "de snackbarhouder noemt de prijs")
	# with money: a kroket, mission 1
	player.add_money(5.0)
	story.complete_step("missie_1_kroket", "kleingeld")
	_skip_story(hud)
	var money_before: float = player.money
	# Enter on the chosen row (the first: the kroket), as the keys do
	shop._choose(0, false)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	_check(shop.handle_input(enter), "Enter in de winkel")
	print("  gekocht: ", shop.spoken_text())
	_check(is_equal_approx(player.money, money_before - 2.0) and int(player.inventory.get("kroket", 0)) == 1, "een kroket gekocht (€ 2 eraf, in je zakken)")
	_check(story.step_done("missie_1_kroket", "kroket") and story.is_finished("missie_1_kroket"), "kroket gekocht: missie 1 klaar")
	_check(shop.notice_text() == "", "na het kopen geen melding meer")
	# the mission's pages over the shop, then the shop again
	_check(hud.is_showing_story(), "de missiepagina's over de winkel heen")
	_skip_story(hud)
	await process_frame
	_check(hud.is_showing_shop() and paused, "daarna nog in de winkel")
	# full pockets: nothing paid
	for kind_index in 6:
		player.inventory["vulsel_%d" % kind_index] = 1
	money_before = player.money
	result = shop.buy(1)
	_check(result == "vol" and shop.notice_text() == "ZAKKEN VOL" and is_equal_approx(player.money, money_before), "zakken vol: niets betaald")
	for kind_index in 6:
		player.inventory.erase("vulsel_%d" % kind_index)
	# leaving: goodbye, then closed
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	shop.handle_input(escape)
	print("  dag: ", shop.spoken_text())
	await create_timer(4.0, true).timeout
	_skip_story(hud)
	await process_frame
	_check(not hud.is_showing_shop() and not paused, "weggaan sluit de winkel, het spel gaat door")
	_check(String(hud._indoor_music) == ShopScreen.SHOP_MUSIC, "in de snackbar blijft de handelaarsmuziek")
	interiors.leave(1)
	await create_timer(1.2, true).timeout

	# ---------------------------------------------------------------- Den Haag Centraal
	var ways: Array = interiors.ways_in().filter(func(way: Dictionary) -> bool: return way.kind == "centraal")
	_check(not ways.is_empty(), "Centraal heeft een ingang")
	if ways.is_empty():
		_finish()
		return
	interiors.enter(ways[0])
	await create_timer(1.4, true).timeout
	var station: Node3D = interiors._interior
	_check(interiors.is_inside() and station != null and station.has_method("departures"), "binnen in het station")
	if station == null or not station.has_method("departures"):
		_finish()
		return
	var music_in_station := String(hud._indoor_music)
	var sellers: Array = station.people()
	var kinds := {}
	for seller: Node3D in sellers:
		kinds[String(seller.get_meta("kind", ""))] = true
		_check(Conversations.is_merchant(seller), "%s verkoopt (%s)" % [seller.get_meta("shop_name", "?"), seller.role])
	print("verkopers in het station: %d, soorten: %s" % [sellers.size(), kinds.keys()])
	var shops: Dictionary = Conversations.shops().get("winkels", {})
	for kind: String in kinds:
		_check(shops.has(kind), "een assortiment voor %s in winkels.json" % kind)
		for entry: Dictionary in (shops.get(kind, {}) as Dictionary).get("menu", []):
			_check(not Items.item(String(entry.item)).is_empty(), "%s: %s staat in items.gd" % [kind, entry.item])
	# the kiosk: walk up to its front, the seller is the one to talk to (across the counter)
	var kiosk_number := 0
	for number in range(1, sellers.size() + 1):
		var marker := station.get_node_or_null("Verkoper_%d" % number) as Node3D
		if marker and String(marker.get_meta("kind", "")) == "kiosk":
			kiosk_number = number
			break
	_check(kiosk_number > 0, "er is een kiosk")
	if kiosk_number == 0:
		_finish()
		return
	var front := station.get_node("Winkel_%d" % kiosk_number) as Node3D
	var kiosk_seller: Node3D = sellers[kiosk_number - 1]
	player.teleport(front.global_position, front.global_rotation.y)
	for frame_index in 6:
		await physics_frame
	print("  voor de kiosk: %.1f m van de verkoper, partner %s" % [player.global_position.distance_to(kiosk_seller.global_position), player._talk_partner])
	_check(player._talk_partner == kiosk_seller and hud._action_prompts.actions() == [["E", "Winkelen"]], "voor de kiosk: [E] Winkelen bij de verkoper")
	player.inventory.clear()
	player.add_money(20.0 - player.money)
	player.talk_to(kiosk_seller)
	await process_frame
	_check(hud.is_showing_shop(), "praten met de kioskhouder opent het winkelscherm")
	_check(String(hud._indoor_music) == ShopScreen.SHOP_MUSIC, "in het station de muziek van de handelaar zolang de winkel open is")
	goods = shop._rows.filter(func(row: Dictionary) -> bool: return row.kind == "kopen")
	print("kiosk: %s / %s / %s: %s" % [shop._kind_label.text, shop._name_label.text, shop._speaker_label.text, goods.map(func(row: Dictionary) -> String: return "%s € %.2f" % [row.item, row.price])])
	_check(shop._kind_label.text == "KIOSK" and shop._name_label.text == String(kiosk_seller.get_meta("shop_name")).to_upper(), "de kiosk en zijn naam bovenin")
	var newspaper := -1
	for good_index in goods.size():
		if goods[good_index].item == "krant":
			newspaper = good_index
	_check(newspaper >= 0, "de kiosk verkoopt kranten")
	var vendor_face: TownsfolkFigure = shop._portrait._townsfolk if shop._portrait else null
	var vendor_mouths := {}
	for sample in 16:
		await create_timer(0.04, true).timeout
		if shop._typewriter.is_done() or vendor_face == null:
			break
		vendor_mouths[snappedf(vendor_face.mouth_opening(), 0.01)] = true
	print("  mond van de verkoper: ", vendor_mouths.keys())
	_check(vendor_face != null and shop._portrait.source_figure == kiosk_seller.figure and vendor_mouths.size() >= 2, "de verkoper praat met een bewegend mondje en volgt de figuur in de winkel")
	shop._typewriter.finish()
	await create_timer(0.1, true).timeout
	_check(vendor_face != null and is_zero_approx(vendor_face.mouth_opening()), "mondje van de verkoper dicht als de zin er staat")
	print("  begroeting: ", shop.spoken_text())
	result = shop.buy(newspaper)
	print("  krant: %s, € %.2f over: %s" % [result, player.money, shop.spoken_text()])
	_check(result == "ok" and int(player.inventory.get("krant", 0)) == 1 and is_equal_approx(player.money, 20.0 - 3.5), "een krant gekocht (€ 3,50)")
	shop.leave()
	await create_timer(4.0, true).timeout
	_check(not hud.is_showing_shop(), "weg bij de kiosk")
	_check(String(hud._indoor_music) == music_in_station, "daarna de muziek van het station weer (%s)" % hud._indoor_music)
	# Smikkels: a snack bar in the station, its own (dearer) kroket
	var smikkels: Array = sellers.filter(func(seller: Node) -> bool: return String(seller.get_meta("kind", "")) == "smikkels")
	_check(not smikkels.is_empty(), "Smikkels in het station")
	if not smikkels.is_empty():
		var talk := Conversations.new(smikkels[0], player, hud)
		var menu: Array = talk.shop_goods()
		_check(talk.is_shop() and menu[0].item == "kroket" and is_equal_approx(float(menu[0].prijs), 2.75), "Smikkels: een kroket voor € 2,75")
		_check(talk.shop_name() == "Smikkels" and String(talk.shop_greeting().text).find("{") < 0, "Smikkels: de naam in de begroeting")
		_check(not (talk.shop_data_of(smikkels[0]).get("gekocht", []) as Array).is_empty(), "Smikkels: wat het weglaat uit snackbarhouder.json")
	_finish()


## The story's pages out of the way (the prologue, a mission done).
func _skip_story(hud: Node) -> void:
	if hud._story_box.is_showing():
		hud._story_box._pages = hud._story_box._pages.slice(-1)
		hud._story_box._page_index = 0
		hud._story_box._next_page()


func _finish() -> void:
	print("winkel ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)


## Everything at the station costs more than in the town: what the town's snack bar sells
## too costs at least STATION_MARKUP times as much in every shop of Den Haag Centraal.
func _check_station_prices() -> void:
	var town := {}
	for entry: Dictionary in Conversations.counter().get("menu", []):
		town[str(entry.item)] = float(entry.prijs)
	var dearer := true
	var compared := 0
	for kind: String in (Conversations.shops().get("winkels", {}) as Dictionary):
		var seller := Node3D.new()
		seller.set_meta("kind", kind)
		for entry: Dictionary in Conversations.shop_data_of(seller).get("menu", []):
			if town.has(str(entry.item)):
				compared += 1
				if float(entry.prijs) < town[str(entry.item)] * Conversations.STATION_MARKUP - 0.001:
					dearer = false
					print("goedkoper op het station: %s bij %s (%.2f, stad %.2f)" % [entry.item, kind, entry.prijs, town[str(entry.item)]])
		seller.free()
	_check(dearer and compared > 0, "op het station is alles duurder dan in de stad (%d vergeleken)" % compared)
