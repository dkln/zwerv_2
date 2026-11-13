extends "res://tests/integration/support/town_test.gd"
## Finds pieces of the city that stand in each other (walls through walls, flickering where
## their faces meet): for every item of the Gebouwen, Grond (above street level), Details and
## Props GridMaps of the town the box of its mesh in the world, then every pair from
## two different items whose boxes overlap by more than CLASH_DEPTH on all three axes, or
## whose faces lie in the same plane while they overlap (z-fighting). Prints the pairs of
## tile names with how often they clash and a few places (metres), worst first. A report to
## read (it judges nothing but that the town has pieces), so a run of its own.
##   tests/run_integration_tests.sh clash [-- <max pairs to list>]

## Metres two boxes must overlap on every axis to count as standing in each other.
const CLASH_DEPTH := 0.3
## Metres within which two parallel faces count as one plane, and the overlap they need.
const SAME_PLANE := 0.02
const PLANE_OVERLAP := 0.5
## Size of the buckets of the spatial hash (metres).
const BUCKET := 4.0
## Items that are meant to overlap others (ground pieces, grass, water, roofs on top).
const IGNORED_PREFIXES := ["natuur/", "water/"]


static func world_options() -> Dictionary:
	return {"own_process": true}


## Lists the pairs of tiles of the town that stand in each other or share a plane, worst
## first (argument 0: how many pairs to list, default 40).
func test_report_the_pieces_standing_in_each_other(test) -> void:
	var listed := int(argument(0, "40"))
	var boxes: Array = []   # [AABB, tile name, layer]
	for layer_name in ["Gebouwen", "Grond", "Details", "Props"]:
		var grid := scene.get_node_or_null(layer_name) as GridMap
		if grid == null:
			continue
		var library := grid.mesh_library
		var mesh_boxes := {}
		for cell in grid.get_used_cells():
			if layer_name == "Grond" and cell.y <= 0:
				continue
			var item := grid.get_cell_item(cell)
			var tile_name := library.get_item_name(item)
			if IGNORED_PREFIXES.any(func(prefix: String) -> bool: return tile_name.begins_with(prefix)):
				continue
			if not mesh_boxes.has(item):
				var mesh := library.get_item_mesh(item)
				mesh_boxes[item] = library.get_item_mesh_transform(item) * mesh.get_aabb() if mesh else AABB()
			var local_box: AABB = mesh_boxes[item]
			if local_box.size == Vector3.ZERO:
				continue
			var turn := grid.get_basis_with_orthogonal_index(grid.get_cell_item_orientation(cell))
			var world := grid.global_transform * Transform3D(turn, grid.map_to_local(cell))
			boxes.append([world * local_box, tile_name, layer_name])
	print("stukken: ", boxes.size())
	test.check(not boxes.is_empty(), "de stad heeft stukken om te vergelijken (%d)" % boxes.size())
	var buckets := {}
	for index in boxes.size():
		var box: AABB = boxes[index][0]
		for bucket_x in range(floori(box.position.x / BUCKET), floori(box.end.x / BUCKET) + 1):
			for bucket_z in range(floori(box.position.z / BUCKET), floori(box.end.z / BUCKET) + 1):
				var key := Vector2i(bucket_x, bucket_z)
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(index)
	var pairs := {}   # "a | b" -> [count, places]
	var seen := {}
	for key in buckets:
		var members: Array = buckets[key]
		for first_index in members.size():
			for second_index in range(first_index + 1, members.size()):
				var first: int = members[first_index]
				var second: int = members[second_index]
				var pair_key := Vector2i(mini(first, second), maxi(first, second))
				if seen.has(pair_key):
					continue
				seen[pair_key] = true
				# pieces of one building sit side by side by design
				if boxes[first][2] == "Gebouwen" and boxes[second][2] == "Gebouwen" \
						and (boxes[first][1] as String).get_slice("/", 0) == (boxes[second][1] as String).get_slice("/", 0):
					continue
				if boxes[first][2] == boxes[second][2] and boxes[first][2] != "Gebouwen" and boxes[first][2] != "Grond":
					continue   # props among props, details among details
				var kind := _clash(boxes[first][0], boxes[second][0])
				if kind == "":
					continue
				var names := [boxes[first][1], boxes[second][1]]
				names.sort()
				var layers := [boxes[first][2], boxes[second][2]]
				layers.sort()
				var label := "%s  |  %s  (%s, %s/%s)" % [names[0], names[1], kind, layers[0], layers[1]]
				if not pairs.has(label):
					pairs[label] = [0, []]
				pairs[label][0] += 1
				if pairs[label][1].size() < 3:
					var centre: Vector3 = (boxes[first][0] as AABB).intersection(boxes[second][0]).get_center()
					pairs[label][1].append("(%.0f, %.0f, %.0f)" % [centre.x, centre.y, centre.z])
	var labels := pairs.keys()
	labels.sort_custom(func(first_label: String, second_label: String) -> bool: return pairs[first_label][0] > pairs[second_label][0])
	print("botsende paren: %d soorten, %d keer" % [labels.size(), pairs.values().reduce(func(total, entry) -> int: return total + entry[0], 0)])
	for label_index in mini(listed, labels.size()):
		var label: String = labels[label_index]
		print("%5d  %s  bij %s" % [pairs[label][0], label, ", ".join(pairs[label][1])])


## "door" if the boxes stand deep in each other, "vlak" if two faces lie in one plane
## while the boxes overlap there, else "".
static func _clash(first: AABB, second: AABB) -> String:
	var overlap := first.intersection(second)
	if overlap.size == Vector3.ZERO:
		# touching boxes: a face of each in the same plane, facing each other, is fine
		return ""
	if overlap.size.x > CLASH_DEPTH and overlap.size.y > CLASH_DEPTH and overlap.size.z > CLASH_DEPTH:
		return "door"
	for axis in 3:
		for first_side in [first.position[axis], first.end[axis]]:
			for second_side in [second.position[axis], second.end[axis]]:
				if absf(first_side - second_side) < SAME_PLANE:
					var other_axes := [0, 1, 2]
					other_axes.erase(axis)
					if overlap.size[other_axes[0]] > PLANE_OVERLAP and overlap.size[other_axes[1]] > PLANE_OVERLAP:
						return "vlak"
	return ""
