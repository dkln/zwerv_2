extends Node3D
## Someone falling into the water (PlayerController, drowning): a splash of voxel droplets,
## white and light blue, flying up and falling back, and then bubbles rising from where they
## went under for `bubble_seconds`. One-shot CPUParticles3D (they need no GPU particle shader
## compile); it frees itself once the last bubble is gone.
##   var splash := WaterSplash.new()   # const WaterSplash = preload(this file)
##   splash.bubble_seconds = 2.5
##   parent.add_child(splash)
##   splash.global_position = water_point

const DROPLET_COLOURS := [Color("#E8F4FF"), Color("#9CCDF0"), Color("#5E9FD6")]
const DROPLET_LIFETIME := 1.1
const BUBBLE_LIFETIME := 0.9

var bubble_seconds := 2.5


func _ready() -> void:
	var droplets := CPUParticles3D.new()
	droplets.name = "Druppels"
	droplets.one_shot = true
	droplets.explosiveness = 0.9
	droplets.amount = 48
	droplets.lifetime = DROPLET_LIFETIME
	droplets.mesh = _cube(0.09)
	droplets.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	droplets.emission_sphere_radius = 0.35
	droplets.direction = Vector3.UP
	droplets.spread = 38.0
	droplets.initial_velocity_min = 2.5
	droplets.initial_velocity_max = 5.5
	droplets.gravity = Vector3(0.0, -11.0, 0.0)
	droplets.scale_amount_min = 0.6
	droplets.scale_amount_max = 1.4
	var droplet_colours := Gradient.new()
	droplet_colours.colors = PackedColorArray(DROPLET_COLOURS)
	droplet_colours.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	droplets.color_initial_ramp = droplet_colours
	add_child(droplets)
	droplets.emitting = true
	var bubbles := CPUParticles3D.new()
	bubbles.name = "Bellen"
	bubbles.amount = 14
	bubbles.lifetime = BUBBLE_LIFETIME
	bubbles.mesh = _cube(0.07)
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.3
	bubbles.direction = Vector3.UP
	bubbles.spread = 15.0
	bubbles.initial_velocity_min = 0.3
	bubbles.initial_velocity_max = 0.8
	bubbles.gravity = Vector3.ZERO
	bubbles.color = DROPLET_COLOURS[0]
	bubbles.position = Vector3.UP * 0.05
	add_child(bubbles)
	bubbles.emitting = true
	get_tree().create_timer(bubble_seconds).timeout.connect(func() -> void: bubbles.emitting = false)
	get_tree().create_timer(bubble_seconds + BUBBLE_LIFETIME + DROPLET_LIFETIME).timeout.connect(queue_free)


static func _cube(size: float) -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cube.material = material
	return cube
