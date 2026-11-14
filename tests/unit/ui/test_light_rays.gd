extends RefCounted
## Unit tests of scripts/ui/widgets/light_rays.gd on its own: the rays behind a reward or a
## new mission (what its drawing depends on: sizes, shapes, flags, clocks).
##   tests/run_unit_tests.sh light_rays

const LightRays = preload("res://scripts/ui/widgets/light_rays.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_light_rays_start_with_the_usual_look(test) -> void:
	var rays := LightRays.new()
	test.check(rays.count == LightRays.RAY_COUNT and rays.colour == LightRays.RAY_COLOUR, "het gewone aantal en de gewone kleur")
	test.check(is_equal_approx(rays.length, LightRays.RAY_LENGTH) and is_equal_approx(rays.spread, LightRays.RAY_SPREAD)
			and is_equal_approx(rays.speed, LightRays.RAY_SPEED), "de gewone lengte, breedte en snelheid")
	test.check(rays.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	rays.free()


func test_light_rays_turn_only_while_seen(test) -> void:
	var rays := LightRays.new()
	rays._process(0.5)
	test.check(rays._clock == 0.0, "niet in beeld: ze staan stil")
	tree.root.add_child(rays)
	rays._process(0.5)
	rays._process(0.25)
	test.check(is_equal_approx(rays._clock, 0.75), "in beeld: de klok loopt (%s)" % rays._clock)
	rays.visible = false
	rays._process(1.0)
	test.check(is_equal_approx(rays._clock, 0.75), "verborgen: weer stil")
	rays.free()
