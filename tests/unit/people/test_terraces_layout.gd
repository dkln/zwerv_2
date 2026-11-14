extends RefCounted
## Unit tests of where the people on the terraces sit (scripts/world/people/terraces_layout.gd).
##   tests/run_unit_tests.sh terraces_layout

const TerracesLayout = preload("res://scripts/world/people/terraces_layout.gd")


func test_a_chair_on_either_side_of_the_table(test) -> void:
	var table := Vector3(10.0, 3.0, 20.0)
	var front := TerracesLayout.chair_spot(table, Basis.IDENTITY, 1.0, 0.25)
	var back := TerracesLayout.chair_spot(table, Basis.IDENTITY, -1.0, 0.25)
	test.check(front.is_equal_approx(Vector3(10.0, 0.25, 20.0 + TerracesLayout.CHAIR_OFFSET)), "de stoel voor de tafel, op de grond")
	test.check(back.is_equal_approx(Vector3(10.0, 0.25, 20.0 - TerracesLayout.CHAIR_OFFSET)), "en die erachter")
	test.check(TerracesLayout.SIDES.size() == 2, "twee stoelen per tafel")
	test.check(TerracesLayout.TERRACE_TILES.size() == 3 and TerracesLayout.SEAT_HEIGHT > 0.0, "de terrastegels en de zithoogte")


func test_a_turned_tile_turns_its_chairs(test) -> void:
	var quarter := Basis(Vector3.UP, PI * 0.5)
	var chair := TerracesLayout.chair_spot(Vector3.ZERO, quarter, 1.0, 0.0)
	test.check(chair.is_equal_approx(Vector3(TerracesLayout.CHAIR_OFFSET, 0.0, 0.0)), "een kwartslag gedraaid: de stoel opzij (%s)" % chair)


func test_everyone_faces_the_table(test) -> void:
	test.check(is_equal_approx(absf(TerracesLayout.facing_of(Basis.IDENTITY, 1.0)), PI), "voor de tafel: kijkt naar -z")
	test.check(is_equal_approx(TerracesLayout.facing_of(Basis.IDENTITY, -1.0), 0.0), "erachter: kijkt naar +z")
	for side: float in TerracesLayout.SIDES:
		var turn := Basis(Vector3.UP, 0.7)
		var chair := TerracesLayout.chair_spot(Vector3.ZERO, turn, side, 0.0)
		var angle := TerracesLayout.facing_of(turn, side)
		var facing := Vector3(sin(angle), 0.0, cos(angle))
		test.check(facing.dot(-chair.normalized()) > 0.99, "ook gedraaid kijkt de gast naar de tafel")
