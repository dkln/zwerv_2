extends RefCounted
## The floor of a branch of a supermarket as a grid (logic, docs/CODE_LAGEN.md): the cells
## of NAV_CELL m over the plan (SupermarketLayout.plan), what its tiles and props take up,
## the free floor the shoppers and whoever puts the player out walk on, and the way over
## it. `a_plan`: the plan, in the shop's space (x from -width/2, z from -depth/2). The node:
## supermarket.gd.
##   const SupermarketFloorRules = preload("res://scripts/world/interiors/supermarket_floor_rules.gd")

const FloorGrid = preload("res://scripts/pathfinding/floor_grid.gd")

const NAV_CELL := 0.5
## How far round a blocked cell a free one is looked for (FloorGrid.free_cell), in cells.
const FREE_CELL_REACH := 5
## The folder of the supermarket's tiles in the library binnen.
const PREFIX := "supermarkt/"
## What hangs with its bottom above this (m) is not in the way (signs), and how far round
## a thing the floor is kept free (m).
const OVERHEAD := 1.6
const MARGIN := 0.15


static func cell_of(a_plan: Dictionary, at: Vector3) -> Vector2i:
	return Vector2i(floori((at.x + float(a_plan.width) * 0.5) / NAV_CELL), floori((at.z + float(a_plan.depth) * 0.5) / NAV_CELL))


static func cell_middle(a_plan: Dictionary, cell: Vector2i) -> Vector3:
	return Vector3(-float(a_plan.width) * 0.5 + (cell.x + 0.5) * NAV_CELL, 0.0, -float(a_plan.depth) * 0.5 + (cell.y + 0.5) * NAV_CELL)


## The nearest free cell of `grid` to `cell` (itself when free).
static func free_cell(grid: AStarGrid2D, cell: Vector2i) -> Vector2i:
	return FloorGrid.free_cell(grid, cell, FREE_CELL_REACH)


## The free floor of `a_plan` as a grid of NAV_CELL m (AStarGrid2D): every tile and prop below
## head height blocks the cells under it (and a little round it).
static func make_floor_grid(a_plan: Dictionary, library: MeshLibrary, props_library: MeshLibrary) -> AStarGrid2D:
	var grid := FloorGrid.make(int(float(a_plan.width) / NAV_CELL), int(float(a_plan.depth) / NAV_CELL))
	for box in footprints(a_plan, library, props_library):
		FloorGrid.block(grid, cell_of(a_plan, box.position - Vector3(MARGIN, 0.0, MARGIN)), cell_of(a_plan, box.end + Vector3(MARGIN, 0.0, MARGIN)))
	return grid


## The boxes the tiles and props of `a_plan` take up (in the shop's space), all but the ones
## high on a wall (signs).
static func footprints(a_plan: Dictionary, library: MeshLibrary, props_library: MeshLibrary) -> Array[AABB]:
	var boxes: Array[AABB] = []
	var placed: Array = []
	for entry: Array in a_plan.tiles:
		placed.append([library, PREFIX + String(entry[0]), entry[1], float(entry[2])])
	for entry: Array in a_plan.props:
		placed.append([props_library, String(entry[0]), entry[1], float(entry[2])])
	for entry: Array in placed:
		var source: MeshLibrary = entry[0]
		var item := source.find_item_by_name(String(entry[1]))
		if item < 0 or source.get_item_mesh(item) == null:
			continue
		var box: AABB = Transform3D(Basis(Vector3.UP, float(entry[3])), entry[2]) * source.get_item_mesh_transform(item) * source.get_item_mesh(item).get_aabb()
		if box.position.y > OVERHEAD:
			continue
		boxes.append(box)
	boxes.append_array(deposit_footprint(a_plan))
	return boxes


## The box of the deposit machine of `a_plan` (its "deposit"), or none.
static func deposit_footprint(a_plan: Dictionary) -> Array[AABB]:
	var found: Array[AABB] = []
	var deposit: Dictionary = a_plan.get("deposit", {})
	if not deposit.is_empty():
		var size: Vector3 = deposit.size
		var turned := Basis(Vector3.UP, float(deposit.turn)) * size
		var extent := Vector3(absf(turned.x), size.y, absf(turned.z))
		found.append(AABB((deposit.at as Vector3) - Vector3(extent.x, 0.0, extent.z) * 0.5, extent))
	return found


## The way from `from` to `to` over the free floor of `grid` (in the shop's space), ending
## at `to`; straight there without a grid.
static func path(grid: AStarGrid2D, a_plan: Dictionary, from: Vector3, to: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	if grid == null:
		points.append(to)
		return points
	for cell in FloorGrid.cell_path(grid, cell_of(a_plan, from), cell_of(a_plan, to), FREE_CELL_REACH):
		points.append(cell_middle(a_plan, cell))
	if points.size() > 1:
		points.remove_at(0)
	points.append(to)
	return points


## True if one can walk from `from` to `to` over the free floor of `grid` (the checks).
static func reachable_on(grid: AStarGrid2D, a_plan: Dictionary, from: Vector3, to: Vector3) -> bool:
	return FloorGrid.reachable(grid, cell_of(a_plan, from), cell_of(a_plan, to), FREE_CELL_REACH)


## Where a player warned at the gates is put back: `metres` into the shop from the door
## (`door`: in the shop's space, facing in), on free floor when there is a grid.
static func way_back_in(grid: AStarGrid2D, a_plan: Dictionary, door: Transform3D, metres: float) -> Vector3:
	var spot := door.origin + door.basis.z * metres
	if grid == null:
		return spot
	return cell_middle(a_plan, free_cell(grid, cell_of(a_plan, spot)))
