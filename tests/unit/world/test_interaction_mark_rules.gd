extends RefCounted
## Unit tests of the rules of the arrow over something you can use
## (scripts/world/things/interaction_mark_rules.gd).
##   tests/run_unit_tests.sh interaction_mark_rules

const InteractionMarkRules = preload("res://scripts/world/things/interaction_mark_rules.gd")


func test_shows_only_near_allowed_and_present(test) -> void:
	test.check(InteractionMarkRules.shows(true, true, 5.0), "dichtbij: te zien")
	test.check(not InteractionMarkRules.shows(true, true, InteractionMarkRules.MARK_FROM), "precies op de grens: niet")
	test.check(InteractionMarkRules.shows(true, true, InteractionMarkRules.MARK_FROM - 0.01), "net erbinnen: wel")
	test.check(not InteractionMarkRules.shows(false, true, 5.0), "niet toegestaan: niet")
	test.check(not InteractionMarkRules.shows(true, false, 5.0), "geen speler of niet in de wereld: niet")
	test.check(not InteractionMarkRules.shows(true, true, INF), "oneindig ver: niet")


func test_height_bobs_between_bottom_and_top(test) -> void:
	test.check(is_equal_approx(InteractionMarkRules.height(2.0, 3.0, 0.0), 2.5), "aan het begin in het midden")
	test.check(is_equal_approx(InteractionMarkRules.height(2.0, 3.0, InteractionMarkRules.BOB_SECONDS * 0.25), 3.0), "een kwart: bovenaan")
	test.check(is_equal_approx(InteractionMarkRules.height(2.0, 3.0, InteractionMarkRules.BOB_SECONDS * 0.75), 2.0), "driekwart: onderaan")
	test.check(is_equal_approx(InteractionMarkRules.height(2.0, 3.0, InteractionMarkRules.BOB_SECONDS), 2.5), "na één keer op en neer weer in het midden")
	for step in 50:
		var height := InteractionMarkRules.height(1.0, 4.0, step * 0.1)
		test.check(height >= 1.0 - 0.0001 and height <= 4.0 + 0.0001, "nooit buiten onder en boven (%s)" % height)
