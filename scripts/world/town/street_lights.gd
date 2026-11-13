extends Node3D
## The street lights at night (made by DayCycle next to itself, "Straatverlichting"): every lamp
## in the Props layer (items "verlichting/...") gets a real light at its head, so the street
## round it is lit, warm and yellow-white. They follow the dark of DayCycle (`night`): off by
## day, fading in at dusk (from NIGHT_FROM), full at night.
## Only the MAX_LIGHTS lamps nearest the middle of the view (Iso.ground_focus of the camera)
## within REACH m burn as lights (the lamps' own glow is in their voxels and burns everywhere),
## chosen again every PICK_INTERVAL s, so 800 lamps cost no more than a few dozen lights.
## LAMP_HEADS: where the light sits per kind of lamp (metres, in the tile's own frame, before
## its turn in the grid): at the end of the arm, on top, both heads of a double lamp.

const Iso = preload("res://scripts/camera/iso_camera.gd")

const LAMP_PREFIX := "verlichting/"
## Per lamp: the heads ([x, y, z] in the tile), the reach (m) and the colour of its light.
const LAMP_HEADS := {
	"verlichting/lantaarn_modern": {"heads": [Vector3(1.4, 5.75, 0.0)], "range": 11.0, "colour": Color("#FFF1DA")},
	"verlichting/lantaarn_klassiek": {"heads": [Vector3(0.0, 4.9, 0.0)], "range": 9.0, "colour": Color("#FFD79A")},
	"verlichting/lantaarn_wand_klassiek": {"heads": [Vector3(0.06, 0.9, 0.45)], "range": 6.0, "colour": Color("#FFD79A")},
	"verlichting/lantaarn_klassiek_dubbel": {"heads": [Vector3(-1.15, 3.9, 0.0), Vector3(1.15, 3.9, 0.0)], "range": 9.0, "colour": Color("#FFD79A")},
	"verlichting/lantaarn_gietijzer": {"heads": [Vector3(1.3, 4.1, 0.0)], "range": 9.0, "colour": Color("#FFD79A")},
	"verlichting/lantaarn_park": {"heads": [Vector3(0.0, 3.4, 0.0)], "range": 8.0, "colour": Color("#FFE2B0")},
	"verlichting/lantaarn_middenberm": {"heads": [Vector3(-4.0, 9.9, 0.0), Vector3(4.0, 9.9, 0.0)], "range": 15.0, "colour": Color("#FFF1DA")},
}
## A lamp not in LAMP_HEADS: one light on the top of its middle.
const DEFAULT_RANGE := 9.0
const DEFAULT_COLOUR := Color("#FFE2B0")
const ENERGY := 1.8
const ATTENUATION := 1.3
## The dark (DayCycle.night) at which the lights start to come on, and at which they are full.
const NIGHT_FROM := 0.3
const NIGHT_FULL := 0.8
const MAX_LIGHTS := 64
const REACH := 70.0
const PICK_INTERVAL := 0.4

@export var props_path := NodePath("../Props")
@export var camera_path := NodePath("../Camera")

var _heads: Array = []           # [world position, range, colour] per lamp head
var _lights: Array[OmniLight3D] = []
var _day_cycle: Node
var _pick_clock := 0.0


func _ready() -> void:
	_day_cycle = get_parent().get_node_or_null("Dagcyclus")
	var props := get_node_or_null(props_path) as GridMap
	if props and props.mesh_library:
		_find_heads(props)
	for light_index in mini(MAX_LIGHTS, _heads.size()):
		var light := OmniLight3D.new()
		light.shadow_enabled = false
		light.omni_attenuation = ATTENUATION
		light.light_specular = 0.25
		light.visible = false
		add_child(light)
		_lights.append(light)


## The heads of every lamp in the Props layer, in the world.
func _find_heads(props: GridMap) -> void:
	var library := props.mesh_library
	for cell in props.get_used_cells():
		var item := props.get_cell_item(cell)
		var item_name := library.get_item_name(item)
		if not item_name.begins_with(LAMP_PREFIX):
			continue
		var basis := props.get_cell_item_basis(cell)
		var origin := props.map_to_local(cell)
		var lamp: Dictionary = LAMP_HEADS.get(item_name, {})
		var heads: Array = lamp.get("heads", [])
		if heads.is_empty():
			var box := library.get_item_mesh(item).get_aabb()
			heads = [Vector3(box.get_center().x, box.end.y - 0.3, box.get_center().z)]
		for head: Vector3 in heads:
			_heads.append([props.global_transform * (origin + basis * head),
					float(lamp.get("range", DEFAULT_RANGE)), lamp.get("colour", DEFAULT_COLOUR)])


func lamp_count() -> int:
	return _heads.size()


func lit_count() -> int:
	var lit := 0
	for light in _lights:
		if light.visible:
			lit += 1
	return lit


func _process(delta: float) -> void:
	var night: float = _day_cycle.night if _day_cycle else 0.0
	var strength := clampf((night - NIGHT_FROM) / (NIGHT_FULL - NIGHT_FROM), 0.0, 1.0)
	if strength <= 0.0:
		for light in _lights:
			light.visible = false
		return
	_pick_clock -= delta
	if _pick_clock <= 0.0:
		_pick_clock = PICK_INTERVAL
		_pick_nearest()
	for light in _lights:
		light.light_energy = ENERGY * strength


## Puts the lights on the heads nearest the middle of the view.
func _pick_nearest() -> void:
	var camera := get_node_or_null(camera_path) as Camera3D
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var focus := Iso.ground_focus(camera)
	var near: Array = []
	for head: Array in _heads:
		var at: Vector3 = head[0]
		var distance := Vector2(at.x - focus.x, at.z - focus.z).length()
		if distance <= REACH:
			near.append([distance, head])
	near.sort_custom(func(first: Array, second: Array) -> bool: return first[0] < second[0])
	for light_index in _lights.size():
		var light := _lights[light_index]
		if light_index >= near.size():
			light.visible = false
			continue
		var head: Array = near[light_index][1]
		light.global_position = head[0]
		light.omni_range = head[1]
		light.light_color = head[2]
		light.visible = true
