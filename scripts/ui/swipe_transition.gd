extends CanvasLayer
## A wipe as in the old films (the Star Wars wipe): the picture as it was is held (a still of
## it, over everything), the change happens behind it, and a hard straight edge sweeps slowly
## across from left to right, wiping the old picture away to show the new one behind it. For
## going into or out of a building (Interiors) and between the main menu and the character
## creation. `covered` fires once the still is up (change what you like then: it is not seen),
## `finished` when the edge is through. It runs while the tree is paused too.
##   const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
##   var swipe := SwipeTransition.swipe(get_tree())
##   await swipe.covered
##   ... (teleport, change the scene)

signal covered
signal finished

const NODE_NAME := "Swipe"
## Frames the new picture gets to settle under the still before the wipe starts, and the
## seconds the edge takes across (slowly, as in the films).
const SETTLE_FRAMES := 3
const WIPE_SECONDS := 1.1
const LAYER := 128

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

## True once `covered` has fired.
var has_covered := false
var _still: TextureRect
var _material: ShaderMaterial


## Starts a wipe over everything. A running one that has not covered yet is returned (so two
## calls in one frame make one wipe); one that already covered (its edge under way) makes way
## for a new one, so `covered` of what is returned always still comes.
static func swipe(tree: SceneTree) -> CanvasLayer:
	var running := tree.root.get_node_or_null(NODE_NAME) as CanvasLayer
	if running:
		if not running.get("has_covered"):
			return running
		running.name = NODE_NAME + "_vorige"
	var transition: CanvasLayer = (load("res://scripts/ui/swipe_transition.gd") as GDScript).new()
	tree.root.add_child(transition)
	transition.call("_run")
	return transition


func _init() -> void:
	name = NODE_NAME
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_still = TextureRect.new()
	_still.set_anchors_preset(Control.PRESET_FULL_RECT)
	_still.stretch_mode = TextureRect.STRETCH_SCALE
	_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_still.mouse_filter = Control.MOUSE_FILTER_STOP   # no clicks through it meanwhile
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	_still.material = _material
	add_child(_still)


func _set_edge(value: float) -> void:
	_material.set_shader_parameter("edge", value)


func _run() -> void:
	# the picture as it is now (the last frame drawn), held
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image and not image.is_empty():
		_still.texture = ImageTexture.create_from_image(image)
	_set_edge(0.0)
	has_covered = true
	covered.emit()
	for frame_index in SETTLE_FRAMES:
		await get_tree().process_frame
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_edge, 0.0, 1.0, WIPE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	finished.emit()
	queue_free()
