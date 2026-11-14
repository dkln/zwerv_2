@tool
extends RefCounted
## The logic of the road network (the rules layer of scripts/traffic/road_network.gd, which
## reads the ground tiles and answers the vehicles; road_network_layout.gd is where the road
## surface lies): what a tile gives its cell (its lanes turned with the tile, who may come on
## it, its speed limit, rails and ramp), the road cell a step on (onto and off ramps), which
## way a two-way cell goes from the road around it, the kind of road and the speed limit
## passed on along the lanes, who is allowed where and how rails join. Plain functions on
## the tables of the network: `lanes` (road cell -> Array of headings) and `rises` (ramp
## cell -> [heading it rises in, metres]). Headings are Vector2i on the map: x = east,
## y = south. (@tool: the editor shows the lanes, lane_arrows.gd.)
##   const RoadNetworkRules = preload("res://scripts/traffic/road_network_rules.gd")

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
## The kinds of road users a tile can allow (Vehicle.vehicle_kind): "auto" (with its buses,
## the motorbike and the microcar), "brommer" (mopeds, scooters), "fiets" (cyclists, the
## fatbike) and "voetganger" (no walkers drive the network yet).
const ROAD_USER_KINDS: Array[String] = ["auto", "brommer", "fiets", "voetganger"]
const ZEBRA_TILE := "weg/zebrapad"
## No road cell (returned by find and step).
const NONE := Vector3i(0, -1000, 0)
const AXES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
## Rounds of deciding two-way lanes from the road around them.
const MAX_ROUNDS := 8
## How far along its lanes a cell looks for a kind of road or a speed limit (cells).
const PASS_ON_REACH := 64
## Levels a street-level cell counts as further off than one on the ground (nearest).
const LEVEL_WEIGHT := 100.0


# ------------------------------------------------------------------ reading a tile

## A direction on the map as a heading (x = east, y = south).
static func flat(direction: Vector3) -> Vector2i:
	return Vector2i(roundi(direction.x), roundi(direction.z))


## The heading on the map of a side ("N" = forward, its back) of a tile turned by `turn`.
static func heading_of_side(turn: Basis, side: String) -> Vector2i:
	return flat(turn * LOCAL_HEADINGS[side])


## This entry of LANE_CHOICES, or an empty one if it is for another tile.
static func choice_for_tile(choice: Dictionary, item_name: String) -> Dictionary:
	return choice if choice.get("tile", "") == item_name else {}


## What the tile in a cell gives the network. `data`: the "traffic" metadata of the tile
## (empty: `has_traffic` false, a tile for nobody); `choice`: what was chosen for this placed
## tile (choice_for_tile); `turn`: the rotation of the tile. Returns
##   only: the kinds of road user that may come on it,
##   chosen_kinds, chosen_speed, chosen: true if those were chosen for this placed tile,
##   headings: its lanes on the map (empty: no road cell),
##   and only when it has them: speed (km/h), rails (pairs of headings out of the cell),
##   and for a road cell open_axes (the axes its tile leaves two-way), kind (Kind) and
##   rise ([heading it rises in, metres]).
static func read_tile(data: Dictionary, choice: Dictionary, turn: Basis, has_traffic: bool) -> Dictionary:
	var chosen_lanes: Array = choice.get("lanes", [])
	var sides: Array = chosen_lanes if not chosen_lanes.is_empty() else data.get("lanes", [])
	var reading := {
		"only": data.get("only", ROAD_USER_KINDS if has_traffic else []),
		"chosen_kinds": choice.has("kinds"),
		"chosen_speed": choice.has("speed"),
		"chosen": false,
	}
	if choice.has("kinds"):
		reading.only = choice.kinds
	if choice.has("speed"):
		reading.speed = float(choice.speed)
	if data.has("rails"):
		var rails := []
		for rail: String in data.rails:
			rails.append([heading_of_side(turn, rail[0]), heading_of_side(turn, rail[1])])
		reading.rails = rails
	var headings: Array[Vector2i] = []
	for local_name in sides:
		if LOCAL_HEADINGS.has(local_name):
			headings.append(heading_of_side(turn, local_name))
	reading.headings = headings
	if headings.is_empty():
		return reading
	if not chosen_lanes.is_empty():
		reading.chosen = true
	else:
		var open_axes := []
		for axis in AXES:
			if on_axis(headings, axis).size() == 2:
				open_axes.append(axis)
		if not open_axes.is_empty():
			reading.open_axes = open_axes
	if KIND_NAMES.has(data.get("road", "")):
		reading.kind = KIND_NAMES[data.road]
		if not reading.has("speed"):
			reading.speed = SPEED_LIMIT_KMH[reading.kind]
	if data.has("speed") and not choice.has("speed"):
		reading.speed = float(data.speed)
	if data.has("rise"):
		reading.rise = [heading_of_side(turn, "N"), float(data.rise)]
	return reading


