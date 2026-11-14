extends Node3D
## An interior (scenes/binnen/*.tscn, built by tools/build/build_interiors.gd, then edited by
## hand in Godot): the GridMaps Vloer and Inrichting with the tiles of the library binnen, the
## markers Deur (in and out; Deur1, Deur2, ... for more doors: doors()), Snackbarhouder (behind
## the counter) and Plek* (the chairs), and its lamps. This is the base of every interior: one
## with more life in it extends this script (Den Haag Centraal: scripts/world/station/station.gd) and
## overrides dress(); Interiors calls dress(), doors(), and player_came_in(player) and
## player_went_out() when it has them. Interiors (scripts/world/interiors/interiors.gd) puts it far off the map and dresses it
## for the snack bar you walk into (dress): the colour variant of its tiles (VARIANTS: every
## tile named "<something>_<variant>" becomes the one of the snack bar's variant, when there
## is one), its name on the wall, the person behind the counter, and a few people at the
## tables, all from the snack bar's seed, so each one is the same every time you come in but
## differs a little from the next.
## Putting the player out (Eviction, scripts/world/interiors/eviction.gd, the same in every interior):
## who comes is evictor_for (the nearest of the role in sight, else one brought in at
## evictor_entry, a door), walk_evictor walks them after the player over the free floor of
## the room (floor_path: a grid of FLOOR_CELL m over the GridMaps, round the counter, the
## tables, the shelves), evictor_stops halts them, evictor_done puts them back where they
## were (or away, one brought in). An interior with its own people (the station) or its own
## floor (the supermarket) overrides what differs.

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const FloorGrid = preload("res://scripts/pathfinding/floor_grid.gd")
const WallClosure = preload("res://scripts/world/interiors/wall_closure.gd")
const SnackBarLayout = preload("res://scripts/world/interiors/snack_bar_layout.gd")
const TILE_FOLDER := "snackbar/"
const VARIANTS := ["zwartwit", "roodwit", "geel", "blauw"]
## How many of the seats are taken (fewest, most).
const GUESTS := Vector2i(1, 3)

## The floor grid for the evictor (floor_path): its cells (m), what is too high to be in
## the way (a sign on the wall) or too low (a doormat), and how far round a thing it keeps.
const FLOOR_CELL := 0.5
const FLOOR_OBSTACLE_TOP_BELOW := 0.2
const FLOOR_OBSTACLE_BOTTOM_ABOVE := 1.6
const FLOOR_OBSTACLE_MARGIN := 0.15
## How often the evictor looks again which way to go (s), and how fast it turns.
const EVICTOR_REPLAN := 0.4
const EVICTOR_TURN := 9.0
## Who is brought in to put the player out keeps this meta (evictor_done takes them away).
const BROUGHT_IN_META := "uitzetter_erbij"
## Where who came for the player stood before (evictor_done puts them back).
const HOME_META := "uitzetter_thuis"

## The layout of the room now (SnackBarLayout.plan), empty for a room that has none.
var layout := {}
var snack_bar_name := ""
var _name_label: Label3D
var _people: Array[InteriorPerson] = []
var _floor_grids := {}               # instance id of a root (floor_root) -> {"grid", "origin"}


## Where you come in and go out (the marker Deur, or else Deur1): its place and the way
## into the room.
func door() -> Transform3D:
	var all := doors()
	return all[0] if not all.is_empty() else global_transform


## Every door (the markers Deur, Deur1, Deur2, ... in that order): an interior with more
## ways in (Den Haag Centraal) has one for each, matching the ways in on the map from west
## to east (Interiors).
func doors() -> Array[Transform3D]:
	var found: Array[Transform3D] = []
	var single := get_node_or_null("Deur") as Node3D
	if single:
		found.append(single.global_transform)
	var number := 1
	while has_node("Deur%d" % number):
		found.append((get_node("Deur%d" % number) as Node3D).global_transform)
		number += 1
	return found


