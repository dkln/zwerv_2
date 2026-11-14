extends RefCounted
## The sizes of the reward screen (the layout layer of scripts/ui/reward_screen.gd, which is
## the behaviour; reward_screen_rules.gd has the logic, reward_screen_view.gd builds it
## with these sizes): the panel, the stage with the item, the chips. Constants and plain
## functions, without nodes.
##   const RewardScreenLayout = preload("res://scripts/ui/screens/reward_screen_layout.gd")

const PANEL_SIZE := Vector2(560, 600)
const PANEL_BORDER := 3
## The room between the edge of the panel and what is in it, at the sides.
const PADDING := 24.0
## The room between the rows of the panel.
const COLUMN_SEPARATION := 10
## The stage with the item turning (or the XP big) and the frame round it.
const STAGE_SIZE := Vector2(512, 260)
const STAGE_BORDER := 3
## A chip: its border, the room inside it and between two of them.
const CHIP_BORDER := 2
const CHIP_MARGIN_SIDE := 10
const CHIP_MARGIN_TOP := 4
const CHIP_SEPARATION := 10


## The room between the top or bottom edge of the panel and what is in it.
static func panel_margin_top() -> float:
	return PADDING * 0.75


## The smallest size of the line of the item: as wide as the panel inside its padding (so
## it wraps there), as high as its text.
static func text_size() -> Vector2:
	return Vector2(PANEL_SIZE.x - PADDING * 2.0, 0.0)
