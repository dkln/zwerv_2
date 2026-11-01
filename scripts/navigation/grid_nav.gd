class_name GridNav
extends RefCounted
## Navigation for characters on a GridMap world, on a navigation map of its own:
## bakes a navigation mesh from the collision shapes of GridMap cells within an area,
## answers path queries, and adds jump and drop links (navigation links) where the
## navigation mesh has a gap the character can bridge: a ledge up to `max_up` higher, a
## drop up to `max_down`, or a low obstacle in between.
##
##   var nav := GridNav.new(1.8, 0.25, 0.25)
##   nav.bake(GridNav.collect_source([ground, buildings], area), area)
##   await nav.baked
##   ... once nav.is_ready(): nav.add_jump_links(space, ...), nav.path(a, b)
##   nav.free_map() when done.
##
## Units are metres; the navigation mesh voxel is `cell` (default one tile voxel).

## The navigation mesh has been baked and handed to the navigation map.
signal baked

## Navigation mesh voxel (metres) and the agent it is baked for.
var cell := 0.125
var agent_height := 1.8
var agent_radius := 0.25
var max_climb := 0.25
var max_slope := 46.0
## Extra cost of a jump or drop link over walking the same distance.
var link_cost := 3.0

var navmesh: NavigationMesh
var map := RID()
var region := RID()
## Links made by add_jump_links: [{from, to, bidirectional, rid}].
var links: Array[Dictionary] = []
## Baking time in milliseconds and number of source triangles.
var bake_ms := 0.0
var source_triangles := 0


func _init(height := 1.8, radius := 0.25, climb := 0.25, voxel := 0.125) -> void:
	agent_height = height
	agent_radius = radius
	max_climb = climb
	cell = voxel


## Source geometry for bake(): the collision shapes (concave and box) of all cells of
## `maps` whose centre lies within `area` (grown by one cell). `skip` (optional):
## func(gm: GridMap, item_name: String) -> bool, true = leave that cell out.
static func collect_source(maps: Array, area: AABB, skip := Callable()) -> NavigationMeshSourceGeometryData3D:
	var source := NavigationMeshSourceGeometryData3D.new()
	for gm: GridMap in maps:
		if gm == null or gm.mesh_library == null:
			continue
		var lib := gm.mesh_library
		var grown := area.grow(maxf(gm.cell_size.x, gm.cell_size.y))
		var faces := {}   # item -> [[faces, shape transform], ...]
		for c in gm.get_used_cells():
			var local := gm.map_to_local(c)
			if not grown.has_point(gm.to_global(local)):
				continue
			var item := gm.get_cell_item(c)
			if skip.is_valid() and skip.call(gm, lib.get_item_name(item)):
				continue
			if not faces.has(item):
				faces[item] = item_faces(lib, item)
			var xform := gm.global_transform * Transform3D(gm.get_cell_item_basis(c), local)
			for f in faces[item]:
				source.add_faces(f[0], xform * f[1])
	return source


## Triangles of the collision shapes of MeshLibrary `item`: [[PackedVector3Array,
## shape Transform3D], ...]. Concave shapes and boxes; other shapes are skipped.
static func item_faces(lib: MeshLibrary, item: int) -> Array:
	var out := []
	var shapes := lib.get_item_shapes(item)
	for i in range(0, shapes.size(), 2):
		var shape = shapes[i]
		var faces := PackedVector3Array()
		if shape is ConcavePolygonShape3D:
			faces = shape.get_faces()
		elif shape is BoxShape3D:
			var box := BoxMesh.new()
			box.size = shape.size
			faces = box.get_faces()
		if not faces.is_empty():
			out.append([faces, shapes[i + 1]])
	return out


## Bakes the navigation mesh of `source` within `area` in the background and puts it on
## a new navigation map. Emits `baked` when done (on the main thread).
func bake(source: NavigationMeshSourceGeometryData3D, area: AABB) -> void:
	var started := Time.get_ticks_usec()
	source_triangles = source.get_vertices().size() / 9   # x, y, z per corner
	navmesh = NavigationMesh.new()
	navmesh.cell_size = cell
	navmesh.cell_height = cell
	# whole voxels, so nothing is rounded (the bake warns otherwise)
	navmesh.agent_height = ceilf(agent_height / cell) * cell
	navmesh.agent_max_climb = floorf(max_climb / cell) * cell
	navmesh.agent_radius = agent_radius
	navmesh.agent_max_slope = max_slope
	navmesh.filter_baking_aabb = area
	NavigationServer3D.bake_from_source_geometry_data_async(navmesh, source, func() -> void:
		_on_baked.call_deferred(started))


func _on_baked(started: int) -> void:
	bake_ms = (Time.get_ticks_usec() - started) / 1000.0
	map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, cell)
	NavigationServer3D.map_set_cell_height(map, cell)
	NavigationServer3D.map_set_active(map, true)
	region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, navmesh)
	baked.emit()


