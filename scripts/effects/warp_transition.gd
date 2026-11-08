class_name WarpTransition
extends CanvasLayer
## The warp between the intro, the main menu and the town: stars streak out from the middle
## of the screen, ever longer and faster, until they and an ink-blue fill cover all (leave);
## the scene changes under it, and in the new one the streaks slow down and shrink away
## again while the fill clears (on its own, on the tree's scene_changed).
##   await WarpTransition.leave(get_tree(), 1.6).covered
##   get_tree().change_scene_to_file(...)
## It lies over everything (a canvas layer under the root, which stays across the change)
## and runs while the tree is paused too.

signal covered

const NODE_NAME := "Warp"
## Seconds the new scene takes to come out of the warp.
const ARRIVE_SECONDS := 1.3
## Share of the leaving in which the fill covers the screen (at its end).
const COVER_SHARE := 0.3

const SHADER := """shader_type canvas_item;
// amount: 0 nothing .. 1 full warp (long fast streaks); cover: the ink fill over all;
// travel: how far the stars have come (grows faster as the warp goes harder)
uniform float amount = 0.0;
uniform float cover = 0.0;
uniform float travel = 0.0;
uniform float aspect = 1.7778;
uniform vec4 ink : source_color = vec4(0.043, 0.051, 0.102, 1.0);
uniform vec4 star : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.78, 0.35, 1.0);

float hash(float seed) {
	return fract(sin(seed * 127.1 + 311.7) * 43758.5453);
}

void fragment() {
	vec2 centred = (UV - 0.5) * vec2(aspect, 1.0);
	float radius = length(centred);
	float around = atan(centred.y, centred.x) / 6.2831853 + 0.5;
	float light = 0.0;
	float warmth = 0.0;
	// three layers of lanes (rays out from the middle), a star in some of each
	for (int layer = 0; layer < 3; layer++) {
		float lanes = 160.0 + float(layer) * 70.0;
		float lane = floor(around * lanes);
		float across = abs(fract(around * lanes) - 0.5);
		float seed = lane + float(layer) * 997.0;
		if (hash(seed + 5.0) < 0.45) {
			continue;
		}
		float pace = 0.5 + hash(seed + 1.0);
		// the head of the streak runs outwards and comes back in the middle
		float head = fract(hash(seed + 2.0) + travel * pace) * 1.3;
		float tail = head - (0.004 + amount * amount * (0.25 + 0.45 * hash(seed + 3.0)));
		float on_streak = step(tail, radius) * step(radius, head);
		float towards_head = clamp((radius - tail) / max(head - tail, 0.001), 0.0, 1.0);
		// thin, and thinner (in angle) further out so it keeps a few pixels wide
		float thin = 1.0 - smoothstep(0.08, 0.32 + 0.1 / max(radius * 8.0, 1.0), across);
		float streak = on_streak * thin * towards_head;
		light += streak;
		warmth += streak * step(0.8, hash(seed + 9.0));
	}
	light = clamp(light, 0.0, 1.0) * smoothstep(0.0, 0.12, amount) * smoothstep(0.015, 0.12, radius);
	// held to a few levels, as the pixel look of the rest
	light = floor(light * 4.0 + 0.5) / 4.0;
	vec3 streak_colour = mix(star.rgb, warm.rgb, clamp(warmth, 0.0, 1.0));
	// the screen darkens behind the streaks as the warp grows, a glow in the middle
	float behind = amount * 0.55;
	float glow = amount * amount * 0.5 * (1.0 - smoothstep(0.0, 0.35, radius));
	vec3 colour = mix(ink.rgb, streak_colour, light) + vec3(glow) * star.rgb;
	float alpha = clamp(max(max(behind, light * smoothstep(0.0, 0.3, amount)), cover) + glow, 0.0, 1.0);
	colour = mix(colour, ink.rgb, cover * (1.0 - light * 0.6));
	COLOR = vec4(colour, alpha);
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
	screen.name = "Strepen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	screen.material = _material
	add_child(screen)


func _process(delta: float) -> void:
	_travel += delta * (0.15 + _amount * _amount * 2.6)
	_material.set_shader_parameter("travel", _travel)
	var window := get_viewport().get_visible_rect().size
	_material.set_shader_parameter("aspect", window.x / maxf(window.y, 1.0))


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


## Out of the warp into the new scene: the fill clears fast, the streaks slow and shrink.
func _arrive() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_cover, 1.0, 0.0, ARRIVE_SECONDS * 0.3)
	_tween.tween_method(_set_amount, 1.0, 0.0, ARRIVE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(queue_free)
