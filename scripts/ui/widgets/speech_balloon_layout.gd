extends RefCounted
## The sizes and places of a speech balloon (layout; docs/CODE_LAGEN.md): how wide and high
## its text is, where the panel stands over the tip of the tail, and the shapes of the tail
## and of the darker copy under the balloon. The tip of the tail is the origin. Built by
## speech_balloon_view.gd.
##   const SpeechBalloonLayout = preload("res://scripts/ui/widgets/speech_balloon_layout.gd")

## The widest the text runs before it wraps (px), the font size, the padding.
const MAX_TEXT_WIDTH := 270.0
const TEXT_SIZE := 15
const PADDING := Vector2(10, 6)
## How far the darker copy under the balloon sits lower (px).
const BALLOON_DEPTH := 3
## The tail: how high and how wide at the panel.
const TAIL_HEIGHT := 10.0
const TAIL_WIDTH := 12.0
const BORDER_WIDTH := 2
## The space between wrapped rows (px).
const LINE_SEPARATION := 4
## How big the balloon is as it pops up (share of its size).
const POP_FROM := 0.6


## How wide the text is for a line that is `line_width` px on one row: as wide as it needs,
## up to MAX_TEXT_WIDTH, so the balloon does not grow while typing.
static func text_width(line_width: float) -> float:
	return minf(ceilf(line_width) + 2.0, MAX_TEXT_WIDTH)


## How high a text stands that is `wrapped_height` px high when wrapped, in a font whose
## rows are `row_height` px: its rows with the line separation between them.
static func rows_height(wrapped_height: float, row_height: float) -> float:
	var rows := maxi(1, roundi(wrapped_height / row_height))
	return ceilf(rows * row_height + (rows - 1) * LINE_SEPARATION)


## Where a panel of `panel_size` stands: above the tip, in the middle, its bottom border on
## the top of the tail.
static func panel_position(panel_size: Vector2) -> Vector2:
	return Vector2(-roundf(panel_size.x * 0.5), -panel_size.y - TAIL_HEIGHT + BORDER_WIDTH)


## The outline of the tail: from the panel's bottom border down to the tip.
static func tail_outline() -> PackedVector2Array:
	var half := TAIL_WIDTH * 0.5 + BORDER_WIDTH
	return PackedVector2Array([Vector2(-half, -TAIL_HEIGHT), Vector2(half, -TAIL_HEIGHT), Vector2(0, BORDER_WIDTH)])


## The fill of the tail: from a pixel inside the panel (so the bottom border is gone where
## the tail joins) down to just above the tip.
static func tail_fill() -> PackedVector2Array:
	var half := TAIL_WIDTH * 0.5
	return PackedVector2Array([Vector2(-half, -TAIL_HEIGHT - 1.0), Vector2(half, -TAIL_HEIGHT - 1.0), Vector2(0, -BORDER_WIDTH)])


## The darker copy under the tail: its outline BALLOON_DEPTH px lower.
static func tail_shadow() -> PackedVector2Array:
	var lower := PackedVector2Array()
	for point in tail_outline():
		lower.append(point + Vector2(0, BALLOON_DEPTH))
	return lower


## The darker copy under a panel at `panel_position` of `panel_size`: BALLOON_DEPTH px lower.
static func panel_shadow(at: Vector2, panel_size: Vector2) -> Rect2:
	return Rect2(at + Vector2(0, BALLOON_DEPTH), panel_size)
