extends RefCounted
## The sizes of a segmented bar (layout; docs/CODE_LAGEN.md): blocks of SEGMENT_WIDTH px,
## GAP px apart, with PADDING round them inside a border of BORDER_WIDTH px. Used by
## segment_bar.gd (its size) and segment_bar_view.gd (what it draws where).
##   const SegmentBarLayout = preload("res://scripts/ui/widgets/segment_bar_layout.gd")

const SEGMENT_WIDTH := 9.0
const GAP := 2.0
const PADDING := 3.0
const BORDER_WIDTH := 2.0


## How big a bar of `segments` blocks of `segment_height` px high is, border and all.
static func bar_size(segments: int, segment_height: float) -> Vector2:
	var inner := Vector2(segments * SEGMENT_WIDTH + (segments - 1) * GAP, segment_height)
	return inner + Vector2.ONE * 2.0 * (PADDING + BORDER_WIDTH)


## The inside of the border of a bar of `size`.
static func inside(size: Vector2) -> Rect2:
	return Rect2(Vector2.ONE * BORDER_WIDTH, size - Vector2.ONE * 2.0 * BORDER_WIDTH)


## The block of segment `segment_index` (0 = the first), `segment_height` px high.
static func segment_rect(segment_index: int, segment_height: float) -> Rect2:
	var start := Vector2.ONE * (BORDER_WIDTH + PADDING)
	return Rect2(start + Vector2(segment_index * (SEGMENT_WIDTH + GAP), 0.0), Vector2(SEGMENT_WIDTH, segment_height))
