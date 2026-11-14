extends RefCounted
## Unit tests of scripts/ui/widgets/mission_badge.gd on its own: the emblem of a new mission
## (what its drawing depends on: sizes, shapes, flags, clocks).
##   tests/run_unit_tests.sh mission_badge

const MissionBadge = preload("res://scripts/ui/widgets/mission_badge.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_badge_diamond(test) -> void:
	var last := MissionBadge.DIAMOND_PIXELS - 1
	var half := MissionBadge.DIAMOND_PIXELS / 2
	test.check(MissionBadge.DIAMOND_PIXELS % 2 == 1, "een oneven aantal pixels: er is een midden")
	test.check(MissionBadge.in_diamond(half, half), "het midden hoort erbij")
	test.check(MissionBadge.in_diamond(half, 0) and MissionBadge.in_diamond(0, half)
			and MissionBadge.in_diamond(last, half) and MissionBadge.in_diamond(half, last), "de vier punten ook")
	test.check(not MissionBadge.in_diamond(0, 0) and not MissionBadge.in_diamond(last, 0)
			and not MissionBadge.in_diamond(0, last) and not MissionBadge.in_diamond(last, last), "de hoeken van het vierkant niet")
	test.check(MissionBadge.in_diamond(half - 1, 1) and not MissionBadge.in_diamond(half - 2, 1), "per rij een pixel breder naar elke kant")
	var pixels := 0
	for row in MissionBadge.DIAMOND_PIXELS:
		for column in MissionBadge.DIAMOND_PIXELS:
			if MissionBadge.in_diamond(column, row):
				pixels += 1
	test.check(pixels == 2 * half * (half + 1) + 1, "een hele ruit (%d pixels)" % pixels)


func test_badge_exclamation_mark(test) -> void:
	var half := MissionBadge.DIAMOND_PIXELS / 2
	test.check(MissionBadge.in_mark(half, 3) and MissionBadge.in_mark(half, 9), "de streep van rij 3 tot en met 9")
	test.check(MissionBadge.in_mark(half - 1, 6) and MissionBadge.in_mark(half + 1, 6), "drie pixels breed")
	test.check(not MissionBadge.in_mark(half - 2, 6) and not MissionBadge.in_mark(half + 2, 6), "niet breder")
	test.check(not MissionBadge.in_mark(half, 2) and not MissionBadge.in_mark(half, 10), "een gat tussen streep en punt")
	test.check(MissionBadge.in_mark(half, 11) and MissionBadge.in_mark(half, 12) and not MissionBadge.in_mark(half, 13), "de punt eronder: twee rijen")
	var inside := true
	for row in MissionBadge.DIAMOND_PIXELS:
		for column in MissionBadge.DIAMOND_PIXELS:
			if MissionBadge.in_mark(column, row) and not MissionBadge.in_diamond(column, row):
				inside = false
	test.check(inside, "het hele uitroepteken ligt in de ruit")


func test_badge_shade_bevels_the_edge(test) -> void:
	var half := MissionBadge.DIAMOND_PIXELS / 2
	var last := MissionBadge.DIAMOND_PIXELS - 1
	var amber := UiStyle.ACCENT
	test.check(MissionBadge.shade(half, half, amber) == amber, "binnenin: de kleur zelf")
	test.check(MissionBadge.shade(half, 0, amber).is_equal_approx(amber.lightened(0.35)), "de rand linksboven lichter")
	test.check(MissionBadge.shade(0, half, amber).is_equal_approx(amber.lightened(0.35)), "ook de linker punt")
	test.check(MissionBadge.shade(half, last, amber).is_equal_approx(amber.darkened(0.3)), "de rand rechtsonder donkerder")
	test.check(MissionBadge.shade(last - 1, half + 1, amber).is_equal_approx(amber.darkened(0.3)), "ook schuin rechtsonder")
	test.check(MissionBadge.shade(half, 1, amber) == amber, "een pixel van de rand af: weer de kleur zelf")


func test_badge_sparkles_blink_in_turn(test) -> void:
	var turn_seconds := MissionBadge.SPARKLE_SECONDS
	test.check(MissionBadge.sparkle_arms(0.0, 0) == 1, "de eerste komt op: klein")
	test.check(MissionBadge.sparkle_arms(0.2 * turn_seconds, 0) == 2, "dan groot")
	test.check(MissionBadge.sparkle_arms(0.4 * turn_seconds, 0) == 1, "dan weer klein")
	test.check(MissionBadge.sparkle_arms(0.5 * turn_seconds, 0) == 0 and MissionBadge.sparkle_arms(0.9 * turn_seconds, 0) == 0, "en de rest van zijn beurt uit")
	test.check(MissionBadge.sparkle_arms(1.2 * turn_seconds, 0) == 2, "de beurt daarna weer")
	test.check(MissionBadge.sparkle_arms(0.0, 1) == 0, "de tweede is dan nog uit")
	test.check(MissionBadge.sparkle_arms(0.45 * turn_seconds, 1) == 2, "en komt een kwart beurt later")
	var seen := {}
	for step in 40:
		for sparkle_index in MissionBadge.SPARKLES.size():
			if MissionBadge.sparkle_arms(step * turn_seconds / 40.0, sparkle_index) > 0:
				seen[sparkle_index] = true
	test.check(seen.size() == MissionBadge.SPARKLES.size(), "in één beurt komen ze allemaal langs")


func test_badge_bobs_only_while_seen(test) -> void:
	var badge := MissionBadge.new()
	test.check(badge.colour == UiStyle.ACCENT and badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "amber, klikken gaan erdoorheen")
	badge._process(1.0)
	test.check(badge._clock == 0.0, "niet in beeld: de klok staat stil")
	tree.root.add_child(badge)
	badge._process(0.4)
	test.check(is_equal_approx(badge._clock, 0.4), "in beeld: hij loopt")
	badge.free()
