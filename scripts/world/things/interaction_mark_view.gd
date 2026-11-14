extends Node3D
## What the arrow bobbing over something you can use looks like (graphics;
## docs/CODE_LAGEN.md; interaction_mark.gd): a flat arrow always facing the camera, in the
## colour of the game's accents, with the faux 3D of the texts (UiStyle.faux_3d): a darker
## copy a little under it, drawn behind. Outside drawn over everything (no depth test), so a
## tree or an awning before it never hides it; inside (`through_walls` false) as anything
## else. It shows what interaction_mark.gd hands it (show_at, show_hidden); its shape comes
## from interaction_mark_layout.gd.
##   const InteractionMarkView = preload("res://scripts/world/things/interaction_mark_view.gd")
##   var view := InteractionMarkView.create(true)

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const InteractionMarkLayout = preload("res://scripts/world/things/interaction_mark_layout.gd")
const MARK_COLOUR := Color("#FFB830")

var _arrow: MeshInstance3D
var _arrow_shadow: MeshInstance3D


## The picture of an arrow (the node "Beeld": "Pijl" and "Pijl_schaduw"), hidden until it is
## shown; `through_walls`: drawn over everything.
static func create(through_walls: bool) -> Node3D:
	var view: Node3D = (load("res://scripts/world/things/interaction_mark_view.gd") as GDScript).new()
	view.name = "Beeld"
	view.call("_build", through_walls)
	return view


## The arrow in view, its point `height` metres up.
func show_at(height: float) -> void:
	_arrow.visible = true
	_arrow_shadow.visible = true
	_arrow.position = InteractionMarkLayout.arrow_place(height)
	_arrow_shadow.position = InteractionMarkLayout.shadow_place(height)


## The arrow out of view.
func show_hidden() -> void:
	_arrow.visible = false
	_arrow_shadow.visible = false


## Whether the arrow is in view.
func is_shown() -> bool:
	return _arrow.visible


## How high the point of the arrow stands.
func height() -> float:
	return _arrow.position.y


func _build(through_walls: bool) -> void:
	var shape := _arrow_mesh()
	_arrow = _make_arrow("Pijl", shape, MARK_COLOUR, 1, through_walls)
	_arrow_shadow = _make_arrow("Pijl_schaduw", shape, UiStyle.faux_3d_colour(MARK_COLOUR), 0, through_walls)


## The flat arrow, its point at the origin, the head below and the shaft above it.
static func _arrow_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = InteractionMarkLayout.arrow_corners()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One arrow of `shape` in `colour`: unshaded, facing the camera (billboard), both sides
## drawn, over everything; in `priority` order: the darker copy first, the arrow over it.
func _make_arrow(arrow_name: String, shape: ArrayMesh, colour: Color, priority: int, through_walls: bool) -> MeshInstance3D:
	var arrow := MeshInstance3D.new()
	arrow.name = arrow_name
	arrow.mesh = shape
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = through_walls
	material.render_priority = priority
	arrow.material_override = material
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.visible = false
	add_child(arrow)
	return arrow
