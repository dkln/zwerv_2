extends "res://tests/integration/support/town_test.gd"
## The machines and what you find for them, without the town (fast): the real
## PlayerController with a stand-in HUD, the machine screens without the swipe (animate off).
## - a card given to the player (PlayerController.give_found_bank_card) is a "pinpas" in the
##   pockets, each card its own account;
## - the cash machine (CashMachineScreen): a wrong PIN is refused, the right one lets you in,
##   no more than the balance comes out, what comes out is in the wallet and off the
##   balance; three wrong PINs and the card is kept (gone from the pockets);
## - the deposit machine (DepositMachineScreen): cans and bottles one by one, 15 cents each,
##   gone from the pockets, the bon pays the total out;
## - the OV-chipkaart (OvCard, OvMachineScreen): buying needs the money, a new card has its
##   balance, checking in costs the fare, topping up, a single ticket kept at check-out.
## The riddles of the cards and the models of the machines are unit tests
## (tests/unit/player/test_bank_cards.gd, tests/unit/world/test_machine_models.gd).
##   tests/run_integration_tests.sh machines

const PlayerController = preload("res://scripts/player/player_controller.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")
const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")
const OvCard = preload("res://scripts/world/station/ov_card.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const CashMachineScreen = preload("res://scripts/ui/machines/cash_machine_screen.gd")
const DepositMachineScreen = preload("res://scripts/ui/machines/deposit_machine_screen.gd")
const OvMachineScreen = preload("res://scripts/ui/machines/ov_machine_screen.gd")

const STAND_IN_HUD := """extends Node
var money := -1.0
func set_money(euros: float) -> void:
	money = euros
func show_floating_number(_at: Vector3, _text: String, _colour: Color, _size := 16, _over := false) -> void:
	pass
"""


static func world_options() -> Dictionary:
	return {"town": false}


## A stand-in town under the root (a node "Stad" with a stand-in "HUD" and the real player
## "Speler", a backpack on so there is room for everything); returns the player.
func _player_in_stand_in_town() -> Node:
	PlayerCharacter.choose("jos")
	var town := Node3D.new()
	town.name = "Stad"
	var hud_script := GDScript.new()
	hud_script.source_code = STAND_IN_HUD
	hud_script.reload()
	var stand_in_hud := Node.new()
	stand_in_hud.name = "HUD"
	stand_in_hud.set_script(hud_script)
	town.add_child(stand_in_hud)
	var stand_in_player := PlayerController.new()
	stand_in_player.name = "Speler"
	town.add_child(stand_in_player)
	add_to_root(town)
	await frames(1)
	stand_in_player.set("has_backpack", true)
	return stand_in_player


## A PIN that is not the one of `card`.
static func _wrong_pin(card: Dictionary) -> String:
	return "0000" if String(card.pin) != "0000" else "1111"


## The screen of a machine closed and gone.
func _close(screen: Node) -> void:
	screen.close()
	await frames(2)


## Two found cards: two "pinpas" in the pockets, each its own account, their riddles in the
## description of the inventory.
func test_found_cards_are_in_the_pockets_each_its_own_account(test) -> void:
	var card_owner := await _player_in_stand_in_town()
	test.check(card_owner.has_method("give_found_bank_card") and card_owner.give_found_bank_card(), "PlayerController.give_found_bank_card geeft een pas")
	test.check(card_owner.give_found_bank_card(), "nog een pas")
	var cards := BankCards.cards_of(card_owner)
	test.check(int(card_owner.inventory.get("pinpas", 0)) == 2 and cards.size() == 2, "twee pinpassen in je zakken (%s)" % card_owner.inventory)
	test.check(cards[0] != cards[1] and int(cards[0].nummer) != int(cards[1].nummer), "elke pas een eigen rekening")
	var text := BankCards.description(card_owner, "Basis.")
	test.check(text.contains(String(cards[0].raadsel)) and text.contains(String(cards[1].raadsel)), "de raadsels staan in de beschrijving van de inventaris")


## The cash machine opens as a 3D scene of its own (the machine's model, you at it, its
## camera, its screen) with the game paused, and closes again.
func test_cash_machine_opens_as_a_scene_of_its_own(test) -> void:
	var card_owner := await _player_in_stand_in_town()
	card_owner.give_found_bank_card()
	var screen: Node = CashMachineScreen.show_for(card_owner, "", false)
	test.check(screen != null and tree.paused, "de geldautomaat gaat open, het spel staat stil")
	await frames(1)
	test.check(screen.state == "start", "eerst: steek uw pas in")
	var stage: Dictionary = screen.stage_parts()
	test.check(stage.machine != null and stage.machine.mesh == MachineModels.cash_machine_mesh() and stage.stand_in != null
		and (stage.camera as Camera3D).is_current() and stage.display != null,
		"een 3D-scène: de geldautomaat, jij ervoor, een eigen camera, het scherm")
	test.check(String(screen._display_text.text) != "", "op het scherm van het model staat wat de automaat zegt")
	await _close(screen)
	test.check(not tree.paused and not is_instance_valid(screen), "de automaat dicht, het spel gaat verder")


## At the cash machine: a wrong PIN is refused, the right one (on the keypad) gives the
## menu, no more than the balance comes out, and what comes out is in the wallet and off the balance.
func test_cash_machine_pays_out_no_more_than_the_balance(test) -> void:
	var card_owner := await _player_in_stand_in_town()
	card_owner.give_found_bank_card()
	var card: Dictionary = BankCards.cards_of(card_owner)[0]
	card["saldo"] = 23.0
	var money_before: float = card_owner.money
	var screen: Node = CashMachineScreen.show_for(card_owner, "", false)
	await frames(1)
	await screen.insert_card(card)
	test.check(screen.state == "pin", "pas erin: pincode intoetsen")
	test.check((await screen.enter_pin(_wrong_pin(card))) == "fout" and BankCards.tries_left(card) == 2, "verkeerde pincode: geweigerd, nog 2 pogingen")
	for digit in String(card.pin):
		screen._keypad(digit)
	screen._keypad("OK")
	await frames(1)
	test.check(screen.state == "menu" and BankCards.tries_left(card) == 3, "goede pincode via het toetsenbord: kies een bedrag")
	test.check(not (await screen.withdraw(50.0)) and is_equal_approx(float(card.saldo), 23.0), "€ 50 kan niet bij € 23 saldo")
	test.check((await screen.withdraw(20.0)), "€ 20 pinnen")
	test.check((screen.stage_parts().came_out as Array).size() == 1, "het geld schuift uit de gleuf")
	test.check(is_equal_approx(card_owner.money, money_before + 20.0) and is_equal_approx(float(card.saldo), 3.0),
		"€ 20 in je portemonnee, € 3 over op de rekening (€ %.2f / € %.2f)" % [card_owner.money, card.saldo])
	test.check(not (await screen.withdraw(5.0)), "€ 5 kan niet meer bij € 3")
	await _close(screen)


## Three wrong PINs and the machine keeps the card: gone from the pockets.
func test_cash_machine_keeps_the_card_after_three_wrong_pins(test) -> void:
	var card_owner := await _player_in_stand_in_town()
	card_owner.give_found_bank_card()
	card_owner.give_found_bank_card()
	var card: Dictionary = BankCards.cards_of(card_owner)[1]
	var screen: Node = CashMachineScreen.show_for(card_owner, "", false)
	await frames(1)
	await screen.insert_card(card)
	await screen.enter_pin(_wrong_pin(card))
	await screen.enter_pin(_wrong_pin(card))
	var third: String = await screen.enter_pin(_wrong_pin(card))
	test.check(third == "ingeslikt" and not BankCards.cards_of(card_owner).has(card) and int(card_owner.inventory.get("pinpas", 0)) == 1,
		"drie keer fout: de pas ingeslikt (%s, %d passen over)" % [third, int(card_owner.inventory.get("pinpas", 0))])
	await _close(screen)


## Without a bank card the cash machine says so and does nothing.
func test_cash_machine_without_a_card(test) -> void:
	var card_owner := await _player_in_stand_in_town()
	var screen: Node = CashMachineScreen.show_for(card_owner, "", false)
	await frames(1)
	test.check(screen.state == "start" and String(screen._display_text.text).contains("geen pinpas"), "zonder pinpas kan de automaat niks")
	await _close(screen)


## The deposit machine: cans and bottles go in one by one (15 cents each, out of the
## pockets), the bon is printed and only taking it pays the total out.
func test_deposit_machine_pays_for_cans_and_bottles(test) -> void:
	var returner := await _player_in_stand_in_town()
	returner.add_item("blikje", 3)
	returner.add_item("statiegeld", 2)
	test.check(is_equal_approx(DepositReturn.total_value(returner.inventory), 0.75), "3 blikjes en 2 flessen: € 0,75 statiegeld")
	var money_before: float = returner.money
	var screen: Node = DepositMachineScreen.show_for(returner, "DERREK", false)
	await frames(1)
	for can_index in 3:
		await screen.insert_one("blikje")
	await screen.insert_one("statiegeld")
	test.check(is_equal_approx((await screen.insert_one("blikje")), 0.0), "een vierde blikje is er niet")
	test.check(not returner.inventory.has("blikje") and int(returner.inventory.get("statiegeld", 0)) == 1, "de blikjes en een fles zijn uit je zakken")
	test.check(is_equal_approx(screen.total, 0.6), "op het display: € 0,60 (%.2f)" % screen.total)
	await screen.print_bon()
	test.check(screen.state == "bon" and is_equal_approx(returner.money, money_before), "de bon geprint, nog niet uitbetaald")
	await screen.take_bon()
	await frames(2)
	test.check(is_equal_approx(returner.money, money_before + 0.6), "bon gepakt: € 0,60 erbij (€ %.2f)" % (returner.money - money_before))
	test.check(not tree.paused, "weg bij de automaat: het spel gaat verder")


## The OV machine: no card without money; a card bought has its start balance, checking in
## costs the fare, topping up needs the money, and a single ticket can be bought.
func test_ov_machine_sells_tops_up_and_checks_in(test) -> void:
	var traveller := await _player_in_stand_in_town()
	traveller.add_money(-traveller.money)
	test.check(OvCard.buy_card(traveller) == "geld", "zonder geld geen kaart")
	traveller.add_money(9.0)
	var screen: Node = OvMachineScreen.show_for(traveller, "TEST", false)
	await frames(1)
	test.check((await screen.buy_card()) == "ok" and OvCard.has_card(traveller), "kaart gekocht via de automaat")
	test.check(is_equal_approx(OvCard.balance(traveller), OvCard.START_BALANCE) and is_equal_approx(traveller.money, 9.0 - OvCard.CARD_PRICE),
		"€ 7,50 betaald, € 2,50 saldo op de kaart")
	test.check(OvCard.check_in(traveller) == "kaart" and is_equal_approx(OvCard.balance(traveller), OvCard.START_BALANCE - OvCard.RIDE_FARE), "inchecken kost de ritprijs")
	test.check((await screen.top_up(5.0)) == "geld", "opladen met te weinig geld gaat niet")
	traveller.add_money(10.0)
	test.check((await screen.top_up(5.0)) == "ok" and is_equal_approx(OvCard.balance(traveller), 6.5), "€ 5 opgeladen: € 6,50 saldo")
	test.check((await screen.buy_ticket()) == "ok" and OvCard.has_ticket(traveller), "los kaartje gekocht")
	await _close(screen)


## A single ticket: used when the card's balance is too low, good for one check-in and
## check-out, gone after; without card or ticket no check-in.
func test_single_ticket_is_gone_at_check_out(test) -> void:
	var traveller := await _player_in_stand_in_town()
	traveller.add_money(20.0 - traveller.money)
	var screen: Node = OvMachineScreen.show_for(traveller, "TEST", false)
	await frames(1)
	await screen.buy_card()
	await screen.buy_ticket()
	await _close(screen)
	traveller.set_meta(OvCard.BALANCE_META, 0.5)
	test.check(OvCard.check_in(traveller, false) == "kaartje", "te weinig saldo: dan het losse kaartje")
	traveller.drop_item(OvCard.CARD_ITEM)
	test.check(OvCard.check_in(traveller) == "kaartje" and OvCard.check_out(traveller) == "kaartje" and not OvCard.has_ticket(traveller),
		"met een los kaartje in en uit, bij het uitchecken is hij weg")
	test.check(OvCard.check_in(traveller) == "geen", "zonder kaart of kaartje: nee")
