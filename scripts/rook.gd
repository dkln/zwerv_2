@tool
class_name Rook
extends Node3D
## Zet rookpluimen op alle fabrieksschoorstenen (en optioneel op gewone schoorstenen)
## in de GridMaps van de scene. Werkt ook live in de editor.

@export var gebouwen_pad := NodePath("../Gebouwen")
@export var details_pad := NodePath("../Details")
@export var ook_kleine_schoorstenen := true
@export var wind := Vector3(1.2, 0, -0.6)
@export var opnieuw_zoeken := false:
	set(v):
		_bouw()


func _ready() -> void:
	_bouw()


func _bouw() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()
	var gb := get_node_or_null(gebouwen_pad) as GridMap
	if gb and gb.mesh_library:
		for cel in gb.get_used_cells():
			var nm := gb.mesh_library.get_item_name(gb.get_cell_item(cel))
			if nm.contains("fabrieksschoorsteen_top"):
				var p := gb.to_global(gb.map_to_local(cel)) + Vector3(0, 3.6, 0)
				_pluim(p, 1.0)
	if ook_kleine_schoorstenen:
		var dt := get_node_or_null(details_pad) as GridMap
		if dt and dt.mesh_library:
			for cel in dt.get_used_cells():
				var nm := dt.mesh_library.get_item_name(dt.get_cell_item(cel))
				if nm.contains("dak/schoorsteen"):
					var p := dt.to_global(dt.map_to_local(cel)) + Vector3(0, 2.1, 0)
					_pluim(p, 0.35)


func _pluim(pos: Vector3, schaal: float) -> void:
	var g := GPUParticles3D.new()
	g.amount = int(40 * schaal) + 10
	g.lifetime = 9.0 * (0.6 + schaal * 0.4)
	g.preprocess = 8.0
	g.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2 * schaal + 0.4
	pm.initial_velocity_max = 2.0 * schaal + 0.6
	pm.gravity = wind * 0.25 + Vector3(0, 0.15, 0)
	pm.damping_min = 0.3
	pm.damping_max = 0.6
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6 * schaal + 0.1
	pm.scale_min = 1.0 * schaal + 0.3
	pm.scale_max = 1.6 * schaal + 0.4
	var groei := Curve.new()
	groei.add_point(Vector2(0, 0.4))
	groei.add_point(Vector2(1, 3.0))
	var ct := CurveTexture.new()
	ct.curve = groei
	pm.scale_curve = ct
	var verloop := Gradient.new()
	verloop.set_color(0, Color(0.55, 0.55, 0.57, 0.0))
	verloop.add_point(0.08, Color(0.6, 0.6, 0.62, 0.55))
	verloop.add_point(0.5, Color(0.72, 0.72, 0.74, 0.35))
	verloop.set_color(verloop.get_point_count() - 1, Color(0.85, 0.85, 0.87, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = verloop
	pm.color_ramp = gt
	g.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _rond()
	mat.roughness = 1.0
	quad.material = mat
	g.draw_pass_1 = quad
	add_child(g)
	g.global_position = pos


static var _tex: Texture2D

static func _rond() -> Texture2D:
	if _tex:
		return _tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_tex = ImageTexture.create_from_image(img)
	return _tex
