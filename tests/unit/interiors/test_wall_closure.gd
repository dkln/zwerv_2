extends RefCounted
## Unit tests of closing the low walls of a room (scripts/world/interiors/wall_closure.gd): a
## room of hand-made tiles, a low wall at the front and the right, a high one at the back.
##   tests/run_unit_tests.sh wall_closure

const WallClosure = preload("res://scripts/world/interiors/wall_closure.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A room: a GridMap (cells of 4 x 4 x 4 m) with the tiles muur_rood (3 m), muur_laag_rood
## (1 m) and wand_laag_half (1 m, 2 m wide): two low ones at the front, one at the right,
## a high one at the back.
func _room() -> Node3D:
	var library := MeshLibrary.new()
	var sizes := {"muur_rood": Vector3(4.0, 3.0, 0.25), "muur_laag_rood": Vector3(4.0, 1.0, 0.25), "wand_laag_half": Vector3(2.0, 1.0, 0.25)}
	var item := 0
	for tile_name: String in sizes:
		var mesh := BoxMesh.new()
		mesh.size = sizes[tile_name]
		library.create_item(item)
		library.set_item_name(item, tile_name)
		library.set_item_mesh(item, mesh)
		library.set_item_mesh_transform(item, Transform3D(Basis(), Vector3(0.0, mesh.size.y * 0.5, 0.0)))
		item += 1
	var grid_map := GridMap.new()
	grid_map.name = "Inrichting"
	grid_map.mesh_library = library
	grid_map.cell_size = Vector3(4.0, 4.0, 4.0)
	grid_map.cell_center_y = false
	grid_map.collision_layer = 5
	grid_map.set_cell_item(Vector3i(0, 0, 1), 0)                                  # the back: high
	grid_map.set_cell_item(Vector3i(0, 0, -1), 1)                                 # the front: low
	grid_map.set_cell_item(Vector3i(1, 0, -1), 2)
	grid_map.set_cell_item(Vector3i(1, 0, 0), 1, grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, -PI * 0.5)))
	var room := Node3D.new()
	var floor_node := Node3D.new()
	floor_node.name = "Etage0"                # a floor under the room, as in the city hall
	floor_node.add_child(grid_map)
	room.add_child(floor_node)
	tree.root.add_child(room)
	room.position = Vector3(100.0, 0.0, 50.0)   # far off, as the interiors are
	return room


func test_is_low_wall(test) -> void:
	test.check(WallClosure.is_low_wall("muur_laag_zwartwit") and WallClosure.is_low_wall("binnen/station/wand_laag_half"), "lage muren")
	test.check(not WallClosure.is_low_wall("muur_zwartwit") and not WallClosure.is_low_wall("toonbank_rood"), "hoge muren en meubels niet")


func test_low_walls_get_full_height_boxes(test) -> void:
	var room := _room()
	var count := WallClosure.close(room)
	test.check(count == 3, "drie lage muren dicht (%d)" % count)
	var holder := room.get_node_or_null(WallClosure.NODE_NAME)
	test.check(holder != null and holder.get_child_count() == 1, "één body voor de ene GridMap")
	if holder == null:
		room.free()
		return
	var body := holder.get_child(0) as StaticBody3D
	test.check(body.collision_layer == 5, "op de laag van de GridMap")
	for shape_node: CollisionShape3D in body.get_children():
		var size := (shape_node.shape as BoxShape3D).size
		test.check(is_equal_approx(size.y, WallClosure.WALL_HEIGHT), "volle hoogte (%.2f)" % size.y)
		test.check(is_equal_approx(shape_node.position.y, WallClosure.WALL_HEIGHT * 0.5), "vanaf de vloer")
	room.free()


func test_closing_again_replaces_the_boxes(test) -> void:
	var room := _room()
	WallClosure.close(room)
	WallClosure.close(room)
	var holders := room.get_children().filter(func(node: Node) -> bool: return node.name.begins_with(WallClosure.NODE_NAME))
	test.check(holders.size() == 1, "nog maar één Muurbotsing (%d)" % holders.size())
	room.free()


func test_turned_wall_box_lies_along_its_side(test) -> void:
	var room := _room()
	var grid_map := room.get_node("Etage0/Inrichting") as GridMap
	var boxes := WallClosure.low_wall_boxes(grid_map, room)
	var turned := boxes.filter(func(box: AABB) -> bool: return box.size.z > box.size.x)
	test.check(turned.size() == 1, "de rechtermuur ligt langs z")
	test.check(WallClosure.tile_boxes(grid_map, room).size() == 4, "alle tegels: 4")
	room.free()


func test_raised_keeps_a_higher_tile(test) -> void:
	var high := AABB(Vector3.ZERO, Vector3(1.0, 5.0, 1.0))
	test.check(is_equal_approx(WallClosure.raised(high, 3.0).size.y, 5.0), "een hogere tegel blijft zo hoog")
	test.check(is_equal_approx(WallClosure.raised(AABB(Vector3(0, 2, 0), Vector3.ONE), 3.0).position.y, 2.0), "de voet blijft")
	var shape := WallClosure.box_shape(AABB(Vector3(1, 0, 1), Vector3(2, 4, 2)))
	test.check(shape.position == Vector3(2, 2, 2), "vorm in het midden")
	shape.free()