# ------------------------------------------------------------------ queries

## Those of `headings` along one axis (none, one, or both ways).
static func on_axis(headings: Array, axis: Vector2i) -> Array[Vector2i]:
	var along: Array[Vector2i] = []
	for heading: Vector2i in headings:
		if heading == axis or heading == -axis:
			along.append(heading)
	return along


## True if a cell with these lanes has lanes on both axes.
static func is_crossing(headings: Array) -> bool:
	return on_axis(headings, Vector2i(1, 0)).size() > 0 and on_axis(headings, Vector2i(0, 1)).size() > 0


## True if `heading` lies along one of `open_axes` (either way).
static func is_along(open_axes: Array, heading: Vector2i) -> bool:
	for axis: Vector2i in open_axes:
		if heading == axis or heading == -axis:
			return true
	return false


## True if a road user of this kind ("auto", "bus", "fiets", ...) may come on a cell that
## allows `allowed`: "auto" also lets buses on.
static func allows(allowed: Array, vehicle_kind: String) -> bool:
	return vehicle_kind in allowed or (vehicle_kind == "bus" and "auto" in allowed)


## Speed in m/s of a speed in km/h.
static func metres_per_second(kmh: float) -> float:
	return kmh / 3.6


## Road cell at map cell (x, z) on this level or, onto or off a ramp, up to
## `max_level_change` levels up or down (one per cell a ramp spans); NONE if there is
## none. `from_cell`: the cell it is reached from (for the ramp check), or NONE.
static func find(lanes: Dictionary, rises: Dictionary, x: int, z: int, level: int, from_cell := NONE, max_level_change := 1) -> Vector3i:
	var same := Vector3i(x, level, z)
	if lanes.has(same):
		return same
	for level_change in range(1, max_level_change + 1):
		for direction in [1, -1]:
			var other := Vector3i(x, level + direction * level_change, z)
			if lanes.has(other) and (rises.has(other) or rises.has(from_cell)):
				return other
	return NONE


## The road cell one step from `cell` in `heading`, or NONE.
static func step(lanes: Dictionary, rises: Dictionary, cell: Vector3i, heading: Vector2i) -> Vector3i:
	return find(lanes, rises, cell.x + heading.x, cell.z + heading.y, cell.y, cell)


## True if rails `rails` (pairs of headings out of a cell) lead a vehicle that arrives in
## heading `arriving` out in heading `leaving`.
static func rail_connects(rails: Array, arriving: Vector2i, leaving: Vector2i) -> bool:
	for rail: Array in rails:
		if (rail[0] == -arriving and rail[1] == leaving) or (rail[1] == -arriving and rail[0] == leaving):
			return true
	return false


## The headings in which `rails` leave their cell, both ways along them.
static func rail_headings(rails: Array) -> Array[Vector2i]:
	var headings: Array[Vector2i] = []
	for rail: Array in rails:
		for heading: Vector2i in rail:
			if not heading in headings:
				headings.append(heading)
	return headings


## Road cell with a lane in `heading` for this kind of vehicle nearest to map cell `near`,
## street level first; NONE when there is none. `only`: cell -> the kinds allowed on it.
static func nearest(lanes: Dictionary, only: Dictionary, near: Vector2i, heading: Vector2i, vehicle_kind := "auto") -> Vector3i:
	var best := NONE
	var best_distance := INF
	for cell: Vector3i in lanes:
		if not lanes[cell].has(heading) or not allows(only.get(cell, []), vehicle_kind):
			continue
		var distance := Vector2(cell.x - near.x, cell.z - near.y).length() + absf(cell.y) * LEVEL_WEIGHT
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


