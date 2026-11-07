extends Node3D
## A big fire now and then in the skyline behind the main menu (scripts/ui/main_menu.gd
## adds one to the menu's map): after FIRST_WAIT seconds a roof somewhere round Centraal
## catches fire, the flames (glowing cubes) and a thick column of smoke (dark cubes, drifting
## with the wind) grow, it burns for a while (BURN_SECONDS), dies down and the smoke thins
## out; after a pause (PAUSE_SECONDS) another roof elsewhere catches fire. Voxel-like, as the
## chimney smoke of the town (smoke.gd): cubes, no soft sprites. An orange flickering light
## lights the buildings around it. The fire keeps growing while it burns: it starts small
## (START_SHARE of the full fire) and spreads to FULL_SIZE times a roof's width, with more
## flames, more smoke and a brighter, wider light. make_flames/make_smoke also set burning
## tractor wrecks on fire (main_menu.gd).
## The roofs: the tops of the Gebouwen GridMap of the map, in view of the camera, at least
## MIN_DISTANCE away (the background) and MIN_HEIGHT high.

const FIRST_WAIT := 30.0
const BURN_SECONDS := Vector2(40.0, 70.0)
const PAUSE_SECONDS := Vector2(12.0, 30.0)
const GROW_SECONDS := 5.0
const DIE_SECONDS := 8.0
const MIN_DISTANCE := 180.0
const MAX_DISTANCE := 520.0
const MIN_HEIGHT := 9.0
const WIND := Vector3(1.6, 0.0, -0.4)
const LIGHT_ENERGY := 6.0
const FULL_SIZE := 1.8
const START_SHARE := 0.2

var grid: GridMap
var camera: Camera3D
## Seconds before the first fire (FIRST_WAIT; a fire added later starts sooner).
var first_wait := FIRST_WAIT
## How fierce (1: as described; more as the chaos behind the menu grows): the fire spreads
## wider, its light reaches further, the pauses are shorter.
var fury := 1.0

## The roofs that burn now (of all fires): a fire does not take a roof near one of them.
static var _burning_roofs: Array[Vector3] = []

var _clock := 0.0
var _phase := "wachten"   # wachten, groeien, branden, doven
var _phase_length := FIRST_WAIT
var _strength := 0.0      # 0 .. 1: how much fire there is
var _flames: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _last_spot := Vector3.INF
var _growth := 0.0        # START_SHARE .. 1: how far the fire has spread
var _burned := 0.0        # seconds since it caught fire
var _burn_length := 1.0   # seconds it grows and burns (GROW_SECONDS + its burn)
var _flame_box := Vector3.ONE
var _smoke_box := Vector3.ONE


func _ready() -> void:
	_phase_length = first_wait
	_flames = make_flames(FULL_SIZE)
	_smoke = make_smoke(FULL_SIZE)
	_flame_box = (_flames.process_material as ParticleProcessMaterial).emission_box_extents
	_smoke_box = (_smoke.process_material as ParticleProcessMaterial).emission_box_extents
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.15)
	_light.omni_range = 45.0
	_light.shadow_enabled = false
	for part: Node3D in [_flames, _smoke, _light]:
		part.visible = false
		add_child(part)


func _process(delta: float) -> void:
	_clock += delta
	match _phase:
		"wachten":
			if _clock > _phase_length and _catch_fire():
				_next("groeien", GROW_SECONDS)
				_burned = 0.0
				_burn_length = GROW_SECONDS + randf_range(BURN_SECONDS.x, BURN_SECONDS.y)
		"groeien":
			_strength = clampf(_clock / GROW_SECONDS, 0.0, 1.0)
			if _clock > _phase_length:
				_next("branden", _burn_length - GROW_SECONDS)
		"branden":
			_strength = 1.0
			if _clock > _phase_length:
				_next("doven", DIE_SECONDS)
		"doven":
			_strength = 1.0 - clampf(_clock / DIE_SECONDS, 0.0, 1.0)
			if _clock > _phase_length:
				_next("wachten", randf_range(PAUSE_SECONDS.x, PAUSE_SECONDS.y) / fury)
				_burning_roofs.erase(_last_spot)
	if _phase == "groeien" or _phase == "branden":
		_burned += delta
		_growth = lerpf(START_SHARE, 1.0, clampf(_burned / _burn_length, 0.0, 1.0))
	# the fire spreads over the roof: the flames and the smoke come from a wider area
	var spread := sqrt(_growth) * fury
	(_flames.process_material as ParticleProcessMaterial).emission_box_extents = _flame_box * Vector3(spread, 1.0, spread)
	(_smoke.process_material as ParticleProcessMaterial).emission_box_extents = _smoke_box * Vector3(spread, 1.0, spread)
	_light.omni_range = (30.0 + 40.0 * _growth) * fury
	_flames.amount_ratio = _strength * _growth
	# the smoke lags behind: it thins out slower than the flames go
	_smoke.amount_ratio = maxf(_strength * _growth, _smoke.amount_ratio - delta / 14.0) if _phase != "wachten" else 0.0
	_smoke.emitting = _smoke.amount_ratio > 0.01
	_flames.emitting = _strength > 0.01
	var flicker := 0.75 + 0.25 * sin(_clock * 17.0) * sin(_clock * 7.3)
	_light.light_energy = LIGHT_ENERGY * _strength * flicker * (0.4 + 0.6 * _growth)
	_light.visible = _strength > 0.01


## True while there is fire (growing, burning or dying down).
func is_burning() -> bool:
	return _phase != "wachten"


func _exit_tree() -> void:
	_burning_roofs.erase(_last_spot)


func _next(phase: String, length: float) -> void:
	_phase = phase
	_phase_length = length
	_clock = 0.0


## Picks a roof in view in the background (not the last one) and moves the fire there.
## False if there is none (it tries again next frame).
func _catch_fire() -> bool:
	if grid == null or camera == null:
		return false
	var tops := {}   # (x, z) -> highest cell
	for cell in grid.get_used_cells():
		var column := Vector2i(cell.x, cell.z)
		if not tops.has(column) or (tops[column] as Vector3i).y < cell.y:
			tops[column] = cell
	var spots: Array[Vector3] = []
	for cell: Vector3i in tops.values():
		var top := grid.to_global(grid.map_to_local(cell)) + Vector3(0, grid.cell_size.y * 0.5, 0)
		var distance := top.distance_to(camera.global_position)
		if top.y < MIN_HEIGHT or distance < MIN_DISTANCE or distance > MAX_DISTANCE:
			continue
		if not camera.is_position_in_frustum(top) or top.distance_to(_last_spot) < 40.0:
			continue
		if _burning_roofs.any(func(roof: Vector3) -> bool: return roof.distance_to(top) < 40.0):
			continue
		spots.append(top)
	if spots.is_empty():
		return false
	_last_spot = spots.pick_random()
	_burning_roofs.append(_last_spot)
	global_position = _last_spot
	_light.position = Vector3(0, 4.0, 0)
	for particles in [_flames, _smoke]:
		(particles as GPUParticles3D).restart()
	for part: Node3D in [_flames, _smoke, _light]:
		part.visible = true
	return true


## The flames: glowing cubes from yellow-white to orange to deep red, quick and short-lived,
## over the width of a roof (`size` 1; smaller for a burning wreck in the menu).
static func make_flames(size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Vlammen"
	particles.amount = int(90 * size) + 10
	particles.lifetime = 1.4
	particles.visibility_aabb = AABB(Vector3(-15, -2, -15) * size, Vector3(30, 30, 30) * size)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(3.5, 0.5, 3.5) * size
	process.direction = Vector3.UP
	process.spread = 15.0
	process.initial_velocity_min = 3.0 * sqrt(size)
	process.initial_velocity_max = 6.5 * sqrt(size)
	process.gravity = Vector3(0, 1.5, 0) + WIND * 0.5
	process.scale_min = 0.8 * sqrt(size)
	process.scale_max = 1.8 * sqrt(size)
	process.particle_flag_rotate_y = true
	process.angle_min = -45.0
	process.angle_max = 45.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1.0))
	shrink.add_point(Vector2(1, 0.2))
	var shrink_texture := CurveTexture.new()
	shrink_texture.curve = shrink
	process.scale_curve = shrink_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(4.0, 3.2, 1.6))
	gradient.add_point(0.25, Color(3.5, 1.5, 0.3))
	gradient.add_point(0.6, Color(2.0, 0.45, 0.08))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.5, 0.08, 0.02))
	var colours := GradientTexture1D.new()
	colours.gradient = gradient
	process.color_ramp = colours
	particles.process_material = process
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.9
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	cube.material = material
	particles.draw_pass_1 = cube
	return particles


## The smoke: big dark grey cubes that rise, grow, drift with the wind and fade, long-lived:
## a column high above the skyline (`size` 1; smaller for a burning wreck).
static func make_smoke(size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Rook"
	particles.amount = int(140 * size) + 20
	particles.lifetime = 16.0 * (0.5 + size * 0.5)
	particles.visibility_aabb = AABB(Vector3(-60, -2, -60) * size, Vector3(160, 140, 120) * size)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(3.0, 1.0, 3.0) * size
	process.direction = Vector3.UP
	process.spread = 10.0
	process.initial_velocity_min = 3.5
	process.initial_velocity_max = 6.0
	process.gravity = WIND + Vector3(0, 0.2, 0)
	process.damping_min = 0.15
	process.damping_max = 0.3
	process.scale_min = 1.5 * sqrt(size)
	process.scale_max = 2.6 * sqrt(size)
	process.particle_flag_rotate_y = true
	process.angle_min = -45.0
	process.angle_max = 45.0
	process.angular_velocity_min = -8.0
	process.angular_velocity_max = 8.0
	var growth := Curve.new()
	growth.add_point(Vector2(0, 0.5))
	growth.add_point(Vector2(1, 3.0))
	var growth_texture := CurveTexture.new()
	growth_texture.curve = growth
	process.scale_curve = growth_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.25, 0.12, 0.06, 0.0))
	gradient.add_point(0.05, Color(0.2, 0.17, 0.16, 0.85))
	gradient.add_point(0.4, Color(0.16, 0.16, 0.18, 0.7))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.3, 0.3, 0.33, 0.0))
	var colours := GradientTexture1D.new()
	colours.gradient = gradient
	process.color_ramp = colours
	particles.process_material = process
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 1.6
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	cube.material = material
	particles.draw_pass_1 = cube
	return particles
