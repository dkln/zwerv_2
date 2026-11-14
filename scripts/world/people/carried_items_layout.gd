extends RefCounted
## Where what a townsperson carries hangs (layout; docs/CODE_LAGEN.md): a briefcase and a
## handbag below the hand, a rucksack on the back, a shoulder bag on the hip with its strap
## across the chest, a trolley case on the ground behind with its grip in the hand. All in
## metres in the space of the figure (or of the arm's joint), from the joints the figure
## gives. The models: carried_items_view.gd; what is carried: carried_items.gd.
##   const CarriedItemsLayout = preload("res://scripts/world/people/carried_items_layout.gd")

## The trolley case: how far it leans over its wheels towards the one pulling it (radians)
## and how far behind the shoulder the hand holds its handle (metres).
const TROLLEY_TILT := 0.75
const TROLLEY_HAND_BACK := 0.3
## The share of the arm's length the arm is stretched pulling it (almost straight).
const TROLLEY_ARM_STRETCH := 0.95
## The case hangs this far below the hand (metres: from the hand to the top of its grip).
const HAND_GRIP_DROP := 0.02
## A rucksack: this far above the hips and behind them (plus half its depth).
const RUCKSACK_UP := 0.08
const RUCKSACK_BACK := 0.1
## A shoulder bag: the share of the shoulder's width it hangs at, and how far below the hips.
const SHOULDER_BAG_OUT := 0.95
const SHOULDER_BAG_DOWN := 0.05
## Its strap: how far above the shoulder it starts and above the bag it ends, how wide and
## thick it is, and how far in front of the hips it runs (half a torso).
const STRAP_ABOVE_SHOULDER := 0.02
const STRAP_ABOVE_BAG := 0.3
const STRAP_WIDTH := 0.04
const STRAP_THICKNESS := 0.03
const STRAP_FRONT := 0.12
## A briefcase or a handbag is heavy: the share of the arm's swing that is left.
const HEAVY_SWING := 0.35


## Where something held in the hand hangs in the arm's joint: below it by the arm's length.
static func in_hand(arm_length: float) -> Vector3:
	return Vector3(0.0, -arm_length - HAND_GRIP_DROP, 0.0)


## The same in the figure for one without that arm's joint, from its `shoulder`.
static func in_hand_from_shoulder(shoulder: Vector3, arm_length: float) -> Vector3:
	return shoulder + Vector3(0.0, -arm_length, 0.0)


## Where the model hangs in its holder with its grip (its top, `height` up) at the hand.
static func hanging_from_grip(height: float) -> Vector3:
	return Vector3(0.0, -height, 0.0)


## Where a rucksack `depth` deep sits, from the middle of the hips.
static func rucksack_spot(hips: Vector3, depth: float) -> Vector3:
	return Vector3(hips.x, hips.y + RUCKSACK_UP, hips.z - RUCKSACK_BACK - depth * 0.5)


## Where a shoulder bag hangs: on the hip under `shoulder`, at the height of the hips.
static func shoulder_bag_spot(shoulder: Vector3, hips: Vector3) -> Vector3:
	return Vector3(shoulder.x * SHOULDER_BAG_OUT, hips.y - SHOULDER_BAG_DOWN, hips.z)


## Where the hand of the one pulling a trolley case is (in the figure): behind and below the
## shoulder, the arm almost straight.
static func trolley_hand(shoulder: Vector3, arm_length: float) -> Vector3:
	var down := sqrt(maxf(pow(arm_length * TROLLEY_ARM_STRETCH, 2.0) - TROLLEY_HAND_BACK * TROLLEY_HAND_BACK, 0.01))
	return shoulder + Vector3(0.0, -down, -TROLLEY_HAND_BACK)


## The grip of a trolley case in the space of its mesh (upright, `box` its bounds): the top
## middle of its handle, on the handle side (the highest z: voxel z 0 is its front), half a
## voxel of `voxel` metres in.
static func trolley_grip(box: AABB, voxel: float) -> Vector3:
	return Vector3(box.get_center().x, box.end.y, box.end.z - voxel * 0.5)


## Where the model of a trolley case stands in its holder: its wheels (the bottom of its
## handle side) on the ground at the holder.
static func trolley_model_spot(box: AABB) -> Vector3:
	return Vector3(-box.get_center().x, 0.0, -box.end.z)


## Where the holder of a trolley case stands on the ground so that its grip (`grip` in the
## upright mesh, the model at `model_spot`), the case leant over by TROLLEY_TILT, is at `hand`.
static func trolley_spot(hand: Vector3, grip: Vector3, model_spot: Vector3) -> Vector3:
	var leant := Basis(Vector3.RIGHT, TROLLEY_TILT) * (grip + model_spot)
	return Vector3(hand.x - leant.x, 0.0, hand.z - leant.z)


## The two ends of the strap of a shoulder bag at `bag` (in the figure): [top, bottom], from
## the other shoulder down to just above the bag.
static func strap_ends(other_shoulder: Vector3, bag: Vector3) -> Array[Vector3]:
	return [other_shoulder + Vector3(0.0, STRAP_ABOVE_SHOULDER, 0.0), bag + Vector3(0.0, STRAP_ABOVE_BAG, 0.0)]


## The size of the band between those ends.
static func strap_size(top: Vector3, bottom: Vector3) -> Vector3:
	return Vector3(STRAP_WIDTH, top.distance_to(bottom), STRAP_THICKNESS)


## Where the band stands in the holder of the bag at `bag`: along the line between the ends,
## over the front of the chest.
static func strap_transform(top: Vector3, bottom: Vector3, bag: Vector3) -> Transform3D:
	var middle := (top + bottom) * 0.5
	var up := (top - bottom).normalized()
	var side := up.cross(Vector3.BACK).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var basis := Basis(side, up, side.cross(up).normalized())
	return Transform3D(basis, middle - bag + Vector3(0.0, 0.0, STRAP_FRONT))


## The turn of an arm that carries something heavy, from the `swing` (radians) of its walk.
static func heavy_arm(swing: float) -> Basis:
	return Basis(Vector3.RIGHT, swing * HEAVY_SWING)
