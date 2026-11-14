class_name CigaretteSmoke
extends Node3D
## The smoke of a roll-up (Blikken Bertus, scripts/story/characters.gd puts it at his mouth):
## a thin wisp of small chunky grey puffs rising from the tip and drifting off, and now and then
## (exhale(), when he takes his hand from his mouth) a bigger cloud of a few larger puffs blown
## out forward. Cheap: two CPUParticles3D of a handful of puffs each, in the style of the game's
## fire and smoke (MenuFire.make_smoke, VehicleFire: little turning cubes with the colour in the
## vertex, no textures), only smaller, grey-white and slower, shrinking and fading as they rise.
##   var smoke := CigaretteSmoke.new()
##   head.add_child(smoke)
##   smoke.exhale()

const PUFF_COLOUR := Color(0.82, 0.82, 0.84, 0.7)
## The wisp from the tip: how many puffs at once and how long each lives (s): plenty and long,
## so it is seen from the iso camera.
const WISP_AMOUNT := 16
const WISP_LIFE := 4.0
## A breath out: how many puffs, how long they live, how fast they go out forward (m/s).
const EXHALE_AMOUNT := 14
const EXHALE_LIFE := 4.5
const EXHALE_SPEED := 0.7
## The drift of the smoke (world space, m/s²): a little wind.
const DRIFT := Vector3(0.25, 0.0, -0.12)

var _wisp: CPUParticles3D
var _breath: CPUParticles3D


func _ready() -> void:
	_wisp = _emitter(WISP_AMOUNT, WISP_LIFE, 0.03, 0.1)
	_wisp.name = "Sliert"
	_wisp.direction = Vector3.UP
	_wisp.spread = 12.0
	_wisp.initial_velocity_min = 0.12
	_wisp.initial_velocity_max = 0.22
	_wisp.emitting = true
	add_child(_wisp)
	_breath = _emitter(EXHALE_AMOUNT, EXHALE_LIFE, 0.06, 0.2)
	_breath.name = "Uitblazen"
	_breath.one_shot = true
	_breath.explosiveness = 0.7
	_breath.direction = Vector3(0.0, 0.35, 1.0)   # out forward (the face looks to +z), rising
	_breath.spread = 25.0
	_breath.initial_velocity_min = EXHALE_SPEED * 0.6
	_breath.initial_velocity_max = EXHALE_SPEED
	_breath.damping_min = 0.5
	_breath.damping_max = 0.8
	_breath.emitting = false
	add_child(_breath)


## A breath out: a bigger cloud blown out forward.
func exhale() -> void:
	if _breath:
		_breath.restart()


## Whether a cloud of a breath out is in the air now (for the checks).
func is_exhaling() -> bool:
	return _breath != null and _breath.emitting


func _emitter(amount: int, life: float, size_from: float, size_to: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.local_coords = false   # the smoke stays where it was blown as he walks on
	particles.gravity = DRIFT + Vector3.UP * 0.12
	var puff := BoxMesh.new()
	puff.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	puff.material = material
	particles.mesh = puff
	# shrinking and fading as it rises (as the cubes of the fires, MenuFire)
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 1.0))
	growth.add_point(Vector2(1.0, size_from / size_to))
	particles.scale_amount_min = size_to
	particles.scale_amount_max = size_to * 1.3
	particles.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.set_color(0, PUFF_COLOUR)
	fade.set_color(1, Color(PUFF_COLOUR, 0.0))
	particles.color_ramp = fade
	particles.angle_min = 0.0
	particles.angle_max = 45.0
	particles.particle_flag_rotate_y = true
	particles.angular_velocity_min = -40.0
	particles.angular_velocity_max = 40.0
	return particles
