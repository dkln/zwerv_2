extends Node3D
## The big arrow bobbing over something you can use (a way in, someone who sells): a flat
## "->" arrow (a shaft with a head) pointing down at it, always facing the camera, in the
## colour of the game's accents, with the faux 3D of the texts (UiStyle.faux_3d): a darker
## copy a little under it, drawn behind. Drawn over everything (no depth test), so a tree or
## an awning before it never hides it. It shows only when the player is within MARK_FROM and
## bobs between `bottom` and `top` (the height of its point).
##   const InteractionMark = preload("res://scripts/world/interaction_mark.gd")
##   var mark := InteractionMark.create(2.5, 3.3)
##   door.add_child(mark)
##   mark.follow(player)        # every frame

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const InteractionMark = preload("res://scripts/world/interaction_mark.gd")

## From how far the arrow shows (metres).
const MARK_FROM := 22.0
## The arrow (metres): the width and height of the head, the width and length of the shaft.
const MARK_COLOUR := Color("#FFB830")
const HEAD_WIDTH := 0.8
const HEAD_HEIGHT := 0.5
const SHAFT_WIDTH := 0.3
const SHAFT_LENGTH := 0.5
## How it bobs (once up and down in BOB_SECONDS), and how far under it its darker copy lies.
const BOB_SECONDS := 1.2
const SHADOW_DROP := 0.09

var bottom := 2.5
var top := 3.3
var _arrow: MeshInstance3D
var _arrow_shadow: MeshInstance3D
var _clock := 0.0


## An arrow bobbing between `low` and `high` over its parent (its point at those heights).
static func create(low: float, high: float) -> InteractionMark:
	var mark := InteractionMark.new()
	mark.name = "Aanwijzer"
	mark.bottom = low
	mark.top = high
	var shape := _arrow_mesh()
	mark._arrow = mark._make_arrow("Pijl", shape, MARK_COLOUR, 1)
	mark._arrow_shadow = mark._make_arrow("Pijl_schaduw", shape, UiStyle.faux_3d_colour(MARK_COLOUR), 0)
	return mark


## Shows it when `player` is near (and `allowed`), and moves it along: call every frame.
func follow(player: Node3D, allowed := true) -> void:
	var near := allowed and player != null and is_inside_tree() \
			and player.global_position.distance_to(global_position) < MARK_FROM
	_arrow.visible = near
	_arrow_shadow.visible = near
	if not near:
		return
	_clock += get_process_delta_time()
	var swing := 0.5 + 0.5 * sin(_clock * TAU / BOB_SECONDS)
	_arrow.position = Vector3(0.0, lerpf(bottom, top, swing), 0.0)
	_arrow_shadow.position = _arrow.position + Vector3(0.0, -SHADOW_DROP, 0.0)


## The flat arrow, its point at the origin, the head below and the shaft above it.
static func _arrow_mesh() -> ArrayMesh:
	var half_head := HEAD_WIDTH * 0.5
	var half_shaft := SHAFT_WIDTH * 0.5
	var shaft_top := HEAD_HEIGHT + SHAFT_LENGTH
	var point := Vector3(0.0, 0.0, 0.0)
	var head_left := Vector3(-half_head, HEAD_HEIGHT, 0.0)
	var head_right := Vector3(half_head, HEAD_HEIGHT, 0.0)
	var shaft_bottom_left := Vector3(-half_shaft, HEAD_HEIGHT, 0.0)
	var shaft_bottom_right := Vector3(half_shaft, HEAD_HEIGHT, 0.0)
	var shaft_top_left := Vector3(-half_shaft, shaft_top, 0.0)
	var shaft_top_right := Vector3(half_shaft, shaft_top, 0.0)
	var corners := PackedVector3Array([
		point, head_right, head_left,
		shaft_bottom_left, shaft_bottom_right, shaft_top_right,
		shaft_bottom_left, shaft_top_right, shaft_top_left,
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = corners
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One arrow of `shape` in `colour`: unshaded, facing the camera (billboard), both sides
## drawn, over everything; in `priority` order: the darker copy first, the arrow over it.
func _make_arrow(arrow_name: String, shape: ArrayMesh, colour: Color, priority: int) -> MeshInstance3D:
	var arrow := MeshInstance3D.new()
	arrow.name = arrow_name
	arrow.mesh = shape
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	arrow.material_override = material
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.visible = false
	add_child(arrow)
	return arrow
