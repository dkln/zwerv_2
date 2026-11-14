extends RefCounted
## Unit tests of the logic of the road network (scripts/traffic/road_network_rules.gd): what a
## tile gives its cell, steps over the road (and ramps), the direction of two-way cells from
## the road around them, kinds and limits passed on, who is allowed and how rails join. On
## small hand-made tables of lanes, without tiles or a GridMap.
##   tests/run_unit_tests.sh road_network_rules

const RoadNetworkRules = preload("res://scripts/traffic/road_network_rules.gd")

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)
const NONE := RoadNetworkRules.NONE
const UNTURNED := Basis.IDENTITY


## A quarter turn (to the left, seen from above) `quarters` times.
static func turned(quarters: int) -> Basis:
	return Basis(Vector3.UP, quarters * PI * 0.5)


## Lanes of a row of cells along x at z (y 0): `row[x]` the headings of cell x.
static func row_lanes(row: Array, z := 0) -> Dictionary:
	var lanes := {}
	for column in row.size():
		if not (row[column] as Array).is_empty():
			lanes[Vector3i(column, 0, z)] = (row[column] as Array).duplicate()
	return lanes


# ------------------------------------------------------------------ reading a tile

func test_flat_and_heading_of_side(test) -> void:
	test.check(RoadNetworkRules.flat(Vector3(0.99, 0.3, -0.01)) == EAST, "afgerond op de kaart, zonder hoogte")
	test.check(RoadNetworkRules.heading_of_side(UNTURNED, "N") == NORTH, "niet gedraaid: N is het noorden")
	test.check(RoadNetworkRules.heading_of_side(UNTURNED, "E") == EAST, "E het oosten")
	test.check(RoadNetworkRules.heading_of_side(turned(1), "N") == WEST, "een kwartslag: N wijst naar het westen")
	test.check(RoadNetworkRules.heading_of_side(turned(2), "N") == SOUTH, "een halve slag: naar het zuiden")
	test.check(RoadNetworkRules.heading_of_side(turned(3), "S") == WEST, "driekwart: S wijst naar het westen")


func test_choice_for_tile(test) -> void:
	var choice := {"tile": "weg/asfalt", "lanes": ["N"]}
	test.check(RoadNetworkRules.choice_for_tile(choice, "weg/asfalt") == choice, "voor deze tegel: de keuze")
	test.check(RoadNetworkRules.choice_for_tile(choice, "weg/zebrapad").is_empty(), "er ligt een andere tegel: de keuze telt niet meer")
	test.check(RoadNetworkRules.choice_for_tile({}, "weg/asfalt").is_empty(), "geen keuze: leeg")


func test_read_tile_of_a_plain_lane(test) -> void:
	var reading := RoadNetworkRules.read_tile({"lanes": ["N"], "road": "hoofdweg"}, {}, turned(3), true)
	test.check(reading.headings == ([EAST] as Array[Vector2i]), "de rijstrook draait met de tegel mee")
	test.check(reading.only == RoadNetworkRules.ROAD_USER_KINDS, "zonder 'only': alle weggebruikers")
	test.check(reading.kind == RoadNetworkRules.Kind.MAIN_ROAD and reading.speed == 50.0, "soort weg en zijn limiet")
	test.check(not reading.chosen and not reading.chosen_kinds and not reading.chosen_speed, "niets gekozen")
	test.check(not reading.has("open_axes") and not reading.has("rise") and not reading.has("rails"), "geen open as, helling of rails")


func test_read_tile_without_traffic_is_for_nobody(test) -> void:
	var reading := RoadNetworkRules.read_tile({}, {}, UNTURNED, false)
	test.check(reading.only == [] and reading.headings.is_empty(), "water of een muur: voor niemand, geen rijstroken")
	test.check(not reading.has("speed") and not reading.has("kind"), "geen limiet of soort")
	var kerb := RoadNetworkRules.read_tile({}, {}, UNTURNED, true)
	test.check(kerb.only == RoadNetworkRules.ROAD_USER_KINDS and kerb.headings.is_empty(), "verkeer zonder rijstroken: geen wegcel")
	var unknown := RoadNetworkRules.read_tile({"lanes": ["X", "N"]}, {}, UNTURNED, true)
	test.check(unknown.headings == ([NORTH] as Array[Vector2i]), "een onbekende kant wordt overgeslagen")


