extends RefCounted
## The sizes of the one panel bottom left of a machine's close-up (the layout of
## scripts/ui/machines/machine_info_view.gd, which builds it; part of the screen of
## scripts/ui/machines/machine_screen.gd): what came out of the machine over what you carry.
## Its width, its distance from the left and the bottom (over the key hints), its margins
## and the room between its lines; it grows upwards with what is in it. Constants and plain
## functions, without nodes.
##   const MachineInfoLayout = preload("res://scripts/ui/machines/machine_info_layout.gd")

const WIDTH := 260.0
## How far from the left and from the bottom of the design the panel stands.
const MARGIN := Vector2(32, 44)
const BORDER := 3
## The room between the edge of the panel and what is in it (sides; top and bottom).
const PADDING := Vector2(14, 12)
## The room between the tray, the line and the pockets, and between the lines of each.
const SECTION_SEPARATION := 8
const LINE_SEPARATION := 4
## The line between the tray and the pockets: how thick.
const RULE_HEIGHT := 2.0
## What came out slides into the tray from this far above its place (px).
const TRAY_SLIDE_FROM := -40.0


## The left and right edge of the panel (px from the left of the design).
static func sides() -> Vector2:
	return Vector2(MARGIN.x, MARGIN.x + WIDTH)


## The bottom of the panel (px from the bottom of the design, negative: above it); it grows
## upwards from there.
static func bottom() -> float:
	return -MARGIN.y
