@tool
class_name TintArea
extends Node3D
## A rectangle (in 4 m cells, centred on this node) that gives everything beneath it a
## tint. Must be a child of a TintMap (tint_map.gd), which rasterises the areas.
## White = no change; brightness > 1 makes it lighter, < 1 darker.
## In the editor a translucent box shows the covered area.

## Tint colour multiplied onto the tiles (white = unchanged).
@export var color := Color(1, 0.85, 0.75):
	set(v):
		color = v
		_update_preview()
## Multiplier on the colour (0 to 2).
@export_range(0.0, 2.0) var brightness := 1.0
## How much of the tint is applied (0 = none, 1 = full).
@export_range(0.0, 1.0) var strength := 1.0
## Size in 4 m cells along x and z (at least 1x1).
@export var size := Vector2i(1, 1):
	set(v):
		size = Vector2i(maxi(1, v.x), maxi(1, v.y))
		_update_preview()

var _preview: MeshInstance3D


func _ready() -> void:
	_update_preview()


## Editor only: creates or updates the translucent preview box (size and colour).
func _update_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		_preview.material_override = m
		add_child(_preview)
	(_preview.mesh as BoxMesh).size = Vector3(size.x * TintMap.CELL, 0.1, size.y * TintMap.CELL)
	(_preview.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 0.25)