func test_read_tile_two_way_axes_are_left_open(test) -> void:
	var plain := RoadNetworkRules.read_tile({"lanes": ["N", "S", "E", "W"]}, {}, UNTURNED, true)
	test.check(plain.open_axes == [EAST, SOUTH], "kaal asfalt: beide assen open")
	test.check(not plain.has("kind") and not plain.has("speed"), "zonder soort: die komt van de weg eromheen")
	var zebra := RoadNetworkRules.read_tile({"lanes": ["N", "S"]}, {}, turned(1), true)
	test.check(zebra.open_axes == [EAST], "een zebra, een kwartslag gedraaid: open langs x")
	var crossing := RoadNetworkRules.read_tile({"lanes": ["N", "E"]}, {}, UNTURNED, true)
	test.check(not crossing.has("open_axes"), "één richting per as: niets open")


func test_read_tile_speed_rise_rails_and_only(test) -> void:
	var cycle_path := RoadNetworkRules.read_tile({"lanes": ["N"], "road": "straat", "speed": 30, "only": ["fiets", "brommer"]}, {}, UNTURNED, true)
	test.check(cycle_path.speed == 30.0, "de limiet van de tegel gaat voor die van de soort weg")
	test.check(cycle_path.only == ["fiets", "brommer"], "alleen wie de tegel toelaat")
	var ramp := RoadNetworkRules.read_tile({"lanes": ["N"], "rise": 1}, {}, turned(3), true)
	test.check(ramp.rise == [EAST, 1.0], "de helling stijgt naar de achterkant van de tegel, meegedraaid")
	var rails := RoadNetworkRules.read_tile({"rails": ["SN", "SE"], "only": ["tram"]}, {}, turned(2), true)
	test.check(rails.rails == [[NORTH, SOUTH], [NORTH, WEST]], "de rails draaien mee (%s)" % str(rails.rails))
	test.check(rails.headings.is_empty(), "een spoortegel heeft geen rijstroken")


func test_read_tile_with_choices_of_the_placed_tile(test) -> void:
	var data := {"lanes": ["N", "S"], "road": "snelweg", "speed": 90, "only": ["auto"]}
	var reading := RoadNetworkRules.read_tile(data, {"tile": "x", "lanes": ["E", "W"], "kinds": ["fiets"], "speed": 15}, UNTURNED, true)
	test.check(reading.headings == ([EAST, WEST] as Array[Vector2i]), "gekozen rijstroken vervangen die van de tegel")
	test.check(reading.chosen and not reading.has("open_axes"), "en worden niet uit de omgeving beslist")
	test.check(reading.only == ["fiets"] and reading.chosen_kinds, "gekozen weggebruikers")
	test.check(reading.speed == 15.0 and reading.chosen_speed, "de gekozen limiet gaat voor die van tegel en soort")
	test.check(reading.kind == RoadNetworkRules.Kind.MOTORWAY, "de soort weg blijft")
	var closed := RoadNetworkRules.read_tile(data, {"tile": "x", "kinds": []}, UNTURNED, true)
	test.check(closed.only == [] and closed.chosen_kinds, "een lege lijst sluit de cel voor iedereen")
	test.check(closed.speed == 90.0 and not closed.chosen and closed.has("open_axes"), "zonder gekozen stroken of limiet: die van de tegel")
	var off_road := RoadNetworkRules.read_tile({}, {"tile": "x", "speed": 20}, UNTURNED, false)
	test.check(off_road.speed == 20.0 and off_road.headings.is_empty(), "een gekozen limiet blijft ook zonder rijstroken")


