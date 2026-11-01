extends Node3D
## Demo of the character systems (the "Wandelaar" node): a test figure walks over the
## map shown, to check proportions, collision shapes and pathfinding on bridges,
## tunnels, stairs and slopes, and shows a fall and a jump. Purely a demo; the reusable
## parts are GridNav (scripts/navigation/grid_nav.gd: navigation mesh from the GridMap
## collision shapes, paths, jump and drop links), VoxCharacter
## (scripts/characters/vox_character.gd: the walking body, also for the player) and
## PathFollower (scripts/characters/path_follower.gd: steers it along a path, for NPCs).
##
## For the map shown (one map part in the tour, scripts/world_parts.gd) it picks up to
## `max_routes` routes from the Grond layer: groups of neighbouring bridge, tunnel,
## stair, slope, hill or quay cells (CATEGORIES), falling back to the pavement. A route
## runs from a point before the group, through its middle, to a point past it. Each
## route gets a GridNav of the area around it (baked in the background), with jump and
## drop links; after that two demo routes are added: the highest drop and a jump.
## The figure is one static model (prop overig/persoon_1m80, 1.80 m) on a VoxCharacter;
## the numbers (stuck, falls, jumps, ...) show at the bottom left and go to the output.
##
## On its own (`auto`) it walks all routes in turn; the tour (tour.gd) sets `auto` off
## and starts the routes itself (route_slots(), route_info(), walk(), is_done()).
## Keys: N = show the navigation mesh, path and links, C = show the collider.
## rebuild() picks new routes; scripts/world_parts.gd calls it when it loads a part.

## Route kinds in order of preference; item names map to a kind in _category().
const CATEGORIES := ["brug", "tunnel", "trap", "helling", "heuvel", "waterkant", "stoep"]
## Prop used as the figure (1.80 m, front towards +Z like every tile).
const MODEL := "overig/persoon_1m80"
## Metres a route starts before and ends past its group of cells, and the longest
## stretch on either side of its middle.
const LEAD := 6.0
const REACH := 22.0
## Space around a route that is baked into its navigation mesh (metres).
const MARGIN := 12.0
## Jump and drop links: highest ledge to jump up and highest drop (metres).
const JUMP_UP := 1.2
const DROP := 3.0
## Demo routes: metres walked before and after the fall or jump.
const DEMO_LEAD := 5.0
## Extra routes after the max_routes ones: the fall and the jump.
const DEMO_ROUTES := 2

## Walks all routes in turn by itself; off = the tour starts the routes (walk()).
@export var auto := true
## Routes per map (part), besides the fall and jump demos.
@export var max_routes := 5
@export var ground_path := NodePath("../Grond")
## Layers whose collision shapes go into the navigation mesh (besides Grond).
@export var obstacle_paths: Array[NodePath] = [NodePath("../Gebouwen"), NodePath("../Props")]
## Show the navigation mesh, path and links (key N) and the collider (key C).
@export var show_navigation := true
@export var show_collider := true

## The route being walked has finished (or failed).
signal route_finished(index: int)
## All routes of the map have their navigation (and the demo routes are added).
signal routes_ready

## The walking body (VoxCharacter); its position is at the feet.
var body: VoxCharacter
## Horizontal walking direction (unit vector), for the tour's camera.
var facing: Vector3:
	get:
		return body.facing if body else Vector3.FORWARD
## Routes of the map shown: {category, title, cells, a, mid, b, a_top, mid_top, b_top,
## aabb, nav (GridNav), ready, link_ms, demo_link ({from, to} for the demo routes)}.
var routes: Array[Dictionary] = []
## Freezes the figure (the tour's pause).
var paused := false:
	set(value):
		paused = value
		if _follower:
			_follower.paused = value
## Numbers of the current walk (see _summary).
var stats := {}
## Still baking the navigation of the routes (routes_ready follows).
var preparing := false

