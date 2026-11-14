extends RefCounted
## Unit tests of the floor grid (scripts/pathfinding/floor_grid.gd): the free floor of a room
## as a grid, on small hand-made grids.
##   tests/run_unit_tests.sh floor_grid

const FloorGrid = preload("res://scripts/pathfinding/floor_grid.gd")


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


func test_free_cell_looks_no_further_than_its_reach(test) -> void:
	var grid := FloorGrid.make(9, 1)
	FloorGrid.block(grid, Vector2i(0, 0), Vector2i(5, 0))
	test.check(FloorGrid.free_cell(grid, Vector2i(0, 0), 3) == Vector2i(0, 0), "geen vrije cel binnen bereik: de cel zelf")
	test.check(FloorGrid.free_cell(grid, Vector2i(0, 0), 6) == Vector2i(6, 0), "binnen bereik: de eerste vrije")
	test.check(FloorGrid.cell_path(grid, Vector2i(0, 0), Vector2i(8, 0), 3).is_empty(), "begin zonder vrije cel: geen pad")
	test.check(not FloorGrid.reachable(grid, Vector2i(0, 0), Vector2i(8, 0), 3), "en niet bereikbaar")
	test.check(FloorGrid.FREE_CELL_REACH >= 6 and FloorGrid.reachable(grid, Vector2i(0, 0), Vector2i(8, 0)), "met het gewone bereik wel")
