extends RefCounted
## Where the traffic lights stand (the layout layer of scripts/traffic/traffic_lights.gd):
## which lights belong to one intersection (the ones within `cluster` metres of each other,
## chained), the middle of every intersection, and the intersection nearest a spot. Plain
## geometry on the positions of the light props (metres); x and z count, the height does not.
##   const TrafficLightsLayout = preload("res://scripts/traffic/traffic_lights_layout.gd")

## No intersection (nearest).
const NONE := -1


## The intersection of every light (an index, counted from 0 in the order their first light
## comes in `positions`): lights closer than `cluster` metres to each other, and on along
## such lights, are one intersection.
static func groups(positions: Array, cluster: float) -> Array[int]:
	var group_of: Array[int] = []
	group_of.resize(positions.size())
	group_of.fill(NONE)
	var group_count := 0
	for first_index in positions.size():
		if group_of[first_index] != NONE:
			continue
		group_of[first_index] = group_count
		var todo := [first_index]
		while not todo.is_empty():
			var here: Vector3 = positions[todo.pop_back()]
			for other_index in positions.size():
				if group_of[other_index] == NONE and flat_distance(here, positions[other_index]) <= cluster:
					group_of[other_index] = group_count
					todo.append(other_index)
		group_count += 1
	return group_of


## How many intersections `group_of` (groups) holds.
static func group_count(group_of: Array) -> int:
	var highest := NONE
	for group: int in group_of:
		highest = maxi(highest, group)
	return highest + 1


## The index of the first light of every intersection.
static func first_lights(group_of: Array) -> Array[int]:
	var firsts: Array[int] = []
	for light_index in group_of.size():
		if int(group_of[light_index]) == firsts.size():
			firsts.append(light_index)
	return firsts


## The middle of every intersection: the mean position of its lights.
static func centres(positions: Array, group_of: Array) -> Array[Vector3]:
	var middles: Array[Vector3] = []
	for group in group_count(group_of):
		var sum := Vector3.ZERO
		var lights := 0
		for light_index in positions.size():
			if int(group_of[light_index]) == group:
				sum += positions[light_index]
				lights += 1
		middles.append(sum / maxi(lights, 1))
	return middles


## The intersection of `among` (indices into `middles`, the middles of the intersections)
## that lies nearest `spot`, within `radius` metres (the later one of `among` on a tie); NONE
## when there is none.
static func nearest(middles: Array, among: Array, spot: Vector3, radius: float) -> int:
	var best := NONE
	var best_distance := radius
	for group: int in among:
		var distance := flat_distance(middles[group], spot)
		if distance <= best_distance:
			best_distance = distance
			best = group
	return best


## Metres between two spots along x and z.
static func flat_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x - to.x, from.z - to.z).length()
