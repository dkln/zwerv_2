@tool
extends MultiMeshInstance3D
## What is seen of the lane arrows in the editor (the graphics layer of
## scripts/traffic/lane_arrows.gd): flat arrows on the road, one MultiMesh, a colour per
## arrow, unshaded and without shadow. It draws the arrows it is given (show_arrows:
## {placement, color} each) and decides nothing; the shape comes from lane_arrows_layout.gd.
##   const LaneArrowsView = preload("res://scripts/traffic/lane_arrows_view.gd")

const LaneArrowsLayout = preload("res://scripts/traffic/lane_arrows_layout.gd")

## The colours of the kinds of arrow (the defaults of the exports of lane_arrows.gd).
const FIXED_COLOR := Color(1.0, 0.85, 0.1)
const CONTEXT_COLOR := Color(0.35, 0.8, 1.0)
const OPEN_COLOR := Color(1.0, 0.2, 0.8)
const CHOSEN_COLOR := Color(0.3, 1.0, 0.35)

var _material: StandardMaterial3D


func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = _material


## Shows these arrows ({placement: world transform, color}), in place of the ones before.
func show_arrows(arrows: Array) -> void:
	multimesh = multimesh_of(arrows)
	if is_inside_tree():
		global_transform = Transform3D.IDENTITY


## Shows the arrows through buildings and bridges too, or not.
func show_through_walls(through: bool) -> void:
	_material.no_depth_test = through


## The arrows ({placement, color}) as a MultiMesh with a colour per arrow.
static func multimesh_of(arrows: Array) -> MultiMesh:
	var arrow_multimesh := MultiMesh.new()
	arrow_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	arrow_multimesh.use_colors = true
	arrow_multimesh.mesh = arrow_mesh()
	arrow_multimesh.instance_count = arrows.size()
	for index in arrows.size():
		arrow_multimesh.set_instance_transform(index, arrows[index].placement)
		arrow_multimesh.set_instance_color(index, arrows[index].color)
	return arrow_multimesh


## The mesh of one arrow (LaneArrowsLayout.arrow_corners).
static func arrow_mesh() -> ArrayMesh:
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = LaneArrowsLayout.arrow_corners()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh
