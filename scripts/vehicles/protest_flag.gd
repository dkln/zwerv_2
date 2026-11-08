extends Node3D
## The upside-down Dutch flag of the protesting farmers (blue on top, red at the bottom) on
## a pole on the rear corner of a tractor's cab roof, waving gently. Built of boxes in the
## voxel style; placed in the vehicle's frame (+Z ahead, x = 0 in the middle, metres), as
## tractor.gd and the columns of the menu (main_menu.gd) use it.

## The foot of the pole (on the roof, tools/voxgen/tiles/small_vehicles.py: roof up to
## voxel 21, the back of the cab at 29, an eighth of a metre each), its height and width.
const POLE_FOOT := Vector3(0.6, 2.55, -1.62)
const POLE_HEIGHT := 1.15
const POLE_WIDTH := 0.05
## The cloth: width (backwards from the pole), height, thickness; three equal bands, top
## to bottom.
const CLOTH_SIZE := Vector3(0.04, 0.5, 0.75)
const BANDS := [Color(0.13, 0.27, 0.55), Color(0.95, 0.95, 0.93), Color(0.68, 0.11, 0.16)]
const POLE_COLOUR := Color(0.55, 0.42, 0.28)
## The waving: degrees to each side round the pole, and how fast (radians per second).
const WAVE_DEGREES := 12.0
const WAVE_SPEED := 3.1

var _cloth: Node3D
var _wave_offset := 0.0


func _init() -> void:
	name = "Protestvlag"
	position = POLE_FOOT
	var pole := _box(Vector3(POLE_WIDTH, POLE_HEIGHT, POLE_WIDTH), POLE_COLOUR)
	pole.position = Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)
	add_child(pole)
	_cloth = Node3D.new()
	_cloth.name = "Doek"
	_cloth.position = Vector3(0.0, POLE_HEIGHT - 0.02, 0.0)
	add_child(_cloth)
	var band_height := CLOTH_SIZE.y / BANDS.size()
	for band_index in BANDS.size():
		var band := _box(Vector3(CLOTH_SIZE.x, band_height, CLOTH_SIZE.z), BANDS[band_index])
		band.position = Vector3(0.0, -band_height * (band_index + 0.5), -CLOTH_SIZE.z * 0.5 - POLE_WIDTH * 0.5)
		_cloth.add_child(band)


func _ready() -> void:
	_wave_offset = float(get_instance_id() % 997) * 0.37


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var seconds := Time.get_ticks_msec() / 1000.0 + _wave_offset
	_cloth.rotation.y = deg_to_rad(WAVE_DEGREES) * (sin(seconds * WAVE_SPEED) * 0.7 + sin(seconds * WAVE_SPEED * 2.3) * 0.3)


func _box(size: Vector3, colour: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	box.material = material
	var part := MeshInstance3D.new()
	part.mesh = box
	return part
