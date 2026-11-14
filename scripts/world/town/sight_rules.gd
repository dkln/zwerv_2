extends RefCounted
## How often something in the town is updated, by where it is seen (logic; docs/CODE_LAGEN.md):
## what is on the screen every physics step; what is off it by more than OFF_SCREEN_MARGIN (a
## share of the screen round it) only every NEAR_STEPS steps; and what is also further than
## FAR_METRES from the point the camera looks at (or FARTHEST_METRES from a perspective
## camera) every FAR_STEPS steps. Things look again every LOOK_STEPS steps. sight.gd asks the
## camera where something is and these rules what follows from it.
##   const SightRules = preload("res://scripts/world/town/sight_rules.gd")

const OFF_SCREEN_MARGIN := 0.3
const FAR_METRES := 150.0
const FARTHEST_METRES := 300.0
const NEAR_STEPS := 6
const FAR_STEPS := 10
const LOOK_STEPS := 15
## Steps between two updates of what is in sight (and of everything without a camera).
const EVERY_STEP := 1


## True for something `from_camera` metres from a perspective camera that is too far off to
## count at all (an orthogonal camera never is: it sees no further by standing further).
static func is_beyond_farthest(perspective: bool, from_camera: float) -> bool:
	return perspective and from_camera > FARTHEST_METRES


## The screen with its margin round it: OFF_SCREEN_MARGIN of its width and height on each side.
static func grown_screen(screen: Rect2) -> Rect2:
	return screen.grow_individual(screen.size.x * OFF_SCREEN_MARGIN, screen.size.y * OFF_SCREEN_MARGIN,
			screen.size.x * OFF_SCREEN_MARGIN, screen.size.y * OFF_SCREEN_MARGIN)


## True if `on_screen` (where something is drawn, in pixels) is on the screen or in its margin.
static func is_in_sight(screen: Rect2, on_screen: Vector2) -> bool:
	return grown_screen(screen).has_point(on_screen)


## Steps between two updates of something out of sight, `from_focus` metres (over the ground)
## from the point the camera looks at.
static func steps_out_of_sight(from_focus: float) -> int:
	return FAR_STEPS if from_focus > FAR_METRES else NEAR_STEPS