var _follower: PathFollower
var _visual: MeshInstance3D
var _collider_view: Node3D
var _nav_view: MeshInstance3D
var _path_view: MeshInstance3D
var _label: Label
## Route being walked (-1 = none), and whether it is done.
var _route := -1
var _done := true
var _started := false
## Pause between routes when walking on its own.
var _wait := 0.0
## Bumped by rebuild(), so work for an older map is dropped.
var _generation := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_make_figure()
	_make_views()
	visible = false
	# the layers may be loaded later (tour scene), rebuild() is called then
	if get_node_or_null(ground_path):
		rebuild.call_deferred()


## Number of route slots per map: max_routes plus the fall and jump demos.
func route_slots() -> int:
	return max_routes + DEMO_ROUTES


## Info of route `index` ({} if there is no such route): category, title, text.
func route_info(index: int) -> Dictionary:
	if index < 0 or index >= routes.size():
		return {}
	var r := routes[index]
	return {"category": r.category, "title": r.title, "text": _describe(r)}


## Starts route `index` (waits for its navigation if that is not ready yet). False if
## there is no such route.
func walk(index: int) -> bool:
	if index < 0 or index >= routes.size():
		return false
	_route = index
	_done = false
	_started = false
	stats = {"stuck": 0, "falls": 0, "max_drop": 0.0, "jumps": 0, "low": INF, "high": -INF,
		"max_off_path": 0.0, "time": 0.0, "length": 0.0, "walked": 0.0, "no_path": false, "events": []}
	_follower.stop()
	visible = true
	_update_views()
	return true


## The current route has finished (or there is none).
func is_done() -> bool:
	return _done


## Stops walking (the figure stays where it is).
func stop() -> void:
	_done = true
	_route = -1
	if _follower:
		_follower.stop()


