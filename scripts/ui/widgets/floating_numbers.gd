extends Control
## Numbers that float up from a point in the world and fade: the money picked up ("+€ 0,50",
## scripts/world/things/loose_change.gd) and the damage the player takes ("-12",
## PlayerController._hurt). Drawn in the HUD picture (hud.gd, show_floating_number), not in
## 3D, so they stay sharp whatever the 3D render scale is. Each frame the point is projected
## through the camera; a number behind the camera is hidden. Behaviour (docs/CODE_LAGEN.md):
## it keeps the numbers and their age; the course of a number's life is
## floating_numbers_rules.gd, its place on the screen floating_numbers_layout.gd, its looks
## floating_numbers_view.gd.
##   const FloatingNumbers = preload("res://scripts/ui/widgets/floating_numbers.gd")
##   floating_numbers.spawn(world_position, "+€ 0,50", Color("#E8B83A"))

const FloatingNumbersRules = preload("res://scripts/ui/widgets/floating_numbers_rules.gd")
const FloatingNumbersLayout = preload("res://scripts/ui/widgets/floating_numbers_layout.gd")
const FloatingNumbersView = preload("res://scripts/ui/widgets/floating_numbers_view.gd")
const LIFETIME := FloatingNumbersRules.LIFETIME

## The font of the numbers (none: the default font).
var font: Font:
	set(value):
		font = value
		view.font = value
## Seconds a number lives here (LIFETIME; longer over the story box, where it is read along).
var lifetime := LIFETIME
## The viewport whose camera looks at the world (the HUD itself draws in a SubViewport
## without 3D, so it is handed the main one).
var world_viewport: Viewport
## Its picture.
var view: FloatingNumbersView

var _numbers: Array[Dictionary] = []   # {"label": Label, "from": Vector3, "age": float, "shift": float}
var _random := RandomNumberGenerator.new()


func _init() -> void:
	view = FloatingNumbersView.new()
	add_child(view)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_random.randomize()


## A number rising from `world_position`, in `colour`, `font_size` design pixels high.
func spawn(world_position: Vector3, text: String, colour: Color, font_size := FloatingNumbersLayout.FONT_SIZE) -> void:
	var label := view.add_number(text, colour, font_size)
	_numbers.append({"label": label, "from": world_position, "age": 0.0,
			"shift": _random.randf_range(-FloatingNumbersLayout.SPREAD_PIXELS, FloatingNumbersLayout.SPREAD_PIXELS)})
	_place(_numbers[-1])


func _process(delta: float) -> void:
	for index in range(_numbers.size() - 1, -1, -1):
		var number: Dictionary = _numbers[index]
		number.age += delta
		if FloatingNumbersRules.is_over(number.age, lifetime):
			view.remove_number(number.label)
			_numbers.remove_at(index)
			continue
		_place(number)


func _place(number: Dictionary) -> void:
	var label: Label = number.label
	var camera := (world_viewport if world_viewport else get_viewport()).get_camera_3d()
	var share := FloatingNumbersRules.life_share(number.age, lifetime)
	var at := FloatingNumbersRules.place(number.from, share)
	if camera == null or camera.is_position_behind(at):
		view.hide_number(label)
		return
	# the camera projects into window pixels; the HUD's design root is scaled to the window
	var on_screen := FloatingNumbersLayout.design_point(camera.unproject_position(at), get_global_transform().get_scale().x)
	view.show_number(label, FloatingNumbersLayout.label_position(on_screen, label.size, number.shift),
			FloatingNumbersRules.pop_scale(number.age), FloatingNumbersRules.opacity(share))
