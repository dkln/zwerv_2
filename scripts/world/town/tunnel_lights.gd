extends Node
## Lights in the tunnels (the "Tunnelverlichting" node; behaviour, docs/CODE_LAGEN.md): the
## sun does not reach in there and the lamps in the tiles only glow. At startup it hangs
## downward spot lights (tunnel_lights_view.gd, the node "Lampen") under the roof of the
## covered tunnel tiles of the ground layer (layer -6): in every SPACING-th column, one in
## the middle of each tube (tunnel_lights_layout.gd). High above the town they are off
## altogether (tunnel_lights_rules.gd).

const TunnelLightsRules = preload("res://scripts/world/town/tunnel_lights_rules.gd")
const TunnelLightsLayout = preload("res://scripts/world/town/tunnel_lights_layout.gd")
const TunnelLightsView = preload("res://scripts/world/town/tunnel_lights_view.gd")

const TUNNEL_LEVEL := TunnelLightsLayout.TUNNEL_LEVEL
const LAMP_HEIGHT := TunnelLightsLayout.LAMP_HEIGHT
const SPACING := TunnelLightsLayout.SPACING

## The ground layer whose tiles tell where a tunnel is covered.
@export var ground_path := NodePath("../Grond")
## Brightness and reach (metres) of a lamp, and the half angle of its cone (degrees).
@export var energy := 7.0
@export var reach := 9.0
@export_range(1.0, 89.0) var angle := 72.0
## Above this camera height (metres) the lamps are off: from there on you only see the roof.
@export var off_above := 45.0

## Its picture: the lamps (null without a ground layer).
var view: TunnelLightsView

var _camera: Camera3D


func _ready() -> void:
	var ground := get_node_or_null(ground_path) as GridMap
	if ground == null or ground.mesh_library == null:
		set_process(false)
		return
	_camera = get_viewport().get_camera_3d()
	view = TunnelLightsView.new()
	add_child(view)
	var columns := _covered_columns(ground)
	for column: int in columns:
		for tube in TunnelLightsLayout.tubes(columns[column]):
			var first_cell := ground.to_global(ground.map_to_local(Vector3i(column, TUNNEL_LEVEL, tube.x)))
			var last_cell := ground.to_global(ground.map_to_local(Vector3i(column, TUNNEL_LEVEL, tube.y)))
			view.add_lamp(TunnelLightsLayout.lamp_position(first_cell, last_cell), energy, reach, angle)


## The lamp columns of `ground` with the rows of their covered tunnel cells: column -> rows.
func _covered_columns(ground: GridMap) -> Dictionary:
	var covered := {}     # ground item -> is it a covered tunnel tile
	var columns := {}     # column -> rows of its covered cells
	for cell in ground.get_used_cells():
		if cell.y != TUNNEL_LEVEL or not TunnelLightsLayout.is_lamp_column(cell.x):
			continue
		var item := ground.get_cell_item(cell)
		if not covered.has(item):
			covered[item] = is_covered_tile(ground.mesh_library.get_item_name(item))
		if covered[item]:
			var rows: Array = columns.get(cell.x, [])
			rows.append(cell.z)
			columns[cell.x] = rows
	return columns


## True for the item name of a covered tunnel tile (not an open trough or a ramp).
static func is_covered_tile(item_name: String) -> bool:
	return TunnelLightsRules.is_covered_tile(item_name)


func _process(_delta: float) -> void:
	if _camera:
		view.show_lit(TunnelLightsRules.is_lit(_camera.global_position.y, off_above))
