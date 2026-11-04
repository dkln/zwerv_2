@tool
extends Node3D
## Arrows on the road showing the driving direction of every lane, only in the editor
## (the "Rijrichtingen" node the builders add; in the game it removes itself). One arrow
## per lane heading of the road network (scripts/world/road_network.gd), on the road
## surface, tilted with a ramp:
## - `fixed_color`: the direction the tile itself gives (a lane tile, turned as placed);
## - `context_color`: a tile without a direction of its own (a crossing, plain asphalt,
##   a zebra, the tunnel), its direction decided from the road around it;
## - `open_color`: still both ways (nothing around it decides it), an arrow each way;
## - `chosen_color`: lanes, road users or speed limit chosen for this one placed tile
##   (Build dock, "Traffic").
## Placing or turning ground tiles or choosing lanes updates the arrows within a second.

## The ground GridMap with the road tiles.
@export var ground: NodePath = ^"../Grond"
@export var show_arrows := true:
	set(value):
		show_arrows = value
		visible = value
@export var fixed_color := Color(1.0, 0.85, 0.1)
@export var context_color := Color(0.35, 0.8, 1.0)
@export var open_color := Color(1.0, 0.2, 0.8)
@export var chosen_color := Color(0.3, 1.0, 0.35)
## Show the arrows through buildings and bridges too.
@export var through_walls := false:
	set(value):
		through_walls = value
		if _material:
			_material.no_depth_test = value

## Height of the arrows above the road surface (metres).
const LIFT := 0.12
## Seconds between checks whether the ground tiles changed.
const CHECK_INTERVAL := 1.0

var _arrows: MultiMeshInstance3D
var _material: StandardMaterial3D
var _signature := 0
var _since_check := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	visible = show_arrows
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = through_walls
	_arrows = MultiMeshInstance3D.new()
	_arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrows.material_override = _material
	add_child(_arrows)   # not owned: never saved with the scene
	_refresh()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or not visible:
		return
	_since_check += delta
	if _since_check < CHECK_INTERVAL:
		return
	_since_check = 0.0
	var gridmap := get_node_or_null(ground) as GridMap
	if gridmap and _signature_of(gridmap) != _signature:
		_refresh()


## Rebuilds the arrows from the ground tiles as they are now.
func _refresh() -> void:
	var gridmap := get_node_or_null(ground) as GridMap
	if gridmap and _arrows:
		_arrows.multimesh = build_arrows(gridmap)
		_arrows.global_transform = Transform3D.IDENTITY


## The arrows of all lanes of this ground GridMap (world positions), as a MultiMesh with
## a colour per arrow.
func build_arrows(gridmap: GridMap) -> MultiMesh:
	_signature = _signature_of(gridmap)
	var arrows := arrow_list(gridmap)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _arrow_mesh()
	multimesh.instance_count = arrows.size()
	for index in arrows.size():
		multimesh.set_instance_transform(index, arrows[index].placement)
		multimesh.set_instance_color(index, arrows[index].color)
	return multimesh


## Every arrow: {placement (world transform), color}.
func arrow_list(gridmap: GridMap) -> Array[Dictionary]:
	var network := RoadNetwork.new(gridmap)
	var arrows: Array[Dictionary] = []
	for cell: Vector3i in network.cells():
		var headings := network.lanes(cell)
		for heading in headings:
			var color := context_color if network.is_from_context(cell, heading) else fixed_color
			if network.is_chosen(cell) or network.has_chosen_kinds(cell) or network.has_chosen_speed(cell):
				color = chosen_color
			elif headings.has(-heading):
				color = open_color
			var placement := gridmap.global_transform * _placement(network, cell, heading, headings.size() > 1) \
					if gridmap.is_inside_tree() else _placement(network, cell, heading, headings.size() > 1)
			arrows.append({"placement": placement, "color": color})
	return arrows


## Where the arrow of `heading` on `cell` goes: on the road surface, pointing along the
## lane (up or down a ramp); moved a little forward when the cell has more than one, so
## the arrows of a crossing don't cover each other.
func _placement(network: RoadNetwork, cell: Vector3i, heading: Vector2i, shift: bool) -> Transform3D:
	var spot := network.centre(cell)
	if shift:
		spot += Vector3(heading.x, 0.0, heading.y) * 0.7
		spot.y = network.height(cell, Vector2(spot.x, spot.z))
	var forward := Vector3(heading.x, network.slope(cell, heading), heading.y).normalized()
	return Transform3D(Basis.looking_at(-forward, Vector3.UP), spot + Vector3.UP * LIFT)


## A flat arrow in the x-z plane, pointing along +z, 2.2 m long.
func _arrow_mesh() -> ArrayMesh:
	var shaft_half := 0.18
	var head_half := 0.6
	var tail := -1.1
	var neck := 0.3
	var tip := 1.1
	var corners := PackedVector3Array([
		Vector3(-shaft_half, 0, tail), Vector3(shaft_half, 0, tail), Vector3(shaft_half, 0, neck),
		Vector3(-shaft_half, 0, tail), Vector3(shaft_half, 0, neck), Vector3(-shaft_half, 0, neck),
		Vector3(-head_half, 0, neck), Vector3(head_half, 0, neck), Vector3(0, 0, tip)])
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = corners
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh


## A number that changes when a ground tile is placed, removed or turned, or its lanes chosen.
func _signature_of(gridmap: GridMap) -> int:
	var cells := gridmap.get_used_cells()
	var values := PackedInt32Array()
	values.resize(cells.size() * 5)
	for index in cells.size():
		var cell: Vector3i = cells[index]
		values[index * 5] = cell.x
		values[index * 5 + 1] = cell.y
		values[index * 5 + 2] = cell.z
		values[index * 5 + 3] = gridmap.get_cell_item(cell)
		values[index * 5 + 4] = gridmap.get_cell_item_orientation(cell)
	return hash([values, gridmap.get_meta(RoadNetwork.LANE_CHOICES, {})])
