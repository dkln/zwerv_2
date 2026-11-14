extends RefCounted
## Unit tests of scripts/ui/widgets/mission_badge.gd on its own: the emblem of a new mission
## (what its drawing depends on: sizes, shapes, flags, clocks).
##   tests/run_unit_tests.sh mission_badge

const MissionBadge = preload("res://scripts/ui/widgets/mission_badge.gd")
const MissionBadgeLayout = preload("res://scripts/ui/widgets/mission_badge_layout.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_badge_shade_bevels_the_edge(test) -> void:
	var half := MissionBadgeLayout.DIAMOND_PIXELS / 2
	var last := MissionBadgeLayout.DIAMOND_PIXELS - 1
	var amber := UiStyle.ACCENT
	test.check(MissionBadge.shade(half, half, amber) == amber, "binnenin: de kleur zelf")
	test.check(MissionBadge.shade(half, 0, amber).is_equal_approx(amber.lightened(0.35)), "de rand linksboven lichter")
	test.check(MissionBadge.shade(0, half, amber).is_equal_approx(amber.lightened(0.35)), "ook de linker punt")
	test.check(MissionBadge.shade(half, last, amber).is_equal_approx(amber.darkened(0.3)), "de rand rechtsonder donkerder")
	test.check(MissionBadge.shade(last - 1, half + 1, amber).is_equal_approx(amber.darkened(0.3)), "ook schuin rechtsonder")
	test.check(MissionBadge.shade(half, 1, amber) == amber, "een pixel van de rand af: weer de kleur zelf")


func test_badge_bobs_only_while_seen(test) -> void:
	var badge := MissionBadge.new()
	test.check(badge.colour == UiStyle.ACCENT and badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "amber, klikken gaan erdoorheen")
	badge._process(1.0)
	test.check(badge._clock == 0.0, "niet in beeld: de klok staat stil")
	tree.root.add_child(badge)
	badge._process(0.4)
	test.check(is_equal_approx(badge._clock, 0.4), "in beeld: hij loopt")
	badge.free()
