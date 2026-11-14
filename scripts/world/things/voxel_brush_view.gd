extends RefCounted
## Painting voxels into a figure and making its mesh (graphics; docs/CODE_LAGEN.md): the
## brush the models of the items (item_models.gd and its *_view.gd parts) and of the machines
## (machine_models.gd) are made with. A figure is a PlayerModel.VoxelFigure; every stroke
## gives its cells a colour and says what that colour is made of (`kind`: "plastic",
## "metal", "skin", "glass", "cloth"; "glow" lights up and is plastic). Which cells a shape
## takes: voxel_brush_layout.gd.
##   const VoxelBrush = preload("res://scripts/world/things/voxel_brush_view.gd")
##   VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(9, 11, 6), colour, "skin")
##   var mesh := VoxelBrush.mesh_of(figure, 0.025)

const PlayerModel = preload("res://scripts/player/player_model.gd")
const VoxelBrushLayout = preload("res://scripts/world/things/voxel_brush_layout.gd")
## How far before and behind a figure paint_front, paint_back and paint_top look (voxels).
const NEAREST := -8
const FARTHEST := 40


## A box from `from` to `to` in `colour`.
static func box(figure: PlayerModel.VoxelFigure, from: Vector3i, to: Vector3i, colour: Color, kind: String,
		glow := false) -> void:
	figure.box(from, to, colour, glow)
	mark(figure, kind, colour)


## Says what `colour` is made of in this figure.
static func mark(figure: PlayerModel.VoxelFigure, kind: String, colour: Color) -> void:
	figure.mark(kind if kind != "glow" else "plastic", [colour])


## Empties the voxels from `from` to `to` (a bite, a screen or slot sunk into a body).
static func clear_box(figure: PlayerModel.VoxelFigure, from: Vector3i, to: Vector3i) -> void:
	for cell: Vector3i in VoxelBrushLayout.box_cells(from, to):
		figure.clear(cell.x, cell.y, cell.z)


## An upright cylinder: the cells whose middle lies within `radius` of `centre` (x, z).
static func cylinder_y(figure: PlayerModel.VoxelFigure, centre: Vector2, radius: float, from_level: int,
		to_level: int, colour: Color, kind: String) -> void:
	for cell: Vector2i in VoxelBrushLayout.disc_cells(centre, radius):
		figure.box(Vector3i(cell.x, from_level, cell.y), Vector3i(cell.x, to_level, cell.y), colour)
	mark(figure, kind, colour)


## Empties an upright cylinder.
static func clear_cylinder_y(figure: PlayerModel.VoxelFigure, centre: Vector2, radius: float, from_level: int,
		to_level: int) -> void:
	for cell: Vector2i in VoxelBrushLayout.disc_cells(centre, radius):
		for level in range(from_level, to_level + 1):
			figure.clear(cell.x, level, cell.y)


## A lying cylinder along x: `centre` is (y, z).
static func cylinder_x(figure: PlayerModel.VoxelFigure, centre: Vector2, radius: float, from_column: int,
		to_column: int, colour: Color, kind: String) -> void:
	for cell: Vector2i in VoxelBrushLayout.disc_cells(centre, radius):
		figure.box(Vector3i(from_column, cell.x, cell.y), Vector3i(to_column, cell.x, cell.y), colour)
	mark(figure, kind, colour)


## A disc facing the front (along z): `centre` is (x, y).
static func cylinder_z(figure: PlayerModel.VoxelFigure, centre: Vector2, radius: float, from_depth: int,
		to_depth: int, colour: Color, kind: String) -> void:
	for cell: Vector2i in VoxelBrushLayout.disc_cells(centre, radius):
		figure.box(Vector3i(cell.x, cell.y, from_depth), Vector3i(cell.x, cell.y, to_depth), colour)
	mark(figure, kind, colour)


## An ellipsoid: the cells whose middle lies within it, none below `lowest_level`.
static func ellipsoid(figure: PlayerModel.VoxelFigure, centre: Vector3, radii: Vector3, colour: Color,
		kind: String, lowest_level := -1000) -> void:
	for cell: Vector3i in VoxelBrushLayout.ellipsoid_cells(centre, radii, lowest_level):
		figure.put(cell.x, cell.y, cell.z, colour)
	mark(figure, kind, colour)


## Gives the cells for which `test` holds one of `colours` (a scattering, by the speckle of
## the cell).
static func recolour_where(figure: PlayerModel.VoxelFigure, test: Callable, colours: Array, kind: String) -> void:
	for cell: Vector3i in figure.cells.keys():
		if test.call(cell):
			figure.cells[cell] = colours[VoxelBrushLayout.speckle(cell + Vector3i(3, 5, 7)) % colours.size()]
	for colour: Color in colours:
		mark(figure, kind, colour)


## The frontmost cell (lowest z) at (column, level) in `colour`; nothing when there is none.
static func paint_front(figure: PlayerModel.VoxelFigure, column: int, level: int, colour: Color, kind: String,
		glow := false) -> void:
	for depth in range(NEAREST, FARTHEST):
		if figure.has(column, level, depth):
			figure.put(column, level, depth, colour, glow)
			mark(figure, kind, colour)
			return


## The backmost cell (highest z) at (column, level) in `colour`.
static func paint_back(figure: PlayerModel.VoxelFigure, column: int, level: int, colour: Color, kind: String) -> void:
	for depth in range(FARTHEST, NEAREST, -1):
		if figure.has(column, level, depth):
			figure.put(column, level, depth, colour)
			mark(figure, kind, colour)
			return


## The topmost cell at (column, depth) in `colour`.
static func paint_top(figure: PlayerModel.VoxelFigure, column: int, depth: int, colour: Color, kind: String) -> void:
	for level in range(FARTHEST, NEAREST, -1):
		if figure.has(column, level, depth):
			figure.put(column, level, depth, colour, figure.glowing.has(Vector3i(column, level, depth)))
			mark(figure, kind, colour)
			return


## The mesh of `figure`, `voxel` metres a voxel: standing on y = 0, centred in x and z.
static func mesh_of(figure: PlayerModel.VoxelFigure, voxel: float) -> ArrayMesh:
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind)
	var parts: Dictionary = figure.to_parts(voxel, {}, materials, PlayerModel.graded)
	return parts.meshes.body