## Dresses the room for a snack bar: `bar_name` on the wall, the rest from `seed`: its
## colour variant, and (a room with a counter: the marker Snackbarhouder) its own layout
## (SnackBarLayout: its size, where the door and the counter are, how many tables).
func dress(bar_name: String, seed: int) -> void:
	snack_bar_name = bar_name
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var variant: String = VARIANTS[random.randi() % VARIANTS.size()]
	if has_node("Snackbarhouder") and has_node("Vloer") and has_node("Inrichting"):
		_lay_out(SnackBarLayout.plan(seed), variant)
	_swap_variant(variant)
	_show_name(bar_name)
	if not layout.is_empty() and _name_label:
		_name_label.position = layout.name_at
	for person in _people:
		person.queue_free()
	_people.clear()
	var keeper_marker := get_node_or_null("Snackbarhouder") as Node3D
	if keeper_marker:
		_place(InteriorPerson.create("snackbarhouder", seed * 3 + 1, false), keeper_marker)
	var seats: Array = get_children().filter(func(node: Node) -> bool: return node is Marker3D and node.name.begins_with("Plek"))
	# the seats in an order of the seed, the first few taken
	for index in range(seats.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var kept: Node = seats[index]
		seats[index] = seats[other]
		seats[other] = kept
	var guests := mini(random.randi_range(GUESTS.x, GUESTS.y), seats.size())
	for index in guests:
		_place(InteriorPerson.create("klant", seed * 7 + index * 13 + 5, true), seats[index])


func people() -> Array[InteriorPerson]:
	return _people


## Builds the room of `plan` (SnackBarLayout) into the GridMaps Vloer and Inrichting, in
## the tiles of `variant`, and moves the markers with it: Deur, Snackbarhouder, the seats
## Plek1.. (as many as the plan has) and the lamps.
func _lay_out(plan: Dictionary, variant: String) -> void:
	layout = plan
	_floor_grids.clear()   # the evictor's floor grid: of the new room
	var floor_map := get_node("Vloer") as GridMap
	var furniture := get_node("Inrichting") as GridMap
	floor_map.clear()
	furniture.clear()
	for entry: Array in plan.floor:
		_put_tile(floor_map, "%s_%s" % [entry[0], variant], entry[1], 0.0)
	for entry: Array in plan.tiles:
		var tile_name := "%s_%s" % [entry[0], variant] if bool(entry[3]) else String(entry[0])
		_put_tile(furniture, tile_name, entry[1], float(entry[2]))
	(get_node("Deur") as Node3D).transform = plan.door
	(get_node("Snackbarhouder") as Node3D).transform = plan.keeper
	for child in get_children():
		if child is Marker3D and child.name.begins_with("Plek"):
			remove_child(child)
			child.queue_free()
	for seat_index in plan.seats.size():
		var seat := Marker3D.new()
		seat.name = "Plek%d" % (seat_index + 1)
		add_child(seat)
		seat.transform = plan.seats[seat_index]
	var lamps: Array = get_children().filter(func(node: Node) -> bool: return node is OmniLight3D)
	for lamp_index in mini(lamps.size(), plan.lamps.size()):
		(lamps[lamp_index] as Node3D).position = plan.lamps[lamp_index]


## A tile of the library binnen (TILE_FOLDER) at `at` (metres, on the 0.5 m grid), turned.
func _put_tile(grid: GridMap, tile_name: String, at: Vector3, turn: float) -> void:
	var item := grid.mesh_library.find_item_by_name(TILE_FOLDER + tile_name) if grid.mesh_library else -1
	if item < 0:
		push_warning("snackbar: geen tile %s" % tile_name)
		return
	var cell := Vector3i(roundi(at.x * 2.0), roundi(at.y * 2.0), roundi(at.z * 2.0))
	grid.set_cell_item(cell, item, grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn)))


func _place(person: InteriorPerson, marker: Node3D) -> void:
	add_child(person)
	person.transform = marker.transform
	_people.append(person)


## Every tile of another variant becomes the one of `variant` (if the library has it).
func _swap_variant(variant: String) -> void:
	for grid_name in ["Vloer", "Inrichting"]:
		var grid := get_node_or_null(grid_name) as GridMap
		if grid == null or grid.mesh_library == null:
			continue
		var library := grid.mesh_library
		for cell in grid.get_used_cells():
			var item := grid.get_cell_item(cell)
			var item_name := library.get_item_name(item)
			for other in VARIANTS:
				if other != variant and item_name.ends_with("_" + other):
					var wanted := library.find_item_by_name(item_name.trim_suffix(other) + variant)
					if wanted >= 0:
						grid.set_cell_item(cell, wanted, grid.get_cell_item_orientation(cell))
					break


## The snack bar's name on the back wall, over the menu board, in the pixel font, lit.
func _show_name(bar_name: String) -> void:
	if _name_label == null:
		_name_label = Label3D.new()
		_name_label.name = "Naam"
		_name_label.font = UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
		_name_label.font_size = 64
		_name_label.pixel_size = 0.006
		_name_label.modulate = Color("#FFE2B0")
		_name_label.outline_size = 0
		_name_label.shaded = false
		_name_label.double_sided = false
		_name_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_name_label.position = Vector3(-1.5, 2.65, 3.6)
		_name_label.rotation.y = PI
		add_child(_name_label)
	_name_label.text = bar_name.to_upper()


# ------------------------------------------------------------------ putting the player out

