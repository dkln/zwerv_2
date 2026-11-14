extends RefCounted
## Where a waste bin and the can in it stand (layout; docs/CODE_LAGEN.md; litter_bins.gd):
## the foot and the top of a bin from the box of its tile, how deep the can sits in the top
## and how it leans.
##   const LitterBinsLayout = preload("res://scripts/world/things/litter_bins_layout.gd")

## Within how many metres of the foot of a bin its can can be taken.
const SPOT_REACH := 1.3
## How far the can sinks into the top of the bin (metres), and how it leans (radians round
## x and z; round y it is turned at random).
const CAN_SINK := 0.08
const CAN_LEAN := Vector2(0.35, 0.2)
## How wide the outline of the can is (metres).
const CAN_OUTLINE := 0.02


## The foot of a bin in its grid: the middle of the `box` of its tile on the ground, the
## tile turned by `basis` and standing at `origin`.
static func foot(box: AABB, basis: Basis, origin: Vector3) -> Vector3:
	return origin + basis * Vector3(box.get_center().x, 0.0, box.get_center().z)


## The top of the bin: over its foot, as high as the box.
static func top(box: AABB, basis: Basis, origin: Vector3) -> Vector3:
	return origin + basis * Vector3(box.get_center().x, box.end.y, box.get_center().z)


## Where the can stands in a bin whose top is at `bin_top`: sunk a little into it.
static func can_place(bin_top: Vector3) -> Vector3:
	return bin_top - Vector3.UP * CAN_SINK


## How the can leans, turned `yaw` radians round y.
static func can_turn(yaw: float) -> Vector3:
	return Vector3(CAN_LEAN.x, yaw, CAN_LEAN.y)
