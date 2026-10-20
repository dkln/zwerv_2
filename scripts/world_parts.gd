extends RefCounted
## The example map in parts. The map is stored as scenes/wereld/deel_01.tscn ..
## deel_NN.tscn, each a strip of the map (north to south) with the four GridMap layers
## (Grond, Gebouwen, Details, Props) at their world position. A part opens quickly in
## the editor and is a Vox Tiles scene of its own, so you build in a part.
##
## The tour scene (scenes/rondleiding.tscn) holds no map: environment, lights, camera
## and helper nodes, plus the metadata of the whole map (districts, places, and
## "part_rows": the tile rows of every part). The tour (scripts/tour.gd) loads one part
## at a time with show_part(): its layers come directly under the root, so DetailNiveau,
## Rook and the tools see one GridMap per layer as before. merge_all() loads every part
## at once (tools that need the whole map, such as tools/coverage.gd).
##
## split() / save_split(): tools/build_example_city.gd builds the map as one scene and
## splits it on saving.

## Folder with the part scenes and their file name (part number from 1).
const PARTS_DIR := "res://scenes/wereld"
const PART_FILE := "deel_%02d.tscn"
## The GridMap layers of a part, in scene order.
const LAYERS := ["Grond", "Gebouwen", "Details", "Props"]
## Ground tile size in metres: parts are cut on ground tile rows.
const TILE := 4.0
## A cut may move this many tile rows from its ideal place to find a quiet row (a street
## or open space, with as few building cells as possible) so buildings aren't cut through.
const CUT_SLACK := 8


## Path of part `index` (from 1).
static func part_path(index: int) -> String:
	return PARTS_DIR.path_join(PART_FILE % index)


## Number of parts of the map in scene `root` (from its "part_rows" metadata).
static func part_count(root: Node) -> int:
	return root.get_meta("part_rows", []).size()


## Part (from 1) holding world position z (metres) in the map of `root`; parts beyond
## the first and last row count as the first and last part. 0 if the map has no parts.
static func part_at(root: Node, z: float) -> int:
	var rows: Array = root.get_meta("part_rows", [])
	var row := floori(z / TILE)
	for i in rows.size():
		if row < rows[i].y or i == rows.size() - 1:
			return i + 1
	return 0


## Shows part `index` in the running scene `root`: frees the layers (and DetailNiveau's
## copies) of the part shown so far, loads the new one, lets DetailNiveau start merging
## it (await Common.wait_for_merge or DetailNiveau.merge_finished), Rook find its
## chimneys and GrondKaart its ground types. Also works on a scene that is not in the tree yet (then the nodes set
## themselves up in _ready).
static func show_part(root: Node, index: int) -> void:
	var dn := root.get_node_or_null("DetailNiveau")
	if dn and dn.has_method("clear"):
		dn.clear()
	load_part(root, index)
	if not root.is_inside_tree():
		return
	if dn and dn.has_method("setup"):
		dn.setup()
	var smoke := root.get_node_or_null("Rook")
	if smoke:
		smoke.set("rescan", true)
	var ground_map := root.get_node_or_null("GrondKaart")
	if ground_map and ground_map.has_method("rebuild"):
		ground_map.rebuild()


## Part (from 1) whose layers are under `root` now; 0 = none (or merge_all).
static func shown_part(root: Node) -> int:
	return root.get_meta("shown_part", 0)


## Replaces the layers directly under `root` by those of part `index`, without
## touching any other node (see show_part). The layers get the "part" metadata (file
## name without extension), which keys DetailNiveau's cache per part.
static func load_part(root: Node, index: int) -> void:
	_remove_layers(root)
	root.set_meta("shown_part", index)
	var part := (load(part_path(index)) as PackedScene).instantiate()
	_adopt_layers(root, part, part_path(index).get_file().get_basename())
	part.free()


## Loads all parts into `root` as one GridMap per layer (the whole map; slow to render).
static func merge_all(root: Node) -> void:
	_remove_layers(root)
	root.set_meta("shown_part", 0)
	var layers := {}   # layer name -> GridMap (from the first part that has it)
	var cells := {}    # layer name -> PackedInt32Array of all parts
	for i in range(1, part_count(root) + 1):
		var part := (load(part_path(i)) as PackedScene).instantiate()
		for gm in part.get_children():
			if not gm is GridMap:
				continue
			if not layers.has(gm.name):
				layers[gm.name] = gm
				cells[gm.name] = PackedInt32Array()
				gm.owner = null
				part.remove_child(gm)
			cells[gm.name].append_array(gm.get("data").get("cells", PackedInt32Array()))
		part.free()
	var holder := Node.new()
	for layer_name in layers:
		var gm: GridMap = layers[layer_name]
		gm.set("data", {"cells": cells[layer_name]})
		holder.add_child(gm)
	_adopt_layers(root, holder, "alles")
	holder.free()


## Frees the GridMaps named in LAYERS directly under root.
static func _remove_layers(root: Node) -> void:
	for layer_name in LAYERS:
		var old := root.get_node_or_null(NodePath(layer_name))
		if old:
			root.remove_child(old)
			old.free()


