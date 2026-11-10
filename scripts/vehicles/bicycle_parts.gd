class_name BicycleParts
extends RefCounted
## The bicycles of the traffic (cyclist.gd, fatbike.gd), built in code from voxels of
## VOXEL metres in three parts, so they move as on a real bicycle:
## - the frame (tubes, saddle, rear mudguard, chain guard, carrier and rear lamp), fixed;
## - the steering (fork, front mudguard, front lamp, stem and swept-back bars), turning
##   about the head tube (STEER_PIVOT, along STEER_AXIS: leaning back at the top);
## - the cranks with the pedals, turning round the bottom bracket (BOTTOM_BRACKET).
## Its rider is a TownsfolkFigure (two_wheeler.gd puts it on: hips on the saddle, feet on
## the pedals, hands on the grips). Sizes are those of a Dutch bicycle for figures of the
## town's size: the hubs 0.5625 m before and behind the middle, 0.375 m up (the wheel
## fiets_wiel), the saddle at 0.75 m.
## Coordinates while building: x across (0..10, the frame in column MIDDLE), "along" from
## the front (0) backwards and "up" in voxels, as tools/voxgen/tiles/two_wheelers.py draws
## the other two-wheelers; point() turns them into metres on the vehicle (x left, y up, z
## forwards, the middle between the hubs at z = 0).

const PlayerModel = preload("res://scripts/player/player_model.gd")

const VOXEL := 0.0625
const MIDDLE := 5
const WIDTH := 11
## The voxel row "up" = LOWEST_UP lies on the road + MODEL_LIFT, and along = MIDDLE_ALONG
## is the middle between the hubs.
const LOWEST_UP := 2.0
const MODEL_LIFT := 0.125
const MIDDLE_ALONG := 14.0

const FRONT_HUB := Vector2(5.0, 6.0)
const REAR_HUB := Vector2(23.0, 6.0)
const BRACKET := Vector2(15.5, 4.5)       # the bottom bracket (continuous along, up)
const CRANK_VOXELS := 2.4                 # crank length in voxels
const HEAD_BOTTOM := Vector2i(7, 10)
const HEAD_TOP := Vector2i(8, 13)
const SEAT_TOP := Vector2i(19, 10)
## Where the rider's hips go (over the saddle) and the grips (continuous along, up; x in
## voxels from the middle, + = left).
const HIP := Vector2(19.0, 12.9)
const GRIP_ALONG_UP := Vector2(11.5, 16.5)
const GRIP_ACROSS := 4.5
## The front lamp and the rear lamp (continuous along, up).
const FRONT_LAMP := Vector2(6.5, 11.5)
const REAR_LAMP := Vector2(27.5, 10.5)

const STEEL := Color("#B8BCC4")
const DARK_METAL := Color("#3A3C42")
const RUBBER := Color("#1C1C1E")
const LAMP_WHITE := Color("#F4F0DC")
const LAMP_RED := Color("#C81E1E")

static var _cache := {}


## A point of the build grid in metres on the vehicle.
static func point(along: float, up: float, across := 0.0) -> Vector3:
	return Vector3(across * VOXEL, MODEL_LIFT + (up - LOWEST_UP) * VOXEL, (MIDDLE_ALONG - along) * VOXEL)


## The steering: the point it turns about and its axis (the head tube, leaning back).
static func steer_pivot() -> Vector3:
	return point(HEAD_BOTTOM.x + 1.0, HEAD_BOTTOM.y + 2.0)


static func steer_axis() -> Vector3:
	var bottom := point(HEAD_BOTTOM.x + 0.5, HEAD_BOTTOM.y + 0.5)
	var top := point(HEAD_TOP.x + 0.5, HEAD_TOP.y + 0.5)
	return (top - bottom).normalized()


static func bottom_bracket() -> Vector3:
	return point(BRACKET.x, BRACKET.y)


static func crank_length() -> float:
	return CRANK_VOXELS * VOXEL


