extends RefCounted
## Where the protest flag of a tractor stands and how big it is (layout;
## docs/CODE_LAGEN.md), in the vehicle's frame (+Z ahead, x = 0 in the middle, metres): the
## pole on the rear corner of the cab roof, the cloth at its top hanging backwards, in
## equal bands from top to bottom. Its model: protest_flag_view.gd.
##   const ProtestFlagLayout = preload("res://scripts/vehicles/protest_flag_layout.gd")

## The foot of the pole (on the roof, tools/voxgen/tiles/small_vehicles.py: roof up to
## voxel 21, the back of the cab at 29, an eighth of a metre each), its height and width.
const POLE_FOOT := Vector3(0.6, 2.55, -1.62)
const POLE_HEIGHT := 1.15
const POLE_WIDTH := 0.05
## The cloth: width (backwards from the pole), height, thickness; BAND_COUNT equal bands,
## top to bottom; how far under the top of the pole it hangs.
const CLOTH_SIZE := Vector3(0.04, 0.5, 0.75)
const BAND_COUNT := 3
const CLOTH_UNDER_TOP := 0.02


static func pole_size() -> Vector3:
	return Vector3(POLE_WIDTH, POLE_HEIGHT, POLE_WIDTH)


## The middle of the pole, from its foot.
static func pole_centre() -> Vector3:
	return Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)


## Where the cloth hangs (its top at the pole), from the foot of the pole.
static func cloth_top() -> Vector3:
	return Vector3(0.0, POLE_HEIGHT - CLOTH_UNDER_TOP, 0.0)


static func band_height() -> float:
	return CLOTH_SIZE.y / BAND_COUNT


static func band_size() -> Vector3:
	return Vector3(CLOTH_SIZE.x, band_height(), CLOTH_SIZE.z)


## The middle of band `band_index` (0: the top one), from the top of the cloth at the pole.
static func band_centre(band_index: int) -> Vector3:
	return Vector3(0.0, -band_height() * (band_index + 0.5), -CLOTH_SIZE.z * 0.5 - POLE_WIDTH * 0.5)
