extends RefCounted
## Unit tests of the rules of the loose change (scripts/world/things/loose_change_rules.gd):
## the values and their weights, the big coin, turning and bobbing, the text of a pick-up.
##   tests/run_unit_tests.sh loose_change_rules

const LooseChangeRules = preload("res://scripts/world/things/loose_change_rules.gd")


func test_value_of_a_draw(test) -> void:
	test.check(LooseChangeRules.VALUES.size() == LooseChangeRules.VALUE_WEIGHTS.size(), "elke waarde een gewicht")
	test.check(LooseChangeRules.value_of(0) == 0.1 and LooseChangeRules.value_of(2) == 0.5 and LooseChangeRules.value_of(3) == 1.0, "de waarde van een trekking")
	test.check(LooseChangeRules.value_of(-1) == 0.1 and LooseChangeRules.value_of(99) == 1.0, "buiten de lijst: de eerste of de laatste")
	test.check(LooseChangeRules.VALUE_WEIGHTS[3] < LooseChangeRules.VALUE_WEIGHTS[0], "een euro komt minder vaak")


func test_only_a_euro_is_big(test) -> void:
	test.check(LooseChangeRules.is_big(1.0) and LooseChangeRules.is_big(2.0), "een euro of meer: groot")
	test.check(not LooseChangeRules.is_big(0.5) and not LooseChangeRules.is_big(0.99), "minder: gewoon")


func test_turn_grows_with_the_clock_from_its_phase(test) -> void:
	test.check(is_equal_approx(LooseChangeRules.turn(0.0, 1.5), 1.5), "aan het begin: zijn eigen fase")
	test.check(is_equal_approx(LooseChangeRules.turn(2.0, 0.0), 2.0 * LooseChangeRules.TURN_SPEED), "na twee seconden")
	test.check(LooseChangeRules.turn(3.0, 0.5) > LooseChangeRules.turn(2.0, 0.5), "steeds verder")


func test_bob_stays_within_its_height(test) -> void:
	test.check(is_zero_approx(LooseChangeRules.bob(0.0, 0.0)), "aan het begin op zijn plek")
	var highest := 0.0
	for step in 200:
		highest = maxf(highest, absf(LooseChangeRules.bob(step * 0.05, 0.7)))
	test.check(highest <= LooseChangeRules.BOB_HEIGHT + 0.00001 and highest > LooseChangeRules.BOB_HEIGHT * 0.9, "tot de deinhoogte, niet verder (%s)" % highest)
	test.check(is_equal_approx(LooseChangeRules.bob(0.0, PI / 2.0), LooseChangeRules.BOB_HEIGHT), "een kwart verder: bovenaan")


func test_pickup_text(test) -> void:
	test.check(LooseChangeRules.pickup_text(0.5) == "+€ 0,50", "vijftig cent (%s)" % LooseChangeRules.pickup_text(0.5))
	test.check(LooseChangeRules.pickup_text(1.0) == "+€ 1,00", "een euro (%s)" % LooseChangeRules.pickup_text(1.0))
	test.check(LooseChangeRules.UNLOCK == "kleingeld", "wat het verhaal ontgrendelt")