# ------------------------------------------------------------------ two-way lanes

## Gives the cells that are two-way on an axis (`open_axes`: cell -> its open axes) one
## direction on it, from the road around them, in rounds (a decided lane helps decide its
## neighbours). Changes `lanes` in place.
static func decide_two_way_lanes(lanes: Dictionary, open_axes: Dictionary, rises: Dictionary) -> void:
	for round_number in MAX_ROUNDS:
		var decided := {}   # [cell, axis] -> heading
		for cell: Vector3i in open_axes:
			for axis: Vector2i in open_axes[cell]:
				if on_axis(lanes.get(cell, []), axis).size() < 2:
					continue
				var heading := direction_along(lanes, rises, cell, axis)
				if heading == Vector2i.ZERO:
					heading = direction_from_beside(lanes, rises, cell, axis)
				if heading != Vector2i.ZERO:
					decided[[cell, axis]] = heading
		if decided.is_empty():
			break
		for key in decided:
			var cell: Vector3i = key[0]
			var heading: Vector2i = decided[key]
			var headings: Array = lanes[cell]
			headings.erase(-heading)
	# what is still open and has no lane with a direction anywhere along it (plain asphalt
	# in a street, crosswise; a stub between two kerbs) leads nowhere: no lane on that axis
	var dead_ends := []
	for cell: Vector3i in open_axes:
		for axis: Vector2i in open_axes[cell]:
			if on_axis(lanes.get(cell, []), axis).size() == 2 and direction_along(lanes, rises, cell, axis) == Vector2i.ZERO:
				dead_ends.append([cell, axis])
	for dead_end in dead_ends:
		var headings: Array = lanes[dead_end[0]]
		headings.erase(dead_end[1])
		headings.erase(-dead_end[1])
		if headings.is_empty():
			lanes.erase(dead_end[0])


## True if the next cell either way along `axis` has a lane on that axis.
static func has_road_along(lanes: Dictionary, rises: Dictionary, cell: Vector3i, axis: Vector2i) -> bool:
	for direction in [axis, -axis]:
		var next_cell := step(lanes, rises, cell, direction)
		if next_cell != NONE and on_axis(lanes.get(next_cell, []), axis).size() > 0:
			return true
	return false


## The direction of the nearest one-way lane along the same line (both ways, through
## two-way cells), or ZERO. The nearer one wins; the one ahead on a tie.
static func direction_along(lanes: Dictionary, rises: Dictionary, cell: Vector3i, axis: Vector2i) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := 1 << 30
	for direction in [axis, -axis]:
		var current := cell
		var distance := 0
		while distance < best_distance:
			var next_cell := step(lanes, rises, current, direction)
			if next_cell == NONE:
				break
			distance += 1
			var headings := on_axis(lanes.get(next_cell, []), axis)
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
static func direction_from_beside(lanes: Dictionary, rises: Dictionary, cell: Vector3i, axis: Vector2i) -> Vector2i:
	if not has_road_along(lanes, rises, cell, axis):
		return Vector2i.ZERO   # no road runs this way through the cell
	var left := Vector2i(axis.y, -axis.x)     # to the left when driving along +axis
	var found := {}
	var road_left := false
	var road_right := false
	for side in [left, -left]:
		var beside := Vector3i(cell.x + side.x, cell.y, cell.z + side.y)
		var headings := on_axis(lanes.get(beside, []), axis)
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

## Fills in `values` (road cell -> value: a kind of road, a speed limit) for the cells
## without one, from the nearest cell along their lanes that has one. Changes `values` in
## place.
static func pass_on_along_lanes(values: Dictionary, lanes: Dictionary, rises: Dictionary) -> void:
	var decided := {}
	for cell: Vector3i in lanes:
		if values.has(cell):
			continue
		var best_distance := 1 << 30
		for heading: Vector2i in lanes[cell]:
			for direction in [heading, -heading]:
				var current := cell
				var distance := 0
				while distance < best_distance and distance < PASS_ON_REACH:
					var next_cell := step(lanes, rises, current, direction)
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
