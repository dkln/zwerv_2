extends RefCounted
## The shape of the arrow bobbing over something you can use (layout; docs/CODE_LAGEN.md;
## interaction_mark_view.gd): a flat "->" pointing down, its point at the origin, the head
## below and the shaft above it; and where the arrow and its darker copy stand.
##   const InteractionMarkLayout = preload("res://scripts/world/things/interaction_mark_layout.gd")

## The arrow (metres): the width and height of the head, the width and length of the shaft.
const HEAD_WIDTH := 0.8
const HEAD_HEIGHT := 0.5
const SHAFT_WIDTH := 0.3
const SHAFT_LENGTH := 0.5
## How far under the arrow its darker copy lies.
const SHADOW_DROP := 0.09


## The corners of the three triangles of the arrow: the head, then the two halves of the
## shaft.
static func arrow_corners() -> PackedVector3Array:
	var half_head := HEAD_WIDTH * 0.5
	var half_shaft := SHAFT_WIDTH * 0.5
	var shaft_top := HEAD_HEIGHT + SHAFT_LENGTH
	var point := Vector3(0.0, 0.0, 0.0)
	var head_left := Vector3(-half_head, HEAD_HEIGHT, 0.0)
	var head_right := Vector3(half_head, HEAD_HEIGHT, 0.0)
	var shaft_bottom_left := Vector3(-half_shaft, HEAD_HEIGHT, 0.0)
	var shaft_bottom_right := Vector3(half_shaft, HEAD_HEIGHT, 0.0)
	var shaft_top_left := Vector3(-half_shaft, shaft_top, 0.0)
	var shaft_top_right := Vector3(half_shaft, shaft_top, 0.0)
	return PackedVector3Array([
		point, head_right, head_left,
		shaft_bottom_left, shaft_bottom_right, shaft_top_right,
		shaft_bottom_left, shaft_top_right, shaft_top_left,
	])


## Where the arrow stands with its point `height` metres up.
static func arrow_place(height: float) -> Vector3:
	return Vector3(0.0, height, 0.0)


## Where its darker copy stands then: a little under it.
static func shadow_place(height: float) -> Vector3:
	return arrow_place(height) + Vector3(0.0, -SHADOW_DROP, 0.0)
