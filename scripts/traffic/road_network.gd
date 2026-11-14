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
## Moving over (the meta MOVE_OVERS of the ground GridMap, {from cell: to cell}): from a
## road cell a vehicle may move over gradually into the lane alongside, reaching it in
## cell `to` (a cell or two forward, one to the side, the same heading): where an exit
## leaves a motorway. Where the lane of `from` goes on, a vehicle chooses (vehicle.gd);
## where it ends there, every vehicle moves over (a lane that leads off the motorway in
## steps, or an on-ramp merging).
##
## Headings are Vector2i on the map: x = east, y = south.

## This script holds the network of one ground GridMap (its tables, read from the tiles) and
## answers the vehicles. The deciding is road_network_rules.gd (what a tile gives, two-way
## lanes, kinds of road, who is allowed), the road surface road_network_layout.gd (heights,
## ramps); what is here under the old names stays for everyone who uses the network.

const RoadNetworkRules = preload("res://scripts/traffic/road_network_rules.gd")
const RoadNetworkLayout = preload("res://scripts/traffic/road_network_layout.gd")

const Kind = RoadNetworkRules.Kind
## Speed limit for cars per kind of road (km/h); a placed tile can have its own (LANE_CHOICES).
const SPEED_LIMIT_KMH := RoadNetworkRules.SPEED_LIMIT_KMH
## Names of the kinds in the tile metadata ("road").
const KIND_NAMES := RoadNetworkRules.KIND_NAMES
## Lane headings of the metadata ("lanes"), on the unturned tile.
const LOCAL_HEADINGS := RoadNetworkRules.LOCAL_HEADINGS
## Meta of the ground GridMap with the lanes chosen per placed tile (see above).
const LANE_CHOICES := &"lane_choices"
## Meta of the ground GridMap with the cells a vehicle can move over from (see above).
const MOVE_OVERS := &"move_overs"
## The kinds of road users a tile can allow (Vehicle.vehicle_kind).
const ROAD_USER_KINDS: Array[String] = RoadNetworkRules.ROAD_USER_KINDS

const CELL := RoadNetworkLayout.CELL
## Top of the road surface above the bottom of its layer (metres; 2 voxels of 0.125 m).
const ROAD_SURFACE := RoadNetworkLayout.ROAD_SURFACE
const ZEBRA_TILE := RoadNetworkRules.ZEBRA_TILE
## No road cell (returned by find and step).
const NONE := RoadNetworkRules.NONE
const AXES: Array[Vector2i] = RoadNetworkRules.AXES
## Rounds of deciding two-way lanes from the road around them.
const MAX_ROUNDS := RoadNetworkRules.MAX_ROUNDS

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
var _move_overs := {}     # road cell -> the road cell it moves over into (MOVE_OVERS)
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
	RoadNetworkRules.decide_two_way_lanes(_lanes, _from_context, _rises)
	# cells without a kind or speed limit of their own (markings, crossings) take that of the
	# nearest cell along their lanes that has one
	RoadNetworkRules.pass_on_along_lanes(_kinds, _lanes, _rises)
	RoadNetworkRules.pass_on_along_lanes(_speeds, _lanes, _rises)
	var move_overs: Dictionary = _ground.get_meta(MOVE_OVERS, {})
	for from_cell: Vector3i in move_overs:
		if _lanes.has(from_cell) and _lanes.has(move_overs[from_cell]):
			_move_overs[from_cell] = move_overs[from_cell]


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
	return RoadNetworkRules.is_along(_from_context.get(cell, []), heading)


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
	return RoadNetworkRules.heading_of_side(_turn_of(cell), side)


func is_crossing(cell: Vector3i) -> bool:
	return RoadNetworkRules.is_crossing(_lanes.get(cell, []))


func is_zebra(cell: Vector3i) -> bool:
	return tile_name(cell) == ZEBRA_TILE


func kind(cell: Vector3i) -> RoadNetworkRules.Kind:
	return _kinds.get(cell, Kind.STREET)


## Speed limit on this cell (km/h); street speed off the road.
func speed_limit_kmh(cell: Vector3i) -> float:
	return _speeds.get(cell, SPEED_LIMIT_KMH[Kind.STREET])


## Speed limit on this cell (m/s).
func speed_limit(cell: Vector3i) -> float:
	return RoadNetworkRules.metres_per_second(speed_limit_kmh(cell))


