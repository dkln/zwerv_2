extends RefCounted
## What is seen of the traffic lights (the graphics layer of scripts/traffic/traffic_lights.gd):
## the light props of the Props layer (a GridMap under the world, one prop per light state).
## It tells which props stand where (light_props) and swaps the prop of a cell for another
## (show_prop), in the layer and in its LOD copies (Props_lod, see level_of_detail.gd). It
## decides nothing: which prop a light shows comes from the behaviour.
##   const TrafficLightsView = preload("res://scripts/traffic/traffic_lights_view.gd")

var _world: Node
var _layer_name: String
var _ids := {}           # prop name -> item id


## `world`: the node the layer (a GridMap called `layer_name`) and its LOD copies hang under.
func _init(world: Node, layer_name: String) -> void:
	_world = world
	_layer_name = layer_name


## True if the layer and its props are there.
func has_layer() -> bool:
	var layer := _layer()
	return layer != null and layer.mesh_library != null


## Every prop of the layer whose name starts with `prefix`: {cell, prop (its name), facing
## (the way its front points on the map), pos (metres, in the layer)}. Remembers the item of
## every such prop of the library on the way (for show_prop).
func light_props(prefix: String) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	if not has_layer():
		return props
	var layer := _layer()
	var library := layer.mesh_library
	for item in library.get_item_list():
		var item_name := library.get_item_name(item)
		if item_name.begins_with(prefix):
			_ids[item_name] = item
	for cell: Vector3i in layer.get_used_cells():
		var prop := library.get_item_name(layer.get_cell_item(cell))
		if not prop.begins_with(prefix):
			continue
		var facing := layer.get_basis_with_orthogonal_index(layer.get_cell_item_orientation(cell)) * Vector3(0, 0, 1)
		props.append({"cell": cell, "prop": prop, "facing": facing, "pos": layer.map_to_local(cell)})
	return props


## True if the library has a prop of this name (found by light_props).
func has_prop(prop: String) -> bool:
	return _ids.has(prop)


## Puts the prop `prop` in each of `cells`, turned as what stood there, in the layer and its
## LOD copies.
func show_props(cells: Array, props: Array) -> void:
	for layer in layers():
		for index in cells.size():
			layer.set_cell_item(cells[index], _ids[props[index]], layer.get_cell_item_orientation(cells[index]))


## The prop now in `cell` of the layer ("" when empty).
func prop_at(cell: Vector3i) -> String:
	var layer := _layer()
	if layer == null or layer.mesh_library == null or layer.get_cell_item(cell) < 0:
		return ""
	return layer.mesh_library.get_item_name(layer.get_cell_item(cell))


## The layer and its LOD copies (Props_lod), whichever exist.
func layers() -> Array[GridMap]:
	var found: Array[GridMap] = []
	for child in _world.get_children():
		if child is GridMap and (child.name == _layer_name or String(child.name).begins_with(_layer_name + "_lod")):
			found.append(child)
	return found


func _layer() -> GridMap:
	return _world.get_node_or_null(_layer_name) as GridMap
