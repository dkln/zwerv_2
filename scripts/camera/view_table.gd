class_name ViewTable
extends RefCounted
## Worked out ahead: for every cell of the town at street level (the Grond cells at level 0,
## not under a building) how many of the view lines round someone standing in its middle a
## building hides, for each of the views the follow camera can turn to (TURNS: the usual one,
## a quarter turn either way, half round), each at the iso pitch and at a steep one (PITCHES:
## for when tall buildings hide the player in every iso view). The follow camera (follow_camera.gd, turning round
## buildings) then looks a spot up instead of walking its lines of sight every few tenths of a
## second while the player walks.
## Made when the map is baked (tools/build/bake_maps.gd) and kept in the bake cache (CACHE_DIR,
## named after the map, keyed on the cells of the Gebouwen and the Grond and VERSION; an older
## one of the same map is removed when a new one is kept); when the map loads it is read
## from there, or made afresh on a thread of its own (from a copy of the building cells: no
## GridMap is touched off the main thread) and kept for the next time. Until it is ready the
## camera tests its lines itself, as before.
## The lines: from LINE_HEIGHTS over the cell's middle (and LINE_ACROSS to either side, across
## the view) towards the camera, in steps of STEP metres up to VIEW_DISTANCE and no higher
## than the top of the highest building; only buildings on the camera's side of the spot count
## (one at its back never hides it), as in the camera's own test.
##   var table := ViewTable.ready_for(world)       # null while it is not there yet
##   var hidden := table.hidden_at(spot, 90.0)     # -1: not in the table (a deck, a tunnel)

const Iso = preload("res://scripts/camera/iso_camera.gd")

const CACHE_DIR := "user://merged"
## Raised when the way it is worked out changes: an older table is then made again.
const VERSION := 2
const TURNS := [0.0, 90.0, -90.0, 180.0]
## The pitches the camera can look down at (degrees): the iso one, and a steep one for when tall
## buildings round the player hide it in every iso view (follow_camera.gd `steep_pitch`).
const PITCHES := [-35.264, -62.0]
const LINE_HEIGHTS := [0.4, 1.0, 1.7]
const LINE_ACROSS := [-0.4, 0.0, 0.4]
const STEP := 1.0
## How far the lines go (metres): the camera's distance at the widest walking view.
const VIEW_DISTANCE := 130.0
## A spot more than this above or below street level (a deck, a tunnel) is not in the table.
const STREET_LEVEL_SLACK := 1.5
const UNKNOWN := 255

## The table of each world being loaded or loaded (world instance id -> ViewTable), and the
## thread task of one being made.
static var _tables := {}
static var _tasks := {}

var origin := Vector2i.ZERO          # the cell (x, z) at the table's corner
var size := Vector2i.ZERO
var cell_size := 4.0
var street_height := 0.0
## Per cell (row by row from origin) one byte per pitch of PITCHES and turn of TURNS (pitch
## first): how many lines are hidden.
var counts := PackedByteArray()


## The table of `world` if it is ready; else null, and it is being read or made (once).
static func ready_for(world: Node) -> ViewTable:
	if world == null:
		return null
	var key := world.get_instance_id()
	if _tables.has(key):
		return _tables[key]
	if _tasks.has(key):
		var task: Dictionary = _tasks[key]
		if WorkerThreadPool.is_task_completed(task.id):
			WorkerThreadPool.wait_for_task_completion(task.id)
			var made: ViewTable = task.table
			_tables[key] = made
			_tasks.erase(key)
			made.save(task.path)
			return made
		return null
	var setup := _setup(world)
	if setup.is_empty():
		_tables[key] = null
		return null
	var cached := load_from(setup.path)
	if cached:
		_tables[key] = cached
		return cached
	var table := ViewTable.new()
	var id := WorkerThreadPool.add_task(table._fill.bind(setup), false, "ViewTable")
	_tasks[key] = {"id": id, "table": table, "path": setup.path}
	return null


