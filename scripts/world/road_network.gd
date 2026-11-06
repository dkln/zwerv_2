@tool
class_name RoadNetwork
extends RefCounted
## The lanes vehicles drive on, shared by every vehicle of a scene
## (scripts/vehicles/vehicle.gd) and shown in the editor (lane_arrows.gd). Read from
## the ground tiles themselves: every tile that vehicles drive on says so in its
## metadata ("traffic" in its .tile.json, written by tools/voxgen/traffic.py, collected
## in the meta "traffic" of the ground MeshLibrary by library_builder.gd). So it works
## on any map, built by a tool or by hand, and turning a tile in the editor turns its
## lanes.
##
## A road cell is Vector3i(x, level, z): the ground cell (4 x 4 m) and its layer (1 m
## steps, 0 = street level, -6 = the floor of a tunnel trough). Per tile:
## - lanes: headings relative to the unturned tile ("N" = towards its back), turned with
##   the cell's rotation. A tile with both headings of an axis has no direction of its
##   own on it (a crossing, plain asphalt, a zebra, a tunnel tile both carriageways use);
##   that is decided from the road around it, in rounds until nothing changes: the
##   nearest lane with a direction along the same line (through crossings and up and
##   down ramps), else the lanes alongside when they agree (the middle lane of three),
##   else driving on the right at the edge of the road. An axis still open with no road
##   along it (plain asphalt in a street, crosswise) gets no lane. A cell with lanes on
##   both axes is a crossing.
## - road: kind of road (Kind), which sets the speed limit; markings and crossings take
##   the kind of the nearest cell along their lanes that has one, else a street.
## - speed: speed limit in km/h, instead of the one of the kind of road; passed on along
##   the lanes in the same way.
## - rise: the surface rises this many metres towards the back of the tile (a ramp).
## - rails: on a rail tile, the sides its rails join ("SN", "SE", ...), turned with the tile: a
##   rail vehicle only leaves a tile along them (scripts/vehicles/rail_vehicle.gd).
## - only: who may come on it: ROAD_USER_KINDS, or for a track "bus", "tram" or "trein"; left out =
##   all four. "auto" also lets buses on, so a bus lane is the one place for "bus" alone.
##   A tile with no "traffic" at all (water, a wall) is for nobody.
##
## Any placed ground tile can have its own lanes, road users and speed limit, set in the
## Build dock of the editor: the meta LANE_CHOICES of the ground GridMap, {cell: {"tile":
## item name, "lanes": ["N", "W"], "kinds": ["auto", "fiets"], "speed": 50}}, each optional.
## - lanes (any combination of forward, left, right and back) replace the lanes of the
##   tile for that one cell, are not decided from the road around it, and turn with the
##   cell like any other lanes.
## - kinds replace the "only" of the tile; an empty list closes the cell to everyone.
## - speed (km/h) replaces the limit of the tile.
## A choice no longer counts once another tile is in the cell.
##
## Headings are Vector2i on the map: x = east, y = south.

enum Kind { STREET, MAIN_ROAD, TUNNEL, MOTORWAY }

## Speed limit for cars per kind of road (km/h): 50 in town, 80 in a tunnel, 100 on the
## motorway. A placed tile can have its own (LANE_CHOICES).
const SPEED_LIMIT_KMH := {
	Kind.STREET: 50.0,
	Kind.MAIN_ROAD: 50.0,
	Kind.TUNNEL: 80.0,
	Kind.MOTORWAY: 100.0,
}
## Names of the kinds in the tile metadata ("road").
const KIND_NAMES := {"straat": Kind.STREET, "hoofdweg": Kind.MAIN_ROAD, "tunnel": Kind.TUNNEL, "snelweg": Kind.MOTORWAY}
## Lane headings of the metadata ("lanes"), on the unturned tile.
const LOCAL_HEADINGS := {"N": Vector3(0, 0, -1), "S": Vector3(0, 0, 1), "E": Vector3(1, 0, 0), "W": Vector3(-1, 0, 0)}
## Meta of the ground GridMap with the lanes chosen per placed tile (see above).
const LANE_CHOICES := &"lane_choices"
## The kinds of road users a tile can allow (Vehicle.vehicle_kind). Only "auto" drives on
## the network so far, with its buses; the others are for road users still to come.
const ROAD_USER_KINDS: Array[String] = ["auto", "brommer", "fiets", "voetganger"]

