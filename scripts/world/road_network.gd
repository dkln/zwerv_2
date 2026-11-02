class_name RoadNetwork
extends RefCounted
## The lanes vehicles drive on, shared by every vehicle of a scene
## (scripts/characters/vehicle.gd): read from the scene's "roads" metadata, which the
## city builder saves (tools/build/build_city.gd, _car).
##
## A road cell is Vector3i(x, level, z): the ground cell (4 x 4 m) and its layer (1 m
## steps, 0 = street level, -6 = the floor of a tunnel trough). Its code holds the lane
## of the east-west road (bits 0-1: 1 = westbound, 2 = eastbound), the lane of the
## north-south road (bits 2-3: 1 = southbound, 2 = northbound), driving on the right,
## and the kind of road (bits 4-5, Kind), which sets the speed limit. A cell with both
## lanes is a crossing. Ramps (ground tiles "tunnel/..._toerit_...") rise one layer
## across the cell, towards their back (away from the side their front faces).
##
## Directions (headings) are Vector2i on the map: x = east, y = south.

enum Kind { STREET, MAIN_ROAD, TUNNEL, MOTORWAY }

## Speed limit per kind of road (km/h), after the signs along them: 30 in the old
## centre, 50 at the city end of the A12, 80 in its tunnel, 100 on the motorway.
const SPEED_LIMIT_KMH := {
	Kind.STREET: 30.0,
	Kind.MAIN_ROAD: 50.0,
	Kind.TUNNEL: 80.0,
	Kind.MOTORWAY: 100.0,
}

const CELL := 4.0
## Top of the road surface above the bottom of its layer (metres; 2 voxels of 0.125 m).
const ROAD_SURFACE := 0.25
## Height a ramp rises over its cell (metres; one layer).
const RAMP_RISE := 1.0
const ZEBRA_TILE := "weg/zebrapad"
## No road cell (returned by find and step).
const NONE := Vector3i(0, -1000, 0)
const HEADINGS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static var _networks := {}   # scene root instance id -> RoadNetwork

var _codes := {}          # road cell -> code
var _ramp_rise := {}      # ramp cell -> heading in which it rises
var _ground: GridMap


## The road network of the scene with this root, made on first use.
static func of(root: Node) -> RoadNetwork:
	var key := root.get_instance_id()
	if not _networks.has(key):
		_networks[key] = RoadNetwork.new(root)
		root.tree_exiting.connect(func() -> void: _networks.erase(key), CONNECT_ONE_SHOT)
	return _networks[key]


func _init(root: Node) -> void:
	_codes = root.get_meta("roads", {})
	_ground = root.get_node_or_null("Grond") as GridMap
	for cell: Vector3i in _codes:
		if tile_name(cell).contains("toerit"):
			_ramp_rise[cell] = _rising_heading(cell)


func is_empty() -> bool:
	return _codes.is_empty()


func has(cell: Vector3i) -> bool:
	return _codes.has(cell)


## Headings a vehicle may drive in on this cell (the lanes through it).
func lanes(cell: Vector3i) -> Array[Vector2i]:
	var headings: Array[Vector2i] = []
	var code: int = _codes.get(cell, 0)
	var east_west_lane := code & 3
	var north_south_lane := (code >> 2) & 3
	if east_west_lane == 1:
		headings.append(Vector2i(-1, 0))
	elif east_west_lane == 2:
		headings.append(Vector2i(1, 0))
	if north_south_lane == 1:
		headings.append(Vector2i(0, 1))
	elif north_south_lane == 2:
		headings.append(Vector2i(0, -1))
	return headings


func is_crossing(cell: Vector3i) -> bool:
	var code: int = _codes.get(cell, 0)
	return (code & 3) != 0 and ((code >> 2) & 3) != 0


func is_zebra(cell: Vector3i) -> bool:
	return tile_name(cell) == ZEBRA_TILE


func kind(cell: Vector3i) -> Kind:
	return ((_codes.get(cell, 0) >> 4) & 3) as Kind


## Speed limit on this cell (m/s); street speed off the road.
func speed_limit(cell: Vector3i) -> float:
	return SPEED_LIMIT_KMH[kind(cell)] / 3.6


## Road cell at map cell (x, z) on this level or, onto or off a ramp, up to
## `max_level_change` levels up or down (one per cell a ramp spans); NONE if there is
## none. `from_cell`: the cell it is reached from (for the ramp check), or NONE.
func find(x: int, z: int, level: int, from_cell := NONE, max_level_change := 1) -> Vector3i:
	var same := Vector3i(x, level, z)
	if _codes.has(same):
		return same
	for level_change in range(1, max_level_change + 1):
		for direction in [1, -1]:
			var other := Vector3i(x, level + direction * level_change, z)
			if _codes.has(other) and (_ramp_rise.has(other) or _ramp_rise.has(from_cell)):
				return other
	return NONE


## The road cell one step from `cell` in `heading`, or NONE.
func step(cell: Vector3i, heading: Vector2i) -> Vector3i:
	return find(cell.x + heading.x, cell.z + heading.y, cell.y, cell)


## Road cell with a lane in `heading` nearest to map cell `near`, street level first.
func nearest(near: Vector2i, heading: Vector2i) -> Vector3i:
	var best := NONE
	var best_distance := INF
	for cell: Vector3i in _codes:
		if not lanes(cell).has(heading):
			continue
		var distance := Vector2(cell.x - near.x, cell.z - near.y).length() + absf(cell.y) * 100.0
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


## Centre of a cell on the map (metres), at the height of its road surface.
func centre(cell: Vector3i) -> Vector3:
	var middle := Vector2(cell.x + 0.5, cell.z + 0.5) * CELL
	return Vector3(middle.x, height(cell, middle), middle.y)


## Height of the road surface of `cell` at map position `spot` (metres, x and z): flat
## at its layer, or rising across a ramp. Cells that are no road count as flat.
func height(cell: Vector3i, spot: Vector2) -> float:
	var surface := cell.y + ROAD_SURFACE
	if _ramp_rise.has(cell):
		var rise: Vector2 = Vector2(_ramp_rise[cell])
		var middle := Vector2(cell.x + 0.5, cell.z + 0.5) * CELL
		var along := clampf((spot - middle).dot(rise) / CELL + 0.5, 0.0, 1.0)
		surface += along * RAMP_RISE
	return surface


## Heading in which a ramp tile rises: towards its back, away from the side its front
## faces.
func _rising_heading(cell: Vector3i) -> Vector2i:
	var front := _ground.get_basis_with_orthogonal_index(_ground.get_cell_item_orientation(cell)) * Vector3(0, 0, 1)
	return Vector2i(-roundi(front.x), -roundi(front.z))


## Name of the ground tile in a cell ("" if empty).
func tile_name(cell: Vector3i) -> String:
	if _ground == null or _ground.mesh_library == null:
		return ""
	var item := _ground.get_cell_item(cell)
	return _ground.mesh_library.get_item_name(item) if item >= 0 else ""
