extends RefCounted
## Unit tests of the rules of the lost bank cards (scripts/world/things/lost_bank_cards_rules.gd):
## how far apart they lie, how a card turns, what the reward screen shows.
##   tests/run_unit_tests.sh lost_bank_cards_rules

const LostBankCardsRules = preload("res://scripts/world/things/lost_bank_cards_rules.gd")


func test_apart_is_a_third_of_the_reach(test) -> void:
	test.check(is_equal_approx(LostBankCardsRules.apart(400.0), 400.0 / 3.0), "een derde van het bereik")
	test.check(LostBankCardsRules.apart(0.0) == 0.0, "geen bereik: geen afstand")


func test_turn_grows_with_the_clock_from_its_phase(test) -> void:
	test.check(is_equal_approx(LostBankCardsRules.turn(0.0, 0.8), 0.8), "aan het begin: zijn eigen fase")
	test.check(is_equal_approx(LostBankCardsRules.turn(2.0, 0.8), 2.0 * LostBankCardsRules.TURN_SPEED + 0.8), "na twee seconden")


func test_found_reward(test) -> void:
	var reward := LostBankCardsRules.found_reward("pinpas")
	test.check(reward.heading == "GEVONDEN" and reward.title == "Op straat", "gevonden, op straat")
	test.check(reward.items == [{"item": "pinpas", "count": 1}], "één pinpas")


func test_constants(test) -> void:
	test.check(LostBankCardsRules.UNLOCK == "pinpassen" and LostBankCardsRules.CARD_SEED == 97, "eigen naam en eigen loting")
	test.check(LostBankCardsRules.CLOSEST == 12.0 and LostBankCardsRules.SCATTER == 1.2, "verder van de start, dichter bij het midden van de cel")
