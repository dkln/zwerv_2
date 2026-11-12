extends SceneTree
## The machines and what you find for them, headless and without the town (fast): the real
## PlayerController with a stand-in HUD, the machine screens without the swipe (animate off).
## - found bank cards (BankCards): a PIN of four digits, a modest balance, a riddle whose
##   answer is that PIN (worked out again from the text, for many cards of every kind); a
##   card given to the player (PlayerController.give_found_bank_card) is a "pinpas" in the
##   pockets, each card its own account;
## - the cash machine (CashMachineScreen): a wrong PIN is refused, the right one lets you in,
##   no more than the balance comes out, what comes out is in the wallet and off the
##   balance; three wrong PINs and the card is kept (gone from the pockets);
## - the deposit machine (DepositMachineScreen): cans and bottles one by one, 15 cents each,
##   gone from the pockets, the bon pays the total out;
## - the OV-chipkaart (OvCard, OvMachineScreen): buying needs the money, a new card has its
##   balance, checking in costs the fare, topping up, a single ticket kept at check-out;
## - the models of the machines (MachineModels): their size, a collider as big as the mesh.
## usage: tools/godot.sh --headless --script tools/check/machines_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")
const DepositReturn = preload("res://scripts/world/deposit_return.gd")
const OvCard = preload("res://scripts/world/ov_card.gd")
const MachineModels = preload("res://scripts/world/machine_models.gd")
const CashMachineScreen = preload("res://scripts/ui/machines/cash_machine_screen.gd")
const DepositMachineScreen = preload("res://scripts/ui/machines/deposit_machine_screen.gd")
const OvMachineScreen = preload("res://scripts/ui/machines/ov_machine_screen.gd")
const CARDS_TRIED := 400

