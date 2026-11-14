extends RefCounted
## Unit tests of the floor grid (scripts/pathfinding/floor_grid.gd) and the way round
## rectangles (detour.gd).
##   tests/run_unit_tests.sh pathfinding

const FloorGrid = preload("res://scripts/pathfinding/floor_grid.gd")
const Detour = preload("res://scripts/pathfinding/detour.gd")


func test_block_and_free_cell(test) -> void:
	var grid := FloorGrid.make(6, 4)
	test.check(FloorGrid.is_free(grid, Vector2i(2, 2)), "nieuw rooster: vrij")
	FloorGrid.block(grid, Vector2i(1, 1), Vector2i(3, 2))
	test.check(not FloorGrid.is_free(grid, Vector2i(3, 2)), "geblokkeerd tot en met de hoek")
	test.check(FloorGrid.is_free(grid, Vector2i(4, 2)), "ernaast vrij")
	test.check(not FloorGrid.is_free(grid, Vector2i(-1, 0)), "buiten het rooster: niet vrij")
	FloorGrid.block(grid, Vector2i(5, 3), Vector2i(9, 9))   # partly outside: no error
	var free := FloorGrid.free_cell(grid, Vector2i(2, 1))
	test.check(FloorGrid.is_free(grid, free) and free.distance_to(Vector2i(2, 1)) <= 1.5, "vrije cel naast de geblokkeerde")
	test.check(FloorGrid.free_cell(grid, Vector2i(2, 1), 0) == Vector2i(2, 1), "bereik 0: de cel zelf")


func test_cell_path_goes_round(test) -> void:
	var grid := FloorGrid.make(5, 5)
	FloorGrid.block(grid, Vector2i(2, 0), Vector2i(2, 3))
	var cells := FloorGrid.cell_path(grid, Vector2i(0, 0), Vector2i(4, 0))
	test.check(not cells.is_empty() and cells[0] == Vector2i(0, 0) and cells[-1] == Vector2i(4, 0), "van begin tot doel")
	test.check(cells.has(Vector2i(2, 4)), "om de wand heen langs de onderste rij")
	for cell in cells:
		test.check(FloorGrid.is_free(grid, cell), "alleen vrije cellen")
	test.check(FloorGrid.reachable(grid, Vector2i(0, 0), Vector2i(4, 0)), "bereikbaar")


func test_cell_path_from_a_blocked_cell_starts_beside_it(test) -> void:
	var grid := FloorGrid.make(5, 3)
	FloorGrid.block(grid, Vector2i(0, 0), Vector2i(0, 0))
	var cells := FloorGrid.cell_path(grid, Vector2i(0, 0), Vector2i(4, 0))
	test.check(not cells.is_empty() and cells[0] != Vector2i(0, 0), "begint in een vrije buurcel")


func test_shut_off_is_not_reachable(test) -> void:
	var grid := FloorGrid.make(5, 5)
	FloorGrid.block(grid, Vector2i(2, 0), Vector2i(2, 4))
	test.check(FloorGrid.cell_path(grid, Vector2i(0, 0), Vector2i(4, 4)).is_empty(), "afgesloten: geen pad")
	test.check(not FloorGrid.reachable(grid, Vector2i(0, 0), Vector2i(4, 4)), "afgesloten: niet bereikbaar")
	test.check(FloorGrid.reachable(grid, Vector2i(1, 1), Vector2i(1, 1)), "zelfde cel: bereikbaar")


func test_diagonal_does_not_cut_corners(test) -> void:
	var grid := FloorGrid.make(2, 2)
	FloorGrid.block(grid, Vector2i(1, 0), Vector2i(1, 0))
	var cells := FloorGrid.cell_path(grid, Vector2i(0, 0), Vector2i(1, 1))
	test.check(cells.size() == 3, "niet schuin langs de hoek (%d)" % cells.size())


func test_detour_round_a_box(test) -> void:
	var box := Rect2(-1.0, -1.0, 2.0, 2.0)
	var from := Vector2(-5.0, 0.0)
	var to := Vector2(5.0, 0.0)
	test.check(Detour.hits(from, to, box), "de rechte lijn raakt de doos")
	var points := Detour.around(from, to, [box], 0.5, 3)
	test.check(points.size() >= 2 and points[-1] == to, "via hoeken naar het doel")
	var here := from
	for point in points:
		test.check(not Detour.hits(here, point, box.grow(0.5)), "geen stuk door de doos (met marge)")
		here = point


func test_detour_straight_when_clear(test) -> void:
	var box := Rect2(-1.0, 3.0, 2.0, 2.0)
	var points := Detour.around(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), [box], 0.5, 3)
	test.check(points == ([Vector2(5.0, 0.0)] as Array[Vector2]), "niets in de weg: rechtdoor")
	test.check(Detour.first_obstacle(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), [box], 0.5) == Rect2(), "geen obstakel")
	test.check(Detour.around(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), [Rect2(-1, -1, 2, 2)], 0.5, 0) == ([Vector2(5.0, 0.0)] as Array[Vector2]),
			"diepte 0: rechtdoor")


func test_detour_picks_the_nearest_obstacle(test) -> void:
	var near := Rect2(-3.0, -1.0, 1.0, 2.0)
	var far := Rect2(2.0, -1.0, 1.0, 2.0)
	test.check(Detour.first_obstacle(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), [far, near], 0.2) == near, "de dichtstbijzijnde eerst")
	test.check(Detour.inside_any(Vector2(-2.9, 1.1), [near], 0.2), "binnen de marge telt als binnen")
	test.check(not Detour.inside_any(Vector2(0.0, 0.0), [near, far], 0.2), "ertussen: vrij")