const CELL := 4.0
## Top of the road surface above the bottom of its layer (metres; 2 voxels of 0.125 m).
const ROAD_SURFACE := 0.25
const ZEBRA_TILE := "weg/zebrapad"
## No road cell (returned by find and step).
const NONE := Vector3i(0, -1000, 0)
const AXES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
## Rounds of deciding two-way lanes from the road around them.
const MAX_ROUNDS := 8

static var _networks := {}   # scene root instance id -> RoadNetwork

var _lanes := {}          # road cell -> Array[Vector2i] of headings
var _from_context := {}   # road cell -> Array[Vector2i] of axes its tile left open (decided from the road around it)
var _kinds := {}          # road cell -> Kind
var _rises := {}          # ramp cell -> [heading it rises in, metres]
var _only := {}           # road cell -> Array of vehicle kinds allowed on it
var _rails := {}          # road cell -> Array of [side, side] its rails join (headings out of the cell)
var _chosen := {}         # road cell whose lanes were chosen for this placed tile -> true
var _chosen_kinds := {}   # road cell whose vehicle kinds were chosen for this placed tile -> true
var _chosen_speeds := {}  # road cell whose speed limit was chosen for this placed tile -> true
var _speeds := {}         # road cell -> speed limit (km/h)
var _ground: GridMap


## The road network of the scene with this root, made on first use (in the game).
static func of(root: Node) -> RoadNetwork:
	var key := root.get_instance_id()
	if not _networks.has(key):
		_networks[key] = RoadNetwork.new(root.get_node_or_null("Grond") as GridMap)
		root.tree_exiting.connect(func() -> void: _networks.erase(key), CONNECT_ONE_SHOT)
	return _networks[key]


## The network of the tiles in this ground GridMap as they are now.
func _init(ground: GridMap) -> void:
	_ground = ground
	if _ground == null or _ground.mesh_library == null:
		return
	_read_tiles()
	_decide_two_way_lanes()
	_decide_kinds()


# ------------------------------------------------------------------ queries

func is_empty() -> bool:
	return _lanes.is_empty()


func has(cell: Vector3i) -> bool:
	return _lanes.has(cell)


## Every road cell.
func cells() -> Array:
	return _lanes.keys()


## Headings a vehicle may drive in on this cell (the lanes through it).
func lanes(cell: Vector3i) -> Array[Vector2i]:
	var headings: Array[Vector2i] = []
	headings.assign(_lanes.get(cell, []))
	return headings


## True if this heading of the cell comes from the road around it, not from its tile.
func is_from_context(cell: Vector3i, heading: Vector2i) -> bool:
	for axis: Vector2i in _from_context.get(cell, []):
		if heading == axis or heading == -axis:
			return true
	return false


## True if the lanes of this cell were chosen for this placed tile (Build dock).
func is_chosen(cell: Vector3i) -> bool:
	return _chosen.has(cell)


## True if the vehicle kinds of this cell were chosen for this placed tile (Build dock).
func has_chosen_kinds(cell: Vector3i) -> bool:
	return _chosen_kinds.has(cell)


## The kinds of road user that may come on this cell.
func allowed_kinds(cell: Vector3i) -> Array:
	return _only.get(cell, [])


## Every ground cell with a tile in it, with or without lanes.
func ground_cells() -> Array:
	return _only.keys()


## The heading on the map of a side of the tile in this cell ("N" = forward, its back).
func heading_of_side(cell: Vector3i, side: String) -> Vector2i:
	return _flat(_turn_of(cell) * LOCAL_HEADINGS[side])


func is_crossing(cell: Vector3i) -> bool:
	return _on_axis(cell, Vector2i(1, 0)).size() > 0 and _on_axis(cell, Vector2i(0, 1)).size() > 0


func is_zebra(cell: Vector3i) -> bool:
	return tile_name(cell) == ZEBRA_TILE


func kind(cell: Vector3i) -> Kind:
	return _kinds.get(cell, Kind.STREET)


