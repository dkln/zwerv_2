extends RefCounted
## Routes over a graph of cells: every cell (Vector3i) a point, linked one way to the cells
## one can go on to from it (`links`: cell -> Array of cells). The shortest way between two
## cells (AStar3D, each step weighed by its length), a way to a place some cells off, the
## cell of the graph nearest a cell outside it.
##
## Knows nothing of the town: who builds the links decides what a link is (Pedestrians: the
## pavements, the zebras, the stairs; a road could be the same, cell and heading by heading).
## So it is tested on its own with small hand-made graphs (tests/unit/pathfinding).
##   const CellRoutes = preload("res://scripts/pathfinding/cell_routes.gd")
##   var routes := CellRoutes.new(links)
##   var way := routes.route(from, to)

var _finder := AStar3D.new()
var _ids := {}                 # cell -> its point in _finder


## `links`: cell -> Array of the cells one can go on to from it (one way; a link back is a
## link of its own). A cell only linked to, without links of its own, is no cell of the graph.
func _init(links: Dictionary = {}) -> void:
	for cell: Vector3i in links:
		var id := _ids.size()
		_ids[cell] = id
		_finder.add_point(id, Vector3(cell))
	for cell: Vector3i in links:
		for next: Vector3i in links[cell]:
			if _ids.has(next):
				_finder.connect_points(int(_ids[cell]), int(_ids[next]), false)


## True if `cell` is a cell of the graph.
func has_cell(cell: Vector3i) -> bool:
	return _ids.has(cell)


## How many cells the graph has.
func size() -> int:
	return _ids.size()


## The cells to go from `from` to `to`, without `from`, ending at `to` (or at the cell of the
## graph nearest it: nearest); empty when there is no way, or `from` is no cell of the graph.
## The cells of `avoid` are kept out of this one way (not `from` and not the goal).
func route(from: Vector3i, to: Vector3i, avoid: Array = []) -> Array[Vector3i]:
	var way: Array[Vector3i] = []
	if not _ids.has(from):
		return way
	var goal := to if _ids.has(to) else nearest(to, _ids.keys())
	if not _ids.has(goal):
		return way
	var left_out: Array[int] = []
	for cell: Vector3i in avoid:
		if _ids.has(cell) and cell != from and cell != goal:
			left_out.append(int(_ids[cell]))
			_finder.set_point_disabled(int(_ids[cell]), true)
	way = _path(from, goal)
	for id in left_out:
		_finder.set_point_disabled(id, false)
	if not way.is_empty():
		way.remove_at(0)
	return way


## The cells to go from `from` to a place some cells off: a cell of `candidates` (drawn at
## random by `random`) between `near_far.x` and `near_far.y` cells away as the crow flies
## (along x and z), whose way is at most `longest` cells and every cell of which `accept`
## takes (a Callable(cell) -> bool; an empty one takes all). At most `attempts` draws, and of
## those at most `routes_tried` ways looked for (each one costs). Without `from`; empty when
## no such place was found.
func route_somewhere(from: Vector3i, candidates: Array, random: RandomNumberGenerator,
		near_far: Vector2i, longest: int, attempts: int, accept := Callable(), routes_tried := 3) -> Array[Vector3i]:
	var way: Array[Vector3i] = []
	if not _ids.has(from) or candidates.is_empty():
		return way
	var tried := 0
	for attempt in attempts:
		var goal: Vector3i = candidates[random.randi() % candidates.size()]
		var far := maxi(absi(goal.x - from.x), absi(goal.z - from.z))
		if far < near_far.x or far > near_far.y or not _ids.has(goal):
			continue
		tried += 1
		if tried > routes_tried:
			break
		way = _path(from, goal)
		# (a way far round, over a bridge at the other end of town, is no walk: another place)
		if way.size() > 1 and way.size() <= longest:
			way.remove_at(0)
			if accept.is_valid() and not way.all(accept):
				way.clear()
				continue
			return way
		way.clear()
	return way


## The cell of `among` nearest `cell` along x and z that is a cell of the graph (`cell` itself
## when it is one; the first of `among` on a tie); `cell` when there is none.
func nearest(cell: Vector3i, among: Array) -> Vector3i:
	if _ids.has(cell):
		return cell
	var best := cell
	var best_distance := INF
	for other: Vector3i in among:
		var distance := Vector2(other.x - cell.x, other.z - cell.z).length_squared()
		if distance < best_distance and _ids.has(other):
			best = other
			best_distance = distance
	return best


## The cells of the shortest way from `from` to `to`, both included (both in the graph).
func _path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var way: Array[Vector3i] = []
	for point in _finder.get_point_path(int(_ids[from]), int(_ids[to])):
		way.append(Vector3i(roundi(point.x), roundi(point.y), roundi(point.z)))
	return way
