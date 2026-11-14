extends RefCounted
## A way round rectangles on a flat floor (no grid): from a spot to another by the corners of
## the obstacles in the way, each grown by a margin (Station: the hall, round its kiosks,
## pillars and machines). Plain geometry, so tested on its own.
##   const Detour = preload("res://scripts/pathfinding/detour.gd")


## The corners to go by from `from` to `to` (`to` included) so none of `obstacles` (grown by
## `margin`) is in the way; at most `depth` obstacles deep (beyond that straight on).
static func around(from: Vector2, to: Vector2, obstacles: Array, margin: float, depth: int) -> Array[Vector2]:
	var blocking := first_obstacle(from, to, obstacles, margin)
	if blocking == Rect2() or depth <= 0:
		return [to]
	var grown := blocking.grow(margin + 0.1)
	var corners: Array[Vector2] = [grown.position, Vector2(grown.end.x, grown.position.y), grown.end, Vector2(grown.position.x, grown.end.y)]
	var keep_out := blocking.grow(margin)
	var best: Array[Vector2] = []
	var best_length := INF
	for first_index in 4:
		var corner := corners[first_index]
		if hits(from, corner, keep_out):
			continue
		if not hits(corner, to, keep_out):
			var length := from.distance_to(corner) + corner.distance_to(to)
			if length < best_length:
				best_length = length
				best = [corner]
			continue
		# round two corners: the one beside it, either way round
		for step in [-1, 1]:
			var second := corners[(first_index + step + 4) % 4]
			if hits(second, to, keep_out):
				continue
			var length := from.distance_to(corner) + corner.distance_to(second) + second.distance_to(to)
			if length < best_length:
				best_length = length
				best = [corner, second]
	if best.is_empty():
		return [to]
	var points: Array[Vector2] = []
	var here := from
	for corner in best:
		points.append_array(around(here, corner, obstacles, margin, depth - 1))
		here = corner
	points.append_array(around(here, to, obstacles, margin, depth - 1))
	return points


## The obstacle of `obstacles` (grown by `margin`) nearest `from` that the straight line from
## `from` to `to` runs through, one with either end in it left out; Rect2() when none.
static func first_obstacle(from: Vector2, to: Vector2, obstacles: Array, margin: float) -> Rect2:
	var nearest := Rect2()
	var nearest_distance := INF
	for obstacle: Rect2 in obstacles:
		var grown := obstacle.grow(margin)
		if grown.has_point(from) or grown.has_point(to):
			continue
		if hits(from, to, grown):
			var distance := from.distance_to(grown.get_center())
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = obstacle
	return nearest


## True if `at` lies in one of `obstacles` grown by `margin`.
static func inside_any(at: Vector2, obstacles: Array, margin: float) -> bool:
	for obstacle: Rect2 in obstacles:
		if obstacle.grow(margin).has_point(at):
			return true
	return false


## True if the line from `from` to `to` touches `area` (or starts or ends in it).
static func hits(from: Vector2, to: Vector2, area: Rect2) -> bool:
	if area.has_point(from) or area.has_point(to):
		return true
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for index in 4:
		if Geometry2D.segment_intersects_segment(from, to, corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false