## True if the speed limit of this cell was chosen for this placed tile (Build dock).
func has_chosen_speed(cell: Vector3i) -> bool:
	return _chosen_speeds.has(cell)


## True if a road user of this kind ("auto", "bus", "fiets", ...) may come on the cell.
func allows(cell: Vector3i, vehicle_kind: String) -> bool:
	return RoadNetworkRules.allows(allowed_kinds(cell), vehicle_kind)


## Road cell at map cell (x, z) on this level or, onto or off a ramp, up to
## `max_level_change` levels up or down (one per cell a ramp spans); NONE if there is
## none. `from_cell`: the cell it is reached from (for the ramp check), or NONE.
func find(x: int, z: int, level: int, from_cell := NONE, max_level_change := 1) -> Vector3i:
	return RoadNetworkRules.find(_lanes, _rises, x, z, level, from_cell, max_level_change)


## The road cell a vehicle on `cell` can move over into (MOVE_OVERS), or NONE.
func move_over_target(cell: Vector3i) -> Vector3i:
	return _move_overs.get(cell, NONE)


## The road cell one step from `cell` in `heading`, or NONE.
func step(cell: Vector3i, heading: Vector2i) -> Vector3i:
	return find(cell.x + heading.x, cell.z + heading.y, cell.y, cell)


## True if the rails of `cell` lead a vehicle that arrives in heading `arriving` out in heading
## `leaving`; true on a tile without rails.
func rail_connects(cell: Vector3i, arriving: Vector2i, leaving: Vector2i) -> bool:
	return not _rails.has(cell) or RoadNetworkRules.rail_connects(_rails[cell], arriving, leaving)


## Every cell with rails.
func rail_cells() -> Array:
	return _rails.keys()


## The rails of `cell`: each a pair of headings out of the cell that it joins.
func rails(cell: Vector3i) -> Array:
	return _rails.get(cell, [])


## The headings in which the rails of `cell` leave it, both ways along them.
func rail_headings(cell: Vector3i) -> Array[Vector2i]:
	return RoadNetworkRules.rail_headings(_rails.get(cell, []))


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
	return RoadNetworkRules.nearest(_lanes, _only, near, heading, vehicle_kind)


## Centre of a cell on the map (metres), at the height of its road surface.
func centre(cell: Vector3i) -> Vector3:
	return RoadNetworkLayout.centre(cell, _rises.get(cell, RoadNetworkLayout.FLAT))


## Height of the road surface of `cell` at map position `spot` (metres, x and z): flat
## at its layer, or rising across a ramp. Cells that are no road count as flat.
func height(cell: Vector3i, spot: Vector2) -> float:
	return RoadNetworkLayout.height(cell, spot, _rises.get(cell, RoadNetworkLayout.FLAT))


## Slope of the road in `heading` on this cell (metres up per metre).
func slope(cell: Vector3i, heading: Vector2i) -> float:
	return RoadNetworkLayout.slope(_rises.get(cell, RoadNetworkLayout.FLAT), heading)


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
		var choice := RoadNetworkRules.choice_for_tile(choices.get(cell, {}), library.get_item_name(item))
		_take_reading(cell, RoadNetworkRules.read_tile(traffic_of_item.get(item, {}), choice, _turn_of(cell), traffic_of_item.has(item)))


## Puts what a tile gives its cell (RoadNetworkRules.read_tile) in the tables.
func _take_reading(cell: Vector3i, reading: Dictionary) -> void:
	_only[cell] = reading.only
	if reading.chosen_kinds:
		_chosen_kinds[cell] = true
	if reading.chosen_speed:
		_chosen_speeds[cell] = true
	if reading.has("speed"):
		_speeds[cell] = reading.speed
	if reading.has("rails"):
		_rails[cell] = reading.rails
	if reading.headings.is_empty():
		return
	_lanes[cell] = reading.headings
	if reading.chosen:
		_chosen[cell] = true
	if reading.has("open_axes"):
		_from_context[cell] = reading.open_axes
	if reading.has("kind"):
		_kinds[cell] = reading.kind
	if reading.has("rise"):
		_rises[cell] = reading.rise


## The rotation of the tile in a cell.
func _turn_of(cell: Vector3i) -> Basis:
	return _ground.get_basis_with_orthogonal_index(_ground.get_cell_item_orientation(cell))
