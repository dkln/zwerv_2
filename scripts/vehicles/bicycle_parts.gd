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
## The name the game knows the bicycle by (docs/CODE_LAGEN.md): where its parts are is
## bicycle_parts_layout.gd's, its model bicycle_parts_view.gd's; this script hands both on
## under the names they had here.

const BicyclePartsLayout = preload("res://scripts/vehicles/bicycle_parts_layout.gd")
const BicyclePartsView = preload("res://scripts/vehicles/bicycle_parts_view.gd")

const VOXEL := BicyclePartsLayout.VOXEL
const MIDDLE := BicyclePartsLayout.MIDDLE
const WIDTH := BicyclePartsLayout.WIDTH
const LOWEST_UP := BicyclePartsLayout.LOWEST_UP
const MODEL_LIFT := BicyclePartsLayout.MODEL_LIFT
const MIDDLE_ALONG := BicyclePartsLayout.MIDDLE_ALONG
const FRONT_HUB := BicyclePartsLayout.FRONT_HUB
const REAR_HUB := BicyclePartsLayout.REAR_HUB
const BRACKET := BicyclePartsLayout.BRACKET
const CRANK_VOXELS := BicyclePartsLayout.CRANK_VOXELS
const HEAD_BOTTOM := BicyclePartsLayout.HEAD_BOTTOM
const HEAD_TOP := BicyclePartsLayout.HEAD_TOP
const SEAT_TOP := BicyclePartsLayout.SEAT_TOP
const HIP := BicyclePartsLayout.HIP
const GRIP_ALONG_UP := BicyclePartsLayout.GRIP_ALONG_UP
const GRIP_ACROSS := BicyclePartsLayout.GRIP_ACROSS
const FRONT_LAMP := BicyclePartsLayout.FRONT_LAMP
const REAR_LAMP := BicyclePartsLayout.REAR_LAMP

const STEEL := BicyclePartsView.STEEL
const DARK_METAL := BicyclePartsView.DARK_METAL
const RUBBER := BicyclePartsView.RUBBER
const LAMP_WHITE := BicyclePartsView.LAMP_WHITE
const LAMP_RED := BicyclePartsView.LAMP_RED


## A point of the build grid in metres on the vehicle.
static func point(along: float, up: float, across := 0.0) -> Vector3:
	return BicyclePartsLayout.point(along, up, across)


## The steering: the point it turns about and its axis (the head tube, leaning back).
static func steer_pivot() -> Vector3:
	return BicyclePartsLayout.steer_pivot()


static func steer_axis() -> Vector3:
	return BicyclePartsLayout.steer_axis()


static func bottom_bracket() -> Vector3:
	return BicyclePartsLayout.bottom_bracket()


static func crank_length() -> float:
	return BicyclePartsLayout.crank_length()


## The top of a pedal (where the foot goes) with the cranks turned by `angle` (radians,
## about x: the top pedal going forwards), right: the pedal on the right side (x < 0).
static func pedal(angle: float, right: bool) -> Vector3:
	return BicyclePartsLayout.pedal(angle, right)


static func hip() -> Vector3:
	return BicyclePartsLayout.hip()


## A grip on the bars (+x: the left one), before steering.
static func grip(left: bool) -> Vector3:
	return BicyclePartsLayout.grip(left)


static func front_lamp() -> Vector3:
	return BicyclePartsLayout.front_lamp()


static func rear_lamp() -> Vector3:
	return BicyclePartsLayout.rear_lamp()


## The three parts of a bicycle: {"frame", "steer", "crank": {"mesh", "offset"}}: each mesh
## is placed at its offset (metres on the vehicle; the crank's offset from the bottom
## bracket, the steering's from steer_pivot). `paint`: the frame colour; `step_through`: a
## low step (a "omafiets"); `fat`: a fatbike (thick tubes, a battery, no mudguards or carrier).
static func build(paint: Color, step_through := false, fat := false) -> Dictionary:
	return BicyclePartsView.build(paint, step_through, fat)
