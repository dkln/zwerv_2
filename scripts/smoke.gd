@tool
class_name Smoke
extends Node3D
## Smoke plumes (the "Rook" node of the world scene): puts a GPUParticles3D plume on
## every factory chimney top in the Gebouwen GridMap and, optionally, on every roof
## chimney in the Details GridMap. The plumes are generated children of this node
## (not saved in the scene) and are rebuilt on load; also works live in the editor.

## Static so all plumes share one texture.
static var _tex: Texture2D

@export var buildings_path := NodePath("../Gebouwen")
@export var details_path := NodePath("../Details")
## Also smoke from the small roof chimneys (Details layer).
@export var include_small_chimneys := true
## Wind (world space); a quarter of it is used as the particles' drift acceleration (m/s²).
@export var wind := Vector3(1.2, 0, -0.6)
## Inspector button: tick it to rebuild the plumes after editing the map.
@export var rescan := false:
	set(v):
		_build()


func _ready() -> void:
	_build()


## Removes all plumes and creates new ones for the chimneys currently in the GridMaps.
func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()
	_scan(buildings_path, "fabrieksschoorsteen_top", 3.6, 1.0)
	if include_small_chimneys:
		_scan(details_path, "dak/schoorsteen", 2.1, 0.35)


## Adds a plume of size `plume_scale` (1 = factory chimney) `height` metres above the
## centre of every cell of the GridMap at `path` whose item name contains `item_part`.
func _scan(path: NodePath, item_part: String, height: float, plume_scale: float) -> void:
	var gm := get_node_or_null(path) as GridMap
	if gm == null or gm.mesh_library == null:
		return
	for cell in gm.get_used_cells():
		if gm.mesh_library.get_item_name(gm.get_cell_item(cell)).contains(item_part):
			_plume(gm.to_global(gm.map_to_local(cell)) + Vector3(0, height, 0), plume_scale)


## Creates one smoke plume at world position `pos`. plume_scale scales amount,
## lifetime, speed and puff size (1 = factory chimney, 0.35 = roof chimney).
func _plume(pos: Vector3, plume_scale: float) -> void:
	var g := GPUParticles3D.new()
	g.amount = int(40 * plume_scale) + 10
	g.lifetime = 9.0 * (0.6 + plume_scale * 0.4)
	g.preprocess = 8.0
	g.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2 * plume_scale + 0.4
	pm.initial_velocity_max = 2.0 * plume_scale + 0.6
	pm.gravity = wind * 0.25 + Vector3(0, 0.15, 0)
	pm.damping_min = 0.3
	pm.damping_max = 0.6
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6 * plume_scale + 0.1
	pm.scale_min = 1.0 * plume_scale + 0.3
	pm.scale_max = 1.6 * plume_scale + 0.4
	# puffs grow from 0.4x to 3x and fade in, lighten and fade out over their lifetime
	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.4))
	growth.add_point(Vector2(1, 3.0))
	var ct := CurveTexture.new()
	ct.curve = growth
	pm.scale_curve = ct
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.55, 0.55, 0.57, 0.0))
	gradient.add_point(0.08, Color(0.6, 0.6, 0.62, 0.55))
	gradient.add_point(0.5, Color(0.72, 0.72, 0.74, 0.35))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.85, 0.85, 0.87, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = gradient
	pm.color_ramp = gt
	g.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _round_texture()
	mat.roughness = 1.0
	quad.material = mat
	g.draw_pass_1 = quad
	add_child(g)
	g.global_position = pos


## Soft round puff texture (32x32, white with quadratic radial alpha falloff), created once.
static func _round_texture() -> Texture2D:
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
