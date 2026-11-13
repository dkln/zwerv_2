extends Node3D
## The sellers at the snack carts of the town (the node "Straatverkopers" of scenes/stad.tscn):
## every snack cart of the Props layer (VENDOR_CARTS: markt/frietkar, on the Stationsplein
## before Den Haag Centraal) is taken out of the grid and put back on the same spot as a node
## of its own (mesh and collision of its tile), its hatch to the north (CART_YAW): of the two
## sides the iso camera sees (north and east) the one the sun lights; the east sides of the
## town stay dark, and turned diagonally the hatch only gets grazing light (and the voxel
## shader wants quarter turns). Inside it, on its floor (SELLER_IN_CART), stands someone
## selling from it, facing out of the hatch: seen through it from the waist up. Talked to from
## before the cart (the reach counts from its counter: InteriorPerson.talk_ahead / talk_reach)
## it opens the shop screen as a snack bar does (Conversations: role "snackbarhouder", what it
## sells data/gesprekken/snackbarhouder.json, a kroket among it), so the first mission's kroket
## can be bought here, close to the start. The arrow of who sells bobs over the front of the
## cart, above its sign, where the cart never hides it.

const InteriorPersonScript = preload("res://scripts/world/interiors/interior_person.gd")
## Prop tiles that get a seller -> the name of the stall ("shop_name").
const VENDOR_CARTS := {"markt/frietkar": "de frietkar"}
## The way the cart's front (its hatch) faces: north (see the top).
const CART_YAW := PI
## Where the seller stands in the cart (metres from its pivot, the front +z): on the floor of
## its room (0.625 m, tools/voxgen/tiles/street_carts.py chip_van), a little before the middle.
const SELLER_IN_CART := Vector3(0.0, 0.625, 0.15)
## Within how many metres of the front of the cart the player can order.
const ORDER_REACH := 2.0
## The arrow over the cart: its point between these heights above the top of the cart.
const MARK_ABOVE := Vector2(0.4, 1.0)

@export var props_path := NodePath("../Props")

var _vendors: Array[Node3D] = []
var _carts: Array[Node3D] = []


func _ready() -> void:
	var props := get_node_or_null(props_path) as GridMap
	if props == null or props.mesh_library == null:
		return
	_place_vendors.call_deferred(props)


## Every snack cart turned to the camera, a seller behind it (see the top).
func _place_vendors(props: GridMap) -> void:
	var library := props.mesh_library
	var number := 0
	var yaw := CART_YAW
	for tile_name: String in VENDOR_CARTS:
		var item := library.find_item_by_name(tile_name)
		if item < 0:
			continue
		var mesh := library.get_item_mesh(item)
		var box := mesh.get_aabb() if mesh else AABB()
		for cell in props.get_used_cells_by_item(item):
			number += 1
			var origin := props.to_global(props.map_to_local(cell))
			_clear_cell(props, cell, item)
			var cart := _cart(library, item, props.collision_layer, Transform3D(Basis(Vector3.UP, yaw), origin))
			cart.name = "Kar%d" % number
			cart.set_meta("tile", tile_name)
			add_child(cart)
			_carts.append(cart)
			var seller: Node3D = InteriorPersonScript.create("snackbarhouder", 7100 + number * 13, false)
			seller.name = "Verkoper%d" % number
			seller.set_meta("shop_name", VENDOR_CARTS[tile_name])
			add_child(seller)
			seller.global_position = cart.global_transform * SELLER_IN_CART
			seller.rotation.y = yaw
			# ordered at the counter: the reach from the front of the cart
			var to_front := box.end.z - SELLER_IN_CART.z
			seller.set("talk_ahead", to_front)
			seller.set("talk_reach", ORDER_REACH)
			# the arrow over the front of the cart, above its sign (heights from the seller's feet)
			var top := box.end.y - SELLER_IN_CART.y
			seller.call("place_mark_ahead", to_front * 0.5, top + MARK_ABOVE.x, top + MARK_ABOVE.y)
			_vendors.append(seller)


## The cart's cell emptied in the Props layer and its LOD copies (Props_lod).
func _clear_cell(props: GridMap, cell: Vector3i, item: int) -> void:
	for layer in props.get_parent().get_children():
		if layer is GridMap and (layer == props or String(layer.name).begins_with(String(props.name) + "_lod")):
			if (layer as GridMap).get_cell_item(cell) == item:
				(layer as GridMap).set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


## The tile `item` of `library` as a node at `at`: its mesh, and its collision shapes on
## `layer` (as the grid had them).
func _cart(library: MeshLibrary, item: int, layer: int, at: Transform3D) -> Node3D:
	var cart := StaticBody3D.new()
	cart.collision_layer = layer
	cart.collision_mask = 0
	cart.transform = at
	var look := MeshInstance3D.new()
	look.name = "Model"
	look.mesh = library.get_item_mesh(item)
	look.transform = library.get_item_mesh_transform(item)
	cart.add_child(look)
	var shapes := library.get_item_shapes(item)
	for index in range(0, shapes.size() - 1, 2):
		var shape := CollisionShape3D.new()
		shape.shape = shapes[index]
		shape.transform = shapes[index + 1]
		cart.add_child(shape)
	return cart


## The sellers placed (for the checks).
func vendors() -> Array[Node3D]:
	return _vendors


## The carts placed, turned to the camera (for the checks).
func carts() -> Array[Node3D]:
	return _carts