## Who warns the player before they are put out (Interiors.offence, uitzetten.json
## "waarschuwing"): of the people in sight the nearest with `role`; null when there is none
## here (no one is brought in for a warning).
func warner_for(role: String, player: Node3D) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF
	for person in people():
		if not is_instance_valid(person) or person.role != role or not person.is_visible_in_tree():
			continue
		var distance := person.global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = person
	return nearest


## Who comes to put the player out (Eviction): of the people in sight the nearest with
## `role` (warner_for), else one of that role brought in at evictor_entry; null when there is
## none (Eviction asks again).
func evictor_for(role: String, player: Node3D) -> Node3D:
	var nearest := warner_for(role, player)
	if nearest:
		return nearest
	var entry := evictor_entry()
	if entry == null or not entry.is_visible_in_tree():
		return null
	var brought := InteriorPerson.create(role, randi(), false, InteriorPerson.SEAT_HEIGHT, evictor_outfit(role))
	brought.name = "Uitzetter"
	brought.role = role
	brought.set_meta(BROUGHT_IN_META, true)
	entry.get_parent().add_child(brought)
	brought.global_transform = entry.global_transform
	return brought


## What one brought in to put the player out wears (InteriorPerson.create "outfit").
func evictor_outfit(_role: String) -> Dictionary:
	return {}


## Where one is brought in to put the player out (evictor_for): the door.
func evictor_entry() -> Node3D:
	var door_marker := get_node_or_null("Deur") as Node3D
	return door_marker if door_marker else get_node_or_null("Deur1") as Node3D


## Whether putting the player out waits now (the city hall: while the lift rides).
func evicting_held() -> bool:
	return false


## Walks `person` towards `target` (global) at `speed` (m/s) for `delta` seconds, over the
## free floor (floor_path, again every EVICTOR_REPLAN s), on their feet (who sat stands
## up); returns how far they went.
func walk_evictor(person: Node3D, target: Vector3, speed: float, delta: float) -> float:
	if not person.has_meta(HOME_META):
		person.set_meta(HOME_META, {"transform": person.transform, "sitting": bool(person.get("sitting"))})
	_stand_up(person)
	var clock := float(person.get_meta("uitzetter_klok", 0.0)) - delta
	var path: PackedVector3Array = person.get_meta("uitzetter_pad", PackedVector3Array())
	if clock <= 0.0 or path.is_empty():
		clock = EVICTOR_REPLAN
		path = floor_path(person.global_position, target)
	person.set_meta("uitzetter_klok", clock)
	var left := speed * delta
	var walked := 0.0
	while left > 0.0 and not path.is_empty():
		var offset := path[0] - person.global_position
		offset.y = 0.0
		if offset.length() <= left:
			person.global_position += offset
			walked += offset.length()
			left -= offset.length()
			path.remove_at(0)
			continue
		var direction := offset.normalized()
		person.global_position += direction * left
		walked += left
		left = 0.0
		var goal := atan2(direction.x, direction.z)
		person.global_rotation.y = lerp_angle(person.global_rotation.y, goal, 1.0 - exp(-EVICTOR_TURN * delta))
	person.set_meta("uitzetter_pad", path)
	_animate_walk(person, walked, delta)
	return walked


## `person` stops where they are (they have the player): standing straight.
func evictor_stops(person: Node3D) -> void:
	var figure: TownsfolkFigure = person.get("figure")
	if figure and not bool(person.get("sitting")):
		figure.walk(0.0, 0.0)


## Over: `person` back where they were before (who sat sits again), or gone (one brought in).
func evictor_done(person: Node3D) -> void:
	if person.has_meta(BROUGHT_IN_META):
		person.queue_free()
		return
	for meta_name in ["uitzetter_klok", "uitzetter_pad", "uitzetter_pas", "uitzetter_loopt"]:
		person.remove_meta(meta_name)
	if person.has_meta(HOME_META):
		var home: Dictionary = person.get_meta(HOME_META)
		person.remove_meta(HOME_META)
		person.transform = home.transform
		var figure: TownsfolkFigure = person.get("figure")
		if figure:
			figure.walk(0.0, 0.0)
		if bool(home.sitting) and person.has_method("_sit"):
			person.set("sitting", true)
			person.call("_sit")


## The way from `from` to `to` (global) over the free floor of floor_root(): a grid of
## FLOOR_CELL m over its floor tiles, the furniture below head height blocking it; straight
## when there is no way (or no floor).
func floor_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	var root := floor_root()
	var floor_grid := _floor_grid_of(root)
	if floor_grid.is_empty():
		points.append(to)
		return points
	var grid: AStarGrid2D = floor_grid.grid
	var cells := FloorGrid.cell_path(grid, _floor_cell(floor_grid, root.to_local(from)), _floor_cell(floor_grid, root.to_local(to)))
	for cell in cells:
		points.append(root.to_global(_floor_cell_middle(floor_grid, cell, root.to_local(from).y)))
	if points.size() > 1:
		points.remove_at(0)
	points.append(to)
	return points


