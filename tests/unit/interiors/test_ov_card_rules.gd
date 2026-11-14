extends RefCounted
## Unit tests of the fares and answers of the OV-chipkaart (scripts/world/station/ov_card_rules.gd):
## what a reader answers to a check-in and a check-out, the balance after it, the charge of a
## trip not checked out, topping up, and the texts of a reader and a post.
##   tests/run_unit_tests.sh ov_card_rules

const Rules = preload("res://scripts/world/station/ov_card_rules.gd")


func test_check_in_with_a_card_a_ticket_or_nothing(test) -> void:
	test.check(Rules.check_in_result(true, false, Rules.RIDE_FARE, 0.0) == Rules.WITH_CARD, "een kaart met precies het tarief: met de kaart")
	test.check(Rules.check_in_result(true, true, 5.0, 0.0) == Rules.WITH_CARD, "kaart en kaartje: de kaart gaat voor")
	test.check(Rules.check_in_result(true, false, Rules.RIDE_FARE - 0.01, 0.0) == Rules.TOO_LITTLE, "een cent te weinig: saldo te laag")
	test.check(Rules.check_in_result(true, true, 0.0, 0.0) == Rules.WITH_TICKET, "een lege kaart maar een kaartje: met het kaartje")
	test.check(Rules.check_in_result(false, true, 0.0, 0.0) == Rules.WITH_TICKET, "alleen een kaartje: met het kaartje")
	test.check(Rules.check_in_result(false, false, 99.0, 0.0) == Rules.NOTHING, "niets: geen")
	test.check(Rules.check_in_result(true, false, 3.9, 3.0) == Rules.TOO_LITTLE, "het saldo dekt de openstaande rit niet: saldo te laag")
	test.check(Rules.check_in_result(true, false, 4.0, 3.0) == Rules.WITH_CARD, "het saldo dekt de openstaande rit en het tarief")


func test_balance_after_a_check_in(test) -> void:
	test.check(is_equal_approx(Rules.balance_after_check_in(2.5, 0.0), 1.5), "het tarief eraf")
	test.check(is_equal_approx(Rules.balance_after_check_in(4.0, 3.0), 0.0), "en de openstaande rit")
	test.check(is_equal_approx(Rules.balance_after_check_in(1.005, 0.0), 0.01) or is_equal_approx(Rules.balance_after_check_in(1.005, 0.0), 0.0), "op centen afgerond")


func test_check_out_and_refusals(test) -> void:
	test.check(Rules.check_out_result(true, true) == Rules.WITH_CARD, "uitchecken met de kaart")
	test.check(Rules.check_out_result(false, true) == Rules.WITH_TICKET, "uitchecken met het kaartje")
	test.check(Rules.check_out_result(false, false) == Rules.NOTHING, "zonder iets: geen")
	test.check(Rules.is_refused(Rules.TOO_LITTLE) and Rules.is_refused(Rules.NOTHING), "saldo en geen zijn een weigering")
	test.check(not Rules.is_refused(Rules.WITH_CARD) and not Rules.is_refused(Rules.WITH_TICKET), "kaart en kaartje niet")


func test_charge_of_a_trip_not_checked_out(test) -> void:
	var rest := Rules.BOARDING_FARE - Rules.RIDE_FARE
	test.check(Rules.missed_check_out_charge(true, true, false) == rest, "een rit opengelaten: de rest van het instaptarief")
	test.check(Rules.missed_check_out_charge(true, false, true) == rest, "nog ingecheckt met de kaart: hetzelfde")
	test.check(Rules.missed_check_out_charge(true, false, false) == 0.0, "niets open: niets")
	test.check(Rules.missed_check_out_charge(false, true, true) == 0.0, "zonder kaart: niets")


func test_topping_up(test) -> void:
	test.check(Rules.can_top_up(10.0, 10.0) and not Rules.can_top_up(9.99, 10.0), "opladen kan met precies genoeg geld, niet met minder")
	test.check(is_equal_approx(Rules.balance_after_top_up(-1.5, 5.0), 3.5), "het bedrag komt bij het saldo (ook onder nul)")


func test_texts_of_readers_and_posts(test) -> void:
	test.check(Rules.post_action(true) == "Uitchecken" and Rules.post_action(false) == "Inchecken", "de paal biedt uit- of inchecken")
	test.check(Rules.check_in_text(0.0) == "Ingecheckt", "ingecheckt zonder inhouding")
	test.check(Rules.check_in_text(3.0).begins_with("Niet uitgecheckt:") and Rules.check_in_text(3.0).contains("3"), "met inhouding: het bedrag erbij")
	test.check(Rules.refusal(Rules.NOTHING) == "Geen OV-chipkaart", "geen kaart")
	test.check(Rules.refusal(Rules.TOO_LITTLE).begins_with("Saldo te laag") and Rules.refusal(Rules.TOO_LITTLE, 3.0).contains("4"), "saldo te laag, met wat er nodig is")


func test_what_a_post_answers(test) -> void:
	var refused := Rules.tap_result(false, Rules.NOTHING, 0.0, 0.0)
	test.check(not refused.ok and refused.sound == Rules.SOUND_REFUSED and refused.text == "Geen OV-chipkaart" and refused.charge == 0.0, "geweigerd: de fouttoon en waarom")
	var checked_in := Rules.tap_result(false, Rules.WITH_CARD, 0.0, 0.0)
	test.check(checked_in.ok and checked_in.sound == Rules.SOUND_IN and checked_in.text == "Ingecheckt", "ingecheckt")
	var charged := Rules.tap_result(false, Rules.WITH_CARD, 3.0, 0.0)
	test.check(charged.ok and charged.charge == 3.0 and String(charged.text).begins_with("Niet uitgecheckt"), "ingecheckt met inhouding")
	var checked_out := Rules.tap_result(true, Rules.WITH_TICKET, 0.0, 0.0)
	test.check(checked_out.ok and checked_out.sound == Rules.SOUND_OUT and checked_out.text == "Uitgecheckt", "uitgecheckt")
