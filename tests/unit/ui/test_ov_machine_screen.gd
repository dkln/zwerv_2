extends RefCounted
## Unit tests of the OV-chipkaart machine (scripts/ui/machines/ov_machine_screen.gd) on its
## own, without the swipe (animate off) and with a stand-in player (a wallet, pockets, `buy`):
## its choices without and with a card, buying a card or a single ticket, topping up, what
## it says when that cannot be (too little money, full pockets, a card already), the keys,
## its pockets panel and where it stands (the station or the street).
##   tests/run_unit_tests.sh ov_machine

const OvMachineScreen = preload("res://scripts/ui/machines/ov_machine_screen.gd")
const OvCard = preload("res://scripts/world/station/ov_card.gd")
const MachineScreen = preload("res://scripts/ui/machines/machine_screen.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A wallet and pockets that buy, as OvCard asks of the player.
class TestPlayer:
	extends Node
	var money := 20.0
	var inventory := {}
	var slots := 4

	func buy(item_id: String, price: float) -> String:
		if money + 0.001 < price:
			return "geld"
		if not inventory.has(item_id) and inventory.size() >= slots:
			return "vol"
		money -= price
		inventory[item_id] = int(inventory.get(item_id, 0)) + 1
		return "ok"

	func add_money(amount: float) -> void:
		money += amount


func _player(money := 20.0) -> TestPlayer:
	var player := TestPlayer.new()
	player.money = money
	tree.root.add_child(player)
	return player


## The screen left and gone at once (close only queues it; a next machine needs its name
## free), the pause back and the player gone.
func _tidy(screen: Node, player: Node, was_paused: bool) -> void:
	if is_instance_valid(screen):
		screen.close()
		screen.free()
	tree.paused = was_paused
	player.free()


static func _option_texts(screen: Node) -> Array:
	var texts := []
	for option: Button in screen._options:
		if option.visible:
			texts.append(option.text)
	return texts


func test_where_it_stands_and_its_parts(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var station: Node = OvMachineScreen.show_for(player, "Den Haag Centraal", false)
	test.check(station != null and station.brand == "OV-CHIPKAART" and station.backdrop == "station" and station.place_name == "Den Haag Centraal",
		"op Den Haag Centraal: de stationshal erachter")
	test.check(is_equal_approx(station.screen_controls_width, 360.0) and station._controls.custom_minimum_size.x == 360.0, "brede knoppen voor zijn lange keuzes")
	var parts: Dictionary = station.machine_parts()
	test.check(parts.mesh is Mesh and parts.screen is Rect2 and parts.keys is Vector3 and parts.slot is Vector3 and float(parts.front) > 0.0,
		"een model met scherm, toetsen en gleuf")
	test.check((parts.screen as Rect2).size.x > 0.0 and (parts.screen as Rect2).position.y > (parts.slot as Vector3).y, "het scherm boven de gleuf")
	test.check(station.stage_parts().machine.mesh != null, "het model staat in de scène")
	test.check(station.key_hints() == "[1-4] KIEZEN   [ESC] STOPPEN", "de toetsen onderaan")
	_tidy(station, player, was_paused)
	var street_player := _player()
	var street: Node = OvMachineScreen.show_for(street_player, "Halte Spui", false)
	test.check(street.backdrop == "straat", "bij een halte: de straat erachter")
	_tidy(street, street_player, was_paused)


func test_without_a_card_you_can_buy_one_or_a_ticket(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = OvMachineScreen.show_for(player, "", false)
	test.check(screen._display_title.text == "MAAK UW KEUZE" and screen._display_text.text.contains("nog geen OV-chipkaart"), "het scherm: je hebt nog geen kaart")
	test.check(_option_texts(screen) == ["[1] OV-CHIPKAART KOPEN  € 7,50", "[2] LOS KAARTJE  € 3,50"], "een kaart kopen of een los kaartje (%s)" % [_option_texts(screen)])
	test.check(screen.pocket_lines()[1] == ["Geen OV-chipkaart", UiStyle.MUTED], "in je zakken: geen kaart")
	test.check(screen.top_up(5.0) == "geen_kaart" and screen._display_text.text.contains("Dat kan niet.") and player.money == 20.0, "opladen zonder kaart kan niet")
	test.check(screen.buy_card() == "ok", "een kaart kopen")
	test.check(is_equal_approx(player.money, 20.0 - OvCard.CARD_PRICE) and OvCard.has_card(player) and is_equal_approx(OvCard.balance(player), OvCard.START_BALANCE),
		"betaald, in je zakken, met het beginsaldo erop")
	test.check(screen._tray_title.text == "OV-CHIPKAART" and (screen.stage_parts().came_out as Array).size() == 1, "de kaart komt uit de automaat")
	test.check(screen._display_text.text.contains("Betaald. Goede reis!") and screen._display_title.get_theme_color("font_color") == MachineScreen.GOOD, "het scherm bedankt")
	test.check(screen._display_text.text.contains("Saldo op uw kaart: € 2,50"), "en toont nu het saldo")
	test.check(screen.pocket_lines()[1] == ["OV-chipkaart", UiStyle.ACCENT] and not screen._busy, "de kaart in je zakken")
	test.check(screen.buy_card() == "heb_al" and screen._display_text.text.contains("Je hebt al een kaart."), "nog een kaart kopen kan niet")
	test.check(screen._display_title.get_theme_color("font_color") == MachineScreen.WARNING, "in de kleur van een waarschuwing")
	_tidy(screen, player, was_paused)


func test_with_a_card_you_top_it_up(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	player.inventory[OvCard.CARD_ITEM] = 1
	player.set_meta(OvCard.BALANCE_META, 1.0)
	var screen: Node = OvMachineScreen.show_for(player, "", false)
	test.check(_option_texts(screen) == ["[1] OPLADEN  € 5,00", "[2] OPLADEN  € 10,00", "[3] OPLADEN  € 20,00", "[4] LOS KAARTJE  € 3,50"],
		"opladen met de drie bedragen, en een los kaartje (%s)" % [_option_texts(screen)])
	test.check(screen.top_up(10.0) == "ok" and is_equal_approx(player.money, 10.0) and is_equal_approx(OvCard.balance(player), 11.0), "€ 10 erop, uit je portemonnee")
	test.check(screen._tray_title.text == "OPGELADEN" and screen._display_text.text.contains("Saldo op uw kaart: € 11,00"), "opgeladen: het nieuwe saldo op het scherm")
	test.check(screen.top_up(20.0) == "geld" and screen._display_text.text.contains("Te weinig geld.") and is_equal_approx(OvCard.balance(player), 11.0),
		"€ 20 met € 10 op zak: te weinig geld")
	test.check(_option_texts(screen).size() == 4, "de keuzes staan er nog")
	_tidy(screen, player, was_paused)


func test_a_single_ticket_and_full_pockets(test) -> void:
	var player := _player(8.0)
	var was_paused := tree.paused
	var screen: Node = OvMachineScreen.show_for(player, "", false)
	test.check(screen.buy_ticket() == "ok" and int(player.inventory.get(OvCard.TICKET_ITEM, 0)) == 1 and is_equal_approx(player.money, 4.5), "een los kaartje gekocht")
	test.check(screen._tray_title.text == "LOS KAARTJE", "het komt uit de automaat")
	test.check(screen.pocket_lines().any(func(line: Array) -> bool: return line[0] == "Los kaartje  1×"), "en staat bij je zakken")
	test.check(screen.buy_card() == "geld" and not OvCard.has_card(player), "voor een kaart is er nu te weinig geld")
	player.money = 50.0
	player.slots = 1
	test.check(screen.buy_card() == "vol" and screen._display_text.text.contains("Je zakken zitten vol.") and player.money == 50.0, "volle zakken: geen kaart, niets betaald")
	test.check(screen.buy_ticket() == "ok" and int(player.inventory[OvCard.TICKET_ITEM]) == 2, "nog een kaartje past in hetzelfde vakje")
	_tidy(screen, player, was_paused)


func test_the_keys_and_the_buttons_choose(test) -> void:
	var player := _player()
	var was_paused := tree.paused
	var screen: Node = OvMachineScreen.show_for(player, "", false)
	test.check(screen._key(KEY_3) and screen._key(KEY_4) and player.money == 20.0, "een keuze die er niet staat: niets")
	screen._key(KEY_2)
	test.check(int(player.inventory.get(OvCard.TICKET_ITEM, 0)) == 1, "2: een los kaartje")
	screen._key(KEY_KP_1)
	test.check(OvCard.has_card(player), "1 (numeriek): de kaart")
	screen._options[0].pressed.emit()
	test.check(is_equal_approx(OvCard.balance(player), OvCard.START_BALANCE + 5.0), "een klik op de eerste keuze: nu € 5 opladen")
	test.check(screen._key(KEY_Q) and is_equal_approx(player.money, 20.0 - 3.5 - 7.5 - 5.0), "een andere toets is van de automaat maar doet niets")
	var stop := screen._controls.get_children().back() as Button
	test.check(stop.text == "[ESC] STOPPEN", "de laatste knop stopt")
	stop.pressed.emit()
	test.check(screen.is_closing() and tree.paused == was_paused, "en de automaat sluit")
	_tidy(screen, player, was_paused)
