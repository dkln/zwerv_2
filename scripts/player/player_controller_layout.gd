extends RefCounted
## Where the parts of the player stand and how big they are (layout; docs/CODE_LAGEN.md): the
## box round the figure and the room its idle movement takes, the shapes it walks and pushes
## with, how it lies asleep, how deep it sinks, and how high over the feet things show and
## sound. The behaviour is player_controller.gd, the picture player_controller_view.gd. Boxes
## are in the figure's own space: feet at y = 0, facing +z.
##   const PlayerControllerLayout = preload("res://scripts/player/player_controller_layout.gd")

## Size of the figure in the town (PlayerModel.figure_scale): about 1.8 m tall (hair and
## hats included), in proportion to the townspeople (TownsfolkFigure, 1.75 m), the
## two-wheelers and the cars.
const FIGURE_SCALE := 0.78
## The box of a figure that has no meshes (yet), and the least height of a real one.
const DEFAULT_FIGURE_BOX := AABB(Vector3(-0.3, 0.0, -0.2), Vector3(0.6, 1.9, 0.4))
const LEAST_FIGURE_HEIGHT := 0.5
## The figure is never quite still (breathing, the arms: PlayerModel's idle movement): standing
## it reaches up to some 3 cm further to the sides and 9 cm further forward than at rest. The
## collider gets that room round the box at rest (metres; -x/-z on the low side, +x/+z on the
## high side; the figure faces +z).
const POSE_ROOM_LOW := Vector3(0.04, 0.0, 0.02)
const POSE_ROOM_HIGH := Vector3(0.04, 0.02, 0.1)
## The cylinder it walks with: its radius within these, its least height, and how far its
## bottom clears what it steps over (`max_step`).
const WALK_RADIUS_LEAST := 0.2
const WALK_RADIUS_MOST := 0.45
const WALK_HEIGHT_LEAST := 0.4
const STEP_CLEARANCE := 0.05
## The least height of the box of what it pushes.
const PUSHED_HEIGHT_LEAST := 0.1
## Metres over the feet: the numbers that rise (experience, full pockets, an item, damage)
## and the sounds (the death cry, the kick, the groan).
const XP_HEIGHT := 2.3
const FULL_HEIGHT := 2.0
const ITEM_HEIGHT := 2.1
const DAMAGE_HEIGHT := 2.1
const DEATH_CRY_HEIGHT := 0.8
const KICK_HEIGHT := 1.0
const GROAN_HEIGHT := 0.4
## Asleep: the middle of the body this share of its length from where it stood.
const SLEEP_BODY_SHARE := 0.45
## Drowning: how far under its own height it sinks, and how high the hop over the edge is.
const SINK_EXTRA := 0.5
const WATER_HOP_HEIGHT := 0.6


## `rest` (the box round the figure at rest) with the room for its idle movement.
static func with_pose_room(rest: AABB) -> AABB:
	return AABB(rest.position - POSE_ROOM_LOW, rest.size + POSE_ROOM_LOW + POSE_ROOM_HIGH)


## The box to use for a figure whose meshes measure `bounds`: that, or DEFAULT_FIGURE_BOX
## when there were none (`measured` false) or it is not a standing figure.
static func figure_box(bounds: AABB, measured: bool) -> AABB:
	if not measured or bounds.size.y < LEAST_FIGURE_HEIGHT:
		return DEFAULT_FIGURE_BOX
	return bounds


## Radius of the cylinder the figure in `box` walks with.
static func walk_radius(box: AABB) -> float:
	return clampf(maxf(box.size.x, box.size.z) * 0.5, WALK_RADIUS_LEAST, WALK_RADIUS_MOST)


## Height of that cylinder: the figure above what it steps over (`max_step`).
static func walk_height(box: AABB, max_step: float) -> float:
	return maxf(box.size.y - max_step - STEP_CLEARANCE, WALK_HEIGHT_LEAST)


## Where the middle of the walking cylinder is with the feet at `feet`.
static func walk_centre(feet: Vector3, max_step: float, cylinder_height: float) -> Vector3:
	return feet + Vector3.UP * (max_step + STEP_CLEARANCE + cylinder_height * 0.5)


## The bottom of what it pushes: clear of the floor, as the walking cylinder.
static func pushed_bottom(box: AABB, max_step: float) -> float:
	return maxf(box.position.y, max_step + STEP_CLEARANCE)


## Size of the shape of what it pushes (`box`), its bottom clear of the floor.
static func pushed_size(box: AABB, max_step: float) -> Vector3:
	return Vector3(box.size.x, maxf(box.end.y - pushed_bottom(box, max_step), PUSHED_HEIGHT_LEAST), box.size.z)


## The middle of that shape, in the player's own space.
static func pushed_centre(box: AABB, max_step: float) -> Vector3:
	var centre := box.get_center()
	centre.y = pushed_bottom(box, max_step) + pushed_size(box, max_step).y * 0.5
	return centre


## Where the figure in `box` lies asleep: on its back (turned -90 degrees round x), its back
## on the ground, the middle of the body about where it stood.
static func sleeping_position(box: AABB) -> Vector3:
	return Vector3(0.0, -box.position.z, box.size.y * SLEEP_BODY_SHARE)


## How far up the figure in `box` comes when it falls over backwards dead (its back on the ground).
static func fallen_lift(box: AABB) -> float:
	return box.size.z * 0.5


## The height (the figure's own y) a drowning figure in `box` sinks to: out of sight.
static func sunk_height(box: AABB) -> float:
	return -box.size.y - SINK_EXTRA


## Where a blow lands on the figure in `box` standing at `feet`: the middle of its body.
static func contact_point(feet: Vector3, box: AABB) -> Vector3:
	return feet + Vector3.UP * box.get_center().y


## A point `height` metres over the feet.
static func over_feet(feet: Vector3, height: float) -> Vector3:
	return feet + Vector3.UP * height


## Where the hop into the water is at `share` (0..1) of the way from `from` to `water`.
static func water_hop(from: Vector3, water: Vector3, share: float) -> Vector3:
	return from.lerp(water, share) + Vector3.UP * sin(share * PI) * WATER_HOP_HEIGHT
