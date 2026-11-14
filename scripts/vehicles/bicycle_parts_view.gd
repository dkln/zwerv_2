extends RefCounted
## What a bicycle of the traffic looks like (graphics; docs/CODE_LAGEN.md): built in code
## from voxels in three parts, so they move as on a real bicycle:
## - the frame (tubes, saddle, rear mudguard, chain guard, carrier and rear lamp), fixed;
## - the steering (fork, front mudguard, front lamp, stem and swept-back bars), turning
##   about the head tube;
## - the cranks with the pedals, turning round the bottom bracket.
## The grid and the points they are built on: bicycle_parts_layout.gd. The meshes of a
## bicycle of one paint and shape are built once and kept.
##   const BicyclePartsView = preload("res://scripts/vehicles/bicycle_parts_view.gd")

const PlayerModel = preload("res://scripts/player/player_model.gd")
const BicyclePartsLayout = preload("res://scripts/vehicles/bicycle_parts_layout.gd")

const STEEL := Color("#B8BCC4")
const DARK_METAL := Color("#3A3C42")
const RUBBER := Color("#1C1C1E")
const LAMP_WHITE := Color("#F4F0DC")
const LAMP_RED := Color("#C81E1E")
const LEATHER := Color("#6A4228")
const DARK_LEATHER := Color("#4A2E1A")

static var _cache := {}


## The three parts of a bicycle: {"frame", "steer", "crank": {"mesh", "offset"}}: each mesh
## is placed at its offset (metres on the vehicle; the crank's offset from the bottom
## bracket, the steering's from steer_pivot). `paint`: the frame colour; `step_through`: a
## low step (a "omafiets"); `fat`: a fatbike (thick tubes, a battery, no mudguards or carrier).
static func build(paint: Color, step_through := false, fat := false) -> Dictionary:
	var key := "%s/%s/%s" % [paint.to_html(), step_through, fat]
	if not _cache.has(key):
		var frame := PlayerModel.VoxelFigure.new()
		var steer := PlayerModel.VoxelFigure.new()
		var crank := PlayerModel.VoxelFigure.new()
		_build_frame(frame, paint, step_through, fat)
		_build_steer(steer, paint, fat)
		_build_crank(crank)
		for figure: PlayerModel.VoxelFigure in [frame, steer, crank]:
			figure.mark("plastic", [paint, paint.darkened(0.3), RUBBER])
			figure.mark("metal", [STEEL, DARK_METAL])
			figure.mark("leather", [LEATHER, DARK_LEATHER])
		_cache[key] = {
			"frame": _part(frame, Vector3.ZERO),
			"steer": _part(steer, BicyclePartsLayout.steer_pivot()),
			"crank": _part(crank, BicyclePartsLayout.bottom_bracket()),
		}
	return _cache[key]


## The mesh of one part and where it goes, seen from `origin` (metres on the vehicle).
static func _part(figure: PlayerModel.VoxelFigure, origin: Vector3) -> Dictionary:
	figure.centre_cell = Vector2(BicyclePartsLayout.MIDDLE + 0.5, BicyclePartsLayout.MIDDLE_ALONG)
	var lowest := 1 << 20
	for cell: Vector3i in figure.cells:
		lowest = mini(lowest, cell.y)
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind)
	var parts: Dictionary = figure.to_parts(BicyclePartsLayout.VOXEL, {}, materials, PlayerModel.graded)
	# to_parts puts x on the middle column, z on BicyclePartsLayout.MIDDLE_ALONG and its lowest voxel on y = 0
	var placed := Vector3(0.0, BicyclePartsLayout.MODEL_LIFT + (lowest - BicyclePartsLayout.LOWEST_UP) * BicyclePartsLayout.VOXEL, 0.0)
	return {"mesh": parts.meshes.body, "offset": placed - origin}