## Speed limit on this cell (km/h); street speed off the road.
func speed_limit_kmh(cell: Vector3i) -> float:
	return _speeds.get(cell, SPEED_LIMIT_KMH[Kind.STREET])


## Speed limit on this cell (m/s).
func speed_limit(cell: Vector3i) -> float:
	return speed_limit_kmh(cell) / 3.6


## True if the speed limit of this cell was chosen for this placed tile (Build dock).
func has_chosen_speed(cell: Vector3i) -> bool:
	return _chosen_speeds.has(cell)


## True if a road user of this kind ("auto", "bus", "fiets", ...) may come on the cell.
func allows(cell: Vector3i, vehicle_kind: String) -> bool:
	var allowed := allowed_kinds(cell)
	return vehicle_kind in allowed or (vehicle_kind == "bus" and "auto" in allowed)


## Road cell at map cell (x, z) on this level or, onto or off a ramp, up to
## `max_level_change` levels up or down (one per cell a ramp spans); NONE if there is
## none. `from_cell`: the cell it is reached from (for the ramp check), or NONE.
func find(x: int, z: int, level: int, from_cell := NONE, max_level_change := 1) -> Vector3i:
	var same := Vector3i(x, level, z)
	if _lanes.has(same):
		return same
	for level_change in range(1, max_level_change + 1):
		for direction in [1, -1]:
			var other := Vector3i(x, level + direction * level_change, z)
			if _lanes.has(other) and (_rises.has(other) or _rises.has(from_cell)):
				return other
	return NONE


## The road cell one step from `cell` in `heading`, or NONE.
func step(cell: Vector3i, heading: Vector2i) -> Vector3i:
	return find(cell.x + heading.x, cell.z + heading.y, cell.y, cell)


## True if the rails of `cell` lead a vehicle that arrives in heading `arriving` out in heading
## `leaving`; true on a tile without rails.
func rail_connects(cell: Vector3i, arriving: Vector2i, leaving: Vector2i) -> bool:
	if not _rails.has(cell):
		return true
	for rail: Array in _rails[cell]:
		if (rail[0] == -arriving and rail[1] == leaving) or (rail[1] == -arriving and rail[0] == leaving):
			return true
	return false


## The headings in which the rails of `cell` leave it, both ways along them.
func rail_headings(cell: Vector3i) -> Array[Vector2i]:
	var headings: Array[Vector2i] = []
	for rail: Array in _rails.get(cell, []):
		for heading: Vector2i in rail:
			if not heading in headings:
				headings.append(heading)
	return headings


## True if rail vehicles of this kind stop beside the tile in `cell` (metadata "platform").
func is_platform_for(cell: Vector3i, vehicle_kind: String) -> bool:
	var item := _ground.get_cell_item(cell)
	if item < 0:
		return false
	var library := _ground.mesh_library
	return vehicle_kind in library.get_meta("platforms", {}).get(library.get_item_name(item), [])


## Road cell with a lane in `heading` for this kind of vehicle nearest to map cell `near`,
## street level first.
func nearest(near: Vector2i, heading: Vector2i, vehicle_kind := "auto") -> Vector3i:
	var best := NONE
	var best_distance := INF
	for cell: Vector3i in _lanes:
		if not lanes(cell).has(heading) or not allows(cell, vehicle_kind):
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
	if _rises.has(cell):
		var rise: Vector2 = Vector2(_rises[cell][0])
		var middle := Vector2(cell.x + 0.5, cell.z + 0.5) * CELL
		var along := clampf((spot - middle).dot(rise) / CELL + 0.5, 0.0, 1.0)
		surface += along * float(_rises[cell][1])
	return surface


## Slope of the road in `heading` on this cell (metres up per metre).
func slope(cell: Vector3i, heading: Vector2i) -> float:
	if not _rises.has(cell):
		return 0.0
	return float(_rises[cell][1]) / CELL * float(Vector2(_rises[cell][0]).dot(Vector2(heading)))


## Name of the ground tile in a cell ("" if empty).
func tile_name(cell: Vector3i) -> String:
	if _ground == null or _ground.mesh_library == null:
		return ""
	var item := _ground.get_cell_item(cell)
	return _ground.mesh_library.get_item_name(item) if item >= 0 else ""


