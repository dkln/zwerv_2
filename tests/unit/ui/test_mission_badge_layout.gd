extends RefCounted
## Unit tests of the shape of the emblem of a new mission
## (scripts/ui/widgets/mission_badge_layout.gd).
##   tests/run_unit_tests.sh mission_badge_layout

const MissionBadgeLayout = preload("res://scripts/ui/widgets/mission_badge_layout.gd")


func test_badge_diamond(test) -> void:
	var last := MissionBadgeLayout.DIAMOND_PIXELS - 1
	var half := MissionBadgeLayout.DIAMOND_PIXELS / 2
	test.check(MissionBadgeLayout.DIAMOND_PIXELS % 2 == 1, "een oneven aantal pixels: er is een midden")
	test.check(MissionBadgeLayout.in_diamond(half, half), "het midden hoort erbij")
	test.check(MissionBadgeLayout.in_diamond(half, 0) and MissionBadgeLayout.in_diamond(0, half)
			and MissionBadgeLayout.in_diamond(last, half) and MissionBadgeLayout.in_diamond(half, last), "de vier punten ook")
	test.check(not MissionBadgeLayout.in_diamond(0, 0) and not MissionBadgeLayout.in_diamond(last, 0)
			and not MissionBadgeLayout.in_diamond(0, last) and not MissionBadgeLayout.in_diamond(last, last), "de hoeken van het vierkant niet")
	test.check(MissionBadgeLayout.in_diamond(half - 1, 1) and not MissionBadgeLayout.in_diamond(half - 2, 1), "per rij een pixel breder naar elke kant")
	var pixels := 0
	for row in MissionBadgeLayout.DIAMOND_PIXELS:
		for column in MissionBadgeLayout.DIAMOND_PIXELS:
			if MissionBadgeLayout.in_diamond(column, row):
				pixels += 1
	test.check(pixels == 2 * half * (half + 1) + 1, "een hele ruit (%d pixels)" % pixels)


func test_badge_exclamation_mark(test) -> void:
	var half := MissionBadgeLayout.DIAMOND_PIXELS / 2
	test.check(MissionBadgeLayout.in_mark(half, 3) and MissionBadgeLayout.in_mark(half, 9), "de streep van rij 3 tot en met 9")
	test.check(MissionBadgeLayout.in_mark(half - 1, 6) and MissionBadgeLayout.in_mark(half + 1, 6), "drie pixels breed")
	test.check(not MissionBadgeLayout.in_mark(half - 2, 6) and not MissionBadgeLayout.in_mark(half + 2, 6), "niet breder")
	test.check(not MissionBadgeLayout.in_mark(half, 2) and not MissionBadgeLayout.in_mark(half, 10), "een gat tussen streep en punt")
	test.check(MissionBadgeLayout.in_mark(half, 11) and MissionBadgeLayout.in_mark(half, 12) and not MissionBadgeLayout.in_mark(half, 13), "de punt eronder: twee rijen")
	var inside := true
	for row in MissionBadgeLayout.DIAMOND_PIXELS:
		for column in MissionBadgeLayout.DIAMOND_PIXELS:
			if MissionBadgeLayout.in_mark(column, row) and not MissionBadgeLayout.in_diamond(column, row):
				inside = false
	test.check(inside, "het hele uitroepteken ligt in de ruit")


func test_badge_sparkles_blink_in_turn(test) -> void:
	var turn_seconds := MissionBadgeLayout.SPARKLE_SECONDS
	test.check(MissionBadgeLayout.sparkle_arms(0.0, 0) == 1, "de eerste komt op: klein")
	test.check(MissionBadgeLayout.sparkle_arms(0.2 * turn_seconds, 0) == 2, "dan groot")
	test.check(MissionBadgeLayout.sparkle_arms(0.4 * turn_seconds, 0) == 1, "dan weer klein")
	test.check(MissionBadgeLayout.sparkle_arms(0.5 * turn_seconds, 0) == 0 and MissionBadgeLayout.sparkle_arms(0.9 * turn_seconds, 0) == 0, "en de rest van zijn beurt uit")
	test.check(MissionBadgeLayout.sparkle_arms(1.2 * turn_seconds, 0) == 2, "de beurt daarna weer")
	test.check(MissionBadgeLayout.sparkle_arms(0.0, 1) == 0, "de tweede is dan nog uit")
	test.check(MissionBadgeLayout.sparkle_arms(0.45 * turn_seconds, 1) == 2, "en komt een kwart beurt later")
	var seen := {}
	for step in 40:
		for sparkle_index in MissionBadgeLayout.SPARKLES.size():
			if MissionBadgeLayout.sparkle_arms(step * turn_seconds / 40.0, sparkle_index) > 0:
				seen[sparkle_index] = true
	test.check(seen.size() == MissionBadgeLayout.SPARKLES.size(), "in één beurt komen ze allemaal langs")