## The top of a pedal (where the foot goes) with the cranks turned by `angle` (radians,
## about x: the top pedal going forwards), right: the pedal on the right side (x < 0).
static func pedal(angle: float, right: bool) -> Vector3:
	var arm := Basis(Vector3.RIGHT, angle) * Vector3(0.0, -crank_length() if right else crank_length(), 0.0)
	return bottom_bracket() + arm + Vector3((-2.5 if right else 2.5) * VOXEL, 0.5 * VOXEL, 0.0)


static func hip() -> Vector3:
	return point(HIP.x, HIP.y)


## A grip on the bars (+x: the left one), before steering.
static func grip(left: bool) -> Vector3:
	return point(GRIP_ALONG_UP.x, GRIP_ALONG_UP.y, GRIP_ACROSS if left else -GRIP_ACROSS)


static func front_lamp() -> Vector3:
	return point(FRONT_LAMP.x, FRONT_LAMP.y)


static func rear_lamp() -> Vector3:
	return point(REAR_LAMP.x, REAR_LAMP.y)


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
			figure.mark("leather", [Color("#6A4228"), Color("#4A2E1A")])
		_cache[key] = {
			"frame": _part(frame, Vector3.ZERO),
			"steer": _part(steer, steer_pivot()),
			"crank": _part(crank, bottom_bracket()),
		}
	return _cache[key]


## The mesh of one part and where it goes, seen from `origin` (metres on the vehicle).
static func _part(figure: PlayerModel.VoxelFigure, origin: Vector3) -> Dictionary:
	figure.centre_cell = Vector2(MIDDLE + 0.5, MIDDLE_ALONG)
	var lowest := 1 << 20
	for cell: Vector3i in figure.cells:
		lowest = mini(lowest, cell.y)
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind)
	var parts: Dictionary = figure.to_parts(VOXEL, {}, materials, PlayerModel.graded)
	# to_parts puts x on the middle column, z on MIDDLE_ALONG and its lowest voxel on y = 0
	var placed := Vector3(0.0, MODEL_LIFT + (lowest - LOWEST_UP) * VOXEL, 0.0)
	return {"mesh": parts.meshes.body, "offset": placed - origin}


## A tube one voxel thick from `start` to `end` ((along, up)) in each of these columns.
static func _tube(figure: PlayerModel.VoxelFigure, start: Vector2, end: Vector2, colour: Color, columns := [MIDDLE]) -> void:
	var steps := int(maxf(absf(end.x - start.x), absf(end.y - start.y)) * 2.0) + 1
	for step in steps + 1:
		var spot := start.lerp(end, float(step) / float(steps))
		for across: int in columns:
			figure.put(across, int(floor(spot.y + 0.5)), int(floor(spot.x + 0.5)), colour)


