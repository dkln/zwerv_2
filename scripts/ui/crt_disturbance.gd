class_name CrtDisturbance
extends Node
## Now and then disturbs the CRT picture it hangs under (a child of a CRT overlay made by
## GameHud.make_crt_overlay): a lighter band rolls down the screen (the shader's glitch_y,
## glitch_strength) in `roll_seconds`, every `every` seconds (from .. to); at
## `tracking_chance` of those the tape loses its tracking as well (the shader's tracking:
## lines jumping sideways, the picture wobbling, the colours slipping, noise), which comes
## on hard and fades in `tracking_seconds`. Used by the main menu and the intro.

@export var every := Vector2(6.0, 16.0)
@export var first_after := 4.0
@export var roll_seconds := 0.7
@export var tracking_chance := 0.45
@export var tracking_seconds := 1.4

var _wait := 0.0


func _ready() -> void:
	_wait = first_after


func _process(delta: float) -> void:
	var overlay := get_parent() as CanvasItem
	if overlay == null or not (overlay.material is ShaderMaterial):
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = randf_range(every.x, every.y)
	var material := overlay.material as ShaderMaterial
	material.set_shader_parameter("glitch_strength", randf_range(0.6, 1.0))
	var roll := create_tween()
	roll.tween_method(func(height: float) -> void: material.set_shader_parameter("glitch_y", height), -0.06, 1.06, roll_seconds)
	roll.tween_callback(func() -> void: material.set_shader_parameter("glitch_y", -1.0))
	if randf() < tracking_chance:
		var strength := randf_range(0.5, 1.0)
		var trouble := create_tween()
		trouble.tween_method(func(amount: float) -> void: material.set_shader_parameter("tracking", amount), 0.0, strength, 0.12)
		trouble.tween_method(func(amount: float) -> void: material.set_shader_parameter("tracking", amount), strength, strength * 0.4, tracking_seconds * 0.5)
		trouble.tween_method(func(amount: float) -> void: material.set_shader_parameter("tracking", amount), strength * 0.4, 0.0, tracking_seconds * 0.5)
