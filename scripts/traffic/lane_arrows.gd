@tool
extends Node3D
## Arrows on the road showing the driving direction of every lane, only in the editor
## (the "Rijrichtingen" node the builders add; in the game it removes itself). One arrow
## per lane heading of the road network (scripts/traffic/road_network.gd), on the road
## surface, tilted with a ramp:
## - `fixed_color`: the direction the tile itself gives (a lane tile, turned as placed);
## - `context_color`: a tile without a direction of its own (a crossing, plain asphalt,
##   a zebra, the tunnel), its direction decided from the road around it;
## - `open_color`: still both ways (nothing around it decides it), an arrow each way;
## - `chosen_color`: lanes, road users or speed limit chosen for this one placed tile
##   (Build dock, "Traffic").
## Placing or turning ground tiles or choosing lanes updates the arrows within a second.
##
## This is the behaviour (the node: it watches the ground and keeps the arrows up to date).
## Which kind of arrow a lane gets is lane_arrows_rules.gd, where it lies
## lane_arrows_layout.gd, the drawing lane_arrows_view.gd (its child `view`).

const LaneArrowsRules = preload("res://scripts/traffic/lane_arrows_rules.gd")
const LaneArrowsLayout = preload("res://scripts/traffic/lane_arrows_layout.gd")
const LaneArrowsView = preload("res://scripts/traffic/lane_arrows_view.gd")

## The ground GridMap with the road tiles.
@export var ground: NodePath = ^"../Grond"
@export var show_arrows := true:
	set(value):
		show_arrows = value
		visible = value
@export var fixed_color: Color = LaneArrowsView.FIXED_COLOR
@export var context_color: Color = LaneArrowsView.CONTEXT_COLOR
@export var open_color: Color = LaneArrowsView.OPEN_COLOR
@export var chosen_color: Color = LaneArrowsView.CHOSEN_COLOR
## Show the arrows through buildings and bridges too.
@export var through_walls := false:
	set(value):
		through_walls = value
		if view:
			view.show_through_walls(value)

## Height of the arrows above the road surface (metres).
const LIFT := LaneArrowsLayout.LIFT
## Seconds between checks whether the ground tiles changed.
const CHECK_INTERVAL := LaneArrowsRules.CHECK_INTERVAL

## The arrows as drawn (in the editor; not owned: never saved with the scene).
var view: LaneArrowsView
var _signature := 0
var _since_check := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	visible = show_arrows
	view = LaneArrowsView.new()
	view.show_through_walls(through_walls)
	add_child(view)   # not owned: never saved with the scene
	_refresh()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or not visible:
		return
	_since_check += delta
	if not LaneArrowsRules.check_due(_since_check):
		return
	_since_check = 0.0
	var gridmap := get_node_or_null(ground) as GridMap
	if gridmap and _signature_of(gridmap) != _signature:
		_refresh()


## Rebuilds the arrows from the ground tiles as they are now.
func _refresh() -> void:
	var gridmap := get_node_or_null(ground) as GridMap
	if gridmap and view:
		_signature = _signature_of(gridmap)
		view.show_arrows(arrow_list(gridmap))


## The arrows of all lanes of this ground GridMap (world positions), as a MultiMesh with
## a colour per arrow.
func build_arrows(gridmap: GridMap) -> MultiMesh:
	_signature = _signature_of(gridmap)
	return LaneArrowsView.multimesh_of(arrow_list(gridmap))


## Every arrow: {placement (world transform), color}.
func arrow_list(gridmap: GridMap) -> Array[Dictionary]:
	var network := RoadNetwork.new(gridmap)
	var colors := {LaneArrowsRules.FIXED: fixed_color, LaneArrowsRules.CONTEXT: context_color,
		LaneArrowsRules.OPEN: open_color, LaneArrowsRules.CHOSEN: chosen_color}
	var arrows: Array[Dictionary] = []
	for cell: Vector3i in network.cells():
		var headings := network.lanes(cell)
		var chosen := network.is_chosen(cell) or network.has_chosen_kinds(cell) or network.has_chosen_speed(cell)
		for heading in headings:
			var kind := LaneArrowsRules.arrow_kind(network.is_from_context(cell, heading), chosen, headings.has(-heading))
			var placement := _placement(network, cell, heading, headings.size() > 1)
			if gridmap.is_inside_tree():
				placement = gridmap.global_transform * placement
			arrows.append({"placement": placement, "color": colors[kind]})
	return arrows


## Where the arrow of `heading` on `cell` goes: on the road surface, pointing along the
## lane (up or down a ramp); moved a little forward when the cell has more than one, so
## the arrows of a crossing don't cover each other.
func _placement(network: RoadNetwork, cell: Vector3i, heading: Vector2i, shift: bool) -> Transform3D:
	var spot := network.centre(cell)
	if shift:
		spot = LaneArrowsLayout.shifted(spot, heading)
		spot.y = network.height(cell, Vector2(spot.x, spot.z))
	return LaneArrowsLayout.placement(spot, heading, network.slope(cell, heading))


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
