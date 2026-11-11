extends Control
## Numbers that float up from a point in the world and fade: the money picked up ("+€ 0,50",
## scripts/world/loose_change.gd) and the damage the player takes ("-12",
## PlayerController._hurt). Drawn in the HUD picture (hud.gd, show_floating_number), not in
## 3D, so they stay sharp whatever the 3D render scale is: a pixel font at a fixed size on
## the screen, with the faux 3D of the game's texts: a copy of the text a few pixels lower,
## behind it, in its colour half as light (UiStyle.faux_3d_colour); no outline. Each frame the point is projected through the
## camera; a number behind the camera is hidden.
##   floating_numbers.spawn(world_position, "+€ 0,50", Color("#E8B83A"))

## Seconds a number lives, how many metres it rises in that time, and when it starts to fade.
const LIFETIME := 1.1
const RISE_METRES := 1.4
const FADE_FROM := 0.45
## The pop when it appears: this much bigger, shrinking back in POP_SECONDS.
const POP_SCALE := 1.25
const POP_SECONDS := 0.12
## How far the black shadow copy sits below the coloured text, in design pixels.
const SHADOW_OFFSET := Vector2(0.0, 3.0)
const UiStyle = preload("res://scripts/ui/ui_style.gd")
## A few pixels of sideways spread, so numbers on the same spot do not cover each other.
const SPREAD_PIXELS := 14.0

var font: Font
## Seconds a number lives here (LIFETIME; longer over the story box, where it is read along).
var lifetime := LIFETIME
## The viewport whose camera looks at the world (the HUD itself draws in a SubViewport
## without 3D, so it is handed the main one).
var world_viewport: Viewport

var _numbers: Array[Dictionary] = []   # {"label": Label, "from": Vector3, "age": float, "shift": float}
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_random.randomize()


## A number rising from `world_position`, in `colour`, `font_size` design pixels high.
func spawn(world_position: Vector3, text: String, colour: Color, font_size := 16) -> void:
	var label := _text_label(text, colour, font_size)
	label.visible = false
	add_child(label)
	label.reset_size()
	# the shadow is a child, so it follows the pop, the rise and the fade of the text itself
	var shadow := _text_label(text, UiStyle.faux_3d_colour(colour), font_size)
	shadow.show_behind_parent = true
	label.add_child(shadow)
	shadow.reset_size()
	shadow.position = SHADOW_OFFSET
	label.pivot_offset = label.size * 0.5
	_numbers.append({"label": label, "from": world_position, "age": 0.0,
			"shift": _random.randf_range(-SPREAD_PIXELS, SPREAD_PIXELS)})
	_place(_numbers[-1])


func _text_label(text: String, colour: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	return label


func _process(delta: float) -> void:
	for index in range(_numbers.size() - 1, -1, -1):
		var number: Dictionary = _numbers[index]
		number.age += delta
		if number.age >= lifetime:
			(number.label as Label).queue_free()
			_numbers.remove_at(index)
			continue
		_place(number)


func _place(number: Dictionary) -> void:
	var label: Label = number.label
	var camera := (world_viewport if world_viewport else get_viewport()).get_camera_3d()
	var share: float = number.age / lifetime
	var at: Vector3 = number.from + Vector3.UP * RISE_METRES * (1.0 - pow(1.0 - share, 2.0))
	if camera == null or camera.is_position_behind(at):
		label.visible = false
		return
	# the camera projects into window pixels; the HUD's design root is scaled to the window
	var root_scale := get_global_transform().get_scale().x
	var on_screen := camera.unproject_position(at) / maxf(root_scale, 0.001)
	label.visible = true
	label.position = (on_screen - label.size * 0.5 + Vector2(number.shift, 0.0)).round()
	var pop := clampf(number.age / POP_SECONDS, 0.0, 1.0)
	label.scale = Vector2.ONE * lerpf(POP_SCALE, 1.0, pop)
	label.modulate.a = 1.0 - clampf((share - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
