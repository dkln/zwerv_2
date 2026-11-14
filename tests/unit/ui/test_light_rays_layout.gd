extends RefCounted
## Unit tests of the shape of the light rays (scripts/ui/widgets/light_rays_layout.gd).
##   tests/run_unit_tests.sh light_rays_layout

const LightRaysLayout = preload("res://scripts/ui/widgets/light_rays_layout.gd")


func test_ray_triangle(test) -> void:
	var middle := Vector2(50, 40)
	var ray := LightRaysLayout.ray_triangle(middle, 100.0, 0.0, 0.1)
	test.check(ray.size() == 3 and ray[0] == middle, "een driehoek vanuit het midden")
	test.check(is_equal_approx(ray[1].distance_to(middle), 100.0) and is_equal_approx(ray[2].distance_to(middle), 100.0), "`reach` px lang")
	test.check(is_equal_approx((ray[1] - middle).angle(), -0.1) and is_equal_approx((ray[2] - middle).angle(), 0.1), "`spread` naar elke kant van de hoek")
	var turned := LightRaysLayout.ray_triangle(middle, 100.0, PI * 0.5)
	var along := ((turned[1] + turned[2]) * 0.5 - middle).normalized()
	test.check(along.is_equal_approx(Vector2.DOWN), "gedraaid: de straal wijst langs de hoek (%s)" % along)
	test.check(is_equal_approx(absf((turned[1] - middle).angle_to(turned[2] - middle)), 2.0 * LightRaysLayout.RAY_SPREAD), "zonder breedte: de gewone")
