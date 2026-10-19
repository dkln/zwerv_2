extends SceneTree
## Coverage: shows which tiles of each library are used in context in the example map
## (everything outside the tile catalogue: cells with z below the root's "catalog_start_m"
## meta, in metres). Prints up to three unused tiles per group and a TOTAL line.
## usage: Godot --headless --script tools/coverage.gd

const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self)
	var sc: Node = load(Common.WORLD).instantiate()
	var limit: float = sc.get_meta("catalog_start_m", 400.0)
	var total := 0
	var used_total := 0
	for layer_name in Common.LAYERS:
		var gm: GridMap = sc.get_node(layer_name)
		var cell_depth := gm.cell_size.z
		var used := {}   # item id -> true
		for c in gm.get_used_cells():
			if c.z * cell_depth < limit:
				used[gm.get_cell_item(c)] = true
		var lib := gm.mesh_library
		var groups := {}   # first path segment of the item name -> unused count
		for id in lib.get_item_list():
			if not used.has(id):
				var g: String = lib.get_item_name(id).split("/")[0]
				groups[g] = groups.get(g, 0) + 1
				if groups[g] <= 3:
					print("  unused: ", lib.get_item_name(id))
		var n := lib.get_item_list().size()
		total += n
		used_total += used.size()
		print("%s: %d of %d used; unused per group: %s" % [layer_name, used.size(), n, groups])
	print("TOTAL %d of %d" % [used_total, total])
	sc.free()
	quit()