## Picks the routes for the map shown now and prepares their navigation in the background.
func rebuild() -> void:
	_generation += 1
	var freed := {}
	for r in routes:
		if r.nav and not freed.has(r.nav):
			freed[r.nav] = true
			r.nav.free_map()
	routes.clear()
	preparing = false
	stop()
	visible = false
	var gm := get_node_or_null(ground_path) as GridMap
	if gm == null or gm.mesh_library == null or body == null:
		return
	routes = _pick_routes(gm)
	preparing = true
	_prepare(_generation)
	if auto and not routes.is_empty():
		walk(0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_N:
			show_navigation = not show_navigation
		KEY_C:
			show_collider = not show_collider
		_:
			return
	_update_views()
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if body == null or _route < 0 or _done or paused:
		_show_stats()
		return
	var r := routes[_route]
	if not _started:
		if r.ready:
			_start_path(r)
		_show_stats()
		return
	stats.time += delta
	var y := body.global_position.y
	stats.low = minf(stats.low, y)
	stats.high = maxf(stats.high, y)
	var moved := body.get_position_delta()
	stats.walked += Vector2(moved.x, moved.z).length()
	stats.max_off_path = maxf(stats.max_off_path, _follower.distance_from_path())
	if y < r.aabb.position.y - 2.0:
		_event("door de wereld gevallen", body.global_position)
		stats.falls += 1
		_follower.skip_ahead()
	_show_stats()


func _process(delta: float) -> void:
	if auto and _done and not routes.is_empty():
		_wait += delta
		if _wait > 1.5:
			_wait = 0.0
			walk((_route + 1) % routes.size() if _route >= 0 else 0)


# ------------------------------------------------------------------ walking

## Builds the path of route `r` and puts the figure at its start: start -> middle -> end,
## or for a demo route start -> its link -> end.
func _start_path(r: Dictionary) -> void:
	var nav: GridNav = r.nav
	var a := nav.lowest_in_column(r.a, r.a_top)
	var b := nav.lowest_in_column(r.b, r.b_top, a)
	var parts := []
	if r.has("demo_link"):
		var l: Dictionary = r.demo_link
		parts = [nav.path(a, l.from), {"points": PackedVector3Array([l.from, l.to]),
			"links": PackedInt32Array([0]), "complete": true}, nav.path(l.to, b)]
	else:
		var m := nav.lowest_in_column(r.mid, r.mid_top, a)
		parts = [nav.path(a, m), nav.path(m, b)]
		# short of the middle: the bridge, tunnel, ... is not connected to its surroundings
		if not parts[0].complete:
			stats.no_path = true
			var end: PackedVector3Array = parts[0].points
			_event("geen pad naar het midden (%.1f, %.1f, %.1f)" % [m.x, m.y, m.z], end[-1] if not end.is_empty() else a)
		if not parts[1].complete:
			var end: PackedVector3Array = parts[1].points
			_event("eind niet bereikbaar, ingekort", end[-1] if not end.is_empty() else m)
	var path := _join(parts)
	if path.points.size() < 2:
		stats.no_path = true
		path = {"points": PackedVector3Array([a, b]), "links": PackedInt32Array()}
	var pts: PackedVector3Array = path.points
	for i in range(1, pts.size()):
		stats.length += pts[i].distance_to(pts[i - 1])
	body.global_position = pts[0] + Vector3.UP * 0.05
	body.velocity = Vector3.ZERO
	body.facing = PathFollower._flat(pts[1] - pts[0]).normalized()
	_follower.follow(path)
	_started = true
	_update_views()


## Paths ({points, links}) one after the other as one path (shared end points once).
static func _join(parts: Array) -> Dictionary:
	var pts := PackedVector3Array()
	var on_link := PackedInt32Array()
	for p in parts:
		var src: PackedVector3Array = p.points
		var skip := 1 if not pts.is_empty() and not src.is_empty() and pts[-1].distance_to(src[0]) < 0.05 else 0
		var offset := pts.size() - skip
		for i in p.links:
			on_link.append(i + offset)
		pts.append_array(src.slice(skip))
	return {"points": pts, "links": on_link}


func _on_arrived() -> void:
	if _done or _route < 0:
		return
	_done = true
	var r := routes[_route]
	print("wandelaar: %s | %s" % [r.title, _summary(r)])
	for e in stats.events:
		print("    ", e)
	route_finished.emit(_route)


func _on_stuck(at: Vector3) -> void:
	stats.stuck += 1
	_event("vast", at)
	_follower.skip_ahead()


func _on_landed(drop: float) -> void:
	if stats.is_empty() or drop <= body.step + 0.2:
		return
	stats.falls += 1
	stats.max_drop = maxf(stats.max_drop, drop)
	_event("gevallen %.1f m" % drop, body.global_position)


func _on_jumped(_target: Vector3) -> void:
	if not stats.is_empty():
		stats.jumps += 1


## Notes a problem at `at` (world metres) with the ground tile there, for the output.
func _event(what: String, at: Vector3) -> void:
	stats.events.append("%s bij (%.1f, %.1f, %.1f) op %s" % [what, at.x, at.y, at.z, _tile_at(at)])


## Name of the highest Grond tile at or below `at` (world metres) in its column.
func _tile_at(at: Vector3) -> String:
	var gm := get_node_or_null(ground_path) as GridMap
	if gm == null:
		return "?"
	var c := gm.local_to_map(gm.to_local(at))
	for y in range(c.y + 1, c.y - 8, -1):
		var item := gm.get_cell_item(Vector3i(c.x, y, c.z))
		if item != GridMap.INVALID_CELL_ITEM:
			return "%s (laag %d)" % [gm.mesh_library.get_item_name(item), y]
	return "niets"


# ------------------------------------------------------------------ routes

## Route category of a Grond item name ("" = not a route tile).
static func _category(item: String) -> String:
	# not for walking: under a deck, walls, rails
	for part in ["pijler", "ligger", "landhoofd", "middenwand", "portaal", "kademuur", "trein", "spoor/"]:
		if part in item:
			return ""
	if item.begins_with("brug/") or item.begins_with("helling_bocht/brug") or item.begins_with("helling/helling_brug"):
		return "brug"
	if item.begins_with("tunnel/"):
		return "tunnel"
	if "trap" in item:
		return "trap"
	if item.begins_with("helling/") or item.begins_with("helling_bocht/"):
		return "helling"
	for prefix in ["heuvel", "waterkant", "stoep"]:
		if item.begins_with(prefix + "/"):
			return prefix
	return ""


## Up to max_routes routes over the groups of route cells in `gm`: bridges and tunnels
## first (each kind of bridge once), then the other categories round by round; the
## pavement only when there is little else.
func _pick_routes(gm: GridMap) -> Array[Dictionary]:
	var lib := gm.mesh_library
	var cells := {}   # category -> {Vector2i(x, z): [Vector3i cell, item name]}
	for c in gm.get_used_cells():
		var item := lib.get_item_name(gm.get_cell_item(c))
		var cat := _category(item)
		if cat == "":
			continue
		if not cells.has(cat):
			cells[cat] = {}
		var k := Vector2i(c.x, c.z)
		# per column the highest cell (a deck above a tunnel counts as the deck)
		if not cells[cat].has(k) or c.y > cells[cat][k][0].y:
			cells[cat][k] = [c, item]
	var groups := {}   # category -> groups (largest first)
	for cat in cells:
		var list := _groups(cells[cat]).filter(func(g): return g.size() >= (1 if cat == "trap" else 2))
		list.sort_custom(func(x, y): return x.size() > y.size())
		groups[cat] = list
	var picked: Array[Dictionary] = []
	var titles := {}
	var pass_i := 0
	while picked.size() < max_routes:
		var any := false
		for cat in CATEGORIES:
			var list: Array = groups.get(cat, [])
			if cat == "stoep" and picked.size() >= 2 or pass_i >= list.size() or picked.size() >= max_routes:
				continue
			any = true
			# bridges and tunnels: more of them in this round, while there is room
			var kinds: Array = range(pass_i, list.size()) if cat in ["brug", "tunnel"] else [pass_i]
			for k in kinds:
				if picked.size() >= max_routes - (1 if k > pass_i else 0):
					break
				var route := _route_over(gm, cat, list[k], cells[cat])
				if titles.has(route.title) and cat != "stoep":
					continue
				titles[route.title] = true
				picked.append(route)
		if not any:
			break
		pass_i += 1
	return picked


## Groups of 8-connected columns (Vector2i keys of `cells`).
static func _groups(cells: Dictionary) -> Array:
	var seen := {}
	var out := []
	for k in cells:
		if seen.has(k):
			continue
		var group: Array[Vector2i] = []
		var todo: Array[Vector2i] = [k]
		seen[k] = true
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			group.append(c)
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var n := c + Vector2i(dx, dz)
					if cells.has(n) and not seen.has(n):
						seen[n] = true
						todo.append(n)
		out.append(group)
	return out


## A route over `group` (columns of `cells`): along its longest side, from LEAD metres
## before it, through the column nearest its centre, to LEAD metres past it (at most
## REACH metres from the middle on either side). Points are cell bases (y); the tops
## say how high the tile is, for GridNav.lowest_in_column.
func _route_over(gm: GridMap, cat: String, group: Array, cells: Dictionary) -> Dictionary:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	var centre := Vector2.ZERO
	for k: Vector2i in group:
		lo = Vector2i(mini(lo.x, k.x), mini(lo.y, k.y))
		hi = Vector2i(maxi(hi.x, k.x), maxi(hi.y, k.y))
		centre += Vector2(k)
	centre /= group.size()
	var mid_key: Vector2i = group[0]
	for k: Vector2i in group:
		if Vector2(k).distance_to(centre) < Vector2(mid_key).distance_to(centre):
			mid_key = k
	var along_x := hi.x - lo.x >= hi.y - lo.y
	var mid := _base(gm, cells[mid_key][0])
	var size := gm.cell_size.x
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var m := mid.x if along_x else mid.z
	var start := clampf((lo.x if along_x else lo.y) * size - LEAD, m - REACH, m)
	var end := clampf((hi.x if along_x else hi.y) * size + size + LEAD, m, m + REACH)
	var first: Vector3i = cells[_outermost(group, along_x, -1)][0]
	var last: Vector3i = cells[_outermost(group, along_x, 1)][0]
	var a := mid + axis * (start - m)
	var b := mid + axis * (end - m)
	a.y = _base(gm, first).y
	b.y = _base(gm, last).y
	var counts := {}
	for k in group:
		var item: String = cells[k][1]
		counts[item] = counts.get(item, 0) + 1
	var main: String = counts.keys()[0]
	for item in counts:
		if counts[item] > counts[main]:
			main = item
	return _new_route(cat, main.get_file(), group.size(), a, mid, b, _top(gm, first), _top(gm, cells[mid_key][0]), _top(gm, last))


func _new_route(cat: String, title: String, cells: int, a: Vector3, mid: Vector3, b: Vector3,
		a_top: float, mid_top: float, b_top: float) -> Dictionary:
	var aabb := AABB(a, Vector3.ZERO).expand(mid).expand(b).grow(MARGIN)
	aabb.position.y -= 6.0
	aabb.size.y += 14.0
	return {"category": cat, "title": title, "cells": cells, "a": a, "mid": mid, "b": b,
		"a_top": a_top, "mid_top": mid_top, "b_top": b_top, "aabb": aabb, "nav": null,
		"ready": false, "link_ms": 0.0}


## Column of `group` furthest along the axis (side -1 = start, 1 = end).
static func _outermost(group: Array, along_x: bool, side: int) -> Vector2i:
	var best: Vector2i = group[0]
	for k: Vector2i in group:
		var v: int = k.x if along_x else k.y
		var bv: int = best.x if along_x else best.y
		if v * side > bv * side:
			best = k
	return best


## Centre of the base of ground cell `c` (world metres).
static func _base(gm: GridMap, c: Vector3i) -> Vector3:
	return gm.to_global(gm.map_to_local(c))


## Height of the tile in ground cell `c` (metres; tunnels are 6 m, with their roof).
static func _top(gm: GridMap, c: Vector3i) -> float:
	var mesh := gm.mesh_library.get_item_mesh(gm.get_cell_item(c))
	return mesh.get_aabb().end.y if mesh else 1.0


# ------------------------------------------------------------------ navigation

## Bakes the navigation of every route in turn (in the background), adds the jump and
## drop links, then the demo routes. Stops when the map changes (generation).
func _prepare(generation: int) -> void:
	var maps: Array = [get_node_or_null(ground_path)]
	for p in obstacle_paths:
		maps.append(get_node_or_null(p))
	for r in routes:
		var nav := GridNav.new(body.height, body.radius, body.step)
		r.nav = nav
		# water has a solid collider, but nobody should plan a walk over it
		var source := GridNav.collect_source(maps, r.aabb, func(gm: GridMap, item: String) -> bool:
			return gm.name == "Grond" and item.begins_with("water/"))
		nav.bake(source, r.aabb)
		await nav.baked
		if generation != _generation:
			return
		while not nav.is_ready():
			await get_tree().physics_frame
			if generation != _generation:
				return
		var t := Time.get_ticks_usec()
		nav.add_jump_links(get_world_3d().direct_space_state, r.aabb, JUMP_UP, DROP)
		r.link_ms = (Time.get_ticks_usec() - t) / 1000.0
		# the links reach the map with its next update
		await get_tree().physics_frame
		await get_tree().physics_frame
		if generation != _generation:
			return
		r.ready = true
		if routes.find(r) == _route:
			_update_views()
	_add_demo_routes()
	preparing = false
	routes_ready.emit()


## The fall and jump demos, from the links of the routes' navigation: the highest drop,
## and a jump (over something at the same level if there is one, else up a ledge).
func _add_demo_routes() -> void:
	var drop := {}
	var jump := {}
	for r in routes:
		for l in r.nav.links:
			var dh: float = l.from.y - l.to.y
			if not l.bidirectional and (drop.is_empty() or dh > drop.dh):
				drop = {"link": l, "dh": dh, "route": r}
			elif l.bidirectional:
				# over something (dh ~ 0) beats up a ledge; higher ledges beat lower ones
				var score := 10.0 if dh <= body.step else dh
				if jump.is_empty() or score > jump.score:
					jump = {"link": l, "score": score, "route": r}
	for d in [drop, jump]:
		if d.is_empty():
			continue
		var l: Dictionary = d.link
		var from: Vector3 = l.from
		var to: Vector3 = l.to
		var is_drop: bool = d.has("dh")
		if not is_drop and from.y > to.y + body.step:
			var swap := from
			from = to
			to = swap   # jump up the ledge, not down
		var dir := PathFollower._flat(to - from).normalized()
		var src: Dictionary = d.route
		var nav: GridNav = src.nav
		var title := ("val van %.1f m" % (from.y - to.y)) if is_drop else \
			("sprong over een obstakel" if absf(from.y - to.y) <= body.step else "sprong %.1f m omhoog" % (to.y - from.y))
		# start and end on the same level as the link's ends
		var a := nav.closest(from - dir * DEMO_LEAD)
		var b := nav.closest(to + dir * DEMO_LEAD)
		var r := _new_route("val" if is_drop else "sprong", title, 0, a + Vector3.DOWN * 0.25, from,
			b + Vector3.DOWN * 0.25, 0.75, 0.75, 0.75)
		r.nav = nav
		r.aabb = src.aabb
		r.ready = true
		r.demo_link = {"from": from, "to": to}
		routes.append(r)


# ------------------------------------------------------------------ views

## The body (VoxCharacter with a PathFollower), the person model and the see-through collider.
func _make_figure() -> void:
	body = VoxCharacter.new()
	body.name = "Lichaam"
	body.collision_layer = 0   # nothing collides with the figure, it collides with the map
	body.collision_mask = 1
	add_child(body)
	body.landed.connect(_on_landed)
	body.jumped.connect(_on_jumped)
	_follower = PathFollower.new()
	_follower.name = "Volger"
	body.add_child(_follower)
	_follower.arrived.connect(_on_arrived)
	_follower.stuck.connect(_on_stuck)
	var pivot := Node3D.new()
	pivot.name = "Model"
	body.add_child(pivot)
	_visual = MeshInstance3D.new()
	var lib := load("res://assets/libraries/props.res") as MeshLibrary
	var id := lib.find_item_by_name(MODEL) if lib else -1
	if id >= 0:
		_visual.mesh = lib.get_item_mesh(id)
		_visual.transform = lib.get_item_mesh_transform(id)
	else:
		push_warning("wandelaar: prop %s not found, using a capsule" % MODEL)
		var m := CapsuleMesh.new()
		m.height = body.height
		m.radius = body.radius
		_visual.mesh = m
		_visual.position.y = body.height * 0.5
	pivot.add_child(_visual)
	# collider: the capsule and the step ray under it
	_collider_view = Node3D.new()
	body.add_child(_collider_view)
	var cm := CapsuleMesh.new()
	cm.height = body.height - body.step
	cm.radius = body.radius
	cm.material = _overlay(Color(1.0, 0.45, 0.1, 0.22), false)
	var capsule := MeshInstance3D.new()
	capsule.mesh = cm
	capsule.position.y = body.step + cm.height * 0.5
	capsule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collider_view.add_child(capsule)
	var rm := CylinderMesh.new()
	rm.top_radius = 0.02
	rm.bottom_radius = 0.02
	rm.height = body.step
	rm.material = _overlay(Color(1.0, 0.2, 0.1, 0.8), false)
	var ray := MeshInstance3D.new()
	ray.mesh = rm
	ray.position.y = body.step * 0.5
	_collider_view.add_child(ray)


func _make_views() -> void:
	_nav_view = MeshInstance3D.new()
	_nav_view.top_level = true
	_nav_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_nav_view)
	_path_view = MeshInstance3D.new()
	_path_view.top_level = true
	_path_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_path_view)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 28
	_label.offset_top = -210
	layer.add_child(_label)