## Moves the GridMaps of `from` to `root`, right after the lights (where the layers of
## an unsplit map stood), tagged with the "part" metadata `tag`.
static func _adopt_layers(root: Node, from: Node, tag: String) -> void:
	var index := 0
	for n in root.get_children():
		if n is WorldEnvironment or n is DirectionalLight3D:
			index = n.get_index() + 1
	for gm in from.get_children():
		if not gm is GridMap:
			continue
		gm.owner = null
		from.remove_child(gm)
		gm.set_meta("part", tag)
		root.add_child(gm)
		root.move_child(gm, index)
		index += 1


## Splits the GridMaps directly under root into `count` parts along z (north to south),
## each with about the same number of cells. Returns the part roots (Node3D "Deel01"..,
## not in a tree, with copies of the layers holding only their own cells); the GridMaps
## of root are left untouched. Cells north of the first cut (polder) go to the first
## part, cells south of the last to the last part.
static func split(root: Node, count: int) -> Array[Node3D]:
	var maps: Array[GridMap] = []
	for n in root.get_children():
		if n is GridMap:
			maps.append(n)
	var cuts := _cuts(maps, count)
	var parts: Array[Node3D] = []
	for i in count:
		var part := Node3D.new()
		part.name = "Deel%02d" % (i + 1)
		part.set_meta("vox_tiles", true)
		# tile rows of this part (the first and last part also hold everything beyond)
		part.set_meta("rows", Vector2i(cuts[i], cuts[i + 1]))
		parts.append(part)
	for gm in maps:
		var src: PackedInt32Array = gm.get("data").get("cells", PackedInt32Array())
		var per_part: Array[PackedInt32Array] = []
		per_part.resize(count)
		for i in range(0, src.size(), 3):
			var p := _part_of(_row(gm, src[i + 1]), cuts)
			per_part[p].append_array([src[i], src[i + 1], src[i + 2]])
		for p in count:
			var copy := gm.duplicate(0) as GridMap
			copy.clear()
			copy.set("data", {"cells": per_part[p]})
			parts[p].add_child(copy)
			copy.owner = parts[p]
	return parts


## Saves the map `root` (GridMap layers directly under it) split into `count` parts in
## PARTS_DIR, and root itself without the layers, with the rows of every part as
## "part_rows" metadata, to `scene_path`. Old part files with a higher number are
## removed. Returns the first error, or OK.
static func save_split(root: Node, scene_path: String, count: int) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARTS_DIR))
	var result := OK
	var part_rows := []
	var parts := split(root, count)
	for i in parts.size():
		# shown in the editor with the surroundings of the tour scene (addons/vox_tiles/scene_preview.gd)
		parts[i].set_meta("preview_scene", scene_path)
		var ps := PackedScene.new()
		ps.pack(parts[i])
		var err := ResourceSaver.save(ps, part_path(i + 1))
		print("saved: ", part_path(i + 1), " (", err, ")")
		if err != OK and result == OK:
			result = err
		part_rows.append(parts[i].get_meta("rows"))
		parts[i].free()
	var old := count + 1
	while FileAccess.file_exists(part_path(old)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(part_path(old)))
		old += 1
	_remove_layers(root)
	root.set_meta("part_rows", part_rows)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, scene_path)
	print("saved: ", scene_path, " (", err, ")")
	return result if result != OK else err


## Tile row (z / TILE) of a cell, from the second int of its packed data (z in the low
## 16 bits, signed).
static func _row(gm: GridMap, packed: int) -> int:
	var z := packed & 0xFFFF
	if z >= 0x8000:
		z -= 0x10000
	return floori(z * gm.cell_size.z / TILE)


## Index of the part holding tile row `row`; cuts[i] .. cuts[i + 1] is part i.
static func _part_of(row: int, cuts: Array[int]) -> int:
	for i in range(1, cuts.size() - 1):
		if row < cuts[i]:
			return i - 1
	return cuts.size() - 2


## count + 1 row boundaries: the first and last row of the map and count - 1 cuts in
## between. Each cut sits near the row where the cell total reaches its share, moved to
## the row with the fewest building cells (Gebouwen, Details) within CUT_SLACK rows.
static func _cuts(maps: Array[GridMap], count: int) -> Array[int]:
	var weight := {}   # row -> cells (all layers)
	var built := {}    # row -> building cells
	for gm in maps:
		var src: PackedInt32Array = gm.get("data").get("cells", PackedInt32Array())
		var building: bool = gm.name in ["Gebouwen", "Details"]
		for i in range(0, src.size(), 3):
			var r := _row(gm, src[i + 1])
			weight[r] = weight.get(r, 0) + 1
			if building:
				built[r] = built.get(r, 0) + 1
	var rows: Array = weight.keys()
	rows.sort()
	var total := 0
	for r in rows:
		total += weight[r]
	var cuts: Array[int] = [rows[0]]
	var sum := 0
	var k := 1
	for r in rows:
		sum += weight[r]
		while k < count and sum >= total * k / count:
			var best: int = r + 1
			for c in range(r + 1 - CUT_SLACK, r + 2 + CUT_SLACK):
				if c > cuts[-1] and built.get(c, 0) < built.get(best, 0):
					best = c
			cuts.append(maxi(best, cuts[-1] + 1))
			k += 1
	cuts.append(rows[-1] + 1)
	return cuts
