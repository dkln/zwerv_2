extends Node
## Day and night cycle (the "Dagcyclus" node of the world scene): rotates and colours
## the sun, dims the fill light and the ambient light, colours the procedural sky and
## sets the global shader parameters the voxel shaders read:
## `zwervr_nacht` (0 = day, 1 = night; brightens emissive voxels) and
## `zwervr_lucht_boven` / `zwervr_lucht_horizon` (sky colours reflected by glass).
##
## The shadow-casting sun stays between `min_elevation` and `max_elevation` degrees
## above the horizon, so shadows never become extremely long; the time of day mainly
## drives the colours and the brightness.

@export_range(0.0, 24.0) var time_of_day := 13.0       ## hour of the day
@export var speed := 0.0                                ## hours per second (0 = standing still)
@export_range(10.0, 80.0) var min_elevation := 36.0     ## degrees; sun elevation at sunrise/sunset, prevents long shadows
@export_range(30.0, 89.0) var max_elevation := 44.0     ## degrees; sun elevation at midday
@export var sun_path := NodePath("../Zon")
@export var fill_light_path := NodePath("../Vullicht")
@export var environment_path := NodePath("../Omgeving")

var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial


func _ready() -> void:
	_sun = get_node_or_null(sun_path)
	_fill = get_node_or_null(fill_light_path)
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we:
		_env = we.environment
		if _env and _env.sky:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_apply()


## Advances the clock by `speed` hours per second (wrapping at 24) and reapplies.
func _process(delta: float) -> void:
	if speed == 0.0:
		return
	time_of_day = fposmod(time_of_day + delta * speed, 24.0)
	_apply()


## Applies `time_of_day` to the sun, fill light, environment, sky and shader globals.
func _apply() -> void:
	if _sun == null:
		return
	# 6:00 sunrise (east), 12:00 south, 18:00 sunset (west)
	var day := clampf((time_of_day - 6.0) / 12.0, 0.0, 1.0)
	var true_elevation := sin(day * PI)               # 0 at the horizon, 1 at midday
	# brightness 0..1: full from ~1/3 elevation, dark outside 5:30-18:30
	var light := clampf(true_elevation * 3.0, 0.0, 1.0) if time_of_day > 5.5 and time_of_day < 18.5 else 0.0
	# rotation around the vertical axis: 90 = light from the east, 0 = from the south.
	# The camera looks from the southeast; the sun stays at an angle from the side
	# (east to southeast) so shadows fall visibly in view and the facades stay lit.
	var azimuth := lerpf(110.0, 55.0, day)
	var elevation := lerpf(min_elevation, max_elevation, true_elevation)
	_sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
	var warm := 1.0 - true_elevation   # warmer (orange) light near the horizon
	_sun.light_color = Color(1.0, 0.93 - warm * 0.25, 0.82 - warm * 0.45)
	_sun.light_energy = 1.55 * light
	_sun.shadow_enabled = light > 0.05
	RenderingServer.global_shader_parameter_set("zwervr_nacht", 1.0 - light)
	if _fill:
		# at night the fill light becomes a faint blue moonlight
		_fill.light_energy = lerpf(0.12, 0.22, light)
		_fill.light_color = Color(0.62, 0.74, 1.0).lerp(Color(0.45, 0.55, 0.9), 1.0 - light)
	if _env:
		_env.ambient_light_energy = lerpf(0.18, 0.8, light)
		_env.background_energy_multiplier = lerpf(0.15, 1.0, light)
	if _sky:
		_sky.sky_top_color = Color(0.05, 0.07, 0.16).lerp(Color(0.3, 0.5, 0.85), light)
		# night -> day horizon, plus a sunset glow when the sun is low but still up
		_sky.sky_horizon_color = Color(0.12, 0.12, 0.22).lerp(Color(0.7, 0.8, 0.92), light).lerp(Color(0.95, 0.6, 0.4), warm * light * 0.6)
		_sky.ground_horizon_color = _sky.sky_horizon_color
		_sky.ground_bottom_color = _sky.sky_horizon_color.lerp(_sky.sky_top_color, 0.5)
		# glass reflects the same sky (voxel_glass.gdshader)
		RenderingServer.global_shader_parameter_set("zwervr_lucht_boven", _sky.sky_top_color.lightened(0.1))
		RenderingServer.global_shader_parameter_set("zwervr_lucht_horizon", _sky.sky_horizon_color)
