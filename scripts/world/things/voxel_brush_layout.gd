extends RefCounted
## Which voxels a shape takes (layout; docs/CODE_LAGEN.md): the cells of a box, of a disc
## (a slice of a cylinder) and of an ellipsoid, and the stable number per cell that scatters
## speckles and crumbs. Pure arithmetic on whole cells; voxel_brush_view.gd paints them into
## a figure (the models of the items and the machines).
##   const VoxelBrushLayout = preload("res://scripts/world/things/voxel_brush_layout.gd")
##   for cell: Vector2i in VoxelBrushLayout.disc_cells(Vector2(3.5, 3.5), 3.5): ...


## Every cell from `from` to `to` (the corners included): by x, then y, then z.
static func box_cells(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for column in range(from.x, to.x + 1):
		for level in range(from.y, to.y + 1):
			for depth in range(from.z, to.z + 1):
				cells.append(Vector3i(column, level, depth))
	return cells


## The cells of a disc: those whose middle lies within `radius` of `centre` (in the two
## directions of the disc), by the first direction, then the second.
static func disc_cells(centre: Vector2, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for first in range(floori(centre.x - radius) - 1, ceili(centre.x + radius) + 1):
		for second in range(floori(centre.y - radius) - 1, ceili(centre.y + radius) + 1):
			if Vector2(first + 0.5, second + 0.5).distance_to(centre) <= radius:
				cells.append(Vector2i(first, second))
	return cells


## The cells of an ellipsoid: those whose middle lies within it, none below `lowest_level`.
static func ellipsoid_cells(centre: Vector3, radii: Vector3, lowest_level := -1000) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for column in range(floori(centre.x - radii.x) - 1, ceili(centre.x + radii.x) + 1):
		for level in range(maxi(floori(centre.y - radii.y) - 1, lowest_level), ceili(centre.y + radii.y) + 1):
			for depth in range(floori(centre.z - radii.z) - 1, ceili(centre.z + radii.z) + 1):
				var offset := (Vector3(column, level, depth) + Vector3(0.5, 0.5, 0.5) - centre) / radii
				if offset.length_squared() <= 1.0:
					cells.append(Vector3i(column, level, depth))
	return cells


## A stable number 0..99 for a cell: where the speckles, crumbs and currants go.
static func speckle(cell: Vector3i) -> int:
	var mixed := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791)
	return absi(mixed) % 100