## Makes the table of `world` here and now and keeps it in the cache (the bake); true if made
## or already there.
static func bake(world: Node) -> bool:
	var setup := _setup(world)
	if setup.is_empty():
		return false
	if FileAccess.file_exists(setup.path):
		return true
	var table := ViewTable.new()
	table._fill(setup)
	return table.save(setup.path)


## How many of its lines a building hides from someone at `spot` with the view turned `turn`
## degrees (one of TURNS); -1 if the spot is not in the table (off the map, off street level,
## a turn not in TURNS).
## `steep`: looked down at the steep pitch (PITCHES[1]) instead of the iso one.
func hidden_at(spot: Vector3, turn: float, steep := false) -> int:
	if absf(spot.y - street_height) > STREET_LEVEL_SLACK:
		return -1
	var turn_index := TURNS.find(_snap_turn(turn))
	if turn_index < 0:
		return -1
	var cell := Vector2i(floori(spot.x / cell_size), floori(spot.z / cell_size)) - origin
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return -1
	var value := counts[(cell.y * size.x + cell.x) * _views() + (TURNS.size() if steep else 0) + turn_index]
	return -1 if value == UNKNOWN else value


func save(path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# the tables of this map made for an older town
	var prefix := path.get_file().get_slice("_zicht_", 0) + "_zicht_"
	for file_name in DirAccess.get_files_at(path.get_base_dir()):
		if file_name.begins_with(prefix) and file_name != path.get_file():
			DirAccess.remove_absolute(path.get_base_dir().path_join(file_name))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var({"version": VERSION, "origin": origin, "size": size, "cell_size": cell_size,
			"street_height": street_height, "counts": counts})
	return true


static func load_from(path: String) -> ViewTable:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var stored: Variant = file.get_var()
	if not stored is Dictionary or int(stored.get("version", 0)) != VERSION:
		return null
	var table := ViewTable.new()
	table.origin = stored.origin
	table.size = stored.size
	table.cell_size = stored.cell_size
	table.street_height = stored.street_height
	table.counts = stored.counts
	return table


## Views per cell: every pitch with every turn.
static func _views() -> int:
	return TURNS.size() * PITCHES.size()


## Unit vector from the focus to the camera turned `turn` degrees from the iso view and looking
## down at `pitch` degrees.
static func towards_camera(turn: float, pitch: float) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(Iso.ROTATION.y + turn), 0.0)).z


static func _snap_turn(turn: float) -> float:
	var snapped := wrapf(roundf(turn / 90.0) * 90.0, -180.0, 180.0)
	return 180.0 if is_equal_approx(snapped, -180.0) else snapped


# ------------------------------------------------------------------ making it

## What making the table of `world` needs, copied on the main thread (the cells of its
## Gebouwen as a set, its Grond cells at street level, the transforms), and the cache path;
## empty if the world has no buildings or ground.
static func _setup(world: Node) -> Dictionary:
	var buildings := world.get_node_or_null("Gebouwen") as GridMap
	var ground := world.get_node_or_null("Grond") as GridMap
	if buildings == null or ground == null:
		return {}
	var building_data: Dictionary = buildings.get("data") if buildings.get("data") is Dictionary else {}
	var ground_data: Dictionary = ground.get("data") if ground.get("data") is Dictionary else {}
	var key := hash([VERSION, building_data.get("cells", PackedInt32Array()), ground_data.get("cells", PackedInt32Array()),
			buildings.transform, ground.transform, buildings.cell_size])
	var occupied := {}
	for cell in buildings.get_used_cells():
		occupied[cell] = true
	var street_cells: Array[Vector3i] = []
	for cell in ground.get_used_cells():
		if cell.y == 0 and not occupied.has(cell) and not occupied.has(Vector3i(cell.x, 1, cell.z)):
			street_cells.append(cell)
	if street_cells.is_empty():
		return {}
	var top := -INF
	for cell: Vector3i in occupied:
		top = maxf(top, (buildings.global_transform * buildings.map_to_local(cell)).y + buildings.cell_size.y)
	# named after the map (as the bake's own cache files: tools/build/bake_maps.gd clears a
	# map's files by that name, and those of maps that are gone)
	var map_name := world.scene_file_path.get_file().get_basename() if world.scene_file_path != "" else "kaart"
	return {"path": "%s/%s_zicht_%d.bin" % [CACHE_DIR, map_name, absi(key)], "occupied": occupied, "street_cells": street_cells,
			"to_map": buildings.global_transform.affine_inverse(), "map_cell_size": buildings.cell_size,
			"buildings_transform": buildings.global_transform, "ground_transform": ground.global_transform,
			"ground_cell_size": ground.cell_size, "top": top}