## The map holds the baked navigation mesh and answers queries (the navigation server
## takes a region in asynchronously, a frame or so after baking).
func is_ready() -> bool:
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var verts := navmesh.get_vertices()
	return not verts.is_empty() and NavigationServer3D.map_get_closest_point_owner(map, verts[0]) == region


## Frees the navigation map, its region and links.
func free_map() -> void:
	for l in links:
		NavigationServer3D.free_rid(l.rid)
	links.clear()
	if region.is_valid():
		NavigationServer3D.free_rid(region)
	if map.is_valid():
		NavigationServer3D.free_rid(map)
	region = RID()
	map = RID()


## Closest point on the navigation mesh (or a link) to `p`.
func closest(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(map, p)


## Navigation mesh points in the vertical column at `at` (x, z) between at.y and
## at.y + `height`, lowest first (one per floor: a tunnel floor and the street on its
## roof, a bridge deck and a ledge under it, ...).
func points_in_column(at: Vector3, height: float, radius := 2.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var h := 0.25
	while h <= height + 0.5:
		var p := closest(at + Vector3.UP * h)
		var flat := Vector2(p.x - at.x, p.z - at.z).length()
		var known := false
		for q in out:
			known = known or q.distance_to(p) < 0.5
		if flat < radius and p.y >= at.y - 0.25 and p.y <= at.y + height + 0.5 and not known:
			out.append(p)
		h += 0.5
	var sorted := Array(out)
	sorted.sort_custom(func(x: Vector3, y: Vector3) -> bool: return x.y < y.y)
	return PackedVector3Array(sorted)


## The lowest navigation mesh point in the vertical column at `at` (see
## points_in_column) that can be walked to from `from` (any one if `from` is INF or
## none can): the floor of a tunnel rather than the street on its roof, the deck of a
## bridge rather than the street under it. Falls back to closest().
func lowest_in_column(at: Vector3, height: float, from := Vector3.INF) -> Vector3:
	var points := points_in_column(at, height)
	if points.is_empty():
		return closest(at + Vector3.UP * 0.5)
	if from != Vector3.INF:
		for p in points:
			if walk_distance(from, p) < INF:
				return p
	return points[0]


## Path from `from` to `to` (both snapped to the map): {"points": PackedVector3Array,
## "links": PackedInt32Array of indices i where points[i] -> points[i + 1] is a jump or
## drop link, "complete": the path reaches `to`}.
func path(from: Vector3, to: Vector3) -> Dictionary:
	var params := NavigationPathQueryParameters3D.new()
	params.map = map
	params.start_position = from
	params.target_position = to
	params.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_TYPES
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(params, result)
	var points := result.path
	var types := result.path_types
	var on_link := PackedInt32Array()
	for i in range(points.size() - 1):
		# the link's start and end point both carry the link type
		if types[i] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK \
				and types[i + 1] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK:
			on_link.append(i)
	var complete := not points.is_empty() and points[-1].distance_to(closest(to)) < 1.0
	return {"points": points, "links": on_link, "complete": complete}


## Length of the walked path from a to b (INF if they are not connected).
func walk_distance(a: Vector3, b: Vector3) -> float:
	var p := NavigationServer3D.map_get_path(map, a, b, true)
	if p.is_empty() or p[-1].distance_to(b) > 0.5:
		return INF
	var d := 0.0
	for i in range(1, p.size()):
		d += p[i].distance_to(p[i - 1])
	return d


## Adds navigation links over the gaps of the navigation mesh within `area`, sampled
## every `spacing` metres: between points up to two samples apart that are not already
## connected by a short walk, with free head room (`clearance` above the higher one,
## checked with rays in `space` against `mask`):
## - a ledge up to `max_up` higher, or a low obstacle in between: a jump (both ways);
## - a drop of up to `max_down`: one way, down.
## The map must be ready (is_ready()). Returns the number of links added. Links of
## neighbouring samples that do the same are merged (one per `spacing` * 2 metres).
func add_jump_links(space: PhysicsDirectSpaceState3D, area: AABB, max_up := 1.2, max_down := 3.0,
		clearance := 1.0, spacing := 1.0, mask := 1) -> int:
	var samples := _samples(area, spacing)
	var seen := {}
	var added := 0
	var offsets := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(2, 0), Vector2i(0, 2)]
	for key: Vector2i in samples:
		for off: Vector2i in offsets:
			var other: Vector2i = key + off
			if not samples.has(other):
				continue
			for ya: float in samples[key]:
				for yb: float in samples[other]:
					var a := Vector3((key.x + 0.5) * spacing, ya, (key.y + 0.5) * spacing)
					var b := Vector3((other.x + 0.5) * spacing, yb, (other.y + 0.5) * spacing)
					var kind := _gap(space, a, b, max_up, max_down, clearance, mask)
					if kind == "":
						continue
					# one link per stretch of edge and direction
					var mid := (a + b) * 0.5
					var tag := [Vector3i(floori(mid.x / (spacing * 2)), roundi(mid.y), floori(mid.z / (spacing * 2))),
						off, roundi(ya - yb)]
					if seen.has(tag):
						continue
					seen[tag] = true
					var from := a if ya >= yb else b
					var to := b if ya >= yb else a
					_add_link(from, to, kind == "jump")
					added += 1
	return added


## Kind of gap between navmesh points a and b: "jump" (both ways), "drop" (one way,
## down) or "" (no link: too high, already connected, or no head room).
func _gap(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, max_up: float, max_down: float,
		clearance: float, mask: int) -> String:
	var dh := absf(a.y - b.y)
	if dh > max_down:
		return ""
	var low := a if a.y < b.y else b
	var high := b if a.y < b.y else a
	var top := high.y + clearance
	if dh <= max_climb:
		# the same level: only over something (blocked at knee height)
		if not _ray(space, a + Vector3.UP * 0.4, b + Vector3.UP * 0.4, mask):
			return ""
	elif dh > max_up:
		# a drop is walked off: nothing (a railing) in the way at the upper level
		var over := Vector3(low.x, high.y, low.z)
		if _ray(space, high + Vector3.UP * 0.4, over + Vector3.UP * 0.4, mask) \
				or _ray(space, high + Vector3.UP * 1.0, over + Vector3.UP * 1.0, mask):
			return ""
	# head room: straight up from both and across at the top
	if _ray(space, low + Vector3.UP * 0.3, Vector3(low.x, top, low.z), mask) \
			or _ray(space, high + Vector3.UP * 0.3, Vector3(high.x, top, high.z), mask) \
			or _ray(space, Vector3(low.x, top, low.z), Vector3(high.x, top, high.z), mask):
		return ""
	var flat := Vector2(a.x - b.x, a.z - b.z).length()
	if walk_distance(a, b) < maxf(4.0, flat * 3.0):
		return ""
	return "jump" if dh <= max_up else "drop"


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.hit_back_faces = true
	return not space.intersect_ray(q).is_empty()


func _add_link(from: Vector3, to: Vector3, bidirectional: bool) -> void:
	var rid := NavigationServer3D.link_create()
	NavigationServer3D.link_set_map(rid, map)
	NavigationServer3D.link_set_start_position(rid, from)
	NavigationServer3D.link_set_end_position(rid, to)
	NavigationServer3D.link_set_bidirectional(rid, bidirectional)
	NavigationServer3D.link_set_travel_cost(rid, link_cost)
	links.append({"from": from, "to": to, "bidirectional": bidirectional, "rid": rid})


## Navmesh points on a grid of `spacing` metres within `area`: Vector2i(x, z) ->
## [heights] (one per floor at that spot: deck, street under it, ...).
func _samples(area: AABB, spacing: float) -> Dictionary:
	var out := {}
	var verts := navmesh.get_vertices()
	for i in navmesh.get_polygon_count():
		var poly := navmesh.get_polygon(i)
		for j in range(1, poly.size() - 1):
			_sample_triangle(verts[poly[0]], verts[poly[j]], verts[poly[j + 1]], spacing, area, out)
	return out


func _sample_triangle(a: Vector3, b: Vector3, c: Vector3, spacing: float, area: AABB, out: Dictionary) -> void:
	var x0 := floori(minf(a.x, minf(b.x, c.x)) / spacing)
	var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / spacing)
	var z0 := floori(minf(a.z, minf(b.z, c.z)) / spacing)
	var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / spacing)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var p := Vector2((x + 0.5) * spacing, (z + 0.5) * spacing)
			var bc := Geometry2D.point_is_inside_triangle(p, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
			if not bc:
				continue
			var y := _height_in_triangle(p, a, b, c)
			if y < area.position.y or y > area.end.y:
				continue
			var k := Vector2i(x, z)
			if not out.has(k):
				out[k] = []
			var dup := false
			for other: float in out[k]:
				dup = dup or absf(other - y) < 0.5
			if not dup:
				out[k].append(y)


## Height of triangle abc at point p (x, z), by barycentric interpolation.
static func _height_in_triangle(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := p - Vector2(a.x, a.z)
	var d := v0.x * v1.y - v1.x * v0.y
	if absf(d) < 0.000001:
		return a.y
	var u := (v2.x * v1.y - v1.x * v2.y) / d
	var v := (v0.x * v2.y - v2.x * v0.y) / d
	return a.y + u * (b.y - a.y) + v * (c.y - a.y)
