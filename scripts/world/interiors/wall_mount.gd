extends RefCounted
## Tiles that hang on a wall of an interior: the name and the emblem of a supermarket chain,
## the paintings and the coat of arms of the city hall. The interiors lay their tiles on a
## 0.5 m grid, and the walls (two voxels, 0.25 m deep) stand centred on their grid line, so
## their inner surface is 0.125 m off the grid: a tile put on the grid near it ends up half
## in the wall, and where its face lies in the plane of the wall the two flicker
## (z-fighting). Here the tile goes into a GridMap of its own, moved off the grid so that
## the back of the tile (its mesh, whatever the depth of its canvas) stands GAP in front of
## the wall's inner surface.
##   const WallMount = preload("res://scripts/world/interiors/wall_mount.gd")
##   WallMount.put(layout_node, library, "supermarkt/logo_derrek", Vector3(x, 2.0, back), PI)

## Half the depth of a wall tile: its inner surface is this far from its grid line.
const WALL_HALF_DEPTH := 0.125
## Room between the wall's inner surface and the back of what hangs on it.
const GAP := 0.02
## The GridMaps of the wall tiles: this name, the direction and the offset in mm after it.
const GRID_PREFIX := "Wand"


## Puts `item_name` (of `library`) on the wall whose grid line runs through `wall_at` (where
## the wall tile itself lies; the height is where the tile's bottom goes), its front (+z of
## the tile) turned `turn` radians, into the room. Into a GridMap child of `parent` (made
## when needed, cell size 0.5 m like the others). False when the library has no such tile.
static func put(parent: Node3D, library: MeshLibrary, item_name: String, wall_at: Vector3, turn: float) -> bool:
	var item := library.find_item_by_name(item_name)
	if item < 0:
		return false
	var distance := offset(library, item)
	var grid_name := "%s_%d_%d" % [GRID_PREFIX, posmod(roundi(rad_to_deg(turn)), 360), roundi(distance * 1000.0)]
	var grid := parent.get_node_or_null(grid_name) as GridMap
	if grid == null:
		grid = GridMap.new()
		grid.name = grid_name
		grid.mesh_library = library
		grid.cell_size = Vector3(0.5, 0.5, 0.5)
		grid.cell_center_x = false
		grid.cell_center_y = false
		grid.cell_center_z = false
		grid.position = Basis(Vector3.UP, turn) * Vector3(0.0, 0.0, distance)
		parent.add_child(grid)
	var cell := Vector3i(roundi(wall_at.x * 2.0), roundi(wall_at.y * 2.0), roundi(wall_at.z * 2.0))
	grid.set_cell_item(cell, item, grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn)))
	return true


## How far item `item` of `library` goes from the wall's grid line into the room (along its
## front) so that its back stands GAP before the wall's inner surface.
static func offset(library: MeshLibrary, item: int) -> float:
	var mesh := library.get_item_mesh(item)
	if mesh == null:
		return WALL_HALF_DEPTH + GAP
	var box: AABB = library.get_item_mesh_transform(item) * mesh.get_aabb()
	return WALL_HALF_DEPTH + GAP - box.position.z
