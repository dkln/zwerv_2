extends RefCounted
## The rules of the shroud (logic; docs/CODE_LAGEN.md): the shapes of the open areas and
## whether a point lies in one of them. The areas are data/gebieden.json (see shroud.gd,
## which keeps what is open): circles round places of the map, wijken and rectangles of
## cells of CELL metres.
##   const ShroudRules = preload("res://scripts/story/shroud_rules.gd")

## Metres of one cell of the map.
const CELL := 4.0
## The radius of a circle of an area that names none.
const AREA_CIRCLE_RADIUS := 30.0


## The rectangle (world metres) of the cells x0, z0 up to and including x1, z1.
static func cells_rect(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	return Rect2(x0 * CELL, z0 * CELL, (x1 - x0 + 1.0) * CELL, (z1 - z0 + 1.0) * CELL)


## The wijken of the city (its "wijken" metadata: [name, x0, z0, x1, z1] in cells) as
## name -> Rect2 in world metres.
static func wijk_rects(wijken: Array) -> Dictionary:
	var rects := {}
	for entry: Array in wijken:
		rects[str(entry[0])] = cells_rect(float(entry[1]), float(entry[2]), float(entry[3]), float(entry[4]))
	return rects


## The whole map: the rectangle round every rectangle of `rects` (an empty one for none).
static func map_rect(rects: Array) -> Rect2:
	var whole := Rect2()
	for rect: Rect2 in rects:
		whole = whole.merge(rect) if whole.has_area() else rect
	return whole


## The start circle of the data (data/gebieden.json "start"): {"centre" (world x, z; INF
## when its place "midden" is not on the map), "place" (that key), "radius"}.
static func start_circle(data: Dictionary, places: Dictionary, fallback_radius: float) -> Dictionary:
	var start: Dictionary = data.get("start", {})
	var place_key := str(start.get("midden", ""))
	return {"centre": places.get(place_key, Vector2.INF), "place": place_key,
		"radius": float(start.get("straal", fallback_radius))}


## The shapes of one area of the data: {"circles": [[centre, radius], ...], "rects":
## [Rect2, ...], "missing": [names of wijken that are not on the map]}. A circle round a
## place that is not on the map is left out.
static func area_shapes(area: Dictionary, places: Dictionary, wijken: Dictionary) -> Dictionary:
	var circles: Array = []
	var rects: Array[Rect2] = []
	var missing: Array[String] = []
	for circle: Dictionary in area.get("cirkels", []):
		var centre: Vector2 = places.get(str(circle.get("midden", "")), Vector2.INF)
		if centre != Vector2.INF:
			circles.append([centre, float(circle.get("straal", AREA_CIRCLE_RADIUS))])
	for wijk_name in area.get("wijken", []):
		if wijken.has(str(wijk_name)):
			rects.append(wijken[str(wijk_name)])
		else:
			missing.append(str(wijk_name))
	for cells: Array in area.get("rechthoeken", []):
		rects.append(cells_rect(float(cells[0]), float(cells[1]), float(cells[2]), float(cells[3])))
	return {"circles": circles, "rects": rects, "missing": missing}


## Whether the start circle grows when asked to be `radius` (it never shrinks).
static func grows(radius: float, current_radius: float) -> bool:
	return radius > current_radius + 0.01


## The radius the start circle needs to take in `spot` (world x, z) with the margin.
static func radius_to(start_centre: Vector2, spot: Vector2, margin: float) -> float:
	return start_centre.distance_to(spot) + margin


## Whether `point` (world x, z) is open: off the map (the interiors far off it), in the
## start circle, in one of `circles` ([centre, radius]) or in one of `rects`.
static func is_open(point: Vector2, whole_map: Rect2, start_centre: Vector2, start_radius: float, circles: Array, rects: Array) -> bool:
	if not whole_map.has_point(point):
		return true
	if start_centre.distance_squared_to(point) <= start_radius * start_radius:
		return true
	for circle: Array in circles:
		if (circle[0] as Vector2).distance_squared_to(point) <= float(circle[1]) * float(circle[1]):
			return true
	for rect: Rect2 in rects:
		if rect.has_point(point):
			return true
	return false


## The middle (world x, z) of a cell of the map.
static func cell_middle(cell_x: int, cell_z: int) -> Vector2:
	return Vector2((cell_x + 0.5) * CELL, (cell_z + 0.5) * CELL)
