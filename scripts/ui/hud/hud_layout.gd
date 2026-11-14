extends RefCounted
## Where the parts of the HUD stand (layout; docs/CODE_LAGEN.md): the HUD is laid out at
## the size of the design (1280 x 720) and scaled to the window, the corners staying in the
## corners. The parts themselves: player_frame.gd (top left), notice_banner.gd (top centre),
## the column top right (location.gd, minimap.gd, clock.gd and waypoint.gd under each
## other), quest_tracker.gd (right, under the minimap), the money (money_view.gd, bottom
## right) and the action prompts (bottom left).
##   const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")

## Size of the design; the HUD is laid out at this size and scaled to the window.
const DESIGN_SIZE := Vector2(1280.0, 720.0)
## How far the parts in the corners stay from the edges.
const MARGIN := 24.0
## How far the money and the action prompts stay from the bottom edge.
const BOTTOM_MARGIN := 28.0
## The notice: its width (a mission title is longer than an area name) and how far from the top.
const NOTICE_WIDTH := 720.0
const NOTICE_TOP := 34.0
## The minimap: a square this big, under the box of the location (this high, a gap between).
const MINIMAP_SIZE := 200.0
const LOCATION_HEIGHT := 58.0
const MAP_TOP := LOCATION_HEIGHT + 8.0
## Under the minimap: the clock this far below it, the chip of the marker this far below
## the top of the clock; the column of all of them is this much higher than MAP_TOP.
const CLOCK_BELOW_MAP := 8.0
const WAYPOINT_BELOW_CLOCK := 30.0
const MAP_COLUMN_BELOW_MAP_TOP := 270.0
## The quest tracker: its width and how far under the top of the minimap it starts.
const TRACKER_WIDTH := 300.0
const TRACKER_BELOW_MAP_TOP := 290.0


## How much the design is scaled to fit the window: the smaller of the two ratios.
static func scale_factor(window: Vector2) -> float:
	return minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)


## The area the parts are laid out in (design pixels): the window divided by the scale, so
## a window wider or higher than the design gives the corners more room.
static func design_area(window: Vector2) -> Vector2:
	return window / scale_factor(window)


static func player_frame_position() -> Vector2:
	return Vector2(MARGIN, MARGIN)


static func notice_position(area: Vector2) -> Vector2:
	return Vector2((area.x - NOTICE_WIDTH) * 0.5, NOTICE_TOP)


## The column top right (the location, the minimap, the clock and the marker under each
## other): where it starts.
static func minimap_position(area: Vector2) -> Vector2:
	return Vector2(area.x - MARGIN - MINIMAP_SIZE, MARGIN)


## How big that column is.
static func map_column_size() -> Vector2:
	return Vector2(MINIMAP_SIZE, MAP_TOP + MAP_COLUMN_BELOW_MAP_TOP)


## The box of the location, at the top of the column: as wide as the minimap.
static func location_size() -> Vector2:
	return Vector2(MINIMAP_SIZE, LOCATION_HEIGHT)


## Where the minimap stands in the column.
static func map_in_column() -> Vector2:
	return Vector2(0.0, MAP_TOP)


## Where the clock stands in the column (its chips against the right edge).
static func clock_in_column() -> Vector2:
	return Vector2(0.0, MAP_TOP + MINIMAP_SIZE + CLOCK_BELOW_MAP)


## Where the chip of the marker stands in the column.
static func waypoint_in_column() -> Vector2:
	return clock_in_column() + Vector2(0.0, WAYPOINT_BELOW_CLOCK)


static func tracker_position(area: Vector2) -> Vector2:
	return Vector2(area.x - MARGIN - TRACKER_WIDTH, TRACKER_BELOW_MAP_TOP + MAP_TOP)


## The money panel (`panel_size`) in the bottom right corner.
static func money_position(area: Vector2, panel_size: Vector2) -> Vector2:
	return area - Vector2(MARGIN, BOTTOM_MARGIN) - panel_size


## The action prompts (`prompts_size`) in the bottom left corner.
static func actions_position(area: Vector2, prompts_size: Vector2) -> Vector2:
	return Vector2(MARGIN, area.y - BOTTOM_MARGIN - prompts_size.y)
