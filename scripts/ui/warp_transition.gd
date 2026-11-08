class_name WarpTransition
extends CanvasLayer
## The wave between the intro, the main menu and the town: the picture starts to ripple,
## its rows of pixels swaying ever wider and faster (the colours splitting a little, as a
## worn tape), while it sinks into ink blue (leave); the scene changes under it, and the
## new one comes up out of the ink still rippling, the waves dying down (on its own, on
## the tree's scene_changed).
##   await WarpTransition.leave(get_tree(), 1.6).covered
##   get_tree().change_scene_to_file(...)
## It lies over everything (a canvas layer under the root, which stays across the change,
## reading the picture under it) and runs while the tree is paused too.

signal covered

const NODE_NAME := "Warp"
## Seconds the new scene takes to come out of the wave.
const ARRIVE_SECONDS := 1.4
## Share of the leaving in which the ink covers the picture (at its end).
const COVER_SHARE := 0.45

const SHADER := """shader_type canvas_item;
// amount: 0 a still picture .. 1 full waves; cover: the ink over all; travel: the phase of
// the waves (it runs faster as they grow)
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float cover = 0.0;
uniform float travel = 0.0;
uniform vec4 ink : source_color = vec4(0.043, 0.051, 0.102, 1.0);

vec3 picture_at(vec2 spot) {
	return texture(screen, clamp(spot, vec2(0.001), vec2(0.999))).rgb;
}

void fragment() {
	vec2 spot = SCREEN_UV;
	float strength = amount * amount;
	// in rows of a few pixels, as the lines of a screen
	float row = floor(spot.y * 180.0) / 180.0;
	float sway = sin(row * 17.0 + travel * 5.0) * 0.05 + sin(row * 43.0 - travel * 8.0) * 0.014;
	float bob = sin(spot.x * 9.0 + travel * 3.5) * 0.022;
	vec2 wavy = spot + vec2(sway, bob) * strength;
	float split = 0.007 * strength;
	vec3 picture = vec3(picture_at(wavy + vec2(split, 0.0)).r, picture_at(wavy).g, picture_at(wavy - vec2(split, 0.0)).b);
	COLOR = vec4(mix(picture, ink.rgb, cover), 1.0);
}
"""

var _material: ShaderMaterial
var _amount := 0.0
var _travel := 0.0
var _tween: Tween


## Starts the warp out of the current scene (`seconds` long, ending covered: await its
## `covered`) and returns it; the next scene comes out of it by itself.
static func leave(tree: SceneTree, seconds: float) -> WarpTransition:
	var warp := tree.root.get_node_or_null(NODE_NAME) as WarpTransition
	if warp == null:
		warp = WarpTransition.new()
		warp.name = NODE_NAME
		tree.root.add_child(warp)
	warp._leave(seconds)
	return warp


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var screen := ColorRect.new()
	screen.name = "Golf"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	screen.material = _material
	add_child(screen)


func _process(delta: float) -> void:
	_travel += delta * (0.4 + _amount * 2.2)
	_material.set_shader_parameter("travel", _travel)


func _set_amount(amount: float) -> void:
	_amount = amount
	_material.set_shader_parameter("amount", amount)


func _set_cover(cover: float) -> void:
	_material.set_shader_parameter("cover", cover)


func _leave(seconds: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_amount, _amount, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_cover, 0.0, 1.0, seconds * COVER_SHARE).set_delay(seconds * (1.0 - COVER_SHARE))
	_tween.chain().tween_callback(covered.emit)
	if not get_tree().scene_changed.is_connected(_arrive):
		get_tree().scene_changed.connect(_arrive, CONNECT_ONE_SHOT)


## Out of the wave into the new scene: the ink clears, the waves die down.
func _arrive() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_cover, 1.0, 0.0, ARRIVE_SECONDS * 0.5)
	_tween.tween_method(_set_amount, 1.0, 0.0, ARRIVE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(queue_free)
