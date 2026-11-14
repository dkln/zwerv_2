extends RefCounted
## Unit tests of the OV-chipkaart on the player (scripts/world/station/ov_card.gd): buying a
## card and a ticket, topping up, checking in and out (what is paid and kept on the player),
## a trip not checked out, a post, and what the readers write. The player is a stand-in.
##   tests/run_unit_tests.sh ov_card

const OvCard = preload("res://scripts/world/station/ov_card.gd")


class TestPlayer:
	extends Node
	var inventory := {}
	var money := 20.0
	var room := true

	func buy(item_id: String, price: float) -> String:
		if money + 0.001 < price:
			return "geld"
		if not room:
			return "vol"
		money -= price
		inventory[item_id] = int(inventory.get(item_id, 0)) + 1
		return "ok"

	func add_money(amount: float) -> void:
		money += amount

	func drop_item(item_id: String) -> void:
		inventory[item_id] = int(inventory.get(item_id, 1)) - 1
		if int(inventory[item_id]) <= 0:
			inventory.erase(item_id)


func _with_card(balance: float) -> TestPlayer:
	var player := TestPlayer.new()
	player.inventory[OvCard.CARD_ITEM] = 1
	player.set_meta(OvCard.BALANCE_META, balance)
	return player


func test_buying_a_card_and_a_ticket(test) -> void:
	var player := TestPlayer.new()
	test.check(not OvCard.has_card(player) and not OvCard.has_ticket(player) and OvCard.balance(player) == 0.0, "eerst niets")
	test.check(OvCard.buy_card(player) == "ok" and OvCard.has_card(player), "een kaart gekocht")
	test.check(OvCard.balance(player) == OvCard.START_BALANCE and is_equal_approx(player.money, 20.0 - OvCard.CARD_PRICE), "met het startsaldo, de prijs betaald")
	test.check(OvCard.buy_card(player) == "heb_al", "een tweede kaart hoeft niet")
	test.check(OvCard.buy_ticket(player) == "ok" and OvCard.has_ticket(player), "een los kaartje gekocht")
	player.money = 1.0
	test.check(OvCard.buy_ticket(player) == "geld", "te weinig geld voor een kaartje")
	test.check(OvCard.buy_card(null) == "geld" and OvCard.buy_ticket(null) == "geld" and not OvCard.has_card(null) and OvCard.balance(null) == 0.0, "zonder speler: niets")
	player.free()


func test_topping_up(test) -> void:
	var player := TestPlayer.new()
	test.check(OvCard.top_up(player, 5.0) == "geen_kaart", "zonder kaart valt er niets op te laden")
	player.free()
	player = _with_card(1.0)
	test.check(OvCard.top_up(player, 10.0) == "ok" and is_equal_approx(OvCard.balance(player), 11.0) and is_equal_approx(player.money, 10.0), "tien euro van de portemonnee op de kaart")
	test.check(OvCard.top_up(player, 20.0) == "geld" and is_equal_approx(OvCard.balance(player), 11.0), "te weinig geld: niets opgeladen")
	player.free()


func test_checking_in_and_out_with_the_card(test) -> void:
	var player := _with_card(2.5)
	test.check(OvCard.check_in(player, false) == "kaart" and OvCard.balance(player) == 2.5 and not OvCard.is_checked_in(player), "alleen kijken: niets betaald")
	test.check(OvCard.check_in(player) == "kaart" and OvCard.is_checked_in(player), "ingecheckt met de kaart")
	test.check(is_equal_approx(OvCard.balance(player), 2.5 - OvCard.RIDE_FARE), "het tarief van het saldo")
	test.check(player.get_meta(OvCard.CHECKED_IN_WITH_META) == "kaart", "onthouden waarmee")
	test.check(OvCard.check_out(player, false) == "kaart" and OvCard.is_checked_in(player), "alleen kijken: nog ingecheckt")
	test.check(OvCard.check_out(player) == "kaart" and not OvCard.is_checked_in(player) and not player.has_meta(OvCard.CHECKED_IN_WITH_META), "uitgecheckt")
	player.set_meta(OvCard.BALANCE_META, 0.5)
	test.check(OvCard.check_in(player) == "saldo" and not OvCard.is_checked_in(player), "te weinig saldo: geweigerd")
	test.check(OvCard.refusal("saldo", player).begins_with("Saldo te laag") and OvCard.refusal("geen") == "Geen OV-chipkaart", "wat de lezer dan zegt")
	player.free()


