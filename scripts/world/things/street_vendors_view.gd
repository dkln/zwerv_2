extends RefCounted
## What a snack cart of the street vendors looks like (graphics; docs/CODE_LAGEN.md;
## street_vendors.gd): the tile of the cart as a node of its own, with the mesh and the
## collision shapes the grid had for it.
##   const StreetVendorsView = preload("res://scripts/world/things/street_vendors_view.gd")
##   var cart := StreetVendorsView.cart(library, item, props.collision_layer, at)

const MODEL_NAME := "Model"


## The tile `item` of `library` as a node at `at`: its mesh (the child "Model"), and its
## collision shapes on `layer` (as the grid had them).
static func cart(library: MeshLibrary, item: int, layer: int, at: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.transform = at
	var look := MeshInstance3D.new()
	look.name = MODEL_NAME
	look.mesh = library.get_item_mesh(item)
	look.transform = library.get_item_mesh_transform(item)
	body.add_child(look)
	var shapes := library.get_item_shapes(item)
	for index in range(0, shapes.size() - 1, 2):
		var shape := CollisionShape3D.new()
		shape.shape = shapes[index]
		shape.transform = shapes[index + 1]
		body.add_child(shape)
	return body