## Works the table out from `setup` (_setup): on a thread when the map loads, here at a bake.
## Only reads the copies in `setup`.
func _fill(setup: Dictionary) -> void:
	var street_cells: Array[Vector3i] = setup.street_cells
	var ground_size: Vector3 = setup.ground_cell_size
	cell_size = ground_size.x
	var ground_transform: Transform3D = setup.ground_transform
	var lowest := Vector2i(1 << 30, 1 << 30)
	var highest := -lowest
	for cell in street_cells:
		lowest = Vector2i(mini(lowest.x, cell.x), mini(lowest.y, cell.z))
		highest = Vector2i(maxi(highest.x, cell.x), maxi(highest.y, cell.z))
	# the table is in world cells (the ground's own cells shifted by its position)
	var shift := Vector2i(roundi(ground_transform.origin.x / cell_size), roundi(ground_transform.origin.z / cell_size))
	origin = lowest + shift
	size = highest - lowest + Vector2i.ONE
	street_height = ground_transform.origin.y
	counts = PackedByteArray()
	counts.resize(size.x * size.y * _views())
	counts.fill(UNKNOWN)
	for cell in street_cells:
		var middle := ground_transform * Vector3((cell.x + 0.5) * cell_size, 0.0, (cell.z + 0.5) * cell_size)
		middle.y = street_height
		var index := ((cell.z - lowest.y) * size.x + (cell.x - lowest.x)) * _views()
		for pitch_index in PITCHES.size():
			for turn_index in TURNS.size():
				counts[index + pitch_index * TURNS.size() + turn_index] = _hidden_lines(setup, middle, TURNS[turn_index], PITCHES[pitch_index])


## The lines (LINE_HEIGHTS x LINE_ACROSS) from round `spot` to the camera turned `turn` that a
## building hides (see the top); as follow_camera.gd's own test.
static func _hidden_lines(setup: Dictionary, spot: Vector3, turn: float, pitch: float) -> int:
	var occupied: Dictionary = setup.occupied
	var to_map: Transform3D = setup.to_map
	var map_cell_size: Vector3 = setup.map_cell_size
	var buildings_transform: Transform3D = setup.buildings_transform
	var top: float = setup.top
	var to_camera := towards_camera(turn, pitch)
	var across := Vector3.UP.cross(to_camera).normalized()
	var flat_towards := Vector2(to_camera.x, to_camera.z)
	var hidden := 0
	for height: float in LINE_HEIGHTS:
		for side: float in LINE_ACROSS:
			var start := spot + Vector3.UP * height + across * side
			var last_cell := Vector3i(1 << 30, 0, 0)
			for step in range(1, int(VIEW_DISTANCE / STEP)):
				var point := start + to_camera * (step * STEP)
				if point.y > top:
					break
				var local := to_map * point
				var cell := Vector3i(floori(local.x / map_cell_size.x), floori(local.y / map_cell_size.y), floori(local.z / map_cell_size.z))
				if cell == last_cell:
					continue
				last_cell = cell
				if not occupied.has(cell):
					continue
				var middle := buildings_transform * (Vector3(cell) * map_cell_size + map_cell_size * 0.5)
				if Vector2(middle.x - spot.x, middle.z - spot.z).dot(flat_towards) > 0.0:
					hidden += 1
					break
	return hidden
