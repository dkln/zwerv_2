extends Node3D
## The sellers at the snack carts of the town (the node "Straatverkopers" of scenes/stad.tscn;
## behaviour, docs/CODE_LAGEN.md: its rules street_vendors_rules.gd, the places
## street_vendors_layout.gd, the cart street_vendors_view.gd):
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
const StreetVendorsRules = preload("res://scripts/world/things/street_vendors_rules.gd")
const StreetVendorsLayout = preload("res://scripts/world/things/street_vendors_layout.gd")
const StreetVendorsView = preload("res://scripts/world/things/street_vendors_view.gd")
## Prop tiles that get a seller -> the name of the stall ("shop_name") (the rules').
const VENDOR_CARTS := StreetVendorsRules.VENDOR_CARTS
## The way the cart faces, where the seller stands in it, from how far you order and how
## high the arrow bobs over it (the layout's).
const CART_YAW := StreetVendorsLayout.CART_YAW
const SELLER_IN_CART := StreetVendorsLayout.SELLER_IN_CART
const ORDER_REACH := StreetVendorsLayout.ORDER_REACH
const MARK_ABOVE := StreetVendorsLayout.MARK_ABOVE

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
			var cart := _add_cart(library, item, props.collision_layer, origin, number, tile_name)
			_add_seller(cart, box, number, tile_name)


## Cart `number` of the tile `tile_name` (`item` of `library`) at `origin`, as a node of its
## own.
func _add_cart(library: MeshLibrary, item: int, layer: int, origin: Vector3, number: int, tile_name: String) -> Node3D:
	var cart := StreetVendorsView.cart(library, item, layer, StreetVendorsLayout.cart_place(origin))
	cart.name = StreetVendorsRules.cart_name(number)
	cart.set_meta("tile", tile_name)
	add_child(cart)
	_carts.append(cart)
	return cart


## Seller `number` in `cart` (the box of its tile: `box`), facing out of the hatch.
func _add_seller(cart: Node3D, box: AABB, number: int, tile_name: String) -> Node3D:
	var seller: Node3D = InteriorPersonScript.create(StreetVendorsRules.SELLER_ROLE, StreetVendorsRules.seller_seed(number), false)
	seller.name = StreetVendorsRules.seller_name(number)
	seller.set_meta("shop_name", StreetVendorsRules.shop_name(tile_name))
	add_child(seller)
	seller.global_position = StreetVendorsLayout.seller_place(cart.global_transform)
	seller.rotation.y = CART_YAW
	# ordered at the counter: the reach from the front of the cart
	seller.set("talk_ahead", StreetVendorsLayout.to_front(box))
	seller.set("talk_reach", ORDER_REACH)
	# the arrow over the front of the cart, above its sign (heights from the seller's feet)
	var heights := StreetVendorsLayout.mark_heights(box)
	seller.call("place_mark_ahead", StreetVendorsLayout.mark_ahead(box), heights.x, heights.y)
	_vendors.append(seller)
	return seller


## The cart's cell emptied in the Props layer and its LOD copies (Props_lod).
func _clear_cell(props: GridMap, cell: Vector3i, item: int) -> void:
	for layer in props.get_parent().get_children():
		if layer is GridMap and StreetVendorsRules.holds_carts(String(layer.name), String(props.name)):
			if (layer as GridMap).get_cell_item(cell) == item:
				(layer as GridMap).set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


## The sellers placed (for the checks).
func vendors() -> Array[Node3D]:
	return _vendors


## The carts placed, turned to the camera (for the checks).
func carts() -> Array[Node3D]:
	return _carts
