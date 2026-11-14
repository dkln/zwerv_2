extends RefCounted
## Every room is closed all round by walls (no way out over the front, nothing thrown out of it),
## but the camera looks in over the walls on its side (Iso.DIRECTION: the front and the right):
## those are drawn low, cut off at about 1 m (the tiles muur_laag*, wand_laag*). Here every such
## low wall gets a box that holds things as a full wall would (WALL_HEIGHT high, in a
## StaticBody3D "Muurbotsing" under the room, on the collision layers of its GridMap); nothing of
## it is drawn. The same for every interior (Interiors calls close() when it has dressed one).
##   const WallClosure = preload("res://scripts/world/interiors/wall_closure.gd")

## The name of the node with the boxes, under the room.
const NODE_NAME := "Muurbotsing"
## Tiles whose name holds one of these are walls drawn low (cut off on the camera's side).
const LOW_WALL_PARTS: Array[String] = ["muur_laag", "wand_laag"]
## How high a closed wall holds (metres above its foot), at least as high as the tile itself.
const WALL_HEIGHT := 3.0


## Closes the low walls of `room` (every GridMap under it, at any depth: the floors of the city
## hall, the branch of a supermarket): the boxes of the last time go first. How many boxes.
static func close(room: Node3D, height := WALL_HEIGHT) -> int:
	var old := room.get_node_or_null(NODE_NAME)
	if old:
		room.remove_child(old)
		old.free()
	var holder := Node3D.new()
	holder.name = NODE_NAME
	var count := 0
	for grid_map in grid_maps_under(room):
		var boxes := low_wall_boxes(grid_map, room)
		if boxes.is_empty():
			continue
		var body := StaticBody3D.new()
		body.collision_layer = grid_map.collision_layer
		body.collision_mask = grid_map.collision_mask
		for box in boxes:
			body.add_child(box_shape(raised(box, height)))
			count += 1
		holder.add_child(body)
	room.add_child(holder)
	return count


## True if the tile `tile_name` is a wall drawn low.
static func is_low_wall(tile_name: String) -> bool:
	for part in LOW_WALL_PARTS:
		if tile_name.contains(part):
			return true
	return false


## The boxes (in the space of `room`) of the low walls of `grid_map`.
static func low_wall_boxes(grid_map: GridMap, room: Node3D) -> Array[AABB]:
	var library := grid_map.mesh_library
	if library == null:
		return [] as Array[AABB]
	return tile_boxes(grid_map, room, func(item: int) -> bool: return is_low_wall(library.get_item_name(item)))


## The boxes the tiles of `grid_map` take up, in the space of `room`: all of them, or the ones
## whose item `keep` (Callable(item) -> bool) takes.
static func tile_boxes(grid_map: GridMap, room: Node3D, keep := Callable()) -> Array[AABB]:
	var boxes: Array[AABB] = []
	var library := grid_map.mesh_library
	if library == null:
		return boxes
	var to_room := room.global_transform.affine_inverse() * grid_map.global_transform
	for cell in grid_map.get_used_cells():
		var item := grid_map.get_cell_item(cell)
		var mesh := library.get_item_mesh(item)
		if mesh == null or (keep.is_valid() and not keep.call(item)):
			continue
		var placed := Transform3D(grid_map.get_basis_with_orthogonal_index(grid_map.get_cell_item_orientation(cell)), grid_map.map_to_local(cell))
		boxes.append(to_room * placed * library.get_item_mesh_transform(item) * mesh.get_aabb())
	return boxes


## `box` from its foot up to `height` (or its own height, when higher).
static func raised(box: AABB, height: float) -> AABB:
	return AABB(box.position, Vector3(box.size.x, maxf(box.size.y, height), box.size.z))


## A collision shape filling `box`.
static func box_shape(box: AABB) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = box.size
	var holder := CollisionShape3D.new()
	holder.shape = shape
	holder.position = box.get_center()
	return holder


## Every GridMap under `root`, at any depth (not `root` itself).
static func grid_maps_under(root: Node) -> Array[GridMap]:
	var found: Array[GridMap] = []
	for child in root.get_children():
		if child is GridMap:
			found.append(child)
		found.append_array(grid_maps_under(child))
	return found
