extends CanvasLayer
## Vignette over the 3D view (the "Vignet" node): a full-screen ColorRect with
## vignette.gdshader that darkens the picture towards the edges. It is an overlay blended
## over the picture (it never reads the screen), so it costs next to nothing. The layer
## lies under the default UI layer, so captions and other UI are not darkened.
## `enabled` off = no vignette.

const SHADER = preload("res://scripts/effects/vignette.gdshader")

@export var enabled := true:
	set(value):
		enabled = value
		if _rect:
			_rect.visible = value
## Darkness at the very corners (0 = none, 1 = the full shade colour).
@export_range(0.0, 1.0) var strength := 0.7:
	set(value):
		strength = value
		_apply()
## Distance from the middle (0) to the edge (1) where the darkening starts.
@export_range(0.0, 1.5) var inner := 0.4:
	set(value):
		inner = value
		_apply()
## Distance over which it grows to full strength.
@export_range(0.01, 1.5) var softness := 0.8:
	set(value):
		softness = value
		_apply()

var _rect: ColorRect


func _ready() -> void:
	layer = -1
	_rect = ColorRect.new()
	_rect.name = "Rand"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = ShaderMaterial.new()
	_rect.material.shader = SHADER
	_rect.visible = enabled
	add_child(_rect)
	_apply()


func _apply() -> void:
	if _rect == null:
		return
	var material: ShaderMaterial = _rect.material
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("inner", inner)
	material.set_shader_parameter("softness", softness)
