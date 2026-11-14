extends RefCounted
## Where the blocks of the far-off people and vehicles stand and how big they are (layout;
## docs/CODE_LAGEN.md): a unit cube stretched to the size of someone on foot standing on
## their feet, or to the box round a vehicle. The node: far_boxes.gd.
##   const FarBoxesLayout = preload("res://scripts/world/town/far_boxes_layout.gd")

## The block of someone on foot (m): wide, tall, deep.
const PERSON_BOX := Vector3(0.5, 1.75, 0.35)


## The block of someone standing at `feet` (world) turned `turn` radians round the vertical.
static func person_block(feet: Vector3, turn: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, turn).scaled(PERSON_BOX), feet + Vector3.UP * PERSON_BOX.y * 0.5)


## The block of a vehicle placed at `placed` (world) whose model fits in `box` (its own space).
static func vehicle_block(placed: Transform3D, box: AABB) -> Transform3D:
	return placed * Transform3D(Basis.from_scale(box.size), box.get_center())