## A mudguard: the part of a ring of `radius` round the hub higher than `from_up` above it.
static func _mudguard(figure: PlayerModel.VoxelFigure, hub: Vector2, radius: float, colour: Color, columns := [MIDDLE]) -> void:
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
	var columns := [MIDDLE]
	var tube := func(start: Vector2i, end: Vector2i, colour: Color) -> void:
		_tube(figure, Vector2(start), Vector2(end), colour, columns)
		if fat:
			_tube(figure, Vector2(start) + Vector2(0, 1), Vector2(end) + Vector2(0, 1), colour, columns)
	tube.call(HEAD_BOTTOM, HEAD_TOP, paint)                                   # the head tube
	tube.call(Vector2i(REAR_HUB), bracket, paint)                             # chain stay
	tube.call(Vector2i(REAR_HUB), SEAT_TOP, paint)                            # seat stay
	tube.call(bracket, SEAT_TOP, paint)                                       # seat tube
	if step_through:
		tube.call(bracket, Vector2i(11, 5), paint)
		tube.call(Vector2i(11, 5), HEAD_BOTTOM, paint)
	else:
		tube.call(bracket, HEAD_BOTTOM, paint)                                # down tube
		tube.call(SEAT_TOP, Vector2i(HEAD_TOP.x, HEAD_TOP.y - 1), paint)      # top tube
	_block(figure, MIDDLE - 1, MIDDLE + 1, bracket.x, bracket.x + 1, bracket.y, bracket.y + 1, paint.darkened(0.3))
	if fat:
		# the battery along the down tube, the rear lamp under the saddle
		for spot: Vector2i in [Vector2i(10, 8), Vector2i(11, 7), Vector2i(12, 6), Vector2i(13, 5)]:
			_block(figure, 4, 6, spot.x, spot.x + 1, spot.y, spot.y + 1, DARK_METAL)
		figure.put(MIDDLE, 9, 22, LAMP_RED)
	else:
		_mudguard(figure, REAR_HUB, 6.6, paint)
		# the carrier over the rear wheel on two stays, the rear lamp at its end
		_block(figure, 3, 7, 22, 27, 11, 11, STEEL)
		_tube(figure, Vector2(27, 11), REAR_HUB, STEEL, [3, 7])
		figure.put(MIDDLE, 10, 27, LAMP_RED)
		# the chain guard on the right side (x < MIDDLE: the right of the bicycle)
		_block(figure, 4, 4, 15, 23, 4, 6, paint)
	# the saddle on its post
	_tube(figure, Vector2(SEAT_TOP), Vector2(SEAT_TOP.x, SEAT_TOP.y + 1), STEEL)
	var saddle := RUBBER if fat else Color("#6A4228")
	_block(figure, 4, 6, 17, 21, 11, 11, saddle)
	figure.put(MIDDLE, 11, 16, saddle)
	figure.put(MIDDLE, 10, 21, Color("#4A2E1A") if not fat else RUBBER)


static func _build_steer(figure: PlayerModel.VoxelFigure, paint: Color, fat: bool) -> void:
	var hub := Vector2i(FRONT_HUB)
	# the fork from the hub to the head tube, the crown, the stem up and the bars swept back
	_tube(figure, Vector2(hub), Vector2(HEAD_BOTTOM) + Vector2(0, -1), paint if fat else STEEL, [4, 6])
	_block(figure, 4, 6, HEAD_BOTTOM.x - 1, HEAD_BOTTOM.x, HEAD_BOTTOM.y - 1, HEAD_BOTTOM.y - 1, paint if fat else STEEL)
	_tube(figure, Vector2(HEAD_TOP) + Vector2(0, 1), Vector2(HEAD_TOP.x + 1, 16), STEEL)
	for across in range(2, 9):
		figure.put(across, 16, 10, STEEL)
	for across: int in [0, 1, 9, 10]:
		figure.put(across, 16, 11, RUBBER)                                    # the grips
	figure.put(1, 16, 10, STEEL)
	figure.put(9, 16, 10, STEEL)
	# the front lamp on the crown
	figure.put(MIDDLE, int(FRONT_LAMP.y), int(FRONT_LAMP.x), LAMP_WHITE)
	figure.put(MIDDLE, int(FRONT_LAMP.y), int(FRONT_LAMP.x) + 1, DARK_METAL)
	if not fat:
		_mudguard(figure, FRONT_HUB, 6.6, paint)


static func _build_crank(figure: PlayerModel.VoxelFigure) -> void:
	# the cranks (the right one down, the left one up) and the pedals at their ends
	var bracket := Vector2i(15, 4)
	var reach := int(round(CRANK_VOXELS))
	_tube(figure, Vector2(bracket), Vector2(bracket.x, bracket.y - reach), DARK_METAL, [4])
	_tube(figure, Vector2(bracket), Vector2(bracket.x, bracket.y + reach), DARK_METAL, [6])
	_block(figure, 2, 3, bracket.x - 1, bracket.x + 1, bracket.y - reach, bracket.y - reach, RUBBER)
	_block(figure, 7, 8, bracket.x - 1, bracket.x + 1, bracket.y + reach, bracket.y + reach, RUBBER)
	figure.put(5, bracket.y, bracket.x, DARK_METAL)
