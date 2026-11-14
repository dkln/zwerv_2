extends RefCounted
## The sizes of the level-up screen (the layout layer of scripts/ui/level_up_screen.gd,
## which is the behaviour; level_up_screen_rules.gd has the logic, level_up_screen_view.gd
## builds it with these sizes): the panel, the stage with the new level, the rows of the
## stats. Constants and plain functions, without nodes.
##   const LevelUpScreenLayout = preload("res://scripts/ui/screens/level_up_screen_layout.gd")

## The smallest size of the panel (as high as what is in it).
const PANEL_SIZE := Vector2(600, 0)
const PANEL_BORDER := 3
## The room between the edge of the panel and what is in it, at the sides.
const PADDING := 24.0
## The room between the rows of the panel.
const COLUMN_SEPARATION := 10
## How high the stage with the new level and its rays is.
const STAGE_HEIGHT := 110.0
## A row of a stat: its border, the room inside it, between its parts and between its two
## lines of words; the size of a pixel of its icon.
const ROW_BORDER := 2
const ROW_MARGIN_SIDE := 12
const ROW_MARGIN_TOP := 8
const ROW_SEPARATION := 14
const WORDS_SEPARATION := 2
const ICON_PIXEL := 3.0


## The room between the top or bottom edge of the panel and what is in it.
static func panel_margin_top() -> float:
	return PADDING * 0.75


## The size of the stage: as wide as the panel inside its padding.
static func stage_size() -> Vector2:
	return Vector2(PANEL_SIZE.x - PADDING * 2.0, STAGE_HEIGHT)


## Where a rectangle of `size` at the origin of something with `transform` is on the screen.
static func on_screen(transform: Transform2D, size: Vector2) -> Rect2:
	return transform * Rect2(Vector2.ZERO, size)


## The first of `rectangles` that `point` is in; -1: none.
static func index_at(rectangles: Array, point: Vector2) -> int:
	for index in rectangles.size():
		if (rectangles[index] as Rect2).has_point(point):
			return index
	return -1
