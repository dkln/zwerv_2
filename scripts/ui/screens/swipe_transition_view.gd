extends TextureRect
## How the wipe between two pictures looks (the graphics layer of
## scripts/ui/swipe_transition.gd, which is the behaviour and has this as its child;
## swipe_transition_rules.gd has the logic; there is no layout file: it fills the screen):
## the picture as it was, held as a still over everything, with the shader that wipes it
## away left of a hard straight edge. It shows what it is handed (show_still, show_edge) and
## sweeps the edge across (play_wipe); it decides nothing.
##   const SwipeTransitionView = preload("res://scripts/ui/screens/swipe_transition_view.gd")

## Seconds the edge takes across (slowly, as in the films).
const WIPE_SECONDS := 1.1

const SHADER := """shader_type canvas_item;
// the still of the old picture, wiped away left of `edge` (0 at the left .. 1 past the right)
uniform float edge = 0.0;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	if (UV.x < edge) {
		discard;
	}
}
"""

var _material: ShaderMaterial


func _init() -> void:
	name = "Beeld"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP   # no clicks through it meanwhile
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	material = _material


## Holds `image` (the picture as it was) as the still.
func show_still(image: Image) -> void:
	texture = ImageTexture.create_from_image(image)


## Puts the edge at `value`: 0 the whole still, 1 all of it wiped away.
func show_edge(value: float) -> void:
	_material.set_shader_parameter("edge", value)


## Where the edge is now (0..1).
func edge() -> float:
	var value: Variant = _material.get_shader_parameter("edge")
	return float(value) if value != null else 0.0


## Sweeps the edge from left to right in WIPE_SECONDS, also while the tree is paused; the
## tween it runs on (its `finished` says the edge is through).
func play_wipe() -> Tween:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(show_edge, 0.0, 1.0, WIPE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween
