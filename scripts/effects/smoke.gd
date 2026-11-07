@tool
class_name Smoke
extends Node3D
## Smoke plumes (the "Rook" node of the world scene): puts a GPUParticles3D plume on
## every factory chimney top in the Gebouwen GridMap and, optionally, on every roof
## chimney in the Details GridMap. The plumes are generated children of this node
## (not saved in the scene) and are rebuilt on load; also works live in the editor.

@export var buildings_path := NodePath("../Gebouwen")
@export var details_path := NodePath("../Details")
## Also smoke from the small roof chimneys (Details layer).
@export var include_small_chimneys := true
## Wind (world space); a quarter of it is used as the particles' drift acceleration (m/s²).
@export var wind := Vector3(1.2, 0, -0.6)
## Inspector button: tick it to rebuild the plumes after editing the map.
@export var rescan := false:
	set(_value):
		_build()


func _ready() -> void:
	_build()


## Removes all plumes and creates new ones for the chimneys currently in the GridMaps.
func _build() -> void:
	if not is_inside_tree():
		return
	for plume in get_children():
		plume.queue_free()
	_scan(buildings_path, "fabrieksschoorsteen_top", 3.6, 1.0)
	if include_small_chimneys:
		_scan(details_path, "dak/schoorsteen", 2.1, 0.35)


## Adds a plume of size `plume_scale` (1 = factory chimney) `height` metres above the
## centre of every cell of the GridMap at `path` whose item name contains `item_part`.
func _scan(path: NodePath, item_part: String, height: float, plume_scale: float) -> void:
	var grid := get_node_or_null(path) as GridMap
	if grid == null or grid.mesh_library == null:
		return
	for cell in grid.get_used_cells():
		if grid.mesh_library.get_item_name(grid.get_cell_item(cell)).contains(item_part):
			_plume(grid.to_global(grid.map_to_local(cell)) + Vector3(0, height, 0), plume_scale)


## Creates one smoke plume at world position `pos`. plume_scale scales amount,
## lifetime, speed and puff size (1 = factory chimney, 0.35 = roof chimney).
## The puffs are small lit cubes, like the voxels of the rest of the game; they stay
## upright (no billboard) and tumble a little as they rise.
func _plume(pos: Vector3, plume_scale: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = int(40 * plume_scale) + 10
	particles.lifetime = 9.0 * (0.6 + plume_scale * 0.4)
	particles.preprocess = 8.0
	particles.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 60, 60))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 12.0
	process.initial_velocity_min = 1.2 * plume_scale + 0.4
	process.initial_velocity_max = 2.0 * plume_scale + 0.6
	process.gravity = wind * 0.25 + Vector3(0, 0.15, 0)
	process.damping_min = 0.3
	process.damping_max = 0.6
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.6 * plume_scale + 0.1
	process.scale_min = 1.0 * plume_scale + 0.3
	process.scale_max = 1.6 * plume_scale + 0.4
	# a slow tumble about the vertical axis, a different start angle per cube
	process.particle_flag_rotate_y = true
	process.angle_min = -45.0
	process.angle_max = 45.0
	process.angular_velocity_min = -12.0
	process.angular_velocity_max = 12.0
	# cubes grow from 0.4x to 2.4x and fade in, lighten and fade out over their lifetime
	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.4))
	growth.add_point(Vector2(1, 2.4))
	var growth_texture := CurveTexture.new()
	growth_texture.curve = growth
	process.scale_curve = growth_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.55, 0.55, 0.57, 0.0))
	gradient.add_point(0.08, Color(0.6, 0.6, 0.62, 0.5))
	gradient.add_point(0.5, Color(0.72, 0.72, 0.74, 0.3))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.85, 0.85, 0.87, 0.0))
	var colour_texture := GradientTexture1D.new()
	colour_texture.gradient = gradient
	process.color_ramp = colour_texture
	particles.process_material = process
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.8
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	cube.material = material
	particles.draw_pass_1 = cube
	add_child(particles)
	particles.global_position = pos
