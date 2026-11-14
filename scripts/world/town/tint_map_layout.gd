extends RefCounted
## Where the tint map lies and which of its cells an area covers (layout;
## docs/CODE_LAGEN.md): the map has one pixel per CELL x CELL metres from its corner
## (`area_start`), an area (tint_area.gd) is a rectangle of whole cells centred on its node
## and covers every map cell whose middle lies in it. Used by tint_map.gd and tint_area.gd.
##   const TintMapLayout = preload("res://scripts/world/town/tint_map_layout.gd")

## Size of one map cell in metres (one texture pixel).
const CELL := 4.0


## The size of the map in pixels: at least one cell each way.
static func map_size(area_cells: Vector2i) -> Vector2i:
	return Vector2i(maxi(1, area_cells.x), maxi(1, area_cells.y))


## The area the map covers, as the shaders get it: x, z of its corner, width, depth (metres).
static func map_area(area_start: Vector2, map_cells: Vector2i) -> Vector4:
	return Vector4(area_start.x, area_start.y, map_cells.x * CELL, map_cells.y * CELL)


## Half the size in metres (x, z) of an area of `size_in_cells` cells.
static func half_extent(size_in_cells: Vector2i) -> Vector2:
	return Vector2(size_in_cells) * CELL * 0.5


## The size in metres of the box that shows an area of `size_in_cells` in the editor.
static func preview_size(size_in_cells: Vector2i) -> Vector3:
	return Vector3(size_in_cells.x * CELL, 0.1, size_in_cells.y * CELL)


## The map cells (pixels) under an area centred on `centre` (x, z in metres) reaching `half`
## metres either way: those whose middle lies in it, within a map of `map_cells` from `area_start`.
static func covered_cells(centre: Vector2, half: Vector2, area_start: Vector2, map_cells: Vector2i) -> Array[Vector2i]:
	var covered: Array[Vector2i] = []
	# only visit the cells near the area; the exact test below decides
	var first_x := maxi(0, floori((centre.x - half.x - area_start.x) / CELL) - 1)
	var end_x := mini(map_cells.x, ceili((centre.x + half.x - area_start.x) / CELL) + 1)
	var first_z := maxi(0, floori((centre.y - half.y - area_start.y) / CELL) - 1)
	var end_z := mini(map_cells.y, ceili((centre.y + half.y - area_start.y) / CELL) + 1)
	for cell_x in range(first_x, end_x):
		for cell_z in range(first_z, end_z):
			# cell centre inside the area?
			var middle_x := area_start.x + (cell_x + 0.5) * CELL
			var middle_z := area_start.y + (cell_z + 0.5) * CELL
			if absf(middle_x - centre.x) <= half.x and absf(middle_z - centre.y) <= half.y:
				covered.append(Vector2i(cell_x, cell_z))
	return covered
