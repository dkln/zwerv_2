extends "res://tests/integration/support/town_test.gd"
## The street sellers' carts and market stalls (props/markt/, tools/voxgen/tiles/street_carts.py)
## in the town: every one of them stands somewhere (scenes/stad.tscn), on pavement or a square,
## its collider the box round its mesh, overlapping no other prop and no building.
##   tests/run_integration_tests.sh market_props

const KINDS := ["frietkar", "draaiorgel", "loempiakar", "ijscokar", "kraam_groente", "kraam_fruit",
	"kraam_bloemen", "kraam_kaas", "kraam_vis", "kraam_stoffen"]


## The name of the tile in `cell` of `grid` ("(niets)" for an empty cell).
static func _library_name(grid: GridMap, cell: Vector3i) -> String:
	var item := grid.get_cell_item(cell)
	return grid.mesh_library.get_item_name(item) if item != GridMap.INVALID_CELL_ITEM else "(niets)"


## The box round a prop's mesh in the world, turned as it is placed.
static func _world_box(grid: GridMap, cell: Vector3i, item: int) -> AABB:
	var mesh := grid.mesh_library.get_item_mesh(item)
	var turned := Transform3D(grid.get_basis_with_orthogonal_index(grid.get_cell_item_orientation(cell)), grid.map_to_local(cell))
	return grid.global_transform * (turned * mesh.get_aabb())


## Every prop of the town: [cell, item name, world box].
func _prop_boxes() -> Array:
	var props: GridMap = scene.get_node("Props")
	var boxes := []
	for cell in props.get_used_cells():
		var item := props.get_cell_item(cell)
		boxes.append([cell, props.mesh_library.get_item_name(item), _world_box(props, cell, item)])
	return boxes


## The carts and stalls among `boxes` (the props of markt/ in KINDS).
func _market_props(boxes: Array) -> Array:
	return boxes.filter(func(entry: Array) -> bool:
		return String(entry[1]).begins_with("markt/") and String(entry[1]).trim_prefix("markt/") in KINDS)


## Every kind of cart and stall stands somewhere in the town.
func test_every_kind_stands_in_the_town(test) -> void:
	var boxes := _prop_boxes()
	for kind: String in KINDS:
		var placed := boxes.filter(func(entry: Array) -> bool: return entry[1] == "markt/" + kind)
		test.check(not placed.is_empty(), "%s staat in de stad (%d x)" % [kind, placed.size()])


## The collider of every kind is made of blocks (library_builder._block_shapes) that lie
## inside the model and are together as wide, deep and high as it.
func test_colliders_follow_the_model_in_blocks(test) -> void:
	var library: MeshLibrary = (scene.get_node("Props") as GridMap).mesh_library
	for kind: String in KINDS:
		var item := library.find_item_by_name("markt/" + kind)
		var shapes := library.get_item_shapes(item)
		var mesh_box := library.get_item_mesh(item).get_aabb()
		var together := AABB()
		var inside := shapes.size() >= 2
		for index in range(0, shapes.size(), 2):
			var box := shapes[index] as BoxShape3D
			if box == null:
				inside = false
				continue
			var block := AABB((shapes[index + 1] as Transform3D).origin - box.size * 0.5, box.size)
			inside = inside and mesh_box.grow(0.07).encloses(block)
			together = block if index == 0 else together.merge(block)
		var fits := inside and (together.size - mesh_box.size).length() < 0.15
		test.check(fits, "%s: botsvorm volgt het model in blokken (%d, samen %s, model %s)" % [kind, shapes.size() / 2, together.size, mesh_box.size])


## Every cart and stall stands on pavement or a square.
func test_they_stand_on_pavement_or_a_square(test) -> void:
	var ground: GridMap = scene.get_node("Grond")
	var placed := _market_props(_prop_boxes())
	test.check(not placed.is_empty(), "er staan karren en kramen (%d)" % placed.size())
	for entry: Array in placed:
		var middle := (entry[2] as AABB).get_center()
		var ground_cell := ground.local_to_map(ground.to_local(Vector3(middle.x, 0.2, middle.z)))
		var under := _library_name(ground, Vector3i(ground_cell.x, 0, ground_cell.z))
		test.check(under.begins_with("plein/") or under.begins_with("stoep/"), "%s bij %s staat op %s" % [entry[1], entry[0], under])


## No cart or stall overlaps another prop.
func test_they_overlap_no_other_prop(test) -> void:
	var boxes := _prop_boxes()
	var placed := _market_props(boxes)
	var overlapping: Array[String] = []
	for entry: Array in placed:
		var box: AABB = entry[2]
		for other: Array in boxes:
			if other[0] == entry[0]:
				continue
			if box.grow(-0.05).intersection(other[2]).has_volume():
				overlapping.append("%s bij %s overlapt %s" % [entry[1], entry[0], other[1]])
	test.check(not placed.is_empty() and overlapping.is_empty(), "geen kar of kraam overlapt een andere prop %s" % [overlapping])


## No corner of a cart or stall stands in a building.
func test_they_stand_in_no_building(test) -> void:
	var buildings: GridMap = scene.get_node("Gebouwen")
	var placed := _market_props(_prop_boxes())
	var in_building: Array[String] = []
	for entry: Array in placed:
		var box: AABB = entry[2]
		for corner_index in 4:
			var corner := Vector3(box.position.x if corner_index % 2 == 0 else box.end.x, 1.0,
				box.position.z if corner_index < 2 else box.end.z)
			if buildings.get_cell_item(buildings.local_to_map(buildings.to_local(corner))) != GridMap.INVALID_CELL_ITEM:
				in_building.append("%s bij %s staat in een gebouw" % [entry[1], entry[0]])
	test.check(not placed.is_empty() and in_building.is_empty(), "geen kar of kraam staat in een gebouw %s" % [in_building])
