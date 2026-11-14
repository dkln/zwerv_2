extends RefCounted
## Unit tests of where the finds of the streets lie (scripts/world/things/street_finds_rules.gd):
## the ground they lie on, the rings round the start, which cells get one, walking over one
## and leaving one alone that could not be taken.
##   tests/run_unit_tests.sh street_finds_rules

const StreetFindsRules = preload("res://scripts/world/things/street_finds_rules.gd")


static func _middle(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * 4.0 + 2.0, 0.0, cell.z * 4.0 + 2.0)


func test_find_ground_is_square_and_pavement(test) -> void:
	var folders := ["plein/", "stoep/"]
	test.check(StreetFindsRules.is_find_ground("plein/klinkers", folders), "een plein: ja")
	test.check(StreetFindsRules.is_find_ground("stoep/tegel_rand", folders), "een stoep: ja")
	test.check(not StreetFindsRules.is_find_ground("weg/asfalt", folders), "een weg: nee")
	test.check(not StreetFindsRules.is_find_ground("groen/plein/gras", folders), "alleen aan het begin van de naam")
	test.check(not StreetFindsRules.is_find_ground("plein/klinkers", []), "geen mappen: nergens")


func test_ring_by_distance(test) -> void:
	test.check(StreetFindsRules.ring(2.0, 3.0, 60.0, 400.0) == "", "te dichtbij: geen")
	test.check(StreetFindsRules.ring(3.0, 3.0, 60.0, 400.0) == "near", "vanaf de kleinste afstand: dichtbij")
	test.check(StreetFindsRules.ring(60.0, 3.0, 60.0, 400.0) == "near", "tot en met `near`: dichtbij")
	test.check(StreetFindsRules.ring(60.5, 3.0, 60.0, 400.0) == "far", "daarna: ver")
	test.check(StreetFindsRules.ring(400.0, 3.0, 60.0, 400.0) == "far", "tot en met `reach`: ver")
	test.check(StreetFindsRules.ring(401.0, 3.0, 60.0, 400.0) == "", "te ver: geen")


func test_choose_takes_near_first_then_far(test) -> void:
	var near_cells := [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)]
	var far_cells := [Vector3i(20, 0, 0), Vector3i(21, 0, 0), Vector3i(22, 0, 0)]
	var chosen := StreetFindsRules.choose(near_cells, far_cells, 2, 4, 0.0, _middle)
	test.check(chosen == [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(20, 0, 0), Vector3i(21, 0, 0)], "twee dichtbij, dan ver tot het aantal (%s)" % str(chosen))
	test.check(StreetFindsRules.choose(near_cells, far_cells, 0, 1, 0.0, _middle) == [Vector3i(20, 0, 0)], "geen dichtbij: de eerste verre")
	test.check(StreetFindsRules.choose(near_cells, far_cells, 0, 9, 0.0, _middle).size() == 3, "niet meer dan er cellen zijn")
	test.check(StreetFindsRules.choose([], [], 2, 3, 0.0, _middle).is_empty(), "geen cellen: niets")
	test.check(StreetFindsRules.choose(near_cells, far_cells, 3, 2, 0.0, _middle).size() == 3, "meer dichtbij gevraagd dan het aantal: die blijven")


func test_choose_keeps_far_ones_apart(test) -> void:
	# cells of 4 m: 20 and 21 lie 4 m apart, 20 and 30 lie 40 m apart
	var far_cells := [Vector3i(20, 0, 0), Vector3i(21, 0, 0), Vector3i(30, 0, 0), Vector3i(31, 0, 0), Vector3i(45, 0, 0)]
	var chosen := StreetFindsRules.choose([], far_cells, 0, 3, 30.0, _middle)
	test.check(chosen == [Vector3i(20, 0, 0), Vector3i(30, 0, 0), Vector3i(45, 0, 0)], "meer dan 30 m uit elkaar (%s)" % str(chosen))
	var with_near := StreetFindsRules.choose([Vector3i(19, 0, 0)], far_cells, 1, 2, 30.0, _middle)
	test.check(with_near == [Vector3i(19, 0, 0), Vector3i(30, 0, 0)], "ook uit de buurt van die dichtbij (%s)" % str(with_near))


func test_walked_over(test) -> void:
	var feet := Vector3(10.0, 0.0, 10.0)
	test.check(StreetFindsRules.walked_over(feet, Vector3(10.5, 0.3, 10.0), 1.0), "eroverheen: ja")
	test.check(not StreetFindsRules.walked_over(feet, Vector3(11.5, 0.3, 10.0), 1.0), "ernaast: nee")
	test.check(not StreetFindsRules.walked_over(feet, Vector3(10.5, 4.0, 10.0), 1.0), "een verdieping hoger: nee")
	test.check(not StreetFindsRules.walked_over(feet, Vector3(10.0, StreetFindsRules.HEIGHT_REACH, 10.0), 1.0), "precies op de grens van de hoogte: nee")
	test.check(not StreetFindsRules.walked_over(feet, Vector3(11.0, 0.0, 10.0), 1.0), "precies op de afstand: nee")
	test.check(StreetFindsRules.walked_over(feet, Vector3(10.0, -1.0, 10.0), 1.0), "een eindje lager: ja")


func test_may_take_only_awake_alive_and_not_just_refused(test) -> void:
	test.check(StreetFindsRules.may_take(false, false, 5.0, 0.0), "wakker en levend: ja")
	test.check(not StreetFindsRules.may_take(true, false, 5.0, 0.0), "slapend: nee")
	test.check(not StreetFindsRules.may_take(false, true, 5.0, 0.0), "dood: nee")
	test.check(not StreetFindsRules.may_take(false, false, 5.0, 6.0), "net geweigerd: nee")
	test.check(StreetFindsRules.may_take(false, false, 6.0, 6.0), "de wachttijd om: weer ja")


func test_refused_until_is_the_retry_time_later(test) -> void:
	test.check(is_equal_approx(StreetFindsRules.refused_until(10.0), 10.0 + StreetFindsRules.RETRY_SECONDS), "even met rust gelaten")
	test.check(StreetFindsRules.RETRY_SECONDS > 0.0, "een wachttijd")


func test_built_over_on_either_storey(test) -> void:
	test.check(not StreetFindsRules.built_over(-1, -1, -1), "niets erboven: open")
	test.check(StreetFindsRules.built_over(4, -1, -1), "een gebouw op de begane grond")
	test.check(StreetFindsRules.built_over(-1, 2, -1), "een gebouw op de verdieping erboven")


func test_defaults_of_a_kind_of_find(test) -> void:
	test.check(StreetFindsRules.CLOSEST > 0.0 and StreetFindsRules.APART == 0.0 and StreetFindsRules.SCATTER > 0.0, "dichtbij, overal, een beetje uit het midden")
	test.check(StreetFindsRules.FIND_GROUND == ["plein/", "stoep/"], "pleinen en stoepen")
