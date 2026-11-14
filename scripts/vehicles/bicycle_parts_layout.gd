extends RefCounted
## Where the parts of a bicycle are (layout; docs/CODE_LAGEN.md): the build grid of the
## bicycles of the traffic (cyclist.gd, fatbike.gd) and its points in metres on the vehicle:
## the hubs, the bottom bracket and the pedals round it, the head tube the steering turns
## about, the saddle (the rider's hips), the grips and the lamps. Sizes are those of a Dutch
## bicycle for figures of the town's size: the hubs 0.5625 m before and behind the middle,
## 0.375 m up (the wheel fiets_wiel), the saddle at 0.75 m.
## Coordinates of the grid: x across (0..10, the frame in column MIDDLE), "along" from the
## front (0) backwards and "up" in voxels of VOXEL metres, as
## tools/voxgen/tiles/two_wheelers.py draws the other two-wheelers; point() turns them into
## metres on the vehicle (x left, y up, z forwards, the middle between the hubs at z = 0).
## The model on these points: bicycle_parts_view.gd; the name the game uses: bicycle_parts.gd.
##   const BicyclePartsLayout = preload("res://scripts/vehicles/bicycle_parts_layout.gd")

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
## How far a pedal's top is from the middle (voxels across) and over the end of its crank.
const PEDAL_ACROSS := 2.5
const PEDAL_UP := 0.5


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
	return bottom_bracket() + arm + Vector3((-PEDAL_ACROSS if right else PEDAL_ACROSS) * VOXEL, PEDAL_UP * VOXEL, 0.0)


static func hip() -> Vector3:
	return point(HIP.x, HIP.y)


## A grip on the bars (+x: the left one), before steering.
static func grip(left: bool) -> Vector3:
	return point(GRIP_ALONG_UP.x, GRIP_ALONG_UP.y, GRIP_ACROSS if left else -GRIP_ACROSS)


static func front_lamp() -> Vector3:
	return point(FRONT_LAMP.x, FRONT_LAMP.y)


static func rear_lamp() -> Vector3:
	return point(REAR_LAMP.x, REAR_LAMP.y)
