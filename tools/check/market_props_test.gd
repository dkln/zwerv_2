extends SceneTree
## The street sellers' carts and market stalls (props/markt/, tools/voxgen/tiles/street_carts.py)
## in the town: every one of them stands somewhere (scenes/stad.tscn), on pavement or a square,
## its collider the box round its mesh, overlapping no other prop and no building.
## usage: tools/godot.sh --headless --script tools/check/market_props_test.gd

const Common = preload("res://tools/tool_common.gd")
const KINDS := ["frietkar", "draaiorgel", "loempiakar", "ijscokar", "kraam_groente", "kraam_fruit",
	"kraam_bloemen", "kraam_kaas", "kraam_vis", "kraam_stoffen"]

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 120)
	var scene := Common.instantiate(Common.CITY)
	get_root().add_child(scene)
	await process_frame
	var props: GridMap = scene.get_node("Props")
	var ground: GridMap = scene.get_node("Grond")
	var buildings: GridMap = scene.get_node("Gebouwen")
	var library := props.mesh_library
	var boxes := []   # [cell, item name, world box]
	for cell in props.get_used_cells():
		var item := props.get_cell_item(cell)
		boxes.append([cell, library.get_item_name(item), _world_box(props, cell, item)])
	for kind: String in KINDS:
		var placed := boxes.filter(func(entry: Array) -> bool: return entry[1] == "markt/" + kind)
		_check(not placed.is_empty(), "%s staat in de stad (%d x)" % [kind, placed.size()])
		var item := library.find_item_by_name("markt/" + kind)
		var shapes := library.get_item_shapes(item)
		var mesh_box := library.get_item_mesh(item).get_aabb()
		# the blocks of the props (library_builder._block_shapes): inside the model, and all
		# together as wide, deep and high as it
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
		_check(fits, "%s: botsvorm volgt het model in blokken (%d, samen %s, model %s)" % [kind, shapes.size() / 2, together.size, mesh_box.size])
		for entry: Array in placed:
			var box: AABB = entry[2]
			var middle := box.get_center()
			var ground_cell := ground.local_to_map(ground.to_local(Vector3(middle.x, 0.2, middle.z)))
			var under := library_name(ground, Vector3i(ground_cell.x, 0, ground_cell.z))
			_check(under.begins_with("plein/") or under.begins_with("stoep/"), "%s bij %s staat op %s" % [kind, entry[0], under])
			for other: Array in boxes:
				if other[0] == entry[0]:
					continue
				var overlap: AABB = box.grow(-0.05).intersection(other[2])
				if overlap.has_volume():
					_check(false, "%s bij %s overlapt %s" % [kind, entry[0], other[1]])
			for corner_index in 4:
				var corner := Vector3(box.position.x if corner_index % 2 == 0 else box.end.x, 1.0,
						box.position.z if corner_index < 2 else box.end.z)
				var building_cell := buildings.local_to_map(buildings.to_local(corner))
				if buildings.get_cell_item(building_cell) != GridMap.INVALID_CELL_ITEM:
					_check(false, "%s bij %s staat in een gebouw" % [kind, entry[0]])
	print("markt ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


static func library_name(grid: GridMap, cell: Vector3i) -> String:
	var item := grid.get_cell_item(cell)
	return grid.mesh_library.get_item_name(item) if item != GridMap.INVALID_CELL_ITEM else "(niets)"


## The box round a prop's mesh in the world, turned as it is placed.
static func _world_box(grid: GridMap, cell: Vector3i, item: int) -> AABB:
	var mesh := grid.mesh_library.get_item_mesh(item)
	var turned := Transform3D(grid.get_basis_with_orthogonal_index(grid.get_cell_item_orientation(cell)), grid.map_to_local(cell))
	return grid.global_transform * (turned * mesh.get_aabb())


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("  FOUT  " + what)
		_problems.append(what)
	elif what.contains("staat in de stad") or what.contains("botsvorm"):
		print("  ok    " + what)