const STAND_IN_HUD := """extends Node
var money := -1.0
func set_money(euros: float) -> void:
	money = euros
func show_floating_number(_at: Vector3, _text: String, _colour: Color, _size := 16, _over := false) -> void:
	pass
"""

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 90)
	PlayerCharacter.choose("jos")
	await process_frame
	_riddles_give_the_pin()
	var town := await _town()
	var player: Node = town.get_node("Speler")
	player.set("has_backpack", true)   # room for everything
	await _found_cards(player)
	await _cash_machine(player)
	await _deposit_machine(player)
	await _ov_card(player)
	_models()
	town.free()
	print("automaten ok" if _problems.is_empty() else "automaten problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _town() -> Node3D:
	var town := Node3D.new()
	town.name = "Stad"
	var hud_script := GDScript.new()
	hud_script.source_code = STAND_IN_HUD
	hud_script.reload()
	var hud := Node.new()
	hud.name = "HUD"
	hud.set_script(hud_script)
	town.add_child(hud)
	var player := PlayerController.new()
	player.name = "Speler"
	town.add_child(player)
	get_root().add_child(town)
	await process_frame
	return town


## Every kind of riddle, worked out from its text, gives its PIN.
func _riddles_give_the_pin() -> void:
	print("raadsels en pincodes:")
	var random := RandomNumberGenerator.new()
	random.seed = 12345
	var wrong := 0
	var first_wrong := ""
	var lowest := INF
	var highest := 0.0
	var kinds := {}
	for index in CARDS_TRIED:
		var card := BankCards.make_card(random)
		var pin := String(card.pin)
		lowest = minf(lowest, float(card.saldo))
		highest = maxf(highest, float(card.saldo))
		var solved := _solve(String(card.raadsel))
		kinds[String(card.raadsel).substr(0, 6)] = true
		if pin.length() != 4 or not pin.is_valid_int() or solved != pin:
			wrong += 1
			if first_wrong == "":
				first_wrong = "%s -> %s (pin %s)" % [card.raadsel, solved, pin]
	_check(wrong == 0, "%d passen: pincode van 4 cijfers, het raadsel geeft hem (%d fout) %s" % [CARDS_TRIED, wrong, first_wrong])
	_check(lowest >= BankCards.BALANCE_RANGE.x and highest <= BankCards.BALANCE_RANGE.y,
		"saldo bescheiden: € %.2f .. € %.2f" % [lowest, highest])
	_check(kinds.size() >= 3, "verschillende soorten raadsels (%d)" % kinds.size())


## The PIN of a riddle, worked out as a player would.
func _solve(text: String) -> String:
	var numbers := RegEx.create_from_string("\\d+").search_all(text).map(func(found: RegExMatch) -> int: return int(found.get_string()))
	if numbers.size() == 3 and not text.begins_with("Eerste"):
		return str(numbers[0] * numbers[1] + numbers[2])
	if text.begins_with("Eerste"):
		var first_half: int = numbers[0] * numbers[1] if text.contains("×") else numbers[0] + numbers[1]
		var second_half: int = numbers[numbers.size() - 1] / 2
		return "%02d%02d" % [first_half, second_half]
	# the digits: each phrase of BankCards.DIGIT_RIDDLES in the order they come
	var found := []
	for digit in BankCards.DIGIT_RIDDLES.size():
		for phrase: String in BankCards.DIGIT_RIDDLES[digit]:
			var at := text.find(phrase)
			while at >= 0:
				found.append([at, digit, phrase.length()])
				at = text.find(phrase, at + 1)
	found.sort_custom(func(first: Array, second: Array) -> bool: return first[0] < second[0])
	var pin := ""
	for entry: Array in found:
		pin += str(entry[1])
	return pin


func _found_cards(player: Node) -> void:
	print("gevonden pinpassen:")
	_check(player.has_method("give_found_bank_card") and player.give_found_bank_card(), "PlayerController.give_found_bank_card geeft een pas")
	_check(player.give_found_bank_card(), "nog een pas")
	var cards := BankCards.cards_of(player)
	_check(int(player.inventory.get("pinpas", 0)) == 2 and cards.size() == 2, "twee pinpassen in je zakken (%s)" % player.inventory)
	_check(cards[0] != cards[1] and int(cards[0].nummer) != int(cards[1].nummer), "elke pas een eigen rekening")
	var text := BankCards.description(player, "Basis.")
	_check(text.contains(String(cards[0].raadsel)) and text.contains(String(cards[1].raadsel)), "de raadsels staan in de beschrijving van de inventaris")


func _cash_machine(player: Node) -> void:
	print("geldautomaat:")
	var card: Dictionary = BankCards.cards_of(player)[0]
	card["saldo"] = 23.0
	var money_before: float = player.money
	var screen: Node = CashMachineScreen.show_for(player, "", false)
	_check(screen != null and paused, "de geldautomaat gaat open, het spel staat stil")
	await process_frame
	_check(screen.state == "start", "eerst: steek uw pas in")
	await screen.insert_card(card)
	_check(screen.state == "pin", "pas erin: pincode intoetsen")
	var wrong_pin := "0000" if String(card.pin) != "0000" else "1111"
	_check((await screen.enter_pin(wrong_pin)) == "fout" and BankCards.tries_left(card) == 2, "verkeerde pincode: geweigerd, nog 2 pogingen")
	for digit in String(card.pin):
		screen._keypad(digit)
	screen._keypad("OK")
	await process_frame
	_check(screen.state == "menu" and BankCards.tries_left(card) == 3, "goede pincode via het toetsenbord: kies een bedrag")
	_check(not (await screen.withdraw(50.0)) and is_equal_approx(float(card.saldo), 23.0), "€ 50 kan niet bij € 23 saldo")
	_check((await screen.withdraw(20.0)), "€ 20 pinnen")
	_check(is_equal_approx(player.money, money_before + 20.0) and is_equal_approx(float(card.saldo), 3.0),
		"€ 20 in je portemonnee, € 3 over op de rekening (€ %.2f / € %.2f)" % [player.money, card.saldo])
	_check(not (await screen.withdraw(5.0)), "€ 5 kan niet meer bij € 3")
	screen.close()
	await process_frame
	await process_frame
	_check(not paused and not is_instance_valid(screen), "de automaat dicht, het spel gaat verder")
	# three wrong PINs: the card is kept
	var second: Dictionary = BankCards.cards_of(player)[1]
	screen = CashMachineScreen.show_for(player, "", false)
	await process_frame
	await screen.insert_card(second)
	var wrong := "0000" if String(second.pin) != "0000" else "1111"
	await screen.enter_pin(wrong)
	await screen.enter_pin(wrong)
	var third: String = await screen.enter_pin(wrong)
	_check(third == "ingeslikt" and not BankCards.cards_of(player).has(second) and int(player.inventory.get("pinpas", 0)) == 1,
		"drie keer fout: de pas ingeslikt (%s, %d passen over)" % [third, int(player.inventory.get("pinpas", 0))])
	screen.close()
	await process_frame
	await process_frame
	# without a card
	BankCards.swallow(player, BankCards.cards_of(player)[0])
	screen = CashMachineScreen.show_for(player, "", false)
	await process_frame
	_check(screen.state == "start" and String(screen._display_text.text).contains("geen pinpas"), "zonder pinpas kan de automaat niks")
	screen.close()
	await process_frame
	await process_frame


func _deposit_machine(player: Node) -> void:
	print("statiegeldautomaat:")
	player.add_item("blikje", 3)
	player.add_item("statiegeld", 2)
	_check(is_equal_approx(DepositReturn.total_value(player.inventory), 0.75), "3 blikjes en 2 flessen: € 0,75 statiegeld")
	var money_before: float = player.money
	var screen: Node = DepositMachineScreen.show_for(player, "DERREK", false)
	await process_frame
	for count in 3:
		await screen.insert_one("blikje")
	await screen.insert_one("statiegeld")
	_check(is_equal_approx((await screen.insert_one("blikje")), 0.0), "een vierde blikje is er niet")
	_check(not player.inventory.has("blikje") and int(player.inventory.get("statiegeld", 0)) == 1, "de blikjes en een fles zijn uit je zakken")
	_check(is_equal_approx(screen.total, 0.6), "op het display: € 0,60 (%.2f)" % screen.total)
	await screen.print_bon()
	_check(screen.state == "bon" and is_equal_approx(player.money, money_before), "de bon geprint, nog niet uitbetaald")
	await screen.take_bon()
	await process_frame
	await process_frame
	_check(is_equal_approx(player.money, money_before + 0.6), "bon gepakt: € 0,60 erbij (€ %.2f)" % (player.money - money_before))
	_check(not paused, "weg bij de automaat: het spel gaat verder")


func _ov_card(player: Node) -> void:
	print("OV-chipkaart:")
	player.add_money(-player.money)
	_check(OvCard.buy_card(player) == "geld", "zonder geld geen kaart")
	player.add_money(9.0)
	var screen: Node = OvMachineScreen.show_for(player, "TEST", false)
	await process_frame
	_check((await screen.buy_card()) == "ok" and OvCard.has_card(player), "kaart gekocht via de automaat")
	_check(is_equal_approx(OvCard.balance(player), OvCard.START_BALANCE) and is_equal_approx(player.money, 9.0 - OvCard.CARD_PRICE),
		"€ 7,50 betaald, € 2,50 saldo op de kaart")
	_check(OvCard.check_in(player) == "kaart" and is_equal_approx(OvCard.balance(player), OvCard.START_BALANCE - OvCard.RIDE_FARE), "inchecken kost de ritprijs")
	_check((await screen.top_up(5.0)) == "geld", "opladen met te weinig geld gaat niet")
	player.add_money(10.0)
	_check((await screen.top_up(5.0)) == "ok" and is_equal_approx(OvCard.balance(player), 6.5), "€ 5 opgeladen: € 6,50 saldo")
	_check((await screen.buy_ticket()) == "ok" and OvCard.has_ticket(player), "los kaartje gekocht")
	screen.close()
	await process_frame
	await process_frame
	player.set_meta(OvCard.BALANCE_META, 0.5)
	_check(OvCard.check_in(player, false) == "kaartje", "te weinig saldo: dan het losse kaartje")
	player.drop_item(OvCard.CARD_ITEM)
	_check(OvCard.check_in(player) == "kaartje" and OvCard.check_out(player) == "kaartje" and not OvCard.has_ticket(player),
		"met een los kaartje in en uit, bij het uitchecken is hij weg")
	_check(OvCard.check_in(player) == "geen", "zonder kaart of kaartje: nee")


func _models() -> void:
	print("modellen:")
	var cash := MachineModels.cash_machine_mesh().get_aabb()
	_check(cash.size.y > 1.6 and cash.size.y < 1.9 and cash.size.x < 1.0, "geldautomaat %s" % cash.size)
	var deposit := MachineModels.deposit_machine_mesh().get_aabb()
	_check(deposit.size.is_equal_approx(Vector3(0.875, 1.875, 0.625)), "statiegeldautomaat zo groot als in de indeling (%s)" % deposit.size)
	_check(MachineModels.can_mesh().get_aabb().size.y > 0.1 and MachineModels.bank_card_mesh().get_aabb().size.x > 0.2, "blikje en pinpas")
	var machine := MachineModels.instance(MachineModels.cash_machine_mesh(), "Test")
	var collider := machine.get_node("Botsvorm").get_child(0) as CollisionShape3D
	_check(((collider.shape as BoxShape3D).size).is_equal_approx(cash.size) and collider.position.is_equal_approx(cash.get_center()),
		"botsvorm zo groot als de geldautomaat")
	machine.free()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
