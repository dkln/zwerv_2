extends CanvasLayer
## Tilt-shift lens effect (the "TiltShift" node): a full-screen ColorRect with
## tilt_shift.gdshader over the 3D view, sharp in a horizontal band and blurred towards
## the top and bottom, so the city looks like a miniature. The layer lies under the
## default UI layer, so captions and other UI stay sharp. `enabled` off = no effect.

const SHADER = preload("res://scripts/effects/tilt_shift.gdshader")

@export var enabled := true:
	set(v):
		enabled = v
		if _rect:
			_rect.visible = v
## Height of the middle of the sharp band (0 = top of the screen, 1 = bottom).
@export_range(0.0, 1.0) var focus_center := 0.55:
	set(v):
		focus_center = v
		_apply()
## Half the height of the sharp band, as a fraction of the screen height.
@export_range(0.0, 0.5) var focus_width := 0.1:
	set(v):
		focus_width = v
		_apply()
## Distance over which the blur grows from nothing to full.
@export_range(0.01, 1.0) var falloff := 0.3:
	set(v):
		falloff = v
		_apply()
## Blur radius at full blur, as a fraction of the screen height.
@export_range(0.0, 0.05) var max_blur := 0.012:
	set(v):
		max_blur = v
		_apply()
## Sharpening in the sharp band (0 = none).
@export_range(0.0, 1.5) var sharpen := 0.45:
	set(v):
		sharpen = v
		_apply()
## Extra saturation (1 = unchanged).
@export_range(0.0, 2.0) var saturation := 1.12:
	set(v):
		saturation = v
		_apply()

var _rect: ColorRect


func _ready() -> void:
	layer = -1
	_rect = ColorRect.new()
	_rect.name = "Lens"
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
	var m: ShaderMaterial = _rect.material
	m.set_shader_parameter("focus_center", focus_center)
	m.set_shader_parameter("focus_width", focus_width)
	m.set_shader_parameter("falloff", falloff)
	m.set_shader_parameter("max_blur", max_blur)
	m.set_shader_parameter("saturation", saturation)
	m.set_shader_parameter("sharpen", sharpen)
