extends Control
## The CRT look over a screen before the game (the intro, the main menu, the character
## creation): the shader of the HUD over the whole window (UiStyle.make_crt_overlay) with
## its disturbances (crt_disturbance.gd: a rolling band, now and then VHS tracking). The
## graphics layer: it is told whether the look is on, how big the window is and when the
## tape starts; it decides nothing.
##   const ScreenCrtView = preload("res://scripts/ui/menu/screen_crt_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
## How far the picture bends and how round its corners are with the look on (off: flat).
const CURVATURE := 0.05
const CORNER := 0.035

var _overlay: ColorRect


func _init() -> void:
	name = "CRT-beeld"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = UiStyle.make_crt_overlay(0.0, 0.0, Vector2.ZERO)
	add_child(_overlay)
	# now and then the picture is disturbed (a rolling band, VHS tracking)
	_overlay.add_child(CrtDisturbance.new())


## The look on (bent, round corners) or off (flat).
func show_crt(on: bool) -> void:
	_put("curvature", CURVATURE if on else 0.0)
	_put("corner", CORNER if on else 0.0)


## The size of the window (real pixels), for the lines of the screen.
func show_screen_size(screen_size: Vector2) -> void:
	_put("screen_size", screen_size)


## The tape starting: the picture loses its tracking (`amount`) and settles in `seconds`.
func play_tape_start(amount: float, seconds: float) -> void:
	_put("tracking", amount)
	create_tween().tween_method(func(now: float) -> void: _put("tracking", now), amount, 0.0, seconds)


## What the shader has for `parameter` now.
func shown(parameter: String) -> Variant:
	return (_overlay.material as ShaderMaterial).get_shader_parameter(parameter)


func _put(parameter: String, value: Variant) -> void:
	(_overlay.material as ShaderMaterial).set_shader_parameter(parameter, value)
