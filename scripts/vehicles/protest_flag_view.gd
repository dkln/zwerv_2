extends Node3D
## What the protest flag of a tractor looks like (graphics; docs/CODE_LAGEN.md): the
## upside-down Dutch flag of the protesting farmers (blue on top, red at the bottom) on a
## wooden pole, built of boxes in the voxel style. Sizes and places: protest_flag_layout.gd;
## protest_flag.gd tells it how far the cloth is turned (show_wave).
##   const ProtestFlagView = preload("res://scripts/vehicles/protest_flag_view.gd")

const ProtestFlagLayout = preload("res://scripts/vehicles/protest_flag_layout.gd")

## The bands of the cloth, top to bottom.
const BANDS := [Color(0.13, 0.27, 0.55), Color(0.95, 0.95, 0.93), Color(0.68, 0.11, 0.16)]
const POLE_COLOUR := Color(0.55, 0.42, 0.28)
const ROUGHNESS := 0.9

var _cloth: Node3D


func _init() -> void:
	name = "Beeld"
	var pole := _box(ProtestFlagLayout.pole_size(), POLE_COLOUR)
	pole.position = ProtestFlagLayout.pole_centre()
	add_child(pole)
	_cloth = Node3D.new()
	_cloth.name = "Doek"
	_cloth.position = ProtestFlagLayout.cloth_top()
	add_child(_cloth)
	for band_index in BANDS.size():
		var band := _box(ProtestFlagLayout.band_size(), BANDS[band_index])
		band.position = ProtestFlagLayout.band_centre(band_index)
		_cloth.add_child(band)


## The cloth turned `turn` radians round the pole.
func show_wave(turn: float) -> void:
	_cloth.rotation.y = turn


## The cloth (its bands are its children), for who wants to look at it.
func cloth() -> Node3D:
	return _cloth


func _box(size: Vector3, colour: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = ROUGHNESS
	box.material = material
	var part := MeshInstance3D.new()
	part.mesh = box
	return part
