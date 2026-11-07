class_name CrashBurst
extends Node3D
## The bang of a crash (vehicle.gd, _crash_with): a burst of voxel shards (bits of body
## paint, glass and black plastic flying out and tumbling down) and a puff of grey dust
## cubes that rises and spreads, both one-shot GPUParticles3D, at the point of contact.
## `strength` (0..1, from the closing speed) scales how many and how far. It frees itself
## once the last particle is gone.

const SHARD_LIFETIME := 1.6
const DUST_LIFETIME := 2.6

## The body colour of the vehicles: some of the shards get it.
var paint := Color(0.7, 0.7, 0.72)
var strength := 0.5


static func spawn(parent: Node, at: Vector3, body_colour: Color, crash_strength: float) -> CrashBurst:
	var burst := CrashBurst.new()
	burst.paint = body_colour
	burst.strength = clampf(crash_strength, 0.0, 1.0)
	parent.add_child(burst)
	burst.global_position = at
	return burst


func _ready() -> void:
	_add_shards()
	_add_dust()
	get_tree().create_timer(DUST_LIFETIME + 0.2, false).timeout.connect(queue_free)


func _add_shards() -> void:
	var particles := _one_shot(int(lerpf(24.0, 70.0, strength)), SHARD_LIFETIME)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 75.0
	process.initial_velocity_min = lerpf(3.0, 5.0, strength)
	process.initial_velocity_max = lerpf(6.0, 11.0, strength)
	process.gravity = Vector3(0, -14.0, 0)
	process.damping_min = 0.5
	process.damping_max = 1.5
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.scale_min = 0.6
	process.scale_max = 1.4
	# tumbling as they fly
	process.particle_flag_rotate_y = true
	process.angular_velocity_min = -540.0
	process.angular_velocity_max = 540.0
	process.angle_max = 360.0
	# paint, glass and black plastic, picked at random along the ramp
	var colours := Gradient.new()
	colours.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colours.set_color(0, paint)
	colours.set_offset(0, 0.0)
	colours.set_color(1, Color(0.75, 0.88, 0.95))
	colours.set_offset(1, 0.5)
	colours.add_point(0.75, Color(0.08, 0.08, 0.09))
	var colour_texture := GradientTexture1D.new()
	colour_texture.gradient = colours
	process.color_initial_ramp = colour_texture
	# they fade out only at the very end (lying on the road a moment)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	particles.process_material = process
	particles.draw_pass_1 = _cube(0.125, false)
	particles.explosiveness = 0.95


func _add_dust() -> void:
	var particles := _one_shot(int(lerpf(10.0, 26.0, strength)), DUST_LIFETIME)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 90.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = lerpf(2.5, 4.5, strength)
	process.gravity = Vector3(0, 0.4, 0)
	process.damping_min = 1.5
	process.damping_max = 2.5
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.8
	process.scale_min = 0.8
	process.scale_max = 1.5
	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.5))
	growth.add_point(Vector2(1, 2.2))
	var growth_texture := CurveTexture.new()
	growth_texture.curve = growth
	process.scale_curve = growth_texture
	process.particle_flag_rotate_y = true
	process.angle_max = 90.0
	process.angular_velocity_min = -30.0
	process.angular_velocity_max = 30.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.5, 0.48, 0.45, 0.7))
	gradient.add_point(0.4, Color(0.62, 0.6, 0.58, 0.45))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.75, 0.74, 0.72, 0.0))
	var colour_texture := GradientTexture1D.new()
	colour_texture.gradient = gradient
	process.color_ramp = colour_texture
	particles.process_material = process
	particles.draw_pass_1 = _cube(0.5, true)
	particles.explosiveness = 0.85


func _one_shot(amount: int, lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.emitting = true
	particles.visibility_aabb = AABB(Vector3(-15, -2, -15), Vector3(30, 20, 30))
	add_child(particles)
	return particles


## A lit cube of `size` metres coloured by the particles (see-through for the dust).
static func _cube(size: float, see_through: bool) -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	if see_through:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cube.material = material
	return cube
