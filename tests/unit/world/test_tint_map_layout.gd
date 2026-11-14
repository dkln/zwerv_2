extends RefCounted
## Unit tests of where the tint map lies and which cells an area covers
## (scripts/world/town/tint_map_layout.gd).

const TintMapLayout = preload("res://scripts/world/town/tint_map_layout.gd")


## The map is at least one cell each way and covers CELL metres per cell from its corner.
func test_the_map_and_its_area(test) -> void:
	test.check(TintMapLayout.map_size(Vector2i(96, 80)) == Vector2i(96, 80), "de maat zoals opgegeven")
	test.check(TintMapLayout.map_size(Vector2i(0, -3)) == Vector2i(1, 1), "nooit kleiner dan één cel")
	var area := TintMapLayout.map_area(Vector2(-8.0, 12.0), Vector2i(10, 5))
	test.check(area == Vector4(-8.0, 12.0, 40.0, 20.0), "hoek, breedte en diepte in meters (%s)" % area)


## An area of whole cells: half its size either way, and a flat box in the editor.
func test_the_size_of_an_area(test) -> void:
	test.check(TintMapLayout.half_extent(Vector2i(2, 3)) == Vector2(4.0, 6.0), "de helft van 2 x 3 cellen in meters")
	test.check(TintMapLayout.preview_size(Vector2i(2, 3)) == Vector3(8.0, 0.1, 12.0), "een platte doos zo groot als het gebied")


## An area covers exactly the cells whose middle lies in it.
func test_an_area_covers_the_cells_whose_middle_lies_in_it(test) -> void:
	# 2 x 1 cells centred on (8, 6): x 4..12, z 4..8: the cells (1, 1) and (2, 1)
	var covered := TintMapLayout.covered_cells(Vector2(8.0, 6.0), TintMapLayout.half_extent(Vector2i(2, 1)), Vector2.ZERO, Vector2i(10, 10))
	test.check(covered == ([Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i]), "de twee cellen eronder (%s)" % [covered])
	# shifted half a cell: only the cell whose middle is still in it
	var shifted := TintMapLayout.covered_cells(Vector2(9.0, 6.0), TintMapLayout.half_extent(Vector2i(1, 1)), Vector2.ZERO, Vector2i(10, 10))
	test.check(shifted == ([Vector2i(2, 1)] as Array[Vector2i]), "half verschoven: de cel met zijn midden erin (%s)" % [shifted])


## The corner of the map counts, and nothing outside the map is covered.
func test_the_corner_of_the_map_and_its_edge(test) -> void:
	var from_corner := TintMapLayout.covered_cells(Vector2(102.0, 202.0), Vector2(2.0, 2.0), Vector2(100.0, 200.0), Vector2i(4, 4))
	test.check(from_corner == ([Vector2i(0, 0)] as Array[Vector2i]), "geteld vanaf de hoek van de kaart (%s)" % [from_corner])
	var over_the_edge := TintMapLayout.covered_cells(Vector2(0.0, 0.0), Vector2(3.0, 3.0), Vector2.ZERO, Vector2i(4, 4))
	test.check(over_the_edge == ([Vector2i(0, 0)] as Array[Vector2i]), "over de rand: alleen wat op de kaart ligt (%s)" % [over_the_edge])
	var outside := TintMapLayout.covered_cells(Vector2(-100.0, -100.0), Vector2(2.0, 2.0), Vector2.ZERO, Vector2i(4, 4))
	test.check(outside.is_empty(), "buiten de kaart: niets")