## A tube one voxel thick from `start` to `end` ((along, up)) in each of these columns.
static func _tube(figure: PlayerModel.VoxelFigure, start: Vector2, end: Vector2, colour: Color, columns := [BicyclePartsLayout.MIDDLE]) -> void:
	var steps := int(maxf(absf(end.x - start.x), absf(end.y - start.y)) * 2.0) + 1
	for step in steps + 1:
		var spot := start.lerp(end, float(step) / float(steps))
		for across: int in columns:
			figure.put(across, int(floor(spot.y + 0.5)), int(floor(spot.x + 0.5)), colour)


## A mudguard: the part of a ring of `radius` round the hub higher than `from_up` above it.
static func _mudguard(figure: PlayerModel.VoxelFigure, hub: Vector2, radius: float, colour: Color, columns := [BicyclePartsLayout.MIDDLE]) -> void:
	var reach := int(radius + 2.0)
	for along in range(int(hub.x) - reach, int(hub.x) + reach + 1):
		for up in range(int(hub.y), int(hub.y) + reach + 1):
			var offset := Vector2(along + 0.5 - hub.x, up + 0.5 - hub.y)
			if offset.length() >= radius and offset.length() < radius + 0.9 and offset.y > 1.0:
				for across: int in columns:
					figure.put(across, up, along, colour)


static func _block(figure: PlayerModel.VoxelFigure, x0: int, x1: int, along0: int, along1: int, up0: int, up1: int, colour: Color) -> void:
	figure.box(Vector3i(x0, up0, along0), Vector3i(x1, up1, along1), colour)


static func _build_frame(figure: PlayerModel.VoxelFigure, paint: Color, step_through: bool, fat: bool) -> void:
	var bracket := Vector2i(15, 4)
	var columns := [BicyclePartsLayout.MIDDLE]
	var tube := func(start: Vector2i, end: Vector2i, colour: Color) -> void:
		_tube(figure, Vector2(start), Vector2(end), colour, columns)
		if fat:
			_tube(figure, Vector2(start) + Vector2(0, 1), Vector2(end) + Vector2(0, 1), colour, columns)
	tube.call(BicyclePartsLayout.HEAD_BOTTOM, BicyclePartsLayout.HEAD_TOP, paint)                                   # the head tube
	tube.call(Vector2i(BicyclePartsLayout.REAR_HUB), bracket, paint)                             # chain stay
	tube.call(Vector2i(BicyclePartsLayout.REAR_HUB), BicyclePartsLayout.SEAT_TOP, paint)                            # seat stay
	tube.call(bracket, BicyclePartsLayout.SEAT_TOP, paint)                                       # seat tube
	if step_through:
		tube.call(bracket, Vector2i(11, 5), paint)
		tube.call(Vector2i(11, 5), BicyclePartsLayout.HEAD_BOTTOM, paint)
	else:
		tube.call(bracket, BicyclePartsLayout.HEAD_BOTTOM, paint)                                # down tube
		tube.call(BicyclePartsLayout.SEAT_TOP, Vector2i(BicyclePartsLayout.HEAD_TOP.x, BicyclePartsLayout.HEAD_TOP.y - 1), paint)      # top tube
	_block(figure, BicyclePartsLayout.MIDDLE - 1, BicyclePartsLayout.MIDDLE + 1, bracket.x, bracket.x + 1, bracket.y, bracket.y + 1, paint.darkened(0.3))
	if fat:
		# the battery along the down tube, the rear lamp under the saddle
		for spot: Vector2i in [Vector2i(10, 8), Vector2i(11, 7), Vector2i(12, 6), Vector2i(13, 5)]:
			_block(figure, 4, 6, spot.x, spot.x + 1, spot.y, spot.y + 1, DARK_METAL)
		figure.put(BicyclePartsLayout.MIDDLE, 9, 22, LAMP_RED)
	else:
		_mudguard(figure, BicyclePartsLayout.REAR_HUB, 6.6, paint)
		# the carrier over the rear wheel on two stays, the rear lamp at its end
		_block(figure, 3, 7, 22, 27, 11, 11, STEEL)
		_tube(figure, Vector2(27, 11), BicyclePartsLayout.REAR_HUB, STEEL, [3, 7])
		figure.put(BicyclePartsLayout.MIDDLE, 10, 27, LAMP_RED)
		# the chain guard on the right side (x < BicyclePartsLayout.MIDDLE: the right of the bicycle)
		_block(figure, 4, 4, 15, 23, 4, 6, paint)
	# the saddle on its post
	_tube(figure, Vector2(BicyclePartsLayout.SEAT_TOP), Vector2(BicyclePartsLayout.SEAT_TOP.x, BicyclePartsLayout.SEAT_TOP.y + 1), STEEL)
	var saddle := RUBBER if fat else LEATHER
	_block(figure, 4, 6, 17, 21, 11, 11, saddle)
	figure.put(BicyclePartsLayout.MIDDLE, 11, 16, saddle)
	figure.put(BicyclePartsLayout.MIDDLE, 10, 21, DARK_LEATHER if not fat else RUBBER)