## Rebuilds the overlays for the current route: navigation mesh (blue), path (yellow,
## drawn through walls and decks) and jump/drop links (magenta arcs).
func _update_views() -> void:
	if _collider_view == null:
		return
	_collider_view.visible = show_collider
	_nav_view.visible = show_navigation
	_path_view.visible = show_navigation
	_nav_view.mesh = null
	_path_view.mesh = null
	if _route < 0 or _route >= routes.size() or routes[_route].nav == null:
		return
	var nav: GridNav = routes[_route].nav
	if nav.navmesh:
		var verts := nav.navmesh.get_vertices()
		var tris := PackedVector3Array()
		for i in nav.navmesh.get_polygon_count():
			var poly := nav.navmesh.get_polygon(i)
			for j in range(1, poly.size() - 1):
				for v in [poly[0], poly[j], poly[j + 1]]:
					tris.append(verts[v] + Vector3.UP * 0.04)
		if not tris.is_empty():
			var am := ArrayMesh.new()
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = tris
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			am.surface_set_material(0, _overlay(Color(0.2, 0.75, 1.0, 0.13), false))
			_nav_view.mesh = am
	var im := ImmediateMesh.new()
	if _follower.points.size() > 1:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _overlay(Color(1.0, 0.9, 0.1, 1.0), true))
		for p in _follower.points:
			im.surface_add_vertex(p + Vector3.UP * 0.1)
		im.surface_end()
	if not nav.links.is_empty():
		im.surface_begin(Mesh.PRIMITIVE_LINES, _overlay(Color(1.0, 0.25, 0.9, 0.9), false))
		for l in nav.links:
			var prev: Vector3 = l.from
			for s in range(1, 9):
				var t := s / 8.0
				var p: Vector3 = l.from.lerp(l.to, t) + Vector3.UP * (0.1 + sin(t * PI) * 0.6)
				im.surface_add_vertex(prev)
				im.surface_add_vertex(p)
				prev = p
		im.surface_end()
	if im.get_surface_count() > 0:
		_path_view.mesh = im


