extends CanvasLayer
## The clouds the camera dives through at the start of the game (cloud_shroud.gdshader), over
## the town and under the HUD; the follow camera (scripts/camera/follow_camera.gd, arrival)
## sets how much they hide (`cover`), how far the dive is (`dive`) and how much the view has
## zoomed in since the start (`magnify`: the clouds grow with it and move aside), and frees
## them after.

const SHADER := preload("res://scripts/effects/cloud_shroud.gdshader")

var cover := 0.0:
	set(value):
		cover = value
		if _material:
			_material.set_shader_parameter("cover", value)
var dive := 0.0:
	set(value):
		dive = value
		if _material:
			_material.set_shader_parameter("dive", value)

var magnify := 1.0:
	set(value):
		magnify = value
		if _material:
			_material.set_shader_parameter("magnify", value)

var _material: ShaderMaterial


func _init() -> void:
	name = "Wolken"
	layer = 5
	var sheet := ColorRect.new()
	sheet.name = "Wolkendek"
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	sheet.material = _material
	add_child(sheet)
