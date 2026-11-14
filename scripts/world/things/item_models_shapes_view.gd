extends RefCounted
## The shapes several item models share (graphics; docs/CODE_LAGEN.md): a plastic bottle, a
## can, a beer bottle, a bag of sweets and the round corners of a card, painted into a
## figure with the voxel brush (voxel_brush_view.gd). Used by item_models_food_view.gd and
## item_models_goods_view.gd.
##   const ItemShapes = preload("res://scripts/world/things/item_models_shapes_view.gd")
##   ItemShapes.can(figure, 3.0, 9, Color("#C8242C"))

const PlayerModel = preload("res://scripts/player/player_model.gd")
const VoxelBrush = preload("res://scripts/world/things/voxel_brush_view.gd")
const VoxelBrushLayout = preload("res://scripts/world/things/voxel_brush_layout.gd")
const ItemLook = preload("res://scripts/world/things/item_models_look.gd")


## A plastic bottle: body, shoulder, neck and cap; water up to `water_level`.
static func bottle(figure: PlayerModel.VoxelFigure, radius: float, body_top: int, water_level: int,
		water: Color, air: Color, cap: Color) -> void:
	var centre := Vector2(4.0, 4.0)
	for level in range(0, body_top + 1):
		VoxelBrush.cylinder_y(figure, centre, radius, level, level, water if level <= water_level else air, "glass")
	VoxelBrush.cylinder_y(figure, centre, radius * 0.8, body_top + 1, body_top + 1, air, "glass")
	VoxelBrush.cylinder_y(figure, centre, radius * 0.57, body_top + 2, body_top + 2, air, "glass")
	VoxelBrush.cylinder_y(figure, centre, 1.2, body_top + 3, body_top + 4, air, "glass")
	VoxelBrush.cylinder_y(figure, centre, 1.6, body_top + 5, body_top + 6, cap, "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 2 and figure.cells[cell] == water, [water.lightened(0.2)], "glass")


## A can: steel ends, a body in `colour`, a ring on top (`with_ring`).
static func can(figure: PlayerModel.VoxelFigure, radius: float, body_top: int, colour: Color,
		with_ring := true) -> void:
	var centre := Vector2(3.0, 3.0) if radius < 3.0 else Vector2(3.5, 3.5)
	VoxelBrush.cylinder_y(figure, centre, radius - 0.4, 0, 0, ItemLook.STEEL, "metal")
	VoxelBrush.cylinder_y(figure, centre, radius, 1, body_top, colour, "metal")
	VoxelBrush.cylinder_y(figure, centre, radius - 0.4, body_top + 1, body_top + 1, ItemLook.STEEL, "metal")
	if with_ring:
		var ring_column := floori(centre.x)
		var ring_depth := floori(centre.y) - 1
		VoxelBrush.box(figure, Vector3i(ring_column - 1, body_top + 2, ring_depth), Vector3i(ring_column, body_top + 2, ring_depth),
				ItemLook.STEEL_DARK, "metal")


## An empty beer bottle with its label, its corner at (column, depth).
static func beer_bottle(figure: PlayerModel.VoxelFigure, column: int, depth: int, glass: Color,
		label: Color) -> void:
	var centre := Vector2(column + 2.0, depth + 2.0)
	VoxelBrush.cylinder_y(figure, centre, 2.0, 0, 8, glass, "glass")
	VoxelBrush.cylinder_y(figure, centre, 1.5, 9, 9, glass, "glass")
	VoxelBrush.cylinder_y(figure, centre, 1.0, 10, 13, glass, "glass")
	VoxelBrush.cylinder_y(figure, centre, 1.3, 14, 14, glass.lightened(0.15), "glass")
	for label_column in range(column, column + 4):
		for level in range(3, 7):
			if not (level == 3 and (label_column == column or label_column == column + 3)):
				VoxelBrush.paint_front(figure, label_column, level, label, "skin")


## A sealed bag of sweets: crimped seams at top and bottom, a band of `accent`, a window on
## its front showing the contents (`contents`: their colours, `fill`: how much of the window
## they cover in percent).
static func candy_bag(figure: PlayerModel.VoxelFigure, size: Vector3i, bag: Color, accent: Color,
		window: Color, contents: Array, fill: int) -> void:
	var width := size.x
	var height := size.y
	var depth := size.z
	VoxelBrush.box(figure, Vector3i(0, 2, 0), Vector3i(width - 1, height - 3, depth - 1), bag, "plastic")
	for level in range(2, height - 2):
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(width - 1, 0), Vector2i(0, depth - 1), Vector2i(width - 1, depth - 1)]:
			figure.clear(corner.x, level, corner.y)
	var middle := floori(depth / 2.0)
	for seam_level in [0, 1, height - 2, height - 1]:
		for column in width:
			var seam_colour := accent if (column + seam_level) % 2 == 0 else bag
			VoxelBrush.box(figure, Vector3i(column, seam_level, middle - 1), Vector3i(column, seam_level, middle), seam_colour, "plastic")
	VoxelBrush.box(figure, Vector3i(1, height - 5, 0), Vector3i(width - 2, height - 4, 0), accent, "plastic")
	for column in range(2, width - 2):
		for level in range(4, height - 6):
			var block := Vector3i(floori(column / 2.0), floori(level / 2.0), 7)
			var speckle := VoxelBrushLayout.speckle(block)
			var colour: Color = contents[speckle % contents.size()] if speckle < fill else window
			VoxelBrush.box(figure, Vector3i(column, level, 0), Vector3i(column, level, 0), colour, "plastic")


## Clears the four corners of a card (`last_column`, `last_level`: its far edges).
static func round_card_corners(figure: PlayerModel.VoxelFigure, last_column: int, last_level: int) -> void:
	for depth in range(0, 2):
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(last_column, 0), Vector2i(0, last_level),
				Vector2i(last_column, last_level)]:
			figure.clear(corner.x, corner.y, depth)
