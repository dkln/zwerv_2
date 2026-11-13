extends RefCounted
## The shroud: where the player may go. What is not open is hidden on the map and the
## minimap and cannot be walked into (PlayerController asks is_open before every step).
## The areas are in data/gebieden.json:
## - "start": a circle round a place of the map ("midden", a key of the city's "places"
##   metadata) with a radius in metres ("straal"); a mission can let it grow (grow_to).
## - "gebieden": named areas a mission opens ("opent"), each made of "cirkels" (as the
##   start), "wijken" (names of the city's "wijken" metadata: [name, x0, z0, x1, z1] in cells
##   of 4 m) and/or "rechthoeken" ([x0, z0, x1, z1] in cells).
## Story owns one (Story.shroud) and says when it changed (Story.shroud_changed).

const AREAS_FILE := "res://data/gebieden.json"
const CELL := 4.0

var start_centre := Vector2.INF   # world x, z of the start circle
var start_radius := 0.0
## Metres added round a place a circle grows to (grow_to), so you can walk up to it.
var margin := 20.0
var open_names: Array[String] = []
## Open shapes: circles [Vector2 centre, radius] and rectangles (Rect2 in world metres).
var _circles: Array = []
var _rects: Array[Rect2] = []
var _areas := {}
var _places := {}
var _wijken := {}
## The whole map (world metres): outside it (the interiors far off the map) nothing is shrouded.
var _map_rect := Rect2()
var enabled := true


## Reads data/gebieden.json with the places and the wijken of the city (`root`: the city's
## root node, its "places" and "wijken" metadata).
func setup(root: Node) -> void:
	_places = root.get_meta("places", {}) if root else {}
	for entry: Array in (root.get_meta("wijken", []) if root else []):
		_wijken[str(entry[0])] = Rect2(float(entry[1]) * CELL, float(entry[2]) * CELL,
			(float(entry[3]) - float(entry[1]) + 1.0) * CELL, (float(entry[4]) - float(entry[2]) + 1.0) * CELL)
		_map_rect = _map_rect.merge(_wijken[str(entry[0])]) if _map_rect.has_area() else _wijken[str(entry[0])]
	if _places.is_empty():
		enabled = false   # no map (a test without the town): nothing to shroud
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(AREAS_FILE))
	if not data is Dictionary:
		push_error("shroud: %s is no valid JSON" % AREAS_FILE)
		enabled = false
		return
	var start: Dictionary = data.get("start", {})
	start_centre = place(str(start.get("midden", "")))
	start_radius = float(start.get("straal", 50.0))
	margin = float(data.get("marge", margin))
	_areas = data.get("gebieden", {})
	if start_centre == Vector2.INF:
		push_error("shroud: the start place %s is not on the map" % str(start.get("midden", "")))
		enabled = false


## A named place of the map (world x, z), INF when there is none.
func place(key: String) -> Vector2:
	return _places.get(key, Vector2.INF)


## Whether the area `name` of data/gebieden.json exists.
func has_area(name: String) -> bool:
	return _areas.has(name)


## Opens the area `name`; false when it was open already or does not exist.
func open_area(name: String) -> bool:
	if open_names.has(name) or not _areas.has(name):
		if not _areas.has(name):
			push_error("shroud: no area \"%s\" in %s" % [name, AREAS_FILE])
		return false
	open_names.append(name)
	var area: Dictionary = _areas[name]
	for circle: Dictionary in area.get("cirkels", []):
		var centre := place(str(circle.get("midden", "")))
		if centre != Vector2.INF:
			_circles.append([centre, float(circle.get("straal", 30.0))])
	for wijk_name in area.get("wijken", []):
		if _wijken.has(str(wijk_name)):
			_rects.append(_wijken[str(wijk_name)])
		else:
			push_error("shroud: no wijk \"%s\" on the map (area %s)" % [wijk_name, name])
	for cells: Array in area.get("rechthoeken", []):
		_rects.append(Rect2(float(cells[0]) * CELL, float(cells[1]) * CELL,
			(float(cells[2]) - float(cells[0]) + 1.0) * CELL, (float(cells[3]) - float(cells[1]) + 1.0) * CELL))
	return true


## The start circle as big as `radius` (it never shrinks).
func set_start_radius(radius: float) -> bool:
	if radius <= start_radius + 0.01:
		return false
	start_radius = radius
	return true


## The radius the start circle needs to take in `spot` (world x, z) with the margin.
func radius_to(spot: Vector2) -> float:
	return start_centre.distance_to(spot) + margin


## Whether the world point (x, z) may be walked on and is shown on the maps.
func is_open(x: float, z: float) -> bool:
	if not enabled:
		return true
	var point := Vector2(x, z)
	if not _map_rect.has_point(point):
		return true
	if start_centre.distance_squared_to(point) <= start_radius * start_radius:
		return true
	for circle: Array in _circles:
		if (circle[0] as Vector2).distance_squared_to(point) <= float(circle[1]) * float(circle[1]):
			return true
	for rect in _rects:
		if rect.has_point(point):
			return true
	return false


## Whether the map cell (cells of 4 m) is open: its middle is.
func is_open_cell(cell_x: int, cell_z: int) -> bool:
	return is_open((cell_x + 0.5) * CELL, (cell_z + 0.5) * CELL)


## Everything open (tests and tools that want the whole town).
func open_everything() -> void:
	enabled = false


## The state to keep and to put back (TownWorld.reset in the tests).
func snapshot() -> Dictionary:
	return {"radius": start_radius, "open": open_names.duplicate(), "enabled": enabled}


func restore(state: Dictionary) -> void:
	start_radius = float(state.get("radius", start_radius))
	enabled = bool(state.get("enabled", true))
	open_names.clear()
	_circles.clear()
	_rects.clear()
	for name in state.get("open", []):
		open_area(str(name))