## The node whose GridMaps are the floor the player walks on now (plan_root, else this).
func floor_root() -> Node3D:
	if has_method("plan_root"):
		var root: Node3D = call("plan_root")
		if root:
			return root
	return self


## Who sat (at the till, behind the counter) gets up to walk.
func _stand_up(person: Node3D) -> void:
	if not bool(person.get("sitting")):
		return
	person.set("sitting", false)
	var figure: TownsfolkFigure = person.get("figure")
	if figure:
		figure.position = Vector3.ZERO
		figure.walk(0.0, 0.0)


## The legs and arms of `person` walking `walked` metres this frame (TownsfolkFigure.walk).
func _animate_walk(person: Node3D, walked: float, delta: float) -> void:
	if person.has_method("walk_cycle"):
		person.call("walk_cycle", walked, delta)   # a Person: its own cycle of steps
		return
	var figure: TownsfolkFigure = person.get("figure")
	if figure == null:
		return
	# after the player they run: the run of the player (TownsfolkFigure.walk `run`)
	var run := TownsfolkFigure.run_share(walked / maxf(delta, 0.0001))
	var stride := float(person.get_meta("uitzetter_pas", 0.0)) + walked / TownsfolkFigure.stride_at(run) * PI
	var amount := move_toward(float(person.get_meta("uitzetter_loopt", 0.0)), 1.0 if walked > 0.0 else 0.0, delta * 5.0)
	person.set_meta("uitzetter_pas", stride)
	person.set_meta("uitzetter_loopt", amount)
	figure.walk(stride, amount, run)


## The floor grid of `root` (made once): {"grid": AStarGrid2D, "origin": Vector2 (the
## corner of cell 0,0 in the root's space)}; empty when it has no floor tiles.
func _floor_grid_of(root: Node3D) -> Dictionary:
	var key := root.get_instance_id()
	if _floor_grids.has(key):
		return _floor_grids[key]
	var floors: Array[AABB] = []
	var obstacles: Array[AABB] = []
	for child in root.get_children():
		var grid_map := child as GridMap
		if grid_map == null or grid_map.mesh_library == null:
			continue
		for box in _tile_boxes(grid_map, root):
			if grid_map.name == "Vloer":
				floors.append(box)
			elif box.end.y > FLOOR_OBSTACLE_TOP_BELOW and box.position.y < FLOOR_OBSTACLE_BOTTOM_ABOVE:
				obstacles.append(box)
	if floors.is_empty():
		_floor_grids[key] = {}
		return {}
	var bounds: AABB = floors[0]
	for box in floors:
		bounds = bounds.merge(box)
	var grid := FloorGrid.make(ceili(bounds.size.x / FLOOR_CELL), ceili(bounds.size.z / FLOOR_CELL))
	var found := {"grid": grid, "origin": Vector2(bounds.position.x, bounds.position.z)}
	for column in grid.region.size.x:
		for row in grid.region.size.y:
			var middle := _floor_cell_middle(found, Vector2i(column, row), 0.0)
			if not _over_any(floors, middle):
				grid.set_point_solid(Vector2i(column, row), true)
	for box in obstacles:
		var low := _floor_cell(found, box.position - Vector3(FLOOR_OBSTACLE_MARGIN, 0.0, FLOOR_OBSTACLE_MARGIN))
		var high := _floor_cell(found, box.end + Vector3(FLOOR_OBSTACLE_MARGIN, 0.0, FLOOR_OBSTACLE_MARGIN))
		FloorGrid.block(grid, low, high)
	_floor_grids[key] = found
	return found


## Whether `point` lies over (or under) one of `boxes`, along the floor.
static func _over_any(boxes: Array[AABB], point: Vector3) -> bool:
	for box in boxes:
		if point.x >= box.position.x and point.x <= box.end.x and point.z >= box.position.z and point.z <= box.end.z:
			return true
	return false


## The boxes the tiles of `grid_map` take up, in the space of `root`.
static func _tile_boxes(grid_map: GridMap, root: Node3D) -> Array[AABB]:
	return WallClosure.tile_boxes(grid_map, root)


static func _floor_cell(floor_grid: Dictionary, at: Vector3) -> Vector2i:
	var origin: Vector2 = floor_grid.origin
	return Vector2i(floori((at.x - origin.x) / FLOOR_CELL), floori((at.z - origin.y) / FLOOR_CELL))


static func _floor_cell_middle(floor_grid: Dictionary, cell: Vector2i, height: float) -> Vector3:
	var origin: Vector2 = floor_grid.origin
	return Vector3(origin.x + (cell.x + 0.5) * FLOOR_CELL, height, origin.y + (cell.y + 0.5) * FLOOR_CELL)
