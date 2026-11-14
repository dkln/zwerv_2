extends RefCounted
## Where the places of a quest stand on the minimap (layout; docs/CODE_LAGEN.md): on the map
## as a diamond, or, when they are off it, on its edge as an arrow pointing the way. Drawn
## by quest_marks.gd.
##   const QuestMarksLayout = preload("res://scripts/ui/widgets/quest_marks_layout.gd")

## Half the size of the diamond, how much bigger its ink rim is, and how far from the edge
## an arrow for a far place sits (px).
const MARK_SIZE := 6.0
const RIM := 3.0
const EDGE_INSET := 9.0
## The arrow for a far place: its ink outline and the coloured arrow in it, each [how far the
## tip lies past its place, length, head length, half the head, half the tail] (px).
const ARROW_OUTLINE := [9.0, 19.0, 12.0, 9.0, 4.0]
const ARROW_INSIDE := [6.0, 14.0, 8.0, 6.0, 2.0]


## Whether `point` lies on a minimap of `map_size` px (EDGE_INSET px inside its edge): there
## it gets its diamond, else an arrow on the edge.
static func is_on_map(point: Vector2, map_size: Vector2) -> bool:
	return Rect2(Vector2.ONE * EDGE_INSET, map_size - Vector2.ONE * EDGE_INSET * 2.0).has_point(point)


## Where the arrow for a `point` off a minimap of `map_size` px sits: on the edge (EDGE_INSET
## px inside it), on the line from the middle to the point. Not for a point in the middle itself.
static func edge_place(point: Vector2, map_size: Vector2) -> Vector2:
	var middle := map_size * 0.5
	var inner_size := map_size - Vector2.ONE * EDGE_INSET * 2.0
	var way := point - middle
	var reach := minf(absf(inner_size.x * 0.5 / way.x) if way.x != 0.0 else INF,
			absf(inner_size.y * 0.5 / way.y) if way.y != 0.0 else INF)
	return (middle + way * reach).round()


## Whether a `point` off a minimap of `map_size` px has a way to point: not the middle itself.
static func has_way(point: Vector2, map_size: Vector2) -> bool:
	return (point - map_size * 0.5).length_squared() >= 0.0001


## The way from the middle of a minimap of `map_size` px to `point` (unit length).
static func way_to(point: Vector2, map_size: Vector2) -> Vector2:
	return (point - map_size * 0.5).normalized()


## A diamond round `at`, `half` px from its middle to a corner.
static func diamond(at: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(0, -half), at + Vector2(half, 0), at + Vector2(0, half), at + Vector2(-half, 0)])