static func _build_steer(figure: PlayerModel.VoxelFigure, paint: Color, fat: bool) -> void:
	var hub := Vector2i(BicyclePartsLayout.FRONT_HUB)
	# the fork from the hub to the head tube, the crown, the stem up and the bars swept back
	_tube(figure, Vector2(hub), Vector2(BicyclePartsLayout.HEAD_BOTTOM) + Vector2(0, -1), paint if fat else STEEL, [4, 6])
	_block(figure, 4, 6, BicyclePartsLayout.HEAD_BOTTOM.x - 1, BicyclePartsLayout.HEAD_BOTTOM.x, BicyclePartsLayout.HEAD_BOTTOM.y - 1, BicyclePartsLayout.HEAD_BOTTOM.y - 1, paint if fat else STEEL)
	_tube(figure, Vector2(BicyclePartsLayout.HEAD_TOP) + Vector2(0, 1), Vector2(BicyclePartsLayout.HEAD_TOP.x + 1, 16), STEEL)
	for across in range(2, 9):
		figure.put(across, 16, 10, STEEL)
	for across: int in [0, 1, 9, 10]:
		figure.put(across, 16, 11, RUBBER)                                    # the grips
	figure.put(1, 16, 10, STEEL)
	figure.put(9, 16, 10, STEEL)
	# the front lamp on the crown
	figure.put(BicyclePartsLayout.MIDDLE, int(BicyclePartsLayout.FRONT_LAMP.y), int(BicyclePartsLayout.FRONT_LAMP.x), LAMP_WHITE)
	figure.put(BicyclePartsLayout.MIDDLE, int(BicyclePartsLayout.FRONT_LAMP.y), int(BicyclePartsLayout.FRONT_LAMP.x) + 1, DARK_METAL)
	if not fat:
		_mudguard(figure, BicyclePartsLayout.FRONT_HUB, 6.6, paint)


static func _build_crank(figure: PlayerModel.VoxelFigure) -> void:
	# the cranks (the right one down, the left one up) and the pedals at their ends
	var bracket := Vector2i(15, 4)
	var reach := int(round(BicyclePartsLayout.CRANK_VOXELS))
	_tube(figure, Vector2(bracket), Vector2(bracket.x, bracket.y - reach), DARK_METAL, [4])
	_tube(figure, Vector2(bracket), Vector2(bracket.x, bracket.y + reach), DARK_METAL, [6])
	_block(figure, 2, 3, bracket.x - 1, bracket.x + 1, bracket.y - reach, bracket.y - reach, RUBBER)
	_block(figure, 7, 8, bracket.x - 1, bracket.x + 1, bracket.y + reach, bracket.y + reach, RUBBER)
	figure.put(5, bracket.y, bracket.x, DARK_METAL)
