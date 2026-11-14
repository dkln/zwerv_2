extends RefCounted
## The sizes of the minimap of the HUD (layout; docs/CODE_LAGEN.md): a square frame with a
## border, the map inside it, the player in its middle and the N of north at the top.
## Where the minimap stands in the HUD: hud_layout.gd. Built by minimap_view.gd.
##   const MinimapLayout = preload("res://scripts/ui/hud/minimap_layout.gd")

const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")
## The frame: a square this big with a border this wide.
const SIZE := HudLayout.MINIMAP_SIZE
const BORDER := 3
## Where the N of north stands in the frame.
const NORTH_POSITION := Vector2(90.0, 4.0)


## The frame of the minimap.
static func frame_size() -> Vector2:
	return Vector2(SIZE, SIZE)


## The map inside the border of the frame: where it starts and how big it is.
static func map_rect() -> Rect2:
	return Rect2(Vector2.ONE * BORDER, Vector2.ONE * (SIZE - 2.0 * BORDER))


## The middle of the map (in its own pixels): where the player stands.
static func centre() -> Vector2:
	return map_rect().size * 0.5