## Unshaded see-through material; on_top = drawn through walls and decks (the path).
static func _overlay(color: Color, on_top: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = on_top
	return m


func _show_stats() -> void:
	if body:
		_visual.get_parent().rotation.y = atan2(body.facing.x, body.facing.z)
	if _label == null:
		return
	if _route < 0 or _route >= routes.size():
		_label.text = ""
		return
	var r := routes[_route]
	var state := "navmesh bakken…" if not r.ready else ("klaar" if _done else "loopt")
	_label.text = "Wandelaar %d/%d · %s · %s\n%s\nfysica %.2f ms/frame · %s" % [_route + 1, routes.size(),
		r.title, state, _summary(r), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		ProjectSettings.get_setting("physics/3d/physics_engine")]


## One line of numbers about route `r` and the walk so far.
func _summary(r: Dictionary) -> String:
	if stats.is_empty():
		return ""
	var nav: GridNav = r.nav
	return ("pad %.0f m%s · gelopen %.0f m in %.0f s · vast %d · gevallen %d (max %.1f m) · sprongen %d · " +
		"hoogte %.1f..%.1f m · naast pad max %.2f m · navmesh %d bron-driehoeken %.0f ms · %d links %.0f ms") % [
		stats.length, " (GEEN VOLLEDIG PAD)" if stats.no_path else "", stats.walked, stats.time, stats.stuck,
		stats.falls, stats.max_drop, stats.jumps, stats.low, stats.high, stats.max_off_path,
		nav.source_triangles if nav else 0, nav.bake_ms if nav else 0.0, nav.links.size() if nav else 0, r.link_ms]


## Explanation of route `r` for the tour caption.
func _describe(r: Dictionary) -> String:
	var how := "Lopen met VoxCharacter (zwaartekracht, opstappen tot %.0f cm via een straal onder de capsule), pad via GridNav." % (body.step * 100.0)
	match r.category:
		"val":
			return "Testpoppetje van 1,80 m loopt over een rand en valt %s naar beneden (paars = val- en spronglinks). %s" % [r.title.trim_prefix("val van "), how]
		"sprong":
			return "Testpoppetje van 1,80 m neemt een spronglink: %s (paars = val- en spronglinks). %s" % [r.title, how]
	return ("Testpoppetje van 1,80 m met een capsule als botsvorm (geel = pad, blauw = navmesh, paars = val- en " +
		"spronglinks). Route over een %s (%s, %d tiles): ervoor, over het midden, erna. %s") % [r.category, r.title,
		r.cells, how]
