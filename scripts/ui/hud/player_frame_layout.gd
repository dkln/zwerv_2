extends RefCounted
## The sizes and places of the player frame of the HUD (layout; docs/CODE_LAGEN.md): the
## portrait with its border and the level badge on its corner, and beside it the column of
## the name, the stat rows and the experience. Built by player_frame_view.gd.
##   const PlayerFrameLayout = preload("res://scripts/ui/hud/player_frame_layout.gd")

## The portrait: a square this big with a border this wide.
const PORTRAIT_SIZE := 76.0
const PORTRAIT_BORDER := 3.0
## How far the level badge sticks out of the portrait at its right and bottom edge, and
## how far its hard shadow lies from it.
const BADGE_OUTSIDE := 10.0
const BADGE_SHADOW := Vector2(3.0, 3.0)
## The column beside the portrait: how far from it, how far from the top, and the space
## between its rows.
const COLUMN_GAP := 14.0
const COLUMN_TOP := 2.0
const ROW_SEPARATION := 7
## Between the icon, the bar and the value of a stat.
const STAT_SEPARATION := 8
## Between the experience bar and the points under it.
const EXPERIENCE_SEPARATION := 5
## The column of the stat icons (and "XP"): this wide, the thing in it in the middle, so
## the bars after it all start at the same place.
const ICON_COLUMN_WIDTH := 18.0


## The picture inside the border of the portrait: where it starts and how big it is.
static func portrait_inner() -> Rect2:
	return Rect2(Vector2.ONE * PORTRAIT_BORDER, Vector2.ONE * (PORTRAIT_SIZE - 2.0 * PORTRAIT_BORDER))


## Where the level badge (`badge_size`) stands on the portrait: its right and bottom edge
## BADGE_OUTSIDE outside the portrait.
static func badge_position(badge_size: Vector2) -> Vector2:
	return Vector2.ONE * (PORTRAIT_SIZE + BADGE_OUTSIDE) - badge_size


## Where the column of the name and the stats starts.
static func column_position() -> Vector2:
	return Vector2(PORTRAIT_SIZE + COLUMN_GAP, COLUMN_TOP)
