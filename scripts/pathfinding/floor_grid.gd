extends RefCounted
## The free floor of a room as a grid (AStarGrid2D, cells of one size, diagonal only where no
## corner is cut): cells under furniture blocked, the way between two spots over the free
## cells. Used by the interiors (Interior.floor_path) and the supermarkets (Supermarket._path);
## knows nothing of rooms or tiles, so it is tested on small hand-made grids.
##   const FloorGrid = preload("res://scripts/pathfinding/floor_grid.gd")

## How far round a blocked cell a free one is looked for (free_cell), in cells.
const FREE_CELL_REACH := 7


## An empty grid of `columns` × `rows` cells (all free).
static func make(columns: int, rows: int) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, columns, rows)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	return grid


## Blocks the cells from `low` to `high` (both included) that lie in the grid.
static func block(grid: AStarGrid2D, low: Vector2i, high: Vector2i) -> void:
	for column in range(low.x, high.x + 1):
		for row in range(low.y, high.y + 1):
			if grid.is_in_boundsv(Vector2i(column, row)):
				grid.set_point_solid(Vector2i(column, row), true)


## True if `cell` lies in the grid and is free.
static func is_free(grid: AStarGrid2D, cell: Vector2i) -> bool:
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


## The nearest free cell to `cell` (itself when free), looked for in squares round it up to
## `reach` cells out; `cell` when there is none.
static func free_cell(grid: AStarGrid2D, cell: Vector2i, reach := FREE_CELL_REACH) -> Vector2i:
	if is_free(grid, cell):
		return cell
	for ring in range(1, reach + 1):
		for column in range(cell.x - ring, cell.x + ring + 1):
			for row in range(cell.y - ring, cell.y + ring + 1):
				var other := Vector2i(column, row)
				if is_free(grid, other):
					return other
	return cell


## The cells from `from` to `to` over the free floor, each moved to the nearest free cell
## first (free_cell), both included; empty when there is no way.
static func cell_path(grid: AStarGrid2D, from: Vector2i, to: Vector2i, reach := FREE_CELL_REACH) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var start := free_cell(grid, from, reach)
	var goal := free_cell(grid, to, reach)
	if not is_free(grid, start) or not is_free(grid, goal):
		return cells
	cells.assign(grid.get_id_path(start, goal))
	return cells


## True if one can walk from `from` to `to` over the free floor (each moved to the nearest
## free cell first).
static func reachable(grid: AStarGrid2D, from: Vector2i, to: Vector2i, reach := FREE_CELL_REACH) -> bool:
	return free_cell(grid, from, reach) == free_cell(grid, to, reach) or not cell_path(grid, from, to, reach).is_empty()
