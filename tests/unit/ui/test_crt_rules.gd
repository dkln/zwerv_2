extends RefCounted
## Unit tests of the rules of the CRT look (scripts/ui/hud/crt_rules.gd).
##   tests/run_unit_tests.sh crt_rules

const CrtRules = preload("res://scripts/ui/hud/crt_rules.gd")


func test_the_hud_bends_at_most_as_far_as_the_world(test) -> void:
	test.check(CrtRules.ui_curvature(0.02, 0.05) == 0.02, "minder dan de wereld: zoals ingesteld")
	test.check(CrtRules.ui_curvature(0.08, 0.05) == 0.05, "meer: zo ver als de wereld")
	test.check(CrtRules.ui_curvature(0.02, 0.0) == 0.0, "een vlak beeld: de HUD ook vlak")


func test_corners_only_on_a_bulging_picture(test) -> void:
	test.check(CrtRules.corner(0.035, 0.05) == 0.035, "een bol beeld: ronde hoeken")
	test.check(CrtRules.corner(0.035, 0.0) == 0.0, "een vlak beeld: geen")


func test_screen_size(test) -> void:
	test.check(CrtRules.screen_size(Vector2(1920.0, 1080.0)) == Vector2(1920.0, 1080.0), "de maat van de laag")
	test.check(CrtRules.screen_size(Vector2.ZERO) == CrtRules.FALLBACK_SCREEN, "nog geen maat: die van het ontwerp")


func test_the_look_on_and_off(test) -> void:
	test.check(CrtRules.curvature_when(true, 0.05) == 0.05, "aan: zoals het was ingesteld")
	test.check(CrtRules.curvature_when(false, 0.05) == 0.0, "uit: vlak")