# ------------------------------------------------------------------ queries

func test_on_axis_is_crossing_is_along(test) -> void:
	test.check(RoadNetworkRules.on_axis([NORTH, EAST, SOUTH], SOUTH) == ([NORTH, SOUTH] as Array[Vector2i]), "beide kanten langs de as")
	test.check(RoadNetworkRules.on_axis([NORTH], EAST).is_empty(), "niets langs de andere as")
	test.check(RoadNetworkRules.on_axis([], EAST).is_empty(), "geen stroken: niets")
	test.check(RoadNetworkRules.is_crossing([NORTH, EAST]), "stroken op beide assen: een kruising")
	test.check(not RoadNetworkRules.is_crossing([NORTH, SOUTH]), "één as: geen kruising")
	test.check(not RoadNetworkRules.is_crossing([]), "geen stroken: geen kruising")
	test.check(RoadNetworkRules.is_along([EAST], WEST) and RoadNetworkRules.is_along([EAST], EAST), "langs een open as, beide kanten op")
	test.check(not RoadNetworkRules.is_along([EAST], NORTH) and not RoadNetworkRules.is_along([], NORTH), "dwars erop of geen open as: niet")


func test_allows(test) -> void:
	test.check(RoadNetworkRules.allows(["auto", "fiets"], "fiets"), "wie in de lijst staat mag erop")
	test.check(not RoadNetworkRules.allows(["fiets"], "auto"), "wie er niet in staat niet")
	test.check(RoadNetworkRules.allows(["auto"], "bus"), "waar auto's mogen mag de bus ook")
	test.check(RoadNetworkRules.allows(["bus"], "bus") and not RoadNetworkRules.allows(["bus"], "auto"), "een busbaan: alleen de bus")
	test.check(not RoadNetworkRules.allows([], "auto") and not RoadNetworkRules.allows([], "bus"), "voor niemand: niemand")
	test.check(not RoadNetworkRules.allows(["fiets"], "bus"), "geen bus op het fietspad")


func test_metres_per_second(test) -> void:
	test.check(is_equal_approx(RoadNetworkRules.metres_per_second(36.0), 10.0), "36 km/u is 10 m/s")
	test.check(RoadNetworkRules.metres_per_second(0.0) == 0.0, "0 blijft 0")
	for kind: int in RoadNetworkRules.KIND_NAMES.values():
		test.check(RoadNetworkRules.SPEED_LIMIT_KMH.has(kind), "elke soort weg heeft een limiet")


func test_find_and_step_on_the_flat(test) -> void:
	var lanes := row_lanes([[EAST], [EAST], [], [EAST]])
	test.check(RoadNetworkRules.find(lanes, {}, 1, 0, 0) == Vector3i(1, 0, 0), "de cel op deze laag")
	test.check(RoadNetworkRules.find(lanes, {}, 2, 0, 0) == NONE, "geen weg: NONE")
	test.check(RoadNetworkRules.step(lanes, {}, Vector3i(0, 0, 0), EAST) == Vector3i(1, 0, 0), "een stap naar het oosten")
	test.check(RoadNetworkRules.step(lanes, {}, Vector3i(1, 0, 0), EAST) == NONE, "een gat: NONE")
	test.check(RoadNetworkRules.step(lanes, {}, Vector3i(0, 0, 0), NORTH) == NONE, "naast de weg: NONE")


