extends RefCounted
## Unit tests of the logic of the wipe (scripts/ui/screens/swipe_transition_rules.gd): which
## wipe a call gets and how long the edge waits, without nodes or the clock.
##   tests/run_unit_tests.sh swipe_transition_rules

const SwipeTransitionRules = preload("res://scripts/ui/screens/swipe_transition_rules.gd")


func test_reuses_running_only_before_it_covered(test) -> void:
	test.check(SwipeTransitionRules.reuses_running(false), "nog niet bedekt: dezelfde veeg")
	test.check(not SwipeTransitionRules.reuses_running(true), "al bedekt: een nieuwe")


func test_previous_name(test) -> void:
	test.check(SwipeTransitionRules.previous_name("Swipe") == "Swipe_vorige", "de oude veeg krijgt een andere naam")
	test.check(SwipeTransitionRules.previous_name("Swipe") != "Swipe", "zodat de nieuwe de naam kan dragen")


func test_give_up_at(test) -> void:
	test.check(SwipeTransitionRules.give_up_at(1000, 5.0) == 6000, "vijf seconden na nu")
	test.check(SwipeTransitionRules.give_up_at(1000, 0.3) == 1300, "delen van een seconde in milliseconden")
	test.check(SwipeTransitionRules.give_up_at(1000, 0.0) == 1000, "niet wachten: nu")
	test.check(SwipeTransitionRules.give_up_at(0, SwipeTransitionRules.MAX_HOLD_SECONDS) == 5000, "gewoon: hooguit vijf seconden")


func test_still_holding(test) -> void:
	test.check(SwipeTransitionRules.still_holding(false, 1000, 6000), "niet klaar en nog tijd: wachten")
	test.check(not SwipeTransitionRules.still_holding(true, 1000, 6000), "klaar: door")
	test.check(not SwipeTransitionRules.still_holding(false, 6000, 6000), "de tijd is om: door")
	test.check(not SwipeTransitionRules.still_holding(false, 7000, 6000), "ruim over tijd: door")
	test.check(not SwipeTransitionRules.still_holding(true, 7000, 6000), "klaar en over tijd: door")
	test.check(SwipeTransitionRules.SETTLE_FRAMES > 0, "het nieuwe beeld krijgt een paar beeldjes")
