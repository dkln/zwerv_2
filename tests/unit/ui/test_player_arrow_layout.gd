extends RefCounted
## Unit tests of the shape of the arrows on the maps
## (scripts/ui/widgets/player_arrow_layout.gd).
##   tests/run_unit_tests.sh player_arrow_layout

const PlayerArrowLayout = preload("res://scripts/ui/widgets/player_arrow_layout.gd")


func test_arrow_shape_pointing_up(test) -> void:
	var arrow := PlayerArrowLayout.shape(Vector2(0, -10), Vector2.UP, 20.0, 8.0, 6.0, 2.0)
	test.check(arrow.size() == 7, "zeven punten: een kop en een staart")
	test.check(arrow[0] == Vector2(0, -10), "de punt eerst")
	var lowest := -INF
	var widest := 0.0
	var sum_of_sides := 0.0
	for point in arrow:
		lowest = maxf(lowest, point.y)
		widest = maxf(widest, absf(point.x))
		sum_of_sides += point.x
	test.check(is_equal_approx(lowest, 10.0), "de staart eindigt `length` px achter de punt (%s)" % lowest)
	test.check(is_equal_approx(widest, 6.0), "de kop `head_half` px naar elke kant")
	test.check(is_zero_approx(sum_of_sides), "links en rechts gelijk")
	test.check(is_equal_approx(arrow[1].y, -2.0) and is_equal_approx(arrow[2].y, -2.0), "de kop is `head_length` lang")
	test.check(is_equal_approx(absf(arrow[3].x), 2.0) and is_equal_approx(absf(arrow[4].x), 2.0), "de staart `tail_half` px naar elke kant")


func test_arrow_shape_turns_with_its_way(test) -> void:
	var up := PlayerArrowLayout.shape(Vector2.ZERO, Vector2.UP, 20.0, 8.0, 6.0, 2.0)
	var right := PlayerArrowLayout.shape(Vector2.ZERO, Vector2.RIGHT, 20.0, 8.0, 6.0, 2.0)
	var same := true
	for point_index in up.size():
		# up turned a quarter clockwise (on the screen) is right
		var turned := Vector2(-up[point_index].y, up[point_index].x)
		same = same and turned.is_equal_approx(right[point_index])
	test.check(same, "naar rechts: dezelfde pijl een kwartslag gedraaid")
	var moved := PlayerArrowLayout.shape(Vector2(30, 40), Vector2.RIGHT, 20.0, 8.0, 6.0, 2.0)
	test.check(moved[0] == Vector2(30, 40) and moved[3].is_equal_approx(right[3] + Vector2(30, 40)), "en hij schuift mee met de punt")