func test_find_and_step_onto_and_off_a_ramp(test) -> void:
	# (0,0,0) flat, (1,0,0) a ramp up to the east, (2,1,0) the road a level higher
	var lanes := {Vector3i(0, 0, 0): [EAST], Vector3i(1, 0, 0): [EAST], Vector3i(2, 1, 0): [EAST], Vector3i(5, 1, 0): [EAST], Vector3i(6, 3, 0): [EAST]}
	var rises := {Vector3i(1, 0, 0): [EAST, 1.0]}
	test.check(RoadNetworkRules.step(lanes, rises, Vector3i(0, 0, 0), EAST) == Vector3i(1, 0, 0), "de helling op, zelfde laag")
	test.check(RoadNetworkRules.step(lanes, rises, Vector3i(1, 0, 0), EAST) == Vector3i(2, 1, 0), "van de helling af: een laag hoger")
	test.check(RoadNetworkRules.step(lanes, rises, Vector3i(2, 1, 0), WEST) == Vector3i(1, 0, 0), "terug de helling op: een laag lager")
	test.check(RoadNetworkRules.find(lanes, rises, 2, 0, 0, Vector3i(0, 0, 0)) == NONE, "zonder helling geen andere laag")
	test.check(RoadNetworkRules.find(lanes, rises, 6, 0, 1, Vector3i(1, 0, 0)) == NONE, "twee lagen verschil: niet met één laag speling")
	test.check(RoadNetworkRules.find(lanes, rises, 6, 0, 1, Vector3i(1, 0, 0), 2) == Vector3i(6, 3, 0), "wel met twee lagen speling")


func test_rails(test) -> void:
	var straight := [[SOUTH, NORTH]]
	test.check(RoadNetworkRules.rail_connects(straight, NORTH, NORTH), "rechtdoor naar het noorden")
	test.check(RoadNetworkRules.rail_connects(straight, SOUTH, SOUTH), "en terug")
	test.check(not RoadNetworkRules.rail_connects(straight, NORTH, EAST), "geen bocht op recht spoor")
	var wissel := [[SOUTH, NORTH], [SOUTH, EAST]]
	test.check(RoadNetworkRules.rail_connects(wissel, NORTH, EAST) and RoadNetworkRules.rail_connects(wissel, WEST, SOUTH), "een wissel: ook de bocht, beide kanten op")
	test.check(not RoadNetworkRules.rail_connects(wissel, SOUTH, EAST), "van noord naar oost ligt geen rail")
	test.check(not RoadNetworkRules.rail_connects([], NORTH, NORTH), "geen rails: geen verbinding")
	test.check(RoadNetworkRules.rail_headings(wissel) == ([SOUTH, NORTH, EAST] as Array[Vector2i]), "elke kant één keer")
	test.check(RoadNetworkRules.rail_headings([]).is_empty(), "geen rails: geen kanten")


func test_nearest(test) -> void:
	var lanes := {Vector3i(0, 0, 0): [EAST], Vector3i(5, 0, 0): [EAST], Vector3i(9, 0, 0): [WEST], Vector3i(8, -6, 0): [EAST], Vector3i(7, 0, 0): [EAST]}
	var only := {Vector3i(0, 0, 0): ["auto"], Vector3i(5, 0, 0): ["auto"], Vector3i(9, 0, 0): ["auto"], Vector3i(8, -6, 0): ["auto"], Vector3i(7, 0, 0): ["fiets"]}
	test.check(RoadNetworkRules.nearest(lanes, only, Vector2i(8, 0), EAST) == Vector3i(5, 0, 0), "de dichtstbijzijnde strook die kant op, voor auto's, op straatniveau")
	test.check(RoadNetworkRules.nearest(lanes, only, Vector2i(8, 0), EAST, "fiets") == Vector3i(7, 0, 0), "voor een fiets: het fietspad")
	test.check(RoadNetworkRules.nearest(lanes, only, Vector2i(8, 0), EAST, "bus") == Vector3i(5, 0, 0), "een bus rijdt waar auto's mogen")
	test.check(RoadNetworkRules.nearest(lanes, only, Vector2i(0, 0), NORTH) == NONE, "geen strook die kant op: NONE")
	test.check(RoadNetworkRules.nearest({Vector3i(8, -6, 0): [EAST]}, only, Vector2i(0, 0), EAST) == Vector3i(8, -6, 0), "alleen de tunnel: dan die")


