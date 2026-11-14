extends RefCounted
## Where the things of the people of the story stand (layout; docs/CODE_LAGEN.md): the marker
## over the one you walk with, the balloons over their heads, the trolley before the one who
## pushes it and what lies in its basket, the hands on its handle, the roll-up at the mouth.
## characters_view.gd builds them at these places.
##   const CharactersLayout = preload("res://scripts/story/characters_layout.gd")

## The marker over the one you walk with: this high over its head, this big, bobbing this far.
const LEAD_MARKER_ABOVE := 0.55
const LEAD_MARKER_SIZE := 0.22
const LEAD_MARKER_BOB := 0.08
## How high over its feet the balloon of a line on the way stands (times its "lengte"), that
## of someone muttering, and the call of the one waiting.
const TALK_HEIGHT := 2.3
const MUTTER_HEIGHT := 2.3
const CALL_HEIGHT := 2.3
## Where the trolley stands before the one pushing it, and its handle (in the person's space).
const TROLLEY_AHEAD := 0.8
const HANDLE := Vector3(0.0, 0.9, 0.36)
## Half the metres between the two hands on the handle.
const HAND_APART := 0.17
## The basket of a trolley without a model, and the size of a bin bag in it.
const BASKET := AABB(Vector3(-0.3, 0.45, -0.4), Vector3(0.6, 0.45, 0.8))
const BAG_SIZE := Vector3(0.26, 0.24, 0.3)
const BAGS := 2
const CANS := 12
const CAN_SCALE := 0.8
## The mouth of a figure, in its cells (TownsfolkFigure.cell_point): where the smoke rises
## and where the hand goes for a drag.
const SMOKE_CELL := Vector3(7.0, 28.5, -4.5)
const DRAG_CELL := Vector3(7.0, 27.0, -3.0)


## How high the marker stands over the feet of someone whose head is at `head_height`, at
## `clock` seconds (it bobs).
static func marker_height(head_height: float, clock: float) -> float:
	return head_height + LEAD_MARKER_ABOVE + sin(clock * 3.0) * LEAD_MARKER_BOB


## The radius and the height of the marker's diamond.
static func marker_radius() -> float:
	return LEAD_MARKER_SIZE * 0.6


static func marker_length() -> float:
	return LEAD_MARKER_SIZE * 1.6


## The trolley in the space of the one pushing it.
static func trolley_position() -> Vector3:
	return Vector3(0.0, 0.0, TROLLEY_AHEAD)


## The handle of the trolley in the space of the one pushing it (at their feet's height 0).
static func handle_point() -> Vector3:
	return Vector3(0.0, HANDLE.y, HANDLE.z)


## The left (`side` -1) or right (1) hand's place, `handle` being the handle's.
static func hand_point(handle: Vector3, side: float) -> Vector3:
	return handle + Vector3(HAND_APART, 0.0, 0.0) * side


## The basket of a trolley whose model fills `model_box`: its upper half, a little inside.
static func basket_in(model_box: AABB) -> AABB:
	return AABB(Vector3(model_box.position.x + 0.08, model_box.position.y + model_box.size.y * 0.5, model_box.position.z + 0.12),
			Vector3(model_box.size.x - 0.16, model_box.size.y * 0.45, model_box.size.z - 0.24))


## Where bin bag `bag_index` lies in `basket`: low, one after the other.
static func bag_position(basket: AABB, bag_index: int) -> Vector3:
	return basket.position + Vector3(basket.size.x * (0.3 + 0.4 * bag_index), basket.size.y * 0.5, basket.size.z * (0.35 + 0.3 * bag_index))


## Where a can lies in `basket`: `across` and `along` (0..1) over its floor, `up` (0.5..1) of
## its height (heaped over the bags).
static func can_position(basket: AABB, across: float, up: float, along: float) -> Vector3:
	return basket.position + Vector3(across * basket.size.x, basket.size.y * up, 0.15 + along * (basket.size.z - 0.15))