func test_checking_in_and_out_with_a_ticket(test) -> void:
	var player := TestPlayer.new()
	test.check(OvCard.check_in(player) == "geen" and OvCard.check_out(player) == "geen", "zonder kaart of kaartje: geen")
	player.inventory[OvCard.TICKET_ITEM] = 1
	test.check(OvCard.check_in(player) == "kaartje" and OvCard.is_checked_in(player) and OvCard.has_ticket(player), "ingecheckt met het kaartje, dat je nog hebt")
	test.check(OvCard.check_out(player) == "kaartje" and not OvCard.has_ticket(player) and not OvCard.is_checked_in(player), "uitchecken: het poortje houdt het kaartje")
	player.free()


func test_a_trip_not_checked_out_costs_the_boarding_fare(test) -> void:
	var player := _with_card(10.0)
	test.check(OvCard.leave_open_trip(player) == "" and OvCard.missed_check_out_charge(player) == 0.0, "niet ingecheckt: niets open")
	OvCard.check_in(player)
	test.check(OvCard.missed_check_out_charge(player) == OvCard.BOARDING_FARE - OvCard.RIDE_FARE, "nog ingecheckt: opnieuw inchecken kost de rest van het instaptarief")
	test.check(OvCard.leave_open_trip(player) == "kaart" and not OvCard.is_checked_in(player) and bool(player.get_meta(OvCard.MISSED_CHECK_OUT_META, false)), "het station uit zonder uitchecken: onthouden")
	test.check(OvCard.check_in(player) == "kaart" and is_equal_approx(OvCard.balance(player), 10.0 - OvCard.RIDE_FARE - OvCard.BOARDING_FARE), "de volgende check-in houdt het in")
	test.check(not player.has_meta(OvCard.MISSED_CHECK_OUT_META) and OvCard.missed_check_out_charge(player) > 0.0, "daarna alleen nog de lopende rit")
	test.check(OvCard.missed_check_out_charge(null) == 0.0, "zonder speler: niets")
	player.free()
	player = TestPlayer.new()
	player.inventory[OvCard.TICKET_ITEM] = 1
	OvCard.check_in(player)
	test.check(OvCard.leave_open_trip(player) == "kaartje" and not OvCard.has_ticket(player), "met een kaartje: het kaartje is op")
	player.free()


func test_a_post_checks_in_and_out_in_turn(test) -> void:
	var player := _with_card(10.0)
	test.check(OvCard.post_action(player) == "Inchecken", "de paal biedt inchecken")
	var checked_in := OvCard.tap(player)
	test.check(checked_in.ok and checked_in.sound == "ov_inchecken" and checked_in.text == OvCard.check_in_text(0.0) and OvCard.is_checked_in(player), "kaart ervoor: ingecheckt")
	test.check(OvCard.post_action(player) == "Uitchecken", "nu biedt hij uitchecken")
	var checked_out := OvCard.tap(player)
	test.check(checked_out.ok and checked_out.sound == "ov_uitchecken" and checked_out.text == "Uitgecheckt" and not OvCard.is_checked_in(player), "nog eens: uitgecheckt")
	player.set_meta(OvCard.MISSED_CHECK_OUT_META, true)
	var charged := OvCard.tap(player)
	test.check(charged.ok and charged.charge == OvCard.BOARDING_FARE - OvCard.RIDE_FARE and charged.text == OvCard.check_in_text(charged.charge), "een opengelaten rit wordt bij het inchecken ingehouden")
	player.free()
	player = TestPlayer.new()
	var refused := OvCard.tap(player)
	test.check(not refused.ok and refused.sound == "ov_geweigerd" and refused.text == "Geen OV-chipkaart", "zonder kaart: geweigerd")
	player.free()