# ------------------------------------------------------------------ two-way lanes

func test_direction_along_takes_the_nearest_one_way_lane(test) -> void:
	var lanes := row_lanes([[WEST], [EAST, WEST], [EAST, WEST], [EAST, WEST], [EAST]])
	test.check(RoadNetworkRules.direction_along(lanes, {}, Vector3i(1, 0, 0), EAST) == WEST, "de dichtste strook met een richting wint")
	test.check(RoadNetworkRules.direction_along(lanes, {}, Vector3i(3, 0, 0), EAST) == EAST, "aan de andere kant de andere")
	# (the comment in the script says the one ahead wins a tie; as written the one behind does)
	test.check(RoadNetworkRules.direction_along(lanes, {}, Vector3i(2, 0, 0), EAST) == WEST, "even ver: de strook tegen de as in")
	test.check(RoadNetworkRules.direction_along(lanes, {}, Vector3i(2, 0, 0), SOUTH) == Vector2i.ZERO, "dwars ligt geen weg: geen richting")
	var gap := row_lanes([[EAST], [], [EAST, WEST]])
	test.check(RoadNetworkRules.direction_along(gap, {}, Vector3i(2, 0, 0), EAST) == Vector2i.ZERO, "niet over een gat heen")


func test_direction_from_beside(test) -> void:
	# three lanes along x at z 0, 1, 2; the outer ones one-way east, the middle open
	var lanes := {}
	for column in 3:
		lanes[Vector3i(column, 0, 0)] = [EAST]
		lanes[Vector3i(column, 0, 1)] = [EAST, WEST]
		lanes[Vector3i(column, 0, 2)] = [EAST]
	test.check(RoadNetworkRules.direction_from_beside(lanes, {}, Vector3i(1, 0, 1), EAST) == EAST, "de stroken ernaast zijn het eens: mee")
	lanes[Vector3i(1, 0, 2)] = [WEST]
	test.check(RoadNetworkRules.direction_from_beside(lanes, {}, Vector3i(1, 0, 1), EAST) == Vector2i.ZERO, "ze spreken elkaar tegen: onbeslist")
	# two open lanes side by side: each drives on the right
	var two := {}
	for column in 3:
		two[Vector3i(column, 0, 0)] = [EAST, WEST]
		two[Vector3i(column, 0, 1)] = [EAST, WEST]
	test.check(RoadNetworkRules.direction_from_beside(two, {}, Vector3i(1, 0, 1), EAST) == EAST, "de weg links (noord) is de tegenrichting: de zuidelijke strook naar het oosten")
	test.check(RoadNetworkRules.direction_from_beside(two, {}, Vector3i(1, 0, 0), EAST) == WEST, "de noordelijke strook naar het westen: rechts rijden")
	test.check(RoadNetworkRules.direction_from_beside({Vector3i(0, 0, 0): [EAST, WEST], Vector3i(0, 0, 1): [EAST, WEST]}, {}, Vector3i(0, 0, 0), EAST) == Vector2i.ZERO,
			"geen weg langs de as door de cel: onbeslist")
	test.check(RoadNetworkRules.has_road_along(two, {}, Vector3i(1, 0, 0), EAST), "er loopt weg langs x")
	test.check(not RoadNetworkRules.has_road_along(row_lanes([[EAST, WEST]]), {}, Vector3i(0, 0, 0), EAST), "een losse cel: geen weg erlangs")
	test.check(not RoadNetworkRules.has_road_along(two, {}, Vector3i(1, 0, 0), SOUTH), "de buurstrook loopt niet langs z")