# ------------------------------------------------------------------ reading the tiles

## Lanes, kinds, ramps and vehicle kinds of every ground cell whose tile has traffic.
func _read_tiles() -> void:
	var library := _ground.mesh_library
	var traffic: Dictionary = library.get_meta("traffic", {})
	var traffic_of_item := {}
	for item in library.get_item_list():
		var item_name := library.get_item_name(item)
		if traffic.has(item_name):
			traffic_of_item[item] = traffic[item_name]
	if traffic_of_item.is_empty():
		push_warning("road network: the ground library has no \"traffic\" metadata (rebuild the libraries)")
	var choices: Dictionary = _ground.get_meta(LANE_CHOICES, {})
	for cell: Vector3i in _ground.get_used_cells():
		var item := _ground.get_cell_item(cell)
		var data: Dictionary = traffic_of_item.get(item, {})
		var turn := _turn_of(cell)
		var choice := _choice_for_tile(choices.get(cell, {}), library.get_item_name(item))
		var chosen: Array = choice.get("lanes", [])
		var sides: Array = chosen if not chosen.is_empty() else data.get("lanes", [])
		_only[cell] = data.get("only", ROAD_USER_KINDS if traffic_of_item.has(item) else [])
		if choice.has("kinds"):
			_only[cell] = choice.kinds
			_chosen_kinds[cell] = true
		if choice.has("speed"):
			_speeds[cell] = float(choice.speed)
			_chosen_speeds[cell] = true
		if data.has("rails"):
			var rails := []
			for rail: String in data.rails:
				rails.append([_flat(turn * LOCAL_HEADINGS[rail[0]]), _flat(turn * LOCAL_HEADINGS[rail[1]])])
			_rails[cell] = rails
		var headings: Array[Vector2i] = []
		for local_name in sides:
			if LOCAL_HEADINGS.has(local_name):
				headings.append(_flat(turn * LOCAL_HEADINGS[local_name]))
		if headings.is_empty():
			continue
		_lanes[cell] = headings
		if not chosen.is_empty():
			_chosen[cell] = true
		else:
			for axis in AXES:
				if _on_axis(cell, axis).size() == 2:
					_from_context.get_or_add(cell, []).append(axis)
		if KIND_NAMES.has(data.get("road", "")):
			_kinds[cell] = KIND_NAMES[data.road]
			if not _speeds.has(cell):
				_speeds[cell] = SPEED_LIMIT_KMH[_kinds[cell]]
		if data.has("speed") and not choice.has("speed"):
			_speeds[cell] = float(data.speed)
		if data.has("rise"):
			_rises[cell] = [_flat(turn * LOCAL_HEADINGS["N"]), float(data.rise)]


## This entry of LANE_CHOICES, or an empty one if it is for another tile.
static func _choice_for_tile(choice: Dictionary, item_name: String) -> Dictionary:
	return choice if choice.get("tile", "") == item_name else {}


## The rotation of the tile in a cell.
func _turn_of(cell: Vector3i) -> Basis:
	return _ground.get_basis_with_orthogonal_index(_ground.get_cell_item_orientation(cell))


static func _flat(direction: Vector3) -> Vector2i:
	return Vector2i(roundi(direction.x), roundi(direction.z))


## The headings of a cell along one axis (none, one, or both ways).
func _on_axis(cell: Vector3i, axis: Vector2i) -> Array[Vector2i]:
	var headings: Array[Vector2i] = []
	for heading: Vector2i in _lanes.get(cell, []):
		if heading == axis or heading == -axis:
			headings.append(heading)
	return headings


# ------------------------------------------------------------------ two-way lanes

