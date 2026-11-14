extends RefCounted
## The rules of the minimap of the HUD (logic; docs/CODE_LAGEN.md): which kind of ground a
## tile is, what the picture of the town is (one pixel per cell: the kind of the top tile
## at street level, a building over it), where the corner of that picture lies in the
## world, how many metres the minimap shows across, and where the map and a mark land on
## it. Used by minimap.gd; the colours of the kinds: map_look.gd.
##   const MinimapRules = preload("res://scripts/ui/hud/minimap_rules.gd")

## Folder of a Grond tile (the start of its library name) -> kind of ground on the minimap.
const KINDS := {
	"weg": "road", "snelweg": "road", "bocht": "road", "parkeren": "road", "tunnel": "road", "brug": "road",
	"fietspad": "cycle_path", "water": "water", "zwembad": "water", "natuur": "grass", "heuvel": "grass",
	"stoep": "pavement", "plein": "pavement", "spoor": "rail", "tram": "rail", "waterkant": "pavement",
}
## The kind of a tile of no known folder, and of a cell with a building on it.
const DEFAULT_KIND := "land"
const BUILDING_KIND := "building"
## Cells higher than this are not on the map (the deck of a bridge, a roof).
const STREET_LEVEL := 0
## Inside a building the minimap shows its floor plan, a little wider than the plan
## (INTERIOR_MARGIN) and at least this many metres across (a snack bar would be a speck).
const INTERIOR_MIN_METRES := 28.0
const INTERIOR_MARGIN := 1.1
## Inside a building a quest place within this many metres is in it and marked on its plan
## (the cans of mission 1 in the station); farther off it is in the town and left out.
const INDOOR_TARGET_REACH := 150.0
## A heading shorter than this (squared) is none: the arrow keeps the way it pointed.
const SHORTEST_HEADING_SQUARED := 0.0001


## The kind of ground of the tile named `item_name` ("weg/asfalt" -> "road").
static func kind_of(item_name: String) -> String:
	var folder := item_name.get_slice("/", 0)
	if item_name.contains("gras") or item_name.contains("park"):
		return "grass"
	if folder == "natuur" and (item_name.contains("pad") or item_name.contains("grind")):
		return "pavement"
	return KINDS.get(folder, DEFAULT_KIND)


## Per column (Vector2i x, z) of `cells` (Vector3i each) its highest cell at street level
## or below: the tile the map shows there.
static func top_cells(cells: Array) -> Dictionary:
	var top := {}
	for cell: Vector3i in cells:
		if cell.y > STREET_LEVEL:
			continue
		var column := Vector2i(cell.x, cell.z)
		if not top.has(column) or cell.y > top[column].y:
			top[column] = cell
	return top


## The part of the grid `columns` (Vector2i each) cover: its lowest column and its size in
## cells; nothing (a size of zero) without columns.
static func bounds(columns: Array) -> Rect2i:
	if columns.is_empty():
		return Rect2i()
	var lowest := Vector2i(1 << 30, 1 << 30)
	var highest := -lowest
	for column: Vector2i in columns:
		lowest = Vector2i(mini(lowest.x, column.x), mini(lowest.y, column.y))
		highest = Vector2i(maxi(highest.x, column.x), maxi(highest.y, column.y))
	return Rect2i(lowest, highest - lowest + Vector2i.ONE)


## The picture of the town as plain data: per pixel (Vector2i, from the corner of
## `map_bounds`) its kind. `kind_of_column`: column -> kind of its ground; a column of
## `building_cells` (Vector3i each) inside the bounds is a building, whatever lies under it.
static func pixel_kinds(kind_of_column: Dictionary, building_cells: Array, map_bounds: Rect2i) -> Dictionary:
	var kinds := {}
	for column: Vector2i in kind_of_column:
		kinds[column - map_bounds.position] = kind_of_column[column]
	for cell: Vector3i in building_cells:
		var pixel := Vector2i(cell.x, cell.z) - map_bounds.position
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < map_bounds.size.x and pixel.y < map_bounds.size.y:
			kinds[pixel] = BUILDING_KIND
	return kinds


## World x, z of the corner of the map picture: cell (x, z) spans x * cell .. x * cell +
## cell (the GridMap centres its tiles in their cells), from where the GridMap stands.
static func origin(lowest: Vector2i, cell_metres: float, ground_at: Vector2) -> Vector2:
	return Vector2(lowest) * cell_metres + ground_at


## The pixels (Vector2i each, row by row) of a map picture of `size` whose cell the story
## has not opened: `is_open_cell` is asked per cell (x, y from `lowest`, the cell of the
## first pixel).
static func shrouded_pixels(size: Vector2i, lowest: Vector2i, is_open_cell: Callable) -> Array:
	var hidden := []
	for row in size.y:
		for column in size.x:
			if not is_open_cell.call(column + lowest.x, row + lowest.y):
				hidden.append(Vector2i(column, row))
	return hidden


## How many metres the minimap shows across: `metres`, or `metres_now` when that is set
## (inside a building).
static func metres_across(metres_now: float, metres: float) -> float:
	return metres_now if metres_now > 0.0 else metres


## How many metres the minimap shows across inside a building whose floor plan is
## `extent` metres: a little more than its longer side, at least INTERIOR_MIN_METRES and
## at most `most` (what it shows of the town).
static func interior_metres(extent: Vector2, most: float) -> float:
	return clampf(maxf(extent.x, extent.y) * INTERIOR_MARGIN, INTERIOR_MIN_METRES, most)


## Pixels of the minimap per metre of the world.
static func pixels_per_metre(map_pixels: float, metres_shown: float) -> float:
	return map_pixels / metres_shown


## How big the map picture (`texture_size` pixels, `metres_per_pixel` each) is drawn.
static func map_size(texture_size: Vector2, pixels_for_a_metre: float, metres_per_pixel: float) -> Vector2:
	return texture_size * (pixels_for_a_metre * metres_per_pixel)


## Where the corner of the map picture is drawn so that `focus` (world x, z) is at `centre`.
static func map_position(centre: Vector2, focus: Vector2, map_origin: Vector2, pixels_for_a_metre: float) -> Vector2:
	return centre - (focus - map_origin) * pixels_for_a_metre


## Where `target` (world x, z) lands on the minimap while `focus` is at `centre`.
static func mark_position(centre: Vector2, focus: Vector2, target: Vector2, pixels_for_a_metre: float) -> Vector2:
	return centre + (target - focus) * pixels_for_a_metre


## A point of the world on the ground plane: its x and z.
static func flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## Whether `heading` (x, z) is a way to point the arrow.
static func has_heading(heading: Vector2) -> bool:
	return heading.length_squared() > SHORTEST_HEADING_SQUARED


## How far the arrow (up = north = -z) is turned to point along `heading` (x, z).
static func arrow_rotation(heading: Vector2) -> float:
	return atan2(heading.x, -heading.y)


## Whether a quest place is marked: outside when the story has opened it (`shrouded`: not
## yet); inside a building only a place in the building itself (`distance` metres off).
static func is_target_marked(indoors: bool, distance: float, shrouded: bool) -> bool:
	if indoors:
		return distance <= INDOOR_TARGET_REACH
	return not shrouded


## Whether the marker set on the map (`at`, Vector2.INF: none) is marked: not while the
## minimap shows the floor plan of a building.
static func is_waypoint_marked(at: Vector2, indoors: bool) -> bool:
	return at != Vector2.INF and not indoors