func test_decide_two_way_lanes(test) -> void:
	# a street east with plain asphalt (all four ways) and a zebra (two-way) in it
	var open := [EAST, WEST, SOUTH, NORTH]
	var lanes := row_lanes([[EAST], open, [EAST, WEST], [EAST]])
	var open_axes := {Vector3i(1, 0, 0): [EAST, SOUTH], Vector3i(2, 0, 0): [EAST]}
	RoadNetworkRules.decide_two_way_lanes(lanes, open_axes, {})
	test.check(lanes[Vector3i(1, 0, 0)] == [EAST], "het asfalt gaat met de straat mee; dwars leidt nergens heen: geen strook (%s)" % str(lanes[Vector3i(1, 0, 0)]))
	test.check(lanes[Vector3i(2, 0, 0)] == [EAST], "de zebra ook")
	test.check(lanes[Vector3i(0, 0, 0)] == [EAST] and lanes[Vector3i(3, 0, 0)] == [EAST], "stroken met een richting blijven")


func test_decide_two_way_lanes_drives_on_the_right_and_drops_dead_ends(test) -> void:
	var lanes := {}
	var open_axes := {}
	for column in 4:
		for row in 2:
			lanes[Vector3i(column, 0, row)] = [EAST, WEST]
			open_axes[Vector3i(column, 0, row)] = [EAST]
	lanes[Vector3i(9, 0, 9)] = [EAST, WEST]   # a loose bit of asphalt
	open_axes[Vector3i(9, 0, 9)] = [EAST]
	RoadNetworkRules.decide_two_way_lanes(lanes, open_axes, {})
	for column in 4:
		test.check(lanes[Vector3i(column, 0, 0)] == [WEST] and lanes[Vector3i(column, 0, 1)] == [EAST], "twee open stroken: rechts rijden (kolom %d)" % column)
	test.check(not lanes.has(Vector3i(9, 0, 9)), "een los stuk dat nergens heen leidt is geen wegcel meer")


func test_decide_two_way_lanes_in_rounds(test) -> void:
	# three open lanes: the edges are decided first (driving on the right); the middle cannot
	# follow (they disagree) and, with no lane with a direction anywhere along it, is dropped
	var lanes := {}
	var open_axes := {}
	for column in 3:
		for row in 3:
			lanes[Vector3i(column, 0, row)] = [EAST, WEST]
			open_axes[Vector3i(column, 0, row)] = [EAST]
	RoadNetworkRules.decide_two_way_lanes(lanes, open_axes, {})
	test.check(lanes[Vector3i(1, 0, 0)] == [WEST] and lanes[Vector3i(1, 0, 2)] == [EAST], "de randen: rechts rijden")
	test.check(not lanes.has(Vector3i(1, 0, 1)), "de middelste, waar niets over beslist: geen wegcel meer")


# ------------------------------------------------------------------ kinds of road

func test_pass_on_along_lanes(test) -> void:
	var lanes := row_lanes([[EAST], [EAST], [EAST], [EAST], [EAST]])
	var kinds := {Vector3i(0, 0, 0): "straat", Vector3i(4, 0, 0): "snelweg"}
	RoadNetworkRules.pass_on_along_lanes(kinds, lanes, {})
	test.check(kinds[Vector3i(1, 0, 0)] == "straat", "van de dichtstbijzijnde cel langs de strook")
	test.check(kinds[Vector3i(3, 0, 0)] == "snelweg", "aan de andere kant de andere")
	test.check(kinds[Vector3i(2, 0, 0)] == "straat", "even ver: de cel achter de strook")
	test.check(kinds[Vector3i(0, 0, 0)] == "straat" and kinds[Vector3i(4, 0, 0)] == "snelweg", "wat er al stond blijft")
	var alone := {}
	RoadNetworkRules.pass_on_along_lanes(alone, lanes, {})
	test.check(alone.is_empty(), "nergens een waarde: niets ingevuld")
	var crosswise := {Vector3i(1, 0, 1): 30.0}
	var beside := row_lanes([[EAST], [EAST]])
	beside[Vector3i(1, 0, 1)] = [EAST]
	RoadNetworkRules.pass_on_along_lanes(crosswise, beside, {})
	test.check(not crosswise.has(Vector3i(1, 0, 0)), "niet van een cel naast de strook")
