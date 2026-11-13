extends Node
## Lights in the tunnels (the "Tunnelverlichting" node): the sun does not reach in there and
## the lamps in the tiles only glow. At startup it hangs downward spot lights under the
## roof of the covered tunnel tiles of the ground layer (layer -6): in every SPACING-th
## column, one in the middle of each tube (each run of touching rows). They shine down, so no light comes through the roof onto the street above, and
## without shadows, so they cost little; high above the town they are off altogether.

const TUNNEL_LEVEL := -6
## Metres above the tile's floor that a lamp hangs: just under the roof (5 m of headroom).
const LAMP_HEIGHT := 4.7
## Columns between two rows of lamps.
const SPACING := 2

## The ground layer whose tiles tell where a tunnel is covered.
@export var ground_path := NodePath("../Grond")
## Brightness and reach (metres) of a lamp, and the half angle of its cone (degrees).
@export var energy := 7.0
@export var reach := 9.0
@export_range(1.0, 89.0) var angle := 72.0
## Above this camera height (metres) the lamps are off: from there on you only see the roof.
@export var off_above := 45.0

var _lamps: Node3D
var _camera: Camera3D


func _ready() -> void:
	var ground := get_node_or_null(ground_path) as GridMap
	if ground == null or ground.mesh_library == null:
		set_process(false)
		return
	_camera = get_viewport().get_camera_3d()
	_lamps = Node3D.new()
	_lamps.name = "Lampen"
	add_child(_lamps)
	var covered := {}     # ground item -> is it a covered tunnel tile
	var columns := {}     # column -> rows of its covered cells
	for cell in ground.get_used_cells():
		if cell.y != TUNNEL_LEVEL or posmod(cell.x, SPACING) != 0:
			continue
		var item := ground.get_cell_item(cell)
		if not covered.has(item):
			covered[item] = is_covered_tile(ground.mesh_library.get_item_name(item))
		if covered[item]:
			var rows: Array = columns.get(cell.x, [])
			rows.append(cell.z)
			columns[cell.x] = rows
	for column: int in columns:
		var rows: Array = columns[column]
		rows.sort()
		var run_start: int = rows[0]
		for index in rows.size():
			var run_ends: bool = index == rows.size() - 1 or rows[index + 1] != rows[index] + 1
			if run_ends:
				var first_cell := ground.to_global(ground.map_to_local(Vector3i(column, TUNNEL_LEVEL, run_start)))
				var last_cell := ground.to_global(ground.map_to_local(Vector3i(column, TUNNEL_LEVEL, rows[index])))
				_lamps.add_child(_lamp((first_cell + last_cell) * 0.5))
				if index < rows.size() - 1:
					run_start = rows[index + 1]


## True for the item name of a covered tunnel tile (not an open trough or a ramp).
static func is_covered_tile(item_name: String) -> bool:
	return item_name.begins_with("tunnel/") and not "toerit" in item_name and not "tunnelbak" in item_name


func _lamp(cell_centre: Vector3) -> SpotLight3D:
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.96, 0.88)
	lamp.light_energy = energy
	lamp.spot_range = reach
	lamp.spot_angle = angle
	lamp.spot_attenuation = 0.6
	lamp.shadow_enabled = false
	lamp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # straight down
	lamp.position = Vector3(cell_centre.x, TUNNEL_LEVEL + LAMP_HEIGHT, cell_centre.z)
	return lamp


func _process(_delta: float) -> void:
	if _camera:
		_lamps.visible = _camera.global_position.y < off_above
