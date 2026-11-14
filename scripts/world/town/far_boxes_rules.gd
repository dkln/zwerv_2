extends RefCounted
## When the people and the vehicles are only blocks (logic; docs/CODE_LAGEN.md): from
## FAR_FROM metres in view (the iso camera's view size) a figure is a few pixels, so they are
## drawn as blocks; back under NEAR_AGAIN their own models return (the gap between the two so
## it does not flip to and fro while zooming). The node: far_boxes.gd.
##   const FarBoxesRules = preload("res://scripts/world/town/far_boxes_rules.gd")

const FAR_FROM := 95.0
const NEAR_AGAIN := 85.0
## The buffer of blocks grows by this many more than asked for, so not at every newcomer.
const ROOM_STEP := 32


## Whether everything is blocks with `view_size` metres in view, given whether it was (`was_far`).
static func is_far(view_size: float, was_far: bool) -> bool:
	return view_size > (NEAR_AGAIN if was_far else FAR_FROM)


## How many blocks the buffer should hold for `count` blocks when it holds `room` now: it
## only grows, in steps.
static func room_for(room: int, count: int) -> int:
	return count + ROOM_STEP if room < count else room
