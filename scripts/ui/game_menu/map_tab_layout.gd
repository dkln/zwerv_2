extends RefCounted
## The sizes and places of the KAART tab of the game menu (layout; docs/CODE_LAGEN.md):
## how the map picture fits its frame, where a point of the town lies on it and back, where
## the north sign and the coordinates stand, and the sizes of the marks. Built with these by
## map_tab_view.gd; map_tab.gd is the behaviour, map_tab_rules.gd the logic.
##   const MapTabLayout = preload("res://scripts/ui/game_menu/map_tab_layout.gd")

## The column beside the map (the chosen place, where you are, the legend).
const SIDE_WIDTH := 296.0
## How much wider than the side column the map's frame stretches.
const MAP_STRETCH := 3.0
const FRAME_SHADOW := 6.0
## The north sign, top right: its size and how far it stands from the edges.
const NORTH_SIZE := 36.0
const NORTH_MARGIN := Vector2(12.0, 10.0)
## The coordinates, bottom left: how far they stand from the edges.
const COORDINATES_MARGIN := Vector2(12.0, 10.0)
## Screen pixels (design) within which a click picks a marker.
const MARKER_PICK_RADIUS := 14.0
## Half the size of the mark of a place, of its dark rim, and the same for the chosen place
## with its white ring.
const PLACE_HALF := 3.0
const PLACE_RIM_HALF := 5.0
const CHOSEN_PLACE_HALF := 5.0
const CHOSEN_PLACE_RIM_HALF := 8.0
const CHOSEN_PLACE_RING_HALF := 11.0
## Half the size of the mark of a supermarket, and of the chosen one.
const SUPERMARKET_HALF := 5.5
const CHOSEN_SUPERMARKET_HALF := 8.0
## Half the size of the mark of a cash machine (upright), and how much larger the chosen one is.
const CASH_MACHINE_HALF := Vector2(4.0, 5.0)
const CHOSEN_CASH_MACHINE_SCALE := 1.5
## The ring round a place a mission marked, the marker you set and a place of the followed quest.
const STORY_RING_RADIUS := 11.0
const WAYPOINT_HALF := 9.0
const TARGET_HALF := 8.0
## The names of the neighbourhoods on the map.
const AREA_FONT_SIZE := 10
## The squares of the legend.
const LEGEND_SQUARE := 10.0


## How the map picture (`texture_size`) fits its frame (`area`): as large as fits, centred.
## {"scale": screen pixels per pixel of the picture, "offset": its top left corner}.
static func fit(area: Vector2, texture_size: Vector2) -> Dictionary:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return {"scale": 1.0, "offset": Vector2.ZERO}
	var scale := minf(area.x / texture_size.x, area.y / texture_size.y)
	return {"scale": scale, "offset": ((area - texture_size * scale) * 0.5).floor()}


## The point of the map (in its frame) of a spot of the town (world x, z): the picture starts
## at `origin` (world), a pixel of it is `metres_per_pixel`, drawn at `scale` from `offset`.
static func world_to_map(world: Vector2, origin: Vector2, metres_per_pixel: float, scale: float, offset: Vector2) -> Vector2:
	return offset + (world - origin) / metres_per_pixel * scale


## The spot of the town (world x, z) under a point of the map: world_to_map the other way.
static func map_to_world(map_point: Vector2, origin: Vector2, metres_per_pixel: float, scale: float, offset: Vector2) -> Vector2:
	return origin + (map_point - offset) / scale * metres_per_pixel


## Where the north sign stands in a frame of size `area`.
static func north_position(area: Vector2) -> Vector2:
	return Vector2(area.x - NORTH_MARGIN.x - NORTH_SIZE, NORTH_MARGIN.y)


## Where the coordinates (a box `box_height` high) stand in a frame of size `area`.
static func coordinates_position(area: Vector2, box_height: float) -> Vector2:
	return Vector2(COORDINATES_MARGIN.x, area.y - COORDINATES_MARGIN.y - box_height)


## The pixels of the map picture (`pixels` in all) a stretch of the town covers, from
## `from_world` to `to_world` (world x, z); an empty rect when it lies off the picture.
static func pixel_rect(from_world: Vector2, to_world: Vector2, origin: Vector2, metres_per_pixel: float, pixels: Vector2i) -> Rect2i:
	var from_pixel := ((from_world - origin) / metres_per_pixel).round()
	var to_pixel := ((to_world - origin) / metres_per_pixel).round()
	return Rect2i(Vector2i(from_pixel), Vector2i(to_pixel - from_pixel)).intersection(Rect2i(Vector2i.ZERO, pixels))


## Where the name of a neighbourhood starts so that it stands centred on `centre` (a point
## of the map): half its width to the left, a little down.
static func area_label_position(centre: Vector2, text_width: float) -> Vector2:
	return centre - Vector2(text_width * 0.5, -4.0)
