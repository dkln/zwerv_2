extends RefCounted
## The rules of the floor plan of an interior (logic; docs/CODE_LAGEN.md): the grid of
## probes over its area and what each probe makes of what it finds: a wall, furniture, the
## floor, lower ground or nothing. Probed and painted by interior_plan.gd.
##   const InteriorPlanRules = preload("res://scripts/ui/widgets/interior_plan_rules.gd")

## Metres between two probes: a pixel of the plan.
const SAMPLE_METRES := 0.5
## Heights of the probes over the floor of the interior (its origin), metres.
const HEAD_HEIGHT := 1.7
const KNEE_HEIGHT := 0.6
## Ground this far below the floor counts as lower (the tracks, a pit).
const LOWER_FROM := -0.4
## How far under the floor the ray down looks for ground (metres).
const GROUND_DEPTH := 4.0
## What a probe finds.
const EMPTY := "empty"
const WALL := "wall"
const FURNITURE := "furniture"
const FLOOR := "floor"
const LOWER := "lower"


## Whether an area of `extent` metres (x, z) is anything to make a plan of.
static func has_area(extent: Vector2) -> bool:
	return extent.x > 0.0 and extent.y > 0.0


## How many probes (pixels) wide and deep the plan of an area of `extent` metres is.
static func grid_size(extent: Vector2) -> Vector2i:
	return Vector2i(int(ceil(extent.x / SAMPLE_METRES)), int(ceil(extent.y / SAMPLE_METRES)))


## The spot (world x, z) of probe (column, row) of a plan that starts at `origin`: the
## middle of its pixel.
static func spot(origin: Vector2, column: int, row: int) -> Vector2:
	return origin + (Vector2(column, row) + Vector2(0.5, 0.5)) * SAMPLE_METRES


## What a spot is: a WALL when something stands at head height, else FURNITURE when
## something stands at knee height, else what the ground under it is (ground_kind).
static func kind(head_blocked: bool, knee_blocked: bool, ground: float, floor_height: float) -> String:
	if head_blocked:
		return WALL
	if knee_blocked:
		return FURNITURE
	return ground_kind(ground, floor_height)


## What ground at height `ground` (NAN: none) is under a floor at `floor_height`: EMPTY
## without ground, LOWER when it lies more than LOWER_FROM under the floor, else FLOOR.
static func ground_kind(ground: float, floor_height: float) -> String:
	if is_nan(ground):
		return EMPTY
	return LOWER if ground < floor_height + LOWER_FROM else FLOOR


## The area `lowest`..`highest` grown to hold a cell round `centre`, `half_cell` to either
## side: [lowest, highest].
static func grown(lowest: Vector2, highest: Vector2, centre: Vector2, half_cell: Vector2) -> Array[Vector2]:
	return [Vector2(minf(lowest.x, centre.x - half_cell.x), minf(lowest.y, centre.y - half_cell.y)),
			Vector2(maxf(highest.x, centre.x + half_cell.x), maxf(highest.y, centre.y + half_cell.y))]
