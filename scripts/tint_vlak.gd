@tool
class_name TintVlak
extends Node3D
## Een rechthoek (in cellen van 4 m) die alles eronder een tint geeft.
## Wit = geen verandering; helderheid > 1 maakt lichter, < 1 donkerder.

@export var kleur := Color(1, 0.85, 0.75):
	set(v):
		kleur = v
		_update_preview()
@export_range(0.0, 2.0) var helderheid := 1.0
@export_range(0.0, 1.0) var sterkte := 1.0
@export var grootte := Vector2i(1, 1):
	set(v):
		grootte = Vector2i(maxi(1, v.x), maxi(1, v.y))
		_update_preview()

var _preview: MeshInstance3D


func _ready() -> void:
	_update_preview()


func _update_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		_preview.material_override = m
		add_child(_preview)
	(_preview.mesh as BoxMesh).size = Vector3(grootte.x * 4.0, 0.1, grootte.y * 4.0)
	(_preview.material_override as StandardMaterial3D).albedo_color = Color(kleur.r, kleur.g, kleur.b, 0.25)
