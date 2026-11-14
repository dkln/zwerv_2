@tool
extends RefCounted
## Where the lane arrows of the editor lie and how big they are (the layout layer of
## scripts/traffic/lane_arrows.gd): the shape of an arrow, how far the arrows of a cell with
## more than one are moved apart, and the placement of an arrow on the road surface, along
## its lane and tilted with a ramp.
##   const LaneArrowsLayout = preload("res://scripts/traffic/lane_arrows_layout.gd")

## Height of the arrows above the road surface (metres).
const LIFT := 0.12
## How far an arrow is moved forward when its cell has more than one (metres), so the arrows
## of a crossing don't cover each other.
const SHIFT := 0.7
## The arrow: flat in the x-z plane, pointing along +z, 2.2 m long (metres).
const SHAFT_HALF_WIDTH := 0.18
const HEAD_HALF_WIDTH := 0.6
const TAIL := -1.1
const NECK := 0.3
const TIP := 1.1


## The corners of the three triangles of the arrow: two for the shaft, one for the head.
static func arrow_corners() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-SHAFT_HALF_WIDTH, 0, TAIL), Vector3(SHAFT_HALF_WIDTH, 0, TAIL), Vector3(SHAFT_HALF_WIDTH, 0, NECK),
		Vector3(-SHAFT_HALF_WIDTH, 0, TAIL), Vector3(SHAFT_HALF_WIDTH, 0, NECK), Vector3(-SHAFT_HALF_WIDTH, 0, NECK),
		Vector3(-HEAD_HALF_WIDTH, 0, NECK), Vector3(HEAD_HALF_WIDTH, 0, NECK), Vector3(0, 0, TIP)])


## The spot of an arrow of a cell with more than one: `spot` (the middle of the cell) moved
## SHIFT forward along `heading`. Its height is to be looked up again there.
static func shifted(spot: Vector3, heading: Vector2i) -> Vector3:
	return spot + Vector3(heading.x, 0.0, heading.y) * SHIFT


## The placement of an arrow at `spot` on the road surface: LIFT above it, pointing along
## `heading`, up or down a ramp of `slope` (metres up per metre).
static func placement(spot: Vector3, heading: Vector2i, slope: float) -> Transform3D:
	var forward := Vector3(heading.x, slope, heading.y).normalized()
	return Transform3D(Basis.looking_at(-forward, Vector3.UP), spot + Vector3.UP * LIFT)
