extends RefCounted
## How the item in its little picture is framed and moves (layout; docs/CODE_LAGEN.md): how
## much of it the camera shows, how it turns, leans and bobs. Shown by item_view.gd.
##   const ItemViewLayout = preload("res://scripts/ui/widgets/item_view_layout.gd")

## How fast it turns (radians a second), how far it leans towards you (degrees), how much
## room there is round it (share of its size), and its bob (metres per metre of model, per second).
const TURN_SPEED := 0.9
const TILT_DEGREES := 18.0
const ROOM := 1.35
const BOB_SHARE := 0.04
const BOB_SPEED := 2.0
## The box of an item without a model, and the least size a model counts as (metres).
const NO_MODEL_BOX := AABB(Vector3.ZERO, Vector3(0.1, 0.1, 0.1))
const SMALLEST := 0.01
## How far the camera stands off and how far it sees (times the size of the model).
const CAMERA_DISTANCE := 4.0
const CAMERA_FAR := 10.0
const CAMERA_NEAR := 0.01


## The size of a model in `box`: its diagonal, so every turn of it fits.
static func model_size(box: AABB) -> float:
	return maxf(box.size.length(), SMALLEST)


## Where the model stands so that it turns round the middle of `box`.
static func model_position(box: AABB) -> Vector3:
	return -box.get_center()


## How the pivot of the model is turned `clock` seconds in: leaning towards you, going round.
static func turn(clock: float) -> Vector3:
	return Vector3(deg_to_rad(TILT_DEGREES), clock * TURN_SPEED, 0.0)


## How high a model of `size` bobs `clock` seconds in (metres).
static func bob(clock: float, size: float) -> float:
	return sin(clock * BOB_SPEED) * size * BOB_SHARE


## How many metres the camera shows (its height) of a model of `size` in a picture of
## `picture` px: the whole model with ROOM round it, also when the picture is narrow.
static func camera_size(size: float, picture: Vector2) -> float:
	var aspect := picture.x / maxf(picture.y, 1.0)
	return size * ROOM / minf(aspect, 1.0)


## Where the camera stands for a model of `size`: in front of it.
static func camera_position(size: float) -> Vector3:
	return Vector3(0.0, 0.0, size * CAMERA_DISTANCE)
