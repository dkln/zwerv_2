extends RefCounted
## Unit tests of the route finder over cells (scripts/pathfinding/cell_routes.gd), on small
## hand-made graphs (grid_links, also used by test_step_field.gd).
##   tests/run_unit_tests.sh cell_routes

const CellRoutes = preload("res://scripts/pathfinding/cell_routes.gd")

const SIDES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## The links of a grid of cells (y 0) drawn as text: "." a cell, "#" none; rows along z.
static func grid_links(rows: Array[String]) -> Dictionary:
	var cells := {}
	for row_index in rows.size():
		for column_index in rows[row_index].length():
			if rows[row_index][column_index] == ".":
				cells[Vector3i(column_index, 0, row_index)] = true
	var links := {}
	for cell: Vector3i in cells:
		var ways: Array[Vector3i] = []
		for side in SIDES:
			if cells.has(cell + side):
				ways.append(cell + side)
		links[cell] = ways
	return links


func test_route_goes_round_a_wall(test) -> void:
	var routes := CellRoutes.new(grid_links([
		".....",
		".###.",
		".....",
	]))
	var way := routes.route(Vector3i(0, 0, 1), Vector3i(4, 0, 1))
	test.check(way.size() == 6, "om de muur heen: 6 stappen (%d)" % way.size())
	test.check(not way.has(Vector3i(0, 0, 1)), "het begin zit er niet in")
	test.check(way[-1] == Vector3i(4, 0, 1), "eindigt op het doel")
	for index in range(1, way.size()):
		var step: Vector3i = way[index] - way[index - 1]
		test.check(absi(step.x) + absi(step.z) == 1, "elke stap naar een buurcel")


func test_route_without_a_way_is_empty(test) -> void:
	var routes := CellRoutes.new(grid_links([
		"..#..",
	]))
	test.check(routes.route(Vector3i(0, 0, 0), Vector3i(4, 0, 0)).is_empty(), "geen weg: leeg")
	test.check(routes.route(Vector3i(9, 0, 9), Vector3i(0, 0, 0)).is_empty(), "begin buiten de graaf: leeg")
	test.check(routes.route(Vector3i(0, 0, 0), Vector3i(0, 0, 0)).is_empty(), "al op het doel: leeg")


func test_route_to_a_cell_outside_goes_to_the_nearest(test) -> void:
	var routes := CellRoutes.new(grid_links([
		"....",
	]))
	var way := routes.route(Vector3i(0, 0, 0), Vector3i(3, 0, 5))
	test.check(not way.is_empty() and way[-1] == Vector3i(3, 0, 0), "naar de dichtstbijzijnde cel van het doel")


func test_route_keeps_out_of_avoided_cells(test) -> void:
	var routes := CellRoutes.new(grid_links([
		"...",
		"...",
	]))
	var middle := Vector3i(1, 0, 0)
	var way := routes.route(Vector3i(0, 0, 0), Vector3i(2, 0, 0), [middle])
	test.check(not way.has(middle), "de vermeden cel zit er niet in")
	test.check(way.size() == 4, "omweg via de tweede rij (%d)" % way.size())
	# only for that one route: the next one may go through it again
	test.check(routes.route(Vector3i(0, 0, 0), Vector3i(2, 0, 0)).has(middle), "daarna weer gewoon")


func test_links_go_one_way(test) -> void:
	var a := Vector3i(0, 0, 0)
	var b := Vector3i(1, 0, 0)
	var routes := CellRoutes.new({a: [b], b: []})
	test.check(routes.route(a, b) == ([b] as Array[Vector3i]), "van a naar b kan")
	test.check(routes.route(b, a).is_empty(), "terug niet: geen link van b naar a")
	test.check(routes.size() == 2 and routes.has_cell(a) and not routes.has_cell(Vector3i(5, 0, 5)), "cellen van de graaf")


func test_nearest(test) -> void:
	var links := grid_links([
		"#.",
		"..",
	])
	var routes := CellRoutes.new(links)
	test.check(routes.nearest(Vector3i(1, 0, 0), links.keys()) == Vector3i(1, 0, 0), "een cel van de graaf: zichzelf")
	test.check(routes.nearest(Vector3i(5, 0, 1), links.keys()) == Vector3i(1, 0, 1), "buiten: de dichtstbijzijnde")
	test.check(CellRoutes.new().nearest(Vector3i(3, 0, 3), []) == Vector3i(3, 0, 3), "lege graaf: de cel zelf")


func test_route_somewhere_stays_within_reach(test) -> void:
	var links := grid_links([
		"............",
		"............",
	])
	var routes := CellRoutes.new(links)
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var from := Vector3i(0, 0, 0)
	for attempt in 20:
		var way := routes.route_somewhere(from, links.keys(), random, Vector2i(5, 8), 20, 40)
		test.check(not way.is_empty(), "een plek gevonden")
		if way.is_empty():
			continue
		var far := maxi(absi(way[-1].x - from.x), absi(way[-1].z - from.z))
		test.check(far >= 5 and far <= 8, "tussen 5 en 8 cellen ver (%d)" % far)
		test.check(not way.has(from), "zonder het begin")


func test_route_somewhere_respects_accept_and_longest(test) -> void:
	var links := grid_links([
		"..........",
	])
	var routes := CellRoutes.new(links)
	var random := RandomNumberGenerator.new()
	random.seed = 3
	var from := Vector3i(0, 0, 0)
	var too_short := routes.route_somewhere(from, links.keys(), random, Vector2i(6, 9), 4, 40)
	test.check(too_short.is_empty(), "elke weg langer dan het maximum: niets")
	var no_column_three := func(cell: Vector3i) -> bool: return cell.x != 3
	test.check(routes.route_somewhere(from, links.keys(), random, Vector2i(6, 9), 20, 40, no_column_three).is_empty(),
			"elke weg door een geweigerde cel: niets")
	test.check(routes.route_somewhere(Vector3i(50, 0, 0), links.keys(), random, Vector2i(1, 9), 20, 40).is_empty(),
			"begin buiten de graaf: niets")


func test_route_somewhere_is_the_same_for_the_same_seed(test) -> void:
	var links := grid_links([
		"..........",
		"..........",
		"..........",
	])
	var routes := CellRoutes.new(links)
	var first := RandomNumberGenerator.new()
	first.seed = 11
	var second := RandomNumberGenerator.new()
	second.seed = 11
	for attempt in 5:
		test.check(routes.route_somewhere(Vector3i(0, 0, 0), links.keys(), first, Vector2i(3, 9), 30, 40)
				== routes.route_somewhere(Vector3i(0, 0, 0), links.keys(), second, Vector2i(3, 9), 30, 40), "zelfde zaad, zelfde weg")