## Gives the cells that are two-way on an axis one direction on it, from the road
## around them, in rounds (a decided lane helps decide its neighbours).
func _decide_two_way_lanes() -> void:
	for round_number in MAX_ROUNDS:
		var decided := {}   # [cell, axis] -> heading
		for cell: Vector3i in _from_context:
			for axis: Vector2i in _from_context[cell]:
				if _on_axis(cell, axis).size() < 2:
					continue
				var heading := _direction_along(cell, axis)
				if heading == Vector2i.ZERO:
					heading = _direction_from_beside(cell, axis)
				if heading != Vector2i.ZERO:
					decided[[cell, axis]] = heading
		if decided.is_empty():
			break
		for key in decided:
			var cell: Vector3i = key[0]
			var heading: Vector2i = decided[key]
			var headings: Array = _lanes[cell]
			headings.erase(-heading)
	# what is still open and has no lane with a direction anywhere along it (plain asphalt
	# in a street, crosswise; a stub between two kerbs) leads nowhere: no lane on that axis
	var dead_ends := []
	for cell: Vector3i in _from_context:
		for axis: Vector2i in _from_context[cell]:
			if _on_axis(cell, axis).size() == 2 and _direction_along(cell, axis) == Vector2i.ZERO:
				dead_ends.append([cell, axis])
	for dead_end in dead_ends:
		var headings: Array = _lanes[dead_end[0]]
		headings.erase(dead_end[1])
		headings.erase(-dead_end[1])
		if headings.is_empty():
			_lanes.erase(dead_end[0])


## True if the next cell either way along `axis` has a lane on that axis.
func _has_road_along(cell: Vector3i, axis: Vector2i) -> bool:
	for direction in [axis, -axis]:
		var next_cell := step(cell, direction)
		if next_cell != NONE and _on_axis(next_cell, axis).size() > 0:
			return true
	return false


## The direction of the nearest one-way lane along the same line (both ways, through
## two-way cells), or ZERO. The nearer one wins; the one ahead on a tie.
func _direction_along(cell: Vector3i, axis: Vector2i) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := 1 << 30
	for direction in [axis, -axis]:
		var current := cell
		var distance := 0
		while distance < best_distance:
			var next_cell := step(current, direction)
			if next_cell == NONE:
				break
			distance += 1
			var headings := _on_axis(next_cell, axis)
			if headings.size() == 1:
				best = headings[0]
				best_distance = distance
				break
			if headings.is_empty():
				break
			current = next_cell
	return best


## The direction from the lanes alongside (left and right on the same level): the one
## they agree on when they are one-way, else driving on the right at the edge of the
## road (the lane with the road only on its left); ZERO if that doesn't decide it, or
## if no road runs along the axis through the cell.
func _direction_from_beside(cell: Vector3i, axis: Vector2i) -> Vector2i:
	if not _has_road_along(cell, axis):
		return Vector2i.ZERO   # no road runs this way through the cell
	var left := Vector2i(axis.y, -axis.x)     # to the left when driving along +axis
	var found := {}
	var road_left := false
	var road_right := false
	for side in [left, -left]:
		var beside := Vector3i(cell.x + side.x, cell.y, cell.z + side.y)
		var headings := _on_axis(beside, axis)
		if headings.is_empty():
			continue
		if side == left:
			road_left = true
		else:
			road_right = true
		if headings.size() == 1:
			found[headings[0]] = true
	if found.size() == 1:
		return found.keys()[0]
	if found.is_empty() and road_left != road_right:
		# driving on the right: the road to its left is the opposite lane
		return axis if road_left else -axis
	return Vector2i.ZERO


# ------------------------------------------------------------------ kinds of road

## Cells without a kind or speed limit of their own (markings, crossings) take that of the
## nearest cell along their lanes that has one.
func _decide_kinds() -> void:
	_pass_on_along_lanes(_kinds)
	_pass_on_along_lanes(_speeds)


## Fills in `values` (road cell -> value) for the cells without one, from the nearest cell
## along their lanes that has one.
func _pass_on_along_lanes(values: Dictionary) -> void:
	var decided := {}
	for cell: Vector3i in _lanes:
		if values.has(cell):
			continue
		var best_distance := 1 << 30
		for heading: Vector2i in _lanes[cell]:
			for direction in [heading, -heading]:
				var current := cell
				var distance := 0
				while distance < best_distance and distance < 64:
					var next_cell := step(current, direction)
					if next_cell == NONE:
						break
					distance += 1
					if values.has(next_cell):
						decided[cell] = values[next_cell]
						best_distance = distance
						break
					current = next_cell
	for cell in decided:
		values[cell] = decided[cell]
