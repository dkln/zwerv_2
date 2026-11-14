extends RefCounted
## Unit tests of how often something is updated by where it is seen
## (scripts/world/town/sight_rules.gd): the margin round the screen, what is too far from a
## perspective camera, and the steps of what is out of sight near and far.

const SightRules = preload("res://scripts/world/town/sight_rules.gd")

const SCREEN := Rect2(0.0, 0.0, 1000.0, 500.0)


## Only a perspective camera has a farthest distance, and only past it.
func test_beyond_the_farthest_only_in_perspective(test) -> void:
	test.check(SightRules.is_beyond_farthest(true, SightRules.FARTHEST_METRES + 1.0), "perspectief, verder dan het verste: te ver")
	test.check(not SightRules.is_beyond_farthest(true, SightRules.FARTHEST_METRES), "precies op het verste: nog niet")
	test.check(not SightRules.is_beyond_farthest(false, 10000.0), "een rechte camera kent geen te ver")


## The screen grows by the margin on every side.
func test_the_screen_grows_by_its_margin(test) -> void:
	var grown := SightRules.grown_screen(SCREEN)
	test.check(grown.position.is_equal_approx(Vector2(-300.0, -150.0)), "links en boven 30%% erbij (%s)" % grown.position)
	test.check(grown.end.is_equal_approx(Vector2(1300.0, 650.0)), "rechts en onder 30%% erbij (%s)" % grown.end)


## In sight: on the screen and in the margin round it, not past it.
func test_in_sight_on_the_screen_and_in_the_margin(test) -> void:
	test.check(SightRules.is_in_sight(SCREEN, Vector2(500.0, 250.0)), "midden in beeld")
	test.check(SightRules.is_in_sight(SCREEN, Vector2(-299.0, 649.0)), "in de rand om het beeld")
	test.check(not SightRules.is_in_sight(SCREEN, Vector2(-301.0, 250.0)), "links voorbij de rand")
	test.check(not SightRules.is_in_sight(SCREEN, Vector2(500.0, 651.0)), "onder voorbij de rand")


## Out of sight: NEAR_STEPS near the focus, FAR_STEPS past FAR_METRES.
func test_steps_out_of_sight(test) -> void:
	test.check(SightRules.steps_out_of_sight(0.0) == SightRules.NEAR_STEPS, "dichtbij: om de %d stappen" % SightRules.NEAR_STEPS)
	test.check(SightRules.steps_out_of_sight(SightRules.FAR_METRES) == SightRules.NEAR_STEPS, "precies op de grens: nog dichtbij")
	test.check(SightRules.steps_out_of_sight(SightRules.FAR_METRES + 0.1) == SightRules.FAR_STEPS, "ver weg: om de %d stappen" % SightRules.FAR_STEPS)
	test.check(SightRules.EVERY_STEP < SightRules.NEAR_STEPS and SightRules.NEAR_STEPS < SightRules.FAR_STEPS, "hoe verder, hoe minder vaak")
